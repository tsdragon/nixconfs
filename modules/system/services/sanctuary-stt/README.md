# Sanctuary speech in LibreChat

LibreChat's microphone sends audio to a loopback-only adapter on port 3081.
The adapter converts audio to FLAC in pieces of up to three minutes and calls
`microsoft/mai-transcribe-2` on OpenRouter with
`provider.options.azure.phraseList.phrases`. There is one transcription model;
no text rewriting model or second inference step is used.
Long recordings are split near quiet points, transcribed in order with the same
Sanctuary terms, and joined into one text attachment. You upload one file.

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
SOPS restarts LibreChat when its credentials change and also restarts the adapter
when the shared OpenRouter key changes.

Recordings are limited to 25 MiB per upload and 25 minutes. Use compressed audio
(such as MP3 or M4A) to stay within the upload limit. Internal chunking avoids
OpenRouter's large-input rejection and reduces the risk of its 60-second
upstream processing timeout. Processing a long recording can take several minutes.
Transient OpenRouter 429/502/503/504 errors get two retries, with the vocabulary
preserved on every attempt. Provider throttling can still cause a request to fail.

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

References: [MAI-Transcribe 2](https://openrouter.ai/microsoft/mai-transcribe-2),
[OpenRouter STT API](https://openrouter.ai/docs/guides/overview/multimodal/stt),
[LibreChat speech configuration](https://www.librechat.ai/docs/configuration/stt_tts).
