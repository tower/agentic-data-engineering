import dlt
from dlt.sources.rest_api import rest_api_source


def main():
    source = rest_api_source(
        {
            "client": {
                "base_url": "https://api.github.com/repos/anthropics/claude-code/",
                "paginator": "header_link",
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

    pipeline = dlt.pipeline(
        pipeline_name="claude_code_issues",
        destination="duckdb",
        dataset_name="github",
    )

    load_info = pipeline.run(source)
    print(load_info)


if __name__ == "__main__":
    main()
