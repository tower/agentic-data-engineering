---
name: gather-context
description: Detect existing project stack, learn conventions from code, and produce a project profile. Run before other skills to give them richer context, or let skills invoke it automatically when no profile exists.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - AskUserQuestion
  - mcp__tower-mcp__tower_file_read
---

# Gather Project Context

Detect the existing project stack, learn conventions from code, and produce a structured project profile at `.tower/project-profile.md`. Other skills read this profile in their Step 0 to adapt to existing codebases instead of assuming greenfield.

---

## Steps

### 1. Stack detection

Check config file existence to classify the project. Run these checks in parallel:

```bash
# Python / uv project
[ -f pyproject.toml ] && echo "SIGNAL:package_manager=uv" && head -30 pyproject.toml

# App entry point
[ -f task.py ] && echo "SIGNAL:entry_point=task.py"
[ -f main.py ] && echo "SIGNAL:entry_point=main.py"

# App type detection
grep -l "RESTAPIConfig\|rest_api_resources\|rest_api_source\|dlt\.pipeline\|dlt\.source" task.py 2>/dev/null && echo "SIGNAL:app_type=dlt"
grep -l "dbt_project.yml\|dbtRunner\|dbt\.cli" task.py 2>/dev/null && echo "SIGNAL:app_type=dbt"
grep -l "Starlette\|FastAPI\|litestar\|app\s*=\s*.*Router\|uvicorn" task.py 2>/dev/null && echo "SIGNAL:app_type=asgi"

# dlt config
[ -f .dlt/config.toml ] && echo "SIGNAL:has_dlt_config=yes" && cat .dlt/config.toml

# Towerfile
[ -f Towerfile ] && echo "SIGNAL:has_towerfile=yes"

# dbt project
[ -f dbt_project.yml ] && echo "SIGNAL:has_dbt_project=yes" && head -20 dbt_project.yml
[ -f profiles.yml ] && echo "SIGNAL:has_profiles=yes"

# Tower reviews
ls .tower/reviews/*.md 2>/dev/null && echo "SIGNAL:has_reviews=yes"

# Git state
git rev-parse --short HEAD 2>/dev/null
git log --oneline -5 2>/dev/null
```

If the Towerfile exists, also read it via `tower_file_read` MCP tool for app name and resource config.

**Classify the app type:**

| Signals                                                                                 | App Type             |
| --------------------------------------------------------------------------------------- | -------------------- |
| task.py contains `RESTAPIConfig`, `rest_api_resources`, `dlt.pipeline`, or `dlt.source` | `dlt`                |
| task.py contains `dbtRunner` or `dbt_project.yml` exists                                | `dbt`                |
| task.py contains `Starlette`, `FastAPI`, `litestar`, or `uvicorn`                       | `asgi`               |
| task.py exists but no dlt/dbt/asgi signals                                              | `python`             |
| No task.py or main.py                                                                   | `empty` (no app yet) |

**Classify the source type** (dlt apps only):

| Signals                                            | Source Type                        |
| -------------------------------------------------- | ---------------------------------- |
| `RESTAPIConfig` or `rest_api_resources` in task.py | `rest_api`                         |
| `sql_database` in task.py or imports               | `sql_database`                     |
| `filesystem` in task.py or imports                 | `filesystem`                       |
| Other dlt source                                   | Read import statements to identify |

**Classify the destination:**

| Signals                                         | Destination                       |
| ----------------------------------------------- | --------------------------------- |
| `.dlt/config.toml` has `[destination.iceberg]`  | `iceberg`                         |
| `.dlt/config.toml` has `[destination.postgres]` | `postgres`                        |
| `.dlt/config.toml` has `[destination.bigquery]` | `bigquery`                        |
| `.dlt/config.toml` has `[destination.duckdb]`   | `duckdb`                          |
| No destination config                           | `unknown` (or not yet configured) |

### 2. Convention learning

If `task.py` exists and app type is `dlt`, read it and extract conventions:

```
Read task.py and extract:

1. Source function:
   - Pattern: @dlt.source def {name}(...)
   - Example: @dlt.source def github_source(access_token=dlt.secrets.value)

2. Resource naming:
   - Pattern: @dlt.resource(name="{name}", ...) or "name": "{name}" in RESTAPIConfig
   - Convention: plural nouns? singular? snake_case?

3. Auth pattern:
   - BearerTokenAuth, APIKeyAuth, HttpBasicAuth, OAuth2ClientCredentials, or custom

4. Import style:
   - from dlt.sources.helpers.rest_client.paginators import ...
   - from dlt.sources.rest_api import ...

5. Write disposition:
   - replace, merge, or append

6. Incremental strategy:
   - dlt.sources.incremental("field_name", initial_value="...")
   - Which field? What initial_value format?

7. Env var bridging:
   - PYICEBERG_CATALOG__DEFAULT__* → DESTINATION__ICEBERG__CREDENTIALS__*
   - Custom secret bridging patterns

8. Pagination:
   - Explicit paginator type and config, or auto-detected

9. Pipeline naming:
   - dlt.pipeline(pipeline_name="...")

10. Existing resources:
    - List all resources with: name, endpoint path, write_disposition, primary_key, incremental field
```

If app type is `dbt`, read model files:

```
Read models/ directory structure and extract:
1. Model naming: fct_, dim_, stg_, prep_ prefixes
2. Materialization: incremental vs table vs view
3. Test patterns: schema.yml test style
4. Source definitions: sources.yml structure
```

If app type is `asgi`, read task.py for:

```
1. Framework: Starlette, FastAPI, or litestar
2. Route definitions and patterns
3. Middleware configuration
4. External service calls (databases, APIs)
5. Authentication patterns
```

If app type is `python`, read task.py for:

```
1. Tower SDK usage patterns
2. Output patterns (Iceberg writes, file output, database writes, stdout)
3. External API patterns (REST clients, LLM providers, database connections)
4. Entry point pattern (main() function, __main__ block)
```

### 3. Review history

Glob `.tower/reviews/*.md` and read the frontmatter of each:

```
For each review artifact, extract:
- persona (from frontmatter)
- date
- gate_result (APPROVE / BLOCK / OVERRIDE)
- mode
```

### 4. Read dependencies

```bash
# Extract dependencies from pyproject.toml
grep -A 50 '^\[project\]' pyproject.toml 2>/dev/null | grep -A 30 'dependencies'
# or
grep -A 50 '^\[tool.uv\]' pyproject.toml 2>/dev/null
```

### 5. Write project profile

Create the directory if needed, then write `.tower/project-profile.md`:

```bash
mkdir -p .tower
```

Write the profile with this structure:

```markdown
---
generated: { ISO 8601 timestamp }
commit: { short git hash }
---

## Stack Detection

| Signal           | Value                                              | Source         |
| ---------------- | -------------------------------------------------- | -------------- |
| Package manager  | {uv / pip / none}                                  | {evidence}     |
| Python version   | {version}                                          | pyproject.toml |
| App type         | {dlt / dbt / asgi / python / empty}                | {evidence}     |
| Source type      | {rest_api / sql_database / filesystem / n/a}       | {evidence}     |
| Destination      | {iceberg / postgres / bigquery / duckdb / unknown} | {evidence}     |
| Tower app name   | {name}                                             | Towerfile      |
| Has Towerfile    | {yes / no}                                         | file check     |
| Has .dlt/ config | {yes / no}                                         | file check     |
| Has dbt_project  | {yes / no}                                         | file check     |

## Conventions Observed

| Convention             | Value                              | Source         |
| ---------------------- | ---------------------------------- | -------------- |
| Source function naming | {pattern with example}             | task.py:{line} |
| Resource naming        | {pattern}                          | task.py:{line} |
| Auth pattern           | {type}                             | task.py:{line} |
| Import style           | {pattern}                          | task.py:{line} |
| Write disposition      | {replace / merge / append}         | task.py:{line} |
| Incremental strategy   | {field + initial_value, or "none"} | task.py:{line} |
| Env var bridging       | {pattern, or "standard iceberg"}   | task.py:{line} |
| Pagination             | {explicit type / auto-detected}    | task.py:{line} |
| Pipeline name          | {name}                             | task.py:{line} |

## Existing Resources

| Resource | Endpoint | Write Disposition      | Primary Key | Incremental Field |
| -------- | -------- | ---------------------- | ----------- | ----------------- |
| {name}   | {path}   | {merge/replace/append} | {key}       | {field or "none"} |

## Dependencies

{List from pyproject.toml}

## Review History

| Review    | Date   | Gate     | Mode   | Artifact |
| --------- | ------ | -------- | ------ | -------- |
| {persona} | {date} | {result} | {mode} | {path}   |
```

For `empty` app type (no task.py), write a minimal profile with just the stack detection table and note "No app code found — project not yet initialized."

### 6. Convention persistence to AGENTS.md

If `AGENTS.md` exists in the repo root, update the fenced conventions section:

- If `<!-- tower-conventions-start -->` marker exists: replace everything between start and end markers
- If no marker exists: append the fenced section at the end

```markdown
<!-- tower-conventions-start -->

## Project Conventions (auto-detected)

- **App type:** {dlt REST API pipeline / dbt project / ASGI app / Python script}
- **Destination:** {Tower-managed Iceberg (REST catalog) / postgres / etc.}
- **Source naming:** `{observed pattern}`
- **Auth:** {observed pattern}
- **Write disposition:** {merge / replace / append}
- **Incremental:** {observed pattern or "not configured"}
<!-- tower-conventions-end -->
```

If `AGENTS.md` does not exist, skip this step (don't create it — that's a separate concern).

---

## Completion

Report one of these status codes when the skill finishes:

| Status                 | Meaning                                                                                 |
| ---------------------- | --------------------------------------------------------------------------------------- |
| **DONE**               | Profile written to `.tower/project-profile.md`, conventions detected                    |
| **DONE_WITH_CONCERNS** | Profile written but some detection was uncertain (e.g., ambiguous app type, no task.py) |
| **BLOCKED**            | Cannot detect anything — no Python project files found                                  |
| **NEEDS_CONTEXT**      | Ambiguous signals — user must clarify (e.g., multiple entry points, mixed app types)    |

Print:

```
STATUS: {status}
Artifact: .tower/project-profile.md
App type: {detected}
Source: {detected}
Destination: {detected}
Resources: {count}
Conventions: {count detected}
```

---

## Error Recovery

**No task.py or main.py found:**
Write a minimal profile with app_type=empty. This is fine — the project may not be initialized yet. Skills that read this profile will use defaults.

**Ambiguous app type (both dlt and dbt signals):**
Use AskUserQuestion: "I found both dlt and dbt signals in your project. Which is the primary app type?"

**Cannot read Towerfile via MCP:**
Fall back to reading the file directly with the Read tool. Note in the profile that MCP read failed.

**pyproject.toml missing:**
Check for requirements.txt as fallback. If neither exists, note "no dependency manifest found."

---

## Self-Regulation

- **Don't over-detect.** If a signal is ambiguous (confidence < 70%), mark it as "uncertain" in the profile rather than guessing wrong.
- **Don't modify code.** This skill is read-only except for writing the profile and updating AGENTS.md conventions.
- **Don't block on missing signals.** Write what you found. A partial profile is better than no profile.
- **Respect existing profiles.** If a profile already exists and is fresh (commit matches HEAD), print "Profile is current — no changes needed" and exit with DONE.
