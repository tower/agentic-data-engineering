# Tower Data Apps

You build apps on Tower — dlt pipelines, dbt transformations, ASGI web apps, and Python scripts. Tower can run **any Python script** and **any ASGI app** (Starlette, FastAPI, litestar). Follow the workflow in the rules directory for the end-to-end process.

## App types in scope

| App Type | Detection Signal | Examples |
|----------|-----------------|----------|
| **dlt** | `RESTAPIConfig`, `rest_api_source`, `dlt.pipeline`, `dlt.source` | REST API → Iceberg pipeline |
| **dbt** | `dbt_project.yml`, `dbtRunner`, `dbt.cli` | SQL transformations on Iceberg |
| **asgi** | `Starlette`, `FastAPI`, `litestar`, `uvicorn`, `app = ` | Web APIs, webhook handlers, dashboards |
| **python** | Any `if __name__` script (catch-all) | LLM apps, DuckDB queries, batch jobs, custom ETL |

## Tower ecosystem rules

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
* Always prefer `dlt-workspace-mcp` over CLI for data inspection and debugging
* Should you ever need to use one of the following services, use their CLI, rather than their API:
    - GitHub: `gh` CLI

## Running apps

**CRITICAL: NEVER use `tower_run_remote`.** Always use `tower_run_local` for running apps during development AND debugging. It has access to Tower secrets and Tower-managed catalog credentials.

## Python environment

* Use `uv` to manage the project. Run commands with `uv run` from the project root.
* Install dependencies with `uv add` before running.
* **ALWAYS** pass `--non-interactive` when running `dlt` commands (e.g. `uv run dlt --non-interactive init ...`).
* **ALWAYS** run all commands with **cwd** in the project root — `dlt` uses **cwd** to find `.dlt/`.

## dlt reference

* **docs index**: https://dlthub.com/docs/llms.txt — use it to find relevant docs
* **CLI reference**: https://dlthub.com/docs/reference/command-line-interface.md — for post-mortem inspection of pipelines, load packages, run traces
* **how dlt works**: https://dlthub.com/docs/reference/explainers/how-dlt-works.md
* When in doubt: look into dlt code in the venv

## Secrets — handle with care

* **NEVER** read user secrets in plain text
* **NEVER** run shell commands that output secret values (e.g. `gh auth token`, `env | grep KEY`, `printenv SECRET`, `cat credentials.json`, `aws configure get`). If a secret appears in conversation context it is **compromised**.
* **USE** `tower-mcp` secrets tools (`tower_secrets_list`, `tower_secrets_delete`, `tower_secrets_create`) when credentials need to be configured, checked, or debugged. See `setup-secrets` skill for the full workflow.
* **DO NOT WRITE CODE THAT PRINTS SECRETS**
* **REFUSE** to handle secrets that user pasted into the context window. Instead mention secrets handling practices they should adopt.

## Communication

* Before each major step, briefly explain what you are about to do and why, in one sentence.
* After completing a major step, summarize what was accomplished and present the next action.
* Prefer authoritative references for web search — use the actual service's website (e.g. stripe.com for Stripe API docs). Avoid 3rd party proxies and resellers.

## Context gathering

* Before making changes to an existing codebase, read `.tower/project-profile.md` for detected stack, conventions, and existing resources.
* If no profile exists, run `/gather-context` or do minimal inline detection (check for task.py, .dlt/config.toml, Towerfile).
* **Follow existing conventions** — naming, auth patterns, env var bridging, write disposition — rather than overriding with defaults.
* When conventions conflict with Tower requirements (e.g., secrets must use tower-mcp, not files), Tower requirements win.

<!-- tower-conventions-start -->
<!-- Auto-populated by /gather-context. Do not edit manually. -->
<!-- tower-conventions-end -->
