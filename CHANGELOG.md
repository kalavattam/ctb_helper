
# Changelog
## [Unreleased]
- Added `ctb_helper.sh`, which starts and stops groups of Cold Turkey Blocker blocks by preset or block name, with `--lock`, `--until`, and `--password` locks, and a macOS notification that lists the blocks that started.
- Added `list` and `edit` subcommands for the presets file, `~/.ctb_presets` by default, and the `CTB_PRESETS` and `CTB_BIN` variables, which name another presets file or Cold Turkey executable.
- Supported Bash 3.2 and newer, including the Bash that ships with macOS, with BSD, GNU, and BusyBox tools.
- Added `dev/tools/format_md_quotes.sh`, which finds straight quotes in Markdown prose and converts them to curly quotes.
- Made `start` and `stop` wait two seconds between Cold Turkey calls, as Cold Turkey can drop a command that arrives too soon after another. `CTB_DELAY` sets a different wait.
- Made `start` and `stop` read Cold Turkey’s settings after their calls to confirm that each block turned on or off. They report each block that did not change and each name that Cold Turkey has no block for. `CTB_DB` names the settings database when it is not in the default location.
- Made `start` and `stop` discard Cold Turkey’s blank output lines and print one summary of the blocks that changed. On a terminal, they also show a spinner while they work as well as how long they took.
- Documented that Cold Turkey ends a lock at the start of a clock minute, so a lock of N minutes lasts between N − 1 and N minutes.
- Added a contract test suite whose stubs replace Cold Turkey, `date`, `osascript`, the editor, `sleep`, and `sqlite3`, including a repository test that keeps straight quotes out of Markdown prose.
- Added two GitHub Actions workflows: one runs the suite under Bash 3.2, 4.4, and 5 on macOS, Ubuntu, Windows under Git Bash, and BusyBox containers, and the other runs ShellCheck 0.10.0.
- Added the README, `docs/standards.md`, which records how the project follows and departs from the `protocol_chipseq_signal_norm` standards, and the MIT license.
