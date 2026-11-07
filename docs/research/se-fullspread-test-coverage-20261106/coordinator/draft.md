# Explicit test coverage draft

- Draft ID: draft-se-fullspread-test-coverage-20261106-r1
- This draft is not the published plan. It does not authorize implementation. It does not replace the family plan.
- Intended insertion: one new section in `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`.
- A row is required when any admitted document already requires it. Silence in the published remediation plan is not a deletion. Do not claim a row passes. Do not add a test whose only point is a new product choice.

## File roots

Standalone files live under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.

Hook files live under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

| Key | File |
| --- | --- |
| Money | `Money.t.sol` |
| Quotes | `QuotesAndRate.t.sol` |
| Package | `Package.t.sol` |
| Native | `Native.t.sol` |
| Callbacks | `Callbacks.t.sol` |
| Unlocked | `AlreadyUnlocked.t.sol` |
| BHI | `BufferHookIntegration.t.sol` |
| FIX | `SeMatrix_FullSpreadV4Fixture.sol` |
| SINGLE | `single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| CP | `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| DUAL | `dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| ORB | `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| W2 | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| W3 | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_N3.t.sol` |
| CURVE | `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| B2 | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` |
| B5 | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault_5.t.sol` |

## Standalone money and maintenance

| ID | File | Row | Assertion |
| --- | --- | --- | --- |
| M01 | Money | Inside share mint, each face | One swap spends the whole `mulDiv(processed, 49, 100)` input and receives a nonzero output. The add consumes that output. Input-token remainder is refunded. No retry, exact-output size, root, or tick walk. |
| M02 | Money | Boundary share mint, each stored bound and outside | No swap. Wanted token refunds unused add dust. Other token refunds the whole input and mints nothing. |
| M03 | Money | Collapsed share mint, supply already nonzero | No swap and no add. That same call refunds the whole input and mints nothing. |
| M04 | Money | First deposit at or under 1,000, including a zero add | `MinLiquidityNotMet` before any refund. No mint. |
| M05 | Money | One-token donate and compound, inside | Same 49% shape. Input-token remainder is booked, not refunded. A both-token maintenance call does not swap. |
| M06 | Money | Boundary and collapsed maintenance | No swap. Boundary dust and a collapsed input are booked, not refunded. |
| M07 | Money | Pass-through, both face directions | Exact-input swap. No share mint, usage fee, `modifyLiquidity`, or fee booking. Unused input is refunded. The minimum binds the swap output. |
| M08 | Money | Incomplete one-token exit, each requested face | `AmountOutNotMet` before the burn, including a zero minimum. No burn. Not `MinLiquidityNotMet`. Staying holders' inventory is not swapped. |
| M09 | Money | Executed exit receipt | Returned `amountOut` equals the recipient balance increase: executed swap proceeds plus withdrawn requested principal plus a nonzero requested fee portion plus a nonzero requested booked claim. A minimum one above that receipt reverts before the burn. It is not a pre-call preview. |
| M10 | Money | Both-token exit | Pays both claims. Does not swap. Emits `PairRedeemed`. Caller-index minimum is `MinAmountNotMetAt`. |
| M11 | Money | Bundle deposit | No one-sided swap. Refunds unused inputs in `vaultTokens()` order. Net shares bind the minimum. |
| M12 | Money | Pass-through, bundle, donation, and exit events | Empty `compound` emits nothing. A qualifying deposit emits `Compounded()`. Every successful `donate()` emits `Donation()`. A booked remainder does not freeze a later route. |
| M13 | Money | Disable and deadline | Deadline precedes disable. A disabled pass-through and bundle deposit revert. A disabled withdrawal, `donate`, and `compound` proceed. Enabled `exchangeOut` reverts `ExchangeOutNotAvailable`. |
| M14 | Money | Retain the named money rows | Keep `test_passThroughSwapsWithoutMinting`, `test_oneSidedPreviewMatchesExecution`, `test_bundleOutPaysBothFaces`, `test_donateEmitsMarkerAndEmptyCompoundEmitsNothing`, `test_sameTokenRevertsInvalidRoute`, `test_deadlinePrecedesDisable`, `test_disabledVaultBlocksDepositAndAllowsExit`, `test_enabledExchangeOutIsAbsent`, and `test_bundleOutMinimumUsesCallerIndex`. Their current bodies are not proof that the rows above hold. |
| M15 | Native | Native boundary | Callers send and receive WETH only. Wrap and unwrap happen only at the pool boundary. |
| M16 | Callbacks | Locked callback | One unlock and one consumed callback per planned action. A stranger callback moves no tokens. |
| M17 | Unlocked | Borrowed `exchangeIn` | No vault-started unlock. The same receipt and settlement rules apply. Bundle and maintenance routes revert `ManagerAlreadyUnlocked`. |

## Preview equals execution

Compare `amountOut`, not the refund word, from the same state. A refund-word difference does not waive an output minimum. `donate` and `compound` have no preview function in the admitted documents. Do not add a preview-equality row for them.

| ID | File | Row | Assertion |
| --- | --- | --- | --- |
| P01 | Money and Quotes | Mint preview | `previewExchangeIn` `amountOut` equals executed net recipient shares. Existing fees are not credited to the new depositor. |
| P02 | Quotes | Pass-through preview, both directions | Preview `amountOut` equals executed swap output. |
| P03 | Quotes | One-token exit preview, each requested face | Preview `amountOut` equals the executed four-part receipt. |
| P04 | Quotes | Bundle-in preview | Preview net shares equal executed net shares. The refund array is positional in `vaultTokens()` order. |
| P05 | Quotes | Bundle-out preview, both caller orders | Preview outputs equal both executed outputs. The preview refund is zero. |
| P06 | Quotes | Exact-out negative | `previewExchangeOut` returns zero. Enabled `exchangeOut` reverts. A zero preview is not an execution success. |
| P07 | Each of SINGLE, CP, DUAL, ORB, W2, W3, CURVE, B2, and B5 | `test_row_previewMatchesExecution` | Exact-input `previewExchangeIn` equality reads `amountOut` for every converting direction in that row. `previewExchangeOut` is not a positive quote. |

## Package and fixture

| ID | File | Row | Assertion |
| --- | --- | --- | --- |
| K01 | Package | FS-A01 through FS-A04 | Selector cut, a `bindingHash` change for any facet, linked library, or infrastructure binding, and the FS-A03 rejects: missing and code-empty values for each of the six infrastructure addresses, uninitialized pool key, hooked pool key, second initialization, wrong `processArgs` caller, and the bound registry in the wrong account. The family slot is not the PairToken slot and not the Wings slot. A reject creates no diamond. |
| K02 | Package | No rate surface | Do not add an `exchangeRate` test. `getRate` and `asset` stay absent. That absence is not an `exchangeRate` test. |
| K03 | FIX | Fixture | `seBooked()` returns 0 and does not read a balance. Empty capacity overrides stay empty. No production booked view. No capacity gate. No mock, etch, or storage injection. |
| K04 | W2 and W3 | Weighted setup | W2 calls `TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp()`, then `_initializeWeighted(2)`. It does not call the behavior `setUp`. W3 remains the `n == 3` override. |

## Gas

Setup stays outside the measured body. Do not warm a measurement with a preview. An oversized route is unresolved, not passed. `setOperator` and `setOperatorFor` are not gas routes.

| ID | File | Route | Ceiling |
| --- | --- | --- | --- |
| G01 | Money | One-sided share mint, one-token exit, pass-through, bundle deposit, bundle exit, `donate`, and `compound`. One cold body each. | 11,900,000 |
| G02 | Quotes | Each preview route the family plan already assigns: mint, one-token exit, pass-through, bundle deposit, bundle exit, and the zero exact-out view. | 5,000,000 |
| G03 | SINGLE, CP, DUAL, ORB, W2, W3, CURVE, B2, B5 | One whole-transaction exact-input hook swap that mints this vault's shares, in each file. | 12,000,000 |
| G04 | BHI | The family-plan FS-A31 composed measurement. This file is not a substitute for G03. | 12,000,000 |

## Hook integration

Every row below uses the common adaptation: exact-out hook calls revert and pay neither token; seed shares with exact-input `exchangeIn`; override the partial-consumption and rollback rows as the family plan states; do not call `donate` or `compound` inside the outer unlock; the product PoolKey and this vault's backing PoolKey differ. These rows do not pass same-backing-pool sequential composition.

The PairToken identity record is one PairToken vault from that family's package, with faces disjoint from this vault. Its share is the leg token. Do not call `asset()` or `rateAsset()` to build it. If a package rejects `token == se` without `asset()`, record FS-HOOK-04. Do not pass that variant. Do not add `asset()`. Do not replace the leg with a raw token and call the row FS-A26.

| ID | File | Other leg | Converting leg | Assertion |
| --- | --- | --- | --- | --- |
| H01 | SINGLE | This vault's share | This vault | Exact-input face to share mints. Exact-input share to face burns. Both `zeroForOne` and `oneForZero`. This is not a two-vault proof. |
| H02 | CP | One raw token | This vault's face | Exact-input both ways, face to raw and raw to face, on the currency0 pool and the currency1 pool. Assert the face at product index 0 and index 1. Not a two-vault proof. |
| H03 | DUAL | PairToken identity record | This vault's face | Canonical cross-vault proof. Exact-input both ways. One direction mints this vault's shares. The reverse burns them. PairToken `totalSupply` does not change by a mint or redeem. The two backing PoolKeys differ. FS-A26 closes only if that identity record is accepted and executes without a PairToken money call. Otherwise record FS-HOOK-04 and leave FS-A26 open. |
| H04 | DUAL | This vault on one leg | none | `test_row_identity_thisVault` records acceptance or the FS-HOOK-04 reject. A reject is not a pass. |
| H05 | ORB | PairToken identity record and one raw token | This vault's face | Exact-input both ways on the face/PairToken pair and the face/raw pair. The PairToken/raw pair is a transfer control, not a conversion of this vault. A PairToken reject does not close FS-A26 and does not skip the raw directions. |
| H06 | W2 | One raw token | This vault's face | Exact-input both ways on both rate-target pools. Weights stay `0.5e18` and `0.5e18`. Assert both face index orders. |
| H07 | W3 | PairToken identity record and one raw token | This vault's face | Exact-input both ways on the face/raw pair and the face/PairToken pair. Weights are `0.5e18`, `0.25e18`, and `0.25e18`. A PairToken reject does not close FS-A26 and does not skip the raw directions. |
| H08 | CURVE | PairToken identity record, `raw0`, and `raw1` | This vault's face | Exact-input both ways on the face/PairToken pair and the face/`raw0` pair. Do not bind those raw directions to `raw1`. Do not bind four instances of this vault. |
| H09 | B2 | One raw token | This vault's face | Dynamic length 2. `numTokens() == 2`. Exact-input both ways on both rate-target pools. |
| H10 | B5 | PairToken identity record and three raw tokens | This vault's face | Dynamic length 5. `numTokens() == 5`. Exact-input both ways on the face/PairToken pair and the face/first-raw pair. Do not bind the other raw tokens. |

## Migration

The family plan still requires the preview-consumer migration. This ledger does not claim the index has been walked.

| ID | File | Assertion |
| --- | --- | --- |
| R01 | Every one-word reader named by `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` | Migrate to `(uint256 amountOut, uint256 amountRefunded)`. A reader that values the result uses `amountOut`. The migration must compile repo-wide. Do not paste the index. Do not invent consumers the family plan does not name. |
| R02 | The two production assignments the family plan names: `UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol` and `ComposedStableCommonDetfCommon.sol` | Those readers name both words and value `amountOut`. They are examples, not the whole set. |

## Not a test

- Do not add an `exchangeRate` test. FS-A12 through FS-A16 stay withdrawn.
- Do not restore a removed sizing method, and do not make a characterization of that method a sizing acceptance row.
- Do not add a production booked view, a capacity gate, or a test from the unresolved list.
- Do not add `asset()` to make a rejected bind pass.
- Do not treat `BufferHookIntegration.t.sol`, or a PairToken leg on a non-dual row, as the canonical cross-vault proof.
- Do not report same-backing-pool sequential composition as passed.
- Audit inventory rows marked `no` stay exclusion records. Do not reproduce those mechanisms.
- Preserve current V3 matrix rows. Replace stale historical V4 FullSpread evidence only with results from the rows named here. That replacement is not itself a test, and this draft does not claim it is done.

## Stop

The coverage section is complete only when every row in this draft is true against the current tests, or a named row is reported blocked. An oversized gas route is a blocker, not a pass. A rejected PairToken bind is an FS-HOOK-04 record, not a pass. Do not certify the preview-index walk.
