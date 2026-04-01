---
persona: plan-business-analyst-review
app: github-claude-code
mode: SCOPE_CHECK
date: 2026-03-31
gate_result: APPROVE
commit: pre-code
---

## Scope Brief

**Goal:** Fetch all issues (not PRs) from the public anthropics/claude-code GitHub repo for ticket analysis.
**Consumer:** User / analyst querying Iceberg tables
**Source:** GitHub REST API
**Destination:** Tower-managed Iceberg

## Endpoints / Resources

| Endpoint | Entity | Purpose | Primary Key | Incremental Field |
|----------|--------|---------|-------------|-------------------|
| /repos/anthropics/claude-code/issues | issues | All repo issues (filtered, no PRs) | id | updated_at |

## Grain

Event-level — one row per issue. Point-in-time snapshots via incremental merge on `updated_at`.

## Scope Decisions

**Included:** Issues endpoint only, filtered to exclude pull requests (issues have no `pull_request` key).
**Excluded:** Pull requests (not needed), comments (not requested), labels (available as nested field on issues), milestones, projects.

## User Decisions

- Q: Filter to issues only, or include comments/labels? → A: Issues only

## Gate Result

APPROVE — high-intent request with clear source, endpoint, and destination.
