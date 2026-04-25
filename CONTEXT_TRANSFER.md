# PicoClaw Project Context Transfer

> Give this file to your AI assistant on the new machine so it has full context.

## Who You Are

- **GitHub**: `trungdangtapcode` / `tcuong1000@gmail.com`
- **Git config**: Always use `-c user.name='trungdangtapcode' -c user.email='tcuong1000@gmail.com'` when committing (this is NOT your machine — the machine belongs to user `mq`)

## The Repo

- **URL**: https://github.com/trungdangtapcode/picoclaw
- **Clone**: `git clone https://github.com/trungdangtapcode/picoclaw.git`
- **Current state**: Pushed and clean as of 2026-04-26

## What Is PicoClaw

PicoClaw is an **open-source personal AI assistant** written in **Go**, by [Sipeed](https://github.com/sipeed/picoclaw). It runs on Raspberry Pi and similar devices. It provides:
- Multi-LLM gateway (OpenAI, Anthropic, DeepSeek, Gemini, Ollama, etc.)
- Skill system (modular capabilities)
- Web launcher UI + TUI
- Hardware access (I2C, SPI, GPIO)
- Voice transcription
- MCP tool support

## What Was Customized (vs upstream v0.2.4, commit `27f638e`)

### 12 Modified Go Source Files

| File | Change |
|------|--------|
| `pkg/providers/factory_provider.go` | Fixed OpenAI `auth_method: token` routing — was incorrectly going to Codex/ChatGPT backend instead of standard OpenAI API. Added `createOpenAITokenProvider()` function. |
| `pkg/providers/factory_test.go` | Updated tests for new token auth routing |
| `pkg/providers/openai_compat/provider.go` | Disabled native web search tool injection (breaks chat/completions). Skips temperature for GPT-5 models. Changed `web_search_preview` → `web_search`. `SupportsNativeSearch()` returns false. |
| `pkg/providers/openai_compat/provider_test.go` | Updated tests for disabled native search |
| `pkg/config/config.go` | Added `Language string` field to `VoiceConfig` struct |
| `pkg/voice/transcriber.go` | Passes `cfg.Voice` (with language) to `NewAudioModelTranscriber` |
| `pkg/voice/audio_model_transcriber.go` | Major changes: added `language`, `apiKey`, `apiBase`, `client` fields. Added `transcribeViaAudioAPI()` for `/audio/transcriptions` endpoint (multipart upload). Vietnamese-specific transcription prompt. |
| `pkg/voice/audio_model_transcriber_test.go` | Added test for audio API transcription path |
| `pkg/agent/loop.go` | Improved voice transcription: new `audioTranscriptionStatus` struct, `sendVoiceRetryPrompt()`, better error handling when transcription fails |
| `pkg/agent/loop_test.go` | Updated tests for new transcription status |
| `pkg/channels/telegram/telegram.go` | Added `ProxyURL` to Telegram file download options |
| `.gitignore` | Added `node_modules/` |

### 12 Custom Skills (in `skills/`)

- `agent-browser` — Browser automation
- `bluetooth-music` — Bluetooth music control
- `control-house` — Home Assistant integration (with shell scripts for HA API)
- `elevenlabs-transcribe` — Voice transcription
- `github` — GitHub operations
- `hardware` — Board pinout & device references for Pi 5
- `skill-creator` — Meta-skill for creating new skills
- `summarize` — Text summarization
- `tmux` — Tmux session management
- `weather` — Weather reporting

### Config

- `config.json` — 29 LLM model providers configured (all API keys replaced with `YOUR_API_KEY_HERE`)
- `auth.json` — Auth template (OpenAI key replaced with `YOUR_OPENAI_API_KEY_HERE`)
- Voice language set to Vietnamese (`vi`)
- Gateway on `127.0.0.1:18790`

### Security Redactions Already Done

1. All API keys in `config.json` → `YOUR_API_KEY_HERE`
2. OpenAI token in `auth.json` → `YOUR_OPENAI_API_KEY_HERE`
3. Google OAuth client ID/secret in `src/pkg/auth/oauth.go` → `REDACTED_*_BASE64`
4. All `ANTIGRAVITY_AUTH.md` docs deleted (contained Google OAuth in plaintext)
5. Hardcoded `/home/mq` path → `~/.picoclaw/workspace`

## Repo Structure

```
picoclaw/
├── README.md                # How to reproduce on any machine
├── CONTEXT_TRANSFER.md      # This file
├── .gitignore               # Excludes build artifacts, node_modules
├── build.sh                 # Build from source (bash build.sh --install)
├── setup.sh                 # Full setup: build + deploy skills/config
├── config.json              # LLM config template (keys redacted)
├── auth.json                # Auth template (keys redacted)
├── autostart/
│   └── picoclaw-web.desktop # GNOME autostart for picoclaw-launcher
├── patches/                 # Reference only
│   ├── picoclaw-custom-fixes.patch  # 994-line unified diff vs upstream
│   └── PICOCLAW_GPT5_FIX.md        # Debugging notes
├── skills/                  # 12 custom skills
│   ├── agent-browser/
│   ├── bluetooth-music/
│   ├── control-house/
│   ├── elevenlabs-transcribe/
│   ├── github/
│   ├── hardware/
│   ├── skill-creator/
│   ├── summarize/
│   ├── tmux/
│   └── weather/
└── src/                     # Full modified PicoClaw Go source
    ├── Makefile
    ├── go.mod / go.sum
    ├── cmd/                 # Entry points (picoclaw, launcher, TUI)
    ├── pkg/                 # Core packages (MODIFIED FILES ARE HERE)
    ├── web/                 # Web launcher (React frontend + Go backend)
    ├── config/
    ├── docker/
    ├── docs/
    ├── examples/
    ├── scripts/
    └── workspace/           # Default workspace templates
```

## How to Set Up on New Machine

```bash
# 1. Clone
git clone https://github.com/trungdangtapcode/picoclaw.git
cd picoclaw

# 2. Install prerequisites
#    - Go 1.25+ (https://go.dev/dl/)
#    - pnpm (npm install -g pnpm) — only for web launcher
#    - gh CLI (optional, for GitHub operations)

# 3. Full setup (builds from source + deploys)
bash setup.sh

# 4. Add your API keys
nano ~/.picoclaw/config.json
nano ~/.picoclaw/auth.json

# 5. Run
~/pico_iot/picoclaw ~/.picoclaw/config.json
# Or web UI:
~/pico_iot/picoclaw-launcher -no-browser ~/.picoclaw/config.json
```

## The Original Machine (where this was created)

- **Machine**: Raspberry Pi 5 (`MQ-Pi`), Linux ARM64, Debian Trixie
- **User**: `mq` (NOT your account — this is someone else's machine)
- **PicoClaw locations on that machine**:
  - Running binary: `/home/mq/pico_iot/picoclaw`
  - Launcher: `/home/mq/pico_iot/picoclaw-launcher`
  - Live config: `/home/mq/.picoclaw/config.json` (has REAL API keys)
  - Live skills: `/home/mq/.picoclaw/workspace/skills/`
  - Original source: `/home/mq/pico_iot/picoclaw-src/`
  - Upstream git backup: `/home/mq/archive/picoclaw-src.git.backup/`
- **DO NOT** commit to the `pi5_iot` repo at `/home/mq/.git` — that belongs to `thanthanh113366`

## What Still Needs Doing

- [ ] Set up environment variables / API keys on the new machine
- [ ] Test `setup.sh` works end-to-end on a fresh machine
- [ ] Consider adding the repo as a proper fork of `sipeed/picoclaw` for easier upstream merging
- [ ] The `setup.sh` currently doesn't handle Go/pnpm installation — could add that
