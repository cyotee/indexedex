# Task 9 - Orbital component accounting implementation

## Status and source frontier

Source/test readiness handoff, not a runtime acceptance receipt. Task label: the 2026-11-06 FullSpread SE hook plan, task 9 (H4). Authority: current FullSpread PRD FS-OWN-34..37 and FS-HOOK-05..10; task-1 surface inventory, task-3 primitives, and task-5 shared red baseline.

Frontier: `orbital-task9-source-20261106-r1`.

SHA-256 of the manifest below: `6e4bdda86f55829d38649ca6a6f5150b121b9af1f8580c7bd0b90aaf02af1700`. The digest input is the sorted manifest's UTF-8 lines, each exactly `<file-sha256>  <repository-relative-path>\n`; the evidence note itself is excluded. There are 12 changed production/TestBase paths and 23 changed family test paths. This inventory is relative to the contents captured at task start, including pre-existing dirty contents, not relative to HEAD. No Git command, reset, commit, install, deployment, delegation, build, or test run was performed. Edits used apply_patch and are confined to the assigned family directories plus this note. Shared primitives, shared FullSpread fixtures/behaviors, HookLiquidityInvariantHandler, configs, FullSpread production, and VT tests were not edited.

## Implementation

- Repo appends booked SE-share quantities and the trusted deployment-registry address. Existing reserves now hold native local pair/raw quantities. Legacy growth-fee storage slots remain reserved. Ambient token/share custody is not treated as a pool component.
- Package initialization obtains registry authority from the existing immutable deployment registry, not caller-selected fee-oracle arguments. Bindings must have a registered package at that authority; failed/unknown authority queries cannot mean enabled. Effective address/package disable is queried through isDisabled. Cross-role duplicate physical tokens are rejected so a holding cannot back two coordinates. No package argument or migration was introduced.
- Ordinary, flexible, proportional, unbalanced and Permit2 entrypoints collect caller inventory, reconcile actual SE tuple receipts with before/after balances, compute one gross mint over all six native components, accept ceil requirements, and return excess pair/share assets to the payer. The forward sizing choice is not a promise of global conversion optimality. Pool books remain separate while the caller converts.
- Existing partial-book entry topology assembles missing coordinates by trading only offered caller assets through the existing sphere curve, then uses the post-trade component book. The mint is never based on sphere NAV. Single-input/zap paths likewise remeasure the actual terminal basket rather than minting the quoted LP unconditionally. Large owner-at-floor joins bound sales by remaining output inventory and refund excess through component acceptance.
- Bootstrap uses pre-owned SE shares on each funded SE leg, executes floor(A/20), rejects incomplete/zero receipts, and retains A-floor(A/20). The seed is the family's sum of normalized retained-share/raw quantities; the 1,000 floor is allocated once. Local redemption output adds backing, not extra rate-valued LP. The radius still serves the retained swap curve and is not an LP ownership denominator.
- The existing feeOracle feeTo()/usageFeeOfVault() source splits backed gross into net and fee LP. No growth-fee issuance/checkpoint path remains active; swaps and withdrawals do not mint protocol LP. Previews and minima use net issuance. Orbital's deliberate exact-net/exact-token LP-route rejection remains.
- Swap reserves are booked local plus rated booked shares. Output consumes local first; only deficits redeem SE shares. Local-only exact output never invokes unavailable underlying exchangeOut. Disabled incoming pool assets remain local, including existing local inventory across re-enable. Receipt refunds are credited exactly once.
- Withdrawals floor each native component against actual pre-burn supply. Pair exits redeem only allocated shares; share-requested exits convert only allocated local assets. Incomplete requested single-asset conversions fail atomically rather than dropping or gifting the residual. Cross-leg exits allocate the caller basket before trading against the remaining book. No cleanup redeposit or additional LP-allocation dust haircut remains.
- Installed split facets and the aggregate target inherit the same Common/DepositCore paths. Sequential views track local quantities and booked shares separately, use optional opaque transition state where advertised, and use ordinary widened preview tuples otherwise. Discovery now reports SE shares in requiredFirstBondTokens for SE-backed genesis legs; existing selector/facet cuts and package argument layout are unchanged. rawReserve documents local/raw native book quantities; seBalance excludes ambient shares. The SE exchangeIn facade now reports the original-input refund measured at the caller, and its preview has a matching refund-aware path. SY keeps its existing single-word return ABI.

### Load-bearing source locations

- Caller conversion receipt reconciliation: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:525`.
- Common native-component acceptance and fee split: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:959`.
- Rate-free seed and six-component gross limit: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:906`.
- Caller-only partial-book trades: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:857`.
- Local-first swap output: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:563`.
- Floor component withdrawal: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:1127`.
- Forward caller basket sizing: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:44`.
- Sequential component acceptance: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:374`.
- Facade refund preview: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:327`.

## Authored test coverage

The existing real FullSpread ComponentAccounting adapter retains the shared eighteen-case LP contract and the explicit exact-net rejection. It adds eighteen family cases for exact local equality, partial/all input refunds, both disabled share-exit axes followed by permitted pair exits, ordinary/flexible/unbalanced/Permit2 aliases, direct/shared/SE/SY single-input aliases, cross-leg exits, late ambient shares, deadlines, zero fee recipient, and outer-PoolManager rollback after positive local settlement.

Single-input aliases do not compare LP ownership against the pre-trade book. Their independent oracle reconstructs hook custody from ERC-20 Transfer receipts, subtracts the still-pending caller basket at each actual ZapSwap, and checks ceil backing against the last post-trade book. It also checks no LP issuance occurs before that point, gross/net/fee conservation, and actual input/refund receipts. Ordinary multi-leg joins retain the shared pre-intake ceil checks.

The new ComponentBoundaries suite adds eight cases using the real registered ERC4626 SE: nineteen-share rejection; twenty/twenty-one share bootstrap rounding; below-floor rollback; an initially empty SE leg becoming live and all-local while disabled; preowned-share joining that all-local book and re-enable; share-requested exit including allocated local input; protocol LP's ordinary withdrawal fraction; inactive fees; and integer fee dust/one-unit ceil acceptance (the all-local sequence shares one test body).

Family and decimal TestBase seed helpers acquire shares before entering the hook. Per-suite direct seeds and joinUnbalanced genesis inputs were migrated as well. Growth-fee tests now assert the backed gross/net split. Local-plus-rated and ambient-custody expectations replace superseded zero-local assumptions while funding, reentry, owner, rate-failure, and radius negatives remain. The family invariant suite bootstraps before constructing the existing shared handler; its handler implementation and assertions remain parent-owned and unchanged.

The FullSpread row no longer treats every exact-output call as unavailable: both false-flag and atomic pretransfer paths positively settle local-only output, while genuine underlying deficits still reject. Positive exact-input directions, disjoint backing pools, rate-target cases, refunds, and cold transaction gas tests remain.

## Verification and remaining gates

Final fresh LSP responses report No diagnostics found for all changed Solidity files, plus the aggregate Target. During validation, Solar identified the reserved identifier partial and an incorrect IFeeCollectorProxy import; both were corrected. Earlier Common freshness timeouts and dependent unresolved-symbol reports cleared after Common reparsed. Document-symbol lookup also timed out once; it is not a compile receipt.

No Forge/build/test/gas/size command was run, and no out/ or cache_forge/ writer was started by this task. No runtime pass, green gate, deployed surface, or gas ceiling is claimed. The parent owns serialized artifact building and execution.

Risks to check in that window:

1. Ordinary SE fallback cannot manufacture a post-operation opaque transition state. Sequential FullSpread zap/exit preview parity, actual terminal minimum checks, and dependent-rate behavior must be checked with the authored exact assertions, not inferred from static inspection. Actual execution always recomputes acceptance from receipts.
2. New native-unit dust/all-refund positives and owner-at-floor bounded sales need runtime receipts; they are not waived or converted into expected reverts.
3. EIP-170 facet/library sizes, cold whole-transaction and preview gas ceilings, and all legacy protocol/decimal rows remain unmeasured. Existing declaration/size/gas tests are retained.
4. Foreign-authority SEs are not silently accepted: this integration supports SEs registered at the hook package's deployment registry. Supporting a different authority needs an evidenced resolution, not a new arbitrary package field or fallback.
5. FullSpread share-requested output can fail if actual conversion returns unconsumed local input; it must not silently return an unrequested mixed basket. Disabled requested-share exits are separately tested, while permitted pair exits remain positive.

## Parent commands (not executed)

Run from /Users/cyotee/Projects/indexedex. The artifact helper builds concrete runtime dependents before testing and uses Solar. Keep out/ and cache_forge/ serialized; do not run these concurrently with another artifact writer.

```bash
sources=(
  contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol
  contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol
)

# Focus the new accounting, alias, refund, disable, and rounding cases first.
python3 scripts/forge-artifacts.py test "${sources[@]}" \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentBoundaries.t.sol \
  -- --isolate -vv

# Then run the complete owned family: installed surfaces, economics, negatives,
# protocol matrix, decimal variants, and the existing invariant campaign.
python3 scripts/forge-artifacts.py test "${sources[@]}" \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital \
  -- --isolate -vv
```

## Exact changed-source manifest

```text
f9e8cdfbcc9b60bcde8a566933d7b10c90f35ea18295d68e435412bb467777bf  contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol
05bb4754cdead30cb915e3166408768a9f72ea84e200699fddbc544c81e29978  contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol
4bdfd5d6e93853d0a0f1aa6f8df721bba33675bff211c039ae1a62c4362d16f6  contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol
0da24289b2287c256df8f5f8b020d132b3a09e3020ed7f07521c7b7a17db4c7b  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol
14ee29f642d4015945dc30d0944669ff89d79593c20f1dbd173b9853e7ecfec9  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol
3387b6c88a2d7a2491a8e393a0ecfa94766959267b1e1ddb16079eaf675baa9f  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol
a7cfeef450208980cd3aac482469d7bee1b97736d7e072835bec1783bb60c6fc  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget.sol
a81e511aa8f8eaffd3026dea191c7fe550b18071e26ee736a601b38fd8044057  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol
1b4853822d3023e270958636b0ff9a44e8da57dc192b8e14797e27501e9d6cff  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol
3b26c991982aca27d5fa70e4379c2a154b6426aa5ffdb61d1efdc4ad2a18957c  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol
7bf10c624f9f8555279104005052afd0589587c9a4d49c40279cc785078a329f  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol
43643f7ed5796e07c6cae22b851369c80d078714c6d00bc767af4f8e64670074  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol
a0c518d5ab8e03cfdce00ac663df066e8c9475c457fcd1d01fde0582a4094379  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/decimals/UniswapV4StandardExchangeOrbitalBufferHook_Decimals.sol
9aaa2cdd47980d1ace5355d90910f2c4caaef1fc3faa5dabb9fb60ee4af35fdf  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/invariant/UniswapV4StandardExchangeOrbitalBufferHook_Invariant.t.sol
b2e75fd402c064fdf846c362526f46aa65a7fe01e9211661d330452ab48f10cc  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Adversarial.t.sol
66f987d79a890c60c26d3218e376609d435e17ac698e9224bf4155ba184f65dd  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_APEX_D41.t.sol
ab06e9268c5f1b5c22c6ffa2527ef3bdfc348d1a04fa9fa28a62f1536b0f796e  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol
f2c6fbaceee012064747a7391a50d36a8c54c8057f1bcc88ebeacac41282a0c2  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_B6.t.sol
1aa242f9abd8481713756e82c4cf8ea908175a113b4047eaf6af141d2eac291e  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Buffer.t.sol
d9693f0b99bfb6fb08604dab138b4223abe5f3b26f77b4560765e7552d61d7f1  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting.t.sol
8a977a04b61ffc1d3f9d57ddc2af333d87eb704a5684dbf9a2ed939592a0b422  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentBoundaries.t.sol
3e233262c645b42fd6fb49041daf6795b2b6fd7018ad46e2e519c70a4088444c  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Fees.t.sol
0f1579b147b78316af2e583649b32e946212c7fd5a318e043bee4fc2d406a252  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FundingRecurrence.t.sol
8e6dedb6ca3e63fdb5704af96d6b0c47377526bfd0fad20461268c9345f8fd0f  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_LedgerReconcile.t.sol
640e383bb8ff3ad34d599931389d017ae672aaea7359323e5d11dc771f0b9f7c  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Liquidity.t.sol
e21eeef393a12261d4c9a81604ec59d3dc77eb96f8a4878ebd085c3681aef654  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_OwnerDuringLock.t.sol
7ac4586b5e80db1947410e72c1e0513c066a35116a4ae7901fcde9b9c0d08a80  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_OwnerOnlyLiquidity.t.sol
ccb6bc6f00795ae0d75c67e28193c5e09dbcd89fb30c6255b4402a87e4988d5f  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_RatedReserve.t.sol
bbd04dc96b9d938723c94f1e1213cc4b37126344235c0e6320adfccc0b3d92d3  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_RateProvider.t.sol
7d157904a46dd2f6d7ddc397e5fb4bd9e82257ea39f3ced379bec341935e4a41  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityPolicy.t.sol
65c41b63a4d2b494afdfa90d891e62dd2e8c7d41394470f2b7ae855a7899787b  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol
f13a5bd7d806ae36dec2da78c86acdf7bd82ebe89e74ff8843d50c78e626c3e5  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeLifecycle.t.sol
2949fdaffd78747bd2a587316885bb89f318184368449664399bc263825dd9f5  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_ERC4626StandardExchange.t.sol
682fdce25a182aaa47903d64b56e9bd0c8f4b3fa43ebafec00df7d61cf78a147  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol
57be5c0041aa869ed83a6f7b304ecd9fb4a17d3e912edebccae19fbb09eba06f  test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol
```

Sources are frozen at this handoff pending a coordinated parent validation failure. This note does not close task 13 or later cross-family/evidence/gas gates and does not authorize deployment.
