# Product Requirements Document (PRD)

## Title

DualLiquidityLinkedCrossVersionUniswapVault (Dual Liquidity Linked Cross-Version Uniswap Vault)

## Status

IMPLEMENTED — the family is built, tested, and green under `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/`. This PRD reflects the as-built design, including the direct Balancer V3 reserve integration (no external proportional-exit adapter or generic-router abstraction — see Reserve Integration).

## Purpose

Enable deployment of a vault that links the liquidity of two arbitrary ERC20 tokens ("linked tokens", `tokenA` and `tokenB`) that each have an existing Uniswap V4 market against a shared common token. The DETF composes three underlying vaults into a Balancer V3 Weighted Pool reserve and mints simple vault shares against that reserve. Deposits and swap routing drive buy pressure and liquidity into the linked tokens' markets.

This package is general-purpose. It must not reference any specific token launch. Any deployer can instantiate it for any token pair with existing common-token V4 markets.

## Naming Rule

Code uses role names only: `commonToken` (the asset shared by both V4 vaults), `tokenA`, `tokenB`. Concrete token names (WETH, RICH, RICHAI, etc.) MUST NOT appear in contract code, storage, interfaces, or NatSpec normative text. Deployment-specific identities live exclusively in deployment scripts/configs and non-normative docs.

## Scope

- Contracts implemented in `contracts/vaults/protocol/uniswap/crossVersion/`
- Fresh codepath per family convention: existing DETF families are behavioral references only, not implementation bases
- Reuses as-is: `UniswapV4StandardExchange*` vault stack (`contracts/protocols/dexes/uniswap/v4/`), Uniswap V2 strategy vault, Balancer V3 Weighted Pool integration, `StandardExchangeRateProviderDFPkg`, `DETFUsageFeeLib`, Vault Fee Oracle, Vault Registry, Crane deployment factories
- Target chain for first deployment: Base

## Reserve Topology

Three underlying vault legs composed into one Balancer V3 Weighted Pool (the "reserve"):

| Leg | Vault | Rate provider denomination |
|-----|-------|---------------------------|
| A | commonToken/tokenA Uniswap V4 Standard Exchange Vault | commonToken |
| B | commonToken/tokenB Uniswap V4 Standard Exchange Vault | commonToken |
| Pair | tokenA/tokenB Uniswap V2 strategy vault | tokenA |

- Weights configurable in package args; default **20 / 20 / 60** with 60 on the Pair leg
- The vault proxy holds only reserve BPT; shares are claims on that BPT
- All three rate providers are instances of the existing `StandardExchangeRateProviderDFPkg` (`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`), already used by the seigniorage and single-vault families

## Token Model

- The diamond proxy is the vault share token (Crane ERC20 facet stack; name/symbol per deployment)
- Simple share model: shares are minted/burned against reserve BPT value. No synthetic token, no rebasing token, no mint/burn threshold gating, no bond NFTs, no bridging
- Usage fee: applies to **every share-minting exchangeIn route** (including direct reserve-BPT and leg-vault-share deposits — no fee-free side door), taken as share inflation. Gross shares are computed, `DETFUsageFeeLib._splitUsageFee` (fee percentage from Vault Fee Oracle `usageFeeOfVault`) splits them; the fee slice is minted directly to the fee oracle's `feeTo()`, the depositor receives the remainder. Existing holders are never diluted; the depositor pays the fee
- Swap routes charge **no vault-level fee**: free aggregation to maximize volume routed through the legs (which carry their own fees). The swap surface is a volume driver, not a revenue line
- No bonding/underwriting machinery of any kind

## Governance and Immutability

The deployed DETF is **immutable and unowned**: no owner facet, no facet upgrades after deployment, no operational open/close toggles, no pause. Consequences:

- The DFPkg must not install ownership or diamond-cut facets; the facet set is final at deploy time
- There is no emergency stop and no recourse for bugs in a deployed instance — correctness burden falls entirely on pre-deployment testing and review
- The only mutable parameters are external: the Vault Fee Oracle (governed by its own owner) controls `usageFeeOfVault` and `feeTo()`. The DETF's reference to the oracle is fixed; the oracle's values are not
- A flawed deployment is abandoned, not fixed; the package can be redeployed with corrections as a new instance

## Pricing and Share Math

- `sharesMinted = bptIn × totalShares / totalBPT`; inverse proportion for burns. Dust-init supply at deploy prevents first-depositor share-price manipulation
- Quoting is delegated, not recomputed: candidate routes are quoted through the underlying vaults' own `IStandardExchangeIn.previewExchangeIn` / `IStandardExchangeOut.previewExchangeOut` surfaces plus Balancer `BasePoolMath` quotes (`computeAddLiquidityUnbalanced`, `computeAddLiquiditySingleTokenExactOut`, `computeProportionalAmountsOut`) evaluated against live Vault state for Weighted Pool joins/exits. The DETF never reimplements underlying vault or pool math; its only owned math is the share↔BPT proportion and the fee split
- Rate providers price vault shares inside the Weighted Pool per the Reserve Topology table

## Reserve Integration

The reserve Weighted Pool is integrated **directly into the vault** — there is no separate proportional-exit adapter and no generic-router indirection. All reserve liquidity operations reuse the existing shared plumbing already used by the other DETF families:

- **Dependency resolution via aware repos.** The Balancer V3 Standard-Exchange router and the Balancer V3 Vault are read at call time from `BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter()` and `BalancerV3VaultAwareRepo._balancerV3Vault()`. They are **not** stored in the vault's own Repo struct; the DFPkg initializes both aware-repo slots from its `BALANCER_V3_ROUTER` / `BALANCER_V3_VAULT` immutables at deploy time.
- **Pool identity in DETF storage.** The Repo holds the reserve pool + BPT and the three tokens' **registration indices** (`indexA`, `indexB`, `indexPair`) so amounts can be mapped between DETF order `[A, B, pair]` and the pool's registration order. No router or Permit2 handle lives in DETF storage.
- **Joins (BPT mint).** Single-leg and multi-leg adds pre-transfer the vault-share token(s) to the Balancer Vault and settle through the router's `prepayAddLiquidityUnbalanced` (the seigniorage funding pattern — the Vault credits tokens already received). The exact-out variant sizes the input with `BasePoolMath.computeAddLiquiditySingleTokenExactOut`, rounds up, and adds via the same unbalanced path; any excess BPT accrues to the reserve.
- **Exits (BPT burn).** Redemption `forceApprove`s the router on the BPT and calls `prepayRemoveLiquidityProportional`; the raw per-registration-index amounts are reordered back to DETF order.
- **Quoting.** Every join/exit has a pure-view mirror computed with `BasePoolMath` (`computeAddLiquidityUnbalanced`, `computeAddLiquiditySingleTokenExactOut`, `computeProportionalAmountsOut`) over live Vault state (`getCurrentLiveBalances`, `getStaticSwapFeePercentage`, BPT `totalSupply`) and the pool's own `IBasePool` invariant callback. This keeps `previewExchange* == exchange*` exact without the vault reimplementing Weighted-Pool math.

Because the 3-token reserve is a generic n-token weighted pool, quoting uses the generic `BasePoolMath` (with the `IBasePool` callback), not the 2-token 80/20 fast path.

### No bespoke interface — config via the standard vault surface

There is **no** `IDualLiquidityLinkedCrossVersionUniswapVault` interface. The deployed diamond is introspected through the standard vault surface it already implements: `IBasicVault.vaultTokens()` returns `[self, vaultA, vaultB, pairVault, reservePool]` (the reserve pool is the entry that is a registered 3-token Balancer pool), and `totalReserveBpt` is simply the proxy's BPT balance (`IERC20(reservePool).balanceOf(detf)`). The family's route/guard errors (`UnsupportedRoute`, `ZeroAmount`, `DeadlineExpired`, `ReservePoolNotInitialized`, `ResidualInventory`) live in the `DualLiquidityLinkedCrossVersionUniswapVaultRepo` library. The USAGE fee type is tagged by `type(IStandardExchangeIn).interfaceId`.

## Bootstrap

No bootstrap event and no treasury capital raise. Both linked-token V4 markets are assumed to already hold locked liquidity.

**Deploy is inert; the reserve is bootstrapped by a manual post-deploy procedure (not inside the DFPkg).** At deploy the package creates the Weighted Pool but does not initialize it and mints **no** shares — so `totalSupply()` and `totalReserveBpt()` are both `0`, and every non-bootstrap route reverts `ReservePoolNotInitialized` until the deployer bootstraps. The bootstrap, run once by the deployer, is a sequence of real operations:

1. Deposit into each Uniswap V4 leg (commonToken/tokenA, commonToken/tokenB) to obtain vaultAShare and vaultBShare, and zap the Uniswap V2 pair leg (tokenA) to obtain pairVaultShare.
2. Initialize the Weighted Pool with the three leg shares (via the Balancer router) to obtain reserve BPT. Balancer locks its own minimum liquidity at pool initialization.
3. Deposit the BPT into the vault (`exchangeIn` BPT → shares). This is the **first** deposit and mints **1:1** against the empty vault (`shares = bptIn`), making the vault live.

**No dust pre-mint and no vault-level minimum-liquidity lock** (Balancer's pool-level lock suffices; the deployer is the first depositor and bootstraps its own launch). The share math (`DualLiquidityLinkedCrossVersionUniswapVaultMathLib._sharesForBpt`) returns `bptIn` 1:1 when `totalSupply == 0 || totalReserveBpt == 0`. The liveness gate is split: `_requireActive` (deadline + non-zero amount) is universal, while `_requireReserveLive` (reserve BPT > 0) guards every route **except** the initializing reserve-BPT → shares deposit into an empty vault. Reserve depth then grows organically from deposits.

## Route Table

Route-selection principle: where multiple candidate routes exist, quote each candidate end-to-end and execute the one that maximizes output (for deposits: final reserve BPT received, equivalently shares minted). Every route has a paired preview query with preview/execution symmetry.

### exchangeIn (deposits → vault shares)

| tokenIn | Route |
|---------|-------|
| Reserve BPT | Process BPT into the reserve directly; mint shares against BPT value. No routing, no market impact. |
| commonToken | Swap the common token for tokenA or tokenB — whichever is cheaper (operationalized as: the candidate purchase whose downstream route yields the most BPT). Deposit the purchased tokens into the Pair (V2) vault. Deposit the resulting V2 vault shares into the Weighted Pool; mint shares from BPT received. |
| tokenA or tokenB | Deposit the token into its respective commonToken V4 vault OR into the Pair (V2) vault — whichever produces the most resulting vault-share value (operationalized as: max BPT after the Weighted Pool join). Deposit the winning vault shares into the Weighted Pool; mint shares from BPT received. |
| Leg vault shares (A, B, or Pair) | Deposit the vault shares into the Weighted Pool (single-sided join); mint vault shares for the BPT received. |

### Swap routes (token ↔ token, no share mint/burn)

The DETF also exposes exchange routes between its constituent assets, routed through its legs. These act as an aggregator over the leg vaults and drive volume through them.

| Route | Definition |
|-------|-----------|
| tokenA ↔ tokenB | Quote both candidates — through the respective commonToken V4 vaults (two hops via the common token) and through the Pair (V2) vault (direct) — and execute whichever returns the most output. |
| commonToken ↔ tokenA or tokenB | Route through that token's respective commonToken V4 vault; quote via the vault's preview for the return. |

### Redemption routes (vault shares → assets)

All redemption routes support **both styles**: exact-in (specify shares to burn, receive route output, guarded by `minAmountOut`) and exact-out (specify the asset amount wanted; the vault computes and burns the needed shares, guarded by `maxSharesIn`, refunding unused shares). Route definitions below are written exact-in; the exact-out variant inverts the same path via the legs' preview surfaces.

| tokenOut | Route |
|----------|-------|
| Reserve BPT | Burn shares for the BPT due. Direct redemption, no routing, no market impact. **Canonical full-value exit.** |
| Leg vault shares (A, B, or Pair) | Calculate BPT due for the shares being burned; execute a proportional Weighted Pool withdrawal of that BPT into the three vault-share tokens; send the requested vault token to the user; redeposit the remaining vault tokens into the Weighted Pool. |
| commonToken / tokenA / tokenB | Burn vault shares for the BPT due; execute a proportional Weighted Pool withdrawal into the three vault-share tokens; redeem the leg vault whose redemption provides the greatest return in the requested asset (quoted via the vaults' `previewExchangeOut`); send proceeds to the user; redeposit the remaining two legs' vault shares into the Weighted Pool. |

### Redemption accounting (resolved)

For both redeposit-pattern payout routes: **the redeposited BPT accrues to the reserve.** The exiting user receives only the redeemed leg's slice of the proportional exit; the re-minted BPT from the remaining legs enriches remaining shareholders. This is a deliberate product decision with these required consequences:

- These payout routes carry a large implicit exit cost (at default 20/20/60 weights: a commonToken payout via a 20-weight leg returns roughly one fifth of the burned share value). They are convenience/volume routes, not fair-value exits.
- **Shares → Reserve BPT is the canonical full-value exit** and must be documented as such everywhere the vault is surfaced (NatSpec, frontend, docs).
- `previewExchangeOut` for these routes MUST return the actual payout the user will receive, so the cost is visible before execution. No route may obscure the difference between burned value and payout value.
- Every such exit is a positive rebase for remaining holders (including `feeTo()`'s accrued fee shares), which strengthens the hold incentive and should be described in the product story rather than left implicit.

## Guards and Failure Policy

- Deadline checks on all state-mutating routes
- Caller slippage bounds: `minSharesOut` on deposits; `minAmountOut` on swaps and redemptions; refund of unused input where applicable
- Zero-amount rejection; unsupported token-in/token-out rejection
- Revert before quoting or execution when the reserve Weighted Pool is uninitialized
- Residual-inventory rejection: no route may leave vault tokens or intermediate assets stranded on the proxy after execution
- Reentrancy protection via Crane lock modifiers
- The Balancer V3 Standard-Exchange router and Vault are runtime dependencies resolved through aware repos (see Reserve Integration), wired by the DFPkg — not hidden or per-call router state. Permit2 is a router-level funding dependency of the underlying leg vaults, not a DETF Repo field

## Architecture / Components

Family follows Repo / Common / Target / Facet / DFPkg / FactoryService conventions:

- `DualLiquidityLinkedCrossVersionUniswapVaultRepo` — storage: commonToken/tokenA/tokenB, the three leg vaults and their share tokens, reserve pool + BPT, the reserve tokens' registration indices (`indexA`/`indexB`/`indexPair`), and the fee oracle. The Balancer router and Vault are **not** stored here — they resolve through aware repos (see Reserve Integration)
- `DualLiquidityLinkedCrossVersionUniswapVaultCommon` — share/BPT math, fee split, direct reserve join/exit helpers (aware-repo router + Vault, `prepay*` ops), and `BasePoolMath` preview mirrors
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet` / `...ExchangeOutFacet` — state-mutating routes (deposits, swaps, redemptions)
- Paired query facets — `previewExchangeIn` / `previewExchangeOut`
- Crane ERC20 facet stack — DETF share token surface
- `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg` + factory services — deploys the leg vaults and the Weighted Pool itself, initializes the Standard-Exchange router / Balancer Vault aware-repo slots, dust-initializes the pool, and deploys the vault through the Vault Registry

## Package Args (deploy-time configuration)

- commonToken, tokenA, tokenB addresses
- The three leg vaults, or configuration sufficient to deploy them
- Weighted Pool weights (default 20/20/60)
- Vault Fee Oracle; Balancer V3 Standard-Exchange router and Balancer V3 Vault (wired into their aware-repo slots by the DFPkg)
- Share token name/symbol

## Testing

Suite under `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/`, following Crane `TestBase_` / `Behavior_` conventions:

- Component specs per facet: every route's preview/execution symmetry (preview equals execution result within rounding); guard reverts (deadline, slippage, zero-amount, unsupported token, uninitialized reserve, residual inventory)
- Fee accounting: inflation split correctness, `feeTo()` accrual, no dilution of existing holders on deposit
- Route selection: quoted-best-route actually executes; fuzz pool imbalances so each candidate wins in some states
- Redemption accounting: reserve accrual on redeposit routes is exact; shares→BPT round-trips at full value
- Both redemption styles: exact-in and exact-out variants per route, including exact-out share-burn computation and unused-share refunds
- Package deploy spec: DFPkg wiring, dust init, registry/fee-oracle registration; immutability verification (no ownership or diamond-cut facets installed, facet set final)
- Fuzz/invariant: deposit-withdraw round trips never mint value from nothing; totalBPT backing ≥ share claims after any operation sequence; reserve BPT-per-share is exactly monotonic non-decreasing (zero-tolerance cross-multiplied check)
- Adversarial: reentrancy — a hostile `tokenB` re-entering `exchangeIn`/`exchangeOut` via its `transferFrom` hook is rejected with `IsLocked` (including cross-function attempts, since both facets share one lock slot); share-inflation / first-depositor — the genesis dust bootstrap leaves no empty-vault window, a BPT donation cannot round a victim's deposit to zero or steal it, and front-running donation is a net loss

## First Deployment Context (non-normative)

The first deployment links, against WETH as commonToken on Base:

- tokenA = **RICH** — a new static-supply ERC20 (Crane token packages) superseding the Protocol DETF's RICH token, distributed via a Uniswap Continuous Clearing Auction using the Crane-vendored `ContinuousClearingAuctionFactory`
- tokenB = **RICHAI** — a Bankr-launched community token (100B fixed supply, Uniswap V4 pool on Base)

Launch deliverables outside this package: RICH token deployment, CCA auction deployment, purchasing RICHAI from its V4 market and seeding the RICH/RICHAI Uniswap V2 pair with initial liquidity (setting its starting price — required before the vault deploys, since the V2 vault's zap deposits need existing pair liquidity), and deployment scripts wiring tokens, vaults, and the vault package on Base. Per the Naming Rule, none of these identities appear in package code.

## Open Items

1. RESOLVED (code-level) — third-party LP fee accrual verified against Doppler source (`whetstoneresearch/doppler`):
   - **Doppler-migrated V4 pools (Bankr):** neither hook generation gates liquidity (`beforeAddLiquidity: false` in both `DopplerHookMigrator` and legacy `UniswapV4MigratorSplitHook`), so third parties can LP permissionlessly, and LP fees accrue pro-rata to all in-range positions per standard V4 mechanics. The advertised 95/5 creator/protocol split applies only to fees earned by the migrated positions locked in `StreamableFeesLocker(V2)` — it does not touch other LPs' fees. Caveat (current generation only): an optional governance-enabled `dopplerHook` (e.g. Rehype) can take an extra after-swap fee from **traders** via return delta and can update a dynamic LP fee — this taxes volume, not LP positions, but affects pool economics.
   - **CCA-seeded pools:** the vendored CCA contracts do not create or hook a pool; `sweepCurrency()`/`sweepUnsoldTokens()` send proceeds to configured recipients and pool seeding is the deployer's own step — so the tokenA pool is a standard hookless V4 pool under our control.
   - RESIDUAL launch-time check: inspect the live RICHAI pool's actual config once launched (migrator generation, static vs dynamic fee, whether a `dopplerHook` is attached) before finalizing leg B's yield assumptions.
2. RESOLVED — the Uniswap V2 strategy vault supports single-token zap deposits, **provided the pair already has liquidity**. Consequence: the tokenA/tokenB V2 pair must be seeded with initial liquidity (establishing its price) before the vault deploys; this is a deployment prerequisite, not package code.

## Known Issues (found by real-code testing)

1. **RESOLVED — residual dust on real pricing swept to `feeTo()`.** On real Uniswap V4/V2 + Balancer pricing, the multi-hop linked-token / common-token deposit routes leave dust-level remainders (~1e14–1e15 wei) of an intermediate token on the proxy; the mocks' fixed exact rates never produced dust, hiding this. Every route now ends by sweeping any grown intermediate balance to the fee oracle's `feeTo()` (`DualLiquidityLinkedCrossVersionUniswapVaultCommon._sweepResidual`) instead of reverting. Dust is **not** refunded to the caller — the caller may be a contract that cannot process a partial refund. Minted shares / payouts are unaffected (dust is never part of the reserve BPT), so preview/execution symmetry stays exact.

## Implementation Progress Checklist

Contract implementation & core design — DONE:
- [x] PRD route table, redemption accounting (reserve accrual), rate-provider reuse
- [x] Math lib, Repo, Common, deposit / swap / exact-in redemption / exact-out routes
- [x] Direct Balancer V3 reserve integration (aware repos + `prepay*` + `BasePoolMath`)
- [x] DFPkg + integrated deploy through the Vault Registry
- [x] **Reentrancy guard** (`nonReentrant` on `exchangeIn`/`exchangeOut`); **zero-tolerance accrual invariant**
- [x] **Bespoke `IDualLiquidityLinkedCrossVersionUniswapVault` interface removed** — errors in `DualLiquidityLinkedCrossVersionUniswapVaultRepo`, config via `IBasicVault`/`IStandardVault`, USAGE fee tag = `IStandardExchangeIn`
- [x] **Inert deploy (`totalSupply == 0`, no dust pre-mint) + 1:1 first-deposit bootstrap**; split liveness gate
- [x] Real-code deployment + manual bootstrap proven end-to-end (real V4/V2/Balancer legs, real `ERC20PermitDFPkg` role tokens)

Test de-mock (in progress — see the plan's Status Update for details):
- [x] Remove protocol mocks from deploy/bootstrap path; delete `MockVaultFeeOracle`, mock `TestBase`/harness (`MockStandardExchange` kept — shared by other families)
- [x] `ProductionDeploy`, `DFPkg_Registry`, `MathLib`, `BootstrapDeposit` suites green over real code
- [x] Extract abstract `DualLiquidityLinkedCrossVersionUniswapVaultProductionBase` (setup + helpers, no tests)
- [x] Residual dust swept to `feeTo()` (Known Issue #1 resolved)
- [x] Deposits suite rebuilt on the real base (7/7)
- [x] Rebuild remaining suites on the real base: Swaps, Redemptions, ExactOut, Fees, Invariant, ShareInflation, Reentrancy
- [x] Fork tests against real Balancer/Uniswap on Base + production SE router (no VaultMock/RouterMock)
- [x] Tighten WITH_RATE proportional-exit / join previews (live scaled18 ↔ raw via ScalingHelpers + `getPoolTokenRates`); BPT + leg-share + vault-share paths assert exact preview == execution
- [x] Mint-from-actual BPT on deposits (pre-join snapshot) so optimistic join quotes cannot dilute existing holders
- [x] Redeposit remainder policy: quote multi-join first; hard-join on positive BPT (atomic revert on failure); refund remainder leg shares to redeemer when join would mint 0 BPT (no silent strand on Balancer vault)
- [ ] Multi-hop deposit / commonToken asset-redeem previews remain sub-bps indicative (post-hop rate-provider update + SE vault hop math); clients should set minAmountOut with a small buffer on those routes
- [ ] Independent audit (immutable, unowned); launch deploy scripts
