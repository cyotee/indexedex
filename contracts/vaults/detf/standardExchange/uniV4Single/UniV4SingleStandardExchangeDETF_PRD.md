# Product Requirements Document (PRD)

## Title

**UniV4SingleStandardExchangeDETF** (Uniswap V4–listed Single Standard Exchange DETF)

## Status

**DRAFT v0.11** — **Reverted** v0.10 SE-share-only bonds. Restored per-bond **dual out-of-range listing positions** so maturity can **return pair + burn DETF**. Refine next.

| Related | Role |
|---------|------|
| [`SingleStandardExchangeDETF_PRD.md`](../single/SingleStandardExchangeDETF_PRD.md) | Behavioral reference only — **not** a subclass base |
| [`DETF_Threshold_Modes_PRD.md`](../../DETF_Threshold_Modes_PRD.md) | ThresholdMode Policy/Open law |
| Uni V4 SE vault | `contracts/protocols/dexes/uniswap/v4/` — claim / protocol id 0 / migrate path (not per-user bond LP) |
| New bond/claim packages | `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/` — **new** NFT + rebasing claim |

---

## Product one-liner

A Single Standard Exchange DETF that:

1. Holds **SE vault shares** as reserve / claim backing.
2. **Lists** itself on Uniswap V4 as `DETF / pairToken` (`pairToken` = any ERC-20; **whether it is inside the SE vault does not matter**).
3. **Mints DETF** using a simple **exchange rate**: the pool’s **initialized price**, until the pool has **liquidity from which to price**; then uses that market mark (TWAP when usable).
4. **Policy gates** use TWAP synthetic (fallback when unusable).
5. **Bonds (restored):** user pays **`pairToken`**, protocol **mints DETF**, opens **two out-of-range listing-pool positions** (salts `keccak256(tokenId, token)`); maturity **returns pair, burns DETF**. Protocol id 0 / claim still use Uni V4 SE vault.

---

## Plain-language pricing (no “linear function” jargon)

### What “initialized price” means

When the Uni V4 pool is created, the deployer sets a starting price, e.g.:

> “1 DETF is worth X of `pairToken`”  
> (encoded on-chain as `sqrtPriceX96`)

That is just an **exchange rate** — like a fixed menu price.

### When is that rate used?

| Pool state | Price used to size primary mint/burn |
|------------|--------------------------------------|
| **Option B unusable** (no 1800s TWAP and/or `liquidity == 0`) | **Creation exchange rate** |
| **Option B usable** (TWAP ready **and** `liquidity > 0`) | **TWAP** from the listing pool |

So: **fixed menu price until TWAP is usable under B; then the market TWAP.**

Fees and seigniorage incentive still adjust the final user amount (input boost → quote → fee split), same spirit as other DETFs.

### What we are *not* doing

- We are **not** walking the Uniswap concentrated-liquidity book tick-by-tick to compute primary mint size like a swap router.
- We are **not** valuing the SE vault share in `pairToken` via a second oracle for the mark.
- Whether `pairToken` is an underlying of the SE vault is **irrelevant** for mint pricing and for listing.

### Synthetic (gates only)

| Condition | Synthetic for Policy mint/burn gates |
|-----------|--------------------------------------|
| TWAP usable | TWAP of DETF vs `pairToken`, scaled to abstract **1e18** peg narrative |
| TWAP / mark unusable | **`1e18` fallback** |

Bootstrap **first mint** remains **synthetically ungated**.

---

## TWAP window (LOCKED)

| Setting | Value |
|---------|--------|
| **`twapSeconds`** | **1800 (30 minutes)** |
| PkgArgs | Store 1800; allow explicit override only if a later PRD opens it — v1 default is fixed **1800** |
| Observation cardinality | **Bootstrap at deploy (LOCKED)** — grow buffer so a 1800s TWAP *can* be stored once enough **time** has passed (see Cardinality) |

**Primary mint size** (once market mark is usable under **B**) uses TWAP, same family as gates.

**v1 thin-book controls:** TWAP + creation-rate / 1e18 fallback only (no max-impact caps).

---

## Usable market mark (LOCKED — option B)

**Market mark is usable iff all of:**

1. Listing pool initialized  
2. **TWAP over 1800s is available** (enough **wall-clock history**, not merely a large buffer)  
3. **Active in-range liquidity `liquidity > 0`** at current tick  

Otherwise **unusable**.

| | Unusable | Usable (B) |
|--|----------|------------|
| Primary mint/burn **size** | **Creation exchange rate** | **TWAP** |
| Policy **synthetic** | **1e18** | TWAP → 1e18-scaled |

Bootstrap first mint remains synthetically ungated.

### Cardinality bootstrap ≠ TWAP ready at t=0

**Deploy-time cardinality bootstrap is LOCKED** (grow the observation ring so 1800s of samples *can* fit).

That does **not** remove init pricing:

| Myth | Reality |
|------|---------|
| “Buffer is large ⇒ TWAP works immediately” | **False.** TWAP(1800) needs **~1800 seconds of elapsed time** with observations written. At second 0 after deploy there is no “price 30 minutes ago.” |
| “Bootstrap ⇒ never use init price” | **False.** Until B holds (time + TWAP available + `liquidity > 0`), mint size still uses **creation exchange rate**; synthetic still **1e18**. |

So: bootstrap makes TWAP *possible* after ~30 minutes (and with active L). Init pricing remains the correct pre-TWAP path.

---

## Locked decisions

Do not re-open without PRD revision once **LOCKED**.

### Product & topology

| Topic | Decision |
|-------|----------|
| Family name | `UniV4SingleStandardExchangeDETF` |
| Primary reserve SE | **Any** `IStandardExchange` (`standardExchangeVault` PkgArg) — vault shares held for primary mint/burn inventory |
| Claim / migrate SE | **Separate** Uni V4 Standard Exchange vault (`uniswapV4StandardExchangeVault` or equiv. PkgArg) at `contracts/protocols/dexes/uniswap/v4/` — claim deposits, NFT position import, protocol id 0 path |
| Reserve / claim backing | Primary path: attached SE shares. Claim path: Uni V4 SE shares held by DETF |
| Listing | Uniswap V4 `DETF / pairToken` |
| `pairToken` | Any ERC-20 PkgArg. **No requirement** that it be in the SE vault. **Irrelevant** to mint pricing logic whether it is or not |
| Pool init | postDeploy `initialize` with required `sqrtPriceX96`, **pool fee**, tickSpacing, hooks |
| Listing pool fee | **One universal Uni swap fee** from **PkgArgs** (`poolFee`) for the listing `PoolKey` (market LPs + any SE-managed position on that pool). Not per-bond |
| Hooks (v1 listing pool) | Vanilla / zero hooks unless later required |
| Instance governance | Immutable, unowned |
| Deploy path | CREATE3 facets; DFPkg via vault registry / manager |

### Pricing & thresholds

| Topic | Decision |
|-------|----------|
| Pre-liquidity / unusable mark primary price | **Creation exchange rate** (`sqrtPriceX96` at init) |
| Usable market primary price | **TWAP** when option **B** holds |
| Usable mark predicate | **B (LOCKED):** TWAP-ready **and** `liquidity > 0` |
| Synthetic gates | TWAP when B; else **1e18** |
| Default TWAP window | **1800 seconds (LOCKED)** |
| ThresholdMode | Policy + Open; defaults 1.05e18 / 0.95e18 via shared policy |
| Bootstrap first mint | Synthetically ungated |
| Live | Pool init + first vault-share primary deposit; **depth not required** |
| Seigniorage incentive | Input boost **before** quote |
| Protocol usage fee (primary mint/burn) | Vault Fee Oracle / peer DETF usage fee path (not the Uni pool fee) |
| Protocol fee / seigniorage split | Same as Single SE: usage → feeTo; **inventory DETF → bond vault reward pool**; remainder per path below |
| O9 | TWAP + fallback only |

### Bond / claim (restored dual listing positions — refine next)

| Topic | Decision |
|-------|----------|
| Bond purpose | Raise **listing-pool** liquidity; enable **burn DETF on close** |
| Bond `tokenIn` | **`pairToken`** |
| User bond LP | **Two** out-of-range positions on listing pool: pair leg + DETF leg |
| Salts | `keccak256(abi.encode(tokenId, pairToken))` and `keccak256(abi.encode(tokenId, detfToken))` |
| Range | Outside current tick via Uni V4 SE–style **`widthMultiplier`** (PkgArg on DETF instance) |
| Bond-open DETF | Mint proportional DETF; **user net** → DETF-side OOR LP; **inventory** → bond vault rewards; **feeTo** free DETF |
| Maturity unlock | **Return pairToken**; **burn DETF** from DETF-side leg (no free DETF principal back) |
| `claimRewards` | Free DETF seigniorage rewards anytime (separate from principal) |
| Protocol NFT id 0 | Via **Uni V4 SE vault** (not dual salts) — claim/compound path |
| Sell NFT → claim | Migrate **both** listing positions into Uni V4 SE → rebasing claim |
| Rebasing claim | Pro-rata on **Uni V4 SE shares** held by DETF/protocol |
| When bond allowed | After **live** |
| **Superseded (v0.10)** | “All bonds = SE shares only, no per-user listing LP” — **reverted** (blocked easy DETF burn on close) |

### Package layout

| Path | Contents |
|------|----------|
| `contracts/vaults/detf/standardExchange/uniV4Single/` | DETF family (facets, DFPkg, this PRD, TestBase) |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/` | **Shared** Uni V4 DETF bond NFT + rebasing claim (new) |
| `contracts/protocols/dexes/uniswap/v4/` | Existing **Uniswap V4 Standard Exchange** vault (protocol id 0 position path) |

---

## Purpose

- Attach one Standard Exchange vault as inventory / claim backing.
- Self-list DETF on Uni V4 vs any `pairToken`.
- Mint/burn at creation exchange rate until the pool can price; then at market mark; plus peer-style fees/incentives.
- Policy/Open synthetic gates via TWAP.
- Bonds: dual OOR listing positions (pair + DETF); free DETF rewards; maturity burn DETF; claim via Uni V4 SE.

---

## Naming rule

### Role names only

| Role | Meaning |
|------|---------|
| `detfToken` / `address(this)` | DETF diamond ERC-20 |
| `standardExchangeVault` | Attached SE (user’s chosen vault; may be Uni V4 SE or any SE) |
| `standardExchangeVaultShare` | That vault’s share token |
| `pairToken` | Listing counter-asset (any ERC-20) |
| `listingPool` / `poolKey` / `poolId` | Uni V4 DETF/`pairToken` pool |
| `creationSqrtPriceX96` | Init exchange rate for pre-liquidity mint |
| `bondNft` | Uni V4 DETF bond NFT (new package) |
| `bondTokenId` | NFT id; dual salts `keccak256(tokenId, token)` |
| `widthMultiplier` | PkgArg — OOR band distance for user bond legs |
| `uniswapV4StandardExchangeVault` | Claim / id 0 / migrate SE |
| `detfBondTokenId` | **Always 0** — protocol DETF NFT |
| `rebasingClaimToken` | Claim on Uni V4 SE shares held by DETF/protocol |

**Anti-patterns:** brand tickers; requiring primary SE contains pairToken; treating user dual-position bonds as id 0 SE path.

### Opacity

- Primary SE: `IStandardExchange*` only.
- Listing pool: pricing + **user bond LP**.
- Id 0 / claim: Uni V4 SE vault package.

---

## Scope

### In scope (v1)

- `standardExchange/uniV4Single/` DETF package
- `detf/protocols/dexes/uniswap/v4/common/` **new** bond NFT + rebasing claim
- Integration with Uni V4 SE for **claim / id 0 / migrate**
- Listing pool init; creation-rate then market-mark mint/burn
- TWAP synthetic (default 30m) + 1e18 fallback; Policy/Open
- User bonds: dual OOR listing positions; free DETF rewards; burn DETF on unlock
- Production-first tests

### Out of scope (v1)

- All-bonds-as-SE-shares-only (v0.10, reverted)
- Bond-as-liveness bootstrap
- Uniswap V3 listing
- Custom listing-pool hooks that replace the CL curve (unless later PRD)
- Max-impact / per-tx size caps
- Multi-vault composition
- Natural expansion / Balancer protocol compound PRDs
- Cross-chain
- Mocks of SUT

---

## Topology

```
  Primary SE (any) ──vault shares──► DETF diamond (primary inventory)
                                           │
                    listing / TWAP / user bonds
                                           ▼
                         Uniswap V4 listing pool
                         DETF ↔ pairToken
                         • market LPs optional
                         • user bond: 2× OOR positions
                           salt = keccak256(tokenId, token)
                                           │
                    sell/migrate / id 0 / claim buy
                                           ▼
                    Uni V4 Standard Exchange vault
                    • SE shares for claim + protocol id 0
                                           │
                         Bond NFT rewards = free DETF ledger
                         claimRewards anytime while locked
```

---

## Token model

- Diamond **is** the DETF ERC-20.
- Name/symbol: deploy args.
- Free DETF (unlocked) vs bonded (in NFT / positions) vs claim (rebasing) are distinct surfaces.

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
| **A. Uniswap listing pool fee** | Swap fee tier on the DETF/`pairToken` pool (`PoolKey.fee`) | **PkgArgs `poolFee`** at deploy | Every swap on that pool; market LPs and SE vault liquidity on that pool. **One universal fee** per listing |
| **B. DETF protocol fees** | Usage fee, seigniorage incentive, mint split | **Vault Fee Oracle** | Primary mint/burn; **also** DETF minted on bond-open |

### A — Universal Uni pool fee (LOCKED)

- Set once via **PkgArgs `poolFee`** when the listing pool is initialized (same arg used for the whole `PoolKey`).
- In Uniswap V4, fee is part of **pool identity**, not per position. Every position on that pool (pair-side bond leg, DETF-side bond leg, external LPs) shares **this one fee**.
- There is no separate “bond position fee” vs “initial DETF-only position fee.” One pool ⇒ one fee from PkgArgs for the life of that listing.

### B — Protocol fees: bond mint vs primary mint (what the old open item meant)

This was **not** about Uni swap fees. It only asked:

> When bond-open **mints DETF**, does that mint pay the same **usage fee / seigniorage incentive / split** as a user primary mint (e.g. vault share → DETF)?

**LOCKED:** **Same protocol fee family as primary mint** (oracle usage fee + seigniorage input boost + mint split). Bond is not a fee-free DETF mint side door.

**Where the split goes (LOCKED — aligned with Single SE):**

| Slice | Destination |
|-------|-------------|
| **feeTo DETF** | Free DETF to `feeTo()` |
| **inventory DETF** (seigniorage share for bonders) | **Bond NFT vault** as `rewardToken` balance — accrued to open bonds via **effectiveShares** ledger; claimable as free DETF anytime while bonded |
| **User free DETF** (primary mint) | Free DETF to minter |
| **User net DETF** (bond-open) | DETF-side **OOR listing position** (burned on maturity unlock) |

Bond **lock terms** (min/max duration, bonus) stay separate oracle fields, as on peer DETFs.

---

## Seigniorage rewards for bond holders (Uni V4 standard)

### Reference: SingleStandardExchangeDETF (Balancer) — verified behavior

Your understanding is **mostly correct**, with one important precision:

| Concept | What it actually is on Single SE |
|---------|----------------------------------|
| **Bond principal** | **Reserve BPT** (share units on the bond NFT). This is the capital claim on the Balancer reserve (DETF self-leg + vault share). |
| **Reward token** | **Free DETF**, not BPT. On mint/bond, after usage fee, a **seigniorage inventory** slice is **minted to the bond NFT vault** (`inventoryDetf` → `bondNftVault`). |
| **Apportionment** | Bond vault tracks `rewardPerShares` from increases in its **DETF balance**. Each NFT has **effectiveShares** (from principal + lock bonus). Pending = f(effectiveShares, rewardPerShares − paid). |
| **Claim anytime** | `claimRewards(tokenId)` while locked — pulls free DETF to the holder. |
| **DETF / protocol NFT** | Protocol-owned NFT (e.g. id 0) also has effective shares and earns the same reward ledger. Its pending free DETF can be **harvested and compounded** (single-sided DETF join → more BPT on the protocol NFT), separate from user free-DETF claim. |
| **Not** | BPT itself is not dripped as the “reward pool token.” BPT is principal; **DETF inventory on the bond vault** is the reward pool. Effective shares are denominated in principal (BPT-like units). |

Code anchors: `SingleStandardExchangeDETFBondingTarget` mints `inventoryDetf` to `bondNftVault`; `DETFNFTVaultRepo._updateGlobalRewards` / `claimRewards`; protocol compound via `reallocateDetfNftRewards` + DETF-only join.

### Uni V4 DETF standard (this family — dual listing LP bonds)

| Role | Balancer Single SE | Uni V4 DETF (current) |
|------|--------------------|------------------------|
| Bond capital / LP | Reserve **BPT** | **Two OOR listing positions** (pair + DETF), salts `keccak256(tokenId, token)` |
| Close principal | Return BPT claim | **Return pair; burn DETF** leg |
| Reward token | Free **DETF** | Free **DETF** |
| Reward custody | Bond NFT vault | Same pattern (new package) |
| effectiveShares | f(BPT, lock bonus) | f(**pair principal at open**, lock bonus) — refine if needed |
| `claimRewards` | Free DETF anytime | **Same** |
| Protocol id 0 / claim | BPT + compound | **Uni V4 SE shares** + compound free DETF into SE shares |
| Sell NFT → claim | Principal → protocol | **Import both listing positions** into Uni V4 SE → claim |

#### Inventory mint sources

1. Usage fee → feeTo  
2. **inventoryDetf** → bond NFT vault  
3. Primary: user free DETF to minter; bond-open: user net DETF → DETF-side OOR LP  

#### Packages

- New bond NFT under `detf/protocols/dexes/uniswap/v4/common/` tracks dual salts + principal metadata.  
- Reuse harvest/lock math libs where possible.

---

## Pricing (normative)

### Primary mint (vault share → DETF)

1. Optional SE allowlisted `tokenIn` → `exchangeIn` → vault share.
2. Seigniorage **input boost** on share notional.
3. **Exchange rate:**
   - If market mark **unusable** → use **creation** DETF/`pairToken` exchange rate.
   - If market mark **usable** → use **TWAP** (same family as synthetic) as the rate.
4. Apply usage fee + mint split; custody shares on DETF; mint DETF.

### Primary burn (DETF → vault share [+ SE out])

1. Policy burn gate if applicable.
2. Inverse of the same rate rule (creation vs TWAP).
3. Inventory-capped vault shares out; optional SE `exchangeOut`.

### Synthetic

- TWAP over **`twapSeconds` (default 1800)** when usable → 1e18-scaled synthetic.
- Else **1e18**.
- Policy/Open as shared threshold PRD; first mint ungated.

### Usable market mark

See **option B** above (normative). Unusable → creation rate (mint size) + 1e18 synthetic.

---

## Bonding (restored dual OOR listing positions)

### Why not “all SE shares” (v0.10)

Using only Uni V4 SE shares as principal (BPT analog) made **burning DETF on bond close** awkward. Restored listing-pool dual legs so maturity can **return pair and burn DETF**.

### Bond open (LOCKED for now — refine next)

| Item | Decision |
|------|----------|
| User pays | **`pairToken`** |
| Protocol mints | DETF proportional (creation rate or TWAP under B) + fee/seigniorage split |
| Positions | **Two** OOR listing-pool legs |
| Pair leg | User pair → OOR; `salt = keccak256(abi.encode(tokenId, pairToken))` |
| DETF leg | User **net** DETF → OOR other side; `salt = keccak256(abi.encode(tokenId, detfToken))` |
| Range | Outside tick via **`widthMultiplier`** (PkgArg; Uni V4 SE–style) |
| Inventory DETF | → bond vault reward pool |
| feeTo | Free DETF |

### User bond lifecycle

1. Pull pair; mint bond NFT `tokenId`.  
2. Mint gross DETF; split: inventory → bond vault; feeTo free; **user net → DETF-side LP**.  
3. Open pair-side + DETF-side OOR positions (dual salts).  
4. **`claimRewards` anytime** → free DETF rewards.  
5. **Maturity:** close legs → **pairToken to user**; **burn DETF** from DETF leg.  
6. **Sell → claim:** import **both** positions into Uni V4 SE → rebasing claim.  

### DETF NFT (`tokenId == 0`)

- Not dual-salt user LP. Protocol path via **Uni V4 SE vault** (claim inventory / compound).  

### Rebasing claim

- Direct buy: deposit into Uni V4 SE → claim.  
- NFT migrate: import dual listing positions into SE → claim.  

### Do not reuse Balancer packages unchanged

New packages under `detf/protocols/dexes/uniswap/v4/common/` for dual-salt bonds + claim.

---

## Liveness

| State | Condition |
|-------|-----------|
| Inert | Deployed; primary blocked except bootstrap first mint |
| Live | Listing pool initialized **and** first successful primary vault-share deposit |

Bond is **not** required for live. Uni depth is **not** required for live.

---

## Canonical flows (short)

1. **Deploy** — listing pool + cardinality bootstrap; primary SE + Uni V4 SE; bond/claim; TWAP=1800; widthMultiplier.
2. **Bootstrap mint** — ungated; creation rate until B; → live.
3. **Later mint/burn** — creation/TWAP per B; inventory DETF → bond vault.
4. **User bond** — pair + mint DETF → dual OOR positions; claimRewards free DETF.
5. **Maturity** — pair out, burn DETF; **or sell → claim** via SE import.
6. **External swap** — listing pool.

---

## PkgArgs (draft)

| Field | Notes |
|-------|--------|
| `standardExchangeVault` | Attached SE |
| `pairToken` | Any ERC-20 |
| `poolFee`, `tickSpacing`, `hooks` | Listing pool |
| `sqrtPriceX96` | Required creation exchange rate |
| `twapSeconds` | **1800** locked |
| `thresholdMode`, thresholds | Shared policy |
| `uniswapV4StandardExchangeVault` | Claim / id 0 / migrate |
| `widthMultiplier` | User bond OOR placement (PkgArg) |
| Bond NFT + claim package refs | New Uni V4 common packages |
| Cardinality bootstrap | postDeploy for 1800s TWAP capacity |

---

## Testing expectations

1. Creation-rate mint with **empty** pool; live without depth.
2. After two-sided liquidity + TWAP ready: mint size and synthetic follow market mark; Policy gates.
3. User bond: dual OOR positions; salts; maturity pair out + burn DETF; claimRewards free DETF.
4. Protocol id 0 / claim via Uni V4 SE; dual-position import on sell.
5. No all-SE-share-only principal (v0.10).
6. Preview == execution for primary closed forms.
7. Fee + incentive ordering.
8. Production SE matrix + Uni V4 hermetic/fork; no SUT mocks.

---

## Differences from Balancer Single SE

| | Balancer Single SE | This family |
|--|--------------------|-------------|
| Reserve | Self-leg weighted pool | SE share inventory + Uni listing |
| Pre-market price | N/A (bond bootstrap) | **Creation exchange rate** |
| Market price | Pool curve / FD synthetic | **TWAP DETF/pair** |
| Live | First bond | First vault deposit |
| User bond principal | Reserve **BPT** | **Dual OOR listing LP** (pair + DETF); close burns DETF |
| Protocol NFT / claim | BPT path | **Uni V4 SE shares** |
| NFT/claim code | Balancer-era packages | **New** under `detf/protocols/dexes/uniswap/v4/common/` |

---

## Cardinality bootstrap (LOCKED: at deploy)

### Product pricing rule (unchanged)

**Init exchange rate until option B is usable** (TWAP available **and** `liquidity > 0`).  
Synthetic **1e18** while B is false.

### Deploy bootstrap (LOCKED)

postDeploy **increases observation cardinality** so the pool *can* store a 1800s TWAP once enough time has passed. Exact slot count = impl plan / gas tradeoff.

### Why init pricing still exists after bootstrap

Bootstrap only allocates **buffer capacity**. It does **not**:

- invent 30 minutes of past prices at deploy, or  
- satisfy `liquidity > 0` (bonds/LPs still have to add depth), or  
- make TWAP(1800) return a real average at `t = 0`.

Timeline example:

| Time | Cardinality | `liquidity` | Mint size source |
|------|-------------|-------------|------------------|
| Deploy | Bootstrapped large | 0 | **Init rate** (B false) |
| +10 min, some LP in range | Large | > 0 | **Init rate** (TWAP window not full yet) |
| +30+ min, L still > 0, observations OK | Large | > 0 | **TWAP** (B true) |

---

## Remaining before LOCK

- [x] TWAP **1800**  
- [x] Usable mark **B**  
- [x] Cardinality **bootstrap at deploy** (init pricing still until B)  
- [x] Seigniorage rewards: inventory DETF → bond vault; claimRewards free DETF  
- [x] Dual vault: any primary SE + Uni V4 SE for claim/id 0  
- [x] **v0.10 SE-share-only bonds REVERTED** — dual OOR listing bonds restored (burn DETF on close)  
- [ ] **Refine** dual-bond process (effectiveShares definition, sell/import details, etc.)  

**Not ready to LOCK** until dual-bond process is refined.

---

## Revision history

| Version | Date | Notes |
|---------|------|-------|
| v0.1 | 2026-07-31 | Initial draft |
| v0.2 | 2026-07-31 | Closed O1–O9 forms |
| v0.3 | 2026-07-31 | Exchange-rate pricing; salt bonds; new NFT/claim paths |
| v0.4 | 2026-07-31 | TWAP 1800; usable options; claim paths; cardinality explained |
| v0.5 | 2026-07-31 | Option B; pair bond + width multiplier; cardinality hygiene |
| v0.6 | 2026-07-31 | Deploy cardinality bootstrap; dual-salt bonds; proportional DETF mint; widthMultiplier PkgArg |
| v0.7 | 2026-07-31 | Fees split: Uni poolFee (universal PkgArgs) vs protocol usage on bond=primary |
| v0.8 | 2026-07-31 | Dual SE; unlock pair+burn DETF; bond split net→LP free fee DETF |
| v0.9 | 2026-07-31 | Seigniorage rewards: inventory→bond vault; free DETF claim |
| v0.10 | 2026-07-31 | (reverted) All bonds = Uni V4 SE shares only |
| v0.11 | 2026-07-31 | Revert v0.10; restore dual OOR listing bonds for pair return + DETF burn on close |

---

## Approval

| Role | Sign-off |
|------|----------|
| Product | Pending — refine dual-bond process |
| Protocol | Pending |

**Status remains DRAFT — dual-bond model under refinement.**
