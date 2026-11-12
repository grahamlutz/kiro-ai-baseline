---
inclusion: fileMatch
fileMatchPattern: ["**/*.py", "**/pyproject.toml", "**/requirements*.txt", "**/setup.cfg"]
---
<!-- tier: default | pack: python | owner: Python guild | edit freely in your repo -->

# Python Standards (pack: python)

## Language and style
- Target the Python version declared in `pyproject.toml` (`requires-python`). Do not use newer syntax.
- Format and lint with `ruff` (`ruff format`, `ruff check`). Follow the repo's ruff config. Do not add per-line `noqa` without a reason.
- Type-annotate all public functions and methods. Prefer `X | None` over `Optional[X]` on 3.10+.
- Use `pathlib` over `os.path`, f-strings over `%`/`format`, and `logging` over `print` in library and service code.
- Never use bare `except:`. Catch specific exceptions and re-raise with context (`raise ... from err`).

## Dependencies and packaging
- Dependencies are declared in `pyproject.toml` and pinned via the repo's lock file (`uv.lock`, `poetry.lock`, or `requirements*.txt` with hashes). Never `pip install` ad hoc in instructions.
- Use a virtual environment; never install into the system interpreter.

## Security
- No `eval`, `exec`, `pickle.loads`, or `yaml.load` (use `yaml.safe_load`) on untrusted data.
- Use `subprocess.run([...], check=True)` with an argument list; never `shell=True` with interpolated input.
- Parameterized SQL only (driver placeholders or the ORM). No string-built queries.
