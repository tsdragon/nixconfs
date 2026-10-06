# Sanctuary speech in LibreChat

LibreChat's microphone sends audio to a loopback-only adapter on port 3081.
The adapter converts audio to FLAC and calls
`microsoft/mai-transcribe-2` on OpenRouter with
`provider.options.azure.phraseList.phrases`. There is one transcription model;
no text rewriting model or second inference step is used.
It first tries the whole recording when its compressed size fits the API limit.
If splitting is needed, chunks are transcribed in order with the same Sanctuary
terms and joined into one text attachment. You upload one file.

The adapter exists because LibreChat 0.8.6's STT provider only sends `file`,
`model`, and `language`. Its speech YAML cannot supply MAI's provider options.
OpenRouter's ordinary Whisper-style `prompt` field is ignored, so adding a
prompt to LibreChat would not supply these hints.

## Use

Open LibreChat at `http://localhost:3080`. In **Settings → Speech**, enable
speech to text and select the external/OpenAI engine rather than Browser.
The exact label depends on the client version. This uses your server's
OpenRouter configuration; it does not need a separate OpenAI key.

LibreChat listens only on localhost, and new account registration is disabled.
For access from another device, forward the port through SSH:

```sh
ssh -N -L 127.0.0.1:3080:127.0.0.1:3080 tal@tal-pc
```

Then open `http://localhost:3080` on that device while the tunnel is running.

Click the microphone (or Ctrl+Alt+L), speak, and stop recording. Review the
transcription in the composer before sending. Auto-send is disabled by default;
existing browser preferences may need changing once. Microphone access requires
localhost or HTTPS when accessing LibreChat from another device.

## Vocabulary

Each request rereads filenames, `name`, and `aliases` from notes in `PCs`, `NPCs`,
`Factions`, `Locations`, and `World` under `/home/tal/Documents/sanctuary`.
Draft entities are included because several played NPCs are still marked draft.
Deprecated/superseded notes, brainstorming note types, hidden directories, and
generic index pages are excluded. Names are spelling hints, not canon assertions.
Only extracted terms and recorded audio are sent to OpenRouter, not note bodies.
The request uses up to 50 terms: extra terms are prioritized, then note names
are ranked by their frequency in session notes. This keeps the vocabulary
focused and avoids provider errors observed with larger lists. Session prose
is read locally for ranking and is never sent.

Extra terms live in [terms.txt](terms.txt). Changes to vault names/aliases take
effect on the next recording. Changes to this code or `terms.txt` need a rebuild.
Keyword hints improve recognition; they do not guarantee exact spellings.

## Operations

The NixOS definition is in `../ai.nix`. It reuses the existing SOPS OpenRouter
credential via systemd `LoadCredential`, gives the adapter read-only vault access,
and starts it alongside LibreChat. Audio conversion files are removed after each
request. The adapter does not log audio, transcripts, names, or credentials.
FLAC encoding uses a temporary seekable file so ffmpeg finalizes the duration
metadata. Streaming FLAC directly to a pipe left that metadata empty and caused
MAI provider HTTP 500 errors, including on short clips.
The service has a 1 GiB memory cap to accommodate larger multipart uploads and
30-minute PCM conversion; a full-duration noisy WAV test peaked around 690 MiB.
SOPS restarts LibreChat when its credentials change and also restarts the adapter
when the shared OpenRouter key changes.

Recordings may be up to **30 minutes** and **64 MiB** (with an extra MiB allowed
for multipart framing). Use MP3 or M4A for larger recordings. LibreChat's current
default upload limit is already above this adapter limit.

Chunk sizes adapt to the recording and provider instead of using a fixed duration.
Each FLAC must be at most 18,000,000 bytes, leaving room for base64 and JSON under
OpenRouter's 25 MB inline request cap. Oversized audio is split locally before
sending. Provider large-input rejections and processing timeouts halve the chunk
duration; later chunks use the reduced limit. Splitting stops at 30 seconds and
returns an error if the provider still fails, rather than returning a partial
transcript. OpenRouter's upstream processing timeout is 60 seconds per request,
so there is no single maximum chunk duration that works for every recording.

Cuts prefer the latest 300 ms pause within the final 30 seconds of a chunk.
If there is no pause, they use the quietest window. Every decoded sample is kept
exactly once, without overlapping speech. Cuts also avoid leaving tiny final
fragments with too little speech context. This reduces mid-word cuts, but cannot
guarantee clean boundaries in continuous speech or noisy recordings.

Processing a long recording can take several minutes. Transient OpenRouter
429/502/503 errors get two retries; size and timeout failures use smaller chunks.
If 502/503 persists after those retries, the adapter also reduces the chunk size,
because OpenRouter can wrap provider large-input failures in gateway errors.
The vocabulary is preserved on every attempt. Provider throttling can still
cause a request to fail.

```sh
curl http://127.0.0.1:3081/health
journalctl -u sanctuary-stt -u librechat --since '10 minutes ago'
```

Tests: run `python3 -m unittest -v test_server.py` here with PyYAML installed.
The adapter's `--vocabulary` argument prints the current extracted terms without
loading credentials or making API calls.

If these new files are not yet tracked in Git, use a `path:` flake reference
so Nix includes them when rebuilding:

```sh
sudo nixos-rebuild switch --flake path:/home/tal/.config/nixconfs#tal-pc
```

If the service was updated immediately using the temporary
`30-minute-audio.conf` systemd override, it lasts until reboot. After a successful
rebuild, remove that override so subsequent declarative updates take effect:

```sh
sudo rm -f /run/systemd/system/sanctuary-stt.service.d/30-minute-audio.conf
sudo systemctl daemon-reload
sudo systemctl restart sanctuary-stt.service
```

References: [MAI-Transcribe 2](https://openrouter.ai/microsoft/mai-transcribe-2),
[OpenRouter STT API](https://openrouter.ai/docs/guides/overview/multimodal/stt),
[LibreChat speech configuration](https://www.librechat.ai/docs/configuration/stt_tts).
