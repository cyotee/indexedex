# Consumers of the old 32-byte preview return

## Question

- Run ID: se-fullspread-preview-consumers-20261103
- Question: What is the complete in-repo list of consumers of the old 32-byte `previewExchangeIn` return?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the owner accepted F13 and F14, and told the council to find all consumers and write a complete list
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.
- The PRD, the blockers file, and prior resolution drafts were not edited.

## Owner acceptances, not reopened

- F13: accepted. Deployed liquidity is the raw liquidity number used in mint and burn. Deployed token reserves are the token amounts plus unpaid fees returned by `reserves()` and `reserveOfToken`.
- F14: accepted. The PRD pass replaces the named compound and idle sentences with the B-02 lock and the principal-only withdrawal rule.

## Participation

| Participant | Requested model | Task ID | Status |
| --- | --- | --- | --- |
| Coordinator | invoking session model | not exposed | complete |
| astra | `chatgpt-subscription/gpt-6-astra:high` | st_01a1a1c1 | completed |
| grok | `xai/grok-4.7:xhigh` | st_01a1a1c2 | completed |
| minimax | `minimax/MiniMax-M3` | st_01a1a1c3 | completed |
| kimi | `kimi-coding/k3.1-pro:high` | st_01a1a1c4 | completed |

- Missing initial responses: none
- Advisory on this merged list: not run. The four inventories were compared, and the fail-closed gates were re-read. This merged list is not a second member-approved text.

## Consumers that reject a non-32-byte success

These were named by all four inventories. Each was re-read. A successful `(uint256, uint256)` return is 64 bytes, so each of these treats that success as failure.

| Path | Lines | What it does |
| --- | --- | --- |
| `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` | 103-106 | Empty-supply preview. `staticcall`, then `data.length != 32` returns 0. |
| `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` | 121-125 | Live preview. Same 32-byte gate, then one-word `abi.decode`. |
| `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` | 65-68 | Same gate. Returns `(false, 0)`. |
| `contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol` | 437-444 | `ret.length != 32` returns false, then one-word decode. |
| `contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol` | 463-470 | Same gate. |
| `contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol` | 474-481 | Same gate. |

The rate-provider path is the one named at blockers file line 196. The three hook targets are the other production gates.

`contracts/test/bases/FundedThresholdAssertions.sol` lines 60-63 decode one word and do not check the length. All four inventories name it. It was not re-read in this merge. A 64-byte return would be misread as the first word rather than rejected.

## ABI bindings that still declare one word

| Path | Lines | Decoding |
| --- | --- | --- |
| `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | 45-48 | `returns (uint256 amountOut)`. Comment selector `0x89d61912`. |
| `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts` | 69-76 | `previewExchangeIn` output is one `uint256`. |
| `frontend/packages/protocol/src/protocolDetfAbi.ts` | 33-40 | `previewExchangeIn` output is one `uint256` named `amountOut`. |

A typed Solidity call through the Crane interface reads that one word. Those call sites are in the index. They do not have their own length check. They break when the interface return changes, not before.

## Complete occurrence index

`INDEX.md` in this directory is every textual `previewExchangeIn` occurrence in `*.sol`, `*.ts`, and `*.tsx`, excluding `node_modules`, `out`, `artifacts`, `cache`, and `broadcast`.

- Occurrences: 1626
- Files: 618

That index is the complete file list. It includes comments and names, so it is wider than the decoder list. The four member files split those lines into `migrate` and `unaffected`. Their counts do not match, and this report does not pick one count.

| Inventory | What it counted |
| --- | --- |
| astra | `members/astra/response.md`, 1535 lines |
| grok | 170 production sites in 48 files, 11 script sites, 915 test sites, plus preserved copies |
| minimax | 1389 call hits, 629 rows, 460 `migrate`, 169 `unaffected` |
| kimi | 423 preview rows, 1077 cited lines; generated trees excluded |

The disagreement is classification, not the fail-closed gates. Grok included generated `typechain` output. Kimi excluded gitignored generated trees. Astra and MiniMax treated a success-only call as unaffected. A call that ignores the returned word does not decode it. It is still bound to the old interface.

## Not this list

`previewExchangeOut`, `exchangeOut`, and the multi-token previews were examined by the members and are not this return change. `exchangeIn` also changes from one word to the tuple. Its decoders are in the member files and are not mixed into this preview list. The comment selector on the current Crane `exchangeIn` is `0x05562cc8`. The accepted interface report names `0xd02d3063`. Neither was recomputed here.

## Limits

- The six production gates and the three ABI bindings were re-read. The 1626-line index was generated from search output and was not line-audited.
- No Forge run. The 64-byte failure is from the ABI width, not an execution.
- This list does not authorize implementation or a PRD edit.
