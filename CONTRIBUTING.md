# Contributing

Use [GitHub Issues](https://github.com/nace-ai/dbt-drex/issues) for bugs and proposals. Include the package
version, your dbt and adapter versions, expected behavior and a small model with synthetic inputs. Never include
credentials, signed image URLs or customer data.

## Local checks

Clone the repository and follow [Development](README.md#development) from the repository root.
The default tests compile every macro for every adapter and run DuckDB against a local mock API. Postgres and
ClickHouse need the Docker setup in [.github/workflows/Tests.yml](.github/workflows/Tests.yml); a passing mock test is
not a live-platform check.

Maintainers check releases against the production API, which needs credentials and incurs API and warehouse
charges; a pull request doesn't need to. Describe any skipped checks in the pull request.

## Pull requests

Keep the change focused, explain the behavior it changes and list the checks you actually ran. A change to what a
macro compiles to updates `test/expected/` (`DREX_UPDATE_EXPECTED=1 uv run pytest test/test_compile.py`), and the
diff shows it for review. Update the [Macro API](docs/API.md) and examples if an interface changes. Keep the macros'
SQL to what each warehouse integration's release takes, and preserve the compile-time checks, credential handling
and cost warnings.

Follow the [branding guidance](docs/assets/README.md) before changing names or adding artwork.
An official download is not, by itself, permission to use a provider logo. Record sources and applicable usage terms.
