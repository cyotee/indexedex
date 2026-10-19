# Port provenance: defi-ui-test-patterns

Reviewed and staged 2026-10-19. Staging only; no installation, repository edits or runtime execution.

## Original asset

- Manifest: /Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json
- Asset id: skill-cc0fe224c85e8e64f2040fe8f261f64c29b4adf1297a2c7b8b07b0605903ce97
- Original tree SHA-256: cc0fe224c85e8e64f2040fe8f261f64c29b4adf1297a2c7b8b07b0605903ce97
- Original selected path: catalog/skills/defi-ui-test-patterns
- Original entry SHA-256: 249b75ecefb7a1d59deed98fb0ced565d9e7bdcd000b606cc48f88a4f1447920
- Upstream version: no pinned release/commit in asset record; any Synpress v4 claim is historical.

## Complete file inventory

- SKILL.md: SHA-256 249b75ecefb7a1d59deed98fb0ced565d9e7bdcd000b606cc48f88a4f1447920; 2889 bytes; mode 644. Resolved inert object: /Users/cyotee/Projects/opencode-config/sources/collected-assets/objects/249b75ecefb7a1d59deed98fb0ced565d9e7bdcd000b606cc48f88a4f1447920

All manifest-listed files were read in full and source hashes checked. This asset contains only SKILL.md; no additional original resource or license file was listed. The port adds [current IndexedEx context](references/INDEXEDEX.md) as local guidance, not as an original source resource.

## Adaptations

- Add dated IndexedEx precedence note and self-contained current framework reference.
- Retain original name, description and MIT metadata without inventing an original license file or grant.
- Document source-version caveat, local-only wallet identities, secret hygiene and signing/broadcast authorization.
- Use live Native tool discovery, no Claude API or compatibility plugin assumptions.
- Scope scenarios to current framework.
- Require real approval.
- Require chain assertions.
- Remove mocked SUT/oracle and fake liquidation state.
- Preserve multi-account roles without substituting stubs.
- Preserve authorization and split approval semantics.
- Replace invented parallel suites and release mandates.

## License evidence

Original frontmatter says license: MIT and is retained as source metadata. The catalog owner license record is not-found-at-root-review-redistribution; this asset contains no original LICENSE text or copyright notice. No MIT grant, rights holder or redistribution permission has been invented. Review the missing original license before publication/redistribution. IndexedEx context was newly authored for this bounded review and does not establish rights to the original source.

## Validation limits

Complete source inventory and hashes, frontmatter, staged relative file links and current repo dependency paths are reviewed in wallet/review.json (staging-root-relative). External links and retained API examples are not runtime-tested. No repo tests, browser/server/extension/npm/wallet actions or live tool integration were run. Changed API syntax was checked only against official references listed in [IndexedEx context](references/INDEXEDEX.md). Current repo policy wins over all historical examples.
