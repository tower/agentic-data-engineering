---
name: find-source
description: Find a dlt source for a given API or data provider. Use when the user asks about a source, wants to find a connector, or asks to implement a pipeline for a specific data source.
argument-hint: "[source-name] [context]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - WebFetch
  - WebSearch
---

# Find a dlt source

Locate the best dlt source for what the user wants to extract data from.

Parse `$ARGUMENTS`:

- `source-name` (required): what the user wants to extract data from (e.g., "alpaca markets", "stripe", "postgres", "csv files", "rest api")
- everything after that: additional context, i.e. which data the user wants to ingest. In case the user does not specify, ask them which data they want to ingest.

## Steps

### 0. Read project context

Read `.tower/project-profile.md` if it exists.

- If present and shows existing resources: acknowledge them. If the user is asking about a new source for an existing pipeline, this is an EXPANSION — note existing source type and conventions.
- If present and shows source_type already configured: confirm whether the user wants to add to the existing source or switch to a different one.
- If missing: proceed as greenfield.

### 1. Classify the request

| User says (examples)                                         | Core source    |
| ------------------------------------------------------------ | -------------- |
| postgres, mysql, mssql, oracle, database, db, sql            | `sql_database` |
| rest api, http api, web api, rest                            | `rest_api`     |
| files, csv, parquet, jsonl, s3, gcs, azure blob, local files | `filesystem`   |

If it matches a core source, skip to **step 5** and report the core source match.

### 2. Search verified sources

If the request looks like a specific API/service name, run:

```
dlt --non-interactive init --list-sources
```

Search the output (case-insensitive) for the source name. If found, skip to **step 5**

### 3. Search dlthub context

Use `search_dlthub_sources` mcp tool to look for sources. It is FTS based so pass only essential keywords to it
ie. "claude analytics". You'll get description of the source and set of reference links to use in web search below.

### 4. Web search and validation

1. Confirm what you've found in **step 3** on the web. Extend the information on the endpoints and data they contains.
2. Perform additional web search to look for better alternatives.
3. **Avoid** 3rd party providers, integrators and proxies. Prefer **authoritative** answers ie.

```
query: <source-name> API documentation
```

4. Read **step 6** on what you will present to the user at the end.

NOTE: we can handle only REST API (**step 5**) and sometimes GraphQL.

### 5. Decide: is this a REST API pipeline?

This toolkit builds **REST API pipelines**. Before continuing, check if the user's data source actually fits.

**STOP and hand off** if any of these are true:

- **Core source is NOT `rest_api`** — the user needs `sql_database`, `filesystem`, or another core source. Tell them which one and the `dlt init` command, then suggest a general coding session to build the pipeline.
- **A verified source exists** (from step 2) — a pre-built, maintained connector is almost always better than building from scratch. Tell the user about it and the `dlt init <source> <destination>` command. Suggest they try the verified source first.

```
Found: <verified source or non-REST core source>
  Command: dlt init <source> <destination>

This is outside the REST API pipeline workflow. You can:
  1. Use the verified source / core source above (recommended)
  2. Start a general coding session if you need a custom pipeline
```

**CONTINUE** only when the best path is building a REST API pipeline — either because:

- The user explicitly asked for REST API / HTTP API
- The data source is a REST API with no verified source available
- A dlthub context source was found (these use the `rest_api` core source under the hood)

### 6. Present findings

1. **high intent user** told you exactly what they want - exact API, endpoint or provider. If you have it - present the result. Only if not - alternatives
2. **low intent user** told you about the goals and why they need data. Allow them to make informed decision. Conversation will be needed!
3. Summarize

- Determine how many genuinely distinct options the user has.
  A **viable option** is one that genuinely differs in tradeoffs — not every search result is a separate option. Only surface choices where the user's preference would actually matter (e.g. a paid source vs. a free public API they could hit directly). If one option is clearly best, just present that one.
- For each viable option, briefly describe what it provides, its init command, and what it requires (check the dlthub source page for requirements and use knowledge of the underlying API for its own access model).

### 7. Ask to pick single endpoint

**CRITICAL: Use the AskUserQuestion tool** to ask the user to pick a single endpoint. Present each viable endpoint as a concrete option with a description. Make the recommended endpoint the first option with "(Recommended)" in the label. Do NOT ask via plain text output.

Do NOT run `dlt init` yet — wait for user confirmation.
After that continue workflow in `create-rest-api-pipeline` skill

## Completion

Report one of these status codes when the skill finishes:

| Status                 | Meaning                                                                             |
| ---------------------- | ----------------------------------------------------------------------------------- |
| **DONE**               | Source identified, user confirmed the source and starting endpoint                  |
| **DONE_WITH_CONCERNS** | Source found but with caveats (e.g. limited API docs, unclear auth model, beta API) |
| **BLOCKED**            | No viable source found after exhausting all search paths                            |
| **NEEDS_CONTEXT**      | User must clarify which data they want or choose between multiple viable options    |

## Error Recovery

**No source found in verified sources or dlthub context:**
Broaden the search — try alternative names, parent company names, or the underlying API provider. For example, if "acme analytics" returns nothing, search for the API it wraps. If still nothing, check whether the service exposes a REST API at all (some only offer SDKs or GraphQL).

**dlthub search returns irrelevant results:**
Do not force-fit a bad match. Fall back to web search for `<service-name> REST API documentation` to confirm whether a REST API exists. If it does, the `rest_api` core source can be used with manual configuration.

**Source exists but is not a REST API (e.g. GraphQL-only, SDK-only):**
Tell the user this is outside the REST API pipeline workflow. Suggest a general coding session or check if a verified source exists via `dlt init --list-sources`. Status: BLOCKED for this toolkit.

**User cannot decide between options:**
Present a clear comparison table with tradeoffs. If still stuck, recommend starting with the simplest option (fewest auth requirements, best documentation). Status: NEEDS_CONTEXT until resolved.
