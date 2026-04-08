---
name: init-tower-app
description: Create a Tower app — either a hello-world scaffold (greenfield) or a wrapper around existing Python pipeline code.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
  - mcp__tower-mcp__tower_teams_list
  - mcp__tower-mcp__tower_teams_switch
  - mcp__tower-mcp__tower_file_generate
  - mcp__tower-mcp__tower_file_update
  - mcp__tower-mcp__tower_file_validate
  - mcp__tower-mcp__tower_file_read
  - mcp__tower-mcp__tower_run_local
  - mcp__tower-mcp__tower_apps_logs
  - mcp__tower-mcp__tower_apps_show
---

# Create a new Tower app

Create a Tower app. Two modes: SCAFFOLD (greenfield) or WRAP (existing Python code).

## Steps

### 0. Read project context and detect mode

Read `.tower/project-profile.md` if it exists.

- If present and shows app_type is NOT `empty` (Towerfile already exists): the app is already initialized. Report DONE immediately: "Tower app already exists ({app_name}). No scaffolding needed."
- If present and shows app_type is `empty`: check for existing scripts (below).
- If missing: check for existing scripts (below).

**Detect existing Python scripts:**

If no `Towerfile` exists, scan for Python files that could be Tower apps:

```bash
find . -name "*.py" -not -path "./.venv/*" -not -path "./__pycache__/*" -not -name "setup.py" -not -name "conftest.py" -not -name "noxfile.py" 2>/dev/null | head -20
```

If matches are found:

- **WRAP mode**: Identify the primary script. Preference order:
  1. Files with `dlt.pipeline` (dlt pipeline)
  2. Files with `Starlette` or `FastAPI` or `app = ` (ASGI app)
  3. Files with `if __name__` (any Python script)
  4. First match
- If ambiguous (multiple candidates), ask the user: "I found these Python files: {list}. Which one is your main entry point?"
- Store the identified script path as `$EXISTING_SCRIPT`.
- Classify the app type: `dlt` (has dlt imports), `asgi` (has Starlette/FastAPI), or `python` (everything else).

If no matches are found:

- **SCAFFOLD mode**: Proceed with the existing hello-world flow.

### 1. Snapshot current folder

Run `ls -la` to see the current state before scaffolding.

### 2. Check or create uv project

Check if `uv` is available. If not, install it with `pip install uv` and then activate the venv.
If `uv` is available, and the folder snapshot shows that we're already in an active uv project, continue.
If the folder is still not a uv project, initialize it with `uv init` and activate the venv.

### 3. Install the latest version tower

Run `uv add tower>=0.1.0` to install the latest version of Tower. This ensures we have the latest features and bug fixes.

### 4. Create `task.py` entry point (mode-dependent)

**SCAFFOLD mode** (no existing scripts):

Create a `task.py` file with the following content:

```python
import tower
if __name__ == "__main__":
    print(f"Hello from Tower version {dir(tower)}")
```

**WRAP mode** (existing script at `$EXISTING_SCRIPT`):

Do NOT delete, rename, or restructure the user's existing files.

If `$EXISTING_SCRIPT` is already named `task.py`: skip this step entirely — the entry point already exists.

Otherwise, create a thin `task.py` wrapper based on the detected app type:

**dlt or Python script with a `main()` function** — prefer a direct import:

```python
"""Tower entry point — wraps existing script."""
from $MODULE import main

if __name__ == "__main__":
    main()
```

**ASGI app** (exports an `app` object like `app = FastAPI()` or `app = Starlette()`):

Tower natively serves ASGI apps. Create a `task.py` that re-exports the app:

```python
"""Tower entry point — wraps existing ASGI app."""
from $MODULE import app  # noqa: F401
```

Tower will detect the `app` object and serve it automatically. No uvicorn startup needed.

**No clear callable entry point** — use subprocess:

```python
"""Tower entry point — wraps existing script."""
import subprocess
import sys

if __name__ == "__main__":
    sys.exit(subprocess.call([sys.executable, "$EXISTING_SCRIPT"]))
```

Replace `$MODULE` and `$EXISTING_SCRIPT` with actual values (e.g., `from pipeline import main`).

### 5. Check the Tower team

**CRITICAL: ALWAYS use tower-mcp server for ALL Tower operations.**

Check whether the user is logged into Tower and whether they are on the right team. Use the `tower_teams_list` tool from the tower-mcp server to list teams and confirm the right one is active. If the user wants to switch teams, they can do so with `tower_teams_switch` MCP tool.

### 6. Use the tower-mcp server to create & verify a Towerfile

**CRITICAL: Use tower-mcp, NOT CLI commands.**

Check whether the Towerfile lists source files explicitly. If that's the case, use the `tower_file_update` tool from tower-mcp server to replace the list with a wildcard (`*`), then use `tower_file_validate` to verify the file.

**WRAP mode:** The wildcard `*` is strongly preferred since it covers both `task.py` and `$EXISTING_SCRIPT` (plus any local modules the script imports).

### 7. Check whether the tower app runs successfully

**CRITICAL: Use tower-mcp for running apps, NOT `uv run tower` CLI.**

Run the Tower app locally using the `tower_run_local` tool from the tower-mcp server. Use `tower_apps_logs` to inspect output if needed.

- **SCAFFOLD mode**: Expect the Tower version print message.
- **WRAP mode**: Expect the existing script to run. If it fails due to missing credentials or external dependencies (e.g. `ConfigFieldMissingException`), that counts as SUCCESS for this step — it means the Tower wrapper structure is correct. Report what credentials or setup the user needs next.

## Completion

Report one of these status codes when the skill finishes:

| Status                 | Meaning                                                                                                                                                         |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **DONE**               | App created. SCAFFOLD: `tower_run_local` prints Tower version. WRAP: `tower_run_local` executes existing script/serves ASGI app (or fails on credentials only). |
| **DONE_WITH_CONCERNS** | App runs but with warnings (e.g. outdated Tower version, team mismatch, missing credentials in WRAP mode)                                                       |
| **BLOCKED**            | Cannot proceed — `uv` not available and install failed, or Tower login/team check failed                                                                        |
| **NEEDS_CONTEXT**      | User must clarify team selection or project directory before continuing                                                                                         |

## Error Recovery

**`uv` not available or install fails:**
Run `pip install uv`. If that also fails (e.g. no `pip`), check whether Python is available with `python3 --version`. Suggest the user install uv manually: `curl -LsSf https://astral.sh/uv/install.sh | sh`. Status: BLOCKED if unresolvable.

**`tower_teams_list` fails (MCP not available or auth error):**
Verify the tower-mcp server is running. Ask the user to confirm they are logged into Tower. Do NOT fall back to CLI commands. Status: BLOCKED.

**`tower_file_validate` fails:**
Read the validation error message. Common causes: missing `task.py` reference, invalid YAML syntax, unsupported Towerfile fields. Fix the Towerfile and re-validate. If the error is unclear, regenerate with `tower_file_generate` and try again.

**`tower_run_local` fails on the hello-world script:**
Check `tower_apps_logs` for the error. If it is a dependency issue, run `uv add tower>=0.1.0` again. If it is a permissions or auth issue, revisit team selection.
