"""Every SQL example of the docs, built as a model on each warehouse against the mock Drex API.

The ```sql blocks of README.md and docs/API.md, and of the Drex docs page (docs-site/integrations/dbt.mdx of
nace-ai/drex) when DREX_DOCS_DBT_MDX names it, each become a model in a copy of integration_tests/ whose `tickets` seed
has the docs' `ticket_id`. A block that starts with `or` is spliced into the `where` of the incremental block before it,
as the docs say to add it. Each doc's project is built twice, so the incremental model runs its incremental branch.

DuckDB always runs; Postgres and ClickHouse run when their DREX_TEST_* variables are set, as in test_postgres.py and
test_clickhouse.py. On ClickHouse, a drex_choice with descriptions fails to compile, as the docs say, and the models
reading it are skipped; everything else builds.
"""

import json
import os
import re
import shutil
from pathlib import Path

import pytest
from conftest import INTEGRATION, MOCK_KEY, ROOT, dbt

DOCS = {"readme": ROOT / "README.md", "api": ROOT / "docs/API.md"}
if os.environ.get("DREX_DOCS_DBT_MDX"):
    DOCS["mdx"] = Path(os.environ["DREX_DOCS_DBT_MDX"])

TARGETS = {
    "duckdb": None,
    "postgres": "DREX_TEST_POSTGRES_PORT",
    "clickhouse": "DREX_TEST_CLICKHOUSE_PORT",
}
SCHEMA = "dbt_drex_snippets"
#: A model the docs' "Reading results" reads, with a choice and a score per ticket
TICKET_ANSWERS = """select
    ticket_id,
    {{ drex.drex_choice("body", "Which team?", ["billing", "technical", "sales"]) }} as team,
    {{ drex.drex_score("body", "How urgent?", ["can wait", "this week", "today"]) }} as urgency
from {{ ref("tickets") }}
"""
#: A drex_choice whose labels are a dict, or a list of {label, description}, which ClickHouse's drex_choice refuses
DESCRIBED_CHOICE = re.compile(r"drex\.drex_choice\([^{}\[\]]*(\{|\[\s*\{)")


def snippets(path: Path) -> dict[str, str]:
    """The doc's SQL blocks as models, by name."""
    blocks = re.findall(r"^```sql\n(.*?)^```", path.read_text(), flags=re.DOTALL | re.MULTILINE)
    assert blocks, f"{path} has no SQL blocks"
    models: list[str] = []
    for block in blocks:
        if block.lstrip().startswith("or "):
            incremental = next(i for i in reversed(range(len(models))) if "is_incremental()" in models[i])
            where = models[incremental].rindex("{% endif %}")
            models[incremental] = models[incremental][:where] + block + models[incremental][where:]
        else:
            models.append(block)
    named = {f"{path.stem.lower()}_{i}": sql for i, sql in enumerate(models, 1)}
    # The model the docs' threshold examples read, from the first block that asks a team of each ticket
    if any('ref("ticket_teams")' in sql for sql in models):
        first = next(name for name, sql in named.items() if 'ref("tickets")' in sql and "as team" in sql)
        named["ticket_teams"] = named.pop(first)
    if any('ref("ticket_answers")' in sql for sql in models):
        named["ticket_answers"] = TICKET_ANSWERS
    return named


def project(tmp_path: Path, models: dict[str, str]) -> Path:
    """A copy of integration_tests/ with these models, in a schema of its own, and the docs' column names."""
    path = tmp_path / "project"
    shutil.copytree(
        INTEGRATION, path, ignore=shutil.ignore_patterns("target", "logs", "dbt_packages", "package-lock.yml", "models")
    )
    (path / "packages.yml").write_text(f"packages:\n  - local: {ROOT}\n")
    profiles = path / "profiles.yml"
    profiles.write_text(profiles.read_text().replace("schema: dbt_drex", f"schema: {SCHEMA}"))
    (path / "seeds/images.csv").unlink()
    tickets = path / "seeds/tickets.csv"
    tickets.write_text(tickets.read_text().replace("id,", "ticket_id,", 1))
    (path / "models").mkdir()
    for name, sql in models.items():
        (path / "models" / f"{name}.sql").write_text(sql)
    dbt(path, "deps")
    return path


def run_results(path: Path) -> dict[str, str]:
    results = json.loads((path / "target/run_results.json").read_text())["results"]
    return {result["unique_id"].split(".")[-1]: result["status"] for result in results}


def expected(models: dict[str, str], target: str) -> dict[str, str]:
    """Each node's status: on ClickHouse, a described drex_choice errors and the models reading it are skipped."""
    statuses = {"tickets": "success", **dict.fromkeys(models, "success")}
    if target == "clickhouse":
        for name, sql in models.items():
            if DESCRIBED_CHOICE.search(sql):
                statuses[name] = "error"
                for child, child_sql in models.items():
                    if f'ref("{name}")' in child_sql:
                        statuses[child] = "skipped"
    return statuses


@pytest.fixture
def env(request, mock, tmp_path):
    target = request.param
    variable = TARGETS[target]
    if variable and not os.environ.get(variable):
        pytest.skip(f"{variable} is not set")
    if target == "duckdb":
        return target, {
            "NACE_API_KEY": MOCK_KEY,
            "NACE_BASE_URL": mock.base_url("snippets"),
            "DREX_DUCKDB_PATH": str(tmp_path / "snippets.duckdb"),
            "DREX_DUCKDB_EXTENSIONS": os.environ.get("DREX_DUCKDB_EXTENSIONS") or str(tmp_path / "extensions"),
        }
    port = os.environ[variable]
    return target, {"DREX_POSTGRES_PORT": port} if target == "postgres" else {"DREX_CLICKHOUSE_PORT": port}


@pytest.mark.parametrize("doc", DOCS)
@pytest.mark.parametrize("env", TARGETS, indirect=True)
def test_doc_snippets_build(doc, env, tmp_path):
    target, variables = env
    models = snippets(DOCS[doc])
    path = project(tmp_path, models)
    statuses = expected(models, target)
    failing = "error" in statuses.values()
    for build in ("first", "second"):
        output = dbt(path, "build", "--target", target, env=variables, check=not failing)
        assert run_results(path) == statuses, f"{build} build:\n{output}"
        if failing:
            assert "ClickHouse's drex_choice takes plain labels" in output
