---
name: find-destination
description: Find a dlt destination for a given storage provider. Use when the user asks about a destination, wants to find a connector, or asks to implement a pipeline for a specific data destination.
argument-hint: "[destination-name] [context]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - WebFetch
  - WebSearch
---

# Find a dlt destination

Locate the best dlt destination for what the user wants to load data into.

Parse `$ARGUMENTS`:
- `destination-name` (optional): what the user wants to load data into (e.g., "duckdb", "postgres", "snowflake", "iceberg", "filesystem"). This is the main input to classify the request and find the best destination.
- everything after that: additional context, i.e. into which schema the user wants to load the data, what authentication method they prefer, what type of data they want to load, etc. Use this context to disambiguate between multiple viable options and to find the best match.

## Steps

### 0. Read project context

Read `.tower/project-profile.md` if it exists.
- If present and shows a destination already configured: confirm the existing destination with the user. Skip the selection flow unless they explicitly request a different destination.
- If missing: proceed with default (Iceberg) or user's explicit request.

### 1. Use Iceberg as the default destination?
If the user has NOT EXPLICITLY mentioned a specific destination assume iceberg tables with rest catalog (polaris) and <client-id><client-secret> credentials. The following iceberg catalog configuration is known to work with dlt and can be used as a default. Secret credentials will be injected as environment variables at runtime:
```
# config.toml
[destination.iceberg]
catalog_type = "rest"
```
Read up on iceberg destination configuration here: https://dlthub.com/docs/dlt-ecosystem/destinations/iceberg

Only If the user has EXPLICITLY mentioned a destination other than iceberg, continue with steps 2-5  to identify the right destination, otherwise jump straight to step 6

#### Iceberg dependencies

**IMPORTANT:** `dlt[iceberg]` extra does NOT exist. You must add `pyiceberg` as a separate dependency:
```
uv add pyiceberg
```

#### Iceberg credentials (Tower-managed runtime)

The following `PYICEBERG_CATALOG__DEFAULT__*` env vars are **automatically injected by the Tower runtime** — they are NOT Tower secrets and do NOT need to be created via `tower_secrets_create`:

| Tower runtime env var | Format | Description |
|---|---|---|
| `PYICEBERG_CATALOG__DEFAULT__URI` | `https://your-catalog.example.com` | REST catalog endpoint |
| `PYICEBERG_CATALOG__DEFAULT__WAREHOUSE` | `my_warehouse` | Warehouse name |
| `PYICEBERG_CATALOG__DEFAULT__CREDENTIAL` | `client_id:client_secret` | OAuth2 credentials (colon-separated) |
| `PYICEBERG_CATALOG__DEFAULT__SCOPE` | `PRINCIPAL_ROLE:your_role` | OAuth2 scope (colon-separated) |

These are available in `tower_run_local` runs automatically. **NEVER create these as Tower secrets.**

**CRITICAL:** dlt's iceberg destination does **NOT** read `PYICEBERG_CATALOG__DEFAULT__*` env vars automatically. It uses its own config resolution (`DESTINATION__ICEBERG__CREDENTIALS__*`). You must manually bridge these env vars in your pipeline code.

#### Env var bridging pattern (required in task.py)

```python
import os
import json

# Bridge PyIceberg env vars → dlt's Iceberg REST catalog config.
# dlt expects DESTINATION__ICEBERG__CREDENTIALS__* but Tower exposes PYICEBERG_CATALOG__DEFAULT__*.
env_map = {
    "DESTINATION__ICEBERG__CREDENTIALS__URI": "PYICEBERG_CATALOG__DEFAULT__URI",
    "DESTINATION__ICEBERG__CREDENTIALS__CREDENTIAL": "PYICEBERG_CATALOG__DEFAULT__CREDENTIAL",
    "DESTINATION__ICEBERG__CREDENTIALS__WAREHOUSE": "PYICEBERG_CATALOG__DEFAULT__WAREHOUSE",
}
for dlt_key, pyiceberg_key in env_map.items():
    if dlt_key not in os.environ and pyiceberg_key in os.environ:
        os.environ[dlt_key] = os.environ[pyiceberg_key]

# Extra catalog properties (scope, etc.) must be passed as a JSON dict.
# dlt does not resolve nested dict keys from individual env vars for MetastoreProperties.
props = {}
if scope := os.environ.get("PYICEBERG_CATALOG__DEFAULT__SCOPE"):
    props["scope"] = scope
if props:
    os.environ["DESTINATION__ICEBERG__CREDENTIALS__PROPERTIES"] = json.dumps(props)
```

#### config.toml (always required)

```toml
[destination.iceberg]
catalog_type = "rest"
```

`catalog_type` **must** be set in `.dlt/config.toml` — it is not auto-detected.


### 2. Search dlt destinations

```
dlt --non-interactive init --list-destinations
```
Search the output (case-insensitive) for the destination name. If found, skip to **step 5**

### 3. Fetch destination-specific documentation
Use the table below to find the documentation URL for the requested destination, then fetch and read it.                                                                            
| Destination | Documentation URL |
|---|---|                                                                                                                            
| postgres | https://dlthub.com/docs/dlt-ecosystem/destinations/postgres |
| snowflake | https://dlthub.com/docs/dlt-ecosystem/destinations/snowflake |
| filesystem | https://dlthub.com/docs/dlt-ecosystem/destinations/filesystem |
| duckdb | https://dlthub.com/docs/dlt-ecosystem/destinations/duckdb |
| ducklake | https://dlthub.com/docs/dlt-ecosystem/destinations/ducklake |
| mssql | https://dlthub.com/docs/dlt-ecosystem/destinations/mssql |
| fabric | https://dlthub.com/docs/dlt-ecosystem/destinations/fabric |
| bigquery | https://dlthub.com/docs/dlt-ecosystem/destinations/bigquery |
| athena | https://dlthub.com/docs/dlt-ecosystem/destinations/athena |
| redshift | https://dlthub.com/docs/dlt-ecosystem/destinations/redshift |
| qdrant | https://dlthub.com/docs/dlt-ecosystem/destinations/qdrant |
| lancedb | https://dlthub.com/docs/dlt-ecosystem/destinations/lancedb |
| motherduck | https://dlthub.com/docs/dlt-ecosystem/destinations/motherduck |
| weaviate | https://dlthub.com/docs/dlt-ecosystem/destinations/weaviate |
| synapse | https://dlthub.com/docs/dlt-ecosystem/destinations/synapse |
| databricks | https://dlthub.com/docs/dlt-ecosystem/destinations/databricks |
| dremio | https://dlthub.com/docs/dlt-ecosystem/destinations/dremio |
| clickhouse | https://dlthub.com/docs/dlt-ecosystem/destinations/clickhouse |
| destination | https://dlthub.com/docs/dlt-ecosystem/destinations/destination |
| sqlalchemy | https://dlthub.com/docs/dlt-ecosystem/destinations/sqlalchemy |


### 4. Decide: is this a destination that dlt can load into?

This toolkit builds only DLT pipelines for known destinations. Before continuing, check if the user's destination actually exists.

**STOP and hand off** if the destination requested by the users does not unambiguously match any of the known destinations listed above, or if the documentation indicates that it's not a destination that dlt can load into.

```
Loading data into [destination] is not currently supported by dlt. Sorry for the inconvenience!
```

**CONTINUE** only if the destination requested by the users DOES unambiguously match any of the known destinations listed above, and if the documentation indicates that it's a destination that dlt can load into.

### 5. Determine the authentication and configuration settings
Use the documentation to determine the different ways and credential set that users can use to authenticate with their chosen destination. Also check whether the pipeline supports different table formats or different file formats. See step 5 for how to use this information.

### 6. Present findings

**CRITICAL: When user input is needed, use the AskUserQuestion tool.** Present each viable destination/auth method as a concrete option. Make the recommended option first with "(Recommended)" in the label. Do NOT ask questions via plain text output.

1. **high intent user** told you exactly what destination, what auth mechanism, and what table/file format they want - present the result. Only if not - alternatives
2. **low intent user** told you about their goals. Allow them to make informed decision. Use AskUserQuestion to let them choose between options.
3. Summarize
- Determine how many genuinely distinct options the user has.
A **viable option** is one that genuinely differs in tradeoffs — not every search result is a separate option. Only surface choices where the user's preference would actually matter (e.g. a remote destination vs. local destination). If one option is clearly best, just present that one.
- For each viable option, briefly describe what it provides, its init command, and what it requires.

## Completion

Report one of these status codes when the skill finishes:

| Status | Meaning |
|---|---|
| **DONE** | Destination identified, configuration requirements clear, user confirmed |
| **DONE_WITH_CONCERNS** | Destination works but with caveats (e.g. limited feature support, complex auth) |
| **BLOCKED** | Requested destination is not supported by dlt |
| **NEEDS_CONTEXT** | User must clarify which destination, auth method, or table format they want |

## Error Recovery

**Destination not in dlt's supported list:**
Run `dlt --non-interactive init --list-destinations` to get the current list. If the user's destination is not listed, check whether it maps to a supported one (e.g. "Redshift Serverless" maps to `redshift`, "Azure SQL" maps to `mssql`). If no mapping exists, tell the user and suggest the closest alternative. Status: BLOCKED if no viable match.

**Destination docs page returns an error or is missing:**
Fall back to the dlt docs index at `https://dlthub.com/docs/llms.txt` and search for the destination name. If the destination was recently added, the docs may lag — check the dlt GitHub repo for the latest destination support.

**Destination requires unsupported auth method:**
Some destinations support multiple auth methods. Check the docs for alternatives (e.g. service account vs. OAuth, connection string vs. individual fields). If none work, Status: BLOCKED with a clear explanation of what is missing.

**User wants Iceberg but with a non-Tower catalog:**
The default Tower-managed catalog is the only tested path. If the user wants a custom catalog (e.g. AWS Glue, Hive), warn that this is outside the standard workflow and may require custom configuration. Status: DONE_WITH_CONCERNS.
