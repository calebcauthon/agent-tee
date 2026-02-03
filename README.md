# Agent Tee

Run commands while teeing stdout+stderr to per-concern log files. Like Unix `tee`, but organized and LLM-ready.

## What It Does

Agent Tee sits between you and your terminal:
- **Tees output** to both terminal and log files (`~/.agent-tee/logs/<concern>.log`)
- **Organizes** logs by concern/category
- **Timestamps** every run with clear separators
- **Auto-copies** last run to clipboard in LLM-friendly format
- **Handles buffering** properly (uses `unbuffer`, `stdbuf`, or `script`)

## Installation

### Homebrew

```bash
brew install caleb/tap/agent-tee
```

### Manual

```bash
curl -L https://github.com/caleb/agent-tee/releases/latest/download/t -o /usr/local/bin/t
chmod +x /usr/local/bin/t
```

## Usage

```bash
# Run with logging
t build npm run build
t deploy ./deploy.sh production
t test pytest -v

# View logs
t latest build     # Last run only
t copy build       # Copy to clipboard
t read build       # Entire log
t tail build       # Tail -f
```

## Log Format

Auto-formatted for clipboard:

```
---
Ran this command: npm run build
Got this output:
[output here]
---
```

Large outputs (>150 lines) are truncated: first 10 lines + last 100 lines.

## Why "Agent Tee"?

- **Tee**: Honors the Unix `tee` command
- **Transparent**: Works invisibly
- **Time**: Every run timestamped
- **Tool**: Terminal companion

## License

MIT
