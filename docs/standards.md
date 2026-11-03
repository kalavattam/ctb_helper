
# Standards
`ctb_helper` follows the repository standards of [`protocol_chipseq_signal_norm`](https://github.com/kalavattam/protocol_chipseq_signal_norm/tree/main/docs/standards) rather than keeping a copy of them. This page records which of those standards apply here, which do not, and where this repository deliberately departs from them.

<br />

## Standards that apply
| Standard            | Applies to                                                                                              |
| :---                | :---                                                                                                    |
| `shell.md`          | Source form, diagnostics, comments, safe mode, static analysis, line length, and shell-test source form |
| `help.md`           | The `help_ctb`, `help_format_md_quotes`, and `help_run_tests` heredocs                                  |
| `source_headers.md` | The header of every shell file                                                                          |
| `source_layout.md`  | Semantic paragraphs, comment attachment, naming, and American English spelling                          |
| `markdown.md`       | Every Markdown file                                                                                     |
| `testing.md`        | Test layers, the runner, fixtures, generated evidence, and harness reporting                            |

<br />

## Standards that do not apply
The wrapper-topology, processing-boundary, submit-bootstrap, and startup-sourcing rules in `shell.md` govern `execute_*.sh` and `submit_*.sh` wrappers and sourced libraries, which this repository does not have. The Python, R, Rust, AWK, JSON, and output standards have no source here to govern. Optional test gates, wet Slurm validation, and scoped cleanup in `testing.md` have no counterpart here.

<br />

## Deliberate departures
| Rule                            | Departure                                                                                                                                          | Reason                                                                                               |
| :---                            | :---                                                                                                                                               | :---                                                                                                 |
| `SHELL.SYNTAX`                  | The Bash floor is 3.2 rather than 4.4, so the source avoids associative arrays, `${var,,}`, `declare -g`, `printf '%(...)T'`, and `mapfile`.       | `ctb_helper.sh` must run under the Bash that ships with macOS.                                       |
| `SHELL.SYNTAX`                  | An array that can be empty expands as `${arr[@]+"${arr[@]}"}`.                                                                                     | Before Bash 4.4, `set -u` treats an empty array as unset.                                            |
| `SHELL.SOURCE.FORM`             | The first test in each Bash version guard uses POSIX `[` rather than `[[`.                                                                         | A non-Bash shell such as dash must reach the guard’s message rather than fail on `[[`.               |
| `SHELL.SOURCE.FORM`             | A negated command test puts `!` with the command on the continuation line (`if \` and then `! command`) rather than on the `if` line (`if ! \`).   | This repository adopts a planned `protocol_chipseq_signal_norm` change before `shell.md` records it. |
| `SHELL.STATIC_ANALYSIS`         | ShellCheck 0.10.0 comes from the `shellcheck-py` package rather than the `env_protocol` Conda environment.                                         | This repository has no Conda environment.                                                            |
| `TEST.EVIDENCE`, harness setup  | Tests run under the Bash running `tests/run_tests.sh`, or the Bash named by `TEST_BASH`, rather than the `env_protocol` Bash.                      | The suite must test each Bash version in the CI matrix.                                              |
| `SHELL.DIAGNOSTIC.FORM` helpers | `ctb_helper.sh` and `format_md_quotes.sh` each define their own `echo_err` and `print_context_diag`, modeled on `lib/bash/core/format_outputs.sh`. | The scripts are standalone and cannot source the protocol repository’s libraries.                    |

External commands use only options that BSD, GNU, and BusyBox share: `basename`, `cat`, `dirname`, `mkdir -p`, `sleep` with a whole or decimal number of seconds, `tr` with POSIX character classes, and `date` with a `+` format in the script, plus `awk` with `-F` and `ENVIRON`, `cksum`, `cmp`, `cp`, `find`, `mv`, `sort`, and `grep -E`, `-F`, `-q`, `-v`, and `-x` in the tests. `format_md_quotes.sh` uses only Bash built-ins. `osascript` runs only on macOS, and `sqlite3 -readonly` and `perl` with the core `JSON::PP` module run only to confirm block states; the script checks that each exists before it uses it and works without them.

`tests/contract/repository/test_shell_source.sh` fails on the constructs newer than Bash 3.2 listed above, and the CI matrix runs the suite under Bash 3.2, 4.4, and 5.

<br />

## Additional rules
### Curly quotes in Markdown prose
Markdown prose uses curly quotes: “ and ” for double quotes, and ‘ and ’ for single quotes, with ’ also serving as the apostrophe. `protocol_chipseq_signal_norm` has no counterpart to this rule. Straight quotes (`"` and `'`) stay where they are syntax: in fenced code blocks, inline code spans, HTML tags, link and image destinations and their titles, and reference-link definitions. A quote escaped with a backslash also stays straight.

`dev/tools/format_md_quotes.sh` reports each straight quote in prose with its line and column and, with `--write`, converts them. `tests/contract/repository/test_markdown_quotes.sh` runs it on every Markdown file in the repository and fails on any straight quote in prose.
