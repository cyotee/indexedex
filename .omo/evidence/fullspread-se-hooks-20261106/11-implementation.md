# Task 11 - Curve quad implementation and test-source handoff

Task date: 2026-11-06. Status: implementation and test sources ready for parent-owned serialized validation.

## Readiness and receipts

All assigned family routes now use the component model, including installed and aggregate paths, proportional and flexible entry/exit, sparse and single-input entry, supported exact-net LP entry, SE/SY facades, projected views, and bootstrap. No source-implementation blocker remains from this task.

All 29 changed Solidity files returned `No diagnostics found` from LSP. Changed files were checked again after the final edits. One earlier symbol request timed out and another reported `analysis inputs changed since request`; direct source/caller inspection supplied that inventory. LSP is not a compiler, bytecode-size, linkage, gas, or runtime receipt.

No build or test ran here. No writer to `out/` or `cache_forge/`, install, commit, Git operation, live deployment, or delegation was started. No runtime pass is claimed. Only the assigned production/test directories and this evidence note were edited; shared helpers, shared fixtures/behaviors outside this family, HookLiquidityInvariantHandler, configuration, FullSpread production code, and VT tests were not edited by this task.

## Provisional single-input interpretation - owner decision pending

Parent correction dated 2026-11-07: the interpretation below was an agent
implementation choice, not an owner decision. The owner question timed out
without an answer. Paid internal swaps followed by post-trade LP acceptance
remain unapproved; passing tests cannot settle that requirement. This family
cannot be signed off on that basis.

The current-session correction separates actual conversion/trade PnL from LP acceptance. A single-input join first trades a caller-owned basket against the existing four-leg pool, then accepts native components against the **post-trade** book. Comparing this path to the pre-trade book would incorrectly prohibit the actual trade. The parent's shared exact-net test now retains exact gross/net/fee and input bounds without that pre-trade comparison; its updated comment was read, not edited here.

The family implements actual component-basket trades using its existing Curve StableSwap amplification and trading fee. These internal trades exchange SE-share/local/raw inventory; they are not pair-token payouts and do not pretend an SE share is pegged to its pair. Ordinary token-output swaps still use local-first payout. Pricing rates are pinned before this caller's SE conversion so the preview and execution price the same trade; actual SE receipts determine the quantities available to trade.

Ordinary proportional pair/share joins and full multi-leg baskets do not use this trade adjustment: they retain the pre-intake ceil-component contract. After either path has assembled its basket, one gross mint is limited by every positive native component, acceptance uses ceil, and unused native assets return to the caller. The alternative of keeping invariant-growth LP issuance, pulling unrequested other tokens, or changing positives into expected reverts was not adopted.

## Implemented paths

- Separate booked SE shares and local/raw pairs; ambient custody is excluded. Pretransfer credit subtracts every booked role of an address. Caller-owned conversion inventory stays separate until acceptance.
- Trusted effective disable resolution from the immutable deployment registry via VaultRegistryAwareRepo. Unknown registrations fail closed; there is no new package field or fee-oracle authority fallback.
- Exact-input SE results preserve output/refund words and reconcile both against operation-local balances. Pool refunds are local backing; incoming-caller refunds remain caller property until accepted.
- Share-only genesis on funded SE legs: redeem floor(A/20), require full share consumption and positive actual pair receipt, retain the remaining shares, and apply the existing four-coordinate geometric seed to normalized retained shares/raw units. The existing locked floor is subtracted once.
- Configured usage-fee WAD splits newly backed gross LP into depositor and protocol LP. No mint on top, growth mint, withdrawal mint, fee-only checkpoint, or projected growth supply remains in executable family paths. The compatibility kLast view stays zero.
- Single-input, flexible, SE, SY, Permit2 and sparse-unbalanced joins now use the same actual trade/acceptance path. The aggregate target inherits the installed targets rather than maintaining duplicate economics.
- Exact-net LP execution uses the shared minimal gross-up and forward-feasible family basket sizing bounded by the caller's maximum. The feasible upper candidate is retained while narrowing; global monotonicity of an SE or globally optimal input is not assumed. It never invokes an SE exchangeOut to mint FullSpread shares. Actual accepted gross is capped to the requested fee-grossed quantity, and actual minted net is checked again after refunds/minting.
- SE exact-input LP facades return the actual input-token refund; their previews report the same refund. Native SY uses the same execution and quote paths.
- Swaps price local plus rated booked shares, consume local output first, redeem only the remaining budget, and book disabled input locally. Local-only exact output avoids an unavailable SE inverse; a real unsupported deficit still rejects.
- Proportional exits floor-allocate every component independently. Pair payouts redeem only the holder's share allocation and include that holder's local allocation. Requested-share payouts convert only the allocated local claim and reject atomically when that requested conversion cannot complete.
- Cross-leg exits allocate first and trade the exiting inventory against the remaining book. The requested final edge is converted only afterward. Exact-token adapters settle the requested output; integer trade-budget surplus remains booked locally, without another LP fee.
- Projected external-deposit/join views use the advertised transition state, projected rate, caller-owned shares and the same trade/acceptance calculation. Projected reserve/bond views include local inventory and actual supply.
- Family seed helpers now acquire shares before hook genesis. Superseded genesis, growth-fee, ambient-donation, and zero-local-residual assertions were updated; independent funding, owner, reentry, unsupported-route, and rollback checks remain.

## Independent test sources

The concrete ComponentAccounting adapter now adds **42 H6-specific test functions** to the inherited real-FullSpread behavior. This is a static source count, not a discovery/execution count. B6Firm adds two further cases for all sixteen fixed-four output masks and an explicit zero-refund swap.

The alias oracle reconstructs the post-trade book and caller basket from native `JoinComponentTrade` movements, actual token balances, and actual funding Transfer logs. It does not call the SUT LP preview as the expected component formula. It checks independent ceil contributions, common-mint maximality where applicable, per-component non-dilution at acceptance, every unused asset refund, no extra caller intake, exact gross/net/fee, and actual input bounds. Raw, pair-funded SE, preowned-share, flexible, ordered/address-listed sparse, Permit2, SE, SY, and supported exact-net aliases reach positive calls in the authored tests.

Other authored cases cover real zero/partial/all refunds, exact local equality, local deficit, zero-local subsequent joins, address/package disablement, disabled preowned-share bootstrap and joins, disabled raw-input trades without minting SE shares, re-enable ownership, requested-share failure plus positive pair exit, dust and minimum rollback, deadlines, booked-local pretransfer rejection, zero recipient, resolved zero fee, sub-legacy fee precision, protocol LP withdrawal, infeasible 100% exact-net fee, exact-token exits, and four independently deployed FullSpread SE legs.

The all-refund positive uses a controlled external raw-token rate provider and a real imbalanced four-leg book so a one-wei fully refunded FullSpread input can still buy positive raw output. Neither the hook nor either SE is mocked. Existing family negative and outer-manager suites remain part of the required parent run; no test execution is inferred from their presence.

## All changed production paths

- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookExitExecutionBase.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookSeTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol`

## Parent validation commands

These commands have not been run. Include every changed production root so the artifact helper rebuilds the linked library/facet closure before FactoryServices deploy it.

```bash
family=contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve
tests=test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve
prefix=UniswapV4StandardExchangeCurveQuadStableBufferHook
sources=(
  "$family/TestBase_$prefix.sol"
  "$family/TestBase_${prefix}_Decimals.sol"
  "$family/${prefix}ClaimLib.sol"
  "$family/${prefix}DFPkg.sol"
  "$family/${prefix}ExitExecutionBase.sol"
  "$family/${prefix}ExitQuoteBase.sol"
  "$family/${prefix}ExitTarget.sol"
  "$family/${prefix}HooksTarget.sol"
  "$family/${prefix}JoinCore.sol"
  "$family/${prefix}JoinQueryTarget.sol"
  "$family/${prefix}LiquidityTarget.sol"
  "$family/${prefix}Repo.sol"
  "$family/${prefix}SeTarget.sol"
  "$family/${prefix}Target.sol"
  "$family/interfaces/I$prefix.sol"
)
python3 scripts/forge-artifacts.py test "${sources[@]}" \
  --test-root "$tests/${prefix}_ComponentAccounting.t.sol" \
  --test-root "$tests/${prefix}_B6Firm.t.sol" \
  --test-root "$tests/${prefix}_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol" \
  --test-root "$tests/${prefix}_Fees.t.sol" \
  -- --isolate -vv

python3 scripts/forge-artifacts.py test "${sources[@]}" \
  --test-root "$tests" -- --isolate -vv
```

The helper supplies Solar and artifact-before-test ordering. Record actual command, source identity, discovered/executed counts, exit code, and failure traces in `11-curve.log` and `11-curve-negative.log`; neither log is asserted to exist.

## Risks and validation limits

- Parent compilation must check linked-library and facet EIP-170 size. ClaimLib gained family basket logic, while the duplicated/legacy JoinCore and aggregate issuance paths were removed. No current bytecode-size or linking receipt exists.
- The family exact-net forward-sizing path and extreme-imbalance math need gas/runtime validation. It promises a forward-feasible input within the supplied maximum, not a globally optimal conversion split.
- Requested-share output is unavailable when the real SE cannot fully convert the allocated local claim without an input refund. The implementation rejects rather than discarding the claim, making a prohibited disabled mint, or paying an unrequested mixed basket.
- A foreign SE not registered under the deployment authority fails closed. Supporting a different registry requires separate evidenced provenance, not an arbitrary fallback.
- Shared arithmetic receipt tests cover malformed/incomplete dependency receipts; real family bootstrap/minimum/dust cases exercise atomic rollback. These source checks are not a claim that every dependency can naturally produce every malformed receipt.
- This frontier covers this task's 29 changed Solidity files. The parent must also freeze its shared dependency closure, run the whole family (including existing invariants/negative/decimal/owner suites), and reconcile the broader plan ledger. No old failure has been relabeled as a runtime pass here.

## Stable source frontier

The final read-only `shasum -a 256` command completed with exit code 0. No source edits will follow this handoff unless the parent returns a concrete validation failure or changes the instruction. The full changed-source list is:

```text
380f53b79032e643d3d9b35ff51134981cecc1c49d67c8df23e6eb5a0ee9924c  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol
422a64942ff0d408c145b90f778d429f6981cec09635a803fa72e6b335ac6809  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals.sol
f51da44b5167f37c427f26a5777940a0e7ee3c02e8b681038eab519f4fa38af7  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol
69cd68f2f44ebe2b7d174af02e1f8d8fc65a177dc74b61f7298bf35f8fbf24c8  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol
d211467c393aa205747d21c8535ae886452c30cf07b2b7ea7caf5ce259bc72cc  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookExitExecutionBase.sol
77de76ec84ebed971fa82269a871e50251cff1c552dea73a0be1cfbf77cc07d9  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase.sol
9ad62606de5f5a1ed37f0146b178926d43addcfeaa58f36737bc668d6e0f647d  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget.sol
ff2960124d7408c6d237ae3392faf9d99fc1d285f18fe453cbbdffec93efcc61  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget.sol
8a3036b53a840e9bb42fee24ba0399b59712c96da1ddc8ad775bde9488e9b88d  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol
0e637854aac0e250c7b0fe4fec005cdcb2669af44e31c5ab6927b3657f52253d  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget.sol
992dca7e7a138b75be3cb48df395927636a8f3e7f9f9698b6c95a8a8d02b1742  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget.sol
3108f476321ba2fda2bcb30ab72abeebd12f64fa0740fff66a344db7b197d67a  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol
f8707d4c3ca56945e841c8eedc05b30ccaabfe7d868f55b063f0ff04205b8bf2  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookSeTarget.sol
2aafcfc03040dee78b46f64d54a7598088abe428b59a7e953394eb1675f16fed  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol
3d488a52e52e8229adb29caffebcad996e6431ac6d578ac91648d22d5c7981a4  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol
25683e9af90f35a30d73c2fab9d6d5144b0347f9c3ea0fbd16b360e6da54474d  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_Adversarial.t.sol
087e1fed32d463f14e46277b38c54f189f11882ea8c7ee132a8e0b51c832379f  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_B6Firm.t.sol
0258cd8fdf3528bfe3f70744c1f4d38f12613e23a8b94ae43db50b33c71d02b1  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_ComponentAccounting.t.sol
7ca87dc6369e4a1e21f596d2670b24b174c1544bcf586d08e303a6de963df059  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_Fees.t.sol
f05af7497270e4d4141e1b71d3c648633e83ce906196961cd327eebd7b4d099c  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FundingRecurrence.t.sol
31de26c9a1abf8e0c3c4713833adcbd06d6143ec45a8e9e15007336a0c96ddd7  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_Liquidity.t.sol
ab87d3b5be5e1b876942a96d07ed60f735484dd723e3f22830d75ad66ff4906c  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_MultiAssetLiq.t.sol
d49000368e42cef9a6db8a98a86730a5489733c737c9a6b5e4db8210d61759da  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_OwnerDuringLock.t.sol
f7b5ae292b3d235bceb4ada518f4ed2cfd422e8bc1a12af1e9cc50810debab23  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_OwnerOnlyLiquidity.t.sol
30b322b5e10ce50739aa853a90d4db2424d53e00a898ffd0a99947408790e055  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_Scale.t.sol
de01b674122e2d27288e73d053ac6b0dc7a018953f8f975babc52c5bfd53c44f  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeBufferAbi.t.sol
ac792629fa8e5c246d0c9059f2c7d726f5f6facf8dbe31358118cfa60d812dd5  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol
e52e780fbaa7d7f608e04e652e11385798e8c25e57dda00f16109294717ac7fe  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
2c210bd74e0aaa49fbf60a4a89242ef96bb78d8c0f4f154e1b54340cf023f500  test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/decimals/UniswapV4StandardExchangeCurveQuadStableBufferHook_Decimals.sol
```
