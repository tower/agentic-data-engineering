#

## Context
AI Coding Agents have become powerful productivity booster, allowing software engineers to launch end-to-end products in hours, not weeks. For data engineering, though, coding agents still suck: vibe coded pipelines break in production, connections and secrets are poorly managed (if at all), and data models barely capture the actual business processes.

This repo closes these gaps and boost data engineering productivity along every step of the workflow. Specifically, the skills, hooks, and rules in here are not meant as a swap-in replacement for a data engineer. Instead, they will make you better at making the right design choices, asking the right questions with your stakeholders, and shipping outcomes faster through...

1. **Opinionated primitives** for effective pipeline, model, and app development
1. A lightweight python runtime, purposefully built for modern, pythonic data tools (dlt, dbt, marimo, pyceberg)
1. Fully integrated, **AI-first data platform** for secure deployments, (orchestration), and end-to-end observability

## Prerequisites
1. `uv` and `duckdb` installed on your machine (see [uv](https://docs.astral.sh/uv/getting-started/installation/), [duckdb](https://duckdb.org/install/?platform=macos&environment=cli&version=lts))
2. Access to any AI coding agent that supports the [Agent Skills Open Format](https://agentskills.io/home), e.g. Claude, Cursor, Codex, AntiGravity, etc.
3. A Tower account [free signup](https://app.tower.dev/)

## TODOs:
- [ ] Do we have a free tier for the Hackathon?
- [ ] Lets try to get free credis from Anthropic?
- [ ]

## Getting started
We're putting ourselves in the shoes of a data engineer: Our goal is to build on top of an existing data pipeline and create a small data app that notifies us when bugs are being reported through our ticketing system.
1. Clone this repository
2. Checkout the `start-here` branch (`git checkout start-here`)
2. Install all dependencies: `uv sync`
3. Ask claude to run the pipeline `claude "Run the pipeline"`. Some of the issues that we'll likely run into are:
- Unauthenticated API calls lead to rate limits -> Need a runtime with credentials
- Local DuckDB destination makes it hard to activate loaded data -> Need a remote destination 
- Lack of context makes the pipeline tough to extend -> Need richer context
4. Checkout the `main` branch and tell claude to run the pipeline again. The `main` branch comes with a full-blown harness of skills, rules, and hooks for AI coding agents to actually make our lives as data engineers easier


