"""The integration project on dbt-clickhouse, with drex-clickhouse's functions against the mock.

The ClickHouse is drex-clickhouse's image at the release with its shipped functions config, each command given the
mock's base URL (test/clickhouse/), as .github/workflows/Tests.yml sets it up. DREX_TEST_CLICKHOUSE_PORT names its HTTP
port and DREX_TEST_CLICKHOUSE_MOCK its mock's URL; without them, these tests skip.
"""

import os

import clickhouse_connect
import e2e
import pytest
from conftest import Mock

PORT = os.environ.get("DREX_TEST_CLICKHOUSE_PORT")
pytestmark = pytest.mark.skipif(not PORT, reason="DREX_TEST_CLICKHOUSE_PORT is not set")
#: The namespace test/clickhouse/functions.py gives the functions' base URL
NAMESPACE = "clickhouse"


@pytest.fixture(scope="module")
def warehouse(integration_deps):
    env = {"DREX_CLICKHOUSE_PORT": PORT}

    def query(sql: str) -> list[tuple]:
        client = clickhouse_connect.get_client(host="127.0.0.1", port=int(PORT), username="default")
        return [tuple(row) for row in client.query(sql).result_rows]

    return env, query, Mock(os.environ["DREX_TEST_CLICKHOUSE_MOCK"])


def test_build(warehouse):
    env, query, mock = warehouse
    e2e.build("clickhouse", env, mock, NAMESPACE, query, "dbt_drex")


def test_incremental(warehouse):
    env, query, mock = warehouse
    # Without a scenario: the functions' base URL is in ClickHouse's functions config, which their pool reads only
    # when ClickHouse starts, and restarting it would take the mock in its network down with it
    e2e.incremental("clickhouse", env, mock, NAMESPACE, query, "dbt_drex")
