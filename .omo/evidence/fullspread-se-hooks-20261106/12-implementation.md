# Task 12 - Balancer stable component accounting

Date: 2026-11-06 (session date). Frozen source frontier: task12-h7-20261107T000227Z. UTC capture: 2026-11-07T00:02:27.923Z.

## Status and receipts

Family implementation and test sources are ready for parent-owned serialized validation. This is not a runtime pass or release approval. No build, Forge test, package-size check or gas run was executed; no command wrote out/ or cache_forge/.

LSP returned "No diagnostics found" at severity all for all 26 changed Solidity files. The component and fee test files were checked again after their final scenario additions, also without diagnostics. The final read-only shasum -a 256 command exited 0 with empty stderr. LSP and fingerprints are static/source receipts, not compiler or runtime receipts.

Only the assigned production/test directories and this note were edited, using apply_patch. The session captured the initial contents of 101 family Solidity files before edits and compared the final frontier to that baseline. Pre-existing family membership fixes and fixture changes were retained. No Git operation, commit, install, deployment, shared arithmetic/tuple edit, cross-family fixture/behavior edit, FullSpread vault/VT edit, or config edit was performed. HookLiquidityInvariantHandler was read, not edited. Its owned family fixture now seeds through the real share-funded bootstrap before constructing the unchanged handler.

Authority: docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md task 12; the FullSpread PRD FS-OWN-34 through FS-OWN-37 and FS-HOOK-05 through FS-HOOK-10; evidence 01, 03 and 05; the parent's in-session clarification of the single-input snapshot boundary below.

## Implemented accounting and route coverage

- Appended booked SE shares and trusted registry provenance. Existing rawReserves holds booked raw/local pair tokens. Former fee-only fields remain reserved, not spendable custody; storage positions are preserved.
- Native full-width component limits, ceil contributions and floor burns use the fixed shared arithmetic. Caller conversion receipts stay outside incumbent books until acceptance. Unaccepted share/local/raw components return to the payer. Zero mint cannot retain caller funds.
- Genesis accepts pre-acquired shares on each funded SE leg, actually redeems the rounded 5%, reconciles exact input/output deltas, requires complete redemption and positive pair output, and uses retained native inventory in the existing StableMath D/n seed. Existing inventory normalization remains fixed. The locked floor is allocated once, before the fee split.
- Existing usageFeeOfVault/feeTo configuration and activation feed the backed gross/net split. Growth issuance, fee-only checkpoints and projected growth supply were removed. Events report the new mint's actual fee portion; withdrawals/swaps do not mint protocol LP.
- Swap reserves include local pair plus rated booked shares. Output uses local first, including exact local equality without calling FullSpread exchangeOut. Unsupported exact-output SE deficits still reject. Pool-owned SE refunds are credited locally once; disabled input remains wholly local without a prohibited mint.
- Effective disable comes from the package's immutable deployment registry, including package disablement. Unknown registry entries fail closed. Foreign-registry SE bindings are an explicit integration limitation; no arbitrary fee-oracle fallback or package field was added.
- Standard, units and flexible proportional paths share native component acceptance/allocation. Installed Query, Exit, SE, SY and liquidity aliases retain selectors and guards. SE facade tuples report actual input refunds. Requested share exits retain allocated shares and convert only the caller's allocated local/cross-leg proceeds; incomplete conversion cannot silently pay an unrequested mixed basket.
- Single/sparse-unbalanced routes use caller-funded StableMath trades before component acceptance. Incoming trade input is booked locally; only the traded output is removed from incumbents. The mint snapshot is the post-trade book, per the parent clarification. Exact-net execution caps accepted gross using grossForNet and actual receipts; all surplus components return to the payer.
- Exact-output previews forward-check a StableMath estimate using bounded ratio refinement, not an SE exchangeOut dependency for LP gross-up. Runtime checks must verify the sizing domain and bounds. A quote never funds a mint: actual component receipts do.
- No new linked library, public selector or PkgArgs field was introduced. Existing ClaimLib linkage is reused. The DFPkg initializes registry awareness and rejects overlapping physical share/pair roles. Existing cuts, staged finalization and FactoryService artifact loading remain intact.

## Parent clarification and independent alias oracle

Parent correction dated 2026-11-07: the interpretation in this section was
an agent implementation choice, not an owner decision. The owner question
timed out unanswered. Paid internal swaps followed by post-trade LP
acceptance remain unapproved and cannot be signed off merely because the
matching tests pass.

The original shared exact-net test compared final components against the pre-trade book. The parent clarified in this session that this conflates trade/conversion PnL with LP acceptance, and will remove that specific comparison while retaining exact gross/net/fee, caller maximum and actual receipt assertions. Ordinary pair/share multi-leg joins retain their independent ceil-component checks. This resolves the previously reported boundary; no shared test was edited by this family task.

The family component adapter independently reconstructs the post-trade book in _postConversionBook. It reads actual token custody and configured rates, uses the pinned StableMath reference for the raw source's sequential local-only trades, and asserts that each traded output fits the actual local inventory. It does not use a SUT join preview or component helper as its backing oracle.

_assertPostConversionBacking then measures actual accepted pair/share deltas and checks exact ceil(gross * postTradeComponent / oldSupply) and the direct integer no-dilution inequality against that post-conversion book. The same assertions run through depositSingle, Standard Exchange exchangeIn, Native SY deposit, and exact-net joinSingleAssetExactOut on both two- and five-leg real FullSpread fixtures. The exact-net branch separately checks exact net output, actual input debit and maximum.

## Authored regression coverage

The real FullSpread component adapter now also runs with five legs. Thirteen added family tests cover:

- Real partial and all-input SE swap refunds, and fully retained disabled input.
- Outer-manager rollback after an actual positive installed join.
- Exact local-output equality, unavailable deficit separation, and a subsequent share join with zero local contribution requirement.
- Enabled share-requested exit; disabled share-exit rollback plus permitted pair exit.
- Standard/SE/SY/exact-net alias fee conservation and independent post-conversion backing.
- Real Permit2 allowance funding.
- Zero-rounded genesis, deadline rollback and a positive recovery call.
- Existing inactive fee activation, zero-recipient fee deactivation, and duplicate-leg rejection.

The fee suite adds a real ERC4626 SE zero-refund swap check. Existing canonical, decimal, matrix and invariant seed helpers acquire shares before bootstrap. Existing fee, ambient donation, local payout, rated-view and n=2..5 tests were updated only where their setup or numerical expectations were superseded. FullSpread exact-output tests execute funded local-only positives and retain the unavailable-deficit negative. Decimal small-input positives use sufficient native units for all ceil components instead of changing successful routes into revert expectations. Independent access, allowance, reentry, FoT and unsupported-route negatives remain.

No discovered/executed test count is claimed. The shared all-zero/all-local arithmetic cases remain part of the shared component suite; these production fixtures do not fabricate an impossible book by storage injection. Runtime coverage, including exact rounding and all-refund positive execution, is a parent gate rather than inferred from source occurrence.

## Validation risks and integration limits

1. No Solidity build, artifact linkage, EIP-170 size, gas ceiling or runtime test receipt exists for this frontier. LSP is not a compiler receipt. Rebuild all affected concrete facets before deploying tests from out/.
2. FullSpread has no transition-quote interface. Sequential conversions can change the SE state used by later estimates. Execution is receipt-driven and minima remain atomic; composed preview parity and exact-net requests at the maximum budget must be demonstrated by the targeted run.
3. Share-only exits reject an incomplete local-to-share conversion rather than dropping the local claim or returning a silent mixed basket. The new FullSpread positive must reach full consumption; do not hide a failure by converting it to an expected revert.
4. Exact-output preview refinement is forward-verified, but feasible sizing across the full supported input domain and original caller maxima needs runtime evidence. No optimal-conversion claim is made.
5. Effective disable is supported only for SE entries known to the package's deployment registry. Unknown/foreign registry bindings fail closed instead of being treated as enabled.
6. The unchanged shared invariant handler has historical fee/valuation assumptions. The owned fixture now gives it valid genesis; task 16 remains the owner of any handler-law migration.
7. The parent owns the announced shared exact-net assertion correction. Until that change lands, its pre-trade component assertion is expected to reject legitimate trade composition; this task did not weaken or bypass it.

## All changed production-directory paths

- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookInQuoteBase.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookSeTarget.sol
- contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol

## All changed test paths

- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Adversarial.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Fees.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Liquidity.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_MultiAssetLiq.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Scale.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_TokenCount.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_VaultViews.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control_F6.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control_F9.t.sol
- test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/invariant/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Invariant.t.sol

## Parent-owned targeted commands

Run against this frozen frontier. Serialize both source selection and artifact writers. Every changed production-directory source, including both TestBases, is included below.

```bash
sources=(
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookInQuoteBase.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookSeTarget.sol
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol
)
python3 scripts/forge-artifacts.py test "${sources[@]}" \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol \
  -- --isolate --match-test 'test_(HB|component_)' -vv

python3 scripts/forge-artifacts.py test "${sources[@]}" \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer \
  -- --isolate -vv
```

The artifact helper supplies Solar and builds affected runtime artifacts before tests. Capture complete output in 12-balancer.log / 12-balancer-negative.log with actual command, frontier, exit code and discovered/executed test counts. Neither log is claimed to have been produced by this task.

## Raw-file SHA-256 frontier

```text
6a036bb931fd6fc53f0c3e8c62ef701689427c03c7e21b5662cd2b398e762731  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol
baf61e63df2e2284a237b57dca426fc2ce2955257eb0266d922efce521d363e0  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals.sol
bcae52f1a79fdc3eac74e4677e4e4781cae5ec86cc6f225dd8f282cf2d1e17f8  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol
415bc5005a92c8f1906acf175131026da7ce7fcae0f92ce311da10e4380e8705  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol
7ad4c91462f6ac74fa3b26843d17e7cc7be079e4e66e5ca7356bf4f3d25424f0  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol
6b3eccabb68dcb0f425696b7eb890ec1cf90ad81315aba676b430dbf3512f1a0  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookHooksTarget.sol
cd7a2dff11c55a45730911dd46400e05af5a2adbfe124fd1bea6ff49998dad73  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookInQuoteBase.sol
5424df91445d06561d01814670e478cf3604fe732819fdc9684a71f2008facd4  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol
2a0415ea3f28adec48fbf62cff35dc6d6dca08a95de35b9f8c095d1cf110547e  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget.sol
5245fa75b9b14c6eafb1bcf915d3d0894a60931d74d4fa28732583868cf18098  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol
fd47ed0f106c551a1776746a363e2382504270e1deee7b9dfcbb38585762734a  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookSeTarget.sol
bc1e1519fab1777e94a86822ff7f042fef65d64ceda5815e12d727421610f17f  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol
efbbecacc8e585da6be70153b0bcf503977bce2996814b3874e1e240cbddba82  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Adversarial.t.sol
d3054e6e80cf063504023e981e56accbcbc14430123583d4051254d47824346f  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol
2775e716c33537202f7fe4c19efea3ea92d87c7b253dda92041fba4f4dca91ec  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Fees.t.sol
9b58c98246b059591efaeb62d97b455a68e9431c171289531cf10902c7e3efaf  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Liquidity.t.sol
639d80c436662b5209dc63634abd2f355b4610c6ae26ec06669543aa8e85293b  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_MultiAssetLiq.t.sol
2189012c232c8ed6e2902dc1cd22974c2facae2b4c86272d1f91dea4ebf345ea  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Scale.t.sol
d6e5dc8f6146b2d38ec3cab70f1e9492820904b503016542340d7ce182a9d88d  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol
92421b567ff56d054e26757c09e44eaefbe22832a790dbf8a7f5c9cdb65e359e  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
7449919be8c948e3b430ce8866882d1a06c7c20b0302e1e5b73cf2c5ceee9b9a  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_TokenCount.t.sol
021b285ce144ee176d8030d0995e3945f267558b0d403adab4a0dc6a953f2ef6  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_VaultViews.t.sol
62a2bb63878e05502dbd36be797ef279559e21459d36b234d8427662156c6af0  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals.sol
a024c61f354143c73c3b36ee6178b9481b94b0dd4a31c33885859f681b6f4ed8  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control_F6.t.sol
2b12adda24bf0452027bdf2b02a59bc45b384dc686587f9a36da748d5930b733  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control_F9.t.sol
b0013364564627a981e9142f45e4e0223cfa102ea422a13254d488f187171fc8  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/invariant/UniswapV4StandardExchangeBalancerQuadStableBufferHook_Invariant.t.sol
```

