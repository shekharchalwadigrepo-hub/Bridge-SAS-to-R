# Contributing

This app is intentionally small. Useful contributions:

1. More DATA step / PROC patterns in `R/convert.R`
2. More paired examples in `R/examples.R`
3. Clearer lesson copy in `R/guide.R`
4. UI polish in `app.R` and `www/custom.css`

## Rules for the converter

- Prefer **intent-preserving** translations over token-for-token rewrites.
- Always attach a short note explaining the mapping.
- If a construct is ambiguous, emit a commented TODO rather than guessing silently.
- Keep dependencies of `convert.R` at base R only.

## How to test a change

1. Run `shiny::runApp()`.
2. Load each example in **Converter** both directions.
3. Paste one short custom PROC and one short dplyr pipeline.
4. Confirm unrecognized input becomes comments plus a warning, not a crash.
