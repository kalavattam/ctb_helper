
# ctb_helper test fixtures
These fixtures let the contract tests run `ctb_helper.sh` without Cold Turkey, a real clock, macOS notifications, an interactive editor, and test `format_md_quotes.sh` against a known input. They are presets files, command stubs, and a Markdown conversion pair that `make.sh` writes from literal text, so regeneration is deterministic and needs only Bash 3.2 or newer.

Regenerate the fixtures from the repository root with:
```bash
bash tests/fixtures/ctb_helper/make.sh
```

Generated fixture outputs are ignored by Git. `tests/run_tests.sh` regenerates this fixture set automatically when its outputs are missing.

<br />

## Files
Readable provenance:
- `make.sh`

Generated presets files:
- `presets/basic.txt`: two well-formed presets, `focus` and `deep`, that share two blocks.
- `presets/messy.txt`: comments, surrounding whitespace and tabs, lines without `=` or without a name, empty entries, a repeated preset name, an empty preset, and a final line without a line feed.
- `presets/comments_only.txt`: comments and blank lines but no presets.

Generated command stubs:
- `tool/cold_turkey`: appends each call’s arguments to the file named by `CTB_FAKE_LOG` and fails for any block named in the colon-separated list `CTB_FAKE_FAIL`.
- `tool/date`: answers `date '+%H %M'` with `CTB_FAKE_NOW` and fails on any other call.
- `tool/osascript`: appends its arguments to the file named by `CTB_FAKE_OSA_LOG`.
- `tool/editor`: appends its arguments to the file named by `CTB_FAKE_EDITOR_LOG`.

Generated Markdown conversion pair:
- `format/input.txt`: Markdown with straight quotes in prose, inline code, a fence, link destinations and titles, an HTML attribute, a reference-link definition, and backslash escapes, ending without a line feed.
- `format/expected.txt`: the hand-written conversion of `input.txt`, with curly quotes in its prose only.

The pair uses `.txt` rather than `.md`, so the repository-wide quote check does not treat its straight quotes as maintained Markdown.

<br />

## Current test coverage
- `tests/contract/interfaces/test_presets.sh` reads all three presets files.
- `tests/contract/interfaces/test_dispatch.sh` checks the exact calls to the Cold Turkey stub and the notification text sent to the `osascript` stub.
- `tests/contract/interfaces/test_until.sh` fixes the clock with the `date` stub.
- `tests/contract/interfaces/test_edit.sh` opens the editor stub.
- Every contract test uses the Cold Turkey stub through `CTB_BIN`.
- `tests/contract/repository/test_markdown_quotes.sh` checks and converts `format/input.txt` and compares the result with `format/expected.txt` byte for byte.
