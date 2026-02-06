# Agent Tee - Development Guide

This document provides guidelines for agents working on the Agent Tee codebase.

## Project Overview

Agent Tee is a Bash script that tees stdout/stderr to per-concern log files. The main script is `t` (~257 lines). No external dependencies required at runtime.

## Build Commands

```bash
make install      # Install to /usr/local/bin (or PREFIX=/custom/path make install)
make uninstall    # Remove installed binary
```

## Test Commands

```bash
make test         # Run --version and --help checks
```

There are no unit tests. To manually test:
```bash
./t --version
./t --help
./t @test echo "hello world"
./t @test latest
```

## Linting

```bash
make lint         # Run shellcheck on t script
```

## Shell Style Guidelines

### Strict Mode
All scripts must start with:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

### Imports/Dependencies
- No imports or requires; bash is pure scripting
- Use `command -v` to check for optional commands before using them
- Prefer POSIX-compliant constructs where possible

### Formatting
- Indent with 4 spaces
- Use `#!/usr/bin/env bash` shebang, not `#!/bin/bash`
- Use heredocs for multi-line output (`cat << 'EOF'`)
- Use `[[ ]]` for tests, not `[ ]`
- Use `[[ -z "$var" ]]` to check if empty, `[[ -n "$var" ]]` if not empty

### Naming Conventions
- Functions: `snake_case` with `cmd_` prefix for CLI commands (e.g., `cmd_latest`, `cmd_copy`)
- Variables: `UPPER_SNAKE_CASE` for constants (e.g., `VERSION`, `LOG_DIR`), `snake_case` for locals
- Constants defined at script top level
- Private/internal functions: leading underscore optional (e.g., `get_last_separator_line`)

### Variable Declarations
```bash
VERSION="0.1.1"
LOG_DIR="${AGENT_TEE_LOG_DIR:-$HOME/.agent-tee/logs}"

local_var() {
    local var_name="$1"
}
```

### Function Structure
```bash
function_name() {
    local arg1="$1"
    local arg2="$2"

    [[ condition ]] && { action; return_code; }

    # Function body
}
```

### Error Handling
- Use `>&2` for all error messages
- Use `return 1` for function failures
- Use `exit 1` for script termination
- Pattern for errors with early return:
```bash
[[ ! -f "$log_file" ]] && { echo "Error: Message" >&2; return 1; }
```

### Exit Codes
- Use `exit 0` for successful termination
- Use `exit 1` for errors
- Capture exit codes from pipes with `${PIPESTATUS[0]:-0}`

### Command Substitution
- Use `$(...)` instead of backticks
- Always quote: `local_var="$(func "$arg")"`

### String Handling
- Use double quotes for variable expansion: `"$var"`
- Use single quotes for literal strings: `'EOF'`
- Use `[[ $var == "value" ]]` for string comparison

### File Operations
- Use `mkdir -p "$LOG_DIR"` for directory creation
- Check file existence before reading: `[[ -f "$file" ]]`

### Arrays/Loops
```bash
for arg in "$@"; do
    [[ "$arg" == @* ]] && { action; }
done
```

### Pattern Matching
- Use `[[ "$var" == pattern ]]` for glob matching
- Use `[[ "$var" =~ regex ]]` for regex
- Use `${var#prefix}` and `${var%suffix}` for string manipulation

## Key Files

- `t` - Main script (runnable, no extension)
- `Makefile` - Build, install, test, lint targets
- `.github/workflows/release.yml` - GitHub Actions release workflow

## Release Process

1. Update `VERSION` in `t` (line 16)
2. Tag commit: `git tag v<x.y.z>`
3. Push: `git push && git push --tags`
4. GitHub Actions builds and releases binary

## Common Tasks

### Adding a New Subcommand
1. Add `cmd_<name>` function
2. Add case handler in `main()` function
3. Update `usage()` function documentation

### Modifying Clipboard Behavior
See `copy_to_clipboard()` function (lines 75-89) for clipboard utility fallback chain.

### Modifying Log Format
Update `cmd_run()` function, specifically the timestamp header and clipboard content formatting.
