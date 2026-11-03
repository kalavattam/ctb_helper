
# `ctb_helper`
[![tests][badge-tests]][run-tests] [![ShellCheck][badge-shellcheck]][run-shellcheck] [![license: MIT][badge-license]](LICENSE)

![Bash 3.2+, tested on 3.2, 4.4, and 5][badge-bash] ![Platforms: macOS and Windows (Git Bash, WSL)][badge-platforms] ![Tools: BSD, GNU, and BusyBox][badge-tools]

`ctb_helper.sh` starts and stops groups of [Cold Turkey Blocker](https://getcoldturkey.com) blocks from a Bash command line on macOS or Windows, so that one command, keyboard shortcut, or button can turn on a preset (see below). It wraps the program’s own command-line interface and adds named presets, locks that end at a given time, and a macOS notification that lists the blocks that started.

This project is neither affiliated with nor endorsed by Cold Turkey Software, Inc.

<br />

## Requirements
- Bash 3.2 or newer, which includes the Bash that ships with macOS.
- Cold Turkey Blocker on macOS or Windows. Locking blocks from the command line requires Cold Turkey Pro.

<br />

## Installation
Clone the repository and link the script onto the `PATH` under a short name such as `ctb`:
```bash
git clone https://github.com/kalavattam/ctb_helper.git ~/repos/ctb_helper
mkdir -p ~/bin
ln -s ~/repos/ctb_helper/bin/ctb_helper.sh ~/bin/ctb
```

`ctb_helper.sh` finds Cold Turkey in its default install location on macOS, under Git Bash on Windows, or under WSL. Set `CTB_BIN` to the Cold Turkey executable if it is installed somewhere else.

<br />

## Presets
A preset names a group of Cold Turkey blocks. Presets live in `~/.ctb_presets`, one per line:
```text
# name = Block One, Block Two, ...
focus = Social Media, News, Shopping
deep  = Social Media, News, Shopping, Email, Slack
```

Block names must match the names in Cold Turkey exactly, including case. Lines that begin with `#` are comments, and a preset named on more than one line combines their blocks. Run `ctb list` to see the blocks that each preset resolves to, and `ctb edit` to open the file in the editor named by `VISUAL` or `EDITOR`. The first `start`, `list`, or `edit` creates an example file when none exists.

<br />

## Usage
```bash
ctb start --lock 90 focus            # Start every block in 'focus', locked for 90 minutes
ctb start --until 5:30pm focus deep  # Lock until 5:30 pm, or tomorrow if that time has passed
ctb start 'Social Media' News        # Start blocks by name, without a lock
ctb stop focus                       # Stop the blocks in 'focus' (only if they are unlocked)
ctb list                             # Print each preset and its blocks
ctb help                             # Print the full help
```

A name that matches a preset expands to that preset’s blocks; any other name is passed to Cold Turkey as a block name. A block named more than once is started or stopped once. Specify at most one of `--lock`, `--until`, and `--password`. A password given with `--password` cannot contain spaces or quotes, and it is visible in shell history and the process list.

<br />

### Running from a button or shortcut
Any launcher that can run a shell command can run a preset. In the macOS Shortcuts app, add a “Run Shell Script” action with a command such as:
```bash
/bin/bash ~/repos/ctb_helper/bin/ctb_helper.sh start --lock 90 focus
```

Shortcuts runs commands with a minimal `PATH`, so use full paths there. A shortcut can then sit in the menu bar or the Dock, or run from a keyboard shortcut. Stream Deck and similar launchers can run the same command.

<br />

### Configuration
| Variable          | Purpose                                                                           |
| :---              | :---                                                                              |
| `CTB_PRESETS`     | Presets file to use instead of `~/.ctb_presets`.                                  |
| `CTB_BIN`         | Cold Turkey executable to use when it is not in a default install location.       |
| `VISUAL`/`EDITOR` | Editor that `ctb edit` opens; the value may include arguments, such as `subl -w`. |

<br />

## Development
Run the test suite from the repository root with any Bash 3.2 or newer:
```bash
bash tests/run_tests.sh
/bin/bash tests/run_tests.sh
```

The tests replace Cold Turkey, `date`, `osascript`, and the editor with stubs, so they never change real blocks. [`tests/README.md`](tests/README.md) describes the suite, and [`docs/standards.md`](docs/standards.md) describes the source and documentation standards followed by the project. GitHub Actions runs the suite on macOS with the system’s default Bash 3.2 and with a Bash 5 that the job installs from Homebrew, on Ubuntu, on Windows under Git Bash, and in `bash:3.2`, `bash:4.4`, and `bash:5` containers, and it runs ShellCheck 0.10.0.

Markdown prose uses curly quotes rather than straight ones, as [`docs/standards.md`](docs/standards.md) describes. To find straight quotes in prose and then convert them, run:
```bash
bash dev/tools/format_md_quotes.sh README.md
bash dev/tools/format_md_quotes.sh --write README.md
```

<br />

## License
`ctb_helper` is distributed under the MIT license; see [`LICENSE`](LICENSE).

<br />

## Authorship and AI assistance attribution
- Director, responsible author, and maintainer: Kris Alavattam.
- Code, documentation, and related materials are planned, designed, developed, reviewed, revised, and maintained with AI assistance from Claude Code (Anthropic; Opus 5.5). All AI-assisted output is reviewed, edited, and approved by the author.

[badge-tests]: https://github.com/kalavattam/ctb_helper/actions/workflows/test.yml/badge.svg
[run-tests]: https://github.com/kalavattam/ctb_helper/actions/workflows/test.yml
[badge-shellcheck]: https://github.com/kalavattam/ctb_helper/actions/workflows/shellcheck.yml/badge.svg
[run-shellcheck]: https://github.com/kalavattam/ctb_helper/actions/workflows/shellcheck.yml
[badge-license]: https://img.shields.io/badge/license-MIT-yellow
[badge-bash]: https://img.shields.io/badge/Bash-3.2%2B%20%28tested%203.2%20%C2%B7%204.4%20%C2%B7%205%29-4EAA25?logo=gnubash&logoColor=white
[badge-platforms]: https://img.shields.io/badge/platforms-macOS%20%C2%B7%20Windows%20%28Git%20Bash%2C%20WSL%29-lightgrey
[badge-tools]: https://img.shields.io/badge/tools-BSD%20%C2%B7%20GNU%20%C2%B7%20BusyBox-lightgrey
