# WhosThere

A lightweight macOS utility that silently captures a photo from your laptop's front camera when you return to your computer after being idle.

## How It Works

WhosThere monitors keyboard and mouse/trackpad activity. When you've been idle for a configurable period (default: 60 seconds) and then interact with your computer again, it automatically captures a photo from the front camera.

## Features

- Monitors all input activity (keyboard, trackpad, external mouse)
- Configurable idle threshold
- Silent background operation
- Saves images with timestamp and idle duration in filename
- Dual storage: local `images/` folder and `/tmp/whosthere/`
- Minimal resource usage (event-driven, not polling)
- Single-file implementation (~250 lines)

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- Camera access permission
- Accessibility access permission (for monitoring keyboard/mouse)

## Building

```bash
swift build -c release
```

The compiled binary will be at `.build/release/WhosThere`

## Running

### Basic Usage

```bash
swift run
```

Or run the compiled binary:

```bash
.build/release/WhosThere
```

### With Custom Idle Threshold

```bash
swift run WhosThere -- --idle-threshold 120
```

This sets the idle threshold to 120 seconds (2 minutes).

## Permissions Setup

On first run, macOS will prompt for permissions:

1. **Camera Access**: Allow when prompted
2. **Accessibility Access**: 
   - Go to System Settings > Privacy & Security > Accessibility
   - Click the lock to make changes
   - Add and enable the WhosThere binary

If you don't grant Accessibility permission, the app will exit with an error message.

## Output

Images are saved to two locations:

1. `./images/capture_YYYYMMDD_HHMMSS_idleXXs.jpg` (persistent)
2. `/tmp/whosthere/capture_YYYYMMDD_HHMMSS_idleXXs.jpg` (temporary)

Example filename: `capture_20231215_143022_idle75s.jpg`
- Captured on Dec 15, 2023 at 2:30:22 PM
- After 75 seconds of idle time

## Running at Startup

To run WhosThere automatically at login, you can:

### Option 1: Login Items (Simple)

1. Build the release binary
2. Go to System Settings > General > Login Items
3. Click "+" and add `.build/release/WhosThere`

### Option 2: launchd (Advanced)

Create `~/Library/LaunchAgents/com.whosthere.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.whosthere</string>
    <key>ProgramArguments</key>
    <array>
        <string>/full/path/to/WhosThere</string>
        <string>--idle-threshold</string>
        <string>60</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/whosthere.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/whosthere.log</string>
</dict>
</plist>
```

Then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.whosthere.plist
```

## Stopping the Application

Press `Ctrl+C` in the terminal, or if running via launchd:

```bash
launchctl unload ~/Library/LaunchAgents/com.whosthere.plist
```

## Configuration

Currently supports command-line argument:
- `--idle-threshold <seconds>`: Set idle threshold (default: 60)

## Future Enhancements

- Cloud storage integration (S3, etc.)
- Web dashboard for viewing captures
- Face detection/recognition
- Configurable image quality/resolution
- Email/notification on capture

## Privacy Note

This application captures photos from your camera and stores them locally. Make sure you understand the privacy implications and comply with local laws regarding surveillance and recording.

