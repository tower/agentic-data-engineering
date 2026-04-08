import dlt
import requests


BASE_URL = "https://api.github.com/repos/anthropics/claude-code"


@dlt.source(name="github_issues")
def github_source():
    return issues()


@dlt.resource(
    name="issues",
    primary_key="id",
    write_disposition="merge",
)
def issues(
    updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
        "updated_at",
        initial_value="2024-01-01T00:00:00Z",
    ),
):
    session = requests.Session()
    url = f"{BASE_URL}/issues"
    params = {
        "state": "all",
        "sort": "updated",
        "direction": "desc",
        "since": updated_at.last_value or "2024-01-01T00:00:00Z",
        "per_page": 100,
    }

    while url:
        response = session.get(url, params=params)
        response.raise_for_status()
        yield from response.json()
        url = response.links.get("next", {}).get("url")
        params = {}


def main():
    pipeline = dlt.pipeline(
        pipeline_name="claude_code_issues",
        destination="duckdb",
        dataset_name="github",
    )
    load_info = pipeline.run(github_source())
    print(load_info)


if __name__ == "__main__":
    main()
