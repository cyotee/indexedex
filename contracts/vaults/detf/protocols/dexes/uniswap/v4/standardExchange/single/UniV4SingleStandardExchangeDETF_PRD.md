# Product Requirements Document (PRD)

## Title

**UniV4SingleStandardExchangeDETF** (Uniswap V4–listed Single Standard Exchange DETF)

## Status

**DRAFT v0.19** — App-level listing oracle (V4 core has no observation ring); bond sell = withdraw tokens → rebasing deposit (not position transfer); protocol id 0 ledger-only; pair-only `effectiveShares`; child packages Ownable→DETF; pure Crane child deploy. Approaching LOCK.

| Related | Role |
|---------|------|
| **Code (normative for peer behavior)** | Bond vault + mint split under `contracts/vaults/detf/` (e.g. `common/bondNft/`, balancer true DETF families) — **not** old Single SE PRD docs |
| Threshold modes | Shared `DETFThresholdPolicy` / code |
| Uni V4 SE (reference only) | `contracts/protocols/dexes/uniswap/v4/` — **behavioral reference** for share math, deposit / wing strategy, `widthMultiplier` (`UniswapV4PositionRepo`). **Not** the claim reserve package. |
| Bond NFT | `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/` |
| Rebasing liquidity claim | `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/` |

---

## Product one-liner

A Single Standard Exchange DETF that:

1. Holds **Backing SE vault shares** as primary **inventory** / burn backing (not a pricing-pool leg). The Backing SE does **not** hold DETF.
2. **Lists** itself on Uniswap V4 as `DETF / pairToken`, where **`pairToken` must be in the Backing SE vault’s `tokens()`** (deploy-time validation).
3. **Sizes DETF** from a **`pairToken` notional** and a simple **exchange rate**: the pool’s **initialized price**, until the market mark is usable under option **B**; then that market mark (TWAP). Same Single SE–style fee/inventory split after the gross quote (“typical modifiers”).
4. **Policy gates** use TWAP synthetic (fallback when unusable). **Open** mode has **no** threshold gates.
5. **Bonds:** NFT package **owns** dual OOR listing positions; pair in + mint DETF; **full** maturity close only (withdraw both → **burn all DETF** → user gets **pair only**) after paying rewards; sell → **withdraw both positions fully** → send **pair + DETF tokens** to rebasing → deposit into standard wings → mint pair-settled claim. No partial bond close.
6. **Rebasing claim package** manages listing-pool liquidity for itself (SE-style share accounting + deposit; **custom redeem** that prefers keeping DETF in the pool). Anyone may deposit **pairToken or DETF** to mint claim. Claim redeems **only in pairToken**. Obligation = pro-rata **ZapOut-to-pair**; execution ladder avoids selling DETF until required.

---

## Role vocabulary (LOCKED — use these names)

| Role | Preferred name | Meaning |
|------|----------------|---------|
| `detfToken` / `address(this)` | DETF diamond | ERC-20 share of the DETF; owns **Backing SE** inventory |
| **Backing SE Vault** | `standardExchangeVault` / `backingStandardExchangeVault` | Any `IStandardExchange` used as primary mint/burn inventory. **Must not** include DETF in its `tokens()`. **`pairToken` must ∈ `tokens()`**. |
| `standardExchangeVaultShare` / `backingVaultShare` | Backing SE share | Inventory token held on the DETF diamond |
| `pairToken` | Listing counter-asset | Quote/curve notional in-asset; must ∈ Backing SE `tokens()` |
| `listingPool` / `poolKey` / `poolId` | Uni V4 DETF/`pairToken` pool | Single pool for TWAP, init price, user bonds, and rebasing managed LP (`hooks = address(0)`) |
| `creationSqrtPriceX96` | Init exchange rate | Used when option B unusable |
| **Bond NFT package** | `bondNft` | Owns user dual OOR PoolManager positions while bond is open |
| **Rebasing claim package** | `rebasingClaimToken` / rebasing manager | Owns managed listing LP after deposits / bond sells; ERC-20 claim; **not** Uni V4 SE |
| `detfBondTokenId` | Always **0** | Protocol DETF NFT for inventory reward ledger weight |
| `widthMultiplier` | Deploy-time | OOR band distance (same semantics as Uni V4 SE) |

**Always distinct (LOCKED):** Backing SE Vault **≠** rebasing package. There is **no** “primary SE may equal claim Uni V4 SE” path. Uni V4 SE vault package is **not** the claim reserve.

**Anti-patterns:** brand tickers; `pairToken` outside Backing SE `tokens()`; using vault share as quote/curve in-asset or share NAV in mint/synthetic; partial bond close; listing-pool hooks in v1; wiring claim redeem through Uni V4 SE zap-out as the primary path; same-address Backing SE and claim manager.

---

## Plain-language pricing (no “linear function” jargon)

### Quote / curve in-asset (LOCKED)

Gross DETF is always computed from a **`pairToken` notional** and the listing DETF/`pairToken` mark. This is the structural analogue of Single SE’s curve-in asset (there: vault share on the Balancer reserve; **here: `pairToken` on the Uni V4 listing pool**).

| Role | Asset |
|------|--------|
| Listing / mark / quote **in-asset** (notional for gross DETF) | **`pairToken`** |
| Listing / mark / quote **out-asset** | **`detfToken`** |
| Primary **inventory** (custody, burn inventory, inert→live) | **`backingVaultShare`** |

After gross DETF: same spirit as Single SE — input boost on the **pairToken notional** → usage fee → inventory DETF → bond vault; user free DETF per path (primary vs bond-open).

**Anti-patterns (do not re-open):**

- Using vault share as the mark/curve in-asset (`outGivenIn(share → DETF)` on a share leg).
- Vault-share NAV in mint quote or synthetic.
- Treating share as a listing-pool currency.
- Pairing DETF with a `pairToken` **not** in Backing SE `tokens()`.

### What “initialized price” means

When the Uni V4 pool is created, the deployer sets a starting price, e.g.:

> “1 DETF is worth X of `pairToken`”  
> (encoded on-chain as `sqrtPriceX96`)

That is just an **exchange rate** — like a fixed menu price. For **mint / bond-open only**, it converts **`pairToken` notional → DETF** when option B is unusable.

**Not used for:** primary burn payout (fair-share Backing SE inventory), claim obligation (ZapOut-to-pair of rebasing reserve), or “inverse R” burn sizing.

### Quote direction (LOCKED — mint / bond-open only)

Do **not** reason about mint size in abstract “token0 vs token1” order. **Mint and bond-open** use the listing mark R in **pair → DETF** direction with the same **typical protocol modifiers** as peer DETFs (seigniorage input boost on pair notional → exchange rate → usage fee / mint split):

| Path | How sized |
|------|-----------|
| **Mint / bond-open** | Exact-in spirit: **`pairToken` notional → DETF** via R (creation or TWAP under B) + typical modifiers |
| **Primary burn** | **Not R.** Fair-share of **backing vault-share inventory** — see Primary burn |
| **Claim redeem obligation** | **Not R.** Pro-rata **ZapOut-to-pairToken** of rebasing full reserve — see Rebasing |

`currency0` / `currency1` / `sqrtPriceX96` encoding is an **implementation detail** of reading Uni V4 state for R; product mint law is always pair → DETF as above.

### When is that rate used?

| Pool state | Price used to size mint from **pairToken** notional |
|------------|--------------------------------------|
| **Option B unusable** (no 1800s TWAP and/or no active in-range L) | **Creation exchange rate** |
| **Option B usable** (TWAP ready **and** active in-range L) | **TWAP** from the listing pool |

So: **fixed menu price until TWAP is usable under B; then the market TWAP.**

Fees and seigniorage incentive still adjust the final user amount (boost on **pairToken** notional → quote → fee split), same spirit as other DETFs (“typical modifiers”).

### What we are *not* doing

- We are **not** walking the Uniswap concentrated-liquidity book tick-by-tick to compute primary mint size like a full swap router (no per-tx impact curve as the seigniorage engine; v1 = TWAP or creation rate only).
- We are **not** valuing the Backing SE vault share in `pairToken` via a second oracle for the mark (shares are inventory, not the quote in-asset).
- We are **not** listing against an arbitrary ERC-20 outside the Backing SE’s accepted tokens.
- We are **not** using Uni V4 Standard Exchange Vault as the rebasing claim reserve (see Rebasing).

### Synthetic (gates only) — formula (LOCKED)

**Peg narrative:** abstract **1e18** means “at the creation exchange rate” (not vault-share NAV; vault share is intentionally **not** in the listing pool).

| Condition | Synthetic |
|-----------|-----------|
| Option B usable | `synthetic = (P_twap / P_creation) * 1e18` (same pair↔DETF direction / decimal handling as price encoding; exact fixed-point in impl plan) |
| Option B unusable | **`1e18`** |

- `P_creation` from deploy `sqrtPriceX96`.  
- `P_twap` from 1800s TWAP on the listing pool (derived from the **DETF listing-oracle ring** — see TWAP source).  
- **Policy** (when live): mint iff `synthetic > mintThreshold` (default 1.05e18); burn iff `synthetic < burnThreshold` (default 0.95e18); equality = deadband.  
- **Open** (when live): threshold gates **always pass** — no mint/burn synthetic gating. Open does **not** change routes, fees, seigniorage split, or inert→live rules.  
- **No vault-share NAV** in this number — by design.

Bootstrap **first mint** remains **synthetically ungated** (both modes).

**Policy applies to bond-open DETF mint** the same as primary mint (bond is not a gate side door). **Open** never gates bond-open either.

---

## TWAP window (LOCKED)

| Setting | Value |
|---------|--------|
| **`twapSeconds`** | **1800 (30 minutes)** |
| PkgArgs | Store 1800; allow explicit override only if a later PRD opens it — v1 default is fixed **1800** |
| Observation cardinality | **Bootstrap at deploy (LOCKED)** — allocate DETF listing-oracle ring capacity so a 1800s TWAP *can* be stored once enough **time** and pokes have passed (see Cardinality; **not** PoolManager core cardinality) |

### TWAP source (LOCKED)

Uniswap V4 **PoolManager core does not** store a V3-style observation ring (`observe` / cardinality on core pool state). Listing-pool **hooks remain `address(0)`** (no TWAP hook in v1).

**v1 resolution (product intent without a listing hook):** this family maintains an **application-level listing-oracle observation ring** on the DETF diamond (or shared listing-oracle lib storage keyed to the instance). Samples record `blockTimestamp` + tick / tickCumulative read from PoolManager `slot0`.

| Mechanism | Rule |
|-----------|------|
| **Permissionless `pokeListingOracle()`** | Anyone may write a sample when time has advanced enough (min 1s or SE-style) |
| **Mandatory poke** | At start of: primary mint (after live), bond-open, bond close/sell, **compound**, and any DETF-orchestrated listing swap |
| **External LPs/swaps** | Do **not** auto-update the ring — callers / keepers / tests poke so option B can become true |
| **Cardinality** | Deploy-time ring capacity **32** (impl plan; covers 1800s at sparse poke rates) |

The family **derives** the 1800s geometric TWAP from this ring after the window is ready. **Mint size from pairToken notional** (once market mark is usable under **B**) uses that TWAP, same family as gates.

**v1 thin-book controls:** TWAP + creation-rate / 1e18 fallback only (no max-impact caps).

**Superseded wording:** “TWAP from PoolManager observations” / “increase PoolManager observation cardinality” — **incorrect for V4 core**; app-level ring is normative (v0.19).

---

## Usable market mark (LOCKED — option B)

**Intent:** Use a market mark only when the listing pool can support a **real trade at the current price** (active depth) **and** a **manipulation-resistant time average** is available. That is why B requires **both** TWAP readiness and active in-range liquidity — not because we size mint by walking the CL book for impact.

**Market mark is usable iff all of:**

1. Listing pool initialized  
2. **TWAP over 1800s is available** from the **DETF listing-oracle ring** (enough **wall-clock history** with pokes, not merely a large buffer capacity)  
3. **Active in-range liquidity `liquidity > 0`** at the current tick (a swap *could* execute against the book at the mark; idle/out-of-range L alone does not satisfy B)

Otherwise **unusable**.

| | Unusable | Usable (B) |
|--|----------|------------|
| Primary mint **size** | **Creation exchange rate** | **TWAP** |
| Policy **synthetic** | **1e18** | TWAP → 1e18-scaled |
| Open **synthetic gates** | Always pass (when live) | Always pass (when live) |

Bootstrap first mint remains synthetically ungated.

**First in-range listing liquidity is permissionless (LOCKED):** protocol does **not** bootstrap listing depth for live or for option B. External LPs, bond dual OOR, and/or rebasing deposits may create `liquidity > 0`. Live itself does **not** require listing depth.

### Cardinality bootstrap ≠ TWAP ready at t=0

**Deploy-time listing-oracle ring bootstrap is LOCKED** (allocate ring capacity so 1800s of samples *can* fit once pokes write them).

That does **not** remove init pricing:

| Myth | Reality |
|------|---------|
| “Buffer is large ⇒ TWAP works immediately” | **False.** TWAP(1800) needs **~1800 seconds of elapsed time** with observations **poked**. At second 0 after deploy there is no “price 30 minutes ago.” |
| “Bootstrap ⇒ never use init price” | **False.** Until B holds (time + TWAP available + `liquidity > 0`), mint size still uses **creation exchange rate**; synthetic still **1e18**. |

So: bootstrap makes TWAP *possible* after ~30 minutes (and with active L + pokes). Init pricing remains the correct pre-TWAP path.

---

## Topology (LOCKED v0.19)

```
  Backing SE Vault (any IStandardExchange)
       │  tokens() includes pairToken; never DETF
       │  vault shares ──► DETF diamond (primary inventory)
       │
       │  primary mint/burn only
       │
  Listing pool (DETF ↔ pairToken, hooks = 0)
       │  • TWAP / init price (DETF mint sizing + synthetic)
       │  • external market LPs: permissionless
       │  • user bond: 2× OOR (NFT owns) until close or sell
       │  • rebasing managed wings (rebasing package owns)
       │
  Bond NFT package                    Rebasing claim package
  (…/common/nft/)                     (…/common/rebasing/)
  • dual OOR salts while open         • owns managed listing LP
  • free DETF reward ledger           • SE-style share math + deposit
  • maturity: burn DETF, pair to user • NOT UniswapV4StandardExchange vault
  • sell: withdraw → tokens to rebasing  • claim settles in pairToken only
                                      • anyone deposits pair or DETF
                                      • redeem: pair wing → center → DETF wing
                                        → sell just enough DETF → pair out
                                        → redeposit residual DETF
```

**Ownership (LOCKED):**

| Asset / right | Owner |
|---------------|--------|
| Backing SE share inventory | **DETF diamond** |
| User bond PoolManager positions (while open) | **Bond NFT package** |
| Managed listing LP after deposit / bond sell | **Rebasing claim package** |
| Protocol free-DETF reward weight (id 0) | Bond vault ledger (peer spirit); compound = **pure donation** of free DETF into rebasing managed LP |

---

## Locked decisions

Do not re-open without PRD revision once **LOCKED**.

### Product & topology

| Topic | Decision |
|-------|----------|
| Family name | `UniV4SingleStandardExchangeDETF` |
| Backing SE Vault | **Any** `IStandardExchange` (`standardExchangeVault` PkgArg) — shares held for primary mint/burn inventory only |
| Backing SE vs DETF | Backing SE **must not** list DETF as a vault token |
| Rebasing claim package | **New** under `…/common/rebasing/` — manages listing-pool LP; **not** Uni V4 SE DFPkg |
| Backing SE vs rebasing | **Always different** systems/addresses. No same-address path (supersedes v0.16) |
| Listing pool | **One** Uni V4 pool: DETF / pairToken — price source **and** rebasing managed LP home |
| `pairToken` | ERC-20 PkgArg; **must be in** Backing SE `tokens()` at deploy (revert otherwise) |
| Pool init | postDeploy `initialize` with required `sqrtPriceX96`, **pool fee**, tickSpacing; **hooks = address(0)** |
| Listing pool fee | **One universal Uni swap fee** from **PkgArgs** (`poolFee`) |
| Hooks (v1 listing pool) | **`address(0)` only (LOCKED)** |
| External market LPs | **Permissionless** |
| Instance governance | Immutable, unowned |
| Deploy path | CREATE3 facets; DFPkg via vault registry / manager |

### Pricing & thresholds

| Topic | Decision |
|-------|----------|
| Quote / curve **in-asset** | **`pairToken` notional** (LOCKED) |
| Quote / curve **out-asset** | **`detfToken`** |
| Quote direction (mint) | Always **pair → DETF**; not token0-relative prose |
| Typical modifiers | Peer DETF path: seigniorage **boost on pair notional before** rate; then usage fee + mint split |
| Vault share role in pricing | **None** for R — inventory + primary burn fair-share only |
| Primary mint `tokenIn` | **Backing vault share** or **Backing SE-accepted token** (incl. `pairToken`); else UnsupportedRoute |
| Primary mint size | `pairTokenNotional` × R (pair paid directly, else Backing SE preview `tokenIn→pair`) |
| Primary burn | Fair-share of diamond **backing** vault-share inventory: `sharesOut = detfIn * shareBal / totalSupply` (not synthetic); share or Backing SE out |
| Pre-liquidity / unusable mark price | **Creation exchange rate** (`sqrtPriceX96` at init) |
| Usable market mark price | **TWAP** when option **B** holds |
| Usable mark predicate | **B (LOCKED):** TWAP-ready **and** active in-range `liquidity > 0` |
| Synthetic gates | TWAP when B; else **1e18** |
| Default TWAP window | **1800 seconds (LOCKED)** |
| ThresholdMode | **Policy** + **Open**; defaults 1.05e18 / 0.95e18 via shared policy |
| Policy gates | When live: mint/burn/bond-open DETF mint use synthetic thresholds |
| Open gates | When live: **no** synthetic mint/burn/bond-open gating |
| Bootstrap first mint | Synthetically ungated (both modes) |
| Live | Pool init + first successful primary mint (inventory deposit); **depth not required** |
| Seigniorage incentive | Input boost on **pairToken notional** **before** quote |
| Protocol usage fee | Vault Fee Oracle / peer DETF path (not the Uni pool fee) |
| Protocol fee / seigniorage split | Same as Single SE: usage → feeTo; **inventory DETF → bond vault reward pool**; remainder per path |
| O9 | TWAP + fallback only |

### Bond / claim (LOCKED shape)

| Topic | Decision |
|-------|----------|
| Bond purpose | Raise **listing-pool** liquidity; incentivize deposits that can feed rebasing managed LP |
| Position owner (open) | **Bond NFT package** owns both Uni V4 PoolManager positions |
| Bond `tokenIn` | **`pairToken`** (must be Backing SE–accepted) |
| User bond LP | **Two** OOR listing positions: pair leg + DETF leg |
| Salts | `keccak256(abi.encode(tokenId, pairToken))`, `keccak256(abi.encode(tokenId, detfToken))` |
| Wing ↔ token | **Pool-determined** by Uniswap V4 range math + `currency0`/`currency1` order — not product-chosen “pair always lower” |
| Range | **Same `widthMultiplier`** outer half-width rules as Uni V4 SE (`UniswapV4PositionRepo` spirit) |
| Bond-open DETF | Mint from pair notional with typical modifiers; **user net** → DETF-side OOR LP; **inventory** → bond vault rewards; **feeTo** free DETF; **same protocol fee family + Policy gates as primary mint** |
| effectiveShares | **`pairToken amount deposited at open` × lock bonus only** — DETF leg does **not** add reward weight |
| Lock terms | Fee oracle min floor / max clamp + bonus (`DETFBondNFTMathLib` spirit) |
| Close shape | **Full close only (LOCKED)** |
| Maturity unlock / close | Pay **pending rewards** first → withdraw **both** positions → **burn all DETF** recovered from either leg → send user **only pairToken** from both legs → retire NFT; **no further** reward accrual |
| Sell NFT → rebasing claim | Pay **pending rewards** first → **withdraw both** dual-salt positions fully → send **all pairToken + all DETF** to rebasing → rebasing **deposits** into **standard wings** → mint claim from ZapOut-to-pair contribution → retire NFT; **no further** bond reward accrual. **Not** PoolManager position ownership transfer / migrate. |
| `claimRewards` while open | Free DETF anytime while bond remains open/unclosed |
| Protocol NFT id 0 | **Not** a dual-salt user bond. **Reward ledger weight only** (inventory seigniorage DETF → bond vault). **No** dual OOR. **No** invented / synthetic pair principal for weighting. Compound = pure DETF donation into rebasing (**0** claim shares). |
| Rebasing claim mint (anyone) | Deposit **`pairToken` or `detfToken`** into rebasing package (SE-style deposit workflow) → claim shares; **or** sell bond (token withdraw → wing deposit) |
| Claim settlement asset | **`pairToken` only (LOCKED)** |
| Claim obligation | `sharesBurned * ZapOutToPair(fullReserve) / totalClaimSupply` |
| Claim redeem ladder | Pair wing → center → DETF wing → sell just enough DETF → pair out → redeposit residual DETF |
| Protocol compound | **Pure donation** of free DETF into rebasing reserve (no protocol claim mint) |
| When bond allowed | After **live** |
| **Superseded (v0.10)** | All-bonds-as-SE-shares-only — reverted |
| **Superseded (v0.13)** | “`pairToken` need not be in SE / irrelevant” — **reverted in v0.14** |
| **Superseded (v0.16)** | Primary SE may equal claim Uni V4 SE; claim via Uni V4 SE import — **reverted in v0.17** |

### Package layout

| Path | Contents |
|------|----------|
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/` | DETF family (facets, DFPkg, this PRD, TestBase) |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/` | **Shared** Uni V4 DETF bond NFT package |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/` | **Shared** rebasing claim + listing LP manager |
| `contracts/protocols/dexes/uniswap/v4/` | Uni V4 SE — **reference** for deposit/share/wing math only; not claim package |

---

## Purpose

- Attach one **Backing SE Vault** as **inventory** / primary burn backing (shares are not the pricing curve in-asset; vault does not hold DETF).
- Self-list DETF on Uni V4 vs a **`pairToken` that the Backing SE accepts** (`tokens()`).
- Size mint from **`pairToken` notional** × creation exchange rate until option B; then TWAP; plus peer-style fees/incentives.
- Policy/Open synthetic gates via TWAP (Open = no gates).
- Bonds: dual OOR listing positions (pair + DETF); free DETF rewards; **full** maturity close burns DETF / pair to user; sell → rebasing manager.
- Rebasing package: holds listing liquidity for itself; accepts pair or DETF deposits; claim redeems in pair only with DETF-preserving path and ZapOut fallback.

---

## Scope

### In scope (v1)

- `detf/protocols/dexes/uniswap/v4/standardExchange/single/` DETF package
- `detf/protocols/dexes/uniswap/v4/common/nft/` bond NFT package
- `detf/protocols/dexes/uniswap/v4/common/rebasing/` rebasing claim + LP manager (SE-style deposit/share math; custom redeem; absorb bond **tokens** → wing deposit)
- Listing pool init (`hooks = address(0)`); mint sized from **pairToken notional** × creation-rate then TWAP under B
- Deploy validation: **`pairToken ∈ Backing SE.tokens()`**
- Backing vault shares as primary inventory only
- TWAP synthetic (default 30m) + 1e18 fallback; Policy/Open
- User bonds: dual OOR; free DETF rewards; **full** close only
- Production-first tests

### Out of scope (v1)

- Using **UniswapV4StandardExchange** DFPkg as the claim / rebasing reserve
- Same-address Backing SE and rebasing manager
- All-bonds-as-SE-shares-only (v0.10, reverted)
- Bond-as-liveness bootstrap
- Uniswap V3 listing
- Custom listing-pool hooks
- Partial bond close / partial principal ops
- Max-impact / per-tx size caps / tick-walk seigniorage sizing
- Multi-vault composition
- Natural expansion / Balancer protocol compound PRDs
- Cross-chain
- Mocks of SUT

---

## Token model

- Diamond **is** the DETF ERC-20.
- Name/symbol: deploy args.
- Free DETF (unlocked) vs bonded (in NFT / positions) vs claim (rebasing, pair-settled) are distinct surfaces.

---

## Governance and immutability

- Instance immutable/unowned after deploy.
- Fee oracle: usage fee, seigniorage incentive, bond lock terms (min floor, max clamp).
- Thresholds + mode + TWAP window + pool params + creation price: deploy-time only.

---

## Fees (two different things)

Do **not** conflate:

| Kind | What it is | Source | Applies to |
|------|------------|--------|------------|
| **A. Uniswap listing pool fee** | Swap fee tier on the DETF/`pairToken` pool (`PoolKey.fee`) | **PkgArgs `poolFee`** at deploy | Every swap on that pool |
| **B. DETF protocol fees** | Usage fee, seigniorage incentive, mint split | **Vault Fee Oracle** | Primary mint/burn; **also** DETF minted on bond-open |

### A — Universal Uni pool fee (LOCKED)

- Set once via **PkgArgs `poolFee`** when the listing pool is initialized.
- One pool ⇒ one fee for market LPs, bond LP, and rebasing managed LP.

### B — Protocol fees: bond mint vs primary mint (LOCKED)

**Same protocol fee family as primary mint** (oracle usage fee + seigniorage input boost + mint split). Bond is not a fee-free DETF mint side door. Under **Policy**, bond-open DETF mint uses the **same synthetic mint gate** as primary mint; under **Open**, neither is gated.

**Where the split goes (LOCKED — aligned with Single SE):**

| Slice | Destination |
|-------|-------------|
| **feeTo DETF** | Free DETF to `feeTo()` |
| **inventory DETF** (seigniorage share for bonders) | **Bond NFT vault** as `rewardToken` balance — accrued via **effectiveShares** ledger; claimable as free DETF anytime while bonded |
| **User free DETF** (primary mint) | Free DETF to minter |
| **User net DETF** (bond-open) | DETF-side **OOR listing position** — exit depends on path (below) |

**User net DETF on bond exit (LOCKED — do not conflate):**

| Bond exit | DETF from positions | User receives |
|-----------|---------------------|---------------|
| **Maturity close** | Withdraw both → **burn all DETF** from either leg | **pairToken only** |
| **Sell → claim** | Withdraw both → pair+DETF tokens to rebasing → wing deposit; **DETF kept** in managed LP | **Rebasing claim** (pair-settled); free DETF rewards paid first |

Bond **lock terms** (min/max duration, bonus) stay separate oracle fields, as on peer DETFs.

---

## Seigniorage rewards for bond holders

### Reference: SingleStandardExchangeDETF (Balancer) — verified behavior

| Concept | What it actually is on Single SE |
|---------|----------------------------------|
| **Bond principal** | **Reserve BPT** on the bond NFT |
| **Reward token** | **Free DETF**, not BPT |
| **Apportionment** | `rewardPerShares` + **effectiveShares** (principal + lock bonus) |
| **Claim anytime** | `claimRewards(tokenId)` while locked |
| **Protocol NFT** | Id 0 earns same ledger; compound path is family-specific |

### Uni V4 DETF (this family — dual listing LP bonds)

| Role | Balancer Single SE | Uni V4 DETF (current) |
|------|--------------------|------------------------|
| Bond capital / LP | Reserve **BPT** | **Two OOR listing positions** (pair + DETF), salts `keccak256(tokenId, token)` |
| Close principal | Return BPT claim | Withdraw both → **burn all DETF** → **pair only** to user |
| Sell principal | BPT → protocol | **Withdraw both → tokens to rebasing** → wing deposit → claim |
| Reward token | Free **DETF** | Free **DETF** |
| effectiveShares | f(BPT, lock bonus) | f(**pair principal at open**, lock bonus) |
| `claimRewards` | Free DETF anytime | **Same** |
| Protocol id 0 / compound | BPT path | Free DETF → **deposit into rebasing managed LP** |
| Claim product | Rebasing on BPT / SE shares | **Rebasing package** (listing LP manager; pair-settled) |

#### Inventory mint sources

1. Usage fee → feeTo  
2. **inventoryDetf** → bond NFT vault  
3. Primary: user free DETF to minter; bond-open: user net DETF → DETF-side OOR LP  

---

## Pricing (normative)

### Gross DETF quote (LOCKED)

```text
pairTokenNotional  →  (+ seigniorage boost on pair notional)
                   →  R = creation rate (B unusable) | TWAP (B usable)
                   →  grossDetf
                   →  usage fee + mint split (Single SE spirit)
```

| | Single SE (Balancer) | This family (Uni V4 listing) |
|--|----------------------|-----------------------------|
| Curve / mark **in** | Vault share (reserve leg) | **`pairToken`** (listing leg) |
| Curve / mark **out** | DETF | DETF |
| After gross | Fee + inventory split | **Same spirit** |
| Inventory asset held | Share (+ DETF self-leg in pool) | **Backing SE shares on DETF** (not in listing pool) |

Bond-open: `pairTokenNotional` = pair deposited at open.  
Primary mint: see **settlement** below — user pays Backing SE share or Backing SE-accepted token; sizing stays in **pairToken** space via R.

### Primary mint settlement (LOCKED)

**Surface (Single SE spirit):** `tokenOut = detfToken`. User pays either:

| `tokenIn` | Allowed |
|-----------|---------|
| **Backing vault share** | Yes — pull shares onto DETF as inventory |
| Any token in Backing SE `tokens()` (includes **`pairToken`**) | Yes — `BackingSE.exchangeIn(tokenIn → vaultShare)` onto DETF as inventory |
| Anything else | **UnsupportedRoute** |

**Two roles (do not conflate):**

1. **Inventory settlement** — always ends with **Backing SE vault shares custody on the DETF diamond**.  
2. **Gross DETF size** — always from **`pairTokenNotional` × R** after seigniorage boost on that notional; then usage fee + mint split.

**How `pairTokenNotional` is chosen (LOCKED):**

| `tokenIn` | `pairTokenNotional` |
|-----------|---------------------|
| **`pairToken`** | `amountIn` (exact pair paid) |
| **Backing vault share** or **other Backing SE token** | Backing SE **preview** exact-in of `tokenIn → pairToken` for `amountIn` |

Then:

1. Policy mint gate if applicable (Open: skip).  
2. Resolve inventory shares as above; custody on DETF.  
3. `grossDetf = quote(pairTokenNotional, R)` with boost → fee split.  
4. Mint: user free DETF → recipient; feeTo free DETF; inventory DETF → bond vault.  
5. Shares are **never** inputs to R.

**First primary mint / live (LOCKED):**  
Live is established by the **first successful primary mint that deposits backing vault-share inventory**. That **first** mint is **synthetically ungated** (both Policy and Open). Listing-pool depth is **not** required. After live, Policy thresholds apply as usual.

### Primary burn (LOCKED — Single SE mirror; plain language)

**Not synthetic price.** Synthetic is only for Policy mint/burn *gates*. Burn **payout size** is a simple **fair-share of Backing SE share inventory**.

1. Require live + burn gate (Open: always allowed when live).  
2. Pull DETF; burn DETF.  
3. Pay a **fraction of the diamond’s backing vault-share inventory**:

```text
sharesOut = detfYouBurn * vaultSharesHeldByDiamond / totalDetfSupply
```

4. If `tokenOut` is backing vault share → transfer those shares.  
5. If `tokenOut` is another Backing SE-accepted token → redeem via Backing SE.  
6. Else UnsupportedRoute. Enforce `minOut`.

**Rules:**

- Use **pre-burn** `totalDetfSupply` so preview == execution.  
- `totalDetfSupply` is the full ERC-20 supply (includes DETF sitting in bond LP or rebasing). Numerator is **only** Backing SE shares held by the **DETF diamond**.  
- Empty inventory / zero payout → revert.  
- **Do not** use listing TWAP/R or synthetic to set `sharesOut`.

### Synthetic

- TWAP over **`twapSeconds` (default 1800)** when usable → 1e18-scaled synthetic.
- Else **1e18**.
- **Policy:** mint/burn/bond-open DETF mint gated when live; **Open:** no synthetic gates when live; **first primary mint** ungated both modes.
- Synthetic tracks listing DETF/`pairToken` mark only — **no** vault-share term.

---

## Bond lifecycle (normative)

### Position ownership (LOCKED)

- **Bond NFT package** is the Uni V4 PoolManager position **owner** for both user legs while the bond is open (salts per tokenId).  
- DETF diamond orchestrates open/close/sell via the NFT package APIs.  
- On **sell**, the NFT package **fully withdraws** both positions and **sends pair + DETF tokens** to the rebasing package; rebasing **deposits** into standard wings and mints claim (see Rebasing). **Not** a PoolManager position ownership transfer / migrate of live liquidity.

### Wing ↔ token (LOCKED — pool-determined)

Uniswap V4 decides single-sided composition from tick range vs current price and `currency0` / `currency1` order:

| Current price vs range | Position is 100% |
|------------------------|------------------|
| Price **above** range (`tick ≥ tickUpper`) | **token0** |
| Price **below** range (`tick < tickLower`) | **token1** |
| In range | both |

**Product rule:** open the OOR wing whose single-sided asset is `pairToken` for the pair leg, and the opposite wing for the DETF leg. Do **not** hardcode “pair = lower wing.”

Outer half-width uses the same `widthMultiplier * tickSpacing` spirit as Uni V4 SE. Ranges fixed at open-time current tick for the life of the bond (no rebalance while open).

### Open

1. User pays **`pairToken`**.  
2. Mint bond NFT `tokenId` (owned by user; NFT contract owns pool positions).  
3. Quote/mint DETF from **pairToken notional** with **typical modifiers**; **Policy** mint gate same as primary mint; **Open** ungated. Seigniorage split: feeTo free; inventory → bond vault; **user net DETF** reserved for DETF leg.  
4. Open **pair-side** OOR position: owner = bond NFT, `salt = keccak256(abi.encode(tokenId, pairToken))`.  
5. Open **DETF-side** OOR position: owner = bond NFT, `salt = keccak256(abi.encode(tokenId, detfToken))`.  
6. Record principal metadata for rewards (effectiveShares).  

### effectiveShares (LOCKED)

- **Base principal** = **pairToken amount deposited** into the pair-side position at open (fixed for weighting).  
- **effectiveShares** = principal × lock-bonus factor (fee oracle min floor / max clamp — same spirit as `DETFBondNFTMathLib`).  
- DETF leg size does **not** add separate reward weight (do **not** value DETF wing in pair and double-count).  

### Rewards while open (LOCKED)

- While the bond is **open**: accrues free DETF via inventory ledger; user may **`claimRewards` anytime**.  
- On **maturity close** or **sell → rebasing claim**:  
  1. Settle/pay **all pending rewards** to user (or designated recipient),  
  2. Then close or withdraw principal,  
  3. Bond loses claim on **future** inventory rewards.  

### Maturity close (UNLOCK principal) — full only (LOCKED)

**No partial close.**

1. Pending rewards → user.  
2. Withdraw **both** positions fully.  
3. **Burn all DETF** recovered from **either** leg (protocol does not keep free DETF on user maturity close).  
4. Send user **only pairToken** recovered from both legs (any pair from the DETF leg included).  
5. Burn/retire NFT; stop reward accrual.  

### Sell → rebasing claim — full only (LOCKED)

**No partial sell.** Protocol wants to **keep** DETF liquidity (via rebasing manager), not burn it.

1. Pending rewards → user.  
2. **Withdraw both** dual-salt PoolManager positions fully (NFT package / DETF orchestrator).  
3. Transfer **all recovered pairToken + all recovered DETF** to the **rebasing package**.  
4. Rebasing package **deposits** those balances into its **standard managed wings** (center/wings strategy adapted from Uni V4 SE).  
5. Mint **rebasing claim** to user from **ZapOut-to-pair contribution** (SE-style share math; first depositor mirrors Uni V4 SE).  
6. Retire bond NFT; no further bond rewards.  

Privileged intake APIs on rebasing (`absorbBondProceeds`, `donateDetf`) are **onlyDETF / Ownable owner = DETF diamond** (not Uni V4 SE).

### widthMultiplier (LOCKED)

- Same semantics as Uni V4 SE vault strategy (`widthMultiplier >= 1`, outer half-width = `widthMultiplier * tickSpacing / 2`, etc.).  
- Both bond legs use that **same** multiplier.  
- Deploy-time PkgArg on DETF / bond / rebasing wiring as needed.  

---

## Rebasing claim package (LOCKED v0.19)

### Why not Uniswap V4 Standard Exchange Vault

Uni V4 SE zap-out burns pro-rata LP and **swaps** the non-desired leg to fulfill `tokenOut`. That **always sells** the other leg and shrinks depth in a single step.

This product wants the rebasing surface to **hold listing liquidity for itself** and only sell DETF as a **last resort** when needed to honor the claim obligation.

**Accounting vs execution (LOCKED):**

| Layer | Rule |
|-------|------|
| **Accounting / obligation** | Claim value uses a **ZapOut-to-pair** calculation, because that is what redemption **could** fully realize if DETF must be sold |
| **Execution** | A **ladder** of wing withdrawals tries to pay pair **without** selling DETF; sell DETF only for any shortfall |

**Do not** deploy `UniswapV4StandardExchangeDFPkg` as the claim reserve. **Do** partially replicate SE behavior inside `…/common/rebasing/`:

| Reuse from Uni V4 SE (behavioral) | Custom for rebasing |
|-----------------------------------|---------------------|
| Share accounting for held managed liquidity | Redeem ladder (below) |
| Deposit workflow (pair and/or DETF into wings) | Pair wing → center → DETF wing order |
| Wing strategy / `widthMultiplier` | Redeposit **all residual DETF** after redeem |
| Pro-rata / ZapOut math for valuation | Sell **just enough** DETF only if still short |
| | Bond sell: **token intake** (`absorbBondProceeds`) → wing deposit (not position migrate) |

### Listing pool identity

Rebasing managed LP **must** be on the **same** listing pool used for DETF price source (`PoolKey` DETF / pairToken).

### Who may deposit (LOCKED)

**Anyone** may deposit to mint rebasing claim shares:

| `tokenIn` | Allowed |
|-----------|---------|
| **`pairToken`** | Yes — SE-style deposit into managed wings |
| **`detfToken`** | Yes — SE-style deposit into managed wings |
| Other | No (v1) |

Bond sell is an additional intake path (withdraw bond LP → tokens in → wing deposit → mint claim), not the only path.

### Claim denomination (LOCKED)

- Rebasing claims are **only for `pairToken`**.  
- Redemption always pays **`pairToken`** (never DETF to the redeemer as the claim asset).  

### Claim obligation / share value (LOCKED)

For a redeem of `sharesBurned` claim shares:

```text
obligationPair = sharesBurned * ZapOutToPair(fullManagedReserve) / totalClaimSupply
```

- `ZapOutToPair(fullManagedReserve)` = value of exiting the **entire** managed reserve to `pairToken` (same spirit as Uni V4 SE full zap-to-pair: exit L + convert any DETF to pair at market).  
- Previews use the same formula.  
- Execution must be able to deliver **`obligationPair`** (subject to `minOut` / slippage guards), using the ladder below — including last-resort sell if required.

### Redeem path (LOCKED — ordered ladder)

When burning claim shares for `pairToken` out, size **`obligationPair`** as above, then:

1. **Pair-token wing** — withdraw from the managed wing associated with **pairToken** (pool-determined) until obligation is met or the wing is exhausted for this redeem.  
2. If still short → **center wing** — withdraw as needed.  
3. If still short → **DETF-token wing** — withdraw as needed.  
4. If still short → **sell just enough DETF** on the listing pool for the remaining pair shortfall (not a full unnecessary dump).  
5. **Send `pairToken` only** to the recipient (`obligationPair`, enforcing `minOut`).  
6. **Redeposit all residual DETF** recovered from **any** wing (and any unsold DETF after step 4) into **standard managed wings** via the SE-style deposit workflow.

**Token handling on every withdraw (LOCKED):**

- Any wing **may** return **both** tokens (e.g. when price has moved so a range is in-range, or fee dust).  
- All **pairToken** recovered counts toward meeting `obligationPair`.  
- All **DETF** recovered is held for step 4 (sell just enough if needed) and/or step 6 (redeposit residual).  
- **Never** send DETF to the claim redeemer.

**Preview == execution** discipline: deterministic sizing for shares burned / wing pulls / sell amount; document any ≤ few-wei dust only if forced by pool math.

### Bond sell consolidation (LOCKED)

After bond dual-position **full withdraw**:

1. Rebasing package receives **pair + DETF token balances** (`absorbBondProceeds`).  
2. **Deposits** into its **standard wings** (not long-term dual per-tokenId salts for sold bonds).  
3. Mints claim shares for the user from **ZapOut-to-pair contribution** (SE-style; first deposit mirrors Uni V4 SE share mint / inflation guards).  

### Protocol compound (LOCKED)

| Step | Behavior |
|------|----------|
| Accrual | Protocol NFT id 0 earns free DETF on the bond inventory ledger like peers (**ledger weight only** — no dual OOR, no invented pair principal) |
| Compound target | Deposit harvested free DETF into **rebasing managed LP** (DETF deposit workflow / `donateDetf`) |
| Ownership | **Pure donation (LOCKED).** No new claim shares minted to protocol. DETF becomes part of the rebasing reserve; existing claim holders benefit via higher ZapOut-to-pair per share |
| Triggers | **Lazy** on DETF touch points that already update rewards **plus** public **`compoundProtocolRewards()`** (or family-equivalent). **Mandatory `pokeListingOracle()`** at start of compound. |
| Failure | **Best-effort** on lazy hooks (never fail user mint/bond solely because compound reverts) |
| User / fee NFTs | **No** auto-compound — claim free DETF while locked only |

Not Balancer BPT join; not natural expansion (out of scope); not protocol claim-share mint.

### Protocol NFT (id 0) vs rebasing claim

| Surface | Who | What they hold |
|---------|-----|----------------|
| **User bond NFT** | Users | Dual OOR listing LP; free DETF rewards while open; `effectiveShares` = pair × lock bonus |
| **Rebasing claim** | Users | Pair-settled claim on **rebasing managed listing LP** (after sell bond or direct deposit) |
| **Protocol NFT id 0** | DETF protocol | Reward ledger weight only — **not** a dual OOR bond; **not** synthetic pair principal; **not** how users buy claim |

---

## Primary pricing note (LOCKED)

- Vault share is **not** in the listing pool and is **not** the quote/curve in-asset.
- Gross DETF always uses **`pairToken` notional** × listing mark (creation or TWAP under B).
- **`pairToken` must be in Backing SE `tokens()`** (deploy-time).
- **No vault-share NAV** in synthetic or mint quote.
- Single SE parallel: same post-quote mint split; different curve-in asset (**pairToken** here vs vault share there).

Do not re-open.

---

## Do not reuse Balancer packages unchanged

New packages under:

- `detf/protocols/dexes/uniswap/v4/common/nft/`
- `detf/protocols/dexes/uniswap/v4/common/rebasing/`

Learn peer behavior from **production code** (bond vault reward ledger, mint split, lock math; Uni V4 SE deposit/share/wing math), not from outdated Single SE PRD paths. **Do not** subclass Uni V4 SE DFPkg as the rebasing claim.

---

## Liveness

| State | Condition |
|-------|-----------|
| Inert | Deployed; primary mint blocked except the live-establishing first mint |
| Live | Listing pool initialized **and** first successful **primary mint** that deposits backing vault-share inventory |

**Bootstrap first mint:** that first primary mint — same user surface as later mints. Synthetically ungated. Not bond-as-liveness (bonds require live).

Bond is **not** required for live. Uni listing depth is **not** required for live. First listing in-range L for option B is **permissionless** (external LP / bond / rebasing).

---

## Deploy & package auth (LOCKED v0.19)

| Topic | Rule |
|-------|------|
| DETF instance | Immutable / unowned after deploy (no diamondCut owner surface for normal operation) |
| Bond NFT + rebasing packages | **Per DETF instance** in postDeploy; **Ownable (or operable) owner = DETF diamond** for privileged absorb/donate/orchestration; DETF diamond address remains owner even if DETF renounces *its own* admin surface |
| Child package deploy path | **Pure Crane** CREATE3 + `diamondPackageFactory` / DFPkg deploy — **not** vault-registry packages (children are not discovered as Standard Exchange vaults) |
| DETF DFPkg | IndexedEx vault registry path (`indexedexManager.deploy*DFPkg` / `deployVault`) like peer DETFs |
| Facets | CREATE3 via FactoryService |
| Robinhood PoolManager (fork tests) | `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` (`lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`) |

---

## Canonical flows (short)

1. **Deploy** — validate `pairToken ∈ Backing SE.tokens()`; listing pool (`hooks=0`) + listing-oracle ring capacity 32; Backing SE + bond NFT + rebasing (owner=DETF); TWAP=1800; widthMultiplier; fee oracle lock terms.  
2. **First primary mint (live)** — user pays backing share or Backing SE token → inventory + DETF mint from pair-space notional; synthetically ungated; instance goes **live**.  
3. **Later mint/burn** — mint: same settlement; burn: fair-share of diamond backing share inventory ± Backing SE out; Policy/Open gates as locked; poke oracle on mint.  
4. **User bond** — pair + mint DETF from pair notional → dual OOR; `effectiveShares` = pair × lock bonus; claimRewards free DETF; **full close only**.  
5. **Maturity** — withdraw both; burn all DETF; pair only to user.  
6. **Sell bond** — withdraw both → pair+DETF tokens to rebasing → wing deposit → mint pair-settled claim.  
7. **Compound** — poke oracle; donate protocol free DETF into rebasing; 0 claim mint.  
8. **Direct claim mint** — anyone deposits pair or DETF into rebasing → claim shares.  
9. **Claim redeem** — obligation = pro-rata ZapOut-to-pair; ladder pair wing → center → DETF wing → sell just enough DETF; pay **obligation only**; redeposit residual DETF + excess pair.  
10. **External swap / LP** — listing pool; third-party LPs unrestricted (permissionless depth for option B).

---

## PkgArgs (draft)

| Field | Notes |
|-------|--------|
| `standardExchangeVault` / Backing SE | Attached inventory SE |
| `pairToken` | ERC-20; **must be in** Backing SE `tokens()` (deploy validate) |
| `poolFee`, `tickSpacing` | Listing pool |
| `hooks` | **Must be `address(0)`** in v1 (or omit / force zero; revert if non-zero) |
| `sqrtPriceX96` | Required creation exchange rate |
| `twapSeconds` | **1800** locked |
| `thresholdMode`, thresholds | Shared policy (Open = no gates when live) |
| Bond NFT package ref | `…/common/nft/` |
| Rebasing package ref | `…/common/rebasing/` (listing LP manager + claim ERC-20) |
| `widthMultiplier` | Bond OOR + rebasing wings |
| Listing-oracle ring capacity | postDeploy allocate **32** slots (app-level; not PoolManager cardinality) |

**Removed (v0.17):** `uniswapV4StandardExchangeVault` as claim/migrate SE PkgArg.

---

## Testing expectations

1. First primary mint (backing share or Backing SE token) → live without listing depth; synthetically ungated; inventory shares on DETF.  
2. Mint with `tokenIn = pairToken` and with `tokenIn = backingVaultShare` / other Backing SE token; pair notional rules; preview == execution.  
3. Burn: fair-share `sharesOut = detfIn * shareBal / totalSupply` (not synthetic); tokenOut share and Backing SE-accepted asset; empty inventory reverts.  
4. After two-sided **in-range** liquidity + listing-oracle TWAP ready (pokes + ≥1800s): mint size and synthetic follow market mark; Policy gates; Open never gates.  
5. Quote never uses vault share as curve in-asset for R.  
6. Deploy **reverts** if `pairToken` not in Backing SE `tokens()`.  
7. User bond: dual OOR; pool-determined wings; salts; `effectiveShares` = pair × lock bonus; **full** maturity: burn all DETF, pair only to user; claimRewards free DETF; **no** partial close.  
8. Sell→claim: full withdraw both positions; pair+DETF tokens to rebasing; wing deposit; mint claim; NFT retired.  
9. Rebasing: anyone deposits pair or DETF → claim (first deposit mirrors Uni V4 SE); redeem obligation = pro-rata ZapOut-to-pair; ladder pair → center → DETF wing → sell just enough DETF; pay **obligation only**; redeposit residual DETF + excess pair.  
10. Rebasing LP is on the **same** listing pool as price source.  
11. Backing SE is never the rebasing manager; Uni V4 SE DFPkg is not the claim package.  
12. Protocol id 0 = ledger only (no synthetic pair principal); compound = pure donation + poke (no protocol claim mint; best-effort lazy + public).  
13. Listing pool has **zero hooks**; external LP unrestricted; first listing L for option B permissionless.  
14. Fee + incentive ordering (boost on pair notional before quote); lock terms from fee oracle.  
15. Backing SE test matrix = Uni V4 SE only; hermetic Crane + Robinhood fork (`ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER`); no SUT mocks.

---

## Differences from Balancer Single SE

| | Balancer Single SE | This family |
|--|--------------------|-------------|
| Reserve | Self-leg weighted pool | Backing SE share inventory + Uni listing |
| Quote / curve in-asset | Vault **share** | **`pairToken`** (listing leg; Backing SE–accepted) |
| Pre-market price | N/A (bond bootstrap) | **Creation exchange rate** |
| Market price | Pool curve / FD synthetic | **TWAP** from **DETF listing-oracle ring** (app-level; not V4 core observations) |
| Live | First bond | First backing vault-share deposit |
| User bond principal | Reserve **BPT** | **Dual OOR listing LP**; maturity burns DETF; sell = **token withdraw → rebasing deposit** |
| Claim / protocol liquidity | BPT / SE path | **Rebasing package** on listing pool (not Uni V4 SE vault) |
| Claim redeem | Family-specific | Pair only; ZapOut obligation; pair→center→DETF wing; sell just enough DETF; redeposit residual DETF |
| NFT/claim code | Balancer-era packages | **New** under `…/common/nft/` + `…/common/rebasing/` |
| Listing hooks | N/A | **None** (`address(0)`) |

---

## Cardinality bootstrap (LOCKED: at deploy)

### Product pricing rule (unchanged)

**Init exchange rate until option B is usable** (TWAP available from listing-oracle ring **and** `liquidity > 0`).  
Synthetic **1e18** while B is false.

### Deploy bootstrap (LOCKED)

postDeploy **allocates the DETF listing-oracle ring** with capacity **32** so the instance *can* store a 1800s TWAP once enough time has passed and pokes have written samples. **Not** a PoolManager `increaseObservationCardinalityNext` call (N/A on V4 core).

### Why init pricing still exists after bootstrap

Bootstrap only allocates **buffer capacity**. It does **not** invent 30 minutes of past prices, satisfy `liquidity > 0`, or make TWAP(1800) valid at `t = 0`.

| Time | Ring capacity | `liquidity` | Mint size source |
|------|---------------|-------------|------------------|
| Deploy | 32 | 0 | **Init rate** (B false) |
| +10 min, some LP in range, sparse pokes | 32 | > 0 | **Init rate** (TWAP window not full yet) |
| +30+ min, L still > 0, pokes span ≥1800s | 32 | > 0 | **TWAP** (B true) |

---

## Remaining before LOCK

- [x] Pricing, TWAP 1800, option B, listing-oracle ring cardinality 32  
- [x] Backing SE (any) always distinct from rebasing package  
- [x] Seigniorage inventory → bond vault; claimRewards  
- [x] Dual OOR bonds; NFT owns positions; pool-determined wings; same widthMultiplier  
- [x] effectiveShares = pair deposited × lock bonus only (no DETF-leg weight)  
- [x] Maturity close: burn all DETF; pair only to user; full close only  
- [x] Sell: withdraw both → pair+DETF tokens to rebasing → wing deposit → mint claim  
- [x] Synthetic = (P_twap / P_creation) × 1e18; no vault-share NAV  
- [x] Quote/curve in-asset = **`pairToken`**; vault shares = inventory only  
- [x] **`pairToken ∈ Backing SE.tokens()`** at deploy  
- [x] Listing hooks = **`address(0)`**; TWAP from **DETF listing-oracle ring** (not V4 core observations)  
- [x] Open = no synthetic gates; Policy gates primary mint/burn **and** bond-open  
- [x] External market LPs permissionless; first listing L for option B permissionless  
- [x] Primary mint settlement; burn fair-share inventory; live = first primary mint  
- [x] Rebasing package **not** Uni V4 SE; SE-style deposit/share math; custom redeem  
- [x] Claim settles **pairToken only**; obligation = pro-rata ZapOut-to-pair; redeem pays obligation only  
- [x] Redeem ladder: pair wing → center → DETF wing → sell just enough DETF → pair out → redeposit residual DETF + excess pair  
- [x] Any wing may return both tokens; pair toward obligation; DETF never to redeemer  
- [x] Anyone may deposit pair or DETF to mint claim; first deposit mirrors Uni V4 SE  
- [x] Bond sell absorb via **token intake** APIs on rebasing (not PoolManager position migrate)  
- [x] Protocol id 0 = ledger only (no synthetic pair principal); compound = pure donation + poke  
- [x] Maturity burn all DETF vs sell keep DETF in rebasing (fee-split table)  
- [x] Quote direction / R applies to mint/bond-open only (not primary burn, not claim)  
- [x] Package paths: `…/common/nft/`, `…/common/rebasing/`  
- [x] Child packages: Ownable owner = DETF; pure Crane deploy (not vault registry)  
- [x] Lock terms from fee oracle  
- [x] Robinhood PoolManager pin: `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER`  
- [ ] Optional: formal LOCK stamp from product owner  

**Material product Q&A: resolved through v0.19.** Ready to mark **LOCKED** on your word. Implementation law: colocated plan.

---

## Revision history

| Version | Date | Notes |
|---------|------|-------|
| v0.1–v0.11 | 2026-07-31 | Iteration history (pricing, bonds, fees, revert SE-share-only) |
| v0.12 | 2026-07-31 | Bond NFT owns LP; rewards close rules; successive import; synthetic formula; id 0 vs claim clarified |
| v0.13 | 2026-07-31 | Gross DETF from **`pairToken` notional** × listing mark; vault shares inventory-only |
| v0.14 | 2026-07-31 | **`pairToken` must ∈ SE.tokens()`**; hooks=`address(0)`; full bond close only; Open ungated; TWAP via observations |
| v0.15 | 2026-07-31 | Mint settlement; burn fair-share inventory; live = first primary mint; protocol compound notes |
| v0.16 | 2026-07-31 | Path → `…/standardExchange/single/`; same-address primary/claim SE allowed (later superseded) |
| v0.17 | 2026-08-01 | **Backing SE** naming; always distinct from claim; **rebasing package** (not Uni V4 SE) holds listing LP; claim **pair only**; sell transfers L to rebasing + consolidate; packages under `common/nft` + `common/rebasing` |
| v0.18 | 2026-08-01 | Redeem ladder pair→center→DETF wing→sell just enough DETF; obligation formula; residual DETF redeposit; any wing may return both tokens; protocol compound pure donation; maturity burn vs sell keep table; quote/R mint-only wording |
| v0.19 | 2026-08-01 | **App-level listing-oracle ring** + poke (not V4 core observations); sell = **full withdraw → tokens to rebasing**; id 0 ledger-only (no synthetic pair principal); pair-only effectiveShares; child Ownable→DETF; pure Crane child deploy; fee-oracle lock terms; mandatory poke on compound; permissionless first listing L; Robinhood PoolManager pin |

---

## Approval

| Role | Sign-off |
|------|----------|
| Product | Pending — mark LOCKED when ready |
| Protocol | Pending |

**Status DRAFT v0.19 — ready for LOCK.**
