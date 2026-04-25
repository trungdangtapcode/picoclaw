# PicoClaw — My Customized Build

My modified fork of [PicoClaw](https://github.com/sipeed/picoclaw) (v0.2.4) running on Raspberry Pi 5.

## Repo Structure

```
picoclaw/
├── src/                    # Full modified PicoClaw source code (Go)
├── skills/                 # 12 custom skills
├── patches/                # Reference diffs against upstream (optional)
├── config.json             # LLM gateway config (API keys redacted)
├── auth.json               # Auth template (keys redacted)
├── autostart/              # GNOME autostart entry
├── build.sh                # Build from source
└── setup.sh                # Full setup (build + deploy)
```

## Reproduce on a New Machine

```bash
# 1. Clone this repo
git clone https://github.com/trungdangtapcode/picoclaw.git
cd pi5_iot

# 2. One-command setup (builds from source + deploys everything)
bash picoclaw/setup.sh

# 3. Update your API keys
nano ~/.picoclaw/config.json
nano ~/.picoclaw/auth.json

# 4. Run
~/pico_iot/picoclaw ~/.picoclaw/config.json
```

### Prerequisites

- **Go 1.25+** — https://go.dev/dl/
- **pnpm** — `npm install -g pnpm` (only for web launcher build)
- **Linux ARM64** (Raspberry Pi 5) or adjust build target

### Build Options

```bash
bash picoclaw/build.sh                # Build picoclaw binary only
bash picoclaw/build.sh --all          # Build picoclaw + launcher + TUI
bash picoclaw/build.sh --install      # Build all + install to ~/pico_iot/
```

## What I Changed (vs upstream v0.2.4)

12 files modified from [upstream](https://github.com/sipeed/picoclaw) commit `27f638e`:

| Area | Change | Files |
|------|--------|-------|
| **OpenAI routing** | `auth_method: token` was incorrectly routed to Codex/ChatGPT backend; now uses standard OpenAI API | `factory_provider.go`, `factory_test.go` |
| **GPT-5 compat** | Disabled native web search tool injection (unsupported), skip temperature param for GPT-5 | `openai_compat/provider.go`, `provider_test.go` |
| **Vietnamese voice** | Added `language` field to config, Vietnamese-specific transcription prompt | `config.go`, `transcriber.go` |
| **Audio API** | Added dedicated `/audio/transcriptions` endpoint support (multipart upload) | `audio_model_transcriber.go`, `audio_model_transcriber_test.go` |
| **Voice UX** | Better error handling with retry prompts when transcription fails | `loop.go`, `loop_test.go` |
| **Telegram proxy** | Added proxy support for media file downloads | `telegram.go` |

See [`patches/PICOCLAW_GPT5_FIX.md`](patches/PICOCLAW_GPT5_FIX.md) for detailed debugging notes.

## Skills

| Skill | Description |
|-------|-------------|
| `agent-browser` | Browser automation agent |
| `bluetooth-music` | Bluetooth music playback control |
| `control-house` | Home Assistant integration (lights, switches, sensors) |
| `elevenlabs-transcribe` | Voice transcription via ElevenLabs |
| `github` | GitHub repository operations |
| `hardware` | Board pinout & common device references |
| `skill-creator` | Meta-skill for creating new skills |
| `summarize` | Text/conversation summarization |
| `tmux` | Tmux session management |
| `weather` | Weather reporting |

## Runtime Info

- **Base**: PicoClaw v0.2.4 (upstream `27f638e`)
- **Platform**: Linux ARM64 (Raspberry Pi 5)
- **Gateway**: `127.0.0.1:18790`
- **Voice**: Vietnamese (`vi`)
- **Models**: 29 LLM providers configured
