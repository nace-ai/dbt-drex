"""The integration project (integration_tests/) end to end on one warehouse, against the mock Drex API.

Each warehouse's test builds the project with its own target, then hands its query function and mock to these checks,
so DuckDB, Postgres and ClickHouse run the same models and the same assertions.
"""

import json
from collections.abc import Callable

from conftest import INTEGRATION, Mock, dbt

BODIES = {
    1: "I was charged twice this month. Please refund the duplicate payment.",
    2: "How do I change the email address on my account?",
    3: "The app crashes every time I open the reports page, and I can't work.",
}
EDITED = BODIES[2] + " Also, the app logs me out."
ADDED = "Do you offer a discount for teams of 50? We'd like a quote."
#: Ticket 3 after var('drex_test_second_edit')
SECOND_EDIT = BODIES[3] + " It started after the update."
TEAMS = ["billing", "technical", "sales"]
URGENCY = ["can wait", "this week", "today"]
#: The text of ticket_escaping.sql
TRICKY = 'It\'s "quoted", C:\\path\\n, a\nnew line,\ta tab, ünïcode 😀'

Query = Callable[[str], list[tuple]]
#: Points the warehouse's functions at a mock scenario, returning the env dbt runs with
Scenario = Callable[[str], dict[str, str]]


def as_json(value):
    return json.loads(value) if isinstance(value, str) else value


def sent(requests: list[dict]) -> list[tuple[str, list[dict], str]]:
    """Each request's state, questions and model, as Drex received them."""
    return [(json.loads(r["state"]), json.loads(r["questions"]), r["model"]) for r in requests]


def build(target: str, env: dict[str, str], mock: Mock, namespace: str, query: Query, schema: str) -> None:
    """dbt build, then every check of the answers and of what was sent."""
    mock.reset(namespace)
    dbt(INTEGRATION, "build", "--target", target, "--full-refresh", env=env)
    requests = sent(mock.requests(namespace))

    # The answers, read through the accessors: ticket 4 has no body, so it has no answers and sent nothing
    readout = {row[0]: row[1:] for row in query(f"select * from {schema}.ticket_readout")}
    assert sorted(readout) == [1, 2, 3, 4]
    for ticket in BODIES:
        refund, team, team_confidence, urgency, urgency_confidence = readout[ticket]
        assert 0 <= refund <= 1
        assert team in TEAMS
        assert 0 <= team_confidence <= 1
        assert 0 <= urgency <= len(URGENCY) - 1
        assert 0 <= urgency_confidence <= 1
    assert all(value is None for value in readout[4])
    assert None not in [state for state, _, _ in requests]

    # One request per question and body, each as Drex takes it
    def asked(question_type: str, instructions: str) -> list[tuple[str, dict, str]]:
        """The typed helpers' requests: one question, whose id each warehouse's Drex function names its own way."""
        return [
            (state, questions[0], model)
            for state, questions, model in requests
            if len(questions) == 1
            and questions[0]["type"] == question_type
            and (questions[0].get("instructions") or "") == instructions
        ]

    refunds = asked("noul", "Is the customer asking for a refund?")
    assert sorted(state for state, _, _ in refunds) == sorted(BODIES.values())
    assert {model for _, _, model in refunds} == {"drex-v2.0"}

    described = asked("noul", "")
    assert len(described) == 3
    assert described[0][1]["criteria"] == {"true": "The customer wants money back", "false": None}

    bugs = asked("noul", "Is this ticket about a bug?")
    assert len(bugs) == 3 and {model for _, _, model in bugs} == {"drex-max"}

    scores = asked("score", "How urgent is this ticket?")
    assert len(scores) == 3 and scores[0][1]["criteria"] == URGENCY

    choices = asked("choice", "Which team should handle this ticket?")
    plain = [question for _, question, _ in choices if question["criteria"] == dict.fromkeys(TEAMS)]
    with_descriptions = [question for _, question, _ in choices if question["criteria"]["billing"] is not None]
    assert list(plain[0]["criteria"]) == TEAMS
    assert len(plain) == 6  # ticket_answers and the incremental model's first run
    if target != "clickhouse":
        assert len(with_descriptions) == 3
        assert with_descriptions[0]["criteria"] == {
            "billing": "Payments, invoices, refunds and charges",
            "technical": "Bugs, crashes and errors in the product",
            "sales": None,
        }
        assert list(with_descriptions[0]["criteria"]) == TEAMS

    # drex_decide: the row as JSON state, three questions in one request, and Drex's whole body back
    decisions = [(state, questions) for state, questions, _ in requests if len(questions) == 3]
    assert len(decisions) == 4
    assert {"subject": "Empty", "body": None} in [state for state, _ in decisions]
    team = next(q for q in decisions[0][1] if q["id"] == "team")
    assert list(team["criteria"]) == TEAMS and team["criteria"]["billing"] == "Payments, invoices, refunds and charges"
    body = as_json(query(f"select decision from {schema}.ticket_decisions where id = 1")[0][0])
    assert set(body) == {"model", "answers", "usage", "evaluation_time_ms", "request_id"}
    assert set(body["answers"]) == {"refund", "team", "urgency"}

    # The threshold example of docs/API.md: every answer the mock gives is 0.9 sure
    confident = sorted(query(f"select id, team from {schema}.ticket_confident_teams"))
    assert [ticket for ticket, _ in confident] == sorted(BODIES)
    assert all(team in TEAMS for _, team in confident)

    # Each warehouse's literals carry quotes, backslashes, a newline, a tab and Unicode to Drex exactly
    escaped = [
        (state, [{k: v for k, v in q.items() if k != "id"} for q in questions], questions)
        for state, questions, _ in requests
        if any(q.get("instructions") == TRICKY for q in questions)
    ]
    assert sorted((q[0]["type"] for _, q, _ in escaped)) == ["choice", "choice", "noul"]
    assert [q for _, q, _ in escaped if q[0]["type"] == "noul"] == [[{"type": "noul", "instructions": TRICKY}]]
    labels = ["it's", "back\\slash", "new\nline", "ünï 😀"]
    typed_choice = next(q for state, q, _ in escaped if q[0]["type"] == "choice" and isinstance(state, str))
    assert typed_choice == [{"type": "choice", "instructions": TRICKY, "criteria": dict.fromkeys(labels)}]
    assert list(typed_choice[0]["criteria"]) == labels
    state, _, questions = next(e for e in escaped if isinstance(e[0], dict))
    assert state == {"id": 1, "half": 0.5, "missing": None, TRICKY: "Double charge"}
    assert questions == [
        {"id": "ünï 'q' \"id\"", "type": "choice", "instructions": TRICKY, "criteria": {"it's": TRICKY, "plain": None}}
    ]


def incremental(
    target: str,
    env: dict[str, str],
    mock: Mock,
    namespace: str,
    query: Query,
    schema: str,
    scenario: Scenario | None = None,
) -> None:
    """After build(): a second run sends only the changed and new tickets, a third nothing, a new question all.

    With `scenario`, which points the warehouse's functions at one of the mock's scenarios and returns the env to run
    dbt with, a ticket edited while Drex is at capacity is left without an answer, isn't asked again, and is asked
    again once, then not again, with docs/API.md's condition for rows with no answer.
    """

    def run(variables: str, run_env: dict[str, str] = env) -> list[str]:
        mock.reset(namespace)
        dbt(
            INTEGRATION,
            "run",
            "--target",
            target,
            "--select",
            "stg_tickets",
            "ticket_teams_incremental",
            "--vars",
            variables,
            env=run_env,
        )
        return sorted(state for state, _, _ in sent(mock.requests(namespace)))

    def teams() -> dict[int, str | None]:
        return dict(query(f"select id, {team_choice(target)} from {schema}.ticket_teams_incremental"))

    assert run("{drex_test_edit: true}") == sorted([EDITED, ADDED])
    assert run("{drex_test_edit: true}") == []
    owns = "drex_test_edit: true, drex_test_team_instructions: 'Which team owns this?'"
    assert run("{" + owns + "}") == sorted([BODIES[1], EDITED, BODIES[3], ADDED])
    answered = teams()
    assert sorted(answered) == [1, 2, 3, 4, 5]
    assert answered[4] is None and all(answered[ticket] in TEAMS for ticket in (1, 2, 3, 5))
    if scenario is None:
        return

    # Every attempt at ticket 3's new body is refused, so its answer is NULL with its new fingerprint
    edited = "{" + owns + ", drex_test_second_edit: true"
    try:
        assert set(run(edited + "}", scenario("529-always"))) == {SECOND_EDIT}
    finally:
        ok = scenario("ok")
    assert teams()[3] is None
    # The fingerprint is unchanged, so it isn't asked again; with the condition, it is, once, and ticket 4 (no body) not
    assert run(edited + "}", ok) == []
    assert run(edited + ", drex_test_retry_unanswered: true}", ok) == [SECOND_EDIT]
    assert run(edited + ", drex_test_retry_unanswered: true}", ok) == []
    answered = teams()
    assert answered[4] is None and all(answered[ticket] in TEAMS for ticket in (1, 2, 3, 5))


def team_choice(target: str) -> str:
    return {
        "duckdb": "team.choice",
        "postgres": "team ->> 'choice'",
        "clickhouse": "tupleElement(team, 'choice')",
    }[target]
