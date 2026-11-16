# Stage-one execution evidence

Status: **owner-approved bounded-execution revision implemented and verified**.
Date: 2026-10-29. No project commit or broadcast was made.

## Result and authority

The owner approved applying the proposed gas-feasibility revision after the
original A70 failure. The adjacent amended PRD controls the current domain:
`6f4cad4f648189da10d0c47db3a3d0cfbc01462bef6ecbe81d2ca97b25a9d1b3`.
The implementation plan pins that exact hash and retains all 70 acceptance IDs.
S1-P07 and S1-GAS-01 record the approved operational change. The original council
PRD hash `574ce6c03c0bc62f79a816e5a7775c831cb932082e0dd4bfe414fc1945ed7a7f`
and its frozen research snapshot remain historical and unmodified.

- Default artifact-first regression: **27,050 passed, zero failed/skipped,
  2,592 suites**, 416.72 seconds (8,030.82 CPU seconds), exit 0.
- Dedicated revised-budget matrix: **15 passed**, zero failed/skipped, exit 0.
  Full family inventory: **237 runner cases across 17 suites**, included in the
  default regression. The preceding full-family run with eleven budget cases
  passed 233; the four added mirrored/paired cases passed in the 15-case run
  and final default gate.
- Final annotation artifact/deployment check: **12 passed**, exit 0.
  All 14 shipped executable runtime bodies are byte-identical before/after the
  final selector-comment edits, excluding compiler metadata. Budget-test tag
  additions also leave executable source unchanged. No redundant full rerun
  was used for those final comment-only changes.
- Canonical verifier: exit 0, gas **22,117,435**. It checks the real product
  interfaces, two added work errors, linked entry points, and all 15 new budget
  test selectors. Central values and source tags agree.
- Independent arithmetic oracle: **123 vectors**, seed 20261028, previously
  verified exit 0; arithmetic inputs/implementation are unchanged by this revision.
- Fuzz/invariant configuration remains runs=16, invariant runs=16/depth=8.
  The grouped ownership invariants and deterministic sequences pass unchanged.
- All normal runtime/initcode limits pass. Solc 0.8.35, optimizer runs=1 and
  via_ir=false remain unchanged. The large Foundry gas allowance is never used
  as the product budget.

## Revised operational contract

| Metric | Per candidate | Two attempted withdrawal candidates | Exact rejection |
| --- | ---: | ---: | --- |
| Canonical swap-loop iterations | 64 | 128 | `QuoteWorkExceeded(65,64)` |
| Actual initialized-tick crossings | 12 | 24 | `QuoteTickCrossingsExceeded(13,12)` |
| Distinct bitmap keys, including boundary words | 16 | 32 | `QuoteBitmapWordsExceeded(17,16)` |

Repeated crossings count again even for a cached tick; repeated reads of a
bitmap key do not. All swaps in one candidate share counters. Iteration admission
precedes each loop; new-word admission occurs before its manager read; initialized
crossing admission occurs before fetching/updating that tick's overlay. Equality
is allowed. A candidate needs no more than fourteen tick records and sixteen
bitmap records. The iteration backstop has an independent memory-counter control;
other metrics can necessarily reject first in a real whole-operation candidate.

Normal maintenance remains first. A typed work failure anywhere in the complete
normal withdrawal admits one fresh collection-only candidate with fresh counters.
Paired fallback has no swaps and remains affordable under excessive swap
complexity. Single-token fallback must itself fit, or preflight rejects before
manager execution, pulls or burns. Its requested output never silently becomes
a pair. Deposits and standalone compound do not acquire withdrawal fallback.
Actual token, wrapper, manager, custody, receipt and payout errors still revert;
no execution exception is caught to retry another mode.

No ownership, supply, fee, rounding, donation, native-representation or SY-value
equation changed. No asynchronous claim, cancellation mechanism, keeper or new
caller bypass flag was added. The product still owns exactly 60 selectors,
with six persistent factory selectors supplied separately. Error additions do
not change ERC-165 IDs. Shared runtime contracts, baseline and Wings are unchanged.

The prior 512-step dense-sale domain is now deliberately unsupported. Its raw
manager fixture remains as historical evidence, while the revised product test
requires an early exact work rejection and a valid paired escape. Partial-fill
and no-liquidity controls retain their economic assertions on real coarse-spacing
pools that reach the same endpoints within the new word budget; no failing
assertion was deleted or changed to accept a partial successful exit.

## Gas acceptance and observations

The shared transaction engineering ceiling is **12,000,000 gas**. Cold call-body
tests enforce **11,900,000**, reserving 100,000 for intrinsic/fixed-calldata costs.
The local preview ceiling is **5,000,000**. These are deterministic admission and
engineering tests, not gasleft-dependent product policy. All observed boundary
cases use real registered proxies, real manager positions, supported reference
tokens and normal receiver behavior. Unbounded external token/receiver programs
are not promised a fixed cost, and no token allowlist was introduced.

| Boundary case | Measured execution gas |
| --- | ---: |
| Six-action token0 entry, both LP fee currencies and protocol fees | 10,696,688 |
| Mirrored six-action token1 entry | 10,688,606 |
| Native maximum entry | 10,033,903 |
| Opposite-leg maximum entry into a native pool | 10,393,948 |
| Wrapped-native maximum entry | 10,470,219 |
| Maximum normal-maintenance paired / terminal exit | 7,799,346 / 7,789,109 |
| Native maximum normal-maintenance paired / terminal exit | 7,499,704 / 7,489,468 |
| Final-sale work exhaustion followed by valid single fallback | 6,030,224 |
| Maximum-crossing single fallback with both fee currencies | 5,499,838 |
| Dense-pool disabled paired escape | 2,337,387 |
| Empty-word exhaustion followed by paired escape | 2,208,719 |

The largest listed entry plus the 100k transaction reserve is 10,796,688 gas,
below 12M. The maximum-entry fixtures assert six actions, twelve crossings,
fourteen distinct ticks and sixteen bitmap keys, in both directions and native
representations. The listed maximum-entry previews range from 2,119,641 to
2,127,403 gas. Mode/paired/rejected-call previews also assert the 5M ceiling;
rejected executions assert the 11.9M call-body ceiling with complete rollback.

The first 32-crossing proposal failed at 17,707,987 gas. Sixteen crossings still
needed 12,068,395, above 11.9M. The documented crossing bound was tightened to
twelve; no gas assertion, compiler setting or configured test depth was relaxed.
Demand-grown caches and prefix-indexed immutable phase captures remain in place.

### Network and provider limits

Targets are the owner's named Ethereum, Base and Robinhood. The documented
Ethereum/Base ordinary transaction cap is 16,777,216; Robinhood's gas precompile
returned 32,000,000 at block 100,471,997 on 2026-10-28. The revised 12M engineering
ceiling is below both observed protocol ceilings. No deployment was performed.

**Unverified integration item:** no production RPC provider was named. The 5M
local read ceiling is proven by tests; provider eth_call allowance, timeout,
rate limits and service availability are not claimed verified. S1-GAS-01 requires
this disclosure rather than inventing a provider cap. Mainnet deployment/provider
integration and existing-instance migration remain outside this execution.

Primary references used for the envelope:

```text
https://eips.ethereum.org/EIPS/eip-7825
https://docs.base.org/upgrades/azul/exec-engine
https://docs.robinhood.com/chain/connecting/
https://github.com/OffchainLabs/nitro-precompile-interfaces/blob/main/ArbGasInfo.sol
https://eips.ethereum.org/EIPS/eip-2200
```

### Historical reason for changing the domain

The original dense candidate needed 164,316,119 execution gas even after
representation optimizations. A genuine 510-tick sale with nonzero global fees
in both currencies required 1,020 zero-to-nonzero outside-fee writes: a 20.4M
SSTORE floor, before vault/planner overhead. Its manager-only sale measured
26,335,441 gas. The current product explicitly rejects that conversion before
execution. These historical numbers explain the authorized domain change;
they are not costs of a currently admitted operation or current acceptance failures.

## Verification commands and outputs

R1 was the default repository phase of this exact sequential command:

```text
cd /Users/cyotee/Projects/indexedex && python3 scripts/forge-artifacts.py test contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultProjection.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultWorkBudget.t.sol -- -vv && forge script lib/crane/scripts/foundry/ComputeNatSpecValues.s.sol --sig "run()" -vvv && forge build && forge test
```

Output: monitor `mon_SH5NFP5R0BTNC3Y5`, terminal `bash_51`, exit 0.
R2 is that command's first, 15-case WorkBudget suite. Final default output:

```text
Ran 2592 test suites in 416.72s (8030.82s CPU time): 27050 tests passed, 0 failed, 0 skipped
```

R3 refreshed final selector-comment artifacts, ran real deployment checks and
verified the product/test NatSpec values:

```text
cd /Users/cyotee/Projects/indexedex && python3 scripts/forge-artifacts.py test contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDeployment.t.sol -- -vv && forge script lib/crane/scripts/foundry/ComputeNatSpecValues.s.sol --sig "run()" -vvv
```

Output: `mon_71Q4T30HSF2JETJ2`, `bash_52`, exit 0; 12 deployment cases
passed and the script used 22,117,435 gas. Only comment tags were added to the
budget test afterwards, with executable-source equality verified. The previous
complete revised-family run was `mon_J2SSTR3MDSZC9QQA`, 233/233, before the
four additional mirrored/paired budget cases.

## Final component sizes

F = UniswapV4PairTokenStandardExchangeVault. All runtime bodies fit 24,576 bytes;
package creation code plus encoded constructor arguments fits 49,152 bytes in
the real-deployment test. No code-size override was introduced.

| Component suffix | Runtime bytes | Creation bytes |
| --- | ---: | ---: |
| MoneyFacet | 23043 | 23071 |
| QuoteFacet | 9932 | 9960 |
| OutFacet | 1397 | 1425 |
| QueryFacet | 4763 | 4791 |
| SYMoneyFacet | 23294 | 23322 |
| SYQueryFacet | 16196 | 16224 |
| CallbackFacet | 10130 | 10158 |
| DFPkg | 11115 | 19139 |
| Math | 5081 | 5133 |
| Projection | 9112 | 9164 |
| SwapProjection | 11839 | 11891 |
| Planner | 21979 | 22031 |
| Execution | 13212 | 13264 |
| ExecutionPreparation | 12874 | 12926 |

## Findings and boundaries

- Existing compiler/lint warnings remain unsuppressed, including the shared SY
  unreachable fallback and unrelated declarations. Bounded calls, exact receipt
  equality, guarded post-call events and deadline comparisons are intentional
  and exercised by the security/ledger suites.
- The token, price, future-only tick/bitmap and wrapper mutation rollback tests
  remain passing. Full-plan witnesses still include keys needed by later phases;
  reduced work bounds do not remove these checks.
- The concrete six-library links remain fixed and package-bound; metadata is
  excluded from product cuts. Occupied identity checks reject different code or
  binding values instead of silently upgrading an existing deployment.
- Production LSP checks were clean; successful compiler/test output is the
  decisive evidence where a large test's 3-second diagnostic refresh timed out.
- No project commit, broadcast, deployment, cache clearing, viaIR, package-specific
  profile, reduced fuzz depth or baseline/shared-runtime edit occurred.

## File scope

P = `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken`.
T = `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken`.
F = `UniswapV4PairTokenStandardExchangeVault`.

Production files under P:

- `UniswapV4PairTokenStandardExchangeVaultCallbackFacet.sol`
- `UniswapV4PairTokenStandardExchangeVaultCallbackTarget.sol`
- `UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol`
- `UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol`
- `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol`
- `UniswapV4PairTokenStandardExchangeVaultExecution.sol`
- `UniswapV4PairTokenStandardExchangeVaultMath.sol`
- `UniswapV4PairTokenStandardExchangeVaultMoneyFacet.sol`
- `UniswapV4PairTokenStandardExchangeVaultMoneyTarget.sol`
- `UniswapV4PairTokenStandardExchangeVaultOutFacet.sol`
- `UniswapV4PairTokenStandardExchangeVaultOutTarget.sol`
- `UniswapV4PairTokenStandardExchangeVaultPlanner.sol`
- `UniswapV4PairTokenStandardExchangeVaultProjection.sol`
- `UniswapV4PairTokenStandardExchangeVaultQueryFacet.sol`
- `UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol`
- `UniswapV4PairTokenStandardExchangeVaultQuoteFacet.sol`
- `UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol`
- `UniswapV4PairTokenStandardExchangeVaultRepo.sol`
- `UniswapV4PairTokenStandardExchangeVaultSYMoneyFacet.sol`
- `UniswapV4PairTokenStandardExchangeVaultSYMoneyTarget.sol`
- `UniswapV4PairTokenStandardExchangeVaultSYQueryFacet.sol`
- `UniswapV4PairTokenStandardExchangeVaultSYQueryTarget.sol`
- `UniswapV4PairTokenStandardExchangeVaultTypes.sol`
- `interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`
- `interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol`
- `test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol`
- `test/behaviors/Behavior_UniswapV4PairTokenStandardExchangeVaultPackage.sol`

Test files under T are the seventeen suite files in the exact case inventory, plus:

- `harness/Handler_UniswapV4PairTokenStandardExchangeVault.sol`
- `harness/PoolActor.sol`
- `harness/ProjectionActor.sol`
- `reference/math_oracle.py`
- `reference/vectors.json`
- `reference/README.md`

Shared verification-only edits: `lib/crane/scripts/foundry/ComputeNatSpecValues.s.sol`
and `lib/crane/docs/reference/CENTRALLY_COMPUTED_NATSPEC_VALUES.md`. This report is
`contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_EXECUTION_EVIDENCE.md`. Shared runtime contracts, the baseline and Wings were not edited.




## Independent product manifest

`F` denotes UniswapV4PairTokenStandardExchangeVault; family denotes its interface
and Repo. Family facet names below carry the F prefix. This manifest was derived
from the PRD and canonical interfaces, not implementation facet lists. Numeric
selectors were verified by the canonical ComputeNatSpecValues run.
Initialization owner for every stored product row is package initAccount in
proxy context; manager position state is created by manager operations. No
factory-owned selectors or IFacet metadata functions belong in these 60 cuts.

| Signature | Facet | Interface | Repo/state | Read policy | Planned test |
| --- | --- | --- | --- | --- | --- |
| `name()` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `symbol()` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `decimals()` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `totalSupply()` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `balanceOf(address)` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `allowance(address,address)` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `approve(address,uint256)` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `transfer(address,uint256)` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `transferFrom(address,address,uint256)` | ERC20Facet | IERC20 / IERC20Metadata | ERC20Repo | canonical | SUR.TokenDomainPermit |
| `permit(address,address,uint256,uint256,uint8,bytes32,bytes32)` | ERC2612Facet | IERC20Permit | ERC2612Repo / EIP712Repo | canonical | SUR.TokenDomainPermit |
| `nonces(address)` | ERC2612Facet | IERC20Permit | ERC2612Repo / EIP712Repo | canonical | SUR.TokenDomainPermit |
| `DOMAIN_SEPARATOR()` | ERC2612Facet | IERC20Permit | ERC2612Repo / EIP712Repo | canonical | SUR.TokenDomainPermit |
| `eip712Domain()` | ERC5267Facet | IERC5267 | EIP712Repo | canonical | SUR.TokenDomainPermit |
| `vaultTokens()` | MultiAssetBasicVaultFacet | IBasicVault | MultiAssetBasicVaultRepo | last committed snapshot | SUR.BookAndDiscovery |
| `reserveOfToken(address)` | MultiAssetBasicVaultFacet | IBasicVault | MultiAssetBasicVaultRepo | last committed snapshot | SUR.BookAndDiscovery |
| `reserves()` | MultiAssetBasicVaultFacet | IBasicVault | MultiAssetBasicVaultRepo | last committed snapshot | SUR.BookAndDiscovery |
| `vaultFeeTypeIds()` | MultiAssetStandardVaultFacet | IStandardVault | StandardVaultRepo | static discovery | SUR.BookAndDiscovery |
| `contentsId()` | MultiAssetStandardVaultFacet | IStandardVault | StandardVaultRepo | static discovery | SUR.BookAndDiscovery |
| `vaultTypes()` | MultiAssetStandardVaultFacet | IStandardVault | StandardVaultRepo | static discovery | SUR.BookAndDiscovery |
| `vaultConfig()` | MultiAssetStandardVaultFacet | IStandardVault | StandardVaultRepo | static discovery | SUR.BookAndDiscovery |
| `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` | MoneyFacet | family / IStandardExchangeIn | family / ERC20Repo / MultiAssetBasicVaultRepo | guarded mutation | ENT / EXT / CMP / STD / CRD |
| `depositPair(uint256,uint256,uint256,address,uint256)` | MoneyFacet | family / IStandardExchangeIn | family / ERC20Repo / MultiAssetBasicVaultRepo | guarded mutation | ENT / EXT / CMP / STD / CRD |
| `redeemPair(uint256,uint256,uint256,address,uint256)` | MoneyFacet | family / IStandardExchangeIn | family / ERC20Repo / MultiAssetBasicVaultRepo | guarded mutation | ENT / EXT / CMP / STD / CRD |
| `donate(address,uint256)` | MoneyFacet | family / IStandardExchangeIn | family / ERC20Repo / MultiAssetBasicVaultRepo | guarded mutation | ENT / EXT / CMP / STD / CRD |
| `compound()` | MoneyFacet | family / IStandardExchangeIn | family / ERC20Repo / MultiAssetBasicVaultRepo | guarded mutation | ENT / EXT / CMP / STD / CRD |
| `previewExchangeIn(address,uint256,address)` | QuoteFacet | family / IStandardExchangeIn | family / ERC20Repo / manager | guard first | PRO.EndToEndParity |
| `previewDepositPair(uint256,uint256)` | QuoteFacet | family / IStandardExchangeIn | family / ERC20Repo / manager | guard first | PRO.EndToEndParity |
| `previewRedeemPair(uint256)` | QuoteFacet | family / IStandardExchangeIn | family / ERC20Repo / manager | guard first | PRO.EndToEndParity |
| `previewWithdrawalMode(uint256,bool,address)` | QuoteFacet | family / IStandardExchangeIn | family / ERC20Repo / manager | guard first | PRO.EndToEndParity |
| `previewZapCredit(address,uint256)` | QuoteFacet | family / IStandardExchangeIn | family / ERC20Repo / manager | guard first | PRO.EndToEndParity |
| `previewExchangeOut(address,address,uint256)` | OutFacet | IStandardExchangeOut | none | unconditional unavailable | STD.ExactOutputUnavailable |
| `exchangeOut(address,uint256,address,uint256,address,bool,uint256)` | OutFacet | IStandardExchangeOut | none | unconditional unavailable | STD.ExactOutputUnavailable |
| `poolManager()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `poolKey()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `wrappedNative()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `rateAsset()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `tickLower()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `tickUpper()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `positionLiquidity()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `localReserves()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `basket()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `maxZapBps()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `maxZapTickMove()` | QueryFacet | family | family / manager | static configuration; economic methods guarded | SUR.BookAndDiscovery / SEC.CallbackReadMatrix |
| `deposit(address,address,uint256,uint256)` | SYMoneyFacet | IStandardizedYield | family / ERC20Repo | guarded money; empty reward semantics | SY.FullSurface / SY.EmptyRewards |
| `redeem(address,uint256,address,uint256,bool)` | SYMoneyFacet | IStandardizedYield | family / ERC20Repo | guarded money; empty reward semantics | SY.FullSurface / SY.EmptyRewards |
| `rewardIndexesCurrent()` | SYMoneyFacet | IStandardizedYield | family / ERC20Repo | guarded money; empty reward semantics | SY.FullSurface / SY.EmptyRewards |
| `claimRewards(address)` | SYMoneyFacet | IStandardizedYield | family / ERC20Repo | guarded money; empty reward semantics | SY.FullSurface / SY.EmptyRewards |
| `previewDeposit(address,uint256)` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `previewRedeem(address,uint256)` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `getTokensIn()` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `getTokensOut()` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `yieldToken()` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `assetInfo()` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `exchangeRate()` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `isValidTokenIn(address)` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `isValidTokenOut(address)` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `getRewardTokens()` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `accruedRewards(address)` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `rewardIndexesStored()` | SYQueryFacet | IStandardizedYield | family / ERC20Repo / manager | guard economic reads before validation; static discovery | SY.FullSurface / SEC.CallbackReadMatrix |
| `unlockCallback(bytes)` | CallbackFacet | IUnlockCallback | family / manager | authenticated active operation | SEC.CallbackCommitment |

Position liquidity, local reserves and basket are economic QueryFacet reads;
its other eight methods are static configuration. SY previewDeposit,
previewRedeem and exchangeRate are economic; other SY reads are discovery.
Out always reverts unavailable, including during mutation. Composed family
and SY interface closure is checked on the proxy rather than partial facets.

## Baseline comparison classes

| Class | Behavior | Control |
| --- | --- | --- |
| Preserved | Full-range salt-zero position; paired ratio/ceil input selection; one-sided full-live-leg acceptance; half zap; raw dust and sequential-floor ratio comparison; quarter cap | R1 BaselineComparison, Math, Entry and Compound controls pass on the common admitted domain. |
| Intentional deviation | S1-X01 through S1-X19: diamond storage/registry, no dead shares/retention/fees, immutable validated configuration, new surfaces, exact full previews, isolated booked inventory, terminal restart, authenticated callback, full final sale, clamped endpoints, empty-book rejection, caller growth attribution, final fee checkpoint, typed fallback, native sync and bounded projection | PRD identifiers preserved; R1 BaselineComparison distinguishes dead-share, retention, terminal and unbooked behavior; the acceptance suites exercise the remaining deviations. |
| Unsupported scope | Factory fee-manager routing, legacy convenience ABI equivalence, permissive initialization, exact output execution, Wings management and retired family restoration | Must remain absent |
| New capability | Canonical permit/domain, registered discovery, native/wrapped SE and SY, guarded whole-operation previews and rational raw SY rate | R1 registered-proxy Deployment, ProxySurface, Native, StandardizedYield and Security controls pass. |

No baseline add-sign defect is assumed: each cost is widened feesAccrued minus
callerDelta per currency. No baseline tests or harnesses are modified.

## Acceptance ledger

All 70 amended acceptance observations pass the engineering gates. This is not
a deployment or RPC-service availability claim. R1 is the final default gate;
R2 identifies the dedicated budget run. Exact case functions follow the table.

| PRD ID | Case family | Required observation | Result / command / suite |
| --- | --- | --- | --- |
| S1-A01 | DEP.RegistryDiscovery | Registered real native/ERC-20 diamonds found by faces, pair contents and declared types. | PASS: R1; Deployment. |
| S1-A02 | DEP.IdentitySensitivity | Prediction/deployment agree; args and package bindings vary identity from controlled pre-deployment snapshots. | PASS: R1; Deployment. |
| S1-A03 | DEP.ConfigurationDomain | All invalid key/code/fee/spacing/hook/price/rate/zap/wrapper/face cases reject; valid pools deploy. | PASS: R1; Deployment. |
| S1-A04 | DEP.LifecycleAuthentication | Direct init, repeat init, wrong process caller/context and invalid components leave no partial initialization. | PASS: R1; Deployment. |
| S1-A05 | SUR.TokenDomainPermit | Exact metadata, 18 decimals, proxy/chain domain, nonce advancement, replay rejection and two-instance isolation. | PASS: R1; ProxySurface. |
| S1-A06 | SUR.TargetFacetCutProxyMatrix | Independent typed controls equal declared/cut/live 60 selectors; factory set disjoint and callable. | PASS: R1; ProxySurface. |
| S1-A07 | SUR.BookAndDiscovery | Ordered views/config/types, sorted contents identity, zero fee IDs and local-vs-deployed distinction. | PASS: R1; ProxySurface. |
| S1-A08 | ENT.Genesis | Exact checked geometric mean wholly to recipient; no dead/virtual shares. | PASS: R1; Entry. |
| S1-A09 | ENT.GenesisFailures | Zero input/mint/fundable liquidity, product overflow and unmet final minimum roll back all state. | PASS: R1; Entry. |
| S1-A10 | ENT.PairedCandidateCredit | Ratio/ceiling accepted input, actual G/J and final cap, unused ERC-20 maxima and exact native refund. | PASS: R1; Entry. |
| S1-A11 | ENT.OneSidedDomain | Full live-leg maximum only; invalid positive-supply/zero-book domain rejects with reachability explained. | PASS: R1; Entry. |
| S1-A12 | ENT.MaintenanceInputIsolation | Pre-entry fees maintained while hypothetical/received caller input and native refund stay excluded. | PASS: R1; Entry. |
| S1-A13 | ENT.BothZaps | Half-swap, tick check, post-swap incumbent fees, caller-only addition and actual credit in both directions. | PASS: R1; Entry. |
| S1-A14 | ENT.ZapBoundaries | Empty/zero/cap/tick boundaries including equality, sub-tick movement and one-over cases. | PASS: R1; Entry. |
| S1-A15 | INV.EntryNonDilution | Independent wide q*R<=S*C at same P*, no epsilon; idle imbalance, partial input fill and rounding. | PASS: R1; AccountingInvariant. |
| S1-A16 | EXT.ProportionalPair | Exact liquidity/idle floors and actual principal; no retention. | PASS: R1; Exit. |
| S1-A17 | EXT.DustAndFeeOwnership | Remaining-holder rounding dust and fees; no duplicate allocation or share creation. | PASS: R1; Exit. |
| S1-A18 | EXT.BothSingleOutputs | Only exit inventory sold; final actual minimum and positive output. | PASS: R1; Exit. |
| S1-A19 | EXT.PartialSaleAndMaintenanceFallback | Partial sale rollback; valid paired CollectOnly succeeds for listed obstacles, not unrelated faults. | PASS: R1/R2; Exit + WorkBudget. |
| S1-A20 | EXT.LastHolderRestart | Zero supply/liquidity/book after paired exit; restart excludes old unbooked assets. | PASS: R1; Exit. |
| S1-A21 | EXT.TerminalSaleLiquidity | External liquidity permits full sale; vault-only liquidity failure preserves shares/state. | PASS: R1; Exit. |
| S1-A22 | CMP.NoVaultFeeOrShareChange | All realized LP fees retained once, no fee manager, no supply delta. | PASS: R1; Compound. |
| S1-A23 | CMP.BaselineBranches | Strict raw dust boundary, tie direction, zero-active liquidity, quarter cap and zero-swap paths. | PASS: R1; Compound. |
| S1-A24 | CMP.FeeCheckpointOwnership | Positive-add/no-add checkpoints, entry-swap incumbent fees, partial exit whole-position fees, remaining-holder exit-sale fees. | PASS: R1; Compound. |
| S1-A25 | STD.RouteTable | Four exact-input routes and every unsupported direction/token. | PASS: R1; StandardExchange. |
| S1-A26 | STD.ExactOutputUnavailable | Both selectors/interfaces present, exact unavailable error before any funding/mutation, including busy context. | PASS: R1; StandardExchange. |
| S1-A27 | PRO.EndToEndParity | Exact output, failure and resulting state from identical initial state for all route forms/modes. | PASS: R1/R2; Projection + Planner + Security + WorkBudget. |
| S1-A28 | PRO.WorkBudgetBoundaries | Exact 64/65 iterations, 12/13 crossings and 16/17 distinct words; shared suffix counters, at most two fresh candidates, exact error/fallback parity and zero failed-overlay leakage. Separate unreachable combinations from component guard controls. | PASS: R1/R2; Projection + Planner + Security + WorkBudget. |
| S1-A29 | SY.FullSurface | All 16 SY selectors share the same token and economic engine; no wrapper receipt token. | PASS: R1; StandardizedYield. |
| S1-A30 | SY.InternalSharesAndValidation | Internal-balance authority, caller class, value, token validation and invalid-preview policy. | PASS: R1; StandardizedYield. |
| S1-A31 | SY.EmptyRewards | Empty arrays and canonical events; LP backing not separately claimable. | PASS: R1; StandardizedYield. |
| S1-A32 | MAT.CanonicalRawSYRate | Fraction oracle, each conversion's own rounding contract, and SYUtils.syToAsset raw-unit results within its checked-multiplication domain for 6/8/18 decimals. No exact-inverse promise; distinguish helper overflow from valid wide-rate/final-overflow cases. | PASS: R1; Math + Projection + StandardizedYield. |
| S1-A33 | SY.EmptyRate | Zero before bootstrap; no artificial target-token 1:1 genesis issuance. | PASS: R1; StandardizedYield. |
| S1-A34 | CRD.FalseFlagReceipt | Exact actual receipt; short delivery cannot borrow booked/existing balances. | PASS: R1; CreditDonation. |
| S1-A35 | CRD.CodeLessPretransfer | EOA and construction-time callers receive canonical pretransfer error. | PASS: R1; CreditDonation. |
| S1-A36 | CRD.MissingOrShortCredit | Contract with insufficient unbooked inventory cannot mint/burn against incumbent backing. | PASS: R1; CreditDonation. |
| S1-A37 | CRD.ExcessCredit | Process declared amount only; no excess refund/adoption, including wrapper representation. | PASS: R1; CreditDonation. |
| S1-A38 | CRD.DonationVsUnsolicited | Same-call donation no mint; unsolicited balances stay unbooked through full lifecycle. | PASS: R1; CreditDonation. |
| S1-A39 | SEC.CallbackCommitment | Actual manager callback succeeds; wrong sender, payload, operation, replay and cross-facet reentry reject. | PASS: R1; Security. |
| S1-A40 | SEC.ManagerAlreadyUnlocked | Explicit pre-nested-unlock failure, no Wings local-sleeve path. | PASS: R1; Security. |
| S1-A41 | INV.CustodyAndPosition | Stable reservations, manager deltas, liquidity, supply/book/events reconcile on every operation. | PASS: R1; AccountingInvariant. |
| S1-A42 | CRD.DisabledPolicy | Issuance/donation blocked; public compound and eligible normal/fallback exits still work. | PASS: R1/R2; CreditDonation + WorkBudget. |
| S1-A43 | SEC.AtomicFailure | Receiver/token/minimum failure rolls back swaps, removals, burns and prior transfers. | PASS: R1; Security. |
| S1-A44 | ENT.MixedDecimalsAndForbiddenTokens | Supported non-18 amounts and real negative FoT/short delivery never overcredit. | PASS: R1; Entry. |
| S1-A45 | MAT.EndpointCapacityDomain | Canonical below/equal/interior/equal/above principal/costs and specified type/capacity failure classification. | PASS: R1; Math + Projection + StandardizedYield. |
| S1-A46 | INV.AdversarialOwnershipSequences | Exact ownership/supply predicates across first deposit, donation, entries/exits; separately track market effects. | PASS: R1; AccountingInvariant. |
| S1-A47 | DEP.InstanceIsolation | Shared facets do not share instance book, domain, approvals, position or initialization state. | PASS: R1; Deployment. |
| S1-A48 | GAS.RuntimeSize | Every shipped facet/package/linked runtime within normal limits; configured compiler/settings unchanged. | PASS: R1; Feasibility + WorkBudget. |
| S1-A49 | NAT.PairedInputRefund | Exact msg.value maximum, pre-maintenance reservation, unused-only refund and rollback on rejection. | PASS: R1; Native. |
| S1-A50 | NAT.NativeWrappedEquivalence | Same economics/state from equal initial state; only representation differs across SE/SY. | PASS: R1; Native. |
| S1-A51 | NAT.ActualProxySettlement | Payable proxy calls, wrapper callbacks, native sync/take/settle and zero-address ERC-20 exclusion. | PASS: R1; Native. |
| S1-A52 | NAT.ReservationSolvency | Forced ETH, pending funds, refunds and temporary wrapper cannot double-count or create free credit. | PASS: R1; Native. |
| S1-A53 | NAT.ReceiverBehavior | Ordinary contract receivers work; reentry/rejection cannot escape guard or partial rollback. | PASS: R1; Native. |
| S1-A54 | NAT.TerminalRestart | Last-holder ETH/token book drained; restart excludes old unsolicited ETH. | PASS: R1; Native. |
| S1-A55 | CRD.DonationForms | Raw/alias/native vs actual WETH leg correct once; wrong value/token/pool form rejected. | PASS: R1; CreditDonation. |
| S1-A56 | SUR.ReusedTwenty | Exactly five canonical facets/20 selectors; no combined permit duplicate, factory input/cut or duplicate SY token entry. | PASS: R1; ProxySurface. |
| S1-A57 | SUR.FactoryLifecycleAndPermit | Persistent factory interfaces, removed temporary hook, correct shared initialization and real permit behavior. | PASS: R1; ProxySurface. |
| S1-A58 | DEP.NativeContentsOrdering | Wrapped face sorts after other token: pair lookup still works; visible lists stay in face order. | PASS: R1; Deployment. |
| S1-A59 | SEC.CallbackReadMatrix | New economic views reject; unchanged basic reserves stay committed; token/static views remain canonical. | PASS: R1; Security. |
| S1-A60 | NAT.OutstandingSync | Native reset after outstanding ERC-20 sync and ledger attribution of proxy receive; final manager deltas zero. | PASS: R1; Native. |
| S1-A61 | PRO.FallbackReasons | Each reason has a real reachable fixture or independent unreachability proof; valid full plan always wins. | PASS: R1/R2; Projection + Planner + Security + WorkBudget. |
| S1-A62 | SEC.NoExecutionRetry | Actual manager/token/wrapper/custody/collection/state/payout failures never become fallback retries. | PASS: R1/R2; Security + WorkBudget. |
| S1-A63 | PRO.ModeAndFinalSale | Minima/ordinary sale failure alone do not switch mode; paired sentinel and raw-ETH output unambiguous. | PASS: R1/R2; Projection + Planner + Security + WorkBudget + WorkBudget. |
| S1-A64 | ENT.CreditDecomposition | G/J/C/incumbent fee separation; addition rounding cost borne by entrant; min against final q. | PASS: R1; Entry. |
| S1-A65 | INV.StableLedgerTerminalReceipts | Categories reconcile; terminal owned receipt paid, unsolicited excluded through restart. | PASS: R1; AccountingInvariant. |
| S1-A66 | CMP.EmptyAndTinyStates | Empty compound no-op, zero-total-output burn rejects, positive one-sided output and tiny-state accounting hold. | PASS: R1; Compound. |
| S1-A67 | PRO.FullStateAndInvalidation | Protocol fees, crossings, empty words/checkpoints and token/wrapper mutations match or invalidate exactly. Include a later-needed tick/bitmap mutation with unchanged current price; reject before consuming that future action. | PASS: R1; Projection + Planner + Security + WorkBudget. |
| S1-A68 | SUR.AbsentCapabilitiesAndBindings | No ownership/diamondCut/rescue/ERC4626/excluded integrations; full manifest and binding-sensitive identity. | PASS: R1; ProxySurface. |
| S1-A69 | DEP.ZeroFeesAndConstants | Real registry accepts zero fee IDs; no fee fallback, raw dust, explicit zap args and cached validated metadata. | PASS: R1; Deployment. |
| S1-A70 | GAS.DeploymentEnvelope | Supported normal/fallback/native/wrapped boundary combinations fit 11.9M cold call-body gas plus 100k transaction reserve and 5M previews. Previously admitted dense single sales reject early; valid paired fallback remains affordable. Keep normal code limits and test settings; disclose unverified RPC-provider caps. | PASS: R1/R2; Feasibility + WorkBudget. |

## Exact case inventory

Each heading identifies `F<heading>.t.sol` under T. The source inventory has
239 test/invariant functions. Foundry groups the three invariant functions as
one case, giving 237 family cases across 17 suites within the default gate.

### Feasibility

```text
test_GAS_RuntimeSizeEveryShippedComponent
test_GAS_AllLinkedComponentsRejectDirectExecution
test_GAS_OccupiedPackageCannotSilentlyRebindLibraries
test_GAS_OccupiedFacetCannotSilentlyReuseDifferentCode
test_GAS_NormalPreviewAndExecutionColdCalls
test_GAS_NativeAndWrappedColdCalls
test_GAS_ConditionalPairedExitAfterCrossingBudget
test_GAS_Former512CandidatesRejectSingleExitBeforeExecution
test_GAS_FinalSaleExhaustionAfterMaintenanceAndDisabledFallback
test_GAS_ProjectionMemoryProfile
test_GAS_RealManager512CrossingSaleProfile
test_GAS_RealManagerStorageWritesExceedEthereumTransactionCap
```

### Native

```text
test_NAT_PairedExactMaximumRefundAndPendingInputIsolation
test_NAT_WrongPairedAndSYValuesRollback
test_NAT_RawWrappedSYAndSEDepositEqualSnapshots
test_NAT_RawWrappedSYAndSEExitEqualSnapshots
test_NAT_OutstandingERC20SyncResetBeforeNativeDebt
test_NAT_ForcedAndEmptyCalldataETHExcludedThroughTerminalRestart
test_NAT_RejectingAndReentrantPayoutRollback
test_NAT_RejectingAndReentrantRefundRollback
test_NAT_NormalHeavyReceiverAndCaughtReentryOutPrecedence
test_NAT_WrappedShortExcessCreditDoesNotUseBookedETH
test_NAT_DiscoveryAndZeroAddressSERejected
test_NAT_TerminalRawAndWrappedSingleExitWithRealExternalLiquidity
test_NAT_DisabledNativeCapitalBlockedRawAndWrappedExitsRemain
```

### CreditDonation

```text
test_CRD_FalseFlagExactPullBothCurrenciesAndAllowance
test_CRD_ShortPullCannotBorrowBackingOrUnsolicitedBalances
test_CRD_TrueFlagEOAAndConstructionRejectionEveryInputClass
test_CRD_ShortSecondPairedPullRestoresFirstPullAndAllowances
test_CRD_ContractMissingShortAndExcessCreditBothCurrencies
test_CRD_SharePretransferCannotBurnHolderOrExcess
test_CRD_DonationAndUnsolicitedRemainDistinctThroughRestart
test_CRD_DisabledBlocksCapitalButAllowsMaintenanceAndAllExitForms
test_CRD_NativeAndWrappedDonationCreditOnceAndValidateValue
test_CRD_DonationZeroSupplyZeroAmountAndInvalidNativeForm
test_CRD_ActualWETHERC20LegNeverActsAsNativeAlias
test_CRD_ShortPayoutRollsBackRemovalBurnAndEarlierManagerTransfers
test_CRD_SecondPayoutShortReceiptRestoresFirstDeliveredToken
```

### StandardExchange

```text
test_STD_FourRoutesExactPullAndBurn
test_STD_UnsupportedRouteCartesianMatrix
test_STD_ExactOutputUnconditionallyUnavailable
test_STD_MinimumAndDeadlineRollbackBothDirections
```

### Exit

```text
test_PairToken_EXT_ProportionalPairFloorsWithoutRetention
test_PairToken_EXT_WholePositionFeesAreProportionallyOwned
test_PairToken_EXT_BothSingleOutputsAndRemainingHolderFees
test_PairToken_EXT_MinimumFailureRollsBackCompleteSale
test_PairToken_EXT_PartialFinalSaleRollsBackAndPairStillWorks
test_PairToken_EXT_LastHolderRestartExcludesUnsolicited
test_PairToken_EXT_TerminalSingleNeedsExternalLiquidity
test_PairToken_EXT_LiquidityCapacityCollectOnlyFallback
test_PairToken_EXT_PriceBoundaryCollectOnlyFallback
test_PairToken_EXT_DeltaCapacityCollectOnlyFallback
test_PairToken_EXT_WorkBudgetCollectOnlyFallback
test_PairToken_EXT_PairedSentinelAndNativeSingleModeAreUnambiguous
test_PairToken_EXT_UnexpectedNativePayoutFailureDoesNotFallback
test_PairToken_EXT_TinyZeroPayoutAndOneSidedPositiveOutput
```

### WorkBudget

```text
test_BUD_Crossing12Allowed13RejectedWithoutFetchingTick
test_BUD_RepeatCrossingsShareTheWholeCandidateBudget
test_BUD_DistinctWord16Allowed17RejectedAndRepeatReadFree
test_BUD_Iteration64Allowed65RejectedComponentGuard
test_BUD_DenseSingleExitRejectedBeforeBurnAndPairRemainsAffordable
test_BUD_BitmapExhaustionPreservesPairedEscapeAndRejectsZap
test_BUD_MaximumCrossingFallbackWithBothFeeCurrencies
test_BUD_MaintenanceFitsButFinalSaleExhaustsSharedBudget
test_BUD_MaximumSupportedEntryAcrossMaintenanceAndZap
test_BUD_MaximumSupportedToken1Entry
test_BUD_MaximumSupportedNativeEntry
test_BUD_MaximumSupportedWrappedEntry
test_BUD_MaximumSupportedNativePoolToken1Entry
test_BUD_MaximumFullCompoundPairedAndTerminalExits
test_BUD_MaximumNativeFullCompoundPairedAndTerminalExits
```

### BaselineComparison

```text
test_BASE_PreservedGeometricQuoteAndFullRange
test_BASE_IntentionalDeadRetentionAndTerminalDeviations
test_BASE_UnbookedPolicyDeviationAndNewSYCapability
```

### Projection

```text
test_PRO_CanonicalPositionKeyAndLoader
test_PRO_ModifyPokeAndPartialRemoval
test_PRO_FeeInclusiveAmountsExcludeReservations
test_PRO_IndependentOneStepProtocolFeeBothDirections
test_PRO_ProtocolOnlyFeeHasNoLPGrowth
test_PRO_InitializedCrossingAndStoredBoundaryBothDirections
test_PRO_ClearAndReinitializeBoundaryOverlays
test_PRO_EndpointAndOutsidePrincipalDomains
test_PRO_Word16Allowed17FailsAndSharedCounter
test_PRO_OneSwapRequiredWord17
test_PRO_FutureOnlyTickInvalidatesInitialWitness
test_PRO_FutureOnlyWordInvalidatesInitialWitness
test_PRO_PhaseCaptureAndLocalReservationIndependence
test_PRO_RealModularGrowthAndCheckpoint
test_PRO_CapacityAndPrincipalFailuresAreTyped
test_PRO_UnrepresentableFeesAreNotMaintenanceCapacity
test_PRO_SignedSwapEndpointsAndLargePartialRequest
test_PRO_UnsupportedAndEmptyDomainsReturnFailure
testFuzz_PRO_SwapAddRemoveRealManagerParity
```

### StandardizedYield

```text
test_SY_FullSurfaceAndEmptyRate
test_SY_ExecutionEventsAndSEEqualityBothDirections
test_SY_InternalShareAuthorityMissingShortAndExcess
test_SY_InternalEOAAndConstructorRejectEvenWithHeldShares
test_SY_FalseFlagCannotBurnAnotherHoldersShares
test_SY_InvalidTokensZeroPreviewsButExecutionReverts
test_SY_ValidationReceiverAmountAndNativeValue
test_SY_RawRateCachedMetadataSixEightEighteenDecimals
test_SY_NonUnitFractionRateBothAssetsAndDecimals
```

### Planner

```text
test_PLN_LinkedPlannerRejectsDirectCalls
test_PLN_FallbackClassifierAllPhasesAndKinds
test_PLN_EmptyCompoundExcludesReservationsAndUnbookedCustody
test_PLN_GenesisMintsAllGeometricSharesAndTerminalRestart
test_PLN_GenesisAndEmptyZapErrors
test_PLN_PositiveGenesisSharesStillRequireFundableLiquidity
test_PLN_InvalidPositiveSupplyEmptyBookAndFinalSupplyOverflow
test_PLN_CompoundDustAndPositiveAddCheckpoint
test_PLN_CompoundSwapWithoutAdditionFinishesWithOneCheckpoint
test_PLN_FeesMaintenanceAndPairedCallerAttribution
test_PLN_ZapBothDirectionsCheckpointsAndResidualDonation
test_PLN_ZapCapAndTickMoveErrors
test_PLN_ZapSizeEqualityAndOneOver
test_PLN_ZapTickEqualityAndOneBelow
test_PLN_PartialPairedExitAllocatesWholePositionFeesOnlyOnce
test_PLN_SingleExitBothDirectionsOnlySellsAllocation
test_PLN_LastSingleExitWithExternalLiquidity
test_PLN_LastSingleExitWithoutLiquidityRevertsWithoutFallback
test_PLN_RealTickCapacityFallbackUsesUntouchedOriginal
test_PLN_UnsignedLiquidityOverflowFallbackAndNoCompoundFallback
test_PLN_RealCollectionOverflowCannotSelectFallback
test_PLN_WholeMaintenanceWorkLimitSelectsFreshPairCandidate
test_PLN_OneSidedPairedIdleCreditWithoutAddition
test_PLN_TinyPairedZeroPayoutRejects
test_PLN_InitialWitnessCoversLaterSwapWord
testFuzz_PLN_PairedEntryAndExitManagerParity
```

### Deployment

```text
test_PairToken_DEP_RegistryDiscovery
test_PairToken_DEP_ArgumentIdentitySensitivity
test_PairToken_DEP_BindingIdentitySnapshots
test_PairToken_DEP_InvalidPoolConfiguration
test_PairToken_DEP_RateZapAndZeroPoolFee
test_PairToken_DEP_MetadataFailureAndSelfFaceDomain
test_PairToken_DEP_LifecycleAuthentication
test_PairToken_DEP_InvalidComponents
test_PairToken_DEP_NativeContentsOrdering
test_PairToken_DEP_InstanceIsolation
test_PairToken_DEP_NativePublicBootstrapAndClose
test_PairToken_DEP_ExternalActorRoundTrip
```

### Compound

```text
test_PairToken_CMP_EmptyCompoundCleanAndUnsolicitedNoOp
test_PairToken_CMP_NoVaultFeeOrShareChange
test_PairToken_CMP_StrictRawDustAndBalancedLeftoverTie
test_PairToken_CMP_SmallLeftoverDoesNotSwap
test_PairToken_CMP_SequentialFloorTieChoosesToken0
test_PairToken_CMP_HalfLeftoverBothDirections
test_PairToken_CMP_QuarterReserveCapBothDirections
test_PairToken_CMP_ZeroActiveLiquidityNoSwap
test_PairToken_CMP_PositiveAddFinalFeeCheckpoint
test_PairToken_CMP_NoAddFinalFeeCheckpoint
test_PairToken_CMP_EntrySwapFeesStayIncumbentBothDirections
```

### Entry

```text
test_ENT_GenesisCompleteGeometricMeanNoDeadShares
test_ENT_GenesisSingleShareIsNotAHiddenMinimum
test_ENT_GenesisZeroInputsAndZeroMintRollback
test_ENT_GenesisCheckedProductOverflowRollback
test_ENT_GenesisPositiveMintButZeroFundableLiquidityRollback
test_ENT_GenesisActualShareMinimumRollback
test_ENT_PairedToken0LimitingCeilAcceptedAndFinalCreditCap
test_ENT_PairedToken1LimitingCeilAcceptedAndFinalCreditCap
test_ENT_PairedNonLimitingMaxUintQuotientDoesNotReject
test_ENT_PairedNativeUnusedMaximumRefundIsExact
test_ENT_OneSidedToken0ConsumesFullLiveLegMaximum
test_ENT_OneSidedToken1ConsumesFullLiveLegMaximum
test_ENT_PositiveSupplyBothZeroAfterTinyGenesisRejects
test_ENT_ComponentOnlyNonLimitingCreditOverflowUsesFinalCap
test_ENT_MaintenanceFeesAndPendingPairInputAreIsolated
test_ENT_MaintenanceFeesAndPendingNativeMaximumAreIsolated
test_ENT_ZapToken0HalfSwapPostSwapFeesAndCallerOnlyCredit
test_ENT_ZapToken1HalfSwapPostSwapFeesAndCallerOnlyCredit
test_ENT_ZapsEmptySupplyRejectBothDirections
test_ENT_ZapZeroInputRollbackBothDirections
test_ENT_ZapSizeCapEqualityAndOneOverBothDirections
test_ENT_ZapTickMovementEqualityAndOneOverBothDirections
test_ENT_ZapSubTickPriceMovementWithZeroTickBound
test_ENT_ZapPartialFillWithZeroOpposingGrowthRollsBack
test_ENT_ZapToken0PartialFillIdleImbalanceAndUncreditedResidual
test_ENT_ZapToken1PartialFillIdleImbalanceAndUncreditedResidual
test_ENT_PairedRoundingCapMinimumUsesFinalNotCandidateShares
test_ENT_ZapFinalMinimumRollbackBothDirections
test_ENT_MixedSixEightEighteenDecimalsPairedAndBothZaps
test_ENT_ForbiddenFeeOnTransferPairedPullRollsBack
test_ENT_ForbiddenFeeOnTransferZapPullRollsBack
```

### Security

```text
test_SEC_CallbackEconomicReadMatrixAndCommittedBook
test_SEC_CrossFacetMoneyReentryAndUnconditionalOut
test_SEC_AlreadyUnlockedManagerRejectsBeforeNestedUnlock
test_SEC_UnsolicitedAndReplayedCallbackPayloadsReject
test_SEC_PullPriceMutationInvalidatesAndRollsBack
test_SEC_ActualManagerCallbackCannotBeReplayedOrModified
test_SEC_FutureOnlyBitmapMutationInvalidatesWithoutPriceMove
test_SEC_FutureOnlyTickMutationInvalidatesAtUnchangedBitmap
test_SEC_WrapperUnwrapMutationInvalidatesWithoutRetry
test_SEC_WrapperWrapMutationRollsBackBurnAndSale
```

### ProxySurface

```text
test_PairToken_SUR_TargetFacetCutProxyMatrix
test_PairToken_SUR_FactoryPersistentClosure
test_PairToken_SUR_TokenDomainPermit
test_PairToken_SUR_BookAndDiscovery
test_PairToken_SUR_ExactOutputUnavailable
test_PairToken_SUR_PublicEngineSurfaceSmoke
```

### AccountingInvariant

```text
invariant_INV_SupplyAndIndependentHolderGhosts
invariant_INV_CustodyAndPositionStableLedger
invariant_INV_EntryNonDilutionAndPreSaleAllocation
test_INV_AdversarialOwnershipSequences
testFuzz_INV_PublicRouteOwnershipSequence
test_INV_StableLedgerTerminalReceiptsAndRestart
test_INV_EntryNonDilutionCappedAndUncappedPairs
test_INV_EntryNonDilutionPartialFillsBothDirections
test_INV_TinyEconomicRejectionsAreAtomicAndClassified
test_INV_UnexpectedHandlerFailureCannotDisappear
```

### Math

```text
test_mathLibrary_rejectsDirectCall
test_principalAndCosts_fractionVectors
test_liquidity_integerVectors
test_pairedQuote_integerVectors
test_pairedQuote_oracleVectors
test_credit_cappedOracleVectors
test_zapCredit_uncappedOracleVectors
test_credit_zeroReserveAndOneSidedAcceptance
test_allocation_integerVectors
test_compoundSwap_integerVectors
test_compoundSwap_inspectableLiquidityFailure
test_liquidity_inspectableCapacityBoundary
test_compoundSwap_sequentialFloorDirection
test_compoundSwap_wideComparison
test_accountingRate_fractionVectors
test_accountingRate_wideIntermediateRepresentableFinal
test_accountingRate_singleFloorNotSequentialFloors
test_accountingRate_canonicalRawSYHelpers
test_accountingRate_rateAndSYRounding
test_accountingRate_helperOverflowIsSeparate
test_accountingRate_finalOverflow
test_accountingRate_emptyAndInvalidPrice
test_pairedQuote_checkedGenesisAndZero
test_credit_invalidAccountingAndZero
test_liquidity_capacityAndInvalidRange
test_liquidity_nonlimitingOverflow
test_allocation_invalidShares
testFuzz_principal_interiorPreserved
testFuzz_liquidity_preservedAffordable
testFuzz_credit_nonDilution
testFuzz_accountingRate_singleFloor
```

