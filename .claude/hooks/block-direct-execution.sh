#!/bin/bash
# PreToolUse hook for Bash: blocks direct execution of pipeline scripts.
# Pipelines MUST run via tower_run_local (MCP), never directly.
#
# Receives JSON on stdin with tool_input.command.
# Returns JSON with permissionDecision: allow|deny.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block direct python execution of pipeline entry points
# Matches: python task.py, python pipeline.py, python main.py
# Also: uv run python task.py, uv run python pipeline.py, etc.
# Does NOT block: uv run python -c "import task" (syntax checks are fine)
# Does NOT block: uv run dlt ... (dlt CLI commands are fine)
if echo "$COMMAND" | grep -qE '(^|&&|\|\||;)\s*(uv run\s+)?python3?\s+(task|pipeline|main)\.py'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Direct pipeline execution is blocked. Use tower_run_local (MCP) instead — it injects Tower secrets and catalog credentials automatically."
    }
  }'
  exit 0
fi

# Allow everything else
exit 0
