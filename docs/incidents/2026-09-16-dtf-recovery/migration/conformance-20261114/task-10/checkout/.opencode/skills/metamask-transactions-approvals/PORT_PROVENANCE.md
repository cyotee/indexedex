# Port provenance: metamask-transactions-approvals

Reviewed and staged 2026-10-19. Staging only; no installation, repository edits or runtime execution.

## Original asset

- Manifest: /Users/cyotee/Projects/opencode-config/sources/collected-assets/manifest.json
- Asset id: skill-7f675ebb9405e29c1d6306cc7b4435d65be1566bef6b53680507f99d18f88c1f
- Original tree SHA-256: 7f675ebb9405e29c1d6306cc7b4435d65be1566bef6b53680507f99d18f88c1f
- Original selected path: catalog/skills/metamask-transactions-approvals
- Original entry SHA-256: 559a0bb17f1ec18fad8775d3d3422ae06f0dc689a8318e2220768276f488a7c1
- Upstream version: no pinned release/commit in asset record; any Synpress v4 claim is historical.

## Complete file inventory

- SKILL.md: SHA-256 559a0bb17f1ec18fad8775d3d3422ae06f0dc689a8318e2220768276f488a7c1; 2237 bytes; mode 644. Resolved inert object: /Users/cyotee/Projects/opencode-config/sources/collected-assets/objects/559a0bb17f1ec18fad8775d3d3422ae06f0dc689a8318e2220768276f488a7c1

All manifest-listed files were read in full and source hashes checked. This asset contains only SKILL.md; no additional original resource or license file was listed. The port adds [current IndexedEx context](references/INDEXEDEX.md) as local guidance, not as an original source resource.

## Adaptations

- Add dated IndexedEx precedence note and self-contained current framework reference.
- Retain original name, description and MIT metadata without inventing an original license file or grant.
- Document source-version caveat, local-only wallet identities, secret hygiene and signing/broadcast authorization.
- Use live Native tool discovery, no Claude API or compatibility plugin assumptions.
- Gate extension API examples and enforce authorization.
- Avoid default unlimited allowance.
- Preserve split approval receipt gates.
- Remove automatic risky-signature acceptance.
- Replace optional gas-only proof with required real effect.
- Remove mainnet signer risk.
- Avoid generic gas override recommendation.
- Verify numeric spendLimit syntax against official Synpress MetaMask reference.

## License evidence

Original frontmatter says license: MIT and is retained as source metadata. The catalog owner license record is not-found-at-root-review-redistribution; this asset contains no original LICENSE text or copyright notice. No MIT grant, rights holder or redistribution permission has been invented. Review the missing original license before publication/redistribution. IndexedEx context was newly authored for this bounded review and does not establish rights to the original source.

## Validation limits

Complete source inventory and hashes, frontmatter, staged relative file links and current repo dependency paths are reviewed in wallet/review.json (staging-root-relative). External links and retained API examples are not runtime-tested. No repo tests, browser/server/extension/npm/wallet actions or live tool integration were run. Changed API syntax was checked only against official references listed in [IndexedEx context](references/INDEXEDEX.md). Current repo policy wins over all historical examples.
