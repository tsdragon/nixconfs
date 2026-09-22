"""LibreChat multipart STT -> OpenRouter MAI with live Sanctuary keyword hints."""

import argparse
import array
import base64
import hmac
import json
import logging
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from email import policy
from email.parser import BytesParser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import yaml

MODEL = "microsoft/mai-transcribe-2"
UPSTREAM = "https://openrouter.ai/api/v1/audio/transcriptions"
MAX_UPLOAD = 25 * 1024 * 1024
MAX_SECONDS = 25 * 60
CHUNK_SECONDS = 3 * 60
PCM_BYTES_PER_SECOND = 16000 * 2
# Keep a focused list: larger lists returned provider 400 in live tests.
MAX_PHRASES = 50
FOLDERS = ("PCs", "NPCs", "Factions", "Locations", "World")
TYPES = {"pc", "npc", "faction", "location", "world", "item"}


def vocabulary(vault, terms_file):
    """Send names/aliases only; never send note bodies or hidden vault files."""
    vault = Path(vault).resolve(strict=True)
    phrases = {}

    def add(value):
        if not isinstance(value, str):
            return
        value = " ".join(value.split()).strip()
        if 1 < len(value) <= 100 and not any(c in value for c in "[]{}<>/\\"):
            phrases.setdefault(value.casefold(), value)

    for line in Path(terms_file).read_text().splitlines():
        if line.strip() and not line.lstrip().startswith("#"):
            add(line)
    pinned = set(phrases)
    for folder in FOLDERS:
        for note in sorted((vault / folder).rglob("*.md")):
            if not note.resolve().is_relative_to(vault):
                continue
            if any(p.startswith((".", "_")) for p in note.relative_to(vault).parts):
                continue
            text = note.read_text(encoding="utf-8")
            match = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", text, re.S)
            if not match:
                continue
            meta = yaml.safe_load(match[1])
            if not isinstance(meta, dict) or meta.get("type") not in TYPES:
                continue
            if meta.get("canon_status") in {"deprecated", "superseded"}:
                continue
            name = meta.get("name", note.stem)
            if name in {"PCs", "Core Concept", "Tech Level", "Player Introduction"}:
                continue
            add(name)
            add(note.stem)
            aliases = meta.get("aliases", [])
            for alias in [aliases] if isinstance(aliases, str) else aliases or []:
                add(alias)
    # Prefer terms actually used at the table when the vault has more names
    # than fit. Session prose stays local and is used only to rank the terms.
    sessions = "\n".join(
        p.read_text(encoding="utf-8") for p in sorted((vault / "Sessions").rglob("*.md"))
        if p.resolve().is_relative_to(vault)
        and not any(part.startswith((".", "_")) for part in p.relative_to(vault).parts)
    ).casefold()
    ranked = sorted(phrases.values(), key=lambda term: (
        term.casefold() not in pinned,
        -len(re.findall(r"(?<!\w)" + re.escape(term.casefold()) + r"(?!\w)", sessions)),
        term.casefold(),
    ))
    return ranked[:MAX_PHRASES]


def parse_upload(content_type, body):
    message = BytesParser(policy=policy.default).parsebytes(
        f"Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n".encode() + body
    )
    if message.get_content_type() != "multipart/form-data" or not message.is_multipart():
        raise ValueError("Expected a multipart audio upload.")
    fields = {}
    for part in message.iter_parts():
        name = part.get_param("name", header="content-disposition")
        if name in {"file", "model", "language"}:
            fields[name] = part.get_payload(decode=True)
    if not fields.get("file"):
        raise ValueError("An audio file is required.")
    if fields.get("model", MODEL.encode()).decode() != MODEL:
        raise ValueError(f"Only {MODEL} is supported.")
    language = fields.get("language", b"").decode()
    if language and not re.fullmatch(r"[a-z]{2,3}(?:-[A-Za-z]{2})?", language):
        raise ValueError("Invalid language code.")
    return fields["file"], language.split("-")[0]


def pcm_chunks(pcm):
    """Split without dropping samples, preferring a quiet point near each boundary."""
    size = CHUNK_SECONDS * PCM_BYTES_PER_SECOND
    while pcm:
        if len(pcm) <= size:
            yield pcm
            return
        # Find the quietest 100 ms within the last five seconds of the chunk.
        # This reduces cuts through words without overlapping/duplicating speech.
        start = size - min(5 * PCM_BYTES_PER_SECOND, size // 2)
        window = PCM_BYTES_PER_SECOND // 10
        def energy(offset):
            samples = array.array("h", pcm[offset:offset + window])
            if sys.byteorder != "little":
                samples.byteswap()
            return sum(abs(sample) for sample in samples)
        quiet = min(range(start, size - window + 1, window), key=energy)
        boundary = quiet + window // 2
        yield pcm[:boundary]
        pcm = pcm[boundary:]


def normalize_audio(audio):
    # Decode a bounded duration to PCM first: WebM often has no duration metadata.
    # The extra second detects overlong clips without silently truncating them.
    with tempfile.TemporaryDirectory(prefix="sanctuary-stt-") as tmp:
        source = Path(tmp) / "input"
        pcm = Path(tmp) / "audio.pcm"
        flac = Path(tmp) / "audio.flac"
        source.write_bytes(audio)
        common = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error"]
        subprocess.run(common + ["-protocol_whitelist", "file,pipe", "-i", str(source),
                       "-t", str(MAX_SECONDS + 1), "-vn", "-ac", "1", "-ar", "16000",
                       "-f", "s16le", str(pcm)], check=True, capture_output=True, timeout=90)
        if pcm.stat().st_size > MAX_SECONDS * 16000 * 2:
            raise ValueError(f"Recordings must be at most {MAX_SECONDS // 60} minutes. Split longer audio.")
        if not pcm.stat().st_size:
            raise ValueError("The recording contains no audio.")
        chunks = []
        for chunk in pcm_chunks(pcm.read_bytes()):
            subprocess.run(common + ["-y", "-f", "s16le", "-ar", "16000", "-ac", "1",
                           "-i", "pipe:0", str(flac)], input=chunk,
                           check=True, capture_output=True, timeout=60)
            chunks.append(flac.read_bytes())
        return chunks


def request_json(url, payload, key):
    request = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={
        "Authorization": f"Bearer {key}", "Content-Type": "application/json",
    })
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)


def transcribe(audio, language, phrases, key):
    payload = {
        "model": MODEL,
        "input_audio": {"data": base64.b64encode(audio).decode(), "format": "flac"},
        "response_format": "json",
        "provider": {"options": {"azure": {"phraseList": {"phrases": phrases}}}},
    }
    if language:
        payload["language"] = language
    # Keep the vocabulary on every attempt; transient provider errors must not
    # silently downgrade transcription to an unhinted request.
    for attempt in range(3):
        try:
            result = request_json(UPSTREAM, payload, key)
            break
        except urllib.error.HTTPError as exc:
            if attempt == 2 or exc.code not in {429, 502, 503, 504}:
                raise
            logging.warning("OpenRouter HTTP %s; retrying transcription", exc.code)
            time.sleep(2 ** (attempt + 1))
    if not isinstance(result.get("text"), str):
        raise ValueError("Transcription provider did not return text.")
    return {"text": result["text"]}


class Handler(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(120)

    def respond(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_upload(self):
        # LibreChat's Axios client streams its multipart body with chunked
        # transfer encoding; regular file-upload clients send Content-Length.
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            chunks, total = [], 0
            while True:
                line = self.rfile.readline(1024)
                if not line.endswith(b"\r\n"):
                    raise ValueError("Invalid upload framing.")
                size = int(line.split(b";", 1)[0].strip(), 16)
                if size < 0:
                    raise ValueError("Invalid chunk size.")
                if size == 0:
                    break
                total += size
                if total > MAX_UPLOAD:
                    raise OverflowError("Upload exceeds 25 MiB.")
                chunk = self.rfile.read(size)
                if len(chunk) != size or self.rfile.read(2) != b"\r\n":
                    raise ValueError("Incomplete upload.")
                chunks.append(chunk)
            return b"".join(chunks)
        size = int(self.headers.get("Content-Length", "0"))
        if not 0 < size <= MAX_UPLOAD:
            raise OverflowError("Upload must be between 1 byte and 25 MiB.")
        body = self.rfile.read(size)
        if len(body) != size:
            raise ValueError("Incomplete upload.")
        return body

    def do_GET(self):
        if self.path != "/health":
            return self.respond(404, {"error": "Not found"})
        try:
            phrases = vocabulary(self.server.vault, self.server.terms_file)
            self.respond(200, {"status": "ok", "model": MODEL, "phrases": len(phrases)})
        except (OSError, ValueError, yaml.YAMLError):
            self.respond(503, {"error": "Cannot load Sanctuary vocabulary"})

    def do_POST(self):
        if self.path != "/v1/audio/transcriptions":
            return self.respond(404, {"error": "Not found"})
        if not hmac.compare_digest(self.headers.get("Authorization", ""),
                                   f"Bearer {self.server.api_key}"):
            return self.respond(401, {"error": "Unauthorized"})
        try:
            body = self.read_upload()
            audio, language = parse_upload(self.headers.get("Content-Type", ""), body)
            phrases = vocabulary(self.server.vault, self.server.terms_file)
            chunks = normalize_audio(audio)
            logging.info("Transcribing recording in %d chunk(s)", len(chunks))
            texts = [transcribe(chunk, language, phrases, self.server.api_key)["text"]
                     for chunk in chunks]
            self.respond(200, {"text": "\n\n".join(text for text in texts if text.strip())})
        except urllib.error.HTTPError as exc:
            logging.warning("OpenRouter returned HTTP %s", exc.code)
            self.respond(502, {"error": f"OpenRouter returned HTTP {exc.code}"})
        except (urllib.error.URLError, TimeoutError):
            self.respond(504, {"error": "OpenRouter connection failed or timed out"})
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            self.respond(400, {"error": "Audio could not be decoded"})
        except OverflowError as exc:
            self.respond(413, {"error": str(exc)})
        except (ValueError, UnicodeError) as exc:
            self.respond(400, {"error": str(exc)})
        except (OSError, yaml.YAMLError):
            self.respond(503, {"error": "Cannot read audio or Sanctuary vocabulary"})

    def log_message(self, fmt, *args):
        # No audio, transcript, vocabulary, or credentials in logs.
        logging.info(fmt, *args)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vocabulary", action="store_true", help="Print current phrase list and exit")
    args = parser.parse_args()
    vault = os.environ.get("SANCTUARY_PATH", "/home/tal/Documents/sanctuary")
    terms_file = os.environ.get("STT_TERMS_FILE", str(Path(__file__).with_name("terms.txt")))
    phrases = vocabulary(vault, terms_file)
    if args.vocabulary:
        print(json.dumps(phrases, ensure_ascii=False, indent=2))
        return
    key = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "openrouter-key").read_text().strip()
    if not key:
        raise ValueError("Empty OpenRouter credential")
    logging.basicConfig(level=logging.INFO)
    server = HTTPServer(("127.0.0.1", 3081), Handler)
    server.api_key, server.vault, server.terms_file = key, vault, terms_file
    logging.info("Sanctuary STT ready with %d phrases", len(phrases))
    server.serve_forever()


if __name__ == "__main__":
    main()
