# Member response

## Identity

- Run ID: hook-failure-diagnosis-20261105
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/hook-failure-diagnosis-20261105/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: What shared code paths cause the listed Foundry failures, and what is the smallest fix direction that restores them without changing the live 49% one-sided fraction and without making `asset()` a bind requirement?
- Required targets: the failure list in the brief; `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol`; the `processArgs` bind checks in the dual, single constant-product, orbital, weighted, Balancer quad, and Curve quad hook packages; `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` `_size`; `UniswapV4FullSpreadStandardExchangeVaultMath.sol` `sizeOneSided` and `_liquidityFittingOut`
- Optional context: `docs/reviews/se-fullspread-plan-execution-20261104/IMPLEMENTATION_AND_TEST_PLAN.md` section 3; the full-spread family PRD FS-OWN-33 lock. Not read. No requirement is taken from them.
- Admitted read scope: the required targets, the failing test files named in the brief, and the hook or vault functions those tests call. Unread files are not treated as examined.
- Public queries: not used

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Failure list | brief, Failure list supplied by the user | coordinator-supplied | Two clusters. Cluster A is bind or inventory reverts (`TokenNotInVaultTokens`, `InvalidSE`, `EvmError: Revert`, empty expected revert). Cluster B is full-spread hook rows after the 49% sizer change. These results were not re-executed. |
| Bind predicate | `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:172-180` | source observation | `pairInVaultTokens` returns true only when `pair` is an element of `IBasicVault(se).vaultTokens()`. It returns false for a zero address or empty code. It does not call `asset()`. The `vaultTokens()` call is not caught. |
| Wrapper classification | same file, `182-192` | source observation | `isWrapperShareInventory` is true only when `pair == se` and a staticcall to selector `0x38d52e0f` returns a non-zero address different from `pair`. The comment says it is not a bind gate and that bind membership is `pairInVaultTokens`. The staticcall failure returns false. |
| Overlap gate | same file, `196-201` | source observation | `addPairSe` reverts `PairSeOverlap` when `pair == se` and `pairInVaultTokens` is false. It does not consult `isWrapperShareInventory`. |
| Rebasing token list | `contracts/protocols/staking/rebasingVault/RebasingAwareVaultMetadataTarget.sol:29-32`, `34-37` | source observation | `vaultTokens()` returns a one-element array of `_asset()`, not the share. `reserveOfToken` reverts `UnknownReserve` unless the token is that asset. |
| ERC-4626 token list | `contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol:52-56` | source observation | `vaultTokens()` returns the reserve asset, not the share. |
| Yield stub | `contracts/test/stubs/SimpleYieldERC4626.sol:17-18`, `94-96` | source observation | The stub implements `asset()` and does not declare `vaultTokens`. The `function vaultTokens` index of `contracts/` and `test/` did not list this file. |
| Unit overlap test | `test/foundry/spec/hooks/uniswap/v4/interfaces/UniswapV4SeBufferHookLegLib.t.sol:123-125` | source observation | `test_addPairSe_wrapperShareInventory_allowsOverlap` deploys `SimpleYieldERC4626` and calls `addPairSe(wrapper, wrapper)` with no expected revert. Supplied result: `EvmError: Revert`. |
| Single bind | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:290-293`, `400-405` | source observation | `processArgs` calls `_validateArgs`. That reverts `TokenNotInVaultTokens` when `pairInVaultTokens` is false, and only then applies `isWrapperShareInventory` to decimals. |
| Dual bind | `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:391-392` | source observation | `_requireTokenInVaultTokens` reverts `TokenNotInVaultTokens` when `pairInVaultTokens` is false. No wrapper allowance. |
| Orbital, weighted, Balancer, Curve binds | orbital package `408-410`; weighted package `450-451`; Balancer package `412-413`; Curve package `422-423` | source observation | Each `_requireSeOwnsToken` reverts `InvalidSE` when `pairInVaultTokens` is false. Wrapper classification is used for decimals, not for this reject. |
| Wrapper args | `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Buffers.t.sol:298-305` | source observation | The single-CP wrapper args set `standardExchange` and `pairToken` to the same wrapper. |
| Ordinary-overlap expect | `RebasingAwareERC4626_Buffers_Balancer.t.sol:58-62` | source observation | The reject test sets `standardExchanges[0] = tokens[0]` and expects `InvalidSE`. The same shape is in the Curve, orbital, and weighted reject tests. Supplied result for those four: reverted as expected, but without data. |
| Dual reject expect | `RebasingAwareERC4626_Buffers_Dual.t.sol:59-64` | source observation | The non-wrapper overlap test uses `vm.expectRevert()` with no selector. |
| Bare-vault control | `UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_SimpleYieldERC4626Control.t.sol:32-48`; test base `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol:63`, `88-89` | source observation | `pairProtocolVault` is a `SimpleYieldERC4626`. The control sets `standardExchange` to that vault and expects deploy and registration to succeed, then an empty revert on the first deposit. Supplied result: `EvmError: Revert`. |
| Identity deploy | dual rebasing matrix test `36-44`; single rebasing matrix test `30-36` | source observation | Both identity tests set the pair token equal to the rebasing SE and then deploy. Supplied result: `TokenNotInVaultTokens()`. |
| Wings dual bind | `FullSpreadSameManagerAmmFixture.sol:109-116`, `199`; `UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol:108-109` | source observation | Dual deploy sets `standardExchange1` and `token1` to the rebasing wrapper. Wings `initAccount` sets the vault token list to `args.targetToken`, not the share. Supplied result on `test_dualCpJoinAndShareExit` and `test_review_dualCpJoinAndShareExit`: `TokenNotInVaultTokens()`. |
| 49% attempt | `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:168-201` | source observation | `_size` comments that the owner lock is one exact-input swap, not a search, and that 49% is the fraction under test. It sets `swapIn_ = FullMath.mulDiv(amount_, 49, 100)` and refunds the whole input only when that value is zero, above `uint256(type(int256).max)`, or the later fit returns no liquidity or no swap. |
| Fit | `UniswapV4FullSpreadStandardExchangeVaultMath.sol:56-98` | source observation | `sizeOneSided` refunds the whole input when the output-side liquidity is zero, `needOut != swapOut`, or `needIn > remaining`. Otherwise `remainder = remaining - needIn`. `_liquidityFittingOut` returns zero when the raw liquidity is zero or above `uint128`. |
| Quote surface | `UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol:14-18` | source observation | `previewExchangeIn` returns `plan.amountRefunded` from `Planner.planIn`. |
| Single residue assertion | `UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:76-84` | source observation | The test subtracts the preview refund from the amount at most eight times, then requires `refund < amount / 100`. Supplied failure: `18047715232245887 >= 8406086873546691`. |
| Sibling supply assertions | Balancer 5-leg file `33-43`; Curve file `152-162`; weighted N3 file `140-158` | source observation | Those direction helpers `expectCall` four selectors with count 0, then require sibling share supply unchanged. Weighted N3 places the `expectCall` on `pairRecord.p0()`, not on `pairRecord.share()`. Supplied actual supplies exceed `1000000000000000000054353`. The brief says the count-0 checks did not fail first. |
| Dual and orbital `test_row_index1` | dual full-spread file `307-312` and `_crossVaultDirections`; orbital full-spread file `159-168` | source observation | Those function bodies do not contain the supplied `assertLe` comparison. Their swap path calls the hook, and the hook's `_buffer` calls the SE `previewExchangeIn` and `exchangeIn` (`UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:358-363`). |
| Mint sites read | `UniswapV4FullSpreadStandardExchangeVaultExecution.sol:76`, `116`, `238-243` | source observation | Share minting in this file is `_mint`, reached from `exchangeIn` and `bundleIn`. No other mint in this file was read. |

## Assumptions

- none

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Failure list | required | examined | Read from the brief. Not re-executed. |
| `UniswapV4SeBufferHookLegLib.sol` | required | examined | Bind, wrapper classification, and `addPairSe` read. |
| Six package `processArgs` bind checks | required | examined | Single, dual, orbital, weighted, Balancer quad, Curve quad. |
| Planner `_size` | required | examined | Lines 168-201. |
| Math `sizeOneSided` and `_liquidityFittingOut` | required | examined | Lines 56-98. |
| Named failing tests and the hook or vault functions they call | required | partially examined | Bind tests, control test, identity deploys, Wings dual args, full-spread row assertions, quote and execution mint path read. DETF helper bodies that build the package args were not read. |
| Plan section 3 and FS-OWN-33 PRD lock | optional | not examined | Not required. Not used as a requirement source. |
| Dual and orbital `assertLe` callee | required to explain that supplied result | not examined | The comparison is not in the test bodies that were read. No production `assertLe` was found on the swap path that was read. |

## Conclusions

Cluster A has one shared gate and two observable failure modes. Cluster B has one shared sizer. The fix direction below does not change `mulDiv(amount_, 49, 100)` and does not make `asset()` a requirement for a bind.

### Cluster A

Source observation: every listed bind check routes through `pairInVaultTokens`, which is membership in `vaultTokens()` and nothing else. `isWrapperShareInventory` is documented as not a bind gate, and the package checks that consult it do so only after the membership reject. `addPairSe` rejects `pair == se` solely when that membership check is false.

Inference, separated from that observation: the supplied Cluster A results are the two ways that one call fails.

- When the candidate implements `vaultTokens()` and returns only the underlying, membership is false. The rebasing metadata target does that. A wrapper-share leg sets the pair equal to the SE, so the share is not in the list. `processArgs` then reverts `TokenNotInVaultTokens` or `InvalidSE` before the wrapper decimal allowance can run. That matches the supplied custom-error failures on the wrapper accept, join, quote, invariant `setUp`, identity deploy, DETF, and Wings dual rows. The Wings and dual-fixture reads show the bound token is the wrapper share, not the asset.
- When the candidate has no `vaultTokens()` implementation, the uncaught external call reverts with no error data. `SimpleYieldERC4626` is that candidate in the unit test and in the bare-vault control. A plain token used as both pair and SE is that candidate in the ordinary-overlap tests. That matches `EvmError: Revert` on the unit test and the control deploy, and "reverted as expected, but without data" where the test expected `InvalidSE`. The dual reject test expects any revert, so an empty revert does not by itself fail that one test.

`asset()` is already not a bind requirement. The wrapper staticcall is an allowance classifier, and only when `pair == se`. Making every bind call `asset()`, or requiring `asset()` to equal the pair, would contradict the question and would not fix the plain-token overlap tests.

Smallest fix direction:

1. Keep `pairInVaultTokens` as vault-token membership only. Do not call `asset()` there. If the `vaultTokens()` call fails, return false instead of bubbling. That turns the ordinary-overlap empty revert into the package error the tests already expect.
2. Before that reject, in `addPairSe` and in each of the six bind checks, accept the leg when `isWrapperShareInventory(token, se)` is true. Check that allowance before calling `vaultTokens()`, so a wrapper with no `vaultTokens()` does not bubble. This is an additional acceptance path for the already-defined identity case. It is not a requirement that a non-identity bind expose `asset()`.
3. Do not satisfy (2) by appending the share to `vaultTokens()`. The rebasing list is the asset, and `reserveOfToken` rejects every other token. Changing that list would couple bind to reserve indexing.
4. Do not reject a non-identity leg merely because `vaultTokens()` is absent. The bare-vault control expects that SE to deploy and to fail later, with empty data, on the first deposit. After (1), a false membership result must not become `TokenNotInVaultTokens` for that case. Reject a missing list only when `pair == se` and the wrapper allowance is false. A real vault whose `vaultTokens()` succeeds and does not list the pair, and which is not wrapper-share inventory, still reverts the package error.

### Cluster B

Source observation: `_size` quotes one swap of exactly 49% of the input, unless that amount cannot be quoted, and then `sizeOneSided` either refunds the whole input or returns a plan whose remainder is the unswapped input minus the paired token the fitted liquidity requires. `previewExchangeIn` returns that remainder.

Inference from the single-row test and the supplied comparison: `assertLt(refund, amount / 100)` failed with refund `18047715232245887` and bound `8406086873546691`. The bound is `amount / 100`, so the amount at the assertion was `840608687354669100` and the refund was about 2.15% of it, not the whole input. The eight-step subtraction cannot reach a residue if that ratio is unchanged at smaller sizes. A 49% quote that `sizeOneSided` accepts will keep a ratio of that kind, because both the swap and the fit scale with the input. This is arithmetic on the supplied values plus the loop that was read. It was not re-executed.

Inference, not a traced mint: the sibling-supply failures are on the assertion that a rejected sibling's share supply stays at `1000000000000000000054353`. The supplied actuals are larger by about `4.990e20`. The count-0 checks did not fail first, so those four selectors were not the observed calls. For weighted N3 the count-0 target is `p0()`, not the share, so a mint on the share would not fail that check. For Curve and the Balancer 5-leg helper the count-0 target is the share, and the only mint sites read are `exchangeIn` and `bundleIn`. No other mint was found. The connection to the 49% plan is therefore: a quote that used to fail the fit and refund the whole input can now return liquidity, and a caller that mints from that plan changes supply. The exact caller for the Curve and Balancer 5-leg supply change was not identified in the files read.

The dual and orbital `test_row_index1` bodies that were read do not contain the supplied `assertLe`. Those tests do reach the hook swap, and that swap calls SE `exchangeIn`, which uses `_size`. The comparison site itself was not found. No line is invented for it.

Smallest fix direction, with the 49 constant left in place:

- Do not edit `49` or `100`, and do not restore a search. The one-swap lock stays.
- After the existing 49% quote and `sizeOneSided`, if the remainder is a material fraction of the input rather than a rounding residue, take the path `_size` already uses for a zero-liquidity fit: clear the swap and the liquidity and refund the whole input. A 49% quote that does not fit must not mint.
- That direction restores rows whose failure is an unexpected partial mint. It does not by itself make the single-row `assertLt(refund, amount / 100)` true. A whole-input refund is also not less than 1% of the input, and the loop stops subtracting when the refund equals the amount. The single-row assertion and a scale-invariant non-residue remainder at a fixed 49% disagree. Closing that one assertion without changing the live fraction requires a fit, at that same 49% quote, whose remainder is actually dust for an amount the loop can reach. The supplied values do not show that fit. Changing the test bound, or changing 49, is not the fix direction.

## Limits

- Runtime or extraction proof: the failure list is coordinator-supplied. No test, build, or trace was run. Cause is from the source that was read, not from a replay.
- Not examined: the optional plan and PRD; the DETF package-arg helpers; the callee that evaluates the dual and orbital `assertLe`; any mint path outside `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`.
- The single-row residue assertion is not restored by the full-refund direction alone. That limit is stated above and is not a second proposed fraction.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
