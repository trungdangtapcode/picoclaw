# Bluetooth Music Skill

## Description

This skill connects to a paired Bluetooth audio device (e.g., headphones, speaker) and plays a given audio stream or local music file using `mpv` (or any other player). It abstracts the typical steps:

1. **Scan & pair** – optional, if the device is not yet paired.
2. **Connect** – establish the A2DP connection.
3. **Play** – start playback of the requested track.
4. **Disconnect** – optionally disconnect after playback finishes.

## Prerequisites

- `bluetoothctl` installed (part of the BlueZ stack).
- `mpv` (or another audio player) installed.
- The target Bluetooth device must be paired beforehand (or you can pair it using the skill).

## Commands

### 1. Pair a new device (once)
```bash
bluetoothctl <<EOF
power on
scan on
# wait for device to appear, then note its MAC address (e.g., AA:BB:CC:DD:EE:FF)
pair AA:BB:CC:DD:EE:FF
trust AA:BB:CC:DD:EE:FF
scan off
quit
EOF
```

### 2. Connect to a paired device
```bash
bluetoothctl connect AA:BB:CC:DD:EE:FF
```

### 3. Play a track (local file or URL)
```bash
# Ensure Bluetooth device is connected first
nohup mpv --no-video "<AUDIO_URL_OR_PATH>" > /dev/null 2>&1 &
```

### 4. Disconnect after playback (optional)
```bash
bluetoothctl disconnect AA:BB:CC:DD:EE:FF
```

## Example usage (single command)
```bash
# Connect and play a YouTube audio stream in background
DEVICE="AA:BB:CC:DD:EE:FF"
URL="https://www.youtube.com/watch?v=example"
bluetoothctl connect $DEVICE && nohup mpv --no-video "$URL" > /dev/null 2>&1 &
```

## Automation script (optional)
You can place the following helper script in the same folder as `run.sh`:
```bash
#!/usr/bin/env bash
set -e
DEVICE="$1"
MEDIA="$2"
# Connect
bluetoothctl connect "$DEVICE"
# Play
nohup mpv --no-video "$MEDIA" > /dev/null 2>&1 &
# Optionally wait for playback to finish then disconnect
# wait $(pgrep -f "mpv --no-video $MEDIA")
# bluetoothctl disconnect "$DEVICE"
```
Make it executable with `chmod +x run.sh`.

## How to invoke from PicoClaw
1. Read this `SKILL.md` (using `read_file`).
2. Execute the desired command with `exec` (or run the helper script with `exec`).
3. Adjust `DEVICE` MAC address and media URL/path as needed.

---

**Note**: Running Bluetooth commands may require appropriate permissions (e.g., being in the `bluetooth` group). Ensure the user running the commands has those rights.
