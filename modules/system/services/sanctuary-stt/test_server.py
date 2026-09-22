import io
import json
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

import server


class SpeechTests(unittest.TestCase):
    def test_librechat_chunked_upload_and_size_limit(self):
        handler = object.__new__(server.Handler)
        handler.headers = {"Transfer-Encoding": "chunked"}
        handler.rfile = io.BytesIO(b"3\r\nabc\r\n2\r\nde\r\n0\r\n\r\n")
        self.assertEqual(handler.read_upload(), b"abcde")
        handler.rfile = io.BytesIO(b"3\r\nabc\r\n2\r\nde\r\n0\r\n\r\n")
        with patch.object(server, "MAX_UPLOAD", 4):
            with self.assertRaises(OverflowError):
                handler.read_upload()

    def test_live_vocabulary_excludes_private_and_retired_notes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "NPCs").mkdir()
            terms = root / "terms.txt"
            terms.write_text("# comment\nSanctuary\n")
            note = root / "NPCs" / "Leshy.md"
            note.write_text("---\ntype: npc\nname: Leshy\naliases: [Leshii]\n---\nSecret plot")
            (root / "NPCs" / "old.md").write_text(
                "---\ntype: npc\nname: OldName\ncanon_status: deprecated\n---\n")
            (root / "NPCs" / ".hidden.md").write_text("---\ntype: npc\nname: Hidden\n---\n")
            self.assertCountEqual(server.vocabulary(root, terms), ["Sanctuary", "Leshy", "Leshii"])
            note.write_text("---\ntype: npc\nname: Ryn\n---\n")
            note.rename(root / "NPCs" / "Ryn.md")
            self.assertEqual(server.vocabulary(root, terms), ["Sanctuary", "Ryn"])

    def test_vocabulary_cap_prioritizes_extra_terms_and_played_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "NPCs").mkdir()
            (root / "Sessions").mkdir()
            (root / "Sessions" / "Session 20.md").write_text("Ryn visited Mirovel. Ryn returned.")
            terms = root / "terms.txt"
            terms.write_text("Sanctuary\n")
            for name in ["Unused", "Ryn", "Mirovel"]:
                (root / "NPCs" / f"{name}.md").write_text(f"---\ntype: npc\nname: {name}\n---\n")
            with patch.object(server, "MAX_PHRASES", 3):
                self.assertEqual(server.vocabulary(root, terms), ["Sanctuary", "Ryn", "Mirovel"])

    def test_librechat_multipart(self):
        body = (b'--test\r\nContent-Disposition: form-data; name="file"; filename="audio.webm"'
                b'\r\nContent-Type: audio/webm\r\n\r\n\x00\xffaudio\r\n'
                b'--test\r\nContent-Disposition: form-data; name="language"\r\n\r\nen-US'
                b'\r\n--test--\r\n')
        self.assertEqual(server.parse_upload("multipart/form-data; boundary=test", body),
                         (b"\x00\xffaudio", "en"))
        with self.assertRaises(ValueError):
            server.parse_upload("application/json", b"{}")

    def test_native_keywords_and_transient_retry(self):
        replies = [urllib.error.HTTPError(server.UPSTREAM, 429, "Provider returned 429", {}, None),
                   io.BytesIO(b'{"text":"Ryn visits Mirovel."}')]
        with patch("urllib.request.urlopen", side_effect=replies) as send, patch("time.sleep"):
            self.assertEqual(server.transcribe(b"fLaC", "en", ["Ryn", "Mirovel"], "key"),
                             {"text": "Ryn visits Mirovel."})
        self.assertEqual(send.call_count, 2)
        for call in send.call_args_list:
            request = call.args[0]
            self.assertEqual(request.full_url, server.UPSTREAM)
            payload = json.loads(request.data)
            self.assertEqual(payload["model"], server.MODEL)
            self.assertEqual(payload["provider"]["options"]["azure"]["phraseList"]["phrases"],
                             ["Ryn", "Mirovel"])
            self.assertEqual(payload["input_audio"]["format"], "flac")
            self.assertNotIn("prompt", payload)

    def test_non_transient_error_is_not_retried(self):
        error = urllib.error.HTTPError(server.UPSTREAM, 401, "Unauthorized", {}, None)
        with patch("urllib.request.urlopen", side_effect=error) as send:
            with self.assertRaises(urllib.error.HTTPError):
                server.transcribe(b"fLaC", "en", ["Ryn"], "key")
        self.assertEqual(send.call_count, 1)

    def test_overlong_audio_is_rejected(self):
        def decode(command, **kwargs):
            with open(command[-1], "wb") as out:
                out.truncate((server.MAX_SECONDS + 1) * 16000 * 2)
        with patch("subprocess.run", side_effect=decode):
            with self.assertRaisesRegex(ValueError, "25 minutes"):
                server.normalize_audio(b"audio")

    def test_exactly_25_minutes_is_accepted(self):
        def convert(command, **kwargs):
            output = Path(command[-1])
            if output.suffix == ".pcm":
                with output.open("wb") as out:
                    out.truncate(25 * 60 * 16000 * 2)
            else:
                output.write_bytes(b"fLaC")
        with patch("subprocess.run", side_effect=convert):
            self.assertEqual(server.normalize_audio(b"audio"), [b"fLaC"] * 9)

    def test_chunks_preserve_every_sample_and_prefer_quiet_boundaries(self):
        size = server.CHUNK_SECONDS * server.PCM_BYTES_PER_SECOND
        pcm = bytearray(b"\x00\x10" * (size + 16000))
        # Quiet interval just before the three-minute boundary.
        quiet = size - server.PCM_BYTES_PER_SECOND
        pcm[quiet:quiet + 6400] = bytes(6400)
        chunks = list(server.pcm_chunks(bytes(pcm)))
        self.assertEqual(b"".join(chunks), pcm)
        self.assertTrue(quiet <= len(chunks[0]) <= quiet + 6400)
        self.assertTrue(all(len(chunk) <= size for chunk in chunks))


if __name__ == "__main__":
    unittest.main()
