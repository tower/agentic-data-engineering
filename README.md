# Agentic Data Engineering

## Context

AI Coding Agents have become powerful productivity booster, allowing software engineers to launch end-to-end products in hours, not weeks. For data engineering, though, coding agents still suck: vibe coded pipelines break in production, connections and secrets are poorly managed (if at all), and data models barely capture the actual business processes.

This repo closes these gaps and boost data engineering productivity along every step of the workflow. Specifically, the skills, hooks, and rules in here are not meant as a swap-in replacement for a data engineer. Instead, they will make you better at making the right design choices, asking the right questions with your stakeholders, and shipping outcomes faster through...

1. **Opinionated primitives** for effective pipeline, model, and app development
1. A lightweight python runtime, purposefully built for modern, pythonic data tools (dlt, dbt, marimo, pyceberg)
1. Fully integrated, **AI-first data platform** for secure deployments, (orchestration), and end-to-end observability

## Prerequisites

1. `uv`, `duckdb`, and `claude code` installed on your machine (see [uv](https://docs.astral.sh/uv/getting-started/installation/), [duckdb](https://duckdb.org/install/?platform=macos&environment=cli&version=lts), [claude code](https://code.claude.com/docs/en/quickstart#step-1-install-claude-code))
2. The Tower CLI installed (`uv tool install tower` or `pip install tower`) and a Tower account [free signup](https://app.tower.dev/)

## Getting started

We're putting ourselves in the shoes of a data engineer: Our goal is to build on top of an existing data pipeline and create a small data app that notifies us when bugs are being reported through our ticketing system.

1. Join our Tutorial discord channel [https://discord.gg/HGe3RYZP](https://discord.gg/HGe3RYZP)
2. Clone this repository `git clone https://github.com/tower/agentic-data-engineering.git`
3. Install all dependencies: `uv sync`
4. Set the Anthropic credentials in your shell `export ANTHROPIC_API_KEY=<api-key>`
5. Head to [https://app.tower.dev/](https://app.tower.dev/) -> `Env` -> `Catalogs` and create a new Tower Catalog named `default`
6. Start the tower mcp server `uvx tower mcp-server --transport sse --port 34567` and check that claude can connect to it using the `/mcp` slash command
7. From there, we will continue working together. Please also use the discord channel for questions.

## Alternative ideas for vibe-coded data apps

- A CS slackbot that answer questions based on our internal notion / linear and external docs
- Feel free to bring your own
