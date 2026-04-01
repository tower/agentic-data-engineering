import os

import dlt
import requests
from dlt.sources.rest_api import rest_api_source

dev_mode = True


def send_discord_alert(issue):
    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL")
    if not webhook_url:
        print("DISCORD_WEBHOOK_URL not set, skipping alert")
        return

    labels = [l["name"] for l in issue.get("labels", [])]
    title = issue.get("title", "Untitled")
    url = issue.get("html_url", "")
    user = issue.get("user", {}).get("login", "unknown")
    number = issue.get("number", "?")

    embed = {
        "title": f"Bug #{number}: {title}",
        "url": url,
        "description": (issue.get("body") or "")[:300],
        "color": 0xD32F2F,
        "fields": [
            {"name": "Author", "value": user, "inline": True},
            {"name": "Labels", "value": ", ".join(labels) or "bug", "inline": True},
        ],
    }

    requests.post(webhook_url, json={"embeds": [embed]}, timeout=10)
    print(f"Discord alert sent for issue #{number}")


def alert_on_new_bugs(issue):
    """Passthrough map that sends a Discord alert for newly created bug issues."""
    labels = [l["name"] for l in issue.get("labels", [])]
    is_bug = "bug" in labels
    is_new = issue.get("created_at") == issue.get("updated_at")
    if is_bug and is_new:
        send_discord_alert(issue)
    return issue


def main():
    source = rest_api_source(
        {
            "client": {
                "base_url": "https://api.github.com/repos/anthropics/claude-code/",
                "paginator": "header_link",
                "auth": {
                    "token": os.environ["SOURCES__GITHUB_ISSUES__AUTH__TOKEN"],
                },
            },
            "resource_defaults": {
                "primary_key": "id",
                "write_disposition": "merge",
                "endpoint": {
                    "params": {
                        "per_page": 100,
                    },
                },
            },
            "resources": [
                {
                    "name": "issues",
                    "endpoint": {
                        "path": "issues",
                        "params": {
                            "state": "all",
                            "sort": "updated",
                            "direction": "desc",
                            "since": "{incremental.start_value}",
                        },
                        "incremental": {
                            "cursor_path": "updated_at",
                            "initial_value": "2024-01-01T00:00:00Z",
                        },
                    },
                },
            ],
        },
        name="github_issues",
    )

    source.issues.add_map(alert_on_new_bugs)

    # Use Tower-managed Iceberg in production, duckdb for local dev
    if dev_mode:
        destination = "duckdb"
    else:
        destination = "iceberg"

    pipeline = dlt.pipeline(
        pipeline_name="claude_code_issues",
        destination=destination,
        dataset_name="github",
    )

    if dev_mode:
        source.add_limit(1)

    load_info = pipeline.run(source, loader_file_format="parquet")
    print(load_info)


if __name__ == "__main__":
    main()
