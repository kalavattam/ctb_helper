
# Test suite
Tests are classified by what they prove, following the layers in the `protocol_chipseq_signal_norm` testing standard. This suite has only contract tests, because `ctb_helper.sh` is tested through its command-line interface.

```text
tests/
├── contract/
│   ├── interfaces/         command-line behavior of ctb_helper.sh
│   └── repository/         shell and Markdown source checks across the repository
├── fixtures/
│   ├── ctb_helper/         recipe and documentation for generated presets and stubs
│   └── format_md_quotes/   recipe and documentation for a quote-conversion pair
├── support/                shared test harness
└── run_tests.sh            canonical runner
```

<br />

## Canonical runner
Run the suite from the repository root:
```bash
bash tests/run_tests.sh
```

Each test runs under the Bash that runs `tests/run_tests.sh`, so the same command tests another Bash when you start it with that Bash. On macOS, for example, this tests the system Bash 3.2:
```bash
/bin/bash tests/run_tests.sh
```

`TEST_BASH` names a different Bash explicitly, such as one installed by a package manager or built from source:
```bash
TEST_BASH=/path/to/bash bash tests/run_tests.sh
```

No extra Bash is needed to run the suite. The CI matrix covers the other versions.

The default `all-safe` group runs every test; `contract` selects the same tests by name. Inspect the deduplicated selection without running it:
```bash
bash tests/run_tests.sh --list
```

Logs and scratch files go to `artifacts/tests/`, which Git ignores. Set `TEST_ARTIFACT_ROOT` to an absolute path outside the repository to keep the working tree untouched; other paths inside the repository are rejected.

<br />

## Fixtures and stubs
Each fixture set has its own `make.sh` and `README.md`. `tests/fixtures/ctb_helper/make.sh` generates the presets files and the command stubs that the `ctb_helper.sh` tests use, and `tests/fixtures/format_md_quotes/make.sh` generates the input and expected output for `format_md_quotes.sh`; [`fixtures/ctb_helper/README.md`](fixtures/ctb_helper/README.md) and [`fixtures/format_md_quotes/README.md`](fixtures/format_md_quotes/README.md) list them. The runner generates a set when it is missing, and you can regenerate either at any time:
```bash
bash tests/fixtures/ctb_helper/make.sh
bash tests/fixtures/format_md_quotes/make.sh
```

Every test puts the stubs first on `PATH` and sets `CTB_BIN` to the Cold Turkey stub, so the suite never runs a real Cold Turkey install, shows a real notification, or opens a real editor.

<br />

## Writing a test
Name the file `test_<subject>.sh`, set `TEST_NAME`, source `support/test_helpers.sh`, and call `setup_test_env` before the first case. Run `ctb_helper.sh` with `run_ctb`, check results with `assert_status`, `assert_lines`, `assert_text_found`, and `assert_text_absent`, and end with `finish`. Keep the test runnable under Bash 3.2.
