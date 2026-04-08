---
name: create-rest-api-pipeline
description: Create a dlt REST API pipeline to run as a Tower app. Use for the rest_api core source, or any generic REST/HTTP API source. Not for sql_database or filesystem sources.
argument-hint: "[dlt-init-command]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
  - WebFetch
  - WebSearch
  - mcp__tower-mcp__tower_file_validate
  - mcp__tower-mcp__tower_file_update
  - mcp__tower-mcp__tower_file_read
  - mcp__tower-mcp__tower_secrets_list
  - mcp__tower-mcp__tower_secrets_create
---

# Create dlt rest api dlt pipeline

Create the simplest working dlt pipeline running as a Tower app — single endpoint, no pagination or incremental loading — to get data flowing fast.

**Requires a `dlt init` command as the argument** (e.g. `dlt init shopify_store iceberg`).
If you don't have one yet, run `find-source` and `find-destination` first to identify the right source and destination

The argument is the full `dlt init` command to run (e.g. `dlt init shopify_store iceberg` or `dlt init sql_database postgres`).

## Steps

### 0. Read project context

Read `.tower/project-profile.md` if it exists.

- If present and fresh: use detected conventions for naming, auth, env var bridging, and write disposition in subsequent steps. If existing resources are listed, you are ADDING to an existing pipeline — do not replace `task.py`, add new resources to the existing config.
- If missing or stale: do minimal inline detection — check if `task.py` already exists and has pipeline code. If it does, read it to learn conventions before making changes.

**Convention-following rules when profile exists:**

- **Source function naming:** Follow the existing `@dlt.source` function name pattern
- **Resource naming:** Follow the existing pluralization and casing convention
- **Auth pattern:** Reuse the existing auth type unless the new source requires a different one
- **Env var bridging:** Follow the same pattern for new secrets
- **Write disposition:** Default to whatever the existing resources use
- **Pagination:** If existing resources use explicit paginators, add explicit paginators to new resources too

### 1. Snapshot current folder

Run `ls -la` to see the current state before scaffolding.

### 2. Check or create uv project

Check if `uv` is available. If not, install it with `pip install uv` and then activate the venv.
If `uv` is available, and the folder snapshot shows that we're already in an active uv project, continue.
If the folder is still not a uv project, initialize it with `uv init` and activate the venv.

### 3. Install the latest version of dlt and dlthub

Run `uv add dlt>=1.23.0 dlthub>=0.9.1` to install the latest versions of dlt and dlthub. This ensures we have the latest features and bug fixes. Make sure to add any extra dependencies that the `dlt init` command might require for the users source and destination (e.g. `dlt[postgres]` if the destination is postgres).

### 4. Run dlt init

`dlt init` can be run multiple times in the same project — each run adds new files without overwriting existing pipeline scripts. It will update shared files (`.dlt/config.toml`, `requirements.txt`, `.gitignore`).

Run the provided `dlt init` command with `--non-interactive` in the active venv. Depending on the source type, this creates:

**Core source** (`dlt init rest_api iceberg`):

- `rest_api_pipeline.py` (or similar) — full working example with RESTAPIConfig, pagination, incremental loading

**Generic fallback** (`dlt init <unknown_name> iceberg`):

- `<name>_pipeline.py` — basic intro template (less useful, prefer core sources)

**Shared files** (created on first init, updated on subsequent runs):

- `.dlt/secrets.toml` — credentials template
- `.dlt/config.toml` — pipeline config
- `requirements.txt` — Python dependencies
- `.gitignore`

Run `ls -la` again to confirm what was created, then rename the generated pipeline file to `task.py` for clarity and to avoid confusion if `dlt init` is run multiple times (replace any existing `task.py` file, if it's just a dummy script).

### 3. Read generated files

Read the following files to understand the scaffold:

- `task.py` — the pipeline code template
- `<source>-docs.yaml` — API endpoint scaffold with auth, endpoints, params, data selectors (if present)
- `.dlt/config.toml` — source/destination config ie. `api_url`
- `.dlt/secrets.toml` — Obsolete

Do NOT read the `.md` file
Delete the auto-generated `.dlt/secrets.toml` — **we use Tower secrets exclusively, never secrets.toml**. Real credentials must never live in files; they are injected at runtime by Tower as environment variables.

### 4. Research before writing code

Do these in parallel:

**Read essential dlt docs upfront:**

- REST API source (config, auth, pagination, processing_steps): `https://dlthub.com/docs/dlt-ecosystem/verified-sources/rest_api/basic.md`
- Source & resource decorators, parameters: `https://dlthub.com/docs/general-usage/source.md` and `https://dlthub.com/docs/general-usage/resource.md`

**Web search the data source:**

- Confirm the scaffold is accurate, learn about auth method, available endpoints
- How does the user get API keys/tokens for this service

**Read additional docs as needed in later steps:**

- How dlt works (extract → normalize → load): `https://dlthub.com/docs/reference/explainers/how-dlt-works.md`
- CLI reference (trace, load-package, schema): `https://dlthub.com/docs/reference/command-line-interface.md`
- File formats: `https://dlthub.com/docs/dlt-ecosystem/file-formats/`
- Full docs index: `https://dlthub.com/docs/llms.txt`

### 5. Present your findings

**CRITICAL: Use the AskUserQuestion tool** to let the user pick **ONE** endpoint to implement. Present each viable endpoint as a concrete option with a description. Make the recommended endpoint the first option with "(Recommended)" in the label. Do NOT ask via plain text output. Answer questions and do more research if needed.

### 6. Create pipeline with single endpoint

Edit `task.py` using information from the scaffold, API research, and dlt docs:

- Focus on a single endpoint, ignore pagination and incremental loading for now
- Configure `base_url` and `auth`
- Add resources with `endpoint.path`, `data_selector`, `params`, `primary_key`
- Use `dev_mode=True` on the pipeline (fresh dataset on every run during debugging)
- Use `.add_limit(1)` on the source when calling `pipeline.run()` (load one page only)
- Use `replace` write disposition to start
- Remove `refresh="drop_sources"` if present — `dev_mode` handles the clean slate

#### Optionally: parameterize the source function

`@dlt.source` and `@dlt.resource` are regular Python function decorators — expose useful parameters:

- **Credentials** (`dlt.secrets.value`): auto-loaded from secrets.toml, user can also pass explicitly
- **Config** (`dlt.config.value`): auto-loaded from config.toml, user can also pass explicitly
- **Runtime params** (plain defaults): date ranges, filters, granularity — give sensible defaults so the pipeline works out of the box

Users will call the source both ways:

```python
pipeline.run(my_source())  # auto-inject from TOML
pipeline.run(my_source(starting_at="2025-01-01T00:00:00Z", bucket_width="1h"))  # explicit
```

Add a docstring documenting parameters and example calls.

#### Example

```python
@dlt.source
def my_source(
    access_token: str = dlt.secrets.value,
    starting_at: str = None,
):
    """Load data from My API.

    Args:
        access_token: API token. Auto-loaded from secrets.toml.
        starting_at: Start of range (ISO8601). Defaults to 7 days ago.
    """
    if starting_at is None:
        starting_at = pendulum.now("UTC").subtract(days=7).start_of("day").to_iso8601_string()

    config: RESTAPIConfig = {
        "client": {"base_url": "https://api.example.com/v1/", ...},
        "resources": [...],
    }
    yield from rest_api_resources(config)
```

### 6b. Set up config and secrets

**Essential Reading** Credentials & config resolution: `https://dlthub.com/docs/general-usage/credentials/setup.md` `https://dlthub.com/docs/general-usage/credentials/advanced`

**Config** (non-secret values like `base_url`, `api_version`): edit `.dlt/config.toml` directly.

```toml
# .dlt/config.toml
[sources.<name>]
base_url = "https://api.example.com/v1/"
```

**Secrets** (API keys, tokens, passwords): **CRITICAL: ALWAYS use tower-mcp server for ALL secret operations.**

**NEVER** read or write secrets to any config or .env files directly. **NEVER** run CLI commands for secrets. **NEVER** run commands that output secret values (e.g. `gh auth token`, `env | grep KEY`).

Use `tower_secrets_list`, `tower_secrets_create`, and `tower_secrets_delete` MCP tools from the tower-mcp server — see `setup-secrets` skill for details.

- `<name>` = `name=` arg on `@dlt.source` if set; otherwise the function name
- Use meaningful placeholders that hint at format (not generic `<configure me>`)

For more complex credential setup (research where to get keys, multiple providers), use `setup-secrets` skill.

#### Iceberg REST catalog destination (default — tower-managed)

When using the default iceberg destination (tower-managed catalog), you **must**:

1. Add `pyiceberg` as a dependency (`uv add pyiceberg`) — `dlt[iceberg]` extra doesn't exist
2. Set `catalog_type = "rest"` in `.dlt/config.toml`:
   ```toml
   [destination.iceberg]
   catalog_type = "rest"
   ```
3. Bridge PyIceberg env vars to dlt's naming convention in `task.py` (before `dlt.pipeline()` call):

   ```python
   import os
   import json

   # Bridge Tower-managed catalog env vars → dlt's Iceberg config.
   # Tower runtime exposes PYICEBERG_CATALOG__DEFAULT__* automatically.
   # These are NOT Tower secrets — they are injected by the Tower runtime.
   _ENV_MAP = {
       "DESTINATION__ICEBERG__CREDENTIALS__URI": "PYICEBERG_CATALOG__DEFAULT__URI",
       "DESTINATION__ICEBERG__CREDENTIALS__CREDENTIAL": "PYICEBERG_CATALOG__DEFAULT__CREDENTIAL",
       "DESTINATION__ICEBERG__CREDENTIALS__WAREHOUSE": "PYICEBERG_CATALOG__DEFAULT__WAREHOUSE",
   }
   for dlt_key, pyiceberg_key in _ENV_MAP.items():
       if dlt_key not in os.environ and pyiceberg_key in os.environ:
           os.environ[dlt_key] = os.environ[pyiceberg_key]

   # Extra catalog properties (scope, etc.) as a JSON dict.
   props = {}
   if scope := os.environ.get("PYICEBERG_CATALOG__DEFAULT__SCOPE"):
       props["scope"] = scope
   if props:
       os.environ["DESTINATION__ICEBERG__CREDENTIALS__PROPERTIES"] = json.dumps(props)
   ```

**IMPORTANT:** These credentials are available in `tower_run_local` automatically. Do NOT create them as Tower secrets — they are managed by the Tower runtime.

**ALWAYS Get Feedback** before you run the pipeline for a first time. Show summary of files that you changed or generated, then use the AskUserQuestion tool to confirm the user is ready to proceed.

### 7. Debug pipeline - first run

When user requests to run pipeline **ALWAYS use `debug-pipeline`** to diagnose and guide credential setup
**NEVER add more endpoints** before that - keep it simple

## Completion

Report one of these status codes when the skill finishes:

| Status                 | Meaning                                                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **DONE**               | Pipeline scaffolded, `uv run python -c "import task"` passes, `tower_file_validate` passes                          |
| **DONE_WITH_CONCERNS** | Pipeline scaffolded but with warnings (e.g. scaffold diverged from expected structure, destination config untested) |
| **BLOCKED**            | `dlt init` failed and cannot be resolved, or import check fails after multiple fix attempts                         |
| **NEEDS_CONTEXT**      | User must confirm endpoint selection, auth method, or destination config before continuing                          |

## Error Recovery

**`dlt init` fails (unknown source, network error, version mismatch):**
Check the error message. If the source name is not recognized, fall back to `dlt init rest_api <destination>` and configure manually. If it is a network error, retry once. If it is a version mismatch, run `uv add dlt>=1.23.0` to update.

**Import check (`uv run python -c "import task"`) fails:**
Read the full traceback. Common causes: missing dependency (fix with `uv add <pkg>`), syntax error in `task.py` (fix the code), or import of a module that does not exist in the scaffold (check the generated file names). Fix and re-run the import check.

**Scaffold does not match expected structure (missing files, unexpected layout):**
Run `ls -la` to see what was actually created. If the pipeline file has a different name than expected, rename it to `task.py`. If `.dlt/` directory is missing, run `dlt init` again. If the scaffold is for a different source type, start over with the correct `dlt init` command.

**`tower_file_validate` fails after code changes:**
The Towerfile may reference files that were renamed or deleted. Use `tower_file_read` to inspect the current Towerfile, then `tower_file_update` to fix file references. Re-validate after each fix.
