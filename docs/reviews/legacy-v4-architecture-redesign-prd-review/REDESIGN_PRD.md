> **Superseded — legacy family deleted (2026-10-15).** Retained as historical evidence only. Do not execute this plan or restore its implementation. See the [removal report](../legacy-v4-removal/EXECUTION_REPORT.md).

# Legacy V4 Standard Exchange architecture redesign

- **Status:** WITHDRAWN, 2026-10-15. The owner is deleting `contracts/protocols/dexes/uniswap/v4`. Do not implement this design or its plan.
- **Updated:** 2026-10-15
- **Why this file:** The owner asked to rewrite `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md`. The review-council guard rejected a write under `contracts/`. This file is the rewritten PRD.
- **Owner ruling:** The current inheritance, self-call, and delegate design is unacceptable and must be replaced regardless of whether a facet is under the size limit.
- **Council:** Astra `ses_ec412bcc2ffejKLo7nuoEAqbV0`, Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`, MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`, Kimi K3 replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. The closed design follows Grok's selector table and Kimi's cross-review. MiniMax's retained delegates are rejected. Astra's sixteen-facet split is not adopted.

## Required outcome

Replace the god base, the two execution delegates, and self-calls to public previews with internal libraries and thin facets. Keep the supported Standard Exchange and native Pendle SY behavior, the full-range managed position, and the funded sleeve. Do not invent a new economic model.

A later implementation plan sequences this design. It does not choose another one.

## Design

Storage stays in the existing repos: `ERC20Repo`, `EIP712Repo`, `Permit2AwareRepo`, `StandardVaultRepo`, `MultiAssetBasicVaultRepo`, `VaultFeeOracleQueryAwareRepo`, `UniswapV4PoolManagerAwareRepo`, `UniswapV4PoolKeyAwareRepo`, `UniswapV4PositionRepo`, `UniswapV4TwapOracleAwareRepo`, and `WETHAwareRepo`. Do not add a family storage slot for a value those repos already store. Do not add a new local-credit slot. Pretransfer credit stays the calculation the current legacy V4 code already uses.

Internal libraries live under `contracts/protocols/dexes/uniswap/v4/internal/`. Each has one responsibility. Facets do not inherit `UniswapV4StandardExchangeCommon`, `UniswapV4StandardExchangeInBase`, or `UniswapV4StandardExchangeOutBase`. A query facet does not inherit an execution target.

| Path | Responsibility |
|---|---|
| `internal/UniswapV4StandardExchangeConfig.sol` | Read the initialized pool key, token faces, managers, and TWAP oracle. One internal token-validity predicate. `_requireNotDisabled` and unlock-state gates. |
| `internal/UniswapV4StandardExchangeAccounting.sol` | One book: sleeve, exact deployed amounts, and earned fees counted once. One `_quoteZapOutAmount`. Share and issuance math. |
| `internal/UniswapV4StandardExchangeCustody.sol` | Pull, credit, burn by an explicit holder, payout, and the current operation-bounded refund. |
| `internal/UniswapV4StandardExchangePoolOps.sol` | One swap, liquidity add or remove, fee collect, zap-in deposit, and zap-out withdrawal body, used inside the unlock. |
| `internal/UniswapV4StandardExchangeReserve.sol` | Deadband and ratio-limited rebalance. No swap to force a ratio. An unexpected external failure reverts. No catch-all. |
| `internal/UniswapV4StandardExchangeImport.sol` | NFT intake only: authorization, matching pool, decrease and collect, conversion into the managed book. |
| `UniswapV4StandardExchangeCallbackTarget.sol` | The one `unlockCallback` body. Validates the PoolManager caller and settles the decoded operation. |
| `UniswapV4StandardExchangeCallbackFacet.sol` | Declares that one selector. |
| `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` | The existing SY error declarations, signatures unchanged. |

The other current facet names stay. Their bodies call these libraries. They do not grow a second copy of a settlement function.

## Selector owners

One selector, one facet. Do not merge these groups. Do not split `exchangeIn` across facets. The five shared facets are not redesigned.

| Selector | Owner |
|---|---|
| `IERC20Metadata.name`, `symbol`, `decimals` | `ERC20Facet` |
| `IERC20.totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom` | `ERC20Facet` |
| `IERC5267.eip712Domain` | `ERC5267Facet` |
| `IERC20Permit.permit`, `nonces`, `DOMAIN_SEPARATOR` | `ERC2612Facet` |
| `IBasicVault.vaultTokens`, `reserveOfToken`, `reserves` | `MultiAssetBasicVaultFacet` |
| `IStandardVault.vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig` | `MultiAssetStandardVaultFacet` |
| `IUnlockCallback.unlockCallback` | `UniswapV4StandardExchangeCallbackFacet` |
| `IStandardExchangeIn.exchangeIn` | `UniswapV4StandardExchangeInFacet` |
| `IStandardizedYield.deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards` | `UniswapV4StandardExchangeInFacet` |
| `IStandardExchangeTransitionQuote.quoteAssets`, `quoteShareBalance`, `quoteTransition`, `quoteTotalSupply` | `UniswapV4StandardExchangeInQueryFacet` |
| `IStandardExchangeExternalQuote.quoteExternalExchange`, `quoteExternalDeposit` | `UniswapV4StandardExchangeInQueryFacet` |
| `IStandardExchangeIn.previewExchangeIn` | `UniswapV4StandardExchangeInMultiQueryFacet` |
| `IStandardExchangeInMulti.previewExchangeInManyToOne` | `UniswapV4StandardExchangeInMultiQueryFacet` |
| `IStandardExchangeInMulti.exchangeInManyToOne` | `UniswapV4StandardExchangeInMultiFacet` |
| `IStandardExchangeOut.exchangeOut` | `UniswapV4StandardExchangeOutFacet` |
| `IStandardExchangeOut.previewExchangeOut`, `IStandardExchangeTransitionQuote.quoteState` | `UniswapV4StandardExchangeOutQueryFacet` |
| `IStandardExchangeOutMulti.exchangeOutOneToMany` | `UniswapV4StandardExchangeOutMultiFacet` |
| `IStandardExchangeOutMulti.previewExchangeOutOneToMany` | `UniswapV4StandardExchangeOutMultiQueryFacet` |
| The twelve SY discovery and preview selectors now on `UniswapV4StandardExchangeOutMultiQueryFacet` | That same facet |
| The seven `IUniswapV4StandardExchangeLiquidReserve` selectors | `UniswapV4StandardExchangeLiquidReserveFacet` |
| `IUniswapV4StandardExchangePositionImport.importPosition` | `UniswapV4StandardExchangePositionImportFacet` |

`UniswapV4StandardExchangeDFPkg.facetCuts` installs the five shared facets, then callback, IN, IN query, position import, OUT, OUT query, liquid reserve, IN multi, IN multi query, OUT multi, OUT multi query. No other family facet is added.

## Calls

- Deposit calls `_executeZapInDeposit` internally. It does not `delegatecall`.
- Share exit keeps the current internal `_executeZapOutExactIn(..., address(this))`.
- Yield redemption keeps the current internal `_executeZapOutExactIn` and the following `_pokeBoundPoolTwap`. Vault-held yield passes `address(this)`. Ordinary yield passes `msg.sender`.
- `exchangeOut` calls internal quote and withdrawal functions. It does not call `previewExchangeOut` on `address(this)`. The withdrawal body moves once from the OUT delegate into `UniswapV4StandardExchangePoolOps`.
- SY `deposit` and `redeem` call the existing `_requireNotDisabled` before burn or token movement. That is REQ-V4-02. Do not import a V3 or FullSpread exemption. Do not add that check to a view selector.
- `rebalanceLiquidReserve` may no-op or partially adjust for deadband, rounding, or an insufficient deployable ratio. Any other external failure reverts the transaction. Do not add a catch-all.
- No in-scope production path calls or `delegatecall`s `address(this)` to reuse an entrypoint, quote, or settlement.

## Delete

- `UniswapV4StandardExchangeInExecutionDelegate.sol`
- `UniswapV4StandardExchangeOutExecutionDelegate.sol`
- Both delegate constructor arguments and factory deployments
- `_delegateExecuteZapInDeposit` and `_delegateExecuteZapOutWithdrawal`
- `contracts/vaults/standard/sy/NativeStandardYieldExecutionTarget.sol`
- `UniswapV4StandardExchangeCommon.sol`, `UniswapV4StandardExchangeInBase.sol`, and `UniswapV4StandardExchangeOutBase.sol` after their bodies have moved
- `UniswapV4StandardExchangeOutTarget.sol`, the unused combiner, after a search confirms it still has no importer
- `_deployExcessImported`, `_increaseImportedPositionCommon`, and `_increaseImportedPosition`

Do not delete the import decrease and collect used by `importPosition`. Do not delete a shared repo field. Do not delete `NativeStandardYieldTarget.sol`. Other families change only import paths from the deleted shim to `NativeStandardYieldTarget.sol` or `NativeStandardYieldErrors.sol`. Do not redesign V3, hookless, or Pons.

A quote helper is deleted only after a repository-wide search shows it has no consumer. If a consumer exists, report it. Do not delete it in this item.

## Size

24,576 bytes is the hard runtime limit for every deployed facet. 23,000 bytes is advisory. Record a miss below the hard limit. Exceeding 24,576 stops the work. Do not restore a hop, a self-call, or `via_ir` to get under either number. Do not assume that fewer files make the runtime smaller. Measure after the move.

The earlier 31,908-byte figure remains an unverified claim. It is not the acceptance gate.

## Decisions

| ID | Decision | Status |
|---|---|---|
| D1 | Replace the god base, delegates, and self-calls with the libraries and callback facet named above. | Decided 2026-10-15 |
| D2 | Preserve supported SE/SY behavior, the full-range book, and the funded sleeve. | Decided |
| D3 | Delete the SY import shim. Other families receive import-path changes only. | Decided by this rewrite |
| D4 | One callback facet. Both execution delegates are deleted. No replacement delegate. | Decided by this rewrite |
| D5 | Imported NFTs are intake only. Normal operations use the converted managed position. | Decided |
| D6 | Include the REQ-V4-02 disable check on SY deposit and redeem. | Decided |
| D7 | Fresh package instances only. No existing-instance migration. | Decided by this rewrite |
| D8 | Unexpected rebalance failures propagate. Deadband and ratio limits may no-op. | Decided |
| D9 | Hard limit 24,576. Advisory target 23,000. | Decided by this rewrite |

## Non-goals

- Do not add a share token, a NAV formula, a public holder-selecting endpoint, or a substitute delegate.
- Do not repair the stored-reserve pretransfer credit residual in this redesign. Preserve the current calculation. A correction of that residual is a separate owner-ruled item.
- Do not redesign V3, hookless, Pons, DETF, or hook packages.
- Do not upgrade live instances or claim storage compatibility with them.
- Do not treat this document as a passing test or a measured size.

## Dissent recorded, not adopted

- MiniMax kept both execution delegates. This rewrite deletes them.
- Astra split the family into sixteen facets and added a new local-credit storage slot. This rewrite keeps the current facet owners except for `unlockCallback`, and it does not add that slot.
- Kimi's first design merged the dual-token facets into IN and OUT. The cross-review withdrew that merge.

Writing this document does not start implementation.
