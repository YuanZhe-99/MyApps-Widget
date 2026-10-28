# AGENTS.md

Read `doc/en-us/architecture.md`, `doc/en-us/envelope.md` and `doc/en-us/verification.md` before
changing implementation. Keep the English and Chinese documentation mirrors aligned.

- Fetch relevant remotes before editing; understand divergence before proceeding.
- Preserve unrelated local changes and application-owned behavior.
- Keep shared documentation independent of application adoption lists and payloads. Document
  application-specific widgets in the corresponding application repository.
- The envelope format, storage keys, privacy wire names and reading order are a compatibility
  contract with widgets already on devices. Change them only together with the Dart, Kotlin and
  Swift readers and the fixtures in `contract/`.
- Any reader change must keep `contract/` passing in all three languages; add a fixture for every
  new rule.
- Document changed contracts and public declarations in the same change.
- Every added function must explain Purpose, Inputs, Returns, Side effects and Notes.
- Validate the final change set after the last edit.
- Publish shared dependencies to both remotes before updating consumer pointers.
- Use relative sibling repository URLs in submodules.
- Attribute only materially participating agents using their actual identity.
- Never commit credentials, generated outputs, user data or machine-specific addresses.
- Do not create release tags for documentation or repository scaffolding alone.
- Remove temporary milestone plans after completion; retain formal contracts.

Run `python3 tool/check_docs.py` for documentation changes and the package checks in
`doc/en-us/verification.md` for code changes. The branch is `main`; push the commit first, then
the tag, to both `origin` and `github`.
