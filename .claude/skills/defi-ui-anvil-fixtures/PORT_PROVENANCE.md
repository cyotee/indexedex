# Port provenance: defi-ui-anvil-fixtures

Reviewed and staged 2026-10-19. Staging only; no installation, repository edits or runtime execution.

## Original asset

- Manifest: /Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json
- Asset id: skill-fa9ac364c06fa3d12ed586f659ae24d8ef0186d5c2f2799a7ed784c7243afd67
- Original tree SHA-256: fa9ac364c06fa3d12ed586f659ae24d8ef0186d5c2f2799a7ed784c7243afd67
- Original selected path: catalog/skills/defi-ui-anvil-fixtures
- Original entry SHA-256: ad7c699d72df701b73181be329c89f070cf6bc5ba49ac55e053132055859c1a8
- Upstream version: no pinned release/commit in asset record; any Synpress v4 claim is historical.

## Complete file inventory

- SKILL.md: SHA-256 ad7c699d72df701b73181be329c89f070cf6bc5ba49ac55e053132055859c1a8; 2962 bytes; mode 644. Resolved inert object: /Users/cyotee/Projects/opencode-config/sources/collected-assets/objects/ad7c699d72df701b73181be329c89f070cf6bc5ba49ac55e053132055859c1a8

All manifest-listed files were read in full and source hashes checked. This asset contains only SKILL.md; no additional original resource or license file was listed. The port adds [current IndexedEx context](references/INDEXEDEX.md) as local guidance, not as an original source resource.

## Adaptations

- Add dated IndexedEx precedence note and self-contained current framework reference.
- Retain original name, description and MIT metadata without inventing an original license file or grant.
- Document source-version caveat, local-only wallet identities, secret hygiene and signing/broadcast authorization.
- Use live Native tool discovery, no Claude API or compatibility plugin assumptions.
- Align chain helper scope.
- Reuse real fixture and environment.
- Replace Foundry default chain with current chain 4663.
- Use configured disposable RPC for mutations.
- Correct snapshot lifecycle.
- Use independent snapshots.
- Restore per test.
- Assert cleanup success and clear consumed id.
- Remove placeholder duplicate lifecycle.
- Remove nonexistent date fixture.
- Replace generic node startup with deployment ownership.
- Constrain impersonation cleanup.
- Separate stub display from real execution.
- Remove duplicate server and unconfigured node startup.
- Replace plugin dependencies.
- Use raw evm_revert boolean; viem revert helper returns void.
- Remove mutation fallback to shared default RPC.
- Require explicit separate loopback endpoint before creating mutable client.
- Keep chain metadata and mutable transport aligned.
- No shared-node fallback in helper example.
- Verify actual disposable chain before use.
- Align illustrative helper path.
- Distinguish example helper and enforce matching signing target.

## License evidence

Original frontmatter says license: MIT and is retained as source metadata. The catalog owner license record is not-found-at-root-review-redistribution; this asset contains no original LICENSE text or copyright notice. No MIT grant, rights holder or redistribution permission has been invented. Review the missing original license before publication/redistribution. IndexedEx context was newly authored for this bounded review and does not establish rights to the original source.

## Validation limits

Complete source inventory and hashes, frontmatter, staged relative file links and current repo dependency paths are reviewed in wallet/review.json (staging-root-relative). External links and retained API examples are not runtime-tested. No repo tests, browser/server/extension/npm/wallet actions or live tool integration were run. Changed API syntax was checked only against official references listed in [IndexedEx context](references/INDEXEDEX.md). Current repo policy wins over all historical examples.
