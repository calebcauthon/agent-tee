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

VERSION="0.1.0"
LOG_DIR="${AGENT_TEE_LOG_DIR:-$HOME/.agent-tee/logs}"

usage() {
    cat << 'EOF'
Usage: t <concern> <command> [args...]
       t latest <concern>
       t copy <concern>
       t read <concern>
       t tail <concern>
       t --version
       t --help

Run commands while logging output to per-concern files.

Options:
    -h, --help      Show this help message
    -v, --version   Show version information

Commands:
    <concern> <cmd>   Run command and log to ~/.agent-tee/logs/<concern>.log
    latest <concern>  Show output from the last run
    copy <concern>    Copy last run output to clipboard
    read <concern>    Read entire log file
    tail <concern>    Tail -f the log file

Examples:
    t build npm run build
    t deploy ./deploy.sh production
    t latest build
    t copy build

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
    
    tail -n +"$sep_line" "$log_file" | copy_to_clipboard
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
    
    # Auto-copy to clipboard
    local sep_line
    sep_line=$(get_last_separator_line "$log_file")
    if [[ -n "$sep_line" ]]; then
        local run_content
        run_content=$(tail -n +"$sep_line" "$log_file")
        local line_count
        line_count=$(echo "$run_content" | wc -l | tr -d ' ')
        
        local command_line
        command_line=$(echo "$run_content" | head -1)
        local command
        command=$(echo "$command_line" | sed 's/.*| \(.*\) <<<.*/\1/')
        
        local clipboard_content="---
Ran this command: ${command}
Got this output:
"
        
        if [[ $line_count -le 150 ]]; then
            clipboard_content+=$(echo "$run_content" | tail -n +2)
        else
            local first_10 last_100
            first_10=$(echo "$run_content" | head -10 | tail -n +2)
            last_100=$(echo "$run_content" | tail -100)
            clipboard_content+=$(echo -e "${first_10}\n\n...\n\n${last_100}")
        fi
        
        clipboard_content+="
---"
        
        copy_to_clipboard "$clipboard_content" 2>/dev/null || true
    fi
    
    return $exit_code
}

main() {
    [[ $# -eq 0 ]] && { usage >&2; exit 1; }
    
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -v|--version) version; exit 0 ;;
    esac
    
    case "$1" in
        latest)
            [[ $# -ne 2 ]] && { echo "Usage: t latest <concern>" >&2; exit 1; }
            cmd_latest "$2"
            ;;
        copy)
            [[ $# -ne 2 ]] && { echo "Usage: t copy <concern>" >&2; exit 1; }
            cmd_copy "$2"
            ;;
        read)
            [[ $# -ne 2 ]] && { echo "Usage: t read <concern>" >&2; exit 1; }
            cmd_read "$2"
            ;;
        tail)
            [[ $# -ne 2 ]] && { echo "Usage: t tail <concern>" >&2; exit 1; }
            cmd_tail "$2"
            ;;
        *)
            cmd_run "$@"
            ;;
    esac
}

main "$@"
