# Implementation & Test Plan: Balancer V3 DETF product-law alignment

**PRD (product law SoT):** [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md`](./BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md) (**DRAFT v0.5**)  
**This plan (implementor SoT once stamped):** migrate the four true Balancer V3 DETF families + shared bond NFT / claim packages to that PRD.  
**Host root:** `contracts/vaults/detf/protocols/dexes/balancer/v3/`  
**Date:** 2026-08-12  
**Status:** Canonical plan aligned to PRD v0.5 — ready to code after product LOCK on the PRD.

---

## Authority

| Layer | Role |
|-------|------|
| **PRD v0.5** | Product law — **wins on any conflict**; patch this plan if the PRD changes |
| **This plan** | Phases, file map, algorithms, deploy path, test matrix, DoD |
| **AGENTS / INDEXEDEX_AGENT_LAW** | DETF common expectations; CREATE3; manager vault registry; production-first tests; mature-only sell |
| **Compound / expansion PRD** | Keep `DETFNaturalExpansionLib` + existing family compound. Do not change Policy/Open. |
| **Crane skills** | `crane-deployment`, `crane-architecture`, `crane-testing`, `crane-adversarial-testing` |
| **IndexedEx skills** | `indexedex-testing`, `indexedex-adversarial-testing` |
| **Uni V4 Orbital** | Behavioral reference for `_requireMature` + `closeBondMature` **only**. **Do not subclass.** |

**Process rule:** If this plan and the PRD disagree, **PRD wins**. Do not reopen closed Q&A without a PRD revision.

**Role names only:** `rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveBpt`, `rebasingClaimToken`, `detfNFTId`. No product brands.

**Out of this plan:** DualLiquidity `uniswap/v4/crossVersion/v2/`; Uni V4 DETF packages; epoch-expansion migration; `DETDFPkg` / `IDetf` renames.

---

## Read order for implementors

1. PRD §1 locked law (especially §1.1, §1.2–§1.2.4, §1.4, §1.5)  
2. PRD §3 audit (what is already OK)  
3. PRD §4 state machine + §5 stages + §7 Q&A  
4. **This plan** §0–§8  
5. Family TestBases next to each package  

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.5 | Co-located |
| This plan | This file |
| Four family packages | **Shipped** (mint/burn, Policy/Open, expansion, compound). **Invalid** on early sell, 1:1 claim mint, missing close/`buyClaim`, Single SE claim |
| Shared `detf/common/bondNft` | `sellPositionToDetfNft` has **no** maturity check; `redeemPosition` is public; `initializeDETFNFT` mints ERC-721 with 0 principal (good) |
| Shared `detf/common/claimToken` | `mintFromNFTSale` mints shares **1:1** with BPT (**wrong**) |
| Composed `RebasingDETFToken` | Same 1:1 mint; `redeem`/`exchangeIn` own unwind math |
| `DETFBondLifecycleLib` | No maturity check; no `unlockTimeOf` on inventory policy |
| DualLiquidity | **Do not touch** |

`_addToPosition` already adds `originalShares` and `effectiveShares` **1:1**. Starting from `initializeDETFNFT` (0/0, no lock bonus), the rebasing-bond invariant holds if **no one** calls `createPosition` on `detfNFTId`. Enforce that.

---

## 1. Goals / non-goals

### Goals (DoD)

1. Mature-only sell and close (`BondNotMature`) on DETF + both NFT packages + lifecycle lib.  
2. Remove public `sellNFT`. DETF sell is `sellPositionToDetfNft(tokenId, minClaimOut, recipient) → claimMinted`.  
3. `closeBondMature` + previews on every family; NFT `redeemPosition` **onlyOwner**.  
4. `buyClaim` / `previewBuyClaim`; DETF `exchangeIn(DETF, *, claim)` and `bond(DETF)` revert.  
5. ERC-4626 mint/redeem against **`originalSharesOf(detfNFTId)` only**; views match.  
6. Rebasing bond: exist at deploy, 0 principal, `effective == original` always.  
7. Single SE wires shared `RebasingClaimToken`; deploy reverts if claim missing.  
8. Close/redeem **redeposit** DETF self-leg; `InsufficientReserveBpt` on shortfall.  
9. Flip hermetic tests that sell immediately after bond. Production-first; no SUT mocks.  
10. Policy/Open + expansion suites stay green (no behavior change except new touches realize expansion per PRD §1.2.4).

### Non-goals

- Reserve math / weights / first-bond topology.  
- DualLiquidity.  
- Uni V4 DETF code.  
- Epoch expansion.  
- Virtual 4626 offset.  
- User/fee-recipient auto-compound.  
- Soulbound NFTs.

---

## 2. Hard gates

| Gate | Requirement |
|------|-------------|
| **G0** | Gold family TestBases still deploy via `indexedexManager.deploy*DFPkg` |
| **G1** | CREATE3 facets + FactoryService; **never** `new` facets/DFPkgs |
| **G2** | Shared NFT + claim packages used by Weighted/Mixed-buffer/Single SE; composed keeps family NFT + `RebasingDETFToken` |
| **G3** | `via_ir` forbidden; seed `cache_forge/` + `out/` in new worktrees; do not kill long `forge` |
| **G4** | Adversarial P0 rows that touch sell/claim updated (catalog D/F/I/J) |

---

## 3. Architecture (implementor map)

### 3.1 Two-level BPT (do not invent a third pile)

```text
physical reserveBpt on DETF diamond
        │
        ├── user tokenId originalShares     → closeBondMature only
        ├── detfNFTId originalShares        → rebasing token’s bond
        │         └── claim ERC-4626 shares → buyClaim / sell / redeemClaim
        └── idle donated BPT                → not a bond (A3)
```

`totalAssets` for 4626 **=** `originalSharesOf(detfNFTId)` **before** the credit/debit of this call.  
**Never** `reserveBpt.balanceOf(DETF)`.

### 3.2 Shared API additions (required)

Add to `IDetfBondInventoryPolicy` (and both NFT Targets/Facets):

| Function | Behavior |
|----------|----------|
| `unlockTimeOf(uint256 tokenId) view returns (uint256)` | Existing mapping; expose for lib + DETF `_requireMature` |
| `originalSharesOf(uint256 tokenId) view` | Expose if not already on the policy (Target already has it) |
| `effectiveSharesOf(uint256 tokenId) view` | For the 1:1 invariant tests / DETF checks |
| `removeFromDETFNFT(uint256 tokenId, uint256 shares)` | **onlyOwner.** Only `tokenId == detfNFTId`. Reduce `originalShares` and `effectiveShares` **1:1** by `shares`; preserve pending reward debt (mirror `_addToPosition` inverse). Revert if `shares > originalShares`. Used by `redeemClaim` debit. |

`DETFBondLifecycleLib._sellPositionToDetfNft` / `_sellPositionToRebasingClaim`:

1. Read `unlockTimeOf(tokenId)`.  
2. If `block.timestamp < unlockTime` revert `BondNotMature(unlockTime)`.  
3. Then existing sell.

Error: add `error BondNotMature(uint256 unlockTime);` on the lib and **both** NFT repos. Replace `LockDurationNotExpired` on sell/close/`redeemPosition` while-locked paths.

### 3.3 File map (touch list)

**Shared**

```text
contracts/vaults/detf/common/
  core/DETFBondLifecycleLib.sol
  inventory/IDetfBondInventoryPolicy.sol
  inventory/IDetfSelfNftInventoryPolicy.sol   # if extra views live here
  bondNft/DETFNFTVault{Repo,Target,Facet,Common}.sol
  claimToken/RebasingClaimToken{Target,Repo,Facet}.sol
```

**Single SE** — `standardExchange/single/`  
Repo, Common, BondingTarget, ExchangeIn*, Info*, DFPkg, interfaces / facet factory if sellNFT selector list, TestBase.

**Weighted** — `multi-vault-weighted/`  
BondingTarget (remove `sellNFT`, add close/buyClaim/previews, fix redeem), Common, Repo, Facets, TestBase.

**Mixed-buffer** — `mixedBuffer/`  
Same shape as Weighted; close has **no** `tokenOut`.

**Composed stable** — `stable/common/`  
BondingFacet (remove `sellNFT`), BondNFTVault Target/Repo/Facet (`BondNotMature`, `onlyOwner` redeem, 1:1 protocol NFT), `RebasingDETFToken*` (4626 + view path + wrapper), Common, DFPkg, TestBase.

**Tests** (mirror under `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/**` and any co-located `*.t.sol`).

**Do not edit** `uniswap/v4/crossVersion/v2/**`.

### 3.4 DETF surface (every family)

Put new money fns on the **bonding** target/facet (or a dedicated claim target if stack depth forces it). `PkgInit` / `PkgArgs` stay **on the interface**.

```text
error BondNotMature(uint256 unlockTime);
error InsufficientReserveBpt(uint256 needed, uint256 available);

function buyClaim(uint256 detfAmount, uint256 minClaimOut, address recipient, bool pretransferred, uint256 deadline)
    returns (uint256 claimMinted);
function previewBuyClaim(uint256 detfAmount) view returns (uint256 claimMinted);

function sellPositionToDetfNft(uint256 tokenId, uint256 minClaimOut, address recipient)
    returns (uint256 claimMinted);

// Single SE / Weighted / Composed:
function closeBondMature(uint256 tokenId, IERC20 tokenOut, uint256 minOut, address recipient, uint256 deadline)
    returns (uint256 amountOut);
function previewCloseBondMature(uint256 tokenId, IERC20 tokenOut) view returns (uint256 amountOut);

// Mixed-buffer:
function closeBondMature(uint256 tokenId, uint256 minOut, address recipient, uint256 deadline)
    returns (uint256 amountOut);
function previewCloseBondMature(uint256 tokenId) view returns (uint256 amountOut);

function redeemClaim(...)           // family ABI; Single SE add (tokenOut set = burn set)
function previewRedeemClaim(...)

function claimLiquidity(uint256 lpAmount, address recipient) returns (uint256);
    // only DETF / owned NFT; not a user entry. Single SE + Weighted + Mixed-buffer must add.
```

**Remove** `sellNFT` from every interface and `facetFuncs`. Loupe must not advertise it.

`claimMinted` / `minClaimOut` = rebasing `balanceOf` units.

---

## 4. Algorithms (frozen — copy, do not invent)

### 4.1 `_requireMature`

```text
unlock = bondNft.unlockTimeOf(tokenId)
if (block.timestamp < unlock) revert BondNotMature(unlock)
```

Call at the start of DETF `sellPositionToDetfNft` and `closeBondMature`. Lib + NFT sell also check.

### 4.2 Protocol NFT 1:1 + deploy

- `postDeploy` (bond vault then DETF): `initializeDETFNFT()` so `detfNFTId` exists, principal 0.  
- **Never** `createPosition` for `detfNFTId`.  
- Credits: `addToDETFNFT(detfNFTId, bptIn)` or NFT sell’s `_addToPosition` (already 1:1).  
- Debits: `removeFromDETFNFT(detfNFTId, bptOut)`.  
- After every mutation: `effectiveSharesOf(detfNFTId) == originalSharesOf(detfNFTId)`.

### 4.3 `mintFromNFTSale(assets, recipient)` (both claim packages)

Measure **before** the DETF credits the protocol NFT (caller passes `assets = bptIn` / user `originalShares`).

```text
totalAssets = detf.protocolBondOriginalShares()   // originalSharesOf(detfNFTId) BEFORE credit
totalShares = claim.totalShares()                 // external
if (totalAssets == 0):
    sharesOut = assets
else:
    sharesOut = assets * totalShares / totalAssets   // floor
mint internal shares (existing SHARE_SCALE)
claimMinted = sharesToBalance(sharesOut, redemptionRate)
```

`redemptionRate` / `balanceOf` / `previewRedeem` = settlement value of `convertToAssets(shares)` against **`detfNFTId` originalShares only**, then the same unwind quote as `redeemClaim`. Fix composed `previewRebasingDetfTokenReserveBpt` if it uses whole-diamond BPT or 1:1.

Expose a DETF view `protocolBondOriginalShares()` (or claim reads NFT `originalSharesOf(detfNFTId)`). Do **not** use `reserveBpt.balanceOf(detf)`.

### 4.4 DETF `sellPositionToDetfNft`

```text
_requireMature(tokenId)
realize expansion if Policy+eligible
assets = bondNft.originalSharesOf(tokenId)     // BEFORE NFT sell
// NFT sell: harvest rewards to recipient, move originalShares → detfNFTId, burn user NFT
// do NOT addToDETFNFT again
claimMinted = rebasingClaim.mintFromNFTSale(assets, recipient)
if (claimMinted < minClaimOut) revert
best-effort compoundProtocolRewards
return claimMinted
```

`mintFromNFTSale` must see `totalAssets` **before** the ledger move. Order options (pick one; tests pin it):

- **Preferred:** DETF reads `totalAssets` + `originalShares`, calls a new `mintFromNFTSale(assets, totalAssetsBefore, recipient)` **or** claim reads protocol NFT **after** DETF passes `assets` and claim does `totalAssets = originalSharesOf(detfNFTId) - assets` when the credit already landed.  
- **Simplest correct:** DETF snapshots `protocolBefore = originalSharesOf(detfNFTId)`, then NFT sell, then claim mints with `totalAssets = protocolBefore` (add optional arg `totalAssetsBefore` on `mintFromNFTSale`, onlyOwner).  

**Lock for this plan:** extend `mintFromNFTSale(uint256 assets, uint256 totalAssetsBefore, address recipient)` on both claim packages (old 2-arg path can forward `totalAssetsBefore = type(uint256).max` meaning “read live,” but DETF **must** pass the snapshot). If `totalAssetsBefore == type(uint256).max`, claim reads live `originalSharesOf(detfNFTId)` (only safe when credit has **not** landed yet — `buyClaim` can use this if it mints **before** `addToDETFNFT`).

**Canonical order (implement this, not the alternatives):**

| Path | Order |
|------|--------|
| `buyClaim` | join → snapshot not needed if mint **before** `addToDETFNFT` using live `originalShares` as `totalAssets` → `mintFromNFTSale(bptIn, recipient)` → `addToDETFNFT(bptIn)` |
| sell | snapshot `protocolBefore` → NFT sell (credits protocol) → `mintFromNFTSale(assets, protocolBefore, recipient)` |

Keep 2-arg `mintFromNFTSale(assets, recipient)` as `mintFromNFTSale(assets, type(uint256).max, recipient)` where `max` means **live read** (buyClaim only).

### 4.5 `buyClaim`

```text
_requireReserveLive; deadline; detfAmount > 0
recipient = recipient == 0 ? msg.sender : recipient
pull DETF via delta gate (pretransferred allowed; I1–I3)
bptIn = singleSidedJoinDetfSelfLeg(detfAmount)   // SAME join as compoundProtocolRewards
if (bptIn == 0) revert ZeroAmount
claimMinted = mintFromNFTSale(bptIn, recipient)  // live totalAssets = protocol originalShares (not yet credited)
addToDETFNFT(detfNFTId, bptIn)
if (claimMinted < minClaimOut) revert
realize expansion if eligible
best-effort compound   // must NOT call buyClaim; must NOT mint claim
return claimMinted
```

Join helper: extract/reuse family `_tryCompoundProtocolRewards` join (single-sided DETF self-leg). Composed: the **same** reserve-entry join compound already uses. Do not invent a second pool.

`previewBuyClaim`: preview that join + 4626 using current `originalSharesOf(detfNFTId)` as `totalAssets`.

No Policy gate, no seigniorage, no usage fee.

### 4.6 `redeemClaim` / `convertToAssets`

```text
sharesBurned = claim.burnShares(claimAmount, owner, pretransferred)  // share units, NOT BPT
totalAssets = originalSharesOf(detfNFTId)
totalShares = claim.totalShares() + sharesBurned   // before-burn; if burn already happened, add back
bptOut = sharesBurned * totalAssets / totalSharesBeforeBurn   // floor
if (bptOut == 0) revert ZeroAmount
physicalAvail = reserveBpt.balanceOf(DETF) - sumUserBondOriginalShares()
  // user-bond sum = total bond-vault originalShares - originalSharesOf(detfNFTId)
  // or iterate if no aggregate; prefer vault totalOriginal - protocol original
if (physicalAvail < bptOut) revert InsufficientReserveBpt(bptOut, physicalAvail)
removeFromDETFNFT(detfNFTId, bptOut)
exit reserve proportional(bptOut)
redeposit DETF self-leg into reserve (add resulting BPT to protocol NFT via addToDETFNFT — this BPT is protocol inventory returning home, NOT a new claim mint)
consolidate other legs → family tokenOut / buffer (existing redeem helpers; NO usage fee)
pay recipient
```

**Redeposit DETF:** the self-leg coming out of the exit is **not** user free DETF. Rejoin it. BPT from that rejoin is protocol-bond inventory: `addToDETFNFT` **without** minting claim (NAV of remaining claim shares rises). Do **not** burn that DETF.

If the family today burns the DETF leg on claim unwind (`_unwindBptToVaultShare`), **stop**.

Claim-token `redeem` / `exchangeIn`: pull claim, call `DETF.redeemClaim` (or an internal onlyOwner unwind), **same** `bptOut`. No second math.

### 4.7 `closeBondMature`

```text
_requireMature(tokenId); deadline
realize expansion; harvest rewards to recipient
assets = originalSharesOf(tokenId)   // user bond
physicalAvail = reserveBpt.balanceOf(DETF) - originalSharesOf(detfNFTId)
  // closer may use only the user-bond pile; other users’ originalShares also reserved
  // available to THIS close = min(assets, physical - protocolOriginal - otherUsersOriginal)
  // simplest correct: physicalAvailForUserPile = balance - protocolOriginal
  // then this close needs `assets`; if other users’ principal is also in that pile,
  // physical is commingled — exiting `assets` wei BPT is the ledger truth (same as today).
  // Insufficient only if balance < protocolOriginal + assets
if (balanceOf(DETF) < originalSharesOf(detfNFTId) + assets)
    revert InsufficientReserveBpt(...)
pull/burn user NFT ledger (sell-to-nowhere / remove position without crediting protocol)
exit `assets` BPT; redeposit DETF self-leg (BPT from rejoin → addToDETFNFT, no claim mint)
consolidate → tokenOut / buffer; no usage fee
pay >= minOut
best-effort compound
```

Do **not** credit `detfNFTId` with the user’s principal (that would be a sell). User principal is **exited**. Redeposited DETF is protocol-bond BPT (same as redeem leftover self-leg).

Mixed-buffer: `tokenOut` is implicit `bufferToken`.

`previewCloseBondMature`: same quote as execution.

### 4.8 Physical BPT check

```text
neededProtocol = originalSharesOf(detfNFTId)
neededUsers   = sum of user tokenId originalShares
// InsufficientReserveBpt when unwinding X from a pile if
//   balanceOf(DETF) < X + the other pile’s originalShares
```

Idle surplus may exist (`balance > neededProtocol + neededUsers`) and **must not** be treated as claim assets. It **may** sit unused (A3). It must **not** fill a shortfall (PRD: revert, no haircut, no idle dip).

### 4.9 Lazy expansion

On `buyClaim`, sell, close: same helper already used on bond/mint (`computeExpansionMint` when live + Policy + mint-allowed). Sell/close harvest the **user** tokenId. `buyClaim` does not harvest a bond.

### 4.10 Single SE claim wiring

In `SingleStandardExchangeDETDFPkg`:

- `PkgInit` gains `IRebasingClaimTokenDFPkg claimTokenPkg` (or existing shared pkg type).  
- `postDeploy`: deploy claim via **pure Crane** / factory (same as Weighted), `owner = DETF`, `setDetf`, store `rebasingClaimToken`.  
- If claim address is 0 after deploy → **revert**.  
- Bond vault `initializeDETFNFT()` before claim init so `detfNFTId` is known.

Add `redeemClaim(claimAmount, tokenOut, minOut, recipient, deadline)` with `tokenOut` ∈ primary-burn allowlist (`vaultShare` + SE `tokens()`).

### 4.11 `claimLiquidity`

Internal callback for NFT/composed paths. `msg.sender` must be this DETF or its bond NFT. EOAs revert. Prefer DETF `closeBondMature` as the user path so `claimLiquidity` is unused publicly. If composed `redeemPosition` stays as an internal helper, it must execute the **same** close algorithm (redeposit DETF, family settlement) and remain `onlyOwner`.

---

## 5. Phases

Implement **in order**. Do not start family `buyClaim` before shared 4626 + maturity gates are in.

### Phase 0 — Shared NFT + lib + policy

| Step | Work |
|------|------|
| 0.1 | `BondNotMature` on shared NFT repo + composed NFT repo + `DETFBondLifecycleLib` |
| 0.2 | `unlockTimeOf` / `originalSharesOf` / `effectiveSharesOf` on inventory policy |
| 0.3 | NFT `sellPositionToDetfNft` reverts `BondNotMature` if locked |
| 0.4 | Lib sell helpers check `unlockTimeOf` first |
| 0.5 | `redeemPosition` `onlyOwner` + `BondNotMature` |
| 0.6 | `removeFromDETFNFT` 1:1 debit + reward-debt inverse of `_addToPosition` |
| 0.7 | Assert `initializeDETFNFT` does not set a lock bonus (0/0) |
| 0.8 | Unit tests on NFT package: early sell reverts; add+remove 1:1; protocol ≠ user tokenId |

### Phase 1 — Shared + composed claim 4626 + views

| Step | Work |
|------|------|
| 1.1 | `mintFromNFTSale(assets, totalAssetsBefore, recipient)` + 2-arg wrapper (`max` = live read) |
| 1.2 | 4626 formula §4.3 in **both** claim Targets |
| 1.3 | `redemptionRate` / `convertToAssets` / `previewRedeem` use `detfNFTId` originalShares only |
| 1.4 | Claim `redeem` / `exchangeIn` call DETF unwind (composed: after DETF `redeemClaim` exists in Phase 2; until then keep a single internal 4626 helper both will use) |
| 1.5 | Claim unit tests: empty vault; second mint after extra protocol BPT gets fewer shares; donate BPT to DETF does not change `totalAssets` |

### Phase 2 — Families (one PR per family is OK; order: Weighted → Mixed-buffer → Composed → Single SE)

Per family:

| Step | Work |
|------|------|
| 2.1 | Repo errors `BondNotMature`, `InsufficientReserveBpt` |
| 2.2 | Common `_requireMature`, `_protocolOriginalShares`, `_userPileReserved`, `_singleSidedJoinDetf` (reuse compound join) |
| 2.3 | Replace sell ABI; delete `sellNFT`; implement §4.4 |
| 2.4 | `closeBondMature` + preview §4.7; `claimLiquidity` only-DETF |
| 2.5 | `redeemClaim` + preview §4.6; redeposit DETF; stop burning DETF leg |
| 2.6 | `buyClaim` + preview §4.5 |
| 2.7 | `bond(DETF)` explicit revert; `acceptedBondTokens` test |
| 2.8 | Facet `facetFuncs` + DFPkg cuts + loupe (J1–J3) |
| 2.9 | Expansion realize on the three new touches |
| 2.10 | Flip every test that sells/closes without `warp(unlock+1)` |

**Single SE extra:** Phase 2.0 claim DFPkg wiring + `redeemClaim` + TestBase helpers.

**Composed extra:** family NFT same gates as shared NFT; do not use `weth` role names.

### Phase 3 — Tests (see §6)

Ship with each family PR. Do not leave Weighted green on early-sell while Mixed-buffer still sells immediately.

### Phase 4 — Docs

| Step | Work |
|------|------|
| 4.1 | Stamp PRD **LOCK** if not already |
| 4.2 | AGENTS “other families must be updated” → this PRD + this plan for Balancer |
| 4.3 | One-line pointer on family compound/expansion stage docs under `docs/detf/balancer/v3/` |
| 4.4 | Uni V4 follow-on **not** in this change set |

---

## 6. Test matrix

Production-first: `CraneTest` → `IndexedexTest` → family `TestBase_*`. No mocks of DETF, facets, DFPkg, manager, registry, fee oracle, or attached SEs.

Exact `assertEq` / typed `expectRevert`. Preview == execution (document ≤ few-wei only if Balancer multi-leg exit forces it).

### 6.1 Product rows (every in-scope family)

| ID | Test |
|----|------|
| M1 | Pre-maturity sell → `BondNotMature` |
| M2 | Pre-maturity close → `BondNotMature` |
| M3 | Locked `claimRewards` still pays (seigniorage; Policy expansion) |
| M4 | `warp(unlock+1)` sell: 4626 vs `protocolBefore`; return rebasing units; user NFT burned; `effective==original` on `detfNFTId` |
| M4b | Compound then redeem: `bptOut` is `convertToAssets`, not 1:1 |
| M5 | Close: settlement from **user** principal; protocol originalShares unchanged by the close itself (except DETF-leg redeposit credit); user gets **no** extra DETF |
| M6 | Transfer locked NFT; buyer cannot sell/close until unlock |
| M7 | `bond(DETF)` reverts; `acceptedBondTokens` excludes DETF |
| M8 | `buyClaim` live, no gate; empty-vault first mint; preview==exec; I1–I3 `pretransferred`; 0 BPT join reverts; second buyer after protocol BPT ↑ gets fewer shares per BPT |
| M8b | DETF `exchangeIn(DETF, *, claim)` reverts; claim `tokenIn=DETF` unsupported; claim `redeem` == `DETF.redeemClaim` |
| M8c | Donate BPT to DETF: `totalAssets` / `redemptionRate` unchanged (A3) |
| M8d | Sell `minClaimOut` too high reverts; close/redeem previews match |
| M8e | Forced shortfall → `InsufficientReserveBpt` |
| M8f | Deploy: `detfNFTId` exists, 0 principal; after credits 1:1 effective/original |
| M8g | `redemptionRate` ignores user-bond BPT and donated idle BPT |
| M9–M11 | Keep existing Policy/Open/expansion/first-bond tests |
| M12 | Deploy with claim pkg = 0 reverts (Single SE + any family that can omit) |
| M13 | `sellNFT` selector **absent** from `facetFuncs` and loupe |
| M14 | EOA `redeemPosition` / `claimLiquidity` reverts |
| M15 | Surface J1–J3 on new selectors |

### 6.2 Adversarial (update existing suites)

| Catalog | Change |
|---------|--------|
| D2 / D3 / D6 | Sell/redeem after maturity; no over-claim beyond 4626 `convertToAssets` |
| F2 / F3 | NFT / `mintFromNFTSale` onlyOwner |
| I1–I3 | `buyClaim` + claim redeem `pretransferred` |
| J | New fns on proxy |
| A3 | Idle BPT donation |

Single SE adversarial NatSpec that says “no rebasing claim v1” is **obsolete** — implement D6/H2.

### 6.3 What to delete / rewrite

- `test_sellPositionToDetfNft` / `test_sellNFT_*` that succeed in the same tx as first bond → expect `BondNotMature`, plus a warped-success twin.  
- Any test that assumes `mintFromNFTSale` shares == BPT.  
- Any test that treats `burnShares` return as BPT 1:1.

---

## 7. Definition of done

A family is done when:

1. M1–M15 green on its gold TestBase (hermetic).  
2. Existing Policy/Open/expansion/compound tests still green.  
3. `sellNFT` gone; claim wired at deploy; `detfNFTId` 1:1.  
4. No DualLiquidity edits.  
5. Facet declaration + live loupe for new selectors.  
6. Forge default profile only (fork optional, not required for this alignment).

Host alignment is done when **all four** families meet the above.

---

## 8. Suggested coding order (one agent / one PR stack)

1. Phase 0 shared NFT + lib (breaks early-sell tests — flip them in the same PR).  
2. Phase 1 claim 4626 (breaks 1:1 claim tests — flip in the same PR).  
3. Weighted Phase 2 + its spec/adversarial.  
4. Mixed-buffer Phase 2 + tests.  
5. Composed Phase 2 + tests.  
6. Single SE claim wire + Phase 2 + tests.  
7. Phase 4 docs.

Do not land Phase 0 without flipping tests in the same change.

---

## 9. Implementor checklist (no product forks)

- [ ] PRD v0.5 is the law; this file is the sequence  
- [ ] `BondNotMature` on DETF, both NFTs, lib  
- [ ] `removeFromDETFNFT` exists; redeem debits `detfNFTId`  
- [ ] Sell snapshots `protocolBefore`; no double `addToDETFNFT`  
- [ ] `buyClaim` mints then credits (live `totalAssets`)  
- [ ] `effectiveSharesOf(detfNFTId) == originalSharesOf(detfNFTId)`  
- [ ] Views quote only the rebasing bond  
- [ ] Redeposit DETF on close/redeem; never burn as user free DETF  
- [ ] `sellNFT` removed from ABI  
- [ ] Single SE claim pkg required  
- [ ] No SUT mocks; no `new` facets/DFPkgs; no DualLiquidity; no `via_ir`  
