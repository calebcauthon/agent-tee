#!/usr/bin/env bash
#
# Agent Tee - Run commands while teeing stdout+stderr to per-concern log files
# https://github.com/calebcauthon/agent-tee
#
# Usage: t <concern> <command> [args...]
#        t latest <concern>
#        t copy <concern>
#        t read <concern>
#        t tail <concern>
#
# Logs go to ~/.agent-tee/logs/<concern>.log

set -euo pipefail

VERSION="0.1.1"
LOG_DIR="${AGENT_TEE_LOG_DIR:-$HOME/.agent-tee/logs}"
CONFIG_FILE="${AGENT_TEE_CONFIG:-$HOME/.agent-tee/config}"
DEFAULT_TEMPLATE='---
Ran: {{command}}
Duration: {{duration}}ms
Output:
{{output}}
---'

usage() {
    cat << 'EOF'
Usage: t [@concern] <command> [args...]
       t [@concern] latest
       t [@concern] copy
       t [@concern] read
       t [@concern] tail
       t --version
       t --help

Run commands while logging output to per-concern files.
Concern is specified with @ prefix. If omitted, "default" is used.

Options:
    -h, --help      Show this help message
    -v, --version   Show version information

Commands:
    [@concern] <cmd>   Run command and log to ~/.agent-tee/logs/<concern>.log
    [@concern] latest  Show output from the last run
    [@concern] copy    Copy last run output to clipboard
    [@concern] read    Read entire log file
    [@concern] tail    Tail -f the log file

Examples:
    t echo 'hello'                   # Run with default concern
    t @build npm run build           # Run with "build" concern
    t @deploy ./deploy.sh prod       # Run with "deploy" concern
    t latest                         # Show latest for default concern
    t @build latest                  # Show latest for "build" concern
    t copy                           # Copy default concern to clipboard
    t @deploy copy                   # Copy "deploy" concern to clipboard

Environment:
    AGENT_TEE_LOG_DIR   Override default log directory
                        (default: ~/.agent-tee/logs)
EOF
}

version() {
    echo "Agent Tee v${VERSION}"
}

get_last_separator_line() {
    local log_file="$1"
    grep -an '^>>> AGENT_TEE_RUN_START:' "$log_file" 2>/dev/null | tail -1 | cut -d: -f1
}

get_last_run() {
    local log_file="$1"
    local sep_line
    sep_line=$(get_last_separator_line "$log_file")
    [[ -z "$sep_line" ]] && return 1
    tail -n +"$sep_line" "$log_file"
}

copy_to_clipboard() {
    local content="$1"
    if command -v pbcopy &>/dev/null; then
        echo "$content" | pbcopy
    elif command -v xclip &>/dev/null; then
        echo "$content" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        echo "$content" | xsel --clipboard --input
    elif command -v wl-copy &>/dev/null; then
        echo "$content" | wl-copy
    else
        echo "Warning: No clipboard utility found" >&2
        return 1
    fi
}

load_clipboard_template() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    echo "${CLIPBOARD_TEMPLATE:-$DEFAULT_TEMPLATE}"
}

process_template() {
    local template="$1" command="$2" output="$3" duration="$4"
    local timestamp="$5" concern="$6" exit_code="$7"

    template="${template//\{\{command\}\}/$command}"
    template="${template//\{\{output\}\}/$output}"
    template="${template//\{\{duration\}\}/$duration}"
    template="${template//\{\{timestamp\}\}/$timestamp}"
    template="${template//\{\{concern\}\}/$concern}"
    template="${template//\{\{exit_code\}\}/$exit_code}"
    echo "$template"
}

format_clipboard_content() {
    local run_content="$1"
    shift
    local concern="$1"
    shift
    local extra_args="$@"

    local template
    template=$(load_clipboard_template)

    local command_line
    command_line=$(echo "$run_content" | head -1)
    local command
    command=$(echo "$command_line" | sed 's/.*| \(.*\) <<<.*/\1/')

    local line_count
    line_count=$(echo "$run_content" | wc -l | tr -d ' ')

    local output
    if [[ $line_count -le 150 ]]; then
        output=$(echo "$run_content" | tail -n +2)
    else
        local first_10 last_100
        first_10=$(echo "$run_content" | head -10 | tail -n +2)
        last_100=$(echo "$run_content" | tail -100)
        output=$(echo -e "${first_10}\n\n...\n\n${last_100}")
    fi

    local timestamp exit_code duration
    timestamp=$(echo "$command_line" | sed 's/.*>>> AGENT_TEE_RUN_START: \(.*\) |.*/\1/')
    exit_code="${AGENT_TEE_EXIT_CODE:-0}"
    duration="${AGENT_TEE_DURATION:-0}"

    process_template "$template" "$command" "$output" "$duration" "$timestamp" "$concern" "$exit_code"
}

cmd_latest() {
    local concern="$1"
    local log_file="${LOG_DIR}/${concern}.log"
    
    [[ ! -f "$log_file" ]] && { echo "Error: No log file found for: $concern" >&2; return 1; }
    
    local sep_line
    sep_line=$(get_last_separator_line "$log_file")
    [[ -z "$sep_line" ]] && { echo "Error: No runs found in log" >&2; return 1; }
    
    tail -n +"$sep_line" "$log_file"
}

cmd_copy() {
    local concern="$1"
    local log_file="${LOG_DIR}/${concern}.log"

    [[ ! -f "$log_file" ]] && { echo "Error: No log file found for: $concern" >&2; return 1; }

    local sep_line
    sep_line=$(get_last_separator_line "$log_file")
    [[ -z "$sep_line" ]] && { echo "Error: No runs found in log" >&2; return 1; }

    local run_content
    run_content=$(tail -n +"$sep_line" "$log_file")

    local clipboard_content
    clipboard_content=$(format_clipboard_content "$run_content" "$concern")

    copy_to_clipboard "$clipboard_content"
    echo "Copied last run for '$concern' to clipboard"
}

cmd_read() {
    local concern="$1"
    local log_file="${LOG_DIR}/${concern}.log"
    
    [[ ! -f "$log_file" ]] && { echo "Error: No log file found for: $concern" >&2; return 1; }
    
    cat "$log_file"
}

cmd_tail() {
    local concern="$1"
    local log_file="${LOG_DIR}/${concern}.log"
    
    [[ ! -f "$log_file" ]] && { echo "Error: No log file found for: $concern" >&2; return 1; }
    
    tail -f "$log_file"
}

cmd_run() {
    local concern="$1"
    shift

    [[ $# -eq 0 ]] && { echo "Error: No command specified" >&2; usage >&2; return 1; }

    local log_file="${LOG_DIR}/${concern}.log"
    local start_time
    start_time=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null) || \
    start_time=$(date -u +%s%3N 2>/dev/null) || \
    start_time=$(gdate -u +%s%3N 2>/dev/null)

    mkdir -p "$LOG_DIR"

    # Timestamp header
    echo -e "\n>>> AGENT_TEE_RUN_START: $(date '+%Y-%m-%d %H:%M:%S') | $* <<<" >> "$log_file"

    # Run with proper buffering
    local exit_code=0
    if command -v unbuffer &>/dev/null; then
        unbuffer "$@" 2>&1 | tee -a "$log_file" || true
        exit_code=${PIPESTATUS[0]:-0}
    elif command -v stdbuf &>/dev/null; then
        stdbuf -oL -eL "$@" 2>&1 | tee -a "$log_file" || true
        exit_code=${PIPESTATUS[0]:-0}
    else
        script -q /dev/null "$@" 2>&1 | sed -l $'s/\\^D\x08\x08//g' | tee -a "$log_file" || true
        exit_code=${PIPESTATUS[0]:-0}
    fi

    # Calculate duration
    local end_time duration
    end_time=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null) || \
    end_time=$(date -u +%s%3N 2>/dev/null) || \
    end_time=$(gdate -u +%s%3N 2>/dev/null)
    duration=$(( end_time - start_time ))

    # Auto-copy to clipboard using template
    local sep_line
    sep_line=$(get_last_separator_line "$log_file")
    if [[ -n "$sep_line" ]]; then
        local run_content
        run_content=$(tail -n +"$sep_line" "$log_file")

        export AGENT_TEE_DURATION="$duration"
        export AGENT_TEE_EXIT_CODE="${exit_code:-0}"

        local clipboard_content
        clipboard_content=$(format_clipboard_content "$run_content" "$concern")

        copy_to_clipboard "$clipboard_content" 2>/dev/null || true
    fi

    return ${exit_code:-0}
}

main() {
    [[ $# -eq 0 ]] && { usage >&2; exit 1; }
    
    # Handle options first
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -v|--version) version; exit 0 ;;
    esac
    
    # Parse concern (must be first if provided)
    local concern="default"
    if [[ "$1" == @* ]]; then
        concern="${1#@}"  # Remove @ prefix
        shift
        [[ -z "$concern" ]] && { echo "Error: Empty concern after @" >&2; exit 1; }
    fi
    
    # Check for double @ symbols (invalid)
    for arg in "$@"; do
        if [[ "$arg" == @* ]]; then
            echo "Error: Cannot specify concern more than once (found: $arg)" >&2
            exit 1
        fi
    done
    
    # No args after concern? Error.
    [[ $# -eq 0 ]] && { echo "Error: No command specified" >&2; exit 1; }
    
    # Check if next arg is a subcommand
    case "$1" in
        latest)
            shift
            [[ $# -gt 0 ]] && { echo "Error: Too many arguments after 'latest'" >&2; exit 1; }
            cmd_latest "$concern"
            ;;
        copy)
            shift
            [[ $# -gt 0 ]] && { echo "Error: Too many arguments after 'copy'" >&2; exit 1; }
            cmd_copy "$concern"
            ;;
        read)
            shift
            [[ $# -gt 0 ]] && { echo "Error: Too many arguments after 'read'" >&2; exit 1; }
            cmd_read "$concern"
            ;;
        tail)
            shift
            [[ $# -gt 0 ]] && { echo "Error: Too many arguments after 'tail'" >&2; exit 1; }
            cmd_tail "$concern"
            ;;
        *)
            # Run command with the specified concern
            cmd_run "$concern" "$@"
            ;;
    esac
}

main "$@"
