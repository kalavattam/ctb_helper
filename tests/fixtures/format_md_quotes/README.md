
# format_md_quotes test fixtures
These fixtures test `dev/tools/format_md_quotes.sh` against a known input. They are a Markdown file with straight quotes and its expected conversion, which `make.sh` writes from literal text, so regeneration is deterministic and needs only Bash 3.2 or newer.

Regenerate the fixtures from the repository root with:
```bash
bash tests/fixtures/format_md_quotes/make.sh
```

Generated fixture outputs are ignored by Git. `tests/run_tests.sh` regenerates this fixture set automatically when its outputs are missing.

<br />

## Files
Readable provenance:
- `make.sh`

Generated conversion pair:
- `format/input.txt`: Markdown with straight quotes in prose, inline code, a fence, link destinations and titles, an HTML attribute, a reference-link definition, and backslash escapes, ending without a line feed.
- `format/expected.txt`: the hand-written conversion of `input.txt`, with curly quotes in its prose only.

The pair uses `.txt` rather than `.md`, so the repository-wide quote check does not treat its straight quotes as maintained Markdown.

<br />

## Current test coverage
- `tests/contract/repository/test_markdown_quotes.sh` checks and converts `format/input.txt` and compares the result with `format/expected.txt` byte for byte.
