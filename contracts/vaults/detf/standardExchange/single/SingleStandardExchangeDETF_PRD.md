# Product Requirements Document (PRD)

## Title

SingleStandardExchangeDETF (Single Standard Exchange DETF)

## Status

IMPLEMENTED — production SingleStandardExchangeDETF shipped under `contracts/vaults/detf/standardExchange/single/` with requirements-backed matrix tests (Aerodrome SE, DualLiquidity, Uni V4 SE, ComposedStable). This PRD remains the normative product and architecture specification for the family.

## Locked decisions

Resolved in requirements clarification (apply everywhere; do not re-open without an explicit PRD revision):

| Topic | Decision |
|-------|----------|
| Default reserve weights | **80% DETF / 20%** Standard Exchange vault share; overridable via package args |
| Mint/burn threshold gate | **Fully diluted synthetic price** (as in other DETFs), not reserve spot alone |
| Bonding v1 | **Full bond NFT vault** (user bonds + protocol NFT + fee-recipient NFT) |
| Bootstrap / liveness | Deploy **inert**; instance becomes live via the **first bond** purchased with Standard Exchange vault token (shares). Buyer acquires shares through whatever process the SE vault requires, then bonds |
| Mint/bond tokenIn discovery | **`IBasicVault.vaultTokens()` allowlist** on the attached Standard Exchange vault: DETF may route listed tokens through `standardExchangeVault.exchangeIn` toward shares, then reserve entry — still no market semantics |
| `rateTarget` | **Explicit PkgArg only** (deployer / test provider always sets it) |
| Package deploy path | **Vault Registry / manager** (`indexedexManager.deploy*DFPkg` style); facets via CREATE3 |
| Instance governance | **Immutable, unowned** (no owner / diamondCut / pause on instance) |
| Testing | **Production code only** (no mocks). Integration priority is **equal** across required production attachments (protocol SE vaults + DualLiquidity cross-version + ComposedStable) — not a single default provider |
| Reentrancy tests | Purpose-built **attacker contract** allowed (harness only; not a mock SE vault) |
| Default thresholds | **`mintThreshold = 1.05e18`**, **`burnThreshold = 0.95e18`** (±5% deadband around synthetic peg); overridable via PkgArgs |
| Synthetic peg | **Always 1e18** abstract units (fully diluted reserve value in `rateTarget` terms ÷ DETF supply); no external price oracle |
| First-bond bootstrap mechanics | Buyer brings SE vault shares (or allowlisted → shares); bond flow **mints DETF self-leg into the reserve** and **joins vault shares** so both 80/20 legs exist; bond NFT receives the bonded position; instance becomes live |
| Bond lock duration / terms | From **Vault Fee Oracle** via `bondTermsOfVault(this)` (min/max lock, bonus curve). **Min is a floor** (revert if shorter). **Max is a bonus ceiling only**: longer locks are allowed and **clamped to `maxLockDuration`** for bonus (and effective lock used for terms); see Bonding |

## Purpose

Enable deployment of a reusable DETF package that pairs the DETF’s own share token with **exactly one** Standard Exchange–compatible vault inside a Balancer V3 Weighted Pool reserve. Users mint and burn DETF tokens against that reserve’s seigniorage curve. The package is protocol- and asset-agnostic: any vault that implements the Standard Exchange surface may be used as the sole external reserve leg, including another DETF that exposes that surface.

This is a **true DETF** (self-paired seigniorage token on a reserve curve), not a simple pro-rata BPT-claim vault.

## Naming Rule

### Product and type names

- Family / package / contract / library names use the full words **Standard Exchange** (e.g. `SingleStandardExchangeDETF`, `SingleStandardExchangeDETFRepo`).
- Do **not** abbreviate Standard Exchange to `SE` (or similar) in contract names, library names, file names, or interface names.

### Role names only in code

Code, storage, interfaces, and normative NatSpec use **role names only**:

| Role | Meaning |
|------|---------|
| `detfToken` / self | The DETF diamond share token (this proxy) |
| `standardExchangeVault` | The single external Standard Exchange vault instance |
| `standardExchangeVaultShare` | Share token of that vault (often the vault address itself) |
| `rateTarget` | Asset in which the Standard Exchange vault share is rate-denominated for the reserve |
| `reservePool` / `reserveBpt` | Balancer V3 Weighted Pool and its BPT |

Concrete project or launch token names (**must not appear** in contracts, storage, interfaces, or normative NatSpec): any brand-specific tickers or product names. Deployment-specific identities live only in deployment scripts, configs, and non-normative docs.

### Variable-name abbreviation

Local variables, parameters, and storage field *short forms* may abbreviate for stack and readability (e.g. `seVault_`, `seShare_`, `rateTarget_`), provided type names and public surface names keep the full Standard Exchange wording where they name the product.

### Opacity of the underlying vault

The DETF **must not** encode or surface what the Standard Exchange vault wraps:

- No assumption that the vault is Uniswap, Aerodrome, Camelot, Aave, another DETF, etc.
- No hard-coded underlyings of the Standard Exchange vault in Repo, routes, or NatSpec.
- All interaction with the external leg is exclusively through `IStandardExchange` / `IStandardExchangeIn` / `IStandardExchangeOut` (and the vault’s ERC-20 share token).
- Nested composition is allowed: the Standard Exchange vault may itself be a DETF or any other Standard Exchange–compatible diamond.

## Scope

### In scope

- Contracts under `contracts/vaults/detf/standardExchange/single/`
- Fresh codepath: `composed/single`, `composed/stable/common`, Protocol DETF, and dual-liquidity cross-version vaults are **behavioral references only**, not implementation bases to subclass
- One Standard Exchange vault as the sole external reserve instrument
- Balancer V3 Weighted Pool reserve with two tokens: DETF (self) + Standard Exchange vault share
- `StandardExchangeRateProvider` (or equivalent) for the vault-share leg, denominated in `rateTarget`
- Seigniorage mint/burn on the reserve curve
- Mint/burn threshold gating on **synthetic price** vs configured thresholds
- **Full bond NFT vault** (v1): user bond positions, protocol-owned NFT, fee-recipient NFT to `feeTo()`
- Crane DFPkg + FactoryService + **Vault Registry / manager** package deploy path
- Integration tests against **production** Standard Exchange vaults and DETFs only (equal priority across matrix rows)

### Out of scope (v1)

- Multi-vault composition (2–N Standard Exchange vaults)
- Intermediate Stable/Common composed pools (that is the stable/common family)
- Rebasing DETF token as a primary user surface (optional later; not required for v1)
- Cross-chain bridge / transport surfaces
- Encoding or routing on the Standard Exchange vault’s internal underlyings beyond what `IBasicVault.vaultTokens()` + Standard Exchange ABI expose
- Mocks / stubs as stand-ins for Standard Exchange vaults

## Behavioral references

| Reference | What to take | What not to copy blindly |
|-----------|--------------|---------------------------|
| `composed/single` | Self-paired reserve (DETF + one vault share), seigniorage curve mint, spot vs synthetic price, thresholds, bond → protocol NFT shape | Token-specific names, Uni-V4-only wiring, RICHIR/bridge ABI requirements |
| `composed/stable/common` | Fresh-path discipline, residual/uninitialized guards, fee/protocol NFT deployment hygiene, package completeness | Multi-vault + dual intermediate pool topology, rebasing as required surface |
| Dual-liquidity cross-version vault | WITH_RATE live↔raw quoting, mint-from-actual / no optimistic dilution, redeposit quote→join-or-refund / hard-revert, residual sweep | Simple BPT-pro-rata share model (this family is seigniorage, not pure BPT claims) |

## Reserve topology

Two-token Balancer V3 Weighted Pool (the **reserve**):

| Leg | Token | Balancer token type | Rate |
|-----|--------|---------------------|------|
| Self | DETF diamond (this) | `STANDARD` | n/a (1) |
| External | `standardExchangeVaultShare` | `WITH_RATE` | `StandardExchangeRateProvider` → `rateTarget` |

- Default weights: **80% DETF / 20% Standard Exchange vault share** (configurable in package args).
- The DETF proxy holds **reserve BPT** as the long-lived backing inventory (plus transient route inventory only).
- The DETF token is a **leg of the reserve**, not merely a claim on external BPT. Mint/burn is seigniorage against the weighted curve.

```
  Any Standard Exchange–compatible vault
              │
              │  vault shares only (interface-opaque underlyings)
              ▼
  Balancer V3 Weighted Reserve
   • DETF (self) — STANDARD
   • vault share — WITH_RATE (rateTarget)
              ▲
              │  curve mint / burn of DETF
         DETF diamond
```

## Token model

- The diamond proxy **is** the DETF share token (Crane ERC-20 facet stack: ERC-20, EIP-712 domain, ERC-2612 as used by peer DETFs).
- Name/symbol are deployment args; no brand defaults in package constants.
- Seigniorage model: DETF is minted/burned according to reserve-curve quotes and family fee policy—not `shares = f(bpt)` pure pro-rata as in dual-liquidity vaults.
- No requirement for a second synthetic/rebasing user token in v1.

## Governance and immutability

- Deployed instance is **immutable and unowned**: no owner facet, no post-deploy diamond cut, no pause toggles on the DETF diamond.
- Mutable external config only via the **Vault Fee Oracle** (and any oracle-owned fee parameters the family already uses): usage fee, seigniorage incentive percentage, `feeTo()`, mint/burn thresholds as applicable.
- A flawed instance is abandoned; corrections ship as a new package/instance.

## Pricing

Keep two signals **separate** (do not collapse into one public price):

| Signal | Definition | Use |
|--------|------------|-----|
| **Reserve spot** | Weighted-pool spot of DETF vs rate-adjusted vault-share leg | Valuation / diagnostics; **not** the v1 mint/burn gate |
| **Synthetic** | Fully diluted reserve value in `rateTarget` terms ÷ total DETF supply | **Mint/burn threshold gating**; primary economic gate |

**Synthetic peg:** always **1e18** abstract units (no external oracle). At fair value, synthetic ≈ 1e18.

**Threshold policy (v1)** via `DETFThresholdPolicy` (or equivalent):

| Condition | Allowed |
|-----------|---------|
| `syntheticPrice > mintThreshold` | Mint |
| `syntheticPrice < burnThreshold` | Burn |
| Otherwise (inside deadband) | Neither mint nor burn |

**Defaults (PkgArgs-overridable):** `mintThreshold = 1.05e18`, `burnThreshold = 0.95e18` (±5% around peg).  
So mint only when synthetic is **above** +5%, burn only when **below** −5%.

## Seigniorage and fees

1. **Seigniorage incentive** (from Vault Fee Oracle, e.g. `seigniorageIncentivePercentageOfVault(this)`): applied as an **input boost** on the Standard Exchange vault-share notional **before** the reserve curve quote (same ordering as Protocol / composed single DETFs).
2. **Mint split**: gross DETF from the curve quote is split per family mint-split policy (user / protocol NFT or bond vault / fee recipient as wired at deploy)—using shared libs such as `DETFMintSplitLib` / `DETFUsageFeeLib` where appropriate.
3. **No fee-free mint side door**: every DETF-minting route pays the family fee policy.
4. **Accounting rule**: never mint DETF against an optimistic join quote that exceeds actual reserve fill. Prefer join-then-mint against actual BPT / proven fill, or mint-for-quote only when `actual >= quote` with excess BPT accruing to the reserve. Existing holders must not be diluted by quote > actual.

## Reserve integration

- Balancer V3 Vault and Standard Exchange router resolved via **aware repos** (initialized by DFPkg), not ad-hoc per-call router addresses in user paths.
- Joins: prepay / seigniorage funding pattern (`prepayAddLiquidityUnbalanced` or family-equivalent) with tokens pre-transferred to the Balancer Vault where required.
- Exits: prepay proportional (or documented single-sided) remove; DETF-leg handling on burn follows the composed-single pattern (exit both legs; **redeposit DETF leg** into the reserve when the economic burn is “pay with the vault-share leg”).
- Quoting: BasePoolMath / weighted helpers with correct WITH_RATE scaling:
  - **Adds**: live balances consistent with Vault add-path rounding (ROUND_UP load where the Vault uses it); raw→live RoundDown for amounts in.
  - **Removes**: live→raw RoundDown to match proportional exit outputs.
- Residual policy: no route may leave intermediate inventory stranded on the diamond; dust swept to `feeTo()` or refunded per explicit rule. Redeposit of multi-token leftovers: quote first; zero-BPT dust refunds to user; hard join otherwise (failure reverts atomically—no silent strand on the Balancer Vault).

## Canonical flows

### Allowlisted token discovery

For any path that accepts a non-share `tokenIn` toward mint or bond:

1. Read `IBasicVault(standardExchangeVault).vaultTokens()` (or equivalent basic vault surface on the diamond).
2. Accept `tokenIn` only if it is the vault share itself or appears in that allowlist.
3. Route allowlisted non-share tokens via `standardExchangeVault.exchangeIn(tokenIn → standardExchangeVaultShare, …)` before reserve entry.
4. Never encode market pairs, DEX routes, or nested DETF topology in this package.

### Mint: vault share or allowlisted asset → DETF

1. Gate: reserve **live** (see Bootstrap); mint allowed by **synthetic** price vs thresholds.
2. Obtain Standard Exchange vault shares (user supplies shares, or allowlisted asset → `exchangeIn` on the vault).
3. Quote DETF out on the reserve curve with seigniorage boost on vault-share input.
4. Join vault shares into the reserve.
5. Mint DETF per fee/seigniorage split with non-dilutive accounting.

**Preview:** same graph with `previewExchangeIn` + BasePoolMath / weighted helpers, WITH_RATE live↔raw correct.

### Direct vault-share deposit

User already holds Standard Exchange vault shares → join reserve → mint DETF on curve (fee still applies).

### Burn: DETF → vault share or allowlisted payout

1. Gate: burn allowed by **synthetic** price vs thresholds; reserve live.
2. Burn DETF; exit reserve for the vault-share slice due; redeposit DETF-leg residual into reserve as specified (composed-single pattern: economic burn pays with the vault-share leg).
3. Optionally redeem vault shares through `standardExchangeVault` into an allowlisted token the vault can pay.
4. Deliver to recipient; residual clean.

### Passthrough

Asset↔asset routes that only involve the attached vault may be **delegated** without minting DETF when both tokens are allowlisted / accepted by the vault’s Standard Exchange surface. DETF supply unchanged.

### Bonding (v1) — full bond NFT vault

- Family-owned **bond NFT vault** with at least:
  - ordinary **user bond** NFTs
  - **protocol-owned** NFT (DETF principal / seigniorage accrual target as designed)
  - **fee-recipient** NFT minted to Vault Fee Oracle `feeTo()`, with deploy-time unlock semantics per stable-family hygiene
- Bond entry reuses the reserve-building graph: input is Standard Exchange vault shares and/or allowlisted tokens that convert to shares.
- **Lock duration and bond terms** come from the **Vault Fee Oracle**, not hardcoded in the DETF:
  - Read `feeOracle.bondTermsOfVault(address(this))` → `BondTerms` (`minLockDuration`, `maxLockDuration`, min/max bonus percentages).
  - Caller supplies `lockDuration`. Processing rules:
    1. If `lockDuration < minLockDuration` → **revert** (user may not bond shorter than the oracle minimum).
    2. If `lockDuration > maxLockDuration` → **clamp**: set effective duration to `maxLockDuration` (override the argument for all term math). The user may lock “as long as they want” in intent, but **bonus shares are computed as if they provided `maxLockDuration`**—no extra bonus past the oracle max.
    3. Otherwise use `lockDuration` as provided.
  - **Bonus shares / multiplier:** use the clamped effective duration with the same bonus curve as peer DETFs (`DETFBondNFTMathLib._calcBonusMultiplier` or equivalent): interpolate between `minBonusPercentage` and `maxBonusPercentage` from min→max lock; at effective `maxLockDuration`, bonus is the full max bonus.
  - After clamping, treat `effectiveLockDuration` as the sole duration for **bonus multiplier**, **position unlockTime** (`block.timestamp + effectiveLockDuration`), and any bond-term math—do not retain a longer raw request for unlock while capping only bonus.
  - Oracle terms remain mutable via fee-oracle governance; the DETF only reads them.
- Sale-to-protocol moves principal into the protocol NFT (rebasing secondary token **not** required for v1).
- **First bond** is the liveness bootstrap (see Bootstrap).

## Route table (normative surface)

Public surface is `IStandardExchangeIn` / `IStandardExchangeOut` (and bonding/info facets as needed). Supported logical routes:

| tokenIn | tokenOut | Kind |
|---------|----------|------|
| `standardExchangeVaultShare` | DETF (self) | Mint (direct join) |
| Token in `IBasicVault(standardExchangeVault).vaultTokens()` (non-self) | DETF (self) | Mint (via vault then join) |
| DETF (self) | `standardExchangeVaultShare` | Burn (exit vault-share leg) |
| DETF (self) | Allowlisted token vault can pay from shares | Burn + vault redeem |
| Allowlisted pairs only on the attached vault | (passthrough) | No DETF mint/burn |
| `standardExchangeVaultShare` (or allowlisted → shares) | Bond NFT position | **Bond** (first bond = bootstrap) |

Unsupported pairs revert with a family error (e.g. `UnsupportedRoute`).

Every mutating route: deadline, minOut / maxIn, zero-amount checks, reentrancy lock, residual policy.

## Bootstrap

1. **Deploy inert** via DFPkg + Vault Registry path: Standard Exchange vault reference, explicit `rateTarget` PkgArg, rate provider, weighted reserve pool **created but not live** for normal seigniorage mint/burn (liveness flag clear).
2. Persist sorted pool indexes; init aware repos; deploy **full bond NFT vault** and special NFTs (protocol + feeTo).
3. **First bond (liveness):**
   - Buyer acquires Standard Exchange vault shares through production SE vault flows (or allowlisted token → shares on the vault).
   - Buyer bonds with those shares (bond NFT path).
   - Bond execution **mints the DETF self-leg into the reserve** and **joins the vault shares**, so the 80/20 pool is populated on both legs in one bootstrap sequence.
   - Bond NFT is credited with the bonded position; seigniorage/fee splits apply per family bond policy.
   - Instance is marked **live** (`isReservePoolInitialized` or equivalent).
4. Thereafter, normal mint/burn/bond routes require a live reserve and **synthetic** threshold gates; pre-live non-bootstrap routes revert `ReservePoolNotInitialized` (or family equivalent).

No brand-token assumptions in bootstrap. No mock vault “seed.” First bond is the only path that turns an inert instance into a live seigniorage market.

## Architecture / components

Family follows Repo / Common / Target / Facet / DFPkg / FactoryService conventions under:

```text
contracts/vaults/detf/standardExchange/single/
```

Expected artifacts (names illustrative; keep full **Standard Exchange** in type names):

| Component | Role |
|-----------|------|
| `SingleStandardExchangeDETFRepo` | Storage: vault, share, rate target, reserve pool/BPT, indexes, weights, thresholds, fee oracle, bond/NFT refs |
| `SingleStandardExchangeDETFCommon` | Price, scale, join/exit, mint split, thresholds, residual |
| `SingleStandardExchangeDETFExchangeIn*` | Mint + passthrough exact-in |
| `SingleStandardExchangeDETFExchangeOut*` | Exact-out where closed-form |
| `SingleStandardExchangeDETFBonding*` | Bond / sell-to-protocol |
| `SingleStandardExchangeDETFInfo*` | Discovery, prices, config views |
| `SingleStandardExchangeDETDFPkg` | Package init, facet cuts, dependency composition |
| `*_Facet_FactoryService` / `*_Pkg_FactoryService` / `*_Component_FactoryService` | Crane/IndexedEx deploy helpers |
| `SingleStandardExchangeDETF_PRD.md` | This document |

### DFPkg composition (Vault Registry path — required)

Package-owned composition via **manager / Vault Registry** deploy helpers (facets CREATE3):

1. ERC-20 facet stack for the DETF token.
2. Accept address of an existing Standard Exchange vault (injected; no underlying knowledge).
3. Deploy rate provider: subject = vault share, target = **explicit `rateTarget` PkgArg**.
4. Create Balancer weighted pool; DETF `STANDARD`, vault share `WITH_RATE`; default weights **80 / 20**.
5. Persist sorted indexes; init aware repos for Balancer Vault + Standard Exchange router.
6. Deploy **full bond NFT vault**; mint protocol NFT + fee-recipient NFT to `feeTo()`.
7. Register package/instance on the Vault Registry; instance remains **inert** until first bond.

### No brand-specific interface

Prefer standard surfaces (`IStandardExchangeIn`, `IStandardExchangeOut`, `IBasicVault` / info facets). Any family interface must use role names only (e.g. `ISingleStandardExchangeDETF`).

## Testing requirements

### Production code only — no mocks

- **Do not use mocks, stubs, or fake Standard Exchange implementations** in this family’s tests (including `MockStandardExchange` and similar).
- Every test that exercises the DETF attaches a **production** Standard Exchange–compatible vault: protocol SE vault packages (Uniswap, Aerodrome, Aave Stata, etc.), dual-liquidity cross-version vault, composed stable DETF, or other production DETFs that expose the Standard Exchange surface.
- Role tokens for fixtures may be production ERC-20 diamonds / package-deployed tokens from Crane factories (as elsewhere in IndexedEx), not mock ERC-20s invented only to fake vault behavior. Prefer live fork assets or the same production token packages used by peer TestBases.
- Pure math libraries (`detf/core` helpers used by this family) may be unit-tested with pure inputs only—**no** mock vault substitution for DETF integration or lifecycle tests.

### Coverage and layout

- Location: `test/foundry/...` mirroring package path (spec and/or Base fork as appropriate).
- Fixtures use **role names** only—never product tickers in test contract names or assert messages beyond addresses.
- Cover: bootstrap; mint/burn gates; curve mint preview≈execution on closed-form paths; non-dilution; residual clean; bonding; WITH_RATE join/exit; passthrough only via vault ABI; unsupported routes; reentrancy.
- Multi-hop paths that go through the attached vault may document a small minOut buffer if the vault’s own preview/execution drifts; DETF-owned closed-form math must still be exact.
- Nested composition tests (outer DETF + inner production DETF/SE vault) are first-class.
- Required production attachments have **equal integration priority** (no single “primary” provider): at minimum DualLiquidity cross-version, ComposedStable DETF, and at least one protocol Standard Exchange vault (e.g. Uniswap V4 on Base fork)—see implementation plan matrix.
- Reentrancy: purpose-built attacker contracts OK; never replace the Standard Exchange vault with a mock.

## Implementation checklist

- [x] PRD accepted with locked decisions
- [ ] Repo + Common (roles only; WITH_RATE scale; non-dilutive mint; synthetic gate)
- [ ] DFPkg + FactoryServices + Vault Registry path + inert deploy
- [ ] ExchangeIn mint + query (`vaultTokens` allowlist)
- [ ] ExchangeOut / burn + residual
- [ ] Full bond NFT vault + **first-bond bootstrap**
- [ ] Info / pricing surface (spot view + synthetic gate)
- [ ] Production-only matrix tests green (equal priority rows)
- [ ] Package deploy script / staged foundry scripts (when ready for launch)

## Explicit non-goals

- Surfacing or special-casing the Standard Exchange vault’s internal markets or underlyings
- Requiring Uniswap, Aerodrome, or any single DEX
- Multi-leg composed stable/common pools
- Token-branded storage fields or route names
- Abbreviating Standard Exchange in public type names
- **Mocks, stubs, or fake Standard Exchange vaults in tests** — production packages and real instances only

## Summary

**SingleStandardExchangeDETF** is a reusable, brand-agnostic DETF package: one Standard Exchange–compatible vault share is paired with the DETF’s own token in a Balancer weighted reserve; mint and burn are seigniorage on that curve; the vault’s underlyings remain opaque and may themselves be any Standard Exchange surface, including another DETF.
