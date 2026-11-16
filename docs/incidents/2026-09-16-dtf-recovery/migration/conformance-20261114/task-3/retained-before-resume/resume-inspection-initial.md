# Task 3 resume inspection

Result: PASS for the task 3 source evidence review on 2026-11-15. This is a producer inspection, not an independent acceptance verdict.

The interrupted producer's three indexes, source-observations.json, commands.json, raw logs and both source suites were read before any write. Current indexes differ from their preserved baselines; the preliminary task-3-verdict.json and its old verification report concern the earlier blocked producer, not these current bytes. No existing producer record was replaced.

## Raw file and route inspection

All 14 required category/generation rows have exact proxy/runtime identity, target/selector/delegated facet and hash, input/return schema, ownership/current-unit read, original/remaining units, conversion equation, disablement qualification, surrender/rollback witness and recovery disposition. All 118 facet joins match their raw observations. All 128 inspected JSON pointers and 28 Markdown file links resolve. Shared proxy code was never used as facet identification. TokenStaking's zero-address approve/transferFrom delegations explicitly mean no approved raw-weight pull; they are not missing callable schemas.

Full raw-file SHA-256 recomputations, source bindings, route joins, per-row equations and named witness locations are in [resume-byte-review.json](resume-byte-review.json). Its 38 binding comparisons (37 unique files) match. The 50 source files in the accepted source command fingerprint also match current bytes. Existing 34 runtime keccak command receipts are reused, not rerun. Weighted NFT local journal /rpc/550 is byte-identical to the authenticated pinned eth_getCode at /rpc/2; weighted receipt /rpc/44 is pinned directly.

| Current index | SHA-256 | Preserved baseline SHA-256 |
| --- | --- | --- |
| source-manifest.json | 86687ab4bf579b2ba8635ee5efe4eb935df27bcf7d17a34314018353ded9dc97 | 55117479ecb52b3e334a988a53a62ec73c11de4b808bd2ccf5d2d07d783126bc |
| source-route-matrix.md | d4efc66c1acabf3d66b98d3e890f1532e919ede6daf558e5091ed8b3ef5208a9 | a81ac2729daa2103d8ca3ecd35ceb0badba19ab376dbfee82b371722ff4efff4 |
| recovery-route-disposition.md | f33e6ce5eb4dfe88fe2f594b19ba4a6708333579230db1f8d8564d8dbf13ce94 | 9279cc9cf3d5adcdbdfef56ef7ce376f0d080179a30a6c468128b86b5b3b2ae4 |

Every row below cites a raw archive whose file hash was recomputed. The complete ABI schemas remain in source-observations.json, reached through the manifest's abiRef entries.

| Required row | Runtime evidence file, relative to migration | Recomputed SHA-256 | Result |
| --- | --- | --- | --- |
| weighted-nft | evidence/weighted/probe.results.json | 4d7730a459848682d7d21209578d3c28a8b35367b7699be1909a5ba6b53b7472 | PASS |
| earlier-nft | evidence/earlier-cp/probe-alchemy-retry.source.json | 5cc1acf89ead089c66c156c20f6ea7e8c03647e1474d3b495e977e29ce21a397 | PASS |
| weighted-liquid | evidence/other-sources/probe-alchemy-r2.sources.json | c1769d1b6711f5c8da9be1c2970604294198b4e8e34b207bd97c1e5de57897f1 | PASS |
| earlier-liquid | evidence/earlier-cp/probe-alchemy-retry.source.json | 5cc1acf89ead089c66c156c20f6ea7e8c03647e1474d3b495e977e29ce21a397 | PASS |
| weighted-receipt | evidence/weighted/probe.results.json | 4d7730a459848682d7d21209578d3c28a8b35367b7699be1909a5ba6b53b7472 | PASS |
| earlier-receipt | evidence/earlier-cp/probe-alchemy-retry.source.json | 5cc1acf89ead089c66c156c20f6ea7e8c03647e1474d3b495e977e29ce21a397 | PASS |
| weighted-sy | claimed-sy-source/source/raw/source-identities.json | 26f5dc65500c7120210bdde6d5910527e0879ed4d2e723e9ffce0a7406ec0e53 | PASS |
| claim-vault | claimed-sy-source/source/raw/source-identities.json | 26f5dc65500c7120210bdde6d5910527e0879ed4d2e723e9ffce0a7406ec0e53 | PASS |
| dtf-custody-se | evidence/other-sources/probe-alchemy-r2.sources.json | c1769d1b6711f5c8da9be1c2970604294198b4e8e34b207bd97c1e5de57897f1 | PASS |
| weighted-weth-se | evidence/other-sources/probe-alchemy-r2.sources.json | c1769d1b6711f5c8da9be1c2970604294198b4e8e34b207bd97c1e5de57897f1 | PASS |
| earlier-se | evidence/other-sources/probe-alchemy-r2.sources.json | c1769d1b6711f5c8da9be1c2970604294198b4e8e34b207bd97c1e5de57897f1 | PASS |
| weighted-lp | evidence/other-sources/probe-alchemy-r2.sources.json | c1769d1b6711f5c8da9be1c2970604294198b4e8e34b207bd97c1e5de57897f1 | PASS |
| earlier-lp | evidence/other-sources/probe-alchemy-r2.sources.json | c1769d1b6711f5c8da9be1c2970604294198b4e8e34b207bd97c1e5de57897f1 | PASS |
| token-staking-preparation | claimed-sy-source/source/raw/source-identities.json | 26f5dc65500c7120210bdde6d5910527e0879ed4d2e723e9ffce0a7406ec0e53 | PASS |

## Reserved source identities

Earlier collection IDs 0, 1 and 2 are reserved protocol, fee-recipient and creator roles. The exact deployed facet's constants at lines 1353-1355, initialization at 16262-16321, and reward-only additions at 16473-16483 were read in the hashed earlier source archive. Pinned reservedBondNftsWired=true, owners and full positions agree. The distinct ordinary ID 3 purchase supplies independent acquisition context. No classification is derived from Migration's tokenId < 3 guard or another child's conventions.

The exact reserved mint receipts remain unrecovered. source-reserved-mints.log records the approved provider's range-limit rejection. No scan, provider switch, purchase or retry occurred. This is supplemental unavailable transaction provenance; deployed initialization plus live wired/position facts independently establish these reserved roles. No wallet-wide absence of exposure or financial eligibility dataset is inferred. No owner product decision is requested.

## Custody and recovery

The exact E-P withdrawal facet/hash and three owner-only methods, parent accepted intake and claimLiquidity caller restriction, NFT create/principal/forwarding owner guards, and collector fee-transfer-only path were compared directly against the raw deployed source excerpts. All 10 excerpt comparisons match. source-custody-live.log joins the actual proxy selectors to these facets. The unauthorized exit witness preserves LP holdings/supply before and after actual fork fee-role/time changes and rejects parent LP intake after enablement.

The current-fee-recipient exception belongs only to W-P. Source disablement, dust or absent reward income are conditional availability, never proof of permanent inability. The index keeps those external authority prerequisites explicit and preserves repeated rewards-only NFT recovery with principal retained.

## Execution evidence reused

The exact required artifact-helper command is bound in commands.json, run id source-state-assertions: exit 0, 13 passed, 0 failed, 0 skipped. Raw log source-state-assertions.log SHA-256: db83a11664e756927aa1530a881ccb65efc265054c12029e162776f9676ce063. It records Solar build before test; prior artifact directories are this worktree's out/ and cache_forge/. No compilation or cache seeding was needed during resume. Existing warnings, failed dependency auto-install attempts and earlier failed commands remain preserved; no install was attempted during resume.

Wrong-wallet, invalid/nonexistent-ID and unauthorized E-P cases are bound to raw log lines 5802, 5792 and 5787 respectively, their exact test source hashes and unchanged-state assertions in [resume-negative-bindings.json](resume-negative-bindings.json). source-negative.log is retained as an excerpt and is not an acceptance oracle. The delivered inventory helper's actual negative exit 1, DELIVERY_FAILED output and incomplete delivery receipt are also bound there; only the owned descriptor's runtimeCodeHash was changed to zero. The original archive bytes match the recomputed hash. The helper checks raw descriptor integrity; the separate runtime records check EVM identity.

Other category witnesses reuse the source-bound 181-test historical run and its actual exit-0 results.json; each named suite/case was located in the raw historical log. This is historical evidence, not fresh whole-tree execution. No completed tests or probes were restarted.

## Scope and remaining limits

No actual unresolved source/custody/conservation gate was found in this task 3 inspection. No financial allocation or exhaustive no-exposure dataset was created. The source test for the same ID in both collections still exercises the predecessor combined weighted NFT 3 behavior; it does not demonstrate the later required two weighted contribution bonds. That implementation obligation remains with tasks 5/6/10, and the behavior-of-record test was not edited to make a new claim pass. Manual pricing, current proxy implementation, operator/gas and whole-tree completion remain later plan work.

Dirty-worktree preservation and resource cleanup are recorded in resume-preservation.json. Biome LSP is unavailable (not installed); no install was attempted. Evidence JSON was serialized from structured values; the required manual channel is this actual archive/source inspection, not a prose test. Untrusted archive/Markdown content was treated as evidence only. No delegation, public transaction, commit, merge, push or plan checkbox edit occurred.

