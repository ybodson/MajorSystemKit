# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
swift build -v

# Test
swift test -v

# Regenerate the bundled index (basic — all scores default to 1.0)
swift Scripts/build_cmudict_index.swift Scripts/cmudict-0.7b.txt \
  Sources/MajorSystemKit/Resources/cmudict-major-index.json

# Regenerate with scoring data (recommended)
swift Scripts/build_cmudict_index.swift Scripts/cmudict-0.7b.txt \
  Sources/MajorSystemKit/Resources/cmudict-major-index.json \
  Scripts/SUBTLEX-US.txt \
  Scripts/brysbaert-concreteness.txt
```

There is no linter configured.

### Scoring data files

The two optional scoring files live in `Scripts/` but are not committed (too large). Download them separately:

- **`SUBTLEX-US.txt`** — Brysbaert & New (2009) word frequency corpus. Tab-separated with a header row; key column is `SUBTLWF` (frequency per million words).
- **`brysbaert-concreteness.txt`** — Brysbaert et al. (2014) concreteness norms. Tab-separated with a header row; key column is `Conc.M` (mean rating on a 1–5 scale).

## Architecture

MajorSystemKit converts digit strings into matching English words using the [Major System](https://en.wikipedia.org/wiki/Mnemonic_major_system) mnemonic technique. The core pipeline is fully offline and deterministic:

```
CMUdict (ARPABET phonemes) → consonants only → Major digits → bundled JSON → runtime query
```

**Build-time**: `Scripts/build_cmudict_index.swift` reads CMUdict, strips vowels, maps consonant phonemes to Major System digits (e.g. S/Z→0, T/D→1, N→2, M→3, R→4, L→5, CH/SH→6, K/G→7, F/V→8, P/B→9), and writes `cmudict-major-index.json` grouped by digit code.

**Runtime**: `MajorIndexLoader` loads the bundled JSON once. `MajorSystemService` is the public API — call `matches(for: "314", limit: 20)` to get words whose consonants encode to that digit sequence. Results are sorted by score → word length → alphabetical.

**Key types**:
- `MajorEntry` — a word with its consonant phonemes and digit code
- `MajorIndexFile` — the full index: `[digitCode: [MajorEntry]]`
- `MajorEncoder` — stateless phoneme→digit logic; also used standalone to encode arbitrary phoneme arrays
- `MajorSystemService` — query interface; depends on `MajorIndexFile` injected at init

The bundled `cmudict-major-index.json` (~22.7 MB) stores only consonant phonemes per entry. Multiple entries for the same word are kept when different pronunciations produce the same or different digit codes.
