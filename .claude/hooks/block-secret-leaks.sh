#!/bin/bash
# PreToolUse hook for Bash: blocks commands that could leak secrets into conversation context.
#
# Receives JSON on stdin with tool_input.command.
# Returns JSON with permissionDecision: allow|deny.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Patterns that leak secrets to conversation context
if echo "$COMMAND" | grep -qiE '(^|\|)\s*(printenv|env)\s*(\||$)|gh auth token|echo\s+\$[A-Z_]|cat\s+\.env|cat\s+credentials|cat\s+\.dlt/secrets\.toml|cat\s+profiles\.yml'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "This command could leak secrets into the conversation. Use tower_secrets_list (MCP) to inspect secrets safely."
    }
  }'
  exit 0
fi

# Allow everything else
exit 0
