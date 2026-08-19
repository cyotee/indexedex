# Product Requirements Document (PRD)

## Title

**Balancer V3 true DETFs — product-law alignment** (mature-only protocol sell, DETF may buy claim but not bonds, deploy-time price gates, Policy-coupled natural expansion)

## Status

**SUPERSEDED for mint/bond/burn/claim/close process** — use [`DETF_ALIGNMENT_PRD.md`](../../../DETF_ALIGNMENT_PRD.md) D1–D28. This file remains for Balancer-only curve/token-set notes.

**LOCK v0.5** — 2026-08-12. Fourth Q&A closed (rebasing bond **1:1 original=effective**, `detfNFTId` at deploy with 0 principal, `redemptionRate` quotes only that bond). Stamped LOCK for implementor execution.

| Related | Role |
|---------|------|
| **This family impl plan** | [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md`](./BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md) (implementor SoT once stamped) |
| **DETF-wide law** | [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../../../../../../../docs/agent/INDEXEDEX_AGENT_LAW.md) § DETF families |
| **Threshold modes** | [`DETFThresholdPolicy.sol`](../../../common/core/DETFThresholdPolicy.sol) + [`docs/detf/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../../../../../docs/detf/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Compound + expansion** | [`docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../../../../../docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) (**LOCKED**) |
| **Valid behavioral reference (mature-only sell/close)** | [`UniswapV4StandardExchangeOrbitalDETF_PRD.md`](../uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_PRD.md) + `UniswapV4StandardExchangeOrbitalDETFBondingTarget` |
| **Valid behavioral peers** | Uni V4 CP / Weighted DETFs under `detf/protocols/dexes/uniswap/v4/standardExchange/` |
| **Shared Balancer bond NFT** | [`detf/common/bondNft/DETFNFTVaultTarget.sol`](../../../common/bondNft/DETFNFTVaultTarget.sol) |
| **Shared claim package** | [`detf/common/claimToken/`](../../../common/claimToken/) (`RebasingClaimToken`) |
| **Composed-stable family NFT + claim** | `stable/common/ComposedStableCommonDetfBondNFTVault*` + `RebasingDETFToken*` |
| **Shared lifecycle helper** | [`DETFBondLifecycleLib.sol`](../../../common/core/DETFBondLifecycleLib.sol) |

**Short name:** Balancer V3 DETF law alignment.

**Do not conflate with:**

| Package | Role in this PRD |
|---------|------------------|
| `…/balancer/v3/uniswap/v4/crossVersion/v2/` DualLiquidity | **Out of scope.** Pro-rata BPT vault, **not** a true DETF. |
| Protocol compound single-sided DETF join | Protocol inventory compounding. **Not** `buyClaim`. Stays allowed. |
| `mintFromNFTSale(lpShares)` minting **shares == BPT 1:1** | **Incorrect.** Must become ERC-4626 `convertToShares(assets)` (§1.2.2). |

---

## 0. Intent

### 0.1 Why this exists

Product law for true DETFs (clarified 2026-08-12):

1. A bond holder **cannot sell the bond to the protocol** until the bond is **mature**.
2. A user **cannot buy a bond with the DETF token**. A user **can** buy the **rebasing claim** with free DETF (`buyClaim`).
3. **Price gating** of primary mint/burn is a **deploy-time** configuration (`ThresholdMode.Policy` vs `Open`).
4. If price gating is **enabled** (`Policy`), DETF supply **automatically expands** into the bond-reward ledger while the instance is live and synthetically mint-allowed.

Uni V4 families under `detf/protocols/dexes/uniswap/v4/` are the **valid** product shape for reserve/seigniorage/gates/expansion. Uni V4 Orbital is the **valid** mature-only sell/close shape. Balancer V3 families under this directory are **invalid** on early sell, incomplete holder surfaces (especially Single SE), and 1:1 claim-share minting. This PRD aligns them without changing reserve topology.

### 0.2 Product one-liner

Every true Balancer V3 DETF: **lock is a lock**, **DETF cannot open a bond**, **DETF can buy claim via ERC-4626 shares**, **gates are deploy-time**, **Policy expands to bonders**.

### 0.3 Goals

1. Lock surfaces, errors, settlement, and claim math so an implementor does not invent any of them.
2. Record the family-by-family audit.
3. Shared enforcement: DETF surface + both NFT packages + `DETFBondLifecycleLib`.
4. Finish Single SE as a full claim peer.
5. Keep family reserve topology unchanged.

### 0.4 Non-goals (this alignment)

1. Changing Balancer reserve math, weights, rate providers, or first-bond / bootstrap topology.
2. DualLiquidity / linked cross-version vaults.
3. Migrating Balancer expansion from `DETFNaturalExpansionLib` premium-closure to Uni V4 **epoch** form (separate shared amendment).
4. Auto-compound of **user** or fee-recipient bond rewards.
5. Soulbound bond NFTs. ERC-721 transfer anytime; buyer inherits the lock.
6. Renaming `DETDFPkg` / `IDetf`.
7. Post-deploy mutation of thresholds, mode, or expansion params.
8. ERC-4626 virtual-offset / inflation-share padding (not in current packages; do not add).
9. Amending Uni V4 family PRDs in this change set (follow-on: they already allow DETF→claim; they must still **forbid DETF→bond** and must not mint claim 1:1 with LP).

---

## 1. Locked product law

Closed Q&A 2026-08-12. These tables are **normative**.

### 1.1 Mature-only protocol sell and close

| Topic | LOCK |
|-------|------|
| Pre-maturity principal exit | **None.** Sell and close **revert** `BondNotMature(unlockTime)` if `block.timestamp < unlockTime`. |
| While locked | Only **`claimRewards`** (free DETF: seigniorage + expansion). Not a principal exit. |
| At / after maturity | (a) **`closeBondMature`** — principal out in family settlement assets, **or** (b) **`sellPositionToDetfNft`** — migrate principal BPT to protocol inventory + mint claim via ERC-4626 shares. |
| Post-maturity hold | Optional forever. No forced close. |
| NFT transfer | Free ERC-721 anytime. Buyer inherits lock + principal. Marketplace sale ≠ protocol sell. |
| Fee-recipient / user bonds | **Same** mature-only rules. Protocol DETF-owned NFT remains unsellable / uncloseable (`DETFNFTRestricted`). |
| Public sell ABI | **`sellPositionToDetfNft(tokenId, minClaimOut, recipient) → claimMinted` only.** **Remove `sellNFT`.** `minClaimOut` is rebasing `balanceOf` units; revert if minted < min. |
| If claim wired (always, §1.5) | NFT `sellPositionToDetfNft` already moves **`originalShares`** onto `detfNFTId` (do **not** `addToDETFNFT` a second time). Then `mintFromNFTSale(originalShares, recipient)` using §1.2.2. Measure `totalAssets` **before** that ledger move. |
| Sell return | **Rebasing claim minted** (`balanceOf` units). |
| Close ABI | **`closeBondMature` on the DETF** is the only user close. See §1.4. **No usage fee.** |
| NFT `redeemPosition` | **`onlyOwner` / only DETF.** Not a public user path. DETF `closeBondMature` may call it internally or unwind itself; users do not. |
| Enforcement (all three) | (1) DETF `_requireMature` on sell and close. (2) Shared `DETFNFTVaultTarget.sellPositionToDetfNft` **and** composed-stable family NFT `sellPositionToDetfNft` revert if unlock pending. (3) `DETFBondLifecycleLib` sell helpers revert if `unlockTimeOf` is still pending (add `unlockTimeOf` to the inventory policy if missing). |
| Error | **`BondNotMature(uint256 unlockTime)`** on DETF repos, both NFT packages, and the lifecycle lib. Replace `LockDurationNotExpired` on sell/close paths (redeem-while-locked on NFT, if any internal path remains, uses the same `BondNotMature`). |

### 1.2 DETF → claim allowed; DETF → bond forbidden

| Topic | LOCK |
|-------|------|
| `bond` / `bootstrapFirstBond` `tokenIn == detfToken` | **`InvalidRoute`** (composed: `BondTokenNotSupported`). |
| `acceptedBondTokens()` | **Must not** contain `address(this)`. Nested **other** DETF used as a vault share is a `vaultShare`, not this instance’s DETF. |
| `initializeReserve` | User supplies vault shares, not DETF. DETF minted **into the pool** for weight pairing remains allowed. |
| Buy claim with free DETF | **Allowed.** DETF surface **`buyClaim`** only (§1.2.1). |
| Claim package `exchangeIn` / `deposit(DETF)` | **Not** the user path. Do not add DETF as claim `tokenIn`. |
| DETF `exchangeIn(DETF, *, claimToken)` | **`InvalidRoute`**. Use `buyClaim`. |
| Policy / Open gate on `buyClaim` | **None.** Same as live bonds. |
| Seigniorage / usage fee on `buyClaim` | **None.** |

#### 1.2.1 `buyClaim` (LOCKED)

```text
buyClaim(
  uint256 detfAmount,
  uint256 minClaimOut,
  address recipient,
  bool pretransferred,
  uint256 deadline
) returns (uint256 claimMinted)

previewBuyClaim(uint256 detfAmount) returns (uint256 claimMinted)
```

`claimMinted` / `minClaimOut` are **rebasing `balanceOf` units**, not raw shares.

1. `_requireReserveLive`; deadline / non-zero checks as other DETF writes. `recipient == 0` → `msg.sender`.
2. Pull `detfAmount` of **this** DETF with the **delta gate** (`_secureTokenTransfer` / family `_pullToken`). `pretransferred=true` is allowed; **idle inventory is not free credit** (I1–I3).
3. **Single-sided join** DETF into the reserve (self-leg only). `bptIn` = BPT minted by that join. If `bptIn == 0`, revert **`ZeroAmount`** (do not mint 0 shares).
4. Credit `bptIn` onto the **protocol-owned bond NFT** via `addToDETFNFT` (§1.2.2). Physical BPT stays on the DETF diamond (today’s custody).
5. Mint claim via **`mintFromNFTSale(bptIn, recipient)`** using §1.2.2.
6. Revert if `claimMinted < minClaimOut`.
7. Realize Policy expansion if eligible, then best-effort `compoundProtocolRewards`. **Do not** harvest a user bond.
8. `previewBuyClaim` uses the same quote path as execution (preview join + `convertToShares`). Tests: preview == execution except documented Balancer few-wei if a multi-leg join forces it.

**Empty vault allowed:** if protocol NFT principal (`totalAssets`) is 0, mint is `sharesOut = bptIn` even if leftover claim shares exist. First claim supply may come from `buyClaim` (no prior mature sell required).

Protocol `compoundProtocolRewards` stays a **separate** path (protocol NFT pending DETF → join → `addToDETFNFT`). It must **not** call `buyClaim` and must **not** mint claim to users.

#### 1.2.2 Two-level BPT shares (LOCKED)

This is the product model. Implementors must not invent a third raw-BPT pile.

```text
                    reserve BPT (one pool)
                            │
            apportioned by bond originalShares
                            │
         ┌──────────────────┼──────────────────┐
         ▼                                     ▼
   user bond NFTs                    rebasing token’s bond
   (holder-owned tokenIds)           (protocol NFT / detfNFTId)
         │                                     │
         │                                     │  apportioned again
         │                                     ▼
         │                          rebasing claim holders
         │                          (ERC-4626 shares of that bond)
         ▼
   closeBondMature
   (that user’s bond only)
```

1. **Every bond** (user or protocol) is an **apportioned share of the reserve BPT**. Ledger unit for principal / 4626 = `originalShares` (BPT).
2. **The rebasing token holds a bond** — the protocol-owned NFT (`detfNFTId`). Economically that bond *is* the claim inventory. Custody may stay on the bond-NFT vault / DETF diamond; do not require the claim ERC-20 to be the ERC-721 owner if today’s wiring already keeps the NFT in the vault.
3. **Create `detfNFTId` at bond-vault / DETF deploy** with **0** `originalShares` (and 0 `effectiveShares`). Live + empty principal is a valid empty 4626 vault. First credit is first `buyClaim` or first mature sell. **Do not** create it lazily.
4. **Rebasing bond is 1:1 — no lock multiplier.** Invariant after every credit/debit: `effectiveSharesOf(detfNFTId) == originalSharesOf(detfNFTId)`. Create with no lock bonus. `addToDETFNFT` / sell-into-protocol must add effective and original **1:1**. User bonds may still have lock bonuses; those bonuses **burn on sell** (principal-only move). Expansion/seigniorage to claim holders is therefore **strictly pro-rata** to that bond’s BPT.
5. **Rebasing holders are apportioned shares of that bond’s shares** of the BPT reserve. Mint/redeem claim = ERC-4626 against **only** `originalSharesOf(detfNFTId)`.
6. User bonds are a **sibling pile**, not inside the rebasing token’s bond, until a **mature sell** moves that user’s `originalShares` into `detfNFTId`.

| Pile | What it is | Who uses it |
|------|------------|-------------|
| User-bond principal | `originalShares` of **user** tokenIds | **`closeBondMature` only** |
| Rebasing token’s bond | `originalShares` of **`detfNFTId`** | `buyClaim`, mature sell, `redeemClaim`, compound credit |
| Idle / donated BPT on the diamond | `reserveBpt.balanceOf(DETF)` minus both bond ledgers | **Not** claim assets (A3). Not a bond. |

**Never** set `totalAssets = reserveBpt.balanceOf(DETF)`. That would let claim redeem against still-locked user bonds.

**Any mint of rebasing claim against BPT assets (sell or `buyClaim`) uses ERC-4626 share accounting. Minting claim shares 1:1 with BPT is incorrect.** Today’s `mintFromNFTSale` (`internalShares = externalSharesToInternal(lpShares)`) is **wrong** and **must be fixed** in:

- `detf/common/claimToken/RebasingClaimTokenTarget.mintFromNFTSale`
- `stable/common/RebasingDETFTokenTarget.mintFromNFTSale`

Normative mint (measure **before** `addToDETFNFT`):

Let `assets` = BPT credited this call (`bptIn`).

Let `totalAssets` = protocol NFT BPT principal **before** crediting `assets`.

Let `totalShares` = claim token `totalShares()` (external share units) before mint.

Ledger units: **`originalShares` are BPT principal** (not `effectiveShares` / lock bonus). `totalAssets = originalSharesOf(detfNFTId)`. Close uses that tokenId’s `originalShares`.

```text
if (totalAssets == 0):
    sharesOut = assets          // empty-vault, even if leftover claim shares remain
else:
    sharesOut = assets * totalShares / totalAssets   // Solidity floor
```

Empty-vault **does** run when `totalShares > 0` and `totalAssets == 0` (ghost shares stay; new mint is `sharesOut = assets`). First mint when both are 0 is the same formula.

Then mint `sharesOut` (via existing internal share scale). **Return / `balanceOf` remain rebasing:** `claimMinted = sharesToBalance(sharesOut, redemptionRate)`. That displayed amount is **not** required to equal `assets` or `detfAmount`.

Do **not** add a virtual offset. First-deposit donation remains catalog A0/A3 (idle BPT is not `totalAssets`).

`mintFromNFTSale(assets, recipient)` argument meaning: **BPT assets contributed**, not “shares to mint”. Update NatSpec. Callers pass `bptIn`, never a 1:1 stand-in.

#### 1.2.2b Claim views quote only the rebasing bond (LOCKED)

`redemptionRate()` and `balanceOf` / `totalSupply` on the claim token are the family settlement-asset (rateAsset / buffer / common token) value of **`convertToAssets(shares)` against `detfNFTId` `originalShares` only**.

- **Not** 1:1 with BPT.
- **Not** `reserveBpt.balanceOf(DETF)` or any commingled book.
- Must match `redeemClaim`’s 4626 `convertToAssets` path (then the same unwind quote to settlement). Fix `previewRebasingDetfTokenReserveBpt` / composed pricing if they still assume 1:1 or whole-diamond BPT.

`minClaimOut` and sell/buyClaim returns stay in these rebasing `balanceOf` units.

#### 1.2.3 `redeemClaim` = `convertToAssets` (LOCKED)

Stop treating `burnShares()` as 1:1 BPT (Weighted/Mixed-buffer `_burnClaimForBpt` today).

```text
bptOut = sharesBurned * protocolClaimTotalAssets / totalSharesBeforeBurn   // floor
```

Then **debit the protocol NFT ledger** by `bptOut` (reduce `originalShares` / remove assets from `detfNFTId`). Inverse of mint; floor dust stays on the protocol NFT.

If physical DETF BPT available to this pile (`balanceOf(DETF) − user-bond originalShares − other reserved`) **< `bptOut`**, revert **`InsufficientReserveBpt`**. Do **not** haircut. Do **not** pull user-bond principal. Do **not** require idle donations.

**No usage fee** on `redeemClaim`.

**Canonical user path:** `DETF.redeemClaim`.  
**Required preview:** `previewRedeemClaim(...)` — same quote path as execution.  
**Wrapper:** existing claim-token `redeem` / `exchangeIn` **must** call this same DETF unwind + 4626 `convertToAssets`. **No second math path.** Do not add DETF as claim `tokenIn`.

#### 1.2.4 Lazy expansion + compound on sell / close / `buyClaim` (LOCKED)

All three are reward-class touches:

| Call | Realize Policy expansion if eligible | Harvest user-bond `claimRewards` | Best-effort `compoundProtocolRewards` |
|------|--------------------------------------|----------------------------------|----------------------------------------|
| `buyClaim` | Yes | **No** | Yes |
| `sellPositionToDetfNft` | Yes | Yes → `recipient` | Yes |
| `closeBondMature` | Yes | Yes → `recipient` | Yes |

### 1.3 Price gating is deploy-time only

Unchanged from AGENTS + `DETFThresholdPolicy`:

| Topic | LOCK |
|-------|------|
| Field | Explicit `ThresholdMode` on `PkgArgs` → storage. |
| Values | **`Policy` (default)** vs **`Open`**. Never infer Open from zero thresholds. |
| Defaults | Zero mint/burn thresholds → **1.05e18 / 0.95e18** in both modes; Open **ignores** gates. |
| Source | `PkgArgs` only. No fee-oracle override. No setter. |
| Policy (live) | Mint iff `synthetic > mintThreshold`; burn iff `synthetic < burnThreshold`; equality = deadband. |
| Open (live) | Gates always pass. Same routes, fees, seigniorage, inert→live. No peg advertised. |
| First bond / bootstrap | Synthetically **ungated**. |
| Bond after live | **No** synthetic price gate. |
| `buyClaim` | **No** synthetic price gate. |

### 1.4 `closeBondMature` settlement (LOCKED)

User calls **DETF only**. NFT `redeemPosition` is not a user entrypoint.

DETF returned from a proportional BPT exit is **rejoined** into the protocol reserve (self-leg). **Never** send it to the user. **Never** burn it as user free DETF. User is paid **only** the family settlement asset.

| Family | Signature | `tokenOut` |
|--------|-----------|------------|
| Single SE | `closeBondMature(tokenId, tokenOut, minOut, recipient, deadline) → amountOut` | Same set as primary **burn** / `redeemClaim`: `vaultShare` and SE `tokens()` already allowed on burn. Else `InvalidRoute`. |
| Multi-vault weighted | `closeBondMature(tokenId, tokenOut, minOut, recipient, deadline) → amountOut` | Same as existing `redeemClaim`: a configured **rateAsset** of a reserve leg. Else `InvalidRoute`. |
| Mixed-buffer | `closeBondMature(tokenId, minOut, recipient, deadline) → amountOut` | **bufferToken only.** No `tokenOut` argument. |
| Composed stable | `closeBondMature(tokenId, tokenOut, minOut, recipient, deadline) → amountOut` | Same assets as existing `claimLiquidity` / claim redeem (configured rateAsset / common token). Else `InvalidRoute`. |

**No usage fee** on close (or on `buyClaim`). Deadline required, same spirit as `bond`.

Mechanics (all families):

1. `_requireMature(tokenId)`; deadline check.
2. Realize expansion / harvest rewards to `recipient` (§1.2.4).
3. Read **user-bond** `originalShares` (BPT principal) from that tokenId. If physical BPT available to the **user-bond pile** < that amount, revert **`InsufficientReserveBpt`**. Do not pull protocol NFT principal or haircut.
4. Proportional exit; **redeposit DETF self-leg**; consolidate other legs to `tokenOut` / buffer via existing redeem/burn helpers.
5. Burn the user bond NFT (ledger already closed).
6. Transfer settlement ≥ `minOut` or revert.
7. Best-effort `compoundProtocolRewards`.

**Required preview:** `previewCloseBondMature(...)` matching each family’s close ABI (same `tokenOut` rules). Same quote path as execution.

No per-tokenId capital-token metadata on Balancer v1 (unlike Orbital Q13). Close pays the **claim-redeem basket**, not “whatever they bonded with.”

### 1.5 Claim package is mandatory at deploy

| Topic | LOCK |
|-------|------|
| All four true DETF families | DFPkg `postDeploy` **reverts** if rebasing claim is missing / zero. |
| Single SE / Weighted / Mixed-buffer | Wire **shared** `detf/common/claimToken` (`RebasingClaimToken`). Do not invent a fifth claim token. |
| Composed stable | Keep family `RebasingDETFToken`, but **same** ERC-4626 mint law and mature-only sell. |
| Owner | DETF diamond. |
| No absorb-only production path | Sell always mints claim. Runtime `ClaimTokenNotConfigured` is a deploy bug, not a product mode. |

### 1.6 Policy ⇒ automatic expansion to bond holders

Unchanged from the locked compound/expansion PRD. Keep `DETFNaturalExpansionLib` (no epoch migration in this work).

| Topic | LOCK |
|-------|------|
| When | Live **and** `Policy` **and** synthetic mint-allowed. |
| What | Mint free DETF with **no** external capital into the bond reward vault. |
| Who | Bond effective-share weights only. |
| Open | **Never** expands. |
| Params | `PkgArgs` → `resolveExpansionParams`. No setter. |
| User claim | `claimRewards` while locked. |

### 1.7 `claimLiquidity`

Internal DETF / NFT / claim-package callback for BPT unwind. **Not** a user “buy” or “sell.” Caller restriction: **only** this DETF (and, if today’s composed path needs it, the bond NFT owned by this DETF). External EOAs revert.

---

## 2. Scope

### 2.1 In scope

| Family | Path |
|--------|------|
| Single Standard Exchange | `standardExchange/single/` |
| Multi-vault weighted | `multi-vault-weighted/` |
| Mixed-buffer multi-vault stable | `mixedBuffer/` |
| Composed stable common | `stable/common/` |

Plus shared `detf/common/bondNft/`, `detf/common/claimToken/`, `DETFBondLifecycleLib`, composed-stable NFT + `RebasingDETFToken`.

### 2.2 Out of scope

- DualLiquidity `uniswap/v4/crossVersion/v2/`
- Uni V4 DETF packages (reference only; follow-on PRD if their claim mint is still 1:1 LP or if `bond(DETF)` is possible)
- Fee oracle, manager, registry, SE internals

---

## 3. Audit vs current code (2026-08-12)

| Law | Single SE | Weighted | Mixed-buffer | Composed stable |
|-----|-----------|----------|--------------|-----------------|
| 1.1 Pre-maturity sell reverts | **GAP** | **GAP** | **GAP** | **GAP** |
| 1.1 `closeBondMature` | **GAP** | **GAP** | **GAP** | **GAP** (NFT `redeemPosition` is public + mature; not DETF-surface) |
| 1.1 Remove `sellNFT` | N/A (absent) | **GAP** (public) | **GAP** | **GAP** |
| 1.1 `BondNotMature` on NFT + lib | **GAP** | **GAP** | **GAP** | **GAP** |
| 1.2 DETF ↛ bond | **OK** (allowlist excludes self) | **OK** | **OK** | **OK** if routes omit DETF; **lock with test** |
| 1.2 `buyClaim` | **GAP** | **GAP** | **GAP** | **GAP** |
| 1.2.2 Protocol NFT = `totalAssets` | **GAP** | **GAP** (commingled DETF BPT used as cap) | **GAP** | **GAP** |
| 1.2.2 ERC-4626 mint | **N/A** (no claim) | **GAP** (`mintFromNFTSale` 1:1 shares) | **GAP** | **GAP** |
| 1.2.3 Redeem `convertToAssets` | **N/A** | **GAP** (`burnShares` as 1:1 BPT) | **GAP** | **GAP** |
| 1.3 Policy/Open | **OK** | **OK** | **OK** | **OK** |
| 1.4 Redeposit DETF on unwind | **GAP** (no close; burn-on-exit in some paths) | **GAP** (burn DETF leg on claim unwind) | **GAP** (same) | **GAP** (family `claimLiquidity` — must redeposit, not user-pay) |
| 1.5 Claim required | **GAP** (not wired) | **OK** (wired) | **OK** | **OK** |
| 1.6 Policy expansion | **OK** | **OK** | **OK** | **OK** |

Hermetic tests that `sellNFT` / `sellPositionToDetfNft` immediately after bond are **wrong** and must flip to `BondNotMature`.

---

## 4. Target holder state machine

```text
inert ── first bond / family bootstrap ──► live
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    ▼                      ▼                      ▼
               open bond              free DETF               buyClaim
               (tokenIn ≠ DETF)       mint/burn               (no price gate;
                                      (Policy gates)           ERC-4626 shares)
                    │
              while locked:
                claimRewards only
                NFT transferable
                sell / close → BondNotMature
                    │
              timestamp ≥ unlockTime
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
  closeBondMature      sellPositionToDetfNft
  (family settlement;  (BPT → protocol inventory
   redeposit DETF)      + ERC-4626 claim mint)
                               │
                         redeemClaim
                         (burn shares → same
                          settlement as close)
```

### 4.1 Required DETF surface (every in-scope family)

| Function | Notes |
|----------|--------|
| `bond(...)` | `tokenIn` ∈ `acceptedBondTokens()`; never DETF. |
| `buyClaim(...)` / `previewBuyClaim(...)` | §1.2.1 — returns rebasing claim minted |
| `claimRewards(tokenId, recipient)` | Via NFT vault. |
| `closeBondMature(...)` / `previewCloseBondMature(...)` | §1.4 — includes `deadline` |
| `sellPositionToDetfNft(tokenId, minClaimOut, recipient) → claimMinted` | Mature-only; 4626 mint; slippage. **No `sellNFT`.** |
| `redeemClaim(...)` / `previewRedeemClaim(...)` | Canonical unwind (§1.2.3). **Add** to Single SE. No usage fee. Claim-token `redeem` is a wrapper only. |
| `thresholdMode` / `isMintingAllowed` / `isBurningAllowed` | Already shipped. |
| `compoundProtocolRewards()` | Already shipped. |

---

## 5. Implementation sequence (no product forks)

### Stage A — Shared gates + 4626 mint

1. Add `BondNotMature` to shared NFT, composed-stable NFT, `DETFBondLifecycleLib`, and each family repo.
2. Maturity check in both NFT `sellPositionToDetfNft` implementations and in the lib sell helpers.
3. Fix `mintFromNFTSale` in **both** claim packages to §1.2.2.
4. Add `unlockTimeOf` on `IDetfSelfNftInventoryPolicy` if the lib cannot read it today.

### Stage B — Family surfaces

1. Each family Common: `_requireMature`.
2. `sellPositionToDetfNft`: mature gate; ERC-4626 mint; **delete `sellNFT`** from interfaces/facets.
3. Add `closeBondMature` per §1.4; implement `claimLiquidity` where missing (Single SE, Weighted, Mixed-buffer) as **only-DETF**.
4. NFT `redeemPosition`: `onlyOwner`.
5. Add `buyClaim` / `previewBuyClaim`.
6. Single SE DFPkg: deploy + wire shared claim; revert if unset. Add `redeemClaim`.
7. Weighted/Mixed-buffer/Composed unwind: **redeposit** DETF self-leg (stop burning it on close/claim).
8. `bond(DETF)` explicit `InvalidRoute` test even where allowlists already exclude it.

### Stage C — Tests (production-first)

| ID | Assertion |
|----|-----------|
| M1 | Pre-maturity `sellPositionToDetfNft` reverts `BondNotMature`. |
| M2 | Pre-maturity `closeBondMature` reverts `BondNotMature`. |
| M3 | Locked `claimRewards` still pays (seigniorage; Policy expansion). |
| M4 | After `warp(unlock+1)`, sell mints claim; `sharesOut` matches ERC-4626 vs **protocol NFT principal before** `addToDETFNFT`; return is rebasing units; NFT burned. |
| M4b | Redeem after compound: `bptOut` follows `convertToAssets`, **not** 1:1 shares. |
| M5 | After maturity, close pays family settlement from **user-bond** principal only; protocol NFT principal unchanged; **no** claim minted; exited DETF **not** in user balance (rejoined). |
| M6 | Transfer locked NFT; new owner cannot sell/close until unlock. |
| M7 | `bond(DETF)` reverts; `acceptedBondTokens()` excludes DETF. |
| M8 | `buyClaim` live, no gate, empty-vault first mint allowed; preview == execution; `pretransferred` delta gate (I1–I3); 0 BPT join reverts; second buyer after compound gets **fewer shares per BPT** than 1:1 (4626). |
| M8b | `exchangeIn(DETF, *, claim)` on the DETF reverts. Claim `tokenIn=DETF` unsupported. Claim `redeem` equals `DETF.redeemClaim` math. |
| M8c | Donate BPT to DETF then `buyClaim` / redeem: donated idle BPT is **not** `totalAssets` (A3). |
| M8d | Sell with `minClaimOut` too high reverts. `previewRedeemClaim` / `previewCloseBondMature` match execution. |
| M8e | Physical BPT short of the pile being unwound reverts `InsufficientReserveBpt`. |
| M8f | After deploy, `detfNFTId` exists with 0 principal. After credits, `effectiveSharesOf(detfNFTId) == originalSharesOf(detfNFTId)`. |
| M8g | `redemptionRate` / `previewRedeem` move only with the rebasing bond’s BPT (not user-bond BPT, not donated idle BPT). |
| M9 | Policy expands; Open does not. **Keep existing tests.** |
| M10 | No threshold setter. **Keep.** |
| M11 | First bond ungated. |
| M12 | Deploy without claim pkg reverts. |
| M13 | `sellNFT` selector **not** on loupe / `facetFuncs`. |
| M14 | External `redeemPosition` / `claimLiquidity` from EOA reverts. |
| M15 | Adversarial P0: non-owner sell, double sell, redeem without claim, I1–I3, J surface. |

No SUT mocks. Gold TestBases. `via_ir` forbidden. Seed `cache_forge/` + `out/` in new worktrees.

### Stage D — Docs

1. Stamp this PRD **LOCK**.
2. AGENTS “other families must be updated” → this file for Balancer.
3. Uni V4 follow-on: forbid `bond(DETF)`; claim mint ERC-4626 if still 1:1 LP.

---

## 6. Definition of done

A Balancer V3 true DETF family is aligned when:

1. Pre-maturity sell and close revert `BondNotMature` on DETF, NFT, and lib.
2. Post-maturity sell mints **4626** claim shares; close pays §1.4 assets and redeposits DETF.
3. `buyClaim` works without a price gate; `bond(DETF)` reverts.
4. `sellNFT` is gone from the ABI; NFT redeem is only-DETF.
5. Claim is wired at deploy (including Single SE).
6. Policy/Open + expansion unchanged and still green.
7. DualLiquidity was not treated as a DETF.

---

## 7. Closed product Q&A (2026-08-12)

| # | Decision |
|---|----------|
| Sell ABI | `sellPositionToDetfNft(tokenId, minClaimOut, recipient) → claimMinted`. Claim required at deploy. |
| `sellNFT` | **Removed** from facet ABI. |
| Sell return / slippage | Rebasing units; revert if `< minClaimOut`. |
| Sell ledger | NFT sell already credits `detfNFTId` with `originalShares`. **No second `addToDETFNFT`.** |
| Redeem fee | **None.** |
| Previews | `previewBuyClaim`, `previewCloseBondMature`, `previewRedeemClaim` — preview == execution. |
| Ghost shares + `totalAssets==0` | Still empty-vault mint (`sharesOut = assets`). |
| Physical BPT shortfall | **`InsufficientReserveBpt`**. No haircut, no other-pile dip. |
| DETF → claim | **Allowed** via `buyClaim`. |
| DETF → bond | **Forbidden**. |
| Claim `totalAssets` | **The rebasing token’s bond only** (`detfNFTId` `originalShares`). Not `balanceOf(DETF)`. Not user-bond principal. Idle donated BPT excluded. |
| Claim mint | **ERC-4626 shares** vs that ledger **before** `addToDETFNFT`. **Not** 1:1 BPT or DETF. |
| Empty-vault `buyClaim` | **Allowed.** `sharesOut = bptIn` when protocol NFT principal and `totalShares` are 0. |
| Redeem | **`convertToAssets`**. Stop 1:1 `burnShares` → BPT. |
| Claim-token `redeem` | Wrapper of **same** `DETF.redeemClaim` unwind + 4626 math. |
| `buyClaim` gate / fee | No Policy gate; no seigniorage; no usage fee. |
| `buyClaim` pull | **`pretransferred` allowed** with delta gate; no free idle credit. Deadline required. `minClaimOut` = rebasing units. 0 BPT join → `ZeroAmount`. |
| Lazy expansion | **`buyClaim`, sell, and close** all realize Policy expansion if eligible + best-effort compound. Sell/close harvest the user bond; `buyClaim` does not. |
| Single SE | Full peer; shared claim package mandatory. |
| Close | DETF `closeBondMature` + `deadline`; settlement = same basket as claim redeem; Mixed-buffer buffer-only (no `tokenOut`); **no usage fee**. |
| NFT `redeemPosition` | only DETF. |
| Exited DETF on close/redeem | **Redeposit** into protocol reserve. |
| Maturity error | `BondNotMature` on DETF + both NFT packages + lib. |
| Claim at deploy | Required; missing pkg reverts deploy. |
| Expansion form | Keep `DETFNaturalExpansionLib`. |
| Rebasing bond lock bonus | **None.** `effectiveSharesOf(detfNFTId) == originalSharesOf(detfNFTId)` always. User-bond bonuses still burn on sell. |
| `detfNFTId` lifetime | **Created at deploy**, principal 0. Not lazy. |
| Claim `redemptionRate` / `balanceOf` | Quote **only** the rebasing bond (`convertToAssets` of `detfNFTId`), then unwind to settlement. Same path as `redeemClaim`. |

**No remaining open questions.** Implement to this file.

---

## 8. Role vocabulary

`rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveBpt`, `rebasingClaimToken`. No product brands.
