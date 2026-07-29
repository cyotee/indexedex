# Product Requirements Document (PRD)

## Title

MultiVaultWeightedDetf (Multi–Standard Exchange Weighted DETF)

## Status

**DRAFT** — design locked via requirements clarification; implementation not started.

**Threshold modes:** Conforms to [`DETF_Threshold_Modes_PRD.md`](../../DETF_Threshold_Modes_PRD.md) (formal LOCKED) — deploy-time Policy (default ±5% synthetic deadband) vs Open; gates always synthetic; trailing `PkgArgs.thresholdMode`.

## Locked decisions

Resolved in requirements clarification (apply everywhere; do not re-open without an explicit PRD revision):

| Topic | Decision |
|-------|----------|
| Reserve composition | **DETF token + only Standard Exchange vaults** (no bare ERC20 legs in v1) |
| Vault count `N` | **`1 ≤ N ≤ 7`** SE vaults → **up to 8** Balancer weighted-pool tokens (DETF + vaults) |
| Packaging | **Single parameterized** DFPkg; `N` and per-leg config in package args |
| Weights | **Fully custom at deploy** (DETF + each vault); must sum to `1e18`; **immutable** after deploy |
| Rate providers | **Optional per vault**: `rateProvider` + `rateAsset` (must be in that vault’s `tokens()`), or unrated / `STANDARD`; legs **never collapse** even if rateAssets match |
| User mint / redeem assets | **Configured SE vault shares only** (and DETF). If the user holds a token inside an underlying vault, they must **deposit into that SE vault first**, then deposit shares into the DETF |
| RateAsset zaps on DETF (user mint) | **Out of scope for v1** — user mint path does not accept rateAssets |
| Share ↔ share on DETF | **Out of scope** — users use Standard Exchange Router or Balancer routers against the reserve weighted pool (ordinary pool) |
| Single-sided mint shape | **Same as single-vault DETF**: quote DETF for vault-share contribution from **weighted pool math**, mint with fee/bond split, join reserve |
| Bonding / claim | **Full bonding + rebasing claim** (behavioral parity with SingleVaultDetf / SingleStandardExchangeDETF shape) |
| Bootstrap / liveness | **Inert deploy**. Instance becomes live when a user **initializes the reserve** (deposits so the weighted pool has liquidity / BPT exists), then **bonds with reserve pool BPT**. Bonding with BPT is the canonical bootstrap completion path |
| Accepted bond tokens | At least **reserve BPT** (bootstrap). Configured **vault shares** for ongoing bonds as peer families (implementation must list via `acceptedBondTokens()`) |
| Claim redemption | Rebasing claim may be redeemed for **any configured `rateAsset[i]`** of a rated leg (exit protocol BPT → vault share path → underlying SE `exchangeIn` to that rateAsset). Unrated legs have no rateAsset payout unless a rate is later configured |
| Nested vaults | **Allowed**. Any `IStandardExchange` is fine, including another DETF. DETF is **opaque** to vault contents |
| Mint / burn gate | **Synthetic price from reserve pool state** (fully diluted backing vs DETF supply) vs mint/burn thresholds; **not** an off-pool multi-asset FX “numeraire” |
| Pricing engine | **Weighted reserve pool** (balances, weights, fees, rate providers) prices legs against each other; mint/burn amounts and synthetic use pool-implied math |
| Codepath | **Fresh** under `contracts/vaults/detf/composed/multi-vault-weighted/`; existing DETFs are **behavioral references only** |
| Cross-chain bridge | **Out of scope for v1** |
| Dynamic reweight | **Out of scope for v1** |
| Non-SE ERC20 reserve legs | **Out of scope for v1** (later mixed-ERC20 DETF family) |
| Naming | **Role names only** in contracts/interfaces/storage/normative NatSpec. No product tickers (RICH, WETH-as-role, etc.) |
| Deploy path | Facets via CREATE3; DFPkg via **Vault Registry / manager** |
| Testing | **Production-first** (no mocks of SUT vaults/manager/registry); real SE vaults + Balancer |

## Purpose

Enable a DETF whose Balancer V3 **weighted** reserve pairs the DETF share token with **one to seven** Standard Exchange vault share tokens, each valued independently.

This family is for baskets where a **stable** pool is the wrong abstraction:

1. **Unrated** vault shares (or no reliable shared rate asset).
2. **Disparate rate targets** (e.g. vaults rated as WBTC, ETH, and USDC).
3. **Same nominal target but distinct market identity** (e.g. ETH/USDC SE vault vs ETH/USDT SE vault — different pools, liquidity, and price paths must remain separate legs with separate rates).

Contrast:

| Family | When to use |
|--------|-------------|
| `standardExchange/single` / `composed/single` | Exactly **one** SE vault + DETF |
| `composed/stable/common` | Multiple SE vaults with **like-kind / equivalent** rate targets (stable-style intermediate composition) |
| **`composed/multi-vault-weighted` (this PRD)** | Multiple SE vaults that must keep **distinct** valuations in a **weighted** reserve with DETF |

## Naming Rule

### Product and type names

- Family / package / contract names use full words, e.g. `MultiVaultWeightedDetf`, `MultiVaultWeightedDetfDFPkg`.
- Prefer not to abbreviate Standard Exchange to `SE` in **type names**; short locals (`vault_`, `share_`) are allowed for stack pressure.

### Role names only in code

| Role | Meaning |
|------|---------|
| `detfToken` / self | The DETF diamond share token (this proxy) |
| `underlyingVaults[i]` | Standard Exchange vault instance for leg `i` |
| `vaultShare[i]` | Share token of that vault (often the vault address itself) |
| `rateAsset[i]` | Optional; Rate Provider quote target for leg `i`; must be ∈ vault `i`’s declared tokens when a provider is set; also a **claim redemption** payout option |
| `rateProvider[i]` | Optional Balancer `IRateProvider` for leg `i` (or family equivalent) |
| `reservePool` / reserve BPT | Balancer V3 Weighted Pool and its BPT; BPT is a **bond input** for bootstrap / bonding |
| `rebasingClaimToken` | Rebasing claim token minted on bond sale (v1 required surface) |
| `bondNftVault` / protocol NFT | Bond position NFT inventory |

**Forbidden in normative code/NatSpec:** product brands (`RICH`, `RICHIR`, role misuse of `WETH`).  
**Allowed:** true WETH-only infrastructure elsewhere; deploy scripts may pass concrete addresses as instance data.

## Scope

### In scope (v1)

- Directory: `contracts/vaults/detf/composed/multi-vault-weighted/`
- Parameterized `N ∈ [1, 7]` Standard Exchange vaults + DETF in one weighted reserve
- Custom immutable weights for DETF + each vault share
- Per-leg optional rate configuration (WITH_RATE vs STANDARD)
- Seigniorage mint/burn gated by **pool-implied** synthetic price deadband
- User exchange surface for **vault shares ↔ DETF** only (exact-in / exact-out as feasible)
- Bootstrap: user builds **reserve BPT**, then **bonds BPT**
- Full **bond NFT** lifecycle + **rebasing claim** (sell → claim mint; redeem claim to **any configured rateAsset**)
- Nested Standard Exchange vaults (including DETF-as-vault) without inspecting contents
- Crane facets + DFPkg + FactoryService + Vault Registry package deploy
- Production-first Foundry tests (hermetic ports and/or fork as needed)

### Out of scope (v1)

- Non–Standard Exchange ERC20s as reserve legs
- DETF-level user zaps of rateAssets / underlyings for **mint** (must use SE vault first)
- DETF-level **vaultShareᵢ ↔ vaultShareⱼ** (use Balancer / Standard Exchange routers on the reserve pool)
- Off-pool multi-asset FX / separate “numeraire” ledger for pricing
- Cross-chain bridge / relayer surfaces
- Dynamic weight updates after deploy
- `N > 7` or more than 8 pool tokens
- Subclassing concrete contracts from `composed/single`, `composed/stable/common`, or Protocol DETF

## Behavioral references

| Reference | Take | Do not copy blindly |
|-----------|------|---------------------|
| `standardExchange/single` | Single SE + DETF weighted reserve, synthetic gate, inert deploy, full bond NFT shape, vault-share-first mental model | Fixed two-token only; product-era names if any remain |
| `composed/single` | Seigniorage split mint, reserve join/exit helpers, bonding + claim orchestration patterns | Hard-wired single leg names; bridge surface |
| `composed/stable/common` | Multi-vault deploy hygiene, bond NFT + claim, production-first TestBases | Stable intermediate pools; multi-hop stable routing |
| DualLiquidityLinked | Inert bootstrap discipline, preview≈execution, residual policy | Pure pro-rata BPT share model (this family is seigniorage) |

## Reserve topology

Balancer V3 **Weighted Pool** with `1 + N` tokens (`1 ≤ N ≤ 7`):

| Index role | Token | Balancer token type | Rate |
|------------|--------|---------------------|------|
| DETF leg | `address(this)` | `STANDARD` | n/a (1) |
| Vault leg `i` | `vaultShare[i]` | `WITH_RATE` if provider set; else `STANDARD` | `rateProvider[i]` → value in `rateAsset[i]` terms when present |

```
  SE vault₁  SE vault₂  …  SE vault_N
   (shares)   (shares)      (shares)
       \         |          /
        \        |         /
         ▼       ▼        ▼
    Balancer V3 Weighted Reserve
    • DETF (self) — STANDARD
    • vaultShare₁ … vaultShare_N — WITH_RATE or STANDARD (per leg)
                ▲
                │  seigniorage mint / burn of DETF
           DETF diamond
                │
         bond NFT / claim token (v1)
```

### Weight invariants

- Deploy args supply `weightDetf` and `weights[i]` for each vault leg.
- `weightDetf + Σ weights[i] == 1e18` (exact; revert otherwise).
- Each weight `> 0` (no zero-weight legs).
- Weights are **immutable** for the life of the instance.

### Distinct legs

Two vaults that both quote the same economic asset (e.g. both ETH-rated) remain **two reserve tokens** with **two** providers (or unrated). The design deliberately does **not** merge like-kind legs; that is the Stable DETF’s job.

## Token model

- Diamond proxy **is** the DETF ERC-20 (Crane ERC-20 / EIP-712 / permit facets as peer DETFs).
- Name/symbol: deployment args only; no brand defaults in package constants.
- Seigniorage model: mint/burn against the multi-asset weighted curve and fee policy—not pure `shares ∝ BPT` unless a route explicitly does proportional exit for claim/bond mechanics.
- **Rebasing claim token** is a required companion package in v1 (sale-to-protocol and redemption via protocol-owned reserve BPT), implemented as a **fresh** package in this family or a shared role-named `IRebasingClaimToken` consumer—not a product-branded type name.

## User flows

### Bootstrap (liveness)

1. Deploy instance **inert** (reserve pool created with DETF + vault share tokens and weights; pool may be uninitialized / no BPT supply).
2. User **builds reserve liquidity** so that **reserve BPT** exists (initialize/join the weighted pool with the required legs—DETF self-leg + vault shares—using the same shape of self-leg mint + join as single-vault where needed). Exact init join helpers are an implementation detail; the product requirement is: **user obtains reserve BPT**.
3. User **bonds with reserve BPT** → bond NFT position; instance is **live** for normal mint/burn/bond share paths as defined by implementation once bootstrap bond has completed (or once pool is initialized and BPT bond is accepted—implementation plan must pick a single “live” flag rule).

```
  vault shares (+ DETF self-leg as required)
            │
            ▼
  weighted reserve initialized  →  reserve BPT
            │
            ▼
      bond(reserve BPT)  →  live DETF + bond NFT
```

### Deposit path (mint DETF) — after live

1. User obtains **SE vault shares** for a configured leg (outside this DETF).
2. User calls DETF `exchangeIn` / mint with **`tokenIn = vaultShare[i]`**.
3. **Same shape as single-vault DETF**: quote DETF from **weighted pool / seigniorage math**, apply mint-threshold policy, mint with fee/bond split, join reserve (single-sided / unbalanced helpers as peers).

### Redeem path (burn DETF)

1. User burns DETF via `exchangeIn`/`exchangeOut` with **`tokenOut = vaultShare[i]`** only.
2. DETF exits reserve toward that vault share.
3. Further exit to rateAsset is on the **underlying SE vault**, not a share↔share DETF route.

### Bond path (ongoing)

1. `acceptedBondTokens()` includes **reserve BPT** and configured **vault shares** (as implemented; BPT required for bootstrap).
2. Bond creates NFT (lock terms from Vault Fee Oracle); protocol/fee NFTs as peer families.
3. `sellNFT` → principal to protocol NFT → mint **rebasing claim**.

### Claim redemption

1. Holder redeems rebasing claim through the DETF-owned path.
2. Protocol-owned reserve BPT is unwound as needed.
3. Payout **`tokenOut` may be any configured `rateAsset[i]`** for a leg that has a rate asset (exit to vault share `i` then SE vault exchange to `rateAsset[i]`). User selects which rateAsset; unsupported/unrated legs revert for that choice.

### Explicit non-flows (v1)

```
User rateAsset     ──✗──►  MultiVaultWeightedDetf (mint)
User rateAsset     ──✓──►  SE vault  ──✓──►  MultiVaultWeightedDetf (shares)

vaultShare_i       ──✗──►  vaultShare_j   on DETF
vaultShare_i       ──✓──►  vaultShare_j   via Balancer / SE Router on reserve pool
```

## Pricing

**The weighted reserve pool is the pricing engine.** Do not introduce an off-pool multi-asset FX numeraire.

| Signal | Definition | Use |
|--------|------------|-----|
| **Per-leg rate** | `rateProvider[i].getRate()` or 1e18 if unrated | Balancer live balances; join/exit math |
| **Reserve spot** | Weighted-pool spot between DETF and legs (and among legs) from pool state | Diagnostics / optional views |
| **Synthetic** | Fully diluted backing from **owned reserve BPT’s claim on pool balances** (rate-scaled as Balancer does), combined in the **same abstract 1e18 peg space as peer single-vault DETFs**, ÷ DETF `totalSupply` | **Mint/burn threshold gating** |

- Relative prices across disparate assets are **pool-implied** (balances + weights + rates), not a separate conversion ledger.
- Synthetic peg is abstract **`1e18`**.
- Exact formula should generalize single-vault “owned DETF leg + rate-adjusted vault legs” to **N vault legs** using proportional BPT ownership of each pool balance.

### Default thresholds

- Defaults: `mintThreshold = 1.05e18`, `burnThreshold = 0.95e18` (overridable via PkgArgs), consistent with peer SingleStandardExchangeDETF unless fee oracle overrides later.

## Governance and immutability

- Prefer **immutable / unowned** instance for diamond cut (match SingleStandardExchangeDETF) unless bonding requires a multi-step owner for claim wiring; if owner is required transiently, restrict to deploy-time wiring only and document.
- Fee/threshold parameters remain via **Vault Fee Oracle** where peer DETFs already do.
- Flawed config → abandon instance; ship new package/args.

## Package and deployment

### DFPkg

- `IMultiVaultWeightedDetfDFPkg` with `PkgInit` / `PkgArgs` **inside the interface** (Crane rule).
- `PkgArgs` (conceptual):

  - `name`, `symbol`
  - `vaults: address[N]` (or dynamic array length-checked to `1..7`)
  - `weights: uint256[N+1]` or `{ weightDetf, weights[] }` summing to `1e18`
  - per-leg optional `rateProvider[]`, `rateAsset[]` (zero address = unrated)
  - `mintThreshold`, `burnThreshold`
  - companion package refs as needed (bond NFT pkg, claim token pkg, rate provider pkg, weighted pool factory, routers, fee oracle already on manager)

- Facets: ERC-20 stack, multi-asset basic/standard vault as needed, exchange in/out/query, info, bonding, claim-related surface.
- Deploy package via **manager vault registry**; instances via registry-backed `deployVault`.

### Bootstrap

1. Deploy DFPkg + facets via factories.
2. Deploy instance: **inert** (no requirement that pool is already initialized).
3. Create weighted pool with full token list + weights.
4. User **deposits** to obtain **reserve BPT** (initialize/join pool; DETF self-leg minted as required—same shape as single-vault).
5. User **bonds reserve BPT** → bond NFT; DETF treated as bootstrapped / live per implementation flag.
6. After live: vault-share mint/burn and share bonds subject to thresholds and guards.

## Interfaces (normative sketch)

Public surface must remain role-named. Minimal required capabilities:

| Area | Requirements |
|------|----------------|
| Info | `underlyingVaults()`, `vaultCount()`, `weights()`, `rateProvider(i)`, `rateAsset(i)`, `rateAssets()` (or enumerable), `reservePool()`, thresholds, synthetic price, mint/burn allowed |
| Exchange | `exchangeIn` / `exchangeOut` / previews for **vaultShare ↔ DETF** only |
| Bond | `acceptedBondTokens` (incl. **reserve BPT** + vault shares), `bond`, `sellNFT`, seigniorage capture as peer families |
| Claim | rebasing claim mint on sale; redeem for **any configured rateAsset** via DETF orchestration |

No DETF-level user mint of arbitrary rateAssets. Claim redemption **to** rateAsset is allowed as a **protocol unwind** path, not a general mint zap.

## Error handling (non-exhaustive)

- `InvalidVaultCount` — `N` not in `[1, 7]`
- `InvalidWeights` — sum ≠ 1e18 or zero weight
- `InvalidRateConfig` — provider set without rateAsset ∈ vault tokens, or inconsistent zero/nonzero
- `DuplicateVault` — same vault twice
- `VaultShareNotConfigured` — tokenIn/out not a configured vault share (or DETF)
- `ReservePoolNotInitialized` / not live
- `MintingNotAllowed` / `BurningNotAllowed` — threshold gate
- Bond/claim errors aligned with peer DETF error libraries (role-named)

## Testing requirements

- Inherit Crane → Indexedex → vault component TestBases; deploy SE vaults via production packages.
- No mocks of MultiVaultWeightedDetf, manager, registry, facets, DFPkg under test.
- Matrix suggestions:
  - Bootstrap: obtain reserve BPT → `bond(BPT)` → live
  - `N=1` smoke (parity-ish with single-vault weighted mint shape)
  - `N=2` disparate rateAssets; claim redeem to each rateAsset
  - `N=2` same rateAsset, two vaults (distinct legs)
  - Nested DETF as one underlying SE vault
  - `N=3..7` deploy + metadata + one mint/bond path (gas/size watch)
  - Unrated leg + rated leg mixed
  - Threshold closed mint/burn
  - Bond vault share → sell → claim redeem to rateAsset
  - Reject rateAsset as mint `tokenIn`; reject share↔share on DETF
- Facet `IFacet` metadata tests for every facet.
- Size checks for diamond package under max facets.

## File structure (proposed)

```
contracts/vaults/detf/composed/multi-vault-weighted/
  MultiVaultWeightedDetf_PRD.md          # this document
  MultiVaultWeightedDetfRepo.sol
  MultiVaultWeightedDetfCommon.sol
  MultiVaultWeightedDetfExchangeInTarget.sol
  MultiVaultWeightedDetfExchangeInFacet.sol
  MultiVaultWeightedDetfExchangeOutTarget.sol
  MultiVaultWeightedDetfExchangeOutFacet.sol
  MultiVaultWeightedDetfExchangeQueryTarget.sol
  MultiVaultWeightedDetfExchangeQueryFacet.sol
  MultiVaultWeightedDetfInfoTarget.sol
  MultiVaultWeightedDetfInfoFacet.sol
  MultiVaultWeightedDetfBondingTarget.sol
  MultiVaultWeightedDetfBondingFacet.sol
  MultiVaultWeightedDetfDFPkg.sol
  MultiVaultWeightedDetf_Facet_FactoryService.sol
  MultiVaultWeightedDetf_Pkg_FactoryService.sol
  MultiVaultWeightedDetf_Component_FactoryService.sol
  # companion claim/bond packages as separate subdirs or shared role-named pkgs
```

## Implementation checklist (high level)

- [ ] PRD review / approval
- [ ] Repo storage for `N` vaults, weights, rates, thresholds, reserve indices, live/bootstrap flag
- [ ] Weighted pool create + inert deploy
- [ ] Bootstrap: user join → BPT → `bond(BPT)`
- [ ] Pool-implied synthetic + mint/burn gates
- [ ] Single-vault-shaped mint for vault shares
- [ ] Exchange in/out for vault shares ↔ DETF + previews only
- [ ] Bond NFT + protocol/fee NFTs + sell → claim
- [ ] Claim redeem to **any** configured rateAsset
- [ ] DFPkg + factories + registry deploy path
- [ ] Production-first test matrix (`N=1,2,3` min; `N=7` deploy smoke; nested DETF leg)
- [ ] Docs / Agents.md pointer to this family and when to use Stable vs Weighted multi-vault

## Open items for implementation plan (not blockers for PRD intent)

1. Exact Balancer factory for arbitrary `1+N` custom weights (2–8 tokens).
2. Precise bootstrap join helper: who mints DETF self-leg and in what proportions on first pool init.
3. Single “live” flag: after first BPT bond only, or after pool init + any BPT bond.
4. Whether vault-share bonds are allowed before/after bootstrap vs BPT-only bootstrap.
5. Whether instance is fully unowned or needs deploy-time owner for claim wiring.
6. Contract size / facet split if `N=7` helpers blow the stack (prefer helper libraries over viaIR).

## Revision history

| Date | Change |
|------|--------|
| 2026-07-14 | Initial draft from locked Q&A: SE-only legs, N=1..7, parameterized package, custom immutable weights, optional per-leg rates, vault-share-only entry, full bond+claim, synthetic deadband, inert bootstrap, fresh codepath, listed non-goals |
| 2026-07-14 | Follow-up locks: bootstrap via deposits→reserve BPT→bond(BPT); single-vault mint shape; claim redeem to any rateAsset; no share↔share on DETF (use external routers); nested DETF allowed; drop off-pool numeraire—pricing is pool-implied |
