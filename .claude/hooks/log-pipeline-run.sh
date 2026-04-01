#!/bin/bash
# PostToolUse hook for tower_run_local: log run outcome for cross-session history.
#
# Writes structured JSONL to .tower/run-log.jsonl with:
#   - timestamp, success/failure, error snippet, duration estimate
#
# This log is read by the suggest-debug-mode PreToolUse hook to detect
# repeated failures and suggest investigation.

INPUT=$(cat)

# Debug logging — remove after confirming hooks work
echo "$(date) | log-pipeline-run fired | tool=$(echo "$INPUT" | jq -r '.tool_name // empty')" >> /tmp/tower-hook-debug.log

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="."

TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')

# Extract outcome from the MCP tool response
# tower_run_local returns an error message on failure or output on success
RESPONSE_TEXT=$(echo "$INPUT" | jq -r '.tool_response | if type == "string" then . elif type == "object" then (.error // .content // .message // (. | tostring)) else (. | tostring) end' 2>/dev/null)

# Determine success: MCP errors start with "Error:" or contain error indicators
SUCCESS=true
ERROR_SNIPPET=""
if echo "$RESPONSE_TEXT" | grep -qiE '^Error:|MCP error|Connection closed|failed|exception|traceback'; then
  SUCCESS=false
  # Capture first 200 chars of error for the log
  ERROR_SNIPPET=$(echo "$RESPONSE_TEXT" | head -5 | cut -c1-200)
fi

# Ensure .tower/ directory exists
mkdir -p "$CWD/.tower" 2>/dev/null

# Write log entry
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --argjson success "$SUCCESS" \
  --arg error "$ERROR_SNIPPET" \
  '{timestamp: $ts, success: $success, error: $error}' \
  >> "$CWD/.tower/run-log.jsonl"

# PostToolUse hooks should always exit 0 (they can't block)
exit 0
