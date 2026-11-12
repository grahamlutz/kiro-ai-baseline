---
inclusion: fileMatch
fileMatchPattern: ["**/test_*.py", "**/*_test.py", "**/tests/**/*.py", "**/conftest.py"]
---
<!-- tier: default | pack: python | owner: Python guild | edit freely in your repo -->

# Python Testing (pack: python)

- Use `pytest`. Plain `assert` statements; fixtures over setup/teardown classes.
- Put shared fixtures in `conftest.py`, closest to the tests that use them.
- Use `pytest.mark.parametrize` for input tables instead of loops inside a test.
- Mock at the boundary (HTTP, DB, clock) with `monkeypatch`, `unittest.mock`, or `responses`/`respx`. Do not mock the code under test.
- Use `tmp_path` for filesystem tests. Never write into the repo tree.
- Run tests with the repo's command (e.g. `uv run pytest -q` or `make test`) before reporting a task done.
