---
name: setup-secrets
description: Safely manage secrets as runtime environment variables. Use when the user directly asks to set up, configure, or inspect credentials (API keys, database passwords, tokens). Do NOT use when in need for reading secrets, for pipeline creation, source discovery, or debugging pipeline execution — those skills call setup-secrets when they need credentials configured.
argument-hint: "[source-name]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - WebFetch
  - WebSearch
  - mcp__tower-mcp__tower_secrets_list
  - mcp__tower-mcp__tower_secrets_create
  - mcp__tower-mcp__tower_secrets_delete
  - mcp__tower-mcp__tower_teams_list
  - mcp__tower-mcp__tower_teams_switch
---

# Set up dlt secrets

**Essential Reading**

- Credentials & config secrets in Tower's default environment: https://docs.tower.dev/docs/concepts/environments#secrets-in-the-default-environment
- How dlt loads secrets and credentials from environment variables: https://dlthub.com/docs/general-usage/credentials/setup

**CRITICAL: ALWAYS use tower-mcp server for ALL secret operations. NEVER use CLI commands or direct file access.**

**NEVER use these for secrets:**

- `.dlt/secrets.toml` — never put real credential values here; delete it if `dlt init` creates one
- `.env` files — not injected into Tower runtime
- Shell `export` / manually set environment variables — not persisted across Tower runs

**Tower secrets are the ONLY mechanism.** They are injected as environment variables into every Tower run automatically. dlt reads them via its standard env var resolution (e.g. `SOURCES__GITHUB__API_KEY` → `dlt.secrets["sources.github.api_key"]`).

Configure credentials using commands from the `tower-mcp` mcp server:

- `tower_secrets_list` - list all secrets
- `tower_secrets_create` - create new secrets (with placeholders only!)
- `tower_secrets_delete` - delete secrets
- `tower_teams_list` - find team name for UI access
- `tower_teams_switch` - switch between teams

**Read additional docs as needed:**

- Connection string credentials (databases, warehouses): `https://dlthub.com/docs/general-usage/credentials/complex_types.md`
- Built-in credential types (`GcpServiceAccountCredentials`, `AwsCredentials`, etc.): `https://dlthub.com/docs/general-usage/credentials/complex_types.md#built-in-credentials`
- Destination-specific credentials: `https://dlthub.com/docs/dlt-ecosystem/destinations/`

Parse `$ARGUMENTS`:

- `source_name` or description of what credentials are needed (e.g. "stripe api key", "postgres credentials")

## 0. Read project context

Read `.tower/project-profile.md` if it exists.

- If present: use the detected env var bridging pattern and secret naming conventions when creating new secrets. Follow the existing `SOURCES__{SOURCE}__{FIELD}` pattern.
- If missing: proceed with standard dlt secret naming conventions.

## 1. Figure out what to configure

If called from another skill, you already know the source, destination, and which fields are needed — skip to step 3.

If called standalone (e.g. user says "set up secrets" or hit `ConfigFieldMissingException`):

- Read the exception message — it tells you the exact field name and TOML path
- Read the pipeline script to find `dlt.secrets.value` parameters on `@dlt.source`/`@dlt.resource` functions
- Identify the destination type for required credentials

## 2. Research credentials

Before asking the user for values:

- **Web search** the data source for how credentials are obtained (API docs, developer portal)
- Tell the user exactly what they need and where to get it (e.g. "Go to https://dashboard.stripe.com/apikeys")
- Explain what each credential field is for

## 3. Write secrets

Use the `tower-mcp` mcp server to create and update secrets. Always use the default tower environment.

**CRITICAL: Only write placeholders** — never pass actual secret values through `secrets_update_fragment` or any other tool. The user fills in real values themselves by editing the file directly.

### Placeholders

Use **meaningful placeholders** that hint at the format:

- API keys: `"sk-*****-your-key"` or `"ak-xxxx-xxxx-xxxx"`
- Tokens: `"ghp_xxxxxxxxxxxxxxxxxxxx"` (GitHub), `"xoxb-xxxx"` (Slack)
- Passwords: `"<paste-your-password-here>"`
- URLs: `"https://your-instance.example.com"`

**Never** use the generic `"<configure me>"`.

#### Iceberg (pyiceberg REST catalog) secrets

For the iceberg destination, create env var secrets (not TOML keys). Use these exact names:

```
PYICEBERG_CATALOG__DEFAULT__URI=https://your-catalog.example.com
PYICEBERG_CATALOG__DEFAULT__WAREHOUSE=your_warehouse
PYICEBERG_CATALOG__DEFAULT__CREDENTIAL=your_client_id:your_client_secret
PYICEBERG_CATALOG__DEFAULT__SCOPE=PRINCIPAL_ROLE:your_role
```

`CREDENTIAL` is `client_id:client_secret` (colon-separated). `SCOPE` is `PRINCIPAL_ROLE:role_name` (colon-separated). pyiceberg picks these up automatically when `catalog_type = "rest"`.

## 5. Verify

Use the `tower-mcp` mcp server to see the unified merged view across all secrets. Tell the user which fields still have placeholders and how to set the real values in the tower UI.

## 6. Instruct the user

After creating placeholder secrets, **always** give the user a concrete action plan:

1. **List the exact secrets** they need to fill in, with a brief description of each and where to obtain the real value. For example:

   ```
   You need to set the following secrets:
   - SOURCES__STRIPE__API_KEY — your Stripe secret key (find it at https://dashboard.stripe.com/apikeys)
   - DESTINATION__BIGQUERY__CREDENTIALS — your GCP service account JSON (download from GCP Console > IAM > Service Accounts)
   ```

   Infer the required secret names from the `@dlt.source`/`@dlt.resource` function signatures (parameters annotated with `dlt.secrets.value`) and the destination configuration. Use the dlt env var naming convention: `SOURCES__<SOURCE_NAME>__<FIELD>` for sources, `DESTINATION__<DEST_NAME>__CREDENTIALS` for destinations.

2. **Direct them to the Tower secrets UI**:
   Use `tower_teams_list` to find the team name, then tell them:

   > Go to **https://app.tower.dev/<team-name>/default/team-settings/secrets** to update your secrets. Find each placeholder, click "Edit", replace the placeholder with the real value, and save.

   If you cannot resolve the team name, use the generic URL: `https://app.tower.dev/tower/default/team-settings/secrets`

3. **Explain where to get each credential** — link to the provider's developer portal or docs (e.g., Stripe Dashboard, GitHub Developer Settings, GCP Console).

## 6. Use secrets in Python

You can write Python scripts that read and use secrets from environment variables.

Example: you need to call the GitHub REST API and `view-redacted` shows `[sources.github] api_key = "***"`:

```py
import dlt
import requests

# reads from environment variables that are exposed in the Tower runtime — never prints the value
api_key = dlt.secrets["sources.github.api_key"]
resp = requests.get(
    "https://api.github.com/user",
    headers={"Authorization": f"Bearer {api_key}"},
)
print(resp.json()["login"])
```

You can also retrieve typed credentials:

```py
from dlt.sources.credentials import GcpServiceAccountCredentials

creds = dlt.secrets.get("destination.bigquery.credentials", GcpServiceAccountCredentials)
```

**Reference**: https://dlthub.com/docs/general-usage/credentials/advanced.md#access-configs-and-secrets-in-code

## Completion

Report one of these status codes when the skill finishes:

| Status                 | Meaning                                                                                                  |
| ---------------------- | -------------------------------------------------------------------------------------------------------- |
| **DONE**               | Placeholder secrets created, user directed to Tower UI with exact URLs and instructions                  |
| **DONE_WITH_CONCERNS** | Placeholders created but some secret names could not be determined (e.g. undocumented auth requirements) |
| **BLOCKED**            | tower-mcp not available, or `tower_secrets_create` fails repeatedly                                      |
| **NEEDS_CONTEXT**      | User must clarify which credentials are needed, or which auth method to use                              |

## Error Recovery

**`tower_secrets_create` fails:**
Check the error message. Common causes: MCP server not running, auth expired, or secret name conflicts with an existing secret. For conflicts, use `tower_secrets_list` to check existing secrets and `tower_secrets_delete` to remove stale ones before retrying. If MCP is down, Status: BLOCKED.

**User does not know where to get credentials:**
Research the data source — web search for `<service-name> API key` or `<service-name> developer portal`. Provide step-by-step instructions with direct links to the provider's credential page. Do not ask the user to paste credentials into the chat.

**Secret naming convention unclear:**
Refer to dlt's env var resolution: `SOURCES__<SOURCE_NAME>__<FIELD>` for source secrets, `DESTINATION__<DEST_NAME>__CREDENTIALS__<FIELD>` for destination secrets. Read the `@dlt.source` function signature to find the exact parameter names annotated with `dlt.secrets.value`.

**Secrets created but pipeline still raises `ConfigFieldMissingException`:**
The placeholder values are still in place — remind the user to replace them with real values in the Tower UI. Verify the secret names match dlt's expected env var names exactly (case-sensitive, double underscores).
