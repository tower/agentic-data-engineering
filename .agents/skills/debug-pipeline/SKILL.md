---
name: debug-pipeline
description: Debug and inspect a dlt pipeline after running it. Use after a pipeline run (success or failure) to inspect traces, load packages, schema, data, and diagnose errors like missing credentials or failed jobs.
argument-hint: "[pipeline-name] [issue]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
  - mcp__tower-mcp__tower_run_local
  - mcp__tower-mcp__tower_apps_logs
  - mcp__tower-mcp__tower_apps_show
---

# Debug a dlt pipeline

**Essential Reading** https://dlthub.com/docs/reference/explainers/how-dlt-works

Parse `$ARGUMENTS`:
- `pipeline-name` (optional): the dlt pipeline name. If omitted, infer from session context. If ambiguous, ask the user and stop.
- `hints` (optional, after `--`): specific issue to investigate

## 0. Read project context

Read `.tower/project-profile.md` if it exists.
- If present: use the detected pipeline name, destination type, and known resources for faster diagnosis. Skip asking the user for pipeline name if the profile has it.
- If missing: proceed with standard detection from task.py.

## Before debugging: increase verbosity

Always do this first before any pipeline debugging:

**IMPORTANT:** Before making changes, note the current values in config files and pipeline code so you can restore them exactly. You are changing the user's files — only revert what YOU changed.

1. **Set log level to INFO** in `.dlt/config.toml`:
   ```toml
   [runtime]
   log_level="INFO"
   ```

2. **Show HTTP error response bodies** (hidden by default!):
   ```toml
   [runtime]
   http_show_error_body = true
   ```

3. **Add progress logging** to the `dlt.pipeline()` call (NOT `pipeline.run()` — that argument doesn't exist):
   ```python
   pipeline = dlt.pipeline(..., progress="log")
   ```
4. **Simplify high-volume resources**: if the pipeline has resources that extract many items, cap them during debugging. **Important caveat**: `.add_limit(N)` on a parent resource does NOT limit its nested children — each parent item still triggers unbounded child fetches (e.g. limiting repos to 5 still fetches ALL workflow_runs for each of those 5 repos).

   **Classify each resource first:**
   - **Entity** (user, org, repo, ticker symbol) → `.add_limit(N)` on the parent is fine; entities don't accumulate unboundedly
   - **Event series** (commits, workflow runs, stock prices, log events) → has timestamps; limit by **date** instead of count

   For **event-series nested resources**, check the API docs for a date filter parameter and add it directly to that resource's `endpoint.params`. Use 7 days as the default debug window:
   ```python
   from datetime import datetime, timedelta, timezone
   seven_days_ago = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()

   # In the REST API resource config (exact param name varies by API):
   {
       "name": "workflow_runs",
       "endpoint": {
           "path": "repos/{repo}/actions/runs",
           "params": {
               "created": f">={seven_days_ago}",  # GitHub uses `created`
               # Other APIs: `since`, `start`, `from_date`, `startTime` — check their docs
           }
       }
   }
   ```
   For flat top-level event resources, `.add_limit(200)` is still appropriate for early debugging.

This shows HTTP requests being made, data extracted, pagination steps, and normalize/load progress. Essential for diagnosing any issue.
**Essential reading if problems PERSIST**: https://dlthub.com/docs/general-usage/http/rest-client.md

## Run the pipeline

**CRITICAL: ALWAYS use `tower_run_local` from tower-mcp server. NEVER use `tower_run_remote` or CLI commands.**

`tower_run_local` has access to both Tower secrets and Tower-managed catalog credentials (e.g. `PYICEBERG_CATALOG__DEFAULT__*` env vars for iceberg). Use it for ALL pipeline runs during development and debugging.

- Use `tower_apps_logs` to inspect detailed logs if needed
- Use `tower_apps_show` to check app status and configuration

Common exceptions and what they mean:
- `ConfigFieldMissingException` - config / secrets are missing. inspect exception message
- `PipelineFailedException` - pipeline failed in one of the steps. inspect exception trace to find a root cause. find **load_id** to identify load package that failed

In extract step most of the exceptions are coming from source/resource code that you wrote!

### First run of the pipeline

**Suggest to run** the pipeline before asking the user to fill in credentials:

Expected: a `ConfigFieldMissingException` or `401 Unauthorized` error confirming:
- The pipeline structure is correct
- Config/secrets resolution is wired up properly
- The right API endpoint is being hit

Tell the user what credentials to fill in and how to get them. If credentials are unknown, research the data source (web search for API docs, auth setup guides — similar to what `find-source` does).

After any run (success or failure), use the dlt CLI for inspection:

### Pipeline appears stuck / runs too long

A pipeline that runs for a long time is suspicious but MAY be normal (large datasets). Analyze stdout before killing it:

**Paginator loops forever** — repeated requests to the same URL or page:
- dlt's auto-detected paginator can guess wrong and loop. Fix: set an explicit `"paginator"` in the resource config.
- `OffsetPaginator`/`PageNumberPaginator` without `stop_after_empty_page=True` require `total_path` or `maximum_offset`/`maximum_page`, otherwise they loop forever.
- `JSONResponseCursorPaginator` with wrong `cursor_path` → cursor never advances → infinite loop.

**Silent retries look like a hang** — the pipeline may be retrying failed HTTP requests:
- Default: 5 retries with exponential backoff (up to 16s per attempt), 60s request timeout.
- A single failing endpoint can stall for 60-80+ seconds before raising an error.
- Override in `.dlt/config.toml` for faster failure during debugging:
  ```toml
  [runtime]
  request_timeout = 15
  request_max_attempts = 2
  ```
- Ref: https://dlthub.com/docs/general-usage/http/requests.md (timeouts and retries)

**Working but slow** — each request returns new data and URL changes. Use `.add_limit(N)` to cap pages during development.

**Can't tell which resource is stuck** in a multi-resource pipeline — switch to sequential extraction:
```toml
[extract]
next_item_mode = "fifo"
```
This makes one resource complete fully before the next starts, making logs much easier to follow.
Ref: https://dlthub.com/docs/reference/performance.md (extraction modes)

### Pipeline succeeds but loads 0 rows

Likely a wrong or missing `data_selector`. dlt auto-detects the data array in the response but can fail silently on complex/nested responses. Fix: explicitly set `data_selector` as a JSONPath to the array (e.g. `"data"`, `"results.items"`).

### Incremental loading stops picking up new data

Inspect pipeline state to check the stored cursor value:
```
dlt pipeline -v <pipeline_name> info
```
Look for `last_value` in the resource state — verify it updates between runs. Also check logs for `"Bind incremental on <resource_name>"` to confirm the incremental param was bound.
Ref: https://dlthub.com/docs/general-usage/incremental/troubleshooting.md


## Post mortem debugging and trace
You can inspect last pipeline run:

```
dlt pipeline -vv <pipeline_name> trace
```
Note: `-vv` goes BEFORE the pipeline name. Shows config/secret resolution, step timing, failures.

## Load packages
Each pipeline run generated one or more load packages. Use trace tool to find their ids.

```
dlt pipeline -v <pipeline_name> load-package          # most recent package
dlt pipeline -v <pipeline_name> load-package <load_id> # specific package
```
Shows package state, per-job details (table, file type, size, timing), and **error messages for failed jobs**. With `-v` also shows schema updates applied.

```
dlt pipeline <pipeline_name> failed-jobs
```
Scans all packages for failed jobs and displays error messages from the destination.

### Inspecting raw load files

Load packages are stored at `~/.dlt/pipelines/<pipeline_name>/load/loaded/<load_id>/`. Job files live in `completed_jobs/` and `failed_jobs/` subdirectories.

File format depends on the destination:

| Format | Default for | File extension |
|---|---|---|
| INSERT VALUES | duckdb, postgres, redshift, mssql, motherduck | `.insert_values.gz` |
| JSONL | bigquery, snowflake, filesystem | `.jsonl.gz` |
| Parquet | athena, databricks (also supported by duckdb, bigquery, snowflake) | `.parquet` |
| CSV | filesystem | `.csv.gz` |

Inspect gzipped files with `zcat`:
```
zcat ~/.dlt/pipelines/<pipeline_name>/load/loaded/<load_id>/completed_jobs/<file>.gz
```
Useful for verifying data transformations and debugging destination errors.

## Clean up after debugging

Before moving on, revert all debugging settings YOU introduced. Only revert what you changed — preserve any user settings that existed before.

Checklist:
- [ ] `.dlt/config.toml` — restore `log_level` to its previous value (e.g. `WARNING`). Remove `http_show_error_body`, `request_timeout`, `request_max_attempts` if you added them. Remove `[extract] next_item_mode` if you added it.
- [ ] Pipeline script — remove `progress="log"` from `dlt.pipeline()` if you added it. Remove `.add_limit(N)` if you added it for debugging.

Do NOT remove settings the user had before you started debugging.

## Completion

Report one of these status codes when the skill finishes:

| Status | Meaning |
|---|---|
| **DONE** | Pipeline loads data successfully, trace and load package inspected |
| **DONE_WITH_CONCERNS** | Pipeline loads data but with warnings (e.g. some rows skipped, unexpected schema, slow performance) |
| **BLOCKED** | Unresolvable error after 5 debug iterations, or fundamental issue (wrong API, broken auth provider) |
| **NEEDS_CONTEXT** | User must provide credentials, clarify API access, or confirm expected behavior |

## Error Recovery

**Self-regulation: 5-iteration cap.** Track each debug cycle (change code or config, re-run pipeline, inspect result). If 5 iterations pass without meaningful progress (same error class, no new information), STOP. Do not continue looping. Instead:
1. Summarize what was tried and what failed
2. State the root cause hypothesis
3. Identify what external input is needed (user credentials, API provider support, upstream bug)
4. Status: BLOCKED

**Pipeline hangs or runs too long:**
Follow the "Pipeline appears stuck" section above. If sequential extraction (`next_item_mode = "fifo"`) does not isolate the stuck resource after 2 attempts, kill the run and inspect the last successful resource to narrow down the problem.

**Credentials error persists after user claims they set real values:**
Use `tower_secrets_list` to verify the secret exists (do NOT read its value). Check the secret name matches dlt's expected env var exactly — common mistakes: single vs. double underscores, wrong case, missing `SOURCES__` or `DESTINATION__` prefix.

**Destination rejects data (load step fails):**
Run `dlt pipeline failed-jobs` to get the destination error message. Common causes: schema mismatch (column type conflict), permissions error (missing write access), or quota exceeded. Fix the schema or destination config and retry.

## Next steps

- **Load successful** → **ALWAYS** run `validate-data` next to inspect schema shape, profile columns, and check data quality. This is the mandatory quality gate before moving to production.
- **Config/secrets missing** → credentials must be set as Tower secrets via `tower-mcp` (never in `.dlt/secrets.toml` or `.env`). Use `setup-secrets` skill or revisit `create-rest-api-pipeline` step 6b.
- **No pipeline exists** → use `create-rest-api-pipeline` to scaffold one first
