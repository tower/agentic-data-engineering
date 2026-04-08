# Agentic Data Engineering

## Context

AI Coding Agents have become powerful productivity booster, allowing software engineers to launch end-to-end products in hours, not weeks. For data engineering, though, coding agents still suck: vibe coded pipelines break in production, connections and secrets are poorly managed (if at all), and data models barely capture the actual business processes.

This repo closes these gaps and boost data engineering productivity along every step of the workflow. Specifically, the skills, hooks, and rules in here are not meant as a swap-in replacement for a data engineer. Instead, they will make you better at making the right design choices, asking the right questions with your stakeholders, and shipping outcomes faster through...

1. **Opinionated primitives** for effective pipeline, model, and app development
1. A lightweight python runtime, purposefully built for modern, pythonic data tools (dlt, dbt, marimo, pyceberg)
1. Fully integrated, **AI-first data platform** for secure deployments, (orchestration), and end-to-end observability

## Prerequisites

1. `uv` and `duckdb` installed on your machine (see [uv](https://docs.astral.sh/uv/getting-started/installation/), [duckdb](https://duckdb.org/install/?platform=macos&environment=cli&version=lts))
2. Claude Code API Key or -subscription. You can create one [here](https://platform.claude.com/login?returnTo=%2F%3F), we'll use < 5$ worth of credits.
3. The Tower CLI installed (`uv tool install tower` or `pip install tower`) and a Tower account [free signup](https://app.tower.dev/)

## Getting started

We're putting ourselves in the shoes of a data engineer: Our goal is to build on top of an existing data pipeline and create a small data app that notifies us when bugs are being reported through our ticketing system.

1. Clone this repository `git clone https://github.com/tower/agentic-data-engineering.git`
2. Install all dependencies: `uv sync`
3. Head to [https://app.tower.dev/](https://app.tower.dev/) -> `Env` -> `Catalogs` and create a new Tower Catalog named `default`
4. Ask claude to run the pipeline `claude "Run the pipeline"`. Some of the issues that we'll likely run into are:

- Unauthenticated API calls lead to rate limits
- Data in local DuckDB is ephemeral
- Lack of context slows down pipeline iterations/extensions

6. `git checkout agentic-de` branch and tell claude to run the pipeline again. The `agentic-de` branch comes with a full-blown harness of skills, rules, and hooks for AI coding agents to actually make our lives as data engineers easier
7. Start the tower mcp server `uvx tower mcp-server --transport sse --port 34567`
8. Launch claude and prompt it to build on top of the pipeline to receive alersts in discord whenever a bug ticket gets filed.

## Alternative ideas for vibe-coded data apps

- A bot that reviews code changes regularly, compares to docs, and suggests docks updates
