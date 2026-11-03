"""The integration project on dbt-duckdb and DuckDB 2.0, with drex-duckdb installed from community extensions."""

import duckdb
import e2e
import pytest
from conftest import MOCK_KEY


@pytest.fixture(scope="module")
def warehouse(mock, integration_deps, tmp_path_factory):
    directory = tmp_path_factory.mktemp("duckdb")
    env = {
        "NACE_API_KEY": MOCK_KEY,
        "NACE_BASE_URL": mock.base_url("duckdb"),
        "DREX_DUCKDB_PATH": str(directory / "drex.duckdb"),
        # Its own extension directory, so the test installs drex (and httpfs) as a new user would
        "DREX_DUCKDB_EXTENSIONS": str(directory / "extensions"),
    }

    def query(sql: str) -> list[tuple]:
        with duckdb.connect(env["DREX_DUCKDB_PATH"], read_only=True) as connection:
            return connection.sql(sql).fetchall()

    return env, query


def test_build(warehouse, mock):
    env, query = warehouse
    e2e.build("duckdb", env, mock, "duckdb", query, "main")


def test_incremental(warehouse, mock):
    env, query = warehouse

    def scenario(name: str) -> dict[str, str]:
        return {**env, "NACE_BASE_URL": mock.base_url("duckdb", name)}

    e2e.incremental("duckdb", env, mock, "duckdb", query, "main", scenario)
