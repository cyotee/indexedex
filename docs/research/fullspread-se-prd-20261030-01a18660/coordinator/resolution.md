# Resolution — fullspread-se-prd-draft-r1

Coordinator resolution after one advisory round. The frozen draft was not edited. Final text is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, revision `fullspread-se-prd-final-r2`. These changes are coordinator revisions, not a new member vote.

## Advisory outcomes

| Member | Disposition |
| --- | --- |
| Astra | REQUEST CHANGES |
| Grok | SUPPORT WITH CORRECTIONS |
| MiniMax | SUPPORT WITH CORRECTIONS |
| Kimi | REQUEST CHANGES |

## Adopted

| Concern | What changed |
| --- | --- |
| Grok C1 and Astra C2 and Kimi FS-ADV-02 | Named FS deltas override only the named inherited clauses. `FS-X01` replaces the already-unlocked reject for `exchangeIn` only. `FS-X02` replaces the provider exclusion. S1-A40 no longer contradicts the hook path. |
| Grok C2 and Astra C4 and Kimi FS-ADV-06 | `moneyFacet` lists `exchangeIn`. Selector manifest is 61. Query facet is not the PairToken facet address. New errors are declared. |
| Grok C3 and Astra C7 and Kimi FS-ADV-03 and MiniMax C4/C5 | Identity `token == share` is not a passing row. Do not add `asset()`. Canonical proof buffers FullSpread into `rateAsset` and does not ask another SE to convert inside the unlock. Family rows are topology-specific. A cited reject does not replace that proof. |
| Grok C4 and MiniMax C7 | `getRate` is `rateAsset` only. The other face is FS-HOOK-04. A rate read requires supply of at least one share. |
| Grok C5 | FS-A26 is exact-input both directions, not exact-out. |
| Grok C6 | Hook rows assert position owner, ticks, salt, and S1-ACC-06 on the borrowed path. |
| Astra C1 and Kimi FS-ADV-01 | Locked path is one unlock per planned action. Borrowed path performs zero unlocks. |
| Astra C2 remainder | `FS-X04` names complete selected-swap consumption. `J_i` booking stays. The phrase "booked donation" was removed. |
| Astra C3 | TestBase follows the current PairToken CREATE3 manager setup. Hook and vault share that manager. |
| Astra C5 | Nonpayable value failure is an ABI boundary, not `InvalidUnlockedContext`. |
| Astra C8 | FS-A31 through FS-A38 close composed gas, busy reads, fee parity, foreign deltas, native sync, caught failures, permissionless funding, and disabled issuance. |
| Astra C9 and Kimi FS-ADV-05 and FS-ADV-07 | ERC-8109 is excluded and still checked on the proxy. `processArgs` requires both the registry caller and the factory account. Target filenames are fully qualified. |
| MiniMax C1 | `recipient == msg.sender` is not required. Weighted `unwrap` pays `to`. Buffer helpers pay the hook. Self-funding stays. |
| MiniMax C2 | Borrowed settlement does not copy the global `getNonzeroDeltaCount` check. |
| MiniMax C3 | Borrowed settlement is atomic sync, transfer, settle, and does not `settleFor` a foreign address. The global `CurrencyReserves` slots are cited. |
| Kimi FS-ADV-04 | Excluded quote names are the three interfaces the hook libraries actually probe. |

## Not adopted as written

| Claim | Disposition |
| --- | --- |
| Omit `getRate` | Rejected. Buffered `rateAsset` legs need the one-share rate. The full-book provider is the wrong formula. |
| Thirteenth `RateFacet` | Withdrawn by MiniMax and rejected. One selector stays on `queryFacet`. MiniMax is right that `bindingHash` changes either way because the query facet bytecode changes. The reason to refuse the extra facet is one rate authority and a stable twelve-field shape, not a claim that the hash would be unchanged. |
| Return zero below one share | Withdrawn by Kimi. Revert stays. |
| Unlock compound, donate, paired methods, and SY | Rejected. Current hooks call `exchangeIn`. |
| Hook allowlist | Rejected. Circular with deployment. |
| Every input wei becomes liquidity | Rejected. Conflicts with `J_i`. |
| MiniMax C6, that orbital `se0` does not exist | Not adopted. Package `PkgArgs` contains `se0`, `se1`, and `se2`. The hook view is `standardExchange(uint8)`. The final names both. |
| One unlock per public `exchangeIn` | Rejected. It contradicted the PairToken action dispatcher and was not a specified replacement. |

## Unresolved on purpose

Same-backing-pool sequential composition is unverified. A hook bind that requires `asset()`, a second rate denomination, or a both-buffered PairToken call is FS-HOOK-04, not a silent hook edit. No implementation was authorized.
