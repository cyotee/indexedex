# Rebasing-aware ERC4626 SY/SE implementation and test plan

**Date:** 2026-09-11  
**Status:** Draft for owner review. Documentation only; implementation and deployment are not authorized.  
**Requirements:** [Rebasing-aware ERC4626 SY/SE PRD](./REBASING_AWARE_ERC4626_SY_SE_PRD.md).  
**Delegation gate:** Review this plan and resolve the buffer topology conflict in §8 before assigning implementation. No implementer may select a topology, relax token policy, change decimals, or omit required buffer tests to resolve that conflict.

## 1. Objective and boundaries

Extend newly deployed `RebasingAwareERC4626DFPkg` vault diamonds with canonical Standard Exchange and Standardized Yield interfaces, registration, and sequential quotes. All interfaces use the existing static ERC20 share token and live rebasing-asset backing. Preserve the owner decisions D-01–D-11 in the PRD.

The wrapper takes no fees, supports general rebasing ERC20 assets without a protocol allowlist, and neither harvests nor distributes separate rewards. Asset-input pretransfers always reject; static-share-input SE withdrawals burn required shares and refund the snapshotted excess. Internal SY redemption burns exactly the requested shares without refunding the remainder. Zero-value executions reject, zero-amount previews return zero, and deposits stop at zero backing with outstanding supply.

This plan fixes the proposed engineering choices for review. It does not represent approval of those choices or evidence of implemented behavior. Required buffer integration remains a release dependency, not a feature the implementer can defer. Frontend work, public deployment, core factory replacement, and automatic migration of existing vaults are outside this task.

Read `CLAUDE.md`, the `.github/ASSISTANT_*` rules, the Crane architecture/deployment/testing/adversarial skills, and IndexedEx testing/adversarial skills before execution. Preserve unrelated working-tree changes. Follow current source over older examples, while reporting conflicts with approved product requirements.

## 2. Proposed contract and storage layout

All new wrapper production files live beside this plan. Preserve the existing `RebasingAwareERC4626Repo` storage slot and its first fields, `asset` and `decimalOffset`. Append `uint8 assetDecimals` and `address vaultRegistry`; initialize once when the factory initializes a new diamond. Do not add a cached asset reserve, owner, upgrade entrypoint, sweep, arbitrary call, or reward state.

| File / component | Implementation responsibility |
|---|---|
| `IRebasingAwareERC4626DFPkg.sol` | Retain both public `deployVault` signatures and the existing `PkgArgs` field order. Extend `PkgInit` in the order specified below; implement the standard package declaration contract. |
| New `IRebasingAwareERC4626.sol` | Wrapper errors and shared structs, including quote state; keep structs on interfaces. |
| `RebasingAwareERC4626Repo.sol` | Immutable asset, effective offset, captured asset decimals, registry reference; live backing reads. |
| New `RebasingAwareERC4626Common.sol` | One conversion and settlement core for all three standards; common entry checks, exact token accounting, and share custody modes. |
| `RebasingAwareERC4626Target.sol` / existing facet | Retain the 16 ERC4626 selectors; delegate internal accounting to Common. |
| New `RebasingAwareStandardExchangeTarget.sol` / `RebasingAwareStandardExchangeFacet.sol` | Canonical SE exact-in, exact-out, and their two previews. No duplicated ERC4626 selectors. |
| New `RebasingAwareStandardYieldTarget.sol` / `RebasingAwareStandardYieldFacet.sol` | All 16 non-ERC20 canonical SY selectors, with a direct call into Common. |
| New `RebasingAwareVaultMetadataTarget.sol` / `RebasingAwareVaultMetadataFacet.sol` | `IBasicVault` and `IStandardVault` metadata using live wrapper backing. |
| New `RebasingAwareStandardExchangeQuoteTarget.sol` / `RebasingAwareStandardExchangeQuoteFacet.sol` | Five transition-quote methods and two external-quote methods. |
| `RebasingAwareERC4626DFPkg.sol` | Six facet cuts: shared ERC20, ERC4626, SE, SY, metadata, quotes; manager registry deployment and immutable release configuration. |
| New `RebasingAwareERC4626_Component_FactoryService.sol` | Artifact-backed facet deployment and registry-backed package deployment with release-sensitive salts. |

Reuse the shared ERC20 facet, Crane safe-token and full-precision math primitives, and the existing shared reentrancy lock. Do not inherit the regular ERC4626 SE accounting core: it wraps an external protocol vault, maintains different reserves, and includes fee behavior. Do not inherit Native SY money routing: a wrapper-specific Target avoids self-call caller-context complexity and accidental SE excess refunds. The existing `NativeStandardYieldSelectors` helper may supply the SY selector list.

`PkgInit` field order: existing `erc20Facet`, `rebasingAwareErc4626Facet`, `diamondFactory`, then `standardExchangeFacet`, `standardYieldFacet`, `vaultMetadataFacet`, `transitionQuoteFacet`, `vaultRegistry`. Facet fields use `IFacet`; factory retains its existing type; registry uses `IVaultRegistryDeployment`. Reject missing/code-less dependencies before deploying a vault. The constructor ABI changes intentionally and therefore requires a new package address.

### 2.1 Metadata and interface ownership

`vaultTokens()` and `vaultConfig().tokens` return exactly `[asset]`. `reserveOfToken(asset)` and `reserves()` report the live asset balance; an unsupported reserve reverts with canonical `UnknownReserve(address)`. `contentsId` hashes `abi.encode(address[]([asset]))` using a constructed one-element memory array. `vaultFeeTypeIds()` is always `bytes32(0)` on both package and vault. No operation queries fee rates or accumulates a fee liability.

Use package name `RebasingAwareERC4626`. Package and vault `vaultTypes()` return, in order, the interface IDs for `IERC4626`, `IStandardExchangeIn`, `IStandardExchangeOut`, `IStandardizedYield`, `IStandardExchangeTransitionQuote`, and `IStandardExchangeExternalQuote`. ERC165 declarations additionally cover installed ERC20/metadata/basic-vault/standard-vault interfaces, following the diamond factory's existing ERC165 ownership. Do not install duplicate `name`, `symbol`, `decimals`, ERC20, or `supportsInterface` selectors. An aggregate interface is advertised only if its complete inherited surface exists.

Generate the selector matrix from compiled ABI signatures, including tuple fields and overloads; do not hand-copy selectors. Assert package cuts, facet declarations, loupe destinations, and successful proxy calls agree. Canonical ERC4626 Deposit/Withdraw and ERC20 mint/burn events accompany each operation; SY executions also emit the canonical SY event once. Verify full event topics and arguments.

## 3. Numeric domain and exact accounting

### 3.1 Decimal bounds

Preserve `effectiveOffset = max(requestedOffset, 10)`. The proposed supported effective offset range is **10 through 18 inclusive**. Reject larger requested offsets. Require `assetDecimals + effectiveOffset <= 77`, so decimal powers used by integrations fit a uint256; do the addition in a widened integer. This is a numerical constraint, not an asset allowlist. Default helpers use offset 10; sDETF produces 19-decimal shares and an 18-decimal asset produces 28-decimal shares. The empty-vault raw SY rate is `10^(18-effectiveOffset)`.

Capture asset decimals at initialization; do not silently reconfigure wrapper decimals if underlying metadata later changes. No metadata offset change is possible after deployment. Preserve helper-generated `Wrapped <name>` / `w<symbol>` metadata and the existing custom-name argument semantics.

### 3.2 Conversion model

Let `A` be live assets, `S` issued shares, `V = 10^effectiveOffset`, and `M = type(uint256).max`. Valid pricing state requires `A < M` and `S <= M - V`. Use full-precision multiplication/division, with explicit overflow failure if a quotient or post-operation state is outside the domain.

| Operation | Required computation |
|---|---|
| Deposit assets `x` | `floor(x * (S + V) / (A + 1))` shares |
| Mint shares `q` | `ceil(q * (A + 1) / (S + V))` assets |
| Redeem shares `q` | `floor(q * (A + 1) / (S + V))` assets |
| Withdraw assets `x` | `ceil(x * (S + V) / (A + 1))` shares |

Check `A + assetsIn < M` and `S + sharesMinted <= M - V` before settling an entry. Check output against actual backing and shares against the appropriate holder before an exit. A full exit does not sweep virtual-share dust. All conversions use raw units; no second decimal normalization is applied at ERC20 boundaries.

`exchangeRate()` computes `floor(1e18 * (A + 1) / (S + V))` independently of executable exits. If zero, revert `SYExchangeRateUnderflow()`. If the full-precision result exceeds uint256, use `NumericDomainExceeded()`. Do not clamp either boundary. Test the PRD bound `abs(convertToAssets(q) - floor(q * rate / 1e18)) <= ceil(q / 1e18) + 1` where rate is representable.

For entry maximums, disabled or insolvent (`A == 0 && S > 0`) vaults return zero. Otherwise calculate the largest input whose resulting state remains in the numeric domain, capped by remaining asset/share capacity. Derive the inverse floor bound with full precision: with remaining share capacity `Q = M - V - S`, deposit capacity from shares is `ceil((Q + 1)*(A + 1)/(S + V)) - 1`; saturate an out-of-range inverse at `M`, then cap by `M - 1 - A`. For mint, cap remaining shares by `floor((M - 1 - A)*(S + V)/(A + 1))`. Max views do not promise that a hostile underlying will accept a transfer. Exits retain their ERC4626 owner-balance limits.

### 3.3 Settlement policy

The proposed generic boundary is **reject a rebase during the asset transfer**, rather than attributing its balance delta to the caller. Settled rebases between operations remain fully supported. No generic method calls an sDETF selector.

Under the shared lock, snapshot `A`, `S`, underlying total supply, and relevant payer/receiver asset balances before token settlement. An inbound pull must debit the payer and credit the vault by exactly the calculated asset input, and leave underlying total supply unchanged. An outbound transfer must debit the vault and credit the receiver by exactly the calculated asset output, also without an underlying total-supply change. Compare deltas without unsigned underflow. A mismatch reverts the entire operation. This rejects measurable transfer tax, transfer-triggered global rebase, incidental reserve donation during a callback, and nominal-output success with a short recipient payment.

This policy deliberately rejects tokens whose transfer cannot complete at a stable accounting boundary. Document that limit to general-purpose compatibility; it is not a claim to accept every possible ERC20. Tests must include a generic rebasing token with no DETF API and the production sDETF implementation. For real sDETF, the integration must settle via the DETF's existing `synchronizeRewards()` before entering the wrapper when rewards are pending. Put that call in the sDETF-aware consumer/router, never in the generic wrapper. If settlement is first triggered inside the wrapper's transfer, require a clean revert; after explicit settlement, the same economically valid operation must succeed. Regression tests must verify TokenStaking's existing sDETF acquisition establishes this boundary, and add explicit synchronization there if needed.

Use three internal share-source modes: `CallerOrApprovedOwner`, `PublicBalanceRefundExcess`, and `PublicBalanceExactBurn`. Public methods select these modes; there is no exposed selector that accepts an arbitrary share owner or mode. The shared lock encloses validation involving external contracts, transfer checks, supply mutation, asset payment, and refunds. No user-directed call/delegatecall is added. Price-dependent public views reject reads during a locked settlement using the same lock's read guard; ordinary ERC20 balance/supply reads remain available to token settlement and ERC20 semantics.

## 4. Route behavior, errors, and precedence

### 4.1 Route table

| Public route | Common operation / share source |
|---|---|
| ERC4626 `deposit`, SE exact-in asset→share, SY deposit | Pull exact assets, mint calculated shares to receiver |
| ERC4626 `mint`, SE exact-out asset→share | Pull calculated assets, mint exact shares |
| ERC4626 `redeem`, SE exact-in share→asset, normal SY redeem | Burn exact owner/caller shares; pay calculated assets |
| ERC4626 `withdraw`, SE exact-out share→asset | Burn calculated owner/caller shares; pay exact assets |
| SE share→asset with pretransfer | Select `PublicBalanceRefundExcess` |
| SY internal-balance redeem | Select `PublicBalanceExactBurn` |

SE asset→asset, share→share, and every other token pair reject. SY accepts only the configured asset in each discovery list and money route. Nonzero `msg.value` rejects; no native-asset wrapping is added. A nonzero share receiver may be the vault, creating the documented public share balance. An asset payout receiver cannot be zero or the vault itself, because a self-transfer cannot satisfy delivered-output accounting.

For SE pretransfer withdrawals, snapshot `P = ERC20Repo.balanceOf(address(this))` before any external settlement. With burn `B`, require `B <= P`; for exact output also require `B <= maxAmountIn`. Burn B and refund exactly `P - B` wrapper shares to the initiating caller. Asset output goes to the requested recipient. Do not use `maxAmountIn - B` or refresh the refund budget after callbacks. In exact-input mode, B is the requested input. Shares arriving later remain in the public balance. Any failure rolls back asset transfer, burn, allowance changes, and refund together.

For internal SY, require the public balance covers the requested shares, burn that exact amount, and leave all excess untouched. Public shares have no cross-transaction attribution: a different caller can consume them. Document atomic transfer-plus-exit usage and test it explicitly. Backing tokens can never stand in for prepaid shares.

### 4.2 Error contract

Declare these new errors on `IRebasingAwareERC4626`:

```solidity
error ZeroOperationAmount();
error ZeroOperationOutput();
error AssetPretransferNotSupported();
error InvalidReceiver(address receiver);
error NativeValueNotSupported();
error ZeroReserveWithOutstandingShares();
error UnsupportedDecimalOffset(uint8 requestedOffset);
error UnsupportedDecimals(uint8 assetDecimals, uint8 effectiveOffset);
error NumericDomainExceeded();
error AssetSupplyChangedDuringTransfer(uint256 beforeSupply, uint256 afterSupply);
error AssetTransferMismatch(uint256 expected, uint256 debited, uint256 credited);
error InsufficientPretransferredShares(uint256 required, uint256 available);
error SYExchangeRateUnderflow();
```

If a measured balance moves in the wrong direction, report zero for that movement's nonnegative debit/credit in `AssetTransferMismatch`; never perform a reverting subtraction. Reuse canonical `InvalidRoute`, `DeadlineExceeded`, `MinAmountNotMet`, `MaxAmountExceeded`, `VaultDisabled`, and transition-quote errors. Retain canonical ERC20 allowance/balance, ERC4626 maximum, safe-transfer, and reentrancy failures where applicable. Do not replace all failures with an undifferentiated wrapper error.

Validation precedence for otherwise decoded calls is: shared lock; nonzero native value (payable SY); zero operation amount; token route; receiver; deadline (`block.timestamp == deadline` succeeds); asset-input pretransfer rejection; inbound disable; zero-reserve entry guard; numeric and conversion checks; zero computed output; slippage/max-input checks; share balance/allowance/payment checks; settlement delta checks; mint/burn/payment/refund completion and events. During transfer validation, supply-change failure precedes delta mismatch. Token-reported transfer failures retain safe-transfer behavior.

Amount-based conversion/preview calls return zero immediately for zero amount, including invalid token arguments. For positive amounts, validate route and numeric state; a rounded-zero result is returned as zero. Preview functions remain economic quotes and do not enforce caller balances, allowance, disable policy, or executable entry capacity. Transition snapshots are a separate stateful quote API: validate their encoded state even for zero transitions, then return unchanged state and zero amounts. No money execution succeeds with zero input or output; a zero slippage minimum is allowed.

### 4.3 SY compatibility methods

`yieldToken()` returns the asset; `assetInfo()` returns `(TOKEN, asset, capturedAssetDecimals)`. Both token discovery arrays contain only the asset. Validity checks are exact equality. Reward-token, accrued reward, and index arrays are empty. `claimRewards` emits the canonical empty reward event and returns an empty array; it neither transfers nor calls any underlying reward method. These empty compatibility methods are exempt from the zero-money-operation rule. Forced ETH and unrelated tokens have no public recovery route.

## 5. Sequential quote implementation

Use an ABI-encoded static `QuoteState` struct on the wrapper interface in this exact field order: `uint256 version`, `uint256 chainId`, `address exchange`, `address asset`, `address holder`, `uint256 assets`, `uint256 supply`, `uint256 holderShares`, `uint8 decimalOffset`. Version is 1; the encoded length is exactly 288 bytes.

`quoteState` supports the configured backing asset only. It snapshots the live coherent book and holder balance. A wrapper-share accounting alias is not added to pretend a share→share SE route exists. Validate state length and canonical word encoding before decoding so malformed payloads produce `InvalidQuoteState()`, not an accidental ABI panic. Validate version, chain ID, this vault, immutable asset/offset, numerical domain, and `holderShares <= supply`. A caller may fabricate a numerically valid hypothetical state; snapshots are projections, not authenticated payment evidence. Never consume them on execution paths or require their supply/backing to equal a later live book.

For every projection use only the input projected A/S/H, with the same conversion equations and no fees:

| Transition | State change |
|---|---|
| DepositExactIn(x) | q=floor conversion; A+=x, S+=q, H+=q |
| RedeemExactIn(q) | x=floor conversion; require q<=H and x<=A; A-=x, S-=q, H-=q |
| WithdrawExactOut(x) | q=ceil conversion; require q<=H and x<=A; A-=x, S-=q, H-=q |
| ReceiveShares(q) | Require H+q<=S; H+=q; A/S unchanged; input/output both q |
| External deposit(x) | Accept only tokenIn=asset; A+=x, S+=q, H unchanged |
| External exchange(q) | Accept only tokenIn=wrapper; require q<=S-H; A-=x, S-=q, H unchanged |

Return holder value from the resulting state using `floor(H*(A+1)/(S+V))`; value zero shares as zero. `quoteAssets` values the requested hypothetical shares from the snapshot, without mutating H or reading live reserves. `quoteShareBalance` returns H; `quoteTotalSupply` returns issued S, excluding virtual shares. Zero projected money amounts are no-ops after state validation. A positive deposit at A=0/S>0 rejects; positive rounded-zero previews remain zero without inventing executable value. Use `InsufficientQuoteShares` for unavailable holder/external shares and `InvalidQuoteState` for impossible resulting states.

Test multi-step projection against real execution restored to the same starting snapshot, including ReceiveShares and another actor's actions. A later rebase invalidates preview/execution equality but does not make the old numerical projection malformed. New snapshots must capture the new backing. Any rate provider used by an approved buffer binding must consume the projected state via `IStandardExchangeRateQuote`; falling back to a stale live wrapper rate for a sequential projection fails acceptance.

## 6. Registry, consumers, and deterministic identity

Implement `IStandardVaultPkg` on the package. Route package deployment through `IVaultRegistryDeployment.deployPkg` on the existing IndexedEx Manager, with its existing owner/operator authorization. Route both package `deployVault` helpers through that registry's `deployVault(address(this), encodedArgs)`. Registered packages already have the required deployment permission; do not add public registry bypasses or deploy vaults directly through the diamond factory from these helpers.

Initialize the vault's registry reference from the immutable package configuration. Each inbound mutation checks `IVaultRegistryDisableQuery(registry).isDisabled(address(this))`. Ordinary exits remain available when disabled, including pretransferred SE and internal SY exits. Test package-level and vault-level disable separately. Registry metadata includes zero fee type IDs; global, family, or vault fee changes cannot alter any wrapper money path.

Use release identifier `indexedex.rebasing-aware-erc4626.sy-se.v1`. For each changed/new facet and the package, derive the CREATE3 salt from `keccak256(abi.encode(releaseIdentifier, componentName, keccak256(creationCode), keccak256(initArgs)))`. Existing unchanged ERC20 facets are reused. Use the factory's established namespacing and prediction helpers; do not substitute bare predicted addresses. Verify initialized immutables and code identity as well as code presence before reuse. Changed facet/package code or constructor dependencies yield a distinct address; repeated identical input yields the same address.

Update these concrete consumers:

- `contracts/protocols/staking/token/TokenStaking_Component_FactoryService.sol`: wrapper helpers forward to the new wrapper FactoryService; package helper takes the registry dependency and does not directly CREATE3-deploy an unregistered package.
- `contracts/protocols/staking/token/TestBase_TokenStaking.sol`: create real registered package and facets, then use existing consumer paths.
- `test/foundry/spec/protocols/staking/token/TokenStaking_PonsUv4Detf.t.sol`: update constructor configuration and add registry assertions.
- `contracts/protocols/staking/token/TokenStakingTarget.sol`: preserve on-demand claim-vault creation and migration/withdrawal economics; establish sDETF settlement only in this aware consumer if existing acquisition does not already do so.
- Search all `IRebasingAwareERC4626DFPkg.PkgInit` and wrapper FactoryService calls again at implementation time; update any newly added caller under the same migration rules.

Existing deployed packages/diamonds remain untouched and retain their existing ERC4626-only interface. Keep the helper selectors and PkgArgs ABI; new PkgInit and new implementation identity are explicit release changes. Existing offsets above 18 are not redeployed as compatible new instances. Do not transfer user funds or rewrite historical manifests to simulate migration. Preserve a legacy deployment fixture/artifact before changes for coexistence testing.

## 7. Launch catalog and artifact changes

Update source only during implementation; running a deployment requires separate authorization.

| Existing source | Required change |
|---|---|
| `scripts/foundry/anvil_robinhood_main/Phase_06_Stage_10_RebasingAwareERC4626Pkg.sol` and `.s.sol` | Deploy/reuse all required facets and registered package; verify release identity and complete expected cuts before skipping. |
| `LaunchState.sol`, `LaunchIo.sol` in that directory | Record/load/export the four new facet addresses, release identifier, registry, constructor fingerprint, and implementation fingerprints. Preserve existing ERC4626 facet/package field names. |
| `Phase_06_Stage_08_TokenStakingPkg.sol` and `.s.sol` | Consume the same enhanced package, including optional-stage execution and resume paths. |
| `scripts/shell/lib/rh_4663_stages.sh`, `rh_4663_verify_inventory.py` | Retain default 06-10 independently of optional TokenStaking; enumerate and verify its complete deployment inventory. |
| `scripts/foundry/supersim/export_frontend_artifacts.py` and current Robinhood export consumers | Export complete overloaded ABI and capability/registry records; verify actual current export entrypoints before editing. |
| `docs/ANVIL_ROBINHOOD_MAIN_ARCHITECTURE_PHASE_STAGE_PRD.md` and stage quote/inventory documentation | Reflect additional facet/package transactions and registration; do not report unmeasured gas estimates as execution evidence. |

Old two-address ERC4626-only manifests fail enhanced-release freshness. Missing or mismatched fingerprints require the new release stage, preserving the old record as historical. Resuming 06-08 must not overwrite a current 06-10 package with the legacy package. Tests cover fresh, repeated, partial, stale, mismatched-registry, and wrong-facet resumes.

Reuse the existing CREATE3, diamond, hook, manager, and collector infrastructure. The previously discussed CREATE3 address is `0xD7786b10BC8Bc97dc7651CAb7B97086c8b227882`; this plan does not claim its registry authorization is valid. A later authorized fork rehearsal must verify that property and record any blocker rather than silently installing a replacement core. No broadcast, local-node state change, or mainnet deployment is part of writing this plan.

## 8. Buffer integration: mandatory design gate before delegation

### 8.1 Concrete conflict discovered in current source

The wrapper's approved SE routes are **raw rebasing asset ↔ static wrapper share**. Current buffer bindings distinguish `pairToken` from `standardExchange`; `UniswapV4SeBufferHookLegLib.addPairSe` explicitly rejects equality with `PairSeOverlap`. Binding the wrapper directly therefore selects its raw rebasing asset as the pair token. Repository token law and PRD §3.3 prohibit permitting raw rebasing assets as direct underlying tokens in unrelated SE/DETF products.

Simply setting pairToken=wrapper is not a working workaround: it conflicts with that binding rule and would require share→share operations, which API-04 rejects. Several buffer packages also limit token or SE decimals to 6–18, whereas the approved default wrapper shares have 19 or 28 decimals. For example, the CP package checks pair/raw decimals; other families have explicit SE-decimal configuration. Raising only a validation maximum is insufficient evidence of arithmetic compatibility.

Consequently, installing quote interfaces alone cannot satisfy D-06/API-16–18/F-16. The implementer must not introduce a raw-rebasing-token exception, add another wrapper silently, change share decimals, treat a rejected deployment as a passing integration test, or mark buffer tests optional.

### 8.2 Recommended resolution for owner review

Add an explicit **static wrapper-share inventory binding** to the in-scope V4 buffer design. Pool currencies and persistent balances use static wrapper shares. Direct receipt intake/return transfers existing shares without invoking a wrapper share→share SE route; actual raw asset wrapping/unwrapping occurs through the wrapper at an atomic boundary outside pool custody. Preserve all existing non-wrapper bindings and surrounding fee rules.

This is a proposal requiring a companion buffer design amendment before implementation. That amendment must specify the concrete PkgArgs discriminator and ABI order, classification when receipt and inventory addresses coincide, quote units, live/projected rate-provider units, decimal bounds and scaling equations, raw-asset routing and allowance cleanup, pool-settlement sequencing, and family-specific fees and rounding. It must explicitly resolve the current pair/SE disjoint-set rule and approve every affected family. Those choices cannot safely be inferred from the standalone wrapper PRD, and this document does not pretend they are resolved.

Until that amendment is reviewed, **do not delegate this complete implementation as execution-ready**. The wrapper implementation specification above is concrete; the full requested product still has this design dependency. This is a review gate for the owner/design stage, not a task instructing the implementer to choose a solution.

### 8.3 Family inventory and required integration evidence

Paths below are relative to `contracts/hooks/uniswap/v4/standardExchange/`. Use production packages and `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol` for applicable composed tests.

| Binding / package directory | Required disposition and tests |
|---|---|
| CP single: `constantProduct/single/` | First approved binding implementation; real wrapper receipt join, projected quote, swap, exit, DETF issuance/redemption, and composed invariant campaign. |
| Weighted: `weighted/` | Wrapper in each eligible leg, mixed wrapped/unwrapped static legs, 19-/28-decimal inventory, projected rates and sequential external deposits. |
| Orbital: `orbital/` | Each eligible SE leg, receipt routing, rate normalization, swaps and sequential exits. |
| Curve quad: `stable/quad/curve/` | Each eligible SE leg, stable-math scaling, receipt custody and coherent rates across rebase boundaries. |
| Balancer quad V4 hook: `stable/quad/balancer/` | Same wrapper evidence through this V4 hook; distinguish it from excluded Balancer-hosted DETFs. |
| Dual CP: `dual/` | Explicitly resolve wrapper receipt bindings for both legs and asymmetric rebases; standalone coverage if not wired to the current DETF factory. Do not claim DETF binding from standalone success. |
| Legacy single: `single/` | Preserve compile/existing regression coverage; no new claim that this legacy topology satisfies current DETF compatibility. |
| Balancer-hosted DETFs and unfinished Slipstream | Remain outside functional scope under D60/D66; compilation/shared compatibility maintenance only. |

For every approved row: test positive/negative rebase, external donation, zero reserve, stale quote, transfer-triggered settlement, disabled inbound/live exits, zero wrapper fees with nonzero outer fees, and rejected raw-asset pretransfer deposits. Record exact concrete package, TestBase, token roles, decimals, pool currencies, quote asset, rate provider, and selected routing mode in the companion amendment. No row may be silently omitted at handoff.

## 9. Implementation sequence and deliverables

Execute only after plan approval and closure of §8. Each work package includes tests; no code-only completion claims.

1. **WP-0 — Freeze specification and baseline.** Record approved PRD/plan revisions, the approved buffer amendment, dependency/compiler revisions, relevant preexisting failures, legacy artifacts, and touched-file status. Generate the expected public ABI matrix and requirement evidence template.
2. **WP-1 — Shared accounting.** Add interface errors/structs and Common; adapt ERC4626 and Repo. Implement bounded decimals, coherent settlement, zero rules, zero-reserve guard, and max views. Add independent-model functional and adversarial tests.
3. **WP-2 — SE and SY.** Add Targets/facets and route to Common. Add exact-in/out limits, caller/owner modes, SE refunds, SY internal burns, discovery, rate and empty rewards. Exercise every overload and cross-interface transition.
4. **WP-3 — Registry and packaging.** Add metadata facet, package declarations, FactoryService and six cuts; update all consumers, release salts, disable guards, coexistence and registry tests. Complete ABI/Target/facet/package/proxy checks.
5. **WP-4 — Projected quotes.** Add transition/external quote facet and tests using an independent projected ledger. Connect the approved rate-provider path; do not substitute live reads for projected state.
6. **WP-5 — Production integrations.** Complete real sDETF and TokenStaking scenarios. Implement the reviewed buffer amendment family by family, with successful end-to-end routes and the composed invariant campaign. This step cannot be skipped to ship the standalone wrapper.
7. **WP-6 — Catalog and documentation.** Update stage wiring, freshness, exports, quote inventory and integration documentation. Add deterministic source/harness tests without broadcasting to a node.
8. **WP-7 — Release validation.** Run the campaigns and regressions below; record runtime sizes, ABI evidence, commands, seeds, handler coverage and any failures. Deliver reviewable changes and a report; do not deploy.

## 10. Test files and requirement traceability

Create `contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol`, inheriting the existing IndexedEx production TestBase hierarchy. Deploy facets through CREATE3 FactoryService and package/vaults through the real manager registry. Never `new` a facet, package, manager, fee oracle, wrapper, or DETF SUT. Mintable/rebasing/taxed/callback underlying harnesses are permitted as external dependencies.

Place wrapper test files under `test/foundry/spec/protocols/staking/rebasingVault/`, with this naming and responsibility matrix. Every referenced PRD row requires named test cases and recorded evidence, not merely a filename.

| Test suffix after `RebasingAwareERC4626_` | PRD requirements |
|---|---|
| `Accounting.t.sol` | ACC-01–09; F-03–08, F-18–21; API-01/03/06; zero/one-unit, initial/residual state, full-precision and decimal boundaries |
| `StandardExchange.t.sol` | API-04–07/14–15; F-03/04/08/14/15/19/20; all four SE routes, exact limits, directional flags and event deltas |
| `StandardYield.t.sol` | API-08–15; F-09/18/19/21; all 16 SY selectors, rate boundaries, reward no-ops and internal balance semantics |
| `Packaging.t.sol` | API-02; PKG-01–04/06; F-01/02/12/13; selector matrix, registry, deployment prediction/replay, immutable configuration, legacy coexistence, fee updates and disable behavior |
| `TransitionQuote.t.sol` | API-16/17; F-17; ADV-15; malformed state, independent/external transitions, zero projections and live/projected isolation |
| `Adversarial.t.sol` | ADV-01–16 and F-14/15/18–21; canonical attack-ID mapping and atomic rollback |
| `Fuzz.t.sol` | FUZZ-01–13, each as a separately identifiable property; cross-interface snapshot replay and negative cases |
| `Invariant.t.sol` | INV-01–15; production two-vault handler, conservation and per-route coverage |
| `StakedDETF.t.sol` | F-10/18; ADV-04/11; funded production rewards, explicit settlement and mid-transfer rejection/retry |
| `TokenStaking.t.sol` | F-11; API-02; partial/full migration, on-demand registered claim vault, user withdrawals and synchronization |
| `Buffers.t.sol` / `BufferInvariant.t.sol` | API-16–18; F-16/17; ADV-15; FUZZ-11; INV-02/05/07/08/12 plus composed custody/supply accounting; all approved §8 bindings |
| `LaunchCompatibility.t.sol` | PKG-04–06; F-12; fresh/repeated/stale/partial stage records, unchanged legacy instances and complete exports |

Retain tests in existing consumer/family suites where their TestBases own the setup; wrapper suite entrypoints must run or reference those concrete cases in the evidence report. Do not replace existing tests with empty forwarding tests.

### 10.1 Functional matrix

Exercise all ERC4626, SE and SY operations from the same seeded states, restoring snapshots to compare different interfaces. Include distinct payer/receiver/owner, finite/infinite/insufficient approvals, exact/excess public shares, and asset/shares sent to the vault before the call. Cover offset requests 0/9/10/18/19/255 and asset decimals 0/6/8/9/18 plus the `77-d` boundary and one beyond. Underlying harness metadata tests do not require a protocol allowlist.

At a minimum, each money route gets zero input, positive input rounded to zero, one-unit successful operation, ordinary size, maximum boundary, failed transfer, and full rollback tests. Zero previews with invalid routes return zero per §4; positive invalid routes reject. Test min/max equality and one unit outside, and deadlines before/equal/after the current timestamp. Test one-argument helpers and custom names/salts as well as registry deployment.

Every SE asset-input pretransfer failure must be tested on an otherwise valid call to prove `AssetPretransferNotSupported()`, plus precedence combinations. Share-pretransfer success must compare B and P-B independently. Include callback-added shares and a rejected operation after the planned refund, proving no partial refund/payment. A failing callback/token must not leave the lock engaged.

### 10.2 Adversarial and independent arithmetic oracle

Map ADV-01–16 to the Crane/IndexedEx categories already enumerated in PRD §8. Required concrete attacks include first-depositor donation inflation, victim sandwich with attacker donation costs included, empty-supply residual capture, cyclic rounding, mid-call positive/negative rebase, short inbound/outbound token delivery, cross-interface reentry, unauthorized explicit-owner burns, public-share replay, callback share donations, cross-vault storage isolation, direct initialization, diamond-cut attempts, malicious quote payloads, rate underflow, and external fee-policy changes.

Do not assert that public unassigned shares are private property. Test their specified public consumption separately from forbidden external-holder theft. No arbitrary-router or permit surface is added; signature categories are inapplicable to this wrapper, with an explicit surface-based note. Existing signature/router behavior used in composed tests retains its applicable negative tests.

The reference model must not call Common, BetterMath conversion helpers, wrapper previews, or the same production conversion library to calculate expected results. Use bounded direct integer multiplication/division in the Solidity model where products provably fit; generate full-domain boundary vectors using a checked-in Python arbitrary-precision model. Commit vectors and their generator. Include quotients requiring 512-bit intermediate multiplication, exact divisibility and remainder-one cases. Compute ceiling with quotient/remainder, avoiding `numerator + denominator - 1` overflow.

Assert conservation and exact deltas, not only approximate prices. Economic exploit accounting includes all attacker-controlled accounts, their donations, and external rebase gains/losses. Derive the rounding residual per operation and reconcile it; do not grant an arbitrary percentage tolerance. Preserve every discovered counterexample as a named deterministic regression.

### 10.3 Stateful campaigns

Use three holders, an attacker, a separate receiver, and two real vault diamonds sharing production facets. Actions cover every public money route, share transfers/approvals, atomic SE prepayment/exit, atomic SY internal redemption, donation, positive/negative rebase, full reserve loss/restoration, funded sDETF settlement, time advance, disable/enable, fee updates and intentional invalid calls.

Maintain independent ghost balances, issued supply, authenticated inputs, payouts, donations, rebase deltas, vault-held public shares, refunds, and fee-recipient deltas. Virtual shares are pricing inputs only. Require INV-01–15 after every successful or intentionally reverted action. Model external rebase effects explicitly so funded yield is not mislabeled as profit.

Handlers record attempts, successes and expected reverts for each action. Expected reverts assert selectors and rollback; unexpected reverts fail the test. Use deterministic setup/bootstrap paths so every required successful route is reachable. Reject a campaign missing successful coverage of any supported route, loss/recovery or rebase transition. Do not use broad catch-and-ignore or constrain inputs until all adversarial cases disappear.

Run a separate composed campaign with the approved production buffer binding and real DETF. Reconcile backing, wrapper shares held in all locations, buffer shares and DETF claims without double-counting. Wrapper fee deltas stay zero while applicable outer fees remain active.

## 11. Validation commands and release evidence

After any production edits, run `forge build` before tests because FactoryServices load creation code from `out/`. Use the existing default profile, configured compiler/optimizer, and no `via_ir`. Seed `out/` and `cache_forge/` from a warm checkout before the first compile in a new worktree. Do not delete artifacts or abort a quiet compiler merely for elapsed time.

The following are planned commands, **not commands executed while writing this document**:

```bash
forge build
forge test --match-path 'test/foundry/spec/protocols/staking/rebasingVault/*.t.sol'
forge test --match-path 'test/foundry/spec/protocols/staking/token/*.t.sol'
forge test --match-path 'test/foundry/spec/vaults/standard/erc4626/*.t.sol'
forge test --match-path 'test/foundry/spec/vaults/standard/sy/*.t.sol'
```

Release minimums are 10,000 fuzz cases per property and 1,000 invariant runs at depth 100, each repeated for these three exact seeds:

```text
0x0000000000000000000000000000000000000000000000000000000000000001
0x0000000000000000000000000000000000000000000000000000000000000011
0x0000000000000000000000000000000000000000000000000000000000000101
```

For each seed, run the following with `REBASING_TEST_SEED` set to that value:

```bash
FOUNDRY_FUZZ_RUNS=10000 FOUNDRY_FUZZ_SEED="$REBASING_TEST_SEED" forge test --match-path 'test/foundry/spec/protocols/staking/rebasingVault/*Fuzz.t.sol'
FOUNDRY_FUZZ_SEED="$REBASING_TEST_SEED" FOUNDRY_INVARIANT_RUNS=1000 FOUNDRY_INVARIANT_DEPTH=100 FOUNDRY_INVARIANT_FAIL_ON_REVERT=true forge test --match-path 'test/foundry/spec/protocols/staking/rebasingVault/*Invariant.t.sol'
```

Capture effective `forge config --json` with the same overrides and verify the installed Foundry applies the intended seed/runs/depth; a silently ignored override is failed evidence. Do not change global smoke settings or add a package-specific profile. Expected-negative handler actions catch only their exact expected errors so `fail_on_revert=true` flags unexpected handler failures.

Run the existing hermetic production sDETF, TokenStaking, registry/disable, native SY, ERC4626 SE, and every modified buffer/DETF family regression suite. Finally run the full default hermetic suite (`forge test`) and report any independently reproduced baseline failures separately. No applicable new failure can be waived as baseline. Runtime size checks must cover each new/changed facet, package, linked deployment component and resulting diamond against **24,576 bytes** using the target settings; compiler-wide preexisting oversize artifacts do not excuse a feature artifact violation.

Write `REBASING_AWARE_ERC4626_SY_SE_VALIDATION.md` beside this plan at implementation completion. It must contain the approved revisions; ACC/API/PKG/F/ADV/FUZZ/INV/AC row-to-test mapping; ABI/loupe matrix; commands and effective configuration; three campaign seeds and handler counts; replayable regressions; production integration bindings; runtime byte counts; deployment/export compatibility evidence; and unresolved failures, if any. AC-01–10 pass only when their complete PRD evidence exists, including §8's approved buffer integration. A document, advertised interface, build success, or standalone test cannot substitute for that evidence.

## 12. Handoff conditions

Before delegation: owner reviews the engineering specification, approves the buffer amendment, and identifies the approved PRD/plan revisions. No implementation agent receives discretion to change fees, decimals, rewards, custody/refunds, zero behavior, settlement attribution, or required integration coverage. Any new conflict returns to the design/owner stage with the exact source and proposed amendment.

At completion: deliver source changes, tests, artifacts/exports changes, updated integration documentation, and the validation report. Do not claim production readiness while any required test, buffer binding, numeric limit, or runtime-size gate remains unresolved. Any later local Robinhood-fork rehearsal is a separate authorized action, records the then-latest fork block/hash and reused core addresses, and does not imply permission to deploy publicly.
