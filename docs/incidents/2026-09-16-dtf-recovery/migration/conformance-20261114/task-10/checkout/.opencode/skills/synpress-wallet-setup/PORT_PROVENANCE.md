# Port provenance: synpress-wallet-setup

Reviewed and staged 2026-10-19. Staging only; no installation, repository edits or runtime execution.

## Original asset

- Manifest: /Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json
- Asset id: skill-8320455ecde0785bb47143164a2f99f6beb1690a396d06aa0000cb5dee1c95a8
- Original tree SHA-256: 8320455ecde0785bb47143164a2f99f6beb1690a396d06aa0000cb5dee1c95a8
- Original selected path: catalog/skills/synpress-wallet-setup
- Original entry SHA-256: a9c5bf298b8827e8d65cf9a3b9c9daa1e30f7b3d9199473bcb89eaf33ab959a3
- Upstream version: no pinned release/commit in asset record; any Synpress v4 claim is historical.

## Complete file inventory

- SKILL.md: SHA-256 a9c5bf298b8827e8d65cf9a3b9c9daa1e30f7b3d9199473bcb89eaf33ab959a3; 2400 bytes; mode 644. Resolved inert object: /Users/cyotee/Projects/opencode-config/sources/collected-assets/objects/a9c5bf298b8827e8d65cf9a3b9c9daa1e30f7b3d9199473bcb89eaf33ab959a3

All manifest-listed files were read in full and source hashes checked. This asset contains only SKILL.md; no additional original resource or license file was listed. The port adds [current IndexedEx context](references/INDEXEDEX.md) as local guidance, not as an original source resource.

## Adaptations

- Add dated IndexedEx precedence note and self-contained current framework reference.
- Retain original name, description and MIT metadata without inventing an original license file or grant.
- Document source-version caveat, local-only wallet identities, secret hygiene and signing/broadcast authorization.
- Use live Native tool discovery, no Claude API or compatibility plugin assumptions.
- Gate setup lifecycle.
- Remove executable setup command.
- Align reference chain id.
- Align network name.
- Align switch name.
- Remove permission to commit wallet cache.
- Replace automatic CI activation with existing framework.
- Preserve secret injection and signing scope.

## License evidence

Original frontmatter says license: MIT and is retained as source metadata. The catalog owner license record is not-found-at-root-review-redistribution; this asset contains no original LICENSE text or copyright notice. No MIT grant, rights holder or redistribution permission has been invented. Review the missing original license before publication/redistribution. IndexedEx context was newly authored for this bounded review and does not establish rights to the original source.

## Validation limits

Complete source inventory and hashes, frontmatter, staged relative file links and current repo dependency paths are reviewed in wallet/review.json (staging-root-relative). External links and retained API examples are not runtime-tested. No repo tests, browser/server/extension/npm/wallet actions or live tool integration were run. Changed API syntax was checked only against official references listed in [IndexedEx context](references/INDEXEDEX.md). Current repo policy wins over all historical examples.
