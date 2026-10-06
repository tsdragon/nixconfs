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
MAX_FILE_BYTES = 64 * 1024 * 1024
MAX_UPLOAD = MAX_FILE_BYTES + 1024 * 1024  # Allow multipart framing.
MAX_SECONDS = 30 * 60
# Below OpenRouter's 25 MB inline limit, including base64 and JSON overhead.
MAX_UPSTREAM_AUDIO = 18_000_000
MIN_CHUNK_SECONDS = 30
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
    if len(fields["file"]) > MAX_FILE_BYTES:
        raise OverflowError("Audio file exceeds 64 MiB.")
    if fields.get("model", MODEL.encode()).decode() != MODEL:
        raise ValueError(f"Only {MODEL} is supported.")
    language = fields.get("language", b"").decode()
    if language and not re.fullmatch(r"[a-z]{2,3}(?:-[A-Za-z]{2})?", language):
        raise ValueError("Invalid language code.")
    return fields["file"], language.split("-")[0]


def pcm_chunks(pcm, max_seconds=MAX_SECONDS):
    """Keep every sample; prefer the latest pause before the requested limit."""
    limit = int(max_seconds * PCM_BYTES_PER_SECOND) // 2 * 2
    while pcm:
        if len(pcm) <= limit:
            yield pcm
            return
        # Avoid leaving a tiny final fragment with too little speech context.
        minimum_tail = min(MIN_CHUNK_SECONDS * PCM_BYTES_PER_SECOND, limit // 2) // 2 * 2
        size = min(limit, len(pcm) - minimum_tail)
        # A 300 ms pause is less likely to be inside a word than a brief dip.
        # Search the final 30 seconds and prefer the latest real pause, keeping
        # chunks large. With continuous speech, use the quietest window instead.
        start = size - min(30 * PCM_BYTES_PER_SECOND, size // 2)
        window = 3 * PCM_BYTES_PER_SECOND // 10
        step = PCM_BYTES_PER_SECOND // 10
        def energy(offset):
            samples = array.array("h", pcm[offset:offset + window])
            if sys.byteorder != "little":
                samples.byteswap()
            return sum(abs(sample) for sample in samples) / len(samples)
        candidates = [(energy(offset), offset)
                      for offset in range(start, size - window + 1, step)]
        pauses = [offset for level, offset in candidates if level <= 327]
        quiet = pauses[-1] if pauses else min(candidates, key=lambda item: (item[0], -item[1]))[1]
        boundary = quiet + window // 2
        yield pcm[:boundary]
        pcm = pcm[boundary:]


def normalize_audio(audio):
    # Decode a bounded duration to PCM first: WebM often has no duration metadata.
    # The extra second detects overlong clips without silently truncating them.
    with tempfile.TemporaryDirectory(prefix="sanctuary-stt-") as tmp:
        source = Path(tmp) / "input"
        pcm = Path(tmp) / "audio.pcm"
        source.write_bytes(audio)
        common = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error"]
        subprocess.run(common + ["-protocol_whitelist", "file,pipe", "-i", str(source),
                       "-t", str(MAX_SECONDS + 1), "-vn", "-ac", "1", "-ar", "16000",
                       "-f", "s16le", str(pcm)], check=True, capture_output=True, timeout=90)
        if pcm.stat().st_size > MAX_SECONDS * PCM_BYTES_PER_SECOND:
            raise ValueError(f"Recordings must be at most {MAX_SECONDS // 60} minutes. Split longer audio.")
        if not pcm.stat().st_size:
            raise ValueError("The recording contains no audio.")
        return pcm.read_bytes()


def encode_audio(pcm):
    # A seekable output lets ffmpeg finalize FLAC's sample count and duration.
    # Piped FLAC leaves those fields empty and MAI returns provider HTTP 500.
    with tempfile.TemporaryDirectory(prefix="sanctuary-stt-flac-") as tmp:
        output = Path(tmp) / "audio.flac"
        subprocess.run(
            ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error",
             "-f", "s16le", "-ar", "16000", "-ac", "1", "-i", "pipe:0", str(output)],
            input=pcm, check=True, capture_output=True, timeout=60,
        )
        return output.read_bytes()


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
            if attempt == 2 or exc.code not in {429, 502, 503}:
                raise
            logging.warning("OpenRouter HTTP %s; retrying transcription", exc.code)
            time.sleep(2 ** (attempt + 1))
    if not isinstance(result.get("text"), str):
        raise ValueError("Transcription provider did not return text.")
    return {"text": result["text"]}


def transcribe_recording(pcm, language, phrases, key):
    """Start as large as possible; reduce only for payload limits or timeouts."""
    chunk_seconds = MAX_SECONDS

    def process(chunk):
        nonlocal chunk_seconds
        seconds = len(chunk) / PCM_BYTES_PER_SECOND
        if seconds > chunk_seconds:
            return [text for smaller in pcm_chunks(chunk, chunk_seconds)
                    for text in process(smaller)]
        audio = encode_audio(chunk)
        if len(audio) > MAX_UPSTREAM_AUDIO:
            if seconds <= MIN_CHUNK_SECONDS:
                raise ValueError("Audio chunk exceeds the transcription provider's size limit.")
            # Estimate the largest fitting duration with a little room for
            # changes in compression; every resulting chunk is checked again.
            limit = seconds * MAX_UPSTREAM_AUDIO / len(audio) * 0.95
        else:
            try:
                text = transcribe(audio, language, phrases, key)["text"]
                logging.info("Transcribed %.1f seconds of audio", seconds)
                return [text]
            except urllib.error.HTTPError as exc:
                too_large = exc.code == 413 or (
                    exc.code == 400
                    and b"does not support large audio" in exc.read(8192).lower()
                )
                # OpenRouter also wraps provider failures in 502/503. After
                # the transient retries are exhausted, reduce the chunk rather
                # than failing the entire long recording on the same payload.
                if seconds <= MIN_CHUNK_SECONDS or not (too_large or exc.code in {408, 502, 503, 504}):
                    raise
                reason = f"OpenRouter HTTP {exc.code}"
            except urllib.error.URLError as exc:
                if seconds <= MIN_CHUNK_SECONDS or not isinstance(exc.reason, TimeoutError):
                    raise
                reason = "connection timeout"
            except TimeoutError:
                if seconds <= MIN_CHUNK_SECONDS:
                    raise
                reason = "connection timeout"
            limit = seconds / 2
            logging.info("Reducing %.1f-second audio chunk after %s", seconds, reason)
        chunk_seconds = min(chunk_seconds, max(MIN_CHUNK_SECONDS, limit))
        del audio
        texts = []
        for smaller in pcm_chunks(chunk, chunk_seconds):
            texts.extend(process(smaller))
        return texts

    return {"text": "\n\n".join(text for text in process(pcm) if text.strip())}


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
                    raise OverflowError("Upload exceeds 64 MiB plus multipart framing.")
                chunk = self.rfile.read(size)
                if len(chunk) != size or self.rfile.read(2) != b"\r\n":
                    raise ValueError("Incomplete upload.")
                chunks.append(chunk)
            return b"".join(chunks)
        size = int(self.headers.get("Content-Length", "0"))
        if not 0 < size <= MAX_UPLOAD:
            raise OverflowError("Upload must be between 1 byte and 64 MiB plus multipart framing.")
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
            del body
            phrases = vocabulary(self.server.vault, self.server.terms_file)
            pcm = normalize_audio(audio)
            del audio
            self.respond(200, transcribe_recording(pcm, language, phrases, self.server.api_key))
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
