# Product Requirements Document (PRD)

## Title

**UniV4SingleStandardExchangeDETF** (Uniswap V4–listed Single Standard Exchange DETF)

## Status

**DRAFT v0.3** — pricing clarified in plain language; Uni V4–native bond/claim model; TWAP default proposed. Not implemented. Iterate until LOCKED.

| Related | Role |
|---------|------|
| [`SingleStandardExchangeDETF_PRD.md`](../single/SingleStandardExchangeDETF_PRD.md) | Behavioral reference only — **not** a subclass base |
| [`DETF_Threshold_Modes_PRD.md`](../../DETF_Threshold_Modes_PRD.md) | ThresholdMode Policy/Open law |
| Uni V4 SE vault | `contracts/protocols/dexes/uniswap/v4/` — used by **DETF bond NFT id 0** for protocol position custody |
| New bond/claim packages | `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/` — **new** NFT + rebasing claim (this family) |

---

## Product one-liner

A Single Standard Exchange DETF that:

1. Holds **SE vault shares** as reserve / claim backing.
2. **Lists** itself on Uniswap V4 as `DETF / pairToken` (`pairToken` = any ERC-20; **whether it is inside the SE vault does not matter**).
3. **Mints DETF** using a simple **exchange rate**: the pool’s **initialized price**, until the pool has **liquidity from which to price**; then uses that market mark (TWAP when usable).
4. **Policy gates** use TWAP synthetic (fallback when unusable).
5. **Bonds** are Uni V4–native: each user bond NFT’s `tokenId` is the **position salt**; protocol **DETF NFT `tokenId == 0`** is special and holds its position via the **Uniswap V4 Standard Exchange vault**.

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
| **No usable market liquidity yet** (empty / single-sided / cannot mark) | **Creation exchange rate** only |
| **Usable liquidity exists** (can take a TWAP / market mark) | **Market mark from the pool** (TWAP when ready) |

So: **fixed menu price until the pool can actually price; then the market price.**

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

## TWAP window — recommendation

| Setting | Suggestion |
|---------|------------|
| **Default `twapSeconds`** | **1800 (30 minutes)** |
| PkgArgs | Required field; default used when zero if resolve-policy allows, or always explicit — **prefer explicit with 1800 as documented default** |
| Observation cardinality | Ensure deploy/postDeploy raises cardinality enough for ≥ 30m history (implementation plan) |

### Why 30 minutes?

| Window | Tradeoff |
|--------|----------|
| **5–15 min** | Faster to open mint/burn after moves; easier short manipulation / thin-book noise |
| **30 min (recommended)** | Common DeFi compromise: enough to blunt one-block and short sandwich noise for **gates**, still reacts within a trading session |
| **1–4 hours** | Safer vs slow grind; Policy gates lag real market; worse UX when legitimately rich/cheap |

**Primary mint size** (once liquid) should follow the same “price from liquidity” mark family as gates where possible (TWAP), so users are not quoted on spot while gated on a different clock — unless a later PRD explicitly splits them.

**v1 thin-book controls:** TWAP + creation-rate fallback only (no max-impact caps).

---

## Locked decisions

Do not re-open without PRD revision once **LOCKED**.

### Product & topology

| Topic | Decision |
|-------|----------|
| Family name | `UniV4SingleStandardExchangeDETF` |
| Reserve / claim backing | SE vault shares held in DETF (and protocol paths below) |
| Listing | Uniswap V4 `DETF / pairToken` |
| `pairToken` | Any ERC-20 PkgArg. **No requirement** that it be in the SE vault. **Irrelevant** to mint pricing logic whether it is or not |
| Pool init | postDeploy `initialize` with required `sqrtPriceX96`, fee, tickSpacing, hooks |
| Hooks (v1 listing pool) | Vanilla / zero hooks unless later required |
| Instance governance | Immutable, unowned |
| Deploy path | CREATE3 facets; DFPkg via vault registry / manager |

### Pricing & thresholds

| Topic | Decision |
|-------|----------|
| Pre-liquidity primary price | **Creation exchange rate** (`sqrtPriceX96` at init) |
| Post-liquidity primary price | **Market mark from pool** (TWAP when usable) |
| Synthetic gates | TWAP when usable; else **1e18** |
| Default TWAP window | **1800 seconds** |
| ThresholdMode | Policy + Open; defaults 1.05e18 / 0.95e18 via shared policy |
| Bootstrap first mint | Synthetically ungated |
| Live | Pool init + first vault-share primary deposit; **depth not required** |
| Seigniorage incentive | Input boost **before** quote |
| O9 | TWAP + fallback only |

### Bond / claim (Uni V4–native — replaces peer BPT bond model)

| Topic | Decision |
|-------|----------|
| Bond role | Lock + LP isolation + sell-to-protocol / claim — **not** liveness bootstrap |
| User bond positions | Uniswap V4 liquidity position on the **listing pool**, with **`salt = bytes32(uint256(tokenId))`** of that user’s bond NFT |
| Position isolation | Each bond NFT maps 1:1 to its own salted position (overlapping ranges allowed across salts) |
| Protocol / DETF NFT | **`tokenId == 0`** is the DETF protocol NFT; managed **differently** from user bonds |
| DETF NFT id 0 custody | Holds its position through the **Uniswap V4 Standard Exchange vault** at `contracts/protocols/dexes/uniswap/v4/` (SE vault share inventory for protocol), **not** the same salt-on-listing-pool path as user bonds |
| Rebasing claim | Holders own **pro-rata claim on SE vault shares held by the DETF** (protocol inventory), not Balancer BPT |
| New contracts required | **New** bond NFT + rebasing claim packages under `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/` — do **not** reuse Balancer-era NFT/claim packages unchanged |
| Accepted bond assets (user) | Vault share, DETF, and tokens in the SE vault (allowlisted) — as inputs that fund / open the salted Uni position per impl plan |
| When bond allowed | After **live** (default) |

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
- Uni V4–native bonds (NFT id = position salt); special DETF NFT 0 via Uni V4 SE vault; rebasing claim on DETF-held SE shares.

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
| `bondTokenId` | NFT id; for user bonds, **position salt** |
| `detfBondTokenId` | **Always 0** — protocol DETF NFT |
| `rebasingClaimToken` | Claim on DETF-held SE vault shares (new package) |

**Anti-patterns:** brand tickers; requiring `pairToken ∈ SE`; treating user bond and DETF NFT 0 as the same custody path.

### Opacity

- User-attached SE leg: `IStandardExchange*` only (may *be* a Uni V4 SE instance without the DETF hard-coding that).
- Listing + user bond salts: Uni V4 PoolManager / position APIs as required.
- DETF NFT 0: may call the Uni V4 SE vault package explicitly as the protocol custody path named in this PRD.

---

## Scope

### In scope (v1)

- `standardExchange/uniV4Single/` DETF package
- `detf/protocols/dexes/uniswap/v4/common/` **new** bond NFT + rebasing claim
- Integration with `contracts/protocols/dexes/uniswap/v4/` for **DETF NFT 0** position/share custody
- Listing pool init; creation-rate then market-mark mint/burn
- TWAP synthetic (default 30m) + 1e18 fallback; Policy/Open
- User bonds: `salt = tokenId` on listing pool
- Claim: shares of SE vault held by DETF
- Production-first tests

### Out of scope (v1)

- Balancer self-leg reserve / BPT bond principal
- Reusing Balancer DETF NFT/claim packages without the Uni V4 salt / id-0 split
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
                    pairToken (any ERC-20)
                           │
                           ▼
              Uniswap V4 listing pool
              DETF  ↔  pairToken
              init price = exchange rate
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   market LPs        user bond NFTs      TWAP mark
   (optional)        salt = tokenId      (gates / post-liq mint)
        │                  │
        │                  │ liquidity position
        │                  ▼
        │            Bond NFT (new package)
        │            tokenId ≥ 1 (users)
        │
        ▼
  DETF diamond (detfToken)
   • primary mint/burn inventory (SE shares)
   • holds SE vault shares backing claims
        │
        │  DETF NFT tokenId == 0 (special)
        ▼
  Uniswap V4 Standard Exchange vault
  (contracts/protocols/dexes/uniswap/v4/)
   • protocol position custody path
        │
        ▼
  Rebasing claim token (new package)
   • pro-rata on SE shares held by DETF
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

### Usable market mark (draft criteria)

Unusable when: pool not initialized; TWAP window/cardinality not ready; or liquidity is empty/single-sided such that a family-defined mark cannot be formed.  
→ fall back to **creation rate** for mint size and **1e18** for synthetic gates (gates fallback stays 1e18 even if mint uses creation rate — both are “no market” modes).

---

## Bonding (Uni V4–specific)

### User bonds (`tokenId != 0`)

1. User opens/buys a bond → mint bond NFT with `tokenId`.
2. Liquidity position on the **listing pool** uses **`salt = bytes32(uint256(tokenId))`**.
3. That salt **binds NFT ↔ position** and isolates accounting per bond (multiple overlapping ranges possible across different salts).
4. Lock terms from fee oracle (min revert, max clamp for bonus).
5. Sell NFT → protocol: principal/position accounting moves to protocol path; mint rebasing claim when configured.

### DETF NFT (`tokenId == 0`)

1. Protocol-owned DETF bond NFT is **id 0**.
2. **Not** opened as a salted user position on the listing pool in the same way.
3. Protocol exposure / position is held via the **Uniswap V4 Standard Exchange vault** (`contracts/protocols/dexes/uniswap/v4/`), whose shares sit under DETF custody as specified in the impl plan.
4. This asymmetry is intentional: user bonds = listing-pool salts; protocol = SE vault machinery.

### Rebasing claim (new package)

1. Lives under `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/`.
2. Claim shares represent **ownership of SE vault shares held by the DETF** (protocol inventory), not BPT.
3. Redeem burns claim shares and pays out SE vault shares (and allowlisted SE outs if offered).
4. Rate can rise when protocol SE share inventory grows relative to claim supply (impl plan).

### Do not reuse unchanged

Balancer-era `detf/bondNft` and `detf/claimToken` packages are **references only**. This family needs **new** contracts for salt-binding and id-0 SE custody.

---

## Liveness

| State | Condition |
|-------|-----------|
| Inert | Deployed; primary blocked except bootstrap first mint |
| Live | Listing pool initialized **and** first successful primary vault-share deposit |

Bond is **not** required for live. Uni depth is **not** required for live.

---

## Canonical flows (short)

1. **Deploy** — init listing pool at exchange rate; wire SE, thresholds, TWAP=1800 default, new NFT/claim packages; DETF NFT 0 setup via Uni V4 SE path.
2. **Bootstrap mint** — ungated; creation rate; → live.
3. **Later mint/burn** — creation rate or TWAP per usability; Policy/Open gates.
4. **User bond** — NFT id → salt → listing pool position.
5. **Sell bond → claim** — rebasing claim on DETF-held SE shares.
6. **External swap** — any router on listing pool.

---

## PkgArgs (draft)

| Field | Notes |
|-------|--------|
| `standardExchangeVault` | Attached SE |
| `pairToken` | Any ERC-20 |
| `poolFee`, `tickSpacing`, `hooks` | Listing pool |
| `sqrtPriceX96` | Required creation exchange rate |
| `twapSeconds` | Default **1800** if zero-resolve allowed; else required |
| `thresholdMode`, thresholds | Shared policy |
| Bond NFT + claim package refs | New Uni V4 common packages |
| Uni V4 SE / PoolManager wiring | For listing + id 0 path |

---

## Testing expectations

1. Creation-rate mint with **empty** pool; live without depth.
2. After two-sided liquidity + TWAP ready: mint size and synthetic follow market mark; Policy gates.
3. User bond: two NFTs, two salts, isolated positions; overlapping ticks allowed.
4. DETF NFT 0 **not** using user salt path; SE vault share custody path covered.
5. Claim redeem vs DETF-held SE shares; no BPT assumptions.
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
| User bond principal | Often BPT | **Uni V4 position salt = tokenId** |
| Protocol NFT | Peer BPT accounting | **tokenId 0 + Uni V4 SE vault** |
| Claim | BPT-oriented redeem | **SE shares held by DETF** |
| NFT/claim code | Shared Balancer-era packages | **New under `detf/protocols/dexes/uniswap/v4/common/`** |

---

## Remaining before LOCK

- [ ] Confirm TWAP default **1800** (or pick 900 / 3600)
- [ ] Exact “usable liquidity” predicate for switching creation rate → market mark
- [ ] Bond open: which assets are converted into listing-pool liquidity vs held as principal metadata
- [ ] DETF NFT 0: exact SE vault operations (import position vs mint shares only)
- [ ] Tick range policy for user bond positions (full range vs PkgArg range)
- [ ] Observation cardinality bootstrap at deploy for 30m TWAP

---

## Revision history

| Version | Date | Notes |
|---------|------|-------|
| v0.1 | 2026-07-31 | Initial draft |
| v0.2 | 2026-07-31 | Closed O1–O9 forms |
| v0.3 | 2026-07-31 | Plain-language exchange-rate pricing; market mark after liquidity; TWAP default 30m; Uni V4 salt bonds; DETF NFT 0 via Uni V4 SE; new NFT/claim under `detf/protocols/dexes/uniswap/v4/common/` |

---

## Approval

| Role | Sign-off |
|------|----------|
| Product | Pending — review v0.3 |
| Protocol | Pending |

**Status remains DRAFT until you mark LOCKED.**
