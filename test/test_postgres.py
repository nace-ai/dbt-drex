"""The integration project on dbt-postgres, with drex-postgres's pgsql-http variant against the mock.

The Postgres is drex-postgres's test image (its docker/Dockerfile at the release), which runs the mock in the same
container, with drex_http.sql installed and its key and base URL in drex_settings, as .github/workflows/Tests.yml sets
it up. DREX_TEST_POSTGRES_PORT names its Postgres port and DREX_TEST_POSTGRES_MOCK its mock's URL; without them, these
tests skip.
"""

import base64
import json
import os
import sys

import e2e
import psycopg2
import pytest
from conftest import ROOT, Mock, dbt

sys.path.insert(0, str(ROOT / "test/mock"))
import pngs  # noqa: E402

PORT = os.environ.get("DREX_TEST_POSTGRES_PORT")
pytestmark = pytest.mark.skipif(not PORT, reason="DREX_TEST_POSTGRES_PORT is not set")
#: The namespace drex_settings.base_url names
NAMESPACE = "postgres"
#: The mock's URL inside drex-postgres's test image
MOCK_IN_IMAGE = "http://127.0.0.1:8787"


def connect():
    return psycopg2.connect(host="127.0.0.1", port=int(PORT), user="postgres", password="postgres", dbname="postgres")


@pytest.fixture(scope="module")
def warehouse(integration_deps):
    env = {"DREX_POSTGRES_PORT": PORT}

    def query(sql: str) -> list[tuple]:
        with connect() as connection, connection.cursor() as cursor:
            cursor.execute(sql)
            return cursor.fetchall()

    return env, query, Mock(os.environ["DREX_TEST_POSTGRES_MOCK"])


def test_build(warehouse):
    env, query, mock = warehouse
    e2e.build("postgres", env, mock, NAMESPACE, query, "dbt_drex")


def test_incremental(warehouse):
    env, query, mock = warehouse

    def scenario(name: str) -> dict[str, str]:
        """drex_settings names the mock as the image's Postgres reaches it, inside the container"""
        with connect() as connection, connection.cursor() as cursor:
            cursor.execute("update public.drex_settings set base_url = %s", (f"{MOCK_IN_IMAGE}/ns/{NAMESPACE}/{name}",))
        return env

    e2e.incremental("postgres", env, mock, NAMESPACE, query, "dbt_drex", scenario)


def test_images_in_order_with_drex_max(warehouse):
    """drex_decide_image defaults to Drex Max, and sends the images in the order given."""
    env, query, mock = warehouse
    mock.reset(NAMESPACE)
    dbt(e2e.INTEGRATION, "run", "--target", "postgres", "--select", "image_decisions", env=env)
    requests = mock.requests(NAMESPACE)
    assert [(r["model"], r["image_colours"]) for r in requests] == [
        ("drex-max", ["red"]),
        ("drex-max", ["red", "blue"]),
        ("drex-max", ["blue", "red"]),
    ]
    answers = {
        order: decision["answers"]["first"]["choice"]
        for order, decision in query("select images_order, decision from dbt_drex.image_decisions")
    }
    assert answers == {"red": "red", "red_then_blue": "red", "blue_then_red": "blue"}
    # The seed holds the mock's own fixtures
    seed = dict(query("select name, png_base64 from dbt_drex.images"))
    assert {name: base64.b64decode(png) for name, png in seed.items()} == {n: pngs.fixture(n) for n in ("red", "blue")}
    assert json.loads(requests[0]["questions"])[0]["criteria"] == {"red": None, "blue": None}
