
# Changelog
## [Unreleased]
- Added `ctb_helper.sh`, which starts and stops groups of Cold Turkey Blocker blocks by preset or block name, with `--lock`, `--until`, and `--password` locks, and a macOS notification that lists the blocks that started.
- Added a contract test suite whose stubs replace Cold Turkey, `date`, `osascript`, and the editor.
- Added a GitHub Actions matrix that runs the suite under Bash 3.2, 4.4, and 5 with BSD, GNU, and BusyBox tools, on Windows under Git Bash, and through ShellCheck 0.10.0.
