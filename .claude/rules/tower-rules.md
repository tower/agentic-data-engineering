# Tower Hard Rules

These rules are non-negotiable. They override default model behavior and must be followed even when errors occur.

## Tower MCP is the ONLY interface

**CRITICAL: ALWAYS use tower-mcp for ALL Tower operations.**

* **NEVER** use Tower CLI commands (`tower run`, `tower deploy`, `tower apps`, `tower secrets`, etc.)
* **ALWAYS** use `tower-mcp` MCP server tools instead:
  - `tower_run_local` - run apps locally (NOT `uv run tower --local`)
  - `tower_run_remote` - run apps remotely (NOT `uv run tower`)
  - `tower_apps_list`, `tower_apps_show`, `tower_apps_logs` - inspect apps
  - `tower_apps_create`, `tower_apps_delete` - manage apps
  - `tower_secrets_list`, `tower_secrets_create`, `tower_secrets_delete` - manage secrets
  - `tower_teams_list`, `tower_teams_switch` - manage teams
  - `tower_file_generate`, `tower_file_update`, `tower_file_validate` - manage Towerfiles
  - `tower_schedules_list`, `tower_schedules_create`, `tower_schedules_update`, `tower_schedules_delete` - manage schedules
  - `tower_deploy` - deploy apps

## Running apps — NEVER run directly

**NEVER run app scripts directly.** This means:
* No `python task.py`
* No `python pipeline.py`
* No `python main.py`
* No `uv run python task.py`
* No `uv run python pipeline.py`
* No `uv run python main.py`

**ALWAYS use `tower_run_local`** from tower-mcp. It has access to Tower secrets and Tower-managed catalog credentials that direct execution does not have.

**NEVER use `tower_run_remote`.** Always use `tower_run_local` for development and debugging.

### If the project is not yet a Tower app

**If the user asks to run a Python file that is not yet a Tower app** (no `Towerfile` exists), do NOT refuse or say "no app to run." Instead:
1. Scan for existing Python files (see workflow.md `has-code` state)
2. Wrap the project into a Tower app using `init-tower-app` (WRAP mode)
3. Then run via `tower_run_local`

### Error recovery when tower_run_local fails

If `tower_run_local` returns an error (timeout, MCP connection closed, etc.):

1. **Check `tower_apps_logs`** for the actual error output from the run
2. **Retry `tower_run_local` once** — transient MCP errors are common
3. **If still failing, report the error to the user** — tell them what happened and suggest troubleshooting steps
4. **NEVER fall back to running the script directly** — this bypasses Tower's secret injection and catalog credentials

## Editing files — intent-based review guidance

Before making code changes to a Tower app, score the user's intent into one of these categories:

| Intent | Description | Review requirement |
|--------|-------------|-------------------|
| **investigation** | Reading code, exploring data, running queries | None — read-only, no edits |
| **yolo** | Quick experiment, throwaway prototype, learning | None — go fast, break things |
| **hotfix** | Targeted bug fix, single-file change, urgent | None — fix it, ship it |
| **feature** | New endpoint, new resource, new app feature | BA review + Architect review before code |
| **refactor** | Restructuring existing app, schema change, migration | BA review + Architect review before code |

**How to score:**
1. When the user asks for work on an existing Tower app (has Towerfile + task.py), assess their intent from the request
2. If ambiguous between categories, say: "This looks like a [category]. Let me run a quick review before we build."
3. For **feature** and **refactor**: run BA + architect reviews before making code changes. This is mandatory.
4. For **hotfix**, **yolo**, **investigation**: proceed directly

**Reviews are mandatory for feature and refactor intents.** If a "hotfix" starts growing into a feature, pause and run reviews before continuing.

**How to run reviews (scope-dependent):**

| Scope | Signal | Review approach | Output |
|-------|--------|----------------|--------|
| **Narrow** | User names a specific feature, single capability addition, clear technical ask | Launch BA and architect as subagents (AUTONOMOUS mode) to review a draft mini-plan. Incorporate their feedback. No user interaction during review. | Present a polished mini-plan to the user, ready to approve or adjust |
| **Broad** | User describes a goal, mentions multiple capabilities, unclear technical approach | Invoke `/plan-business-analyst-review` (DISCOVERY or EXPANSION) and `/plan-data-architect-review` (PRE-LOAD) as interactive skills with the user | Plan emerges from the interactive review session |

**Narrow scope flow:**
1. Explore the codebase to understand current state
2. Draft a v1 mini-plan (entities, approach, key decisions)
3. Launch BA subagent: pass the v1 plan, ask for scope check feedback (pass/fail + concerns)
4. Launch architect subagent: pass the v1 plan, ask for PRE-LOAD assessment (schema impact, query approach, blocking issues)
5. Incorporate both reviews' feedback into a v2 plan
6. Present v2 to the user — they see the plan, not the review process

**Broad scope flow:**
1. Invoke `/plan-business-analyst-review` — interactive DISCOVERY or EXPANSION session with user
2. On BA approval, invoke `/plan-data-architect-review` — interactive PRE-LOAD session
3. Review artifacts written to `.tower/reviews/`
4. Plan emerges from the review outputs

**Never offer to skip reviews for feature or refactor intents.** If the user explicitly says "skip reviews" or "just build it", acknowledge it but still run a lightweight scope check before coding.

## Secrets and credentials — NEVER use env vars or files

**NEVER suggest environment variables for credentials.** This means:
* No `GITHUB_TOKEN=...`
* No `export API_KEY=...`
* No `.env` files
* No `.dlt/secrets.toml`
* No `profiles.yml` with hardcoded credentials

**ALWAYS use Tower secrets** via `tower_secrets_create` / `tower_secrets_list` / `tower_secrets_delete`.

When an app needs credentials:
1. Use `tower_secrets_create` to create a placeholder secret with the correct env var name
2. Direct the user to the Tower secrets UI to fill in the real value — always include a direct link. Use `tower_teams_list` to get the team slug and `tower_secrets_list` to get the environment name, then point them to `https://app.tower.dev/<team-slug>/<environment>/team-settings/secrets`
3. Reference the `setup-secrets` skill for the full workflow

**NEVER read user secrets in plain text.** If a secret appears in conversation context, it is **compromised**.

**REFUSE** to handle secrets that the user pastes into the chat. Instead, explain Tower secrets handling practices.

## Python environment

* Use `uv` to manage the project. Run commands with `uv run` from the project root.
* Install dependencies with `uv add` before running.
* **ALWAYS** pass `--non-interactive` when running `dlt` commands (e.g. `uv run dlt --non-interactive init ...`).
* **ALWAYS** run all commands with **cwd** in the project root — `dlt` uses **cwd** to find `.dlt/`.
* `uv run` is fine for non-app commands (e.g. `uv run dlt init`, `uv run python -c "import task"`, `uv run ruff`). The restriction is specifically on running app entry points (`task.py`, `main.py`, `pipeline.py`).
