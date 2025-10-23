# WhosThere

macOS utility that captures a photo from the front camera when you return after being idle (or someone else touched it).

## Usage

```bash
swift build
swift run
```

Or run the compiled binary:

```bash
swift build -c release
.build/release/WhosThere --idle-threshold 60
```

## Requirements

- macOS 13.0+
- Camera and Accessibility permissions

## Configuration

- `--idle-threshold <seconds>`: Idle duration before capture (default: 60)

## Output

Images saved to:
- `./images/capture_YYYYMMDD_HHMMSS_idleXXs.jpg`
- `/tmp/whosthere/capture_YYYYMMDD_HHMMSS_idleXXs.jpg`

## Run at Startup

Add `.build/release/WhosThere` to System Settings > General > Login Items
