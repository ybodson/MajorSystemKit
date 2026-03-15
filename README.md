# MajorSystemKit

A Swift package for generating and querying Major System mnemonic matches.

## Current shape

- Loads a precomputed pronunciation index from a bundled JSON resource.
- Encodes ARPABET phonemes into Major System digits.
- Stores only consonant phonemes in the generated JSON.
- Includes a Swift preprocessing script for converting CMUdict into the bundled index format.

## Why this architecture

The package uses a deterministic pronunciation lexicon pipeline instead of an LLM or online API:

```text
CMUdict -> phonemes -> consonants only -> major code -> bundled index -> fast lookup
```

That keeps lookups fast, offline, and reproducible.

## Resource format

The package expects a bundled resource named `cmudict-major-index.json` shaped like this:

```json
{
  "entriesByCode": {
    "314": [
      {
        "word": "meter",
        "phonemes": ["M", "T", "R"],
        "majorCode": "314",
        "score": 1.0
      }
    ]
  }
}
```

The `phonemes` array in the generated JSON is intentionally filtered to consonant sounds only. Vowels are dropped, and rhotic vowel `ER` is normalized to `R` so words like `meter` still become `M T R`.

## Updating the index

1. Download CMUdict.
2. Run:

```bash
swift Scripts/build_cmudict_index.swift cmudict-0.7b.dict Sources/MajorSystemKit/Resources/cmudict-major-index.json
```

3. Build or test the package.

## Notes

This starter package intentionally keeps the first version small and boring in a good way.
Phrase generation, frequency ranking, and multi-language support can sit on top later.
