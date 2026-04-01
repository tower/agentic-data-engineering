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

## Running pipelines — NEVER run directly

**NEVER run pipeline scripts directly.** This means:
* No `python task.py`
* No `python pipeline.py`
* No `python main.py`
* No `uv run python task.py`
* No `uv run python pipeline.py`
* No `uv run python main.py`

**ALWAYS use `tower_run_local`** from tower-mcp. It has access to Tower secrets and Tower-managed catalog credentials that direct execution does not have.

**NEVER use `tower_run_remote`.** Always use `tower_run_local` for development and debugging.

### Error recovery when tower_run_local fails

If `tower_run_local` returns an error (timeout, MCP connection closed, etc.):

1. **Check `tower_apps_logs`** for the actual error output from the run
2. **Retry `tower_run_local` once** — transient MCP errors are common
3. **If still failing, report the error to the user** — tell them what happened and suggest troubleshooting steps
4. **NEVER fall back to running the script directly** — this bypasses Tower's secret injection and catalog credentials

## Editing files — BA + Architect review required first

**NEVER edit or create project files without approved reviews.** This is enforced by a PreToolUse hook on Edit and Write — there is no bypass.

A hook blocks ALL Edit and Write calls except to exempt paths (`.tower/*`, `.claude/*`, `.agents/*`, `.gitignore`). Before any code changes, you MUST have:

1. **BA review** — `.tower/reviews/ba-review-{app}*.md` with `gate_result: APPROVE`
2. **Architect review** — `.tower/reviews/architect-review-{app}*.md` with `gate_result: APPROVE`

Both must exist and not be stale (≤5 commits behind HEAD).

**Workflow:** Run `/plan-business-analyst-review` and `/plan-data-architect-review` BEFORE writing any code — including initial scaffolding. These reviews produce plan artifacts (scope brief, schema design) that the hook checks. The hook will deny the tool call and tell you exactly what's missing.

**Do NOT attempt to work around this gate.** Do not try to edit files without reviews. Do not ask the user to disable the hook. Run the reviews.

## Secrets and credentials — NEVER use env vars or files

**NEVER suggest environment variables for credentials.** This means:
* No `GITHUB_TOKEN=...`
* No `export API_KEY=...`
* No `.env` files
* No `.dlt/secrets.toml`
* No `profiles.yml` with hardcoded credentials

**ALWAYS use Tower secrets** via `tower_secrets_create` / `tower_secrets_list` / `tower_secrets_delete`.

When a pipeline needs credentials:
1. Use `tower_secrets_create` to create a placeholder secret with the correct dlt env var name
2. Direct the user to the Tower secrets UI to fill in the real value
3. Reference the `setup-secrets` skill for the full workflow

**NEVER read user secrets in plain text.** If a secret appears in conversation context, it is **compromised**.

**REFUSE** to handle secrets that the user pastes into the chat. Instead, explain Tower secrets handling practices.

## Python environment

* Use `uv` to manage the project. Run commands with `uv run` from the project root.
* Install dependencies with `uv add` before running.
* **ALWAYS** pass `--non-interactive` when running `dlt` commands (e.g. `uv run dlt --non-interactive init ...`).
* **ALWAYS** run all commands with **cwd** in the project root — `dlt` uses **cwd** to find `.dlt/`.
* `uv run` is fine for non-pipeline commands (e.g. `uv run dlt init`, `uv run python -c "import task"`, `uv run ruff`). The restriction is specifically on running pipeline entry points.
