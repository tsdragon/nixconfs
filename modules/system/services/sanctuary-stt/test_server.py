import array
import io
import json
import shutil
import subprocess
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

import server


class SpeechTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "ffmpeg/ffprobe required")
    def test_flac_has_finalized_duration_and_preserves_samples(self):
        pcm = b"\x00\x10\x00\xf0" * 8000
        audio = server.encode_audio(pcm)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "audio.flac"
            output.write_bytes(audio)
            metadata = subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(output)],
                check=True, capture_output=True, timeout=10,
            )
            self.assertEqual(float(json.loads(metadata.stdout)["format"]["duration"]), 1.0)
            decoded = subprocess.run(
                ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-i", str(output),
                 "-f", "s16le", "pipe:1"], check=True, capture_output=True, timeout=10,
            ).stdout
            self.assertEqual(decoded, pcm)

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
        with patch.object(server, "MAX_FILE_BYTES", 4):
            with self.assertRaises(OverflowError):
                server.parse_upload("multipart/form-data; boundary=test", body)
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
            with self.assertRaisesRegex(ValueError, "30 minutes"):
                server.normalize_audio(b"audio")

    def test_exactly_30_minutes_is_accepted(self):
        def convert(command, **kwargs):
            output = Path(command[-1])
            if output.suffix == ".pcm":
                with output.open("wb") as out:
                    out.truncate(30 * 60 * 16000 * 2)
        with patch("subprocess.run", side_effect=convert):
            self.assertEqual(len(server.normalize_audio(b"audio")), 30 * 60 * 16000 * 2)

    def test_chunks_preserve_every_sample_and_prefer_quiet_boundaries(self):
        size = 10 * 60 * server.PCM_BYTES_PER_SECOND
        pcm = bytearray(b"\x00\x10" * (size + 16000))
        # Two pauses: choose the later one to keep the chunk large.
        earlier = size - 20 * server.PCM_BYTES_PER_SECOND
        pcm[earlier:earlier + 16000] = bytes(16000)
        quiet = size - server.PCM_BYTES_PER_SECOND
        pcm[quiet:quiet + 16000] = bytes(16000)
        chunks = list(server.pcm_chunks(bytes(pcm), 10 * 60))
        self.assertEqual(b"".join(chunks), pcm)
        self.assertTrue(quiet <= len(chunks[0]) <= quiet + 16000)
        self.assertTrue(all(len(chunk) <= size for chunk in chunks))

    def test_continuous_speech_chunks_preserve_samples(self):
        pcm = b"\x00\x10" * (40 * 16000)
        chunks = list(server.pcm_chunks(pcm, 30))
        self.assertEqual(b"".join(chunks), pcm)
        self.assertTrue(all(len(chunk) % 2 == 0 for chunk in chunks))
        self.assertTrue(all(len(chunk) <= 30 * server.PCM_BYTES_PER_SECOND for chunk in chunks))

    def test_split_does_not_leave_tiny_final_fragment(self):
        pcm = bytes(61 * server.PCM_BYTES_PER_SECOND)
        chunks = list(server.pcm_chunks(pcm, 60))
        self.assertEqual(b"".join(chunks), pcm)
        self.assertTrue(all(30 * server.PCM_BYTES_PER_SECOND <= len(chunk)
                            <= 60 * server.PCM_BYTES_PER_SECOND for chunk in chunks))

    def test_whole_recording_sent_when_it_fits(self):
        pcm = bytes(30 * 60 * server.PCM_BYTES_PER_SECOND)
        with patch.object(server, "encode_audio", return_value=b"fLaC") as encode, \
                patch.object(server, "transcribe", return_value={"text": "Complete transcript"}) as send:
            self.assertEqual(server.transcribe_recording(pcm, "en", ["Ryn"], "key"),
                             {"text": "Complete transcript"})
        encode.assert_called_once_with(pcm)
        send.assert_called_once_with(b"fLaC", "en", ["Ryn"], "key")

    def test_payload_limit_splits_before_sending_and_keeps_sample_order(self):
        pcm = array.array("h", range(16000)).tobytes() * 120
        sent = []
        def send(audio, language, phrases, key):
            self.assertLessEqual(len(audio), 2_000_000)
            sent.append(audio)
            return {"text": str(len(sent))}
        with patch.object(server, "encode_audio", side_effect=lambda chunk: chunk), \
                patch.object(server, "MAX_UPSTREAM_AUDIO", 2_000_000), \
                patch.object(server, "transcribe", side_effect=send):
            result = server.transcribe_recording(pcm, "en", ["Ryn"], "key")
        self.assertEqual(b"".join(sent), pcm)
        self.assertEqual(result, {"text": "1\n\n2\n\n3"})

    def test_provider_limits_split_and_preserve_vocabulary(self):
        for failure in [
            urllib.error.HTTPError(server.UPSTREAM, 400, "Bad Request", {},
                                   io.BytesIO(b'{"error":"The selected model does not support large audio inputs"}')),
            urllib.error.HTTPError(server.UPSTREAM, 413, "Too large", {}, None),
            urllib.error.HTTPError(server.UPSTREAM, 504, "Timeout", {}, None),
            TimeoutError(),
            urllib.error.URLError(TimeoutError()),
        ]:
            with self.subTest(failure=type(failure).__name__, code=getattr(failure, "code", None)):
                pcm = bytes(120 * server.PCM_BYTES_PER_SECOND)
                sent = []
                def send(audio, language, phrases, key):
                    self.assertEqual((language, phrases, key), ("en", ["Ryn"], "key"))
                    if not sent:
                        sent.append(None)
                        raise failure
                    sent.append(audio)
                    return {"text": str(len(sent) - 1)}
                with patch.object(server, "encode_audio", side_effect=lambda chunk: chunk), \
                        patch.object(server, "transcribe", side_effect=send):
                    result = server.transcribe_recording(pcm, "en", ["Ryn"], "key")
                self.assertEqual(b"".join(sent[1:]), pcm)
                self.assertEqual(result, {"text": "1\n\n2\n\n3"})

    def test_unrelated_provider_error_does_not_split(self):
        error = urllib.error.HTTPError(server.UPSTREAM, 400, "Bad phrase list", {},
                                      io.BytesIO(b'{"error":"Invalid vocabulary"}'))
        with patch.object(server, "encode_audio", return_value=b"fLaC"), \
                patch.object(server, "transcribe", side_effect=error) as send:
            with self.assertRaises(urllib.error.HTTPError):
                server.transcribe_recording(bytes(120 * server.PCM_BYTES_PER_SECOND), "en", [], "key")
        send.assert_called_once()

    def test_exhausted_gateway_retries_reduce_chunks_and_keep_hints(self):
        for status in (502, 503):
            with self.subTest(status=status):
                failures = [urllib.error.HTTPError(server.UPSTREAM, status, "Provider error", {},
                                                   io.BytesIO(b'{"error":{"message":"Provider returned error"}}'))
                            for _ in range(3)]
                replies = failures + [io.BytesIO(json.dumps({"text": str(i)}).encode())
                                      for i in range(1, 4)]
                pcm = bytes(120 * server.PCM_BYTES_PER_SECOND)
                with patch.object(server, "encode_audio", side_effect=lambda chunk: chunk), \
                        patch("urllib.request.urlopen", side_effect=replies) as send, \
                        patch("time.sleep"):
                    result = server.transcribe_recording(pcm, "en", ["Ryn"], "key")
                self.assertEqual(result, {"text": "1\n\n2\n\n3"})
                self.assertEqual(send.call_count, 6)
                for call in send.call_args_list:
                    payload = json.loads(call.args[0].data)
                    self.assertEqual(payload["language"], "en")
                    self.assertEqual(payload["provider"]["options"]["azure"]["phraseList"]["phrases"], ["Ryn"])

    def test_repeated_gateway_errors_stop_at_minimum_chunk_duration(self):
        def fail(*args, **kwargs):
            raise urllib.error.HTTPError(server.UPSTREAM, 502, "Provider error", {}, io.BytesIO(b'{}'))
        pcm = bytes(120 * server.PCM_BYTES_PER_SECOND)
        with patch.object(server, "encode_audio", return_value=b"fLaC"), \
                patch("urllib.request.urlopen", side_effect=fail) as send, patch("time.sleep"):
            with self.assertRaises(urllib.error.HTTPError):
                server.transcribe_recording(pcm, "en", [], "key")
        self.assertLessEqual(send.call_count, 9)

    def test_repeated_timeouts_stop_at_minimum_chunk_duration(self):
        pcm = bytes(120 * server.PCM_BYTES_PER_SECOND)
        with patch.object(server, "encode_audio", return_value=b"fLaC"), \
                patch.object(server, "transcribe", side_effect=TimeoutError()) as send:
            with self.assertRaises(TimeoutError):
                server.transcribe_recording(pcm, "en", [], "key")
        self.assertLessEqual(send.call_count, 3)


if __name__ == "__main__":
    unittest.main()
