#!/bin/bash
# PreToolUse hook for tower_run_local: block runs that need debug mode.
#
# Returns "deny" (not "ask") so the user never sees the 3-option prompt
# and can't accidentally disable the hook via "don't ask again."
#
# The agent sees the denial reason and should set up debug scaffolding.
#
# Decision logic uses .tower/run-log.jsonl (written by PostToolUse/Failure hooks):
#   - No log file → never completed a run → deny, require debug mode
#   - Log exists, no successes → never succeeded → deny, require debug mode
#   - Log exists, last 3 all failed → repeated failures → deny, require investigation
#   - Log exists, has successes → pipeline works → allow silently
#
# Allows silently if code already has debug scaffolding (dev_mode, add_limit).

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="."

# --- Check if pipeline code has debug scaffolding ---

ENTRY_FILE=""
[ -f "$CWD/task.py" ] && ENTRY_FILE="$CWD/task.py"
[ -f "$CWD/pipeline.py" ] && ENTRY_FILE="$CWD/pipeline.py"

[ -z "$ENTRY_FILE" ] && exit 0

HAS_DEBUG=$(grep -cE 'dev_mode|add_limit' "$ENTRY_FILE" 2>/dev/null)
[ -z "$HAS_DEBUG" ] && HAS_DEBUG=0
[ "$HAS_DEBUG" -gt 0 ] && exit 0

# --- Check cross-session run log ---

RUN_LOG="$CWD/.tower/run-log.jsonl"

if [ ! -f "$RUN_LOG" ]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Pipeline has no previous runs and no debug scaffolding (dev_mode, add_limit). Add debug scaffolding first: use /debug-pipeline to add .add_limit(1), dev_mode=True, and verbose logging before running. This catches auth errors and pagination issues early without burning through API quota."
    }
  }'
  exit 0
fi

SUCCESS_COUNT=$(grep -c '"success":true' "$RUN_LOG" 2>/dev/null)
[ -z "$SUCCESS_COUNT" ] && SUCCESS_COUNT=0

if [ "$SUCCESS_COUNT" -eq 0 ]; then
  TOTAL=$(wc -l < "$RUN_LOG" 2>/dev/null | tr -d ' ')
  jq -n --arg n "$TOTAL" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": ("Pipeline has run " + $n + " time(s) but never succeeded, and has no debug scaffolding. Add debug scaffolding first: use /debug-pipeline to add .add_limit(1), dev_mode=True, and verbose logging before retrying.")
    }
  }'
  exit 0
fi

# Has succeeded before — check for recent failure streak
TOTAL=$(wc -l < "$RUN_LOG" 2>/dev/null | tr -d ' ')
[ -z "$TOTAL" ] && TOTAL=0
if [ "$TOTAL" -ge 3 ]; then
  LAST_THREE_FAILURES=$(tail -3 "$RUN_LOG" | grep -c '"success":false' 2>/dev/null)
  [ -z "$LAST_THREE_FAILURES" ] && LAST_THREE_FAILURES=0
  if [ "$LAST_THREE_FAILURES" -ge 3 ]; then
    LAST_ERROR=$(tail -1 "$RUN_LOG" | jq -r '.error // "unknown"' 2>/dev/null)
    jq -n --arg err "$LAST_ERROR" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": ("Last 3 pipeline runs all failed. Most recent error: " + $err + "\nInvestigate the root cause before retrying. Use /debug-pipeline for verbose logging and diagnostics, or check tower_apps_logs for details.")
      }
    }'
    exit 0
  fi
fi

# Pipeline has succeeded before and no failure streak — allow silently
exit 0
