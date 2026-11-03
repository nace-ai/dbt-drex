"""The macros' SQL on every adapter, and the arguments they refuse, without a warehouse.

Each model of test/compile_project is compiled for each adapter and compared with test/expected/<adapter>/, which
holds the calls each warehouse integration's release takes (see docs/API.md). DREX_UPDATE_EXPECTED=1 rewrites the
expected files from the compiled SQL instead, for review in the diff.
"""

import os
import shutil
from pathlib import Path

import pytest
from conftest import ROOT, dbt
from dbt.cli.main import dbtRunner

PROJECT = ROOT / "test/compile_project"
EXPECTED = ROOT / "test/expected"
ADAPTERS = ["snowflake", "bigquery", "databricks", "postgres", "clickhouse", "duckdb"]
#: Where the macros look for the functions, and the model they ask, set for the whole project
LOCATION_VARS = '{"drex_database": "analytics", "drex_schema": "ml", "drex_model": "drex-max-v1.1"}'


@pytest.fixture(scope="module")
def compile_deps():
    dbt(PROJECT, "deps")


def compiled(adapter: str, tmp_path: Path, *args: str) -> dict[str, str]:
    target = tmp_path / adapter
    dbt(
        PROJECT,
        "compile",
        "--target",
        adapter,
        "--target-path",
        str(target),
        "--no-populate-cache",
        "--no-introspect",
        *args,
    )
    models = target / "compiled/drex_compile_tests/models"
    return {path.stem: path.read_text().strip() + "\n" for path in sorted(models.glob("*.sql"))}


def check_expected(directory: Path, sql: dict[str, str]) -> None:
    if os.environ.get("DREX_UPDATE_EXPECTED"):
        shutil.rmtree(directory, ignore_errors=True)
        directory.mkdir(parents=True)
        for name, text in sql.items():
            (directory / f"{name}.sql").write_text(text)
    expected = {path.stem: path.read_text() for path in sorted(directory.glob("*.sql"))}
    assert sorted(sql) == sorted(expected), f"compiled models differ from {directory}"
    for name in sql:
        assert sql[name] == expected[name], f"{directory.name}/{name}.sql"


@pytest.mark.parametrize("adapter", ADAPTERS)
def test_compiles_to_each_warehouse_call(adapter, compile_deps, tmp_path):
    check_expected(EXPECTED / adapter, compiled(adapter, tmp_path))


@pytest.mark.parametrize("adapter", ADAPTERS)
def test_location_and_model_vars(adapter, compile_deps, tmp_path):
    sql = compiled(adapter, tmp_path, "--vars", LOCATION_VARS, "--select", "noul", "choice", "decide_image")
    check_expected(EXPECTED / f"{adapter}-vars", sql)


class Inline:
    """`dbt compile --inline` in this process, keeping the error messages dbt logs."""

    def __init__(self):
        self.messages: list[str] = []
        self.runner = dbtRunner(callbacks=[lambda event: self.messages.append(event.info.msg)])

    def compile(self, snippet: str, target: str = "duckdb") -> tuple[str | None, str]:
        self.messages.clear()
        result = self.runner.invoke(
            [
                "compile",
                "--project-dir",
                str(PROJECT),
                "--profiles-dir",
                str(PROJECT),
                "--target",
                target,
                "--no-populate-cache",
                "--no-introspect",
                "--quiet",
                "--inline",
                snippet,
            ]
        )
        log = "\n".join(str(message) for message in self.messages)
        return (result.result.results[0].node.compiled_code if result.success else None), log


@pytest.fixture(scope="module")
def inline(compile_deps):
    return Inline()


LABELS_256 = [f"l{i}" for i in range(256)]
QUESTIONS_513 = {f"q{i}": {"type": "noul", "instructions": "x"} for i in range(513)}

REFUSED = {
    # Labels, as drex-duckdb refuses them at bind
    "one label": ("drex.drex_choice('body', 'x', ['a'])", "drex_choice: labels takes 2 to 255 labels, got 1"),
    "256 labels": (f"drex.drex_choice('body', 'x', {LABELS_256})", "labels takes 2 to 255 labels, got 256"),
    "duplicate label": (
        "drex.drex_choice('body', 'x', ['a', 'a'])",
        "drex_choice: labels must be unique; 'a' is a duplicate",
    ),
    "duplicate level": (
        "drex.drex_score('body', 'x', ['a', 'a'])",
        "drex_score: levels must be unique; 'a' is a duplicate",
    ),
    "duplicate after reading an integer": (
        "drex.drex_choice('body', 'x', {1: none, '1': none})",
        "drex_choice: labels must be unique; '1' is a duplicate",
    ),
    "empty label": ("drex.drex_choice('body', 'x', ['a', ''])", "drex_choice: labels must not be empty"),
    "empty question label": (
        "drex.drex_decide('s', {'q': {'type': 'choice', 'criteria': ['a', '']}})",
        "drex_decide: questions.q.criteria labels must not be empty",
    ),
    "null label": ("drex.drex_choice('body', 'x', ['a', none])", "drex_choice: labels must not hold a NULL label"),
    "labels as SQL": ("drex.drex_choice('body', 'x', 'label_column')", "labels must be a list of labels"),
    "unknown label key": ("drex.drex_choice('body', 'x', [{'label': 'a', 'text': 'b'}, 'c'])", "labels must be a list"),
    "no labels": ("drex.drex_choice('body', 'x', none)", "drex_choice: the question needs labels"),
    "score description": (
        "drex.drex_score('body', 'x', [{'label': 'low', 'description': 'd'}, 'high'])",
        "score levels take no description; describe them in instructions",
    ),
    "score dict": (
        "drex.drex_score('body', 'x', {'low': none, 'high': none})",
        "levels must be a list of labels or of {label, description}",
    ),
    "noul labels": (
        "drex.drex_noul('body', 'x', ['yes', 'no'])",
        "criteria labels must be exactly true and false, got [yes, no]",
    ),
    "noul one label in a list": (
        "drex.drex_noul('body', 'x', ['true'])",
        "criteria labels must be exactly true and false",
    ),
    "noul without text": (
        "drex.drex_noul('body', none, {'true': none, 'false': none})",
        "drex_noul: the question needs instructions, or a description of true or false",
    ),
    # Arguments that must be Jinja values
    "instructions as a list": ("drex.drex_noul('body', ['x'])", "drex_noul: instructions must be text"),
    "model as a number": ("drex.drex_noul('body', 'x', model=2)", "model must be a model name"),
    "no input": ("drex.drex_noul(none, 'x')", "drex_noul: input must be a SQL expression"),
    # Questions
    "questions as SQL": (
        "drex.drex_decide('s', 'questions_column')",
        "questions must be a dict of question id to question",
    ),
    "no questions": ("drex.drex_decide('s', {})", "questions takes 1 to 512 questions, got 0"),
    "513 questions": (f"drex.drex_decide('s', {QUESTIONS_513})", "questions takes 1 to 512 questions, got 513"),
    "blank id": (
        "drex.drex_decide('s', {' ': {'type': 'noul', 'instructions': 'x'}})",
        "question ids must not be empty",
    ),
    "__proto__": (
        "drex.drex_decide('s', {'__proto__': {'type': 'noul', 'instructions': 'x'}})",
        "the question id '__proto__' is not allowed: Drex can't answer it",
    ),
    "__proto__ with images": (
        "drex.drex_decide_image('s', 'i', {'__proto__': {'type': 'noul', 'instructions': 'x'}})",
        "drex_decide_image: the question id '__proto__' is not allowed",
    ),
    "duplicate id": (
        "drex.drex_decide('s', {'Team': {'type': 'noul', 'instructions': 'x'}, "
        "'team': {'type': 'noul', 'instructions': 'x'}})",
        "question ids must be unique ignoring case; 'team' is a duplicate",
    ),
    "unknown question key": (
        "drex.drex_decide('s', {'q': {'type': 'noul', 'instructions': 'x', 'model': 'm'}})",
        "questions.q has an unknown key 'model'; use type, instructions and criteria",
    ),
    "multiple_choice": (
        "drex.drex_decide('s', {'q': {'type': 'multiple_choice', 'criteria': ['a', 'b']}})",
        "questions.q: multiple_choice questions are not supported, since Drex has no multiple_choice",
    ),
    "box": ("drex.drex_decide('s', {'q': {'type': 'box'}})", "questions.q: box questions are not supported"),
    "unknown type": (
        "drex.drex_decide('s', {'q': {'type': 'yes_no'}})",
        "questions.q.type must be noul, choice or score, not 'yes_no'",
    ),
    "choice without criteria": (
        "drex.drex_decide('s', {'q': {'type': 'choice', 'instructions': 'x'}})",
        "questions.q needs criteria",
    ),
    "question criteria rules": (
        "drex.drex_decide('s', {'q': {'type': 'choice', 'criteria': ['a']}})",
        "questions.q.criteria takes 2 to 255 labels, got 1",
    ),
    "question score dict": (
        "drex.drex_decide('s', {'q': {'type': 'score', 'criteria': {'a': none, 'b': none}}})",
        "questions.q.criteria must be a list of labels or of {label, description}",
    ),
    "question noul without text": (
        "drex.drex_decide('s', {'q': {'type': 'noul'}})",
        "questions.q needs instructions, or a description of true or false",
    ),
    "empty state": (
        "drex.drex_decide({}, {'q': {'type': 'noul', 'instructions': 'x'}})",
        "state must have at least one key",
    ),
    "state key": (
        "drex.drex_decide({1: 'a'}, {'q': {'type': 'noul', 'instructions': 'x'}})",
        "drex_decide: state keys must be non-empty text",
    ),
    "state value": (
        "drex.drex_decide({'k': ''}, {'q': {'type': 'noul', 'instructions': 'x'}})",
        "drex_decide: state.k must be a SQL expression, such as a column name",
    ),
    "no images": (
        "drex.drex_decide_image('s', '', {'q': {'type': 'noul', 'instructions': 'x'}})",
        "drex_decide_image: images must be a SQL expression, such as a column name",
    ),
    "no result": ("drex.drex_choice_value('')", "drex_choice_value: result must be a SQL expression"),
    "description as a number": (
        "drex.drex_choice('body', 'x', [{'label': 'a', 'description': 3}, 'b'])",
        "drex_choice: labels must be a list of labels or of {label, description}, or a dict of label to description",
    ),
    "question id as a number": (
        "drex.drex_decide('s', {1: {'type': 'noul', 'instructions': 'x'}})",
        "drex_decide: question ids must be text, not 1",
    ),
    "question as text": (
        "drex.drex_decide('s', {'q': 'noul'})",
        "drex_decide: questions.q must be a dict with type, instructions and criteria",
    ),
    "question instructions as a number": (
        "drex.drex_decide('s', {'q': {'type': 'noul', 'instructions': 3}})",
        "drex_decide: questions.q.instructions must be text",
    ),
}


@pytest.mark.parametrize("case", REFUSED)
def test_refused_at_compile_time(inline, case):
    call, message = REFUSED[case]
    sql, log = inline.compile("{{ " + call + " }}")
    assert sql is None, f"compiled: {sql}"
    assert message in log


ADAPTER_REFUSED = {
    "clickhouse descriptions": (
        "clickhouse",
        "drex.drex_choice('body', 'x', {'a': 'described', 'b': none})",
        "drex_choice: ClickHouse's drex_choice takes plain labels; for labels with descriptions, use drex_decide",
    ),
    "clickhouse score descriptions never reach it": (
        "clickhouse",
        "drex.drex_score('body', 'x', [{'label': 'a', 'description': 'd'}, 'b'])",
        "score levels take no description",
    ),
    "duckdb images": (
        "duckdb",
        "drex.drex_decide_image('s', 'i', {'q': {'type': 'noul', 'instructions': 'x'}})",
        "drex_decide_image: drex-duckdb has no drex_decide_image",
    ),
    "plain spark": ("spark", "drex.drex_noul('body', 'x')", "drex: dbt-spark isn't supported"),
    # dbt dispatch walks an adapter's parents, so an adapter built on dbt-postgres would reach the postgres__ macros
    "postgres child macro": (
        "materialize",
        "drex.drex_noul('body', 'x')",
        "drex: the materialize adapter isn't supported",
    ),
    "postgres child accessor": (
        "materialize",
        "drex.drex_choice_value('team')",
        "drex: the materialize adapter isn't supported",
    ),
    "postgres child state": (
        "materialize",
        "drex.drex_decide({'body': 'body'}, {'q': {'type': 'noul', 'instructions': 'x'}})",
        "drex: the materialize adapter isn't supported",
    ),
}


@pytest.mark.parametrize("case", ADAPTER_REFUSED)
def test_refused_on_an_adapter(inline, case):
    target, call, message = ADAPTER_REFUSED[case]
    sql, log = inline.compile("{{ " + call + " }}", target)
    assert sql is None, f"compiled: {sql}"
    assert message in log


def test_model_none_and_empty_mean_the_default(inline):
    assert inline.compile("{{ drex.drex_noul('body', 'x', model='') }}")[0] == "prompt_drex(body, 'x')"
    assert inline.compile("{{ drex.drex_noul('body', 'x', model=none) }}", "bigquery")[0] == (
        "drex.noul(body, 'x', NULL, NULL)"
    )


def test_model_empty_reads_the_drex_model_var(compile_deps, tmp_path):
    """docs/API.md: `none` or `''` is var('drex_model'), for the macro and its fingerprint alike."""
    project = project_with(
        tmp_path,
        "m",
        "select {{ drex.drex_noul('body', 'x', model='') }} as a, {{ drex.drex_noul('body', 'x', model=none) }} as b,"
        " {{ drex.drex_fingerprint('body', 'x', model='') }} as c, {{ drex.drex_fingerprint('body', 'x') }} as d",
    )
    dbt(project, "compile", "--no-populate-cache", "--vars", "{drex_model: drex-max}")
    sql = (project / "target/compiled/drex_compile_tests/models/m.sql").read_text()
    assert sql.count("prompt_drex(body, 'x', model := 'drex-max')") == 2
    assert sql.count('{"model": "drex-max", "question": "x"}') == 2


def test_drex_model_var_does_not_reach_images(compile_deps, tmp_path):
    """The default text model doesn't read images, so drex_decide_image keeps the function's default, Drex Max."""
    project = project_with(
        tmp_path,
        "m",
        "select {{ drex.drex_decide_image('s', 'i', {'q': {'type': 'noul', 'instructions': 'x'}}) }} as a,"
        " {{ drex.drex_noul('body', 'x') }} as b",
    )
    dbt(project, "compile", "--target", "postgres", "--no-populate-cache", "--vars", "{drex_model: drex-v1.5}")
    sql = (project / "target/compiled/drex_compile_tests/models/m.sql").read_text()
    assert 'public.drex_decide_image(s, i, \'{"q": {"type": "noul", "instructions": "x"}}\'::jsonb) as a' in sql
    assert "public.drex_noul(body, 'x', NULL, 'drex-v1.5') as b" in sql


def test_image_fingerprint_with_an_explicit_model(compile_deps, tmp_path):
    """docs/API.md: drex_decide_image ignores var('drex_model'), so its fingerprint names the same explicit model, and
    changing the var changes neither the call nor the fingerprint."""
    questions = "{'q': {'type': 'noul', 'instructions': 'x'}}"
    project = project_with(
        tmp_path,
        "m",
        f"select {{{{ drex.drex_decide_image('s', 'i', {questions}, model='drex-max') }}}} as a,"
        f" {{{{ drex.drex_fingerprint('i', {questions}, model='drex-max') }}}} as b",
    )
    compiled = []
    for model in ("drex-v1.5", "drex-v2.0"):
        dbt(project, "compile", "--target", "postgres", "--no-populate-cache", "--vars", f"{{drex_model: {model}}}")
        compiled.append((project / "target/compiled/drex_compile_tests/models/m.sql").read_text())
        assert model not in compiled[-1]
    assert compiled[0] == compiled[1]
    assert '"model": "drex-max"' in compiled[0]


def project_with(tmp_path: Path, name: str, sql: str) -> Path:
    project = tmp_path / "project"
    shutil.copytree(PROJECT, project, ignore=shutil.ignore_patterns("target", "logs", "dbt_packages", "models"))
    (project / "packages.yml").write_text(f"packages:\n  - local: {ROOT}\n")
    (project / "models").mkdir()
    (project / "models" / f"{name}.sql").write_text(sql)
    dbt(project, "deps")
    return project


def test_errors_name_the_model_file(tmp_path):
    project = project_with(
        tmp_path, "ticket_teams", "select {{ drex.drex_choice('body', 'Which team?', ['billing']) }}"
    )
    output = dbt(project, "compile", "--no-populate-cache", check=False)
    assert "Compilation Error in model ticket_teams (models/ticket_teams.sql)" in output
    assert "drex_choice: labels takes 2 to 255 labels, got 1" in output


@pytest.mark.parametrize("materialized", ["view", "ephemeral"])
def test_warns_in_a_model_every_read_runs_again(tmp_path, materialized):
    sql = (
        f"{{{{ config(materialized='{materialized}') }}}}\nselect {{{{ drex.drex_noul('body', 'Refund?') }}}} as refund"
    )
    output = dbt(project_with(tmp_path, "refunds", sql), "compile", "--no-populate-cache")
    assert (
        f"drex: drex_noul in model refunds (models/refunds.sql), materialized as {materialized}: every read of it "
        "sends every row to Drex again, and each answer is billed" in output
    )


def test_warn_error_fails_the_view(tmp_path):
    sql = "{{ config(materialized='view') }}\nselect {{ drex.drex_noul('body', 'Refund?') }} as refund"
    output = dbt(project_with(tmp_path, "refunds", sql), "--warn-error", "compile", "--no-populate-cache", check=False)
    assert "Compilation Error in model refunds (models/refunds.sql)" in output
    assert "drex: drex_noul in model refunds (models/refunds.sql), materialized as view" in output


def test_no_warning_in_a_table(tmp_path):
    sql = "{{ config(materialized='table') }}\nselect {{ drex.drex_noul('body', 'Refund?') }} as refund"
    assert "every read of it sends" not in dbt(project_with(tmp_path, "refunds", sql), "compile", "--no-populate-cache")
