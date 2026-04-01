---
name: init-tower-app
description: Create a 'hello world' Tower app as the foundational runtime environment for dlt pipelines.
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

Create an empty Tower app

## Steps

### 0. Read project context

Read `.tower/project-profile.md` if it exists.
- If present and shows app_type is NOT `empty` (Towerfile + task.py already exist): the app is already initialized. Report DONE immediately: "Tower app already exists ({app_name}). No scaffolding needed."
- If present and shows app_type is `empty`: proceed with scaffolding as normal.
- If missing: proceed with scaffolding as normal (greenfield project).

### 1. Snapshot current folder

Run `ls -la` to see the current state before scaffolding.

### 2. Check or create uv project
Check if `uv` is available. If not, install it with `pip install uv` and then activate the venv.
If `uv` is available, and the folder snapshot shows that we're already in an active uv project, continue.
If the folder is still not a uv project, initialize it with `uv init` and activate the venv.

### 3. Install the latest version tower
Run `uv add tower>=0.1.0` to install the latest version of Tower. This ensures we have the latest features and bug fixes.

### 4. Create `task.py` script
Create a `task.py` file with the following content:
```python
import tower
if __name__ == "__main__":
    print(f"Hello from Tower version {dir(tower)}")
```

### 5. Check the Tower team
**CRITICAL: ALWAYS use tower-mcp server for ALL Tower operations.**

Check whether the user is logged into Tower and whether they are on the right team. Use the `tower_teams_list` tool from the tower-mcp server to list teams and confirm the right one is active. If the user wants to switch teams, they can do so with `tower_teams_switch` MCP tool.

### 6. Use the tower-mcp server to create & verify a Towerfile
**CRITICAL: Use tower-mcp, NOT CLI commands.**

Check whether the Towerfile lists source files explicitly. If that's the case, use the `tower_file_update` tool from tower-mcp server to replace the list with a wildcard (`*`), then use `tower_file_validate` to verify the file.

### 7. Check whether the tower app runs successfully
**CRITICAL: Use tower-mcp for running apps, NOT `uv run tower` CLI.**

Run the Tower app locally using the `tower_run_local` tool from the tower-mcp server, and check that it prints the expected message with the Tower version. Use `tower_apps_logs` to inspect output if needed.

## Completion

Report one of these status codes when the skill finishes:

| Status | Meaning |
|---|---|
| **DONE** | App scaffold created, `tower_run_local` prints Tower version successfully |
| **DONE_WITH_CONCERNS** | App runs but with warnings (e.g. outdated Tower version, team mismatch) |
| **BLOCKED** | Cannot proceed — `uv` not available and install failed, or Tower login/team check failed |
| **NEEDS_CONTEXT** | User must clarify team selection or project directory before continuing |

## Error Recovery

**`uv` not available or install fails:**
Run `pip install uv`. If that also fails (e.g. no `pip`), check whether Python is available with `python3 --version`. Suggest the user install uv manually: `curl -LsSf https://astral.sh/uv/install.sh | sh`. Status: BLOCKED if unresolvable.

**`tower_teams_list` fails (MCP not available or auth error):**
Verify the tower-mcp server is running. Ask the user to confirm they are logged into Tower. Do NOT fall back to CLI commands. Status: BLOCKED.

**`tower_file_validate` fails:**
Read the validation error message. Common causes: missing `task.py` reference, invalid YAML syntax, unsupported Towerfile fields. Fix the Towerfile and re-validate. If the error is unclear, regenerate with `tower_file_generate` and try again.

**`tower_run_local` fails on the hello-world script:**
Check `tower_apps_logs` for the error. If it is a dependency issue, run `uv add tower>=0.1.0` again. If it is a permissions or auth issue, revisit team selection.
