"""Shared fixtures: dbt runs, and the mock Drex API (test/mock/drex_mock.py, drex-duckdb's, copied unchanged)."""

import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
INTEGRATION = ROOT / "integration_tests"
DBT = Path(sys.executable).parent / "dbt"
#: A key of the shape Drex's keys have, which the mock accepts
MOCK_KEY = "nace_sk_" + "m" * 43


def dbt(project: Path, *args: str, env: dict[str, str] | None = None, check: bool = True) -> str:
    """Runs dbt in `project` with its own profiles.yml, returning its output; fails the test on an error."""
    result = subprocess.run(
        [str(DBT), *args, "--project-dir", str(project), "--profiles-dir", str(project), "--no-use-colors"],
        cwd=project,
        env={**os.environ, "DBT_SEND_ANONYMOUS_USAGE_STATS": "false", **(env or {})},
        capture_output=True,
        text=True,
    )
    output = result.stdout + result.stderr
    if check and result.returncode != 0:
        pytest.fail(f"dbt {' '.join(args)} failed:\n{output}")
    return output


class Mock:
    """The mock Drex API, its request log read per namespace."""

    def __init__(self, url: str):
        self.url = url

    def base_url(self, namespace: str, scenario: str = "ok") -> str:
        return f"{self.url}/ns/{namespace}/{scenario}"

    def requests(self, namespace: str) -> list[dict]:
        """The namespace's /v1/systemone requests since its last reset, oldest first."""
        with urllib.request.urlopen(f"{self.url}/__log/{namespace}") as response:
            records = [json.loads(line) for line in response.read().decode().splitlines() if line.strip()]
        return [record for record in records if record["endpoint"] == "/v1/systemone"]

    def reset(self, namespace: str) -> None:
        urllib.request.urlopen(f"{self.url}/__reset/{namespace}").read()


@pytest.fixture(scope="session")
def mock(tmp_path_factory):
    """A mock on a free port of this machine, for DuckDB, which calls it from this process."""
    url_file = tmp_path_factory.mktemp("mock") / "url"
    process = subprocess.Popen(
        [sys.executable, str(ROOT / "test/mock/drex_mock.py"), "--port", "0", "--url-file", str(url_file)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(100):
            if url_file.exists() and url_file.read_text().strip():
                break
            time.sleep(0.1)
        else:
            pytest.fail("the mock didn't start")
        yield Mock(url_file.read_text().strip())
    finally:
        process.terminate()
        process.wait()


@pytest.fixture(scope="session")
def integration_deps():
    """Installs this package into integration_tests/ once."""
    dbt(INTEGRATION, "deps")
