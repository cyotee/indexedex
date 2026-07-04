# SingleStandardExchangeDETF — Implementation and Testing Plan

## Purpose

Execute the [PRD](./SingleStandardExchangeDETF_PRD.md): implement a brand-agnostic Single Standard Exchange DETF, and prove it works against **any** Standard Exchange–compatible vault, including existing protocol vaults and other DETFs that expose the Standard Exchange surface.

This plan is ordered for incremental delivery: each phase leaves a green, reviewable slice.

## Status

**IMPLEMENTED** — production package + equal-priority matrix green: Aerodrome SE (local), DualLiquidity (fork), Uni V4 SE (fork), ComposedStable (local; abstract 1:1 when rate not quotable).

### Locked decisions (summary)

| Topic | Decision |
|-------|----------|
| Weights | Default **80 DETF / 20 vault share**, overridable |
| Threshold gate | **Synthetic** (fully diluted) price |
| Bonding v1 | **Full bond NFT vault** (user + protocol + feeTo NFTs) |
| Bootstrap | **Inert deploy**; **first bond** with SE vault token opens live market |
| tokenIn discovery | **`IBasicVault.vaultTokens()` allowlist** |
| `rateTarget` | **Explicit PkgArg** |
| Deploy path | **Vault Registry / manager** |
| Governance | **Immutable, unowned** |
| Tests | Production only; **equal priority** across Uni V4 (or peer protocol SE), DualLiquidity, ComposedStable |
| Reentrancy harness | Purpose-built attacker contract OK |
| Default thresholds | **mint 1.05e18 / burn 0.95e18** (±5% synthetic deadband); PkgArgs-overridable |
| Synthetic peg | **1e18** abstract (rateTarget-denominated fully diluted value / supply); no oracle |
| First-bond bootstrap | Mint **DETF self-leg into pool** + **join vault shares**; bond NFT gets position; then live |
| Bond lock / terms | Oracle `bondTermsOfVault(this)`; **revert if &lt; min**; **clamp to max** if longer (bonus as at max); bonus via `DETFBondNFTMathLib` curve |

---

## 1. Goals and non-goals

### Goals

1. Implement `SingleStandardExchangeDETF` under `contracts/vaults/detf/standardExchange/single/` per the PRD.
2. Prove **interface opacity**: the DETF only talks to `IStandardExchange` / share ERC-20; no underlying-market knowledge.
3. Prove **composition**: attach diverse Standard Exchange vaults (DEX, lending, and DETF-as-vault).
4. Leave a **matrix-ready** test harness so future Standard Exchange vaults and DETFs plug in with a thin adapter TestBase, not a rewrite.

### Non-goals (this plan)

- Implementing multi-vault stable/common topology here (that remains `composed/stable/common`).
- Rebasing secondary token (v2).
- Production mainnet deploy scripts (follow-up after green integration).
- Fixing unrelated debt in peer DETF families unless it blocks this package’s tests.
- **Mocks / stubs / fake Standard Exchange vaults** — forbidden for this family (see §4.0).

---

## 2. Naming and layout

### Source

```text
contracts/vaults/detf/standardExchange/single/
  SingleStandardExchangeDETF_PRD.md                          # normative product
  SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
  SingleStandardExchangeDETFRepo.sol
  SingleStandardExchangeDETFCommon.sol
  SingleStandardExchangeDETFExchangeInTarget.sol
  SingleStandardExchangeDETFExchangeInFacet.sol
  SingleStandardExchangeDETFExchangeInQueryTarget.sol
  SingleStandardExchangeDETFExchangeInQueryFacet.sol
  SingleStandardExchangeDETFExchangeOutTarget.sol
  SingleStandardExchangeDETFExchangeOutFacet.sol
  SingleStandardExchangeDETFExchangeOutQueryTarget.sol   # if exact-out query split
  SingleStandardExchangeDETFExchangeOutQueryFacet.sol
  SingleStandardExchangeDETFBondingTarget.sol
  SingleStandardExchangeDETFBondingFacet.sol
  SingleStandardExchangeDETFInfoTarget.sol
  SingleStandardExchangeDETFInfoFacet.sol
  SingleStandardExchangeDETDFPkg.sol                     # PkgInit/PkgArgs in interface
  SingleStandardExchangeDETF_Facet_FactoryService.sol
  SingleStandardExchangeDETF_Pkg_FactoryService.sol
  SingleStandardExchangeDETF_Component_FactoryService.sol
  interfaces/ISingleStandardExchangeDETF.sol             # optional slim info surface
  interfaces/ISingleStandardExchangeDETDFPkg.sol         # PkgInit / PkgArgs only
```

**Type names:** always full **Standard Exchange** (never `SE` in contract/library/file names).  
**Variables:** `seVault_`, `seShare_`, etc. allowed.  
**No** product tickers in code.

### Tests

```text
# Harness / matrix adapters (prefer next to family or under contracts/test/bases/)
contracts/vaults/detf/standardExchange/single/
  TestBase_SingleStandardExchangeDETF.sol                 # abstract: DETF under test + seVault hook
  TestBase_SingleStandardExchangeDETF_Components.sol      # facets/pkg only if needed

# Spec (unit / local / lightly forked) — matrix providers
test/foundry/spec/vaults/detf/standardExchange/single/
  matrix/
    IStandardExchangeVaultProvider.sol                    # interface for adapters
    providers/                                            # one file per attached vault family
  SingleStandardExchangeDETF_Deploy.t.sol
  SingleStandardExchangeDETF_Mint.t.sol
  SingleStandardExchangeDETF_Burn.t.sol
  SingleStandardExchangeDETF_Passthrough.t.sol
  SingleStandardExchangeDETF_Bonding.t.sol
  SingleStandardExchangeDETF_Pricing.t.sol
  SingleStandardExchangeDETF_Guards.t.sol
  SingleStandardExchangeDETF_Invariants.t.sol
  SingleStandardExchangeDETF_NestedDetf.t.sol             # DETF-as-seVault
  SingleStandardExchangeDETF_Matrix_*.t.sol               # or parameterized suite runner

# Fork (live protocols on Base) — heavier legs
test/foundry/fork/base_main/vaults/detf/standardExchange/single/
  TestBase_SingleStandardExchangeDETF_BaseFork.sol
  ... suites as needed for Uni V4 / Aerodrome / Aave / dual-liquidity legs
```

Use `FOUNDRY_PROFILE=fork` + `FOUNDRY_TEST=.../standardExchange/single` for fork isolation (same pattern as cross-version).

---

## 3. Standard Exchange inventory (current)

These are **attachment candidates** for the DETF’s `standardExchangeVault` slot. The DETF code must not import their concrete types—only test adapters may.

### 3.1 Protocol Standard Exchange vaults (DEX / lending)

| Family | Location (indicative) | TestBase | Notes |
|--------|----------------------|----------|--------|
| Uniswap V4 | `contracts/protocols/dexes/uniswap/v4/` | `TestBase_UniswapV4StandardExchange` | Primary liquid Base fork candidate |
| Uniswap V2 | `contracts/protocols/dexes/uniswap/v2/` | `TestBase_UniswapV2StandardExchange` | Simpler pair vault |
| Camelot V2 | `contracts/protocols/dexes/camelot/v2/` | `TestBase_CamelotV2StandardExchange` | Arbitrum-oriented; use if chain profile allows |
| Aerodrome V1 | `contracts/protocols/dexes/aerodrome/v1/` | `TestBase_AerodromeStandardExchange` | Base fork |
| Aerodrome Slipstream | `contracts/protocols/dexes/aerodrome/slipstream/` | `TestBase_SlipstreamStandardExchange` | Base CL |
| Aave V3 Stata | `contracts/protocols/lending/aave/v3.6/` | `TestBase_AaveV3StataStandardExchange` | ERC-4626-style stata as SE vault |
| Balancer V3 SE router vaults | protocol balancer stacks | existing SE router TestBases | Where a vault diamond is SE-compatible |

### 3.2 DETF / vault products that expose Standard Exchange (nesting)

| Family | Location | Role in matrix |
|--------|----------|----------------|
| **DualLiquidityLinkedCrossVersionUniswapVault** | `contracts/vaults/protocol/uniswap/crossVersion/` | **Primary nested “just shipped” DETF-like SE vault** (simple shares + full SE surface) |
| **ComposedStableCommonDetf** | `contracts/vaults/detf/composed/stable/common/` | Nested DETF attachment (mint/burn through composed stack) |
| **SingleVaultDetf** | `contracts/vaults/detf/composed/single/` | Nested reference; brand-specific names stay **inside that family only**—adapter maps to role tokens for outer DETF tests |
| **Seigniorage DETF** | `contracts/vaults/seigniorage/` | Optional matrix row if SE surface is complete |
| Protocol DETF proxies | `IProtocolDETFProxy` / protocol stack | Optional; only if SE In/Out fully usable without brand assumptions in **this** family’s production code |

### 3.3 Future inventory rule

When a new Standard Exchange–compatible vault or DETF ships:

1. Add a **provider adapter** under `test/.../matrix/providers/` that deploys **production** packages only.
2. Register it in the matrix table (this section + checklist below).
3. Run the shared suite against that provider (spec and/or fork as appropriate).
4. Do **not** change `SingleStandardExchangeDETF` production code for the new underlying.
5. Do **not** introduce a mock “stand-in” for the new vault.

---

## 4. Testing architecture

### 4.0 Production code only — no mocks

**Hard rule (aligns with PRD and dual-liquidity demock discipline):**

- Do **not** use `MockStandardExchange`, protocol mocks, or hand-rolled fake vaults/stubs for DETF lifecycle or integration tests.
- Every suite that mints, burns, bonds, or bootstraps the DETF attaches a **production** Standard Exchange vault (protocol SE DFPkg instance, dual-liquidity cross-version vault, composed stable DETF, etc.).
- Pure-function tests of shared `detf/core` math (if any stay local) use pure numeric inputs only—not a mock vault.
- Role ERC-20s come from production token packages / peer TestBase funding patterns (CREATE3 ERC-20 packages, fork whales), not mock ERC-20s that pretend to be Standard Exchange vaults.
- Forbidden imports in this family’s tests for vault behavior: `contracts/test/stubs/MockStandardExchange.sol` and any new mock SE invented “to go faster.”

### 4.1 Provider interface (matrix adapter)

Define a small Solidity (or abstract TestBase) contract that each attachment implements:

```solidity
/// @dev Test-only. Production DETF never sees this interface.
interface IStandardExchangeVaultProvider {
    /// Deploy or bind a live Standard Exchange vault + its share token and a rateTarget
    /// the rate provider should use for the outer DETF reserve.
    function provideStandardExchangeVault()
        external
        returns (
            IStandardExchangeProxy seVault,
            IERC20 seShare,
            IERC20 rateTarget
        );

    /// Fund `to` with `amount` of a token the SE vault accepts for minting shares
    /// (provider-specific; outer suite only calls this hook).
    function fundForShareMint(address to, uint256 amount) external;

    /// Human label for logs (e.g. "UniswapV4", "DualLiquidityCrossVersion", "ComposedStable").
    function providerLabel() external pure returns (string memory);
}
```

Optional hooks as needed: `acquireVaultShares(to, amount)`, `supportedPassthroughPair()`, `isForkOnly()`.

### 4.2 Core TestBase

`TestBase_SingleStandardExchangeDETF`:

1. Extends `IndexedexTest` / `TestBase_VaultComponents` / Crane factories as required.
2. Calls abstract/virtual `provideStandardExchangeVault()` (or composes a provider).
3. Deploys rate provider for `(seShare, rateTarget)`.
4. Deploys `SingleStandardExchangeDETDFPkg` and instance via manager registry path.
5. Deploys outer DETF **inert**; exposes `_bootstrapViaFirstBond` (acquire se shares via production vault → first bond → live).
6. Exposes helpers: `_mintDetfFromVaultShares`, `_burnDetfToVaultShares`, `_assertNoResidualInventory`, `_syntheticPrice`, `_bptPerDetfSupply`.

Concrete matrix suites inherit TestBase + one provider mixin. **No single preferred provider** — Uni V4 (or Uni V2 where local), DualLiquidity, and ComposedStable are **equal-priority** integration rows.

### 4.3 Suite layers

| Layer | What | When |
|-------|------|------|
| **L0 Pure math** | `detf/core` helpers (threshold, mint split, scale) with pure inputs only—**no vault** | Every PR |
| **L1 Protocol SE** | Full DETF + production Uni V2/V4 (or other protocol SE) TestBase | Equal priority with L2 |
| **L2 Nested DETF** | Outer DETF + DualLiquidity cross-version **and** ComposedStable as `standardExchangeVault` | Equal priority with L1 |
| **L3 Base fork expansion** | Aerodrome, Slipstream, Aave Stata, etc. | Fork profile; expand matrix |
| **L4 Invariants** | First-bond bootstrap, synthetic gates, non-dilution, residual, reentrancy (attacker harness) | On L1/L2 attachments |

### 4.4 Shared behavioral cases (run per provider)

Each provider that claims SE compatibility must pass (or explicitly skip with reason):

1. **Deploy inert** — non-bootstrap mint/burn reverts before first bond.
2. **First-bond bootstrap** — acquire se vault shares via production path; first bond mints DETF leg + joins shares (80/20), opens live reserve.
3. **Mint from vault shares** — synthetic **> 1.05e18** (or configured mintThreshold); preview ≈ execution; fee split; no residual.
4. **Mint via allowlisted `vaultTokens()` asset** — fund → `seVault.exchangeIn` → join → mint DETF.
5. **Burn to vault shares** — synthetic gate, redeposit DETF leg, residual clean.
6. **Burn to SE-redeemed allowlisted asset** — if provider supports redeem path.
7. **Passthrough** — allowlisted pairs only; DETF supply unchanged.
8. **Thresholds** — mint only if synthetic **> mintThreshold** (default 1.05e18); burn only if synthetic **< burnThreshold** (default 0.95e18); neither inside the deadband.
9. **Non-dilution** — after mint, existing holders’ pro-rata reserve claim non-decreasing (modulo intentional fee mint destinations).
10. **Bonding** — user bond, protocol NFT, feeTo NFT wiring; sell-to-protocol if in scope.
11. **Reentrancy** — purpose-built attacker cannot re-enter through exchange/bond.
12. **Unsupported route** — token not in allowlist / not vault share reverts.

Nested DETF providers additionally:

13. **Opacity** — outer DETF bytecode / storage has no knowledge of inner DETF’s underlyings (review + grep gate).
14. **Double composition** — outer mint/burn does not brick inner vault; inner still serves direct users.
15. **Bond lock clamp** — `< min` reverts; `> max` clamps bonus/unlock to max.

---

## 5. Implementation phases

### Phase 0 — Scaffold and package skeleton

**Deliverables**

- [x] `ISingleStandardExchangeDETDFPkg` with `PkgInit` / `PkgArgs` **in the interface** (Crane rule).
- [x] Skeleton Repo, Common, Facets, DFPkg compiling under default profile (minimal real wiring, not fake vaults).
- [x] Facet + Pkg + Component FactoryServices (CREATE3 / manager path).
- [x] Spec deploy test with a **production** SE vault provider (Aerodrome SE via Balancer SE router TestBase): package deploys; facet cuts; no diamond-cut owner.

**Exit:** `forge test --match-path test/foundry/spec/vaults/detf/standardExchange/single/*Deploy*` green against a production SE vault. ✅

### Phase 1 — Reserve, pricing, bootstrap

**Deliverables**

- [x] Repo storage: role fields only (`standardExchangeVault`, share, rateTarget, reserve, indexes, weights, thresholds, feeOracle, NFT refs).
- [x] Common: load reserve state; WITH_RATE scale; synthetic price; threshold helpers.
- [x] DFPkg creates weighted pool (DETF STANDARD + share WITH_RATE, default 80/20); rate provider from explicit `rateTarget` PkgArg; aware-repo init; Vault Registry deploy.
- [x] Inert deploy + `ReservePoolNotInitialized` until first bond.
- [x] Synthetic + threshold helpers gate on **synthetic** (defaults 1.05e18 / 0.95e18).
- [x] Tests: inert guards + price views on production SE vault provider.

**Exit:** Package deploys inert with pool/rate provider wired; synthetic readable; mint blocked until live. ✅

### Phase 2 — Full bond NFT vault + first-bond bootstrap + info

**Deliverables**

- [x] Full bond NFT vault package wiring: user bonds, protocol NFT init.
- [x] Bond entry: vault shares and/or `vaultTokens()` allowlisted assets → shares → bond / reserve build.
- [x] **Lock duration / terms** from `feeOracle.bondTermsOfVault(this)`: revert if `< min`; clamp if `> max`.
- [x] **First bond:** mint DETF self-leg into reserve + join vault shares; mark live.
- [x] Sale-to-protocol orchestration (no rebasing token required in v1).
- [x] Info facet: synthetic, thresholds, vault refs (role names).

**Tests**

- [x] Inert until first bond; first bond with production se shares goes live.
- [x] Bond reverts when `lockDuration < minLockDuration`.
- [x] Bond with `lockDuration > maxLockDuration` succeeds (clamped).
- [ ] Bonus at min, mid, and max lock matches oracle bonus curve; above max matches max.
- [x] After bootstrap, mint gated by synthetic threshold (default 1.05e18).
- [ ] Subsequent user bonds; protocol/fee NFT state.
- [ ] Sell-to-protocol if in scope.
- [x] Info introspection matches package wiring.

**Exit:** First bond with production SE vault shares makes instance live. ✅ (core)

### Phase 3 — ExchangeIn mint + query

**Deliverables**

- [x] Mint from `standardExchangeVaultShare`.
- [x] Mint via `vaultTokens()` allowlist → `standardExchangeVault.exchangeIn` → shares → join → mint.
- [x] Seigniorage split + synthetic mint gate.
- [x] `previewExchangeIn` mirrors execution on closed-form share→DETF path.
- [ ] Residual sweep hardening.

**Tests (production SE — Aerodrome SE local)**

- [x] Mint preview ≈ execution (share path).
- [ ] Fee to `feeTo` / protocol slice assertions.
- [ ] Existing holder claim non-decreasing.
- [x] Mint reverts while inert; open-threshold mint after bootstrap.

**Exit:** Core seigniorage mint proven on production Aerodrome Standard Exchange vault. ✅

### Phase 4 — Burn / ExchangeOut

**Deliverables**

- [x] DETF → vault shares (exit + DETF-leg redeposit).
- [x] DETF → asset via Standard Exchange redeem when allowlisted.
- [x] **Synthetic** burn gate.
- [x] Preview BPT claim computed pre-burn (matches execution).

**Tests**

- [x] Burn preview ≈ execution on production provider.

**Exit:** Full mint/burn lifecycle on production Standard Exchange vault. ✅

### Phase 5 — Equal-priority production matrix

#### 5.1 DualLiquidityLinkedCrossVersionUniswapVault (required)

- [x] Provider: deploy/bootstrap dual-liquidity vault using existing `TestBase_DualLiquidityLinkedCrossVersionUniswapVault` (fork profile).
- [x] `rateTarget` = dual-liquidity’s common/role asset used by its rate providers (as exposed via vault tokens / package—not brand names in outer code).
- [x] Outer SingleStandardExchangeDETF uses dual-liquidity diamond as `standardExchangeVault`.
- [x] Full L2 suite: mint/burn outer DETF by depositing dual-liquidity shares; optional path deposit common via dual-liquidity exchange then join.
- [x] Assert outer residual clean; dual-liquidity still serves direct SE calls.

#### 5.2 ComposedStableCommonDetf (required)

- [x] Provider: use IntegratedDeploy production graph to produce a DETF instance that implements SE In/Out.
- [x] Attach as `standardExchangeVault` with explicit `standardExchangeVaultShare=detfToken`; `rateTarget=0` abstract 1:1 (composed detf→asset rate quotes not SE-provider-quotable).
- [x] Mint outer DETF from composed DETF tokens (shares); burn back; residual clean.
- [x] Documented limitation: rateTarget=0 STANDARD/STANDARD when inner burn-path pricing is unavailable.

#### 5.3 Protocol Standard Exchange vaults (equal priority with 5.1–5.2)

- [x] Uniswap V4 Standard Exchange (Base fork) — required matrix row (deploy + first bond + mint + burn + residual).
- [ ] Uniswap V2 Standard Exchange if usable in local/spec without mocks.
- [x] Aerodrome V1 (local production package — primary L1 suite).

#### 5.4 Optional

- [ ] SingleVaultDetf (brand setup only inside provider).
- [ ] Seigniorage DETF if SE-complete.

**Exit:** **DualLiquidity + ComposedStable + Uni V4 + Aerodrome SE** green on appropriate profiles—**equal priority**. ✅

### Phase 6 — Hardening

- [x] Reentrancy suites (ReentrantMockERC20 share transferFrom → expect IsLocked / SafeERC20 wrap; control path succeeds unarmed).
- [x] Residual inventory assertions on success paths (matrix + requirements).
- [x] Non-dilution mint check (requirements suite).
- [ ] Sequence invariants (deposit/swap/burn/bond order) — optional expansion.
- [ ] Share inflation / donation resistance on reserve BPT — optional expansion.
- [ ] Gas/size snapshot for package — optional expansion.
- [x] PRD checklist sync; mark PRD status IMPLEMENTED when done.

### Phase 7 — Future extensions (process, not code yet)

When adding a new Standard Exchange vault or DETF:

1. Implement `IStandardExchangeVaultProvider` adapter.
2. Add matrix row to §3 and checklist §8.
3. Run shared suite; file skips only with written reason.
4. No production DETF changes for new underlyings.

---

## 6. Implementation order (file-level)

Recommended commit/slice order (matches phases):

1. Interface + DFPkg + factories + inert deploy (Vault Registry, production SE provider)  
2. Repo + Common (synthetic gate defaults, WITH_RATE scale, join/exit primitives)  
3. Full bond NFT vault + oracle lock clamp/bonus + **first-bond bootstrap** (DETF leg mint + share join)  
4. ExchangeIn mint + query (`vaultTokens` allowlist, same curve as share mint)  
5. ExchangeOut burn + residual + synthetic burn gate  
6. Info facet  
7. Equal-priority matrix: Uni V4 + DualLiquidity + ComposedStable  
8. Invariants + reentrancy attacker harness  
9. Expand Aerodrome / Aave / Slipstream matrix  
10. Docs / PRD status IMPLEMENTED  

**Implicit defaults (follow peer DETFs unless revised):** first bond **ungated** by synthetic (no supply yet); usage/seigniorage **split destinations** from fee oracle like other DETFs; exact-out only where closed-form in v1.

Reuse from `contracts/vaults/detf/core/` where possible:

- `DETFUsageFeeLib`, `DETFMintSplitLib`, `DETFThresholdPolicy`, `DETFBalancerScaleLib`, `DETFSafeTransferLib`, `DETFPreviewLib`

Do not subclass `SingleVaultDetf*` or `ComposedStableCommonDetf*` concrete contracts.

---

## 7. Acceptance criteria

### Product

- [ ] Fresh path under `detf/standardExchange/single/` only.
- [ ] No product tickers in production Solidity or normative NatSpec.
- [ ] Type names contain full **Standard Exchange** wording.
- [ ] DETF production sources do not import concrete Uni/Aerodrome/Camelot/Aave/cross-version vault contracts (only `IStandardExchange*` / shared interfaces).
- [ ] Nested DualLiquidity and ComposedStable work as `standardExchangeVault`.

### Quality

- [ ] Closed-form paths: preview == execution.
- [ ] No residual inventory after success paths.
- [ ] No silent stranded prepaid tokens on Balancer vault.
- [ ] Non-dilution on mint for existing holders (fee destinations accounted for).
- [ ] Immutable diamond package (no owner/diamondCut on instance).
- [ ] **No mocks/stubs** in this family’s test tree for Standard Exchange behavior.

### Test matrix (minimum to call v1 done) — equal priority

| Provider | Profile | Required |
|----------|---------|----------|
| Uniswap V4 Standard Exchange | fork | Yes |
| DualLiquidityLinkedCrossVersionUniswapVault | fork | Yes |
| ComposedStableCommonDetf | default and/or fork | Yes |
| Uniswap V2 Standard Exchange | default/spec if production-local | Recommended |
| Aerodrome / Slipstream / Aave Stata | fork | Recommended expansion |
| SingleVaultDetf / Seigniorage | as available | Optional |

---

## 8. Matrix checklist (living)

Copy and tick as providers land (**production packages only**):

- [ ] Uniswap V2 Standard Exchange  
- [x] Uniswap V4 Standard Exchange (Base fork matrix)  
- [x] DualLiquidityLinkedCrossVersionUniswapVault (Base fork matrix)  
- [x] ComposedStableCommonDetf (local; rateTarget=0 abstract 1:1 when SE burn not quotable)  
- [x] Aerodrome V1 Standard Exchange (local production package via Balancer SE router TestBase)  
- [ ] Slipstream Standard Exchange  
- [ ] Aave V3 Stata Standard Exchange  
- [ ] Camelot V2 Standard Exchange (chain-gated)  
- [ ] SingleVaultDetf (provider-local brand setup only)  
- [ ] Seigniorage DETF  
- [ ] _(future production SE vault or DETF)_ _______________________________  

---

## 9. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Nested DETF gas too high for one tx mint | Allow multi-step test paths; document UX; optional intermediate share mint |
| Inner DETF thresholds block outer mint | Provider sets thresholds open in fixture; production docs for deployers |
| WITH_RATE preview drift after nested ops | Apply PRD scale rules; mint-from-actual; matrix soft-bounds only where SE vault itself drifts |
| Fork RPC / compile isolation | `FOUNDRY_TEST` path isolation; provider `isForkOnly()` |
| Accidental brand leakage | CI grep for forbidden tickers under `detf/standardExchange/single/` production paths |
| Importing concrete vault types into DETF | Architecture test / review: production files may only import interfaces + Crane + detf/core |
| Pressure to reintroduce mocks for speed | Reject; expand production provider matrix instead; pure math stays pure-input-only |

---

## 10. Definition of done

v1 is done when:

1. PRD implementation checklist is complete.  
2. Phases 0–6 are green for required matrix rows.  
3. Nested tests prove DualLiquidity cross-version and Composed Stable DETF as attached Standard Exchange vaults.  
4. This plan’s matrix process is documented so the next Standard Exchange vault is adapter-only work.  
5. PRD status updated to IMPLEMENTED with as-built notes if any intentional deltas remain.

---

## 11. Immediate next actions

1. Scaffold Phase 0 (interface, DFPkg, factories, inert deploy) against a **production** SE vault — Vault Registry path.  
2. Phase 1 + full bond NFT vault + **first-bond bootstrap**.  
3. Mint/burn against production SE vault (`vaultTokens` allowlist, synthetic gates).  
4. Land equal-priority matrix: Uni V4 + DualLiquidity + ComposedStable.  
5. Invariants, reentrancy attacker harness, matrix expansion.  

*(Coding starts when you say so — docs-only per clarification round.)*
