#!/bin/bash
# PreToolUse hook for Edit and Write: blocks file changes unless BA + Architect
# reviews exist with gate_result: APPROVE (or OVERRIDE) and are not stale.
#
# Exempt paths: .tower/*, .claude/*, .agents/*, .gitignore
# If no Towerfile exists: deny (app not initialized).
# Otherwise: require both review artifacts for the app.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && CWD="."

# --- Exempt paths: review artifacts, config, skills ---

if echo "$FILE_PATH" | grep -qE '/(\.tower|\.claude|\.agents)/'; then
  exit 0
fi
if [ "$(basename "$FILE_PATH")" = ".gitignore" ]; then
  exit 0
fi

# --- Require Towerfile (app must be initialized) ---

TOWERFILE="$CWD/Towerfile"
if [ ! -f "$TOWERFILE" ]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Edit blocked: no Towerfile found. Initialize the app with /init-tower-app first, but only AFTER running /plan-business-analyst-review and /plan-data-architect-review to produce approved review artifacts."
    }
  }'
  exit 0
fi

# --- Extract app name from Towerfile ---

APP_NAME=$(grep -E '^name\s*=' "$TOWERFILE" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
if [ -z "$APP_NAME" ]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Edit blocked: could not parse app name from Towerfile."
    }
  }'
  exit 0
fi

REVIEWS_DIR="$CWD/.tower/reviews"

# --- Helper: check a review artifact ---
# Args: $1=glob pattern, $2=review label, $3=skill command
# Sets: CHECK_RESULT ("ok" or error message), CHECK_DETAIL (status line for checklist)
check_review() {
  local pattern="$1"
  local label="$2"
  local skill="$3"

  # Find most recent matching artifact
  local artifact
  artifact=$(ls -t $pattern 2>/dev/null | head -1)

  if [ -z "$artifact" ]; then
    CHECK_RESULT="missing"
    CHECK_DETAIL="- [ ] $label (not found -- run $skill)"
    return
  fi

  # Extract gate_result from frontmatter
  local gate
  gate=$(grep -m1 '^gate_result:' "$artifact" | awk '{print $2}')

  if [ "$gate" != "APPROVE" ] && [ "$gate" != "OVERRIDE" ]; then
    CHECK_RESULT="blocked"
    CHECK_DETAIL="- [ ] $label (gate: ${gate:-UNKNOWN} -- resolve blocking issues or re-run $skill)"
    return
  fi

  # Check staleness via commit hash
  local commit
  commit=$(grep -m1 '^commit:' "$artifact" | awk '{print $2}')

  if [ -n "$commit" ]; then
    local distance
    distance=$(git -C "$CWD" rev-list --count "$commit..HEAD" 2>/dev/null)
    if [ -n "$distance" ] && [ "$distance" -gt 5 ]; then
      CHECK_RESULT="stale"
      CHECK_DETAIL="- [ ] $label (stale: $distance commits behind HEAD -- re-run $skill)"
      return
    fi
  fi

  CHECK_RESULT="ok"
  CHECK_DETAIL="- [x] $label (APPROVE, commit: ${commit:-unknown})"
}

# --- Check both required reviews ---

check_review "$REVIEWS_DIR/ba-review-${APP_NAME}*.md" "BA review" "/plan-business-analyst-review"
BA_RESULT="$CHECK_RESULT"
BA_DETAIL="$CHECK_DETAIL"

check_review "$REVIEWS_DIR/architect-review-${APP_NAME}*.md" "Architect review" "/plan-data-architect-review"
ARCH_RESULT="$CHECK_RESULT"
ARCH_DETAIL="$CHECK_DETAIL"

# --- Gate decision ---

if [ "$BA_RESULT" = "ok" ] && [ "$ARCH_RESULT" = "ok" ]; then
  exit 0
fi

REASON=$(cat <<EOF
Edit blocked: review gate not satisfied.

Required approvals:
$BA_DETAIL
$ARCH_DETAIL

Run the missing reviews before making code changes. There is no bypass.
EOF
)

jq -n --arg reason "$REASON" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'
exit 0
