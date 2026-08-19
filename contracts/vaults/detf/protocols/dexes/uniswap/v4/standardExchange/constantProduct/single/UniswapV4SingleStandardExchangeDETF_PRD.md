# Product Requirements Document (PRD)

## Title

**UniswapV4SingleStandardExchangeDETF** — true DETF with Uniswap V4 **Single SE Buffer Constant Product** reserve

## Status

**SUPERSEDED for mint/bond/burn/claim/close process** — use [`DETF_ALIGNMENT_PRD.md`](../../../../../../DETF_ALIGNMENT_PRD.md) D1–D28. This file remains for family curve/token-set notes.

**DRAFT v0.5** — Clarifications LOCK-ready: bond ungated when live; expansion realize on reward/compound/bond only; burn uses effective supply; shared epoch amendment planned. Co-located (internal product law).

| Related | Role |
|---------|------|
| **Reserve hook (mandatory dependency)** | [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](../../../../../../../../../hooks/uniswap/v4/standardExchange/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md) |
| **Hook impl plan** | Same directory under hooks — hook ABI freeze is a **hard coding gate** for this DETF |
| **This family impl plan** | [`UniswapV4SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md`](./UniswapV4SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md) (implementor SoT once stamped) |
| **Removed topology** | Former listing-family draft at `…/uniswap/v4/standardExchange/single/` (listing pool `hooks=0`, dual OOR bonds, app TWAP; no liquidity-holding reserve) — **deleted**; do not reintroduce |
| **Behavioral peer (code)** | Balancer `SingleStandardExchangeDETF` under `detf/…/balancer/v3/standardExchange/single/` — seigniorage split, burn LP formula, bond lifecycle, compound/expansion libs |
| **Shared core** | `detf/common/core/*` (`DETFThresholdPolicy`, `DETFUsageFeeLib`, `DETFBondNFTMathLib`, `DETFNaturalExpansionLib` **or epoch successor**, compound helpers) |
| **Shared compound / expansion law** | `docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` (this family **in scope**). **Epoch form + debt-inclusive synthetic** are the **planned shared target** for all true DETFs (amendment soon); this PRD §10 is the normative draft of that form. |
| **AGENTS.md** | DETF families — common expectations; product docs co-located with code |

**Short name:** UniV4 SE DETF (constant-product reserve family).

---

## 0. Intent

### 0.1 Why this family

Balancer true DETFs use a multi-asset weighted reserve and **BPT** principal. Bootstrap is awkward when the product goal is:

1. **List DETF vs a pair token** (e.g. USDC) on Uniswap V4 for public UX.  
2. **Price the SE leg by claim** (yield-aware) under the hood.  
3. **Start the reserve at a deploy-time price** from `PkgArgs` (may be far from abstract peg after free-float / market dynamics).  
4. Keep **BPT-like** bond/claim accounting via **fungible hook LP**.  
5. **Launch-rich Policy instances:** seed so synthetic can sit **well above peg**, offer high **token** expansion APY to bonders, and **dilute synthetic toward peg over months–~1 year** via deploy-time **epoch** premium-closure (see §10.2–§10.3).

The reserve host is:

**`UniswapV4SingleStandardExchangeBufferConstantProductHook`**

- Pool currencies: **DETF (raw leg) ↔ pairToken**  
- SE buffers pairToken; CP on raw DETF inventory × SE claim  
- Fungible LP ≈ BPT  
- Proportional deposit + zap-in; proportional withdraw + **zap-out**

### 0.2 Product one-liner

A **true DETF**: diamond **is** the DETF ERC-20; seigniorage mint/burn vs a **Uni V4 CP buffer reserve** with DETF self-leg; bond principal = **hook LP**; rebasing claim = pro-rata claim on **protocol-owned hook LP**; Policy/Open synthetic gates; **permissionless** first **bond** establishes live at **deploy-time creation rate**; Policy natural expansion is **immutable epoch premium-closure** paid to bonders.

### 0.3 Goals

1. Ship DETF package under  
   `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/`.  
2. Wire **one** backing `IStandardExchange` + **one** reserve hook instance (raw = this DETF, pair = `pairToken`).  
3. Primary mint/burn + bond + sell→claim + direct claim paths.  
4. Deploy-time **creation rate** for empty-reserve first join; synthetic + Policy/Open thereafter.  
5. Seigniorage inventory → bond reward ledger (**same split as Balancer Single SE**); protocol compound into reserve LP.  
6. **Natural expansion (Policy):** deploy-time **epoch length + closure rate**; full whole-epoch catch-up on touch; free DETF to bonders (claimable → optional rebasing claim).  
7. Production-first tests; no SUT mocks.

### 0.4 Non-goals (v1)

1. Implementing the reserve hook inside this package (hook is a dependency).  
2. Dual-OOR CL listing bonds / app-level listing oracle from the superseded PRD.  
3. Multi-vault / multi-SE composition.  
4. Balancer BPT reserve.  
5. Native ETH as pair (use WETH if needed).  
6. Cross-chain.  
7. Subclassing Balancer DETF contracts or Uni V4 SE DFPkg as claim.  
8. Guaranteeing peg, APY, or first-bond holder parity with later bonders (first bond may intentionally seed off-peg).  
9. Primary burn of free DETF to assets other than **pairToken**.  
10. MEV protection / commit-reveal on permissionless first bond.

---

## 1. Locked product decisions (summary)

| Topic | Decision |
|-------|----------|
| Family type name | **`UniswapV4SingleStandardExchangeDETF`** |
| Package path | `detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/` (PRD co-located) |
| True DETF | **Yes** — diamond is share ERC-20; reserve includes DETF self-leg |
| Reserve host | **Single SE Buffer CP Hook** only |
| Hook raw leg | **`address(this)` / detfToken** |
| Hook pair leg | **`pairToken`** ∈ backing SE `vaultTokens()` / `tokens()` |
| Backing SE | Same SE instance bound to the reserve hook; closed-form routes for settlement |
| Live | **Permissionless first successful bond** that joins reserve LP (synthetically ungated) |
| Creation rate | **Deploy-time `PkgArgs`** — sizes first-bond DETF for join so initial mid ≈ creation rate |
| Seigniorage | **Peer Single SE:** boost on pair notional → quote → usage fee → half-incentive inventory / user / feeTo |
| Primary mint (live) | Pair zap-in + free DETF; **Policy mint gate** uses **debt-inclusive** synthetic; does **not** realize expansion debt |
| Primary burn | **pairToken only**; `lpOut = detfBurned * protocolLp / effectiveSupply` where `effectiveSupply = totalSupply + pendingExpansion`; burn gate **debt-inclusive**; does **not** realize expansion debt |
| Bond (after live) | **No Policy/synthetic price gate** — proportional LP deepen; may still mint free seigniorage legs from quote; **does realize** expansion debt (reward path) |
| Bond principal | **Hook LP** on bond NFT package |
| Claim redeem | Same protocol-LP apportioning; pair / vaultShare / SE `tokens()`; **`InvalidRoute`** else |
| Free DETF → claim | **`depositSingle(DETF)`**; no seigniorage |
| Expansion realize paths | **Only** reward/compound-class touches: bond, `claimRewards`, `compoundProtocolRewards` (+ family reward updates). **Not** primary mint/burn |
| Route errors | **`InvalidRoute` only** |
| Fixed-point | Scale to **1e18** internal; scale back for transfers |
| Instance governance | Immutable / unowned after deploy |
| DETF DFPkg path | IndexedEx manager vault registry |
| Hook / children deploy | Hook: create3; bond NFT + rebasing: pure Crane; owner = DETF diamond |
| Fee-recipient NFT | **Wire like Balancer Single SE** (claimable free DETF; no auto-compound v1) |
| Compound | Shared law (protocol NFT only → single-sided DETF join) |
| Natural expansion | Deploy-time epochs + premium-closure; unlimited whole-epoch catch-up (`maxCatchUpEpochs=0`); **not** fee-oracle; **shared amendment planned** for all true DETFs |
| Synthetic + epoch debt | Pending expansion in synthetic denominator (§5.5) |
| Launch-rich narrative | High early token APY while rich; decays with premium; peg walk months–~1y; not year-long 4-digit APY (§10.3–§10.4) |
| Test matrix | **Gentle and launch-rich expansion PkgArgs are equal-priority rows** |

---

## 2. Role vocabulary (LOCKED)

| Role | Name | Meaning |
|------|------|---------|
| DETF share / diamond | `detfToken` / `address(this)` | ERC-20; reserve raw leg |
| Backing SE | `standardExchangeVault` / `backingStandardExchangeVault` | Inventory SE for settlement; **must not** list DETF in `tokens()` |
| SE share | `vaultShare` / `backingVaultShare` | SE ERC-20 share token (usually SE address) |
| Quote / buffer asset | `pairToken` | Hook pair leg; ∈ SE tokens; public market counter-asset; primary burn settlement |
| Reserve | `reserveHook` / `reservePool` | CP buffer hook + its V4 pool |
| Reserve principal | `reserveLp` / hook LP | Fungible LP from reserve hook (BPT analogue) |
| Bond NFT | `bondNft` | User bond positions; holds user `reserveLp` while open |
| Protocol principal | protocol-owned `reserveLp` | Primary mint joins, bond sells, compound, direct claim deposits — **held by rebasing package** (LOCK) |
| Rebasing claim | `rebasingClaimToken` | ERC-20 claim on protocol `reserveLp` |
| Creation rate | `creationPairPerDetfWad` | Deploy-time empty-book join rate (WAD after decimal normalize) |
| Rate asset (narrative) | often = `pairToken` | Settlement numeraire for synthetic peg and primary burn |

**Anti-patterns:** brand tickers; `pairToken` ∉ SE tokens; using Uni V4 SE DFPkg as claim; listing-pool dual OOR as bond principal; treating wrapper pricing hook as reserve; inventing hook APIs not in the hook PRD.

---

## 3. Topology (LOCKED)

```text
                    ┌──────────────────────────────────────────┐
                    │ UniswapV4SingleStandardExchangeDETF       │
                    │ diamond = detfToken ERC-20                │
                    │ immutable / unowned after deploy          │
                    └───────────────────┬──────────────────────┘
                                        │
     ┌──────────────────────────────────┼──────────────────────────────────┐
     │                                  │                                  │
     v                                  v                                  v
┌──────────────┐              ┌─────────────────────┐            ┌─────────────────┐
│ Backing SE   │              │ Reserve CP Hook       │            │ Bond NFT pkg    │
│ (e.g. Uni V4 │              │ raw = DETF            │            │ owns user LP    │
│  SE on       │◄─buffer──────│ pair = pairToken      │──LP───────►│ while bonded    │
│  WETH/USDC)  │              │ SE = same backing SE  │            │ reward ledger   │
└──────────────┘              │ fungible LP           │            └────────┬────────┘
                              └──────────┬────────────┘                     │ sell
                                         │ protocol LP                      │
                                         v                                  v
                              ┌─────────────────────┐            ┌─────────────────┐
                              │ Rebasing claim pkg   │◄───────────│ migrate LP →    │
                              │ holds protocol LP    │  deposit   │ protocol        │
                              │ redeem pair/share/SE │            └─────────────────┘
                              └─────────────────────┘
```

**Opacity:** DETF production talks to `IStandardExchange*`, reserve hook ABI, bond NFT APIs, rebasing APIs, fee oracle, shared DETF libs. DFPkg may call PoolManager `initialize` / plumbing only. Product mid is **never** V4 `sqrtPriceX96` after first bond.

**Same SE instance:** Backing SE for mint/bond settlement **is** the SE bound to the reserve hook.

---

## 4. Liveness & first bond (LOCKED)

### 4.1 States

| State | Condition |
|-------|-----------|
| **Inert** | Deployed; reserve hook bound; V4 pool may be initialized with plumbing; **no** successful bond yet; primary mint/burn blocked; non-first bonds blocked |
| **Live** | First **successful bond** completed that minted DETF for join and placed **reserve LP** on the bond NFT; `isReserveLive = true` |

### 4.2 First bond access (LOCKED)

**Permissionless.** Any address may establish live with a successful first bond.  
No product min notional beyond hook **MINIMUM_LIQUIDITY** / geometric mint constraints.  
If geometric mint would mint LP &lt; MINIMUM_LIQUIDITY after fees, **revert** with a clear product error (cannot go live).  
No MEV protection in v1; operators should seed with a **small but viable** first bond. **No holder-parity guarantee** between first and later bonders.

### 4.3 Creation rate (deploy-time)

| Field | Meaning |
|-------|---------|
| **`creationPairPerDetfWad`** | After **decimal normalize to 1e18**, how much **pairToken** (WAD) equals **1e18 DETF** at empty-book join. Encodes “list DETF at price P.” |
| Storage | Resolved from `PkgArgs` at deploy; **immutable** on instance |

#### Decimal convention (LOCKED)

1. Convert amounts to **internal WAD (1e18)** for all pricing, synthetic, creation-rate, and seigniorage math:  
   `amountWad = amountRaw * 10^(18 - decimals)` (and inverse for transfers).  
2. `creationPairPerDetfWad` is stored and consumed **only in WAD space**.  
3. Scale back to native decimals for ERC-20 transfers and hook calls.

**Example (USDC 6 decimals, DETF 18):**  
Want “1 DETF = 2 USDC” at seed → `creationPairPerDetfWad = 2e18`.  
User supplies `2e6` USDC raw → `2e18` pair WAD → `detfForJoin = 1e18` (before fees/split).

### 4.4 First bond mechanics (normative)

First bond is **synthetically ungated** (Policy and Open).

1. User supplies bond capital: **`pairToken`**, **backing vault share**, or other **SE-accepted token** (see §7).  
2. Convert capital to **pair-notional** \(C\) in WAD (if share/other: SE preview → pair, then scale).  
3. **Mint DETF for join** using **creation rate only** (not market CP mid):

```text
// WAD space
detfForJoinWad = pairNotionalWad * 1e18 / creationPairPerDetfWad
// fixed-point: mulDiv; direction pair capital → DETF amount for proportional join
```

4. Apply **peer mint modifiers** on the join-sized gross (same as Balancer bond spirit):  
   - Treat `detfForJoin` as **gross** for split purposes **or** apply boost-on-notional then quote — **normative for first bond:** size join DETF from creation rate on **post-boost pair notional** when seigniorage incentive &gt; 0, then `_splitMintedDetf(gross)` for free legs (see §6).  
   - **Pool join** uses the creation-rate (boosted) DETF amount as self-leg.  
   - **Additionally mint** free legs: `userDetf`, `feeToDetf`, `inventoryDetf` (same split as peer).  
5. Settle capital to **pairToken** (v1: convert to pair before hook `deposit`).  
6. Reserve hook **`deposit`** proportional: join DETF + pair (clamp/refund per hook).  
7. **LP → bond NFT package** for `tokenId`; record principal metadata.  
8. Set **`isReserveLive = true`**.

**Empty book:** hook first mint is dual-asset geometric; ratio forced by creation-rate mint sizing so initial mid ≈ creation rate (modulo SE buffer fees / dust).

### 4.5 After live

- **Primary mint/burn:** subject to Policy/Open **debt-inclusive** synthetic gates (Open: ungated).  
- **Further bonds (after live):** **no synthetic / Policy mint gate.** Bonds **deepen liquidity** (proportional join + LP on NFT); they are not treated as high-impact free-float seigniorage that must wait on mint threshold. First bond remains the only liveness gate.  
- Bond paths **may still** mint free DETF legs from the seigniorage split of the join quote (peer fee split); that is inventory/fee economics, **not** a Policy price gate.  
- Bond / `claimRewards` / `compoundProtocolRewards` **realize** pending expansion debt (§10.2). Primary mint/burn **do not**.  
- Reserve mid from CP effective reserves (raw DETF × SE claim).  
- Creation rate remains **peg reference** for synthetic; **not** used to size later mints.  
- **Live does not imply burnable depth:** first-bond LP sits on the NFT; protocol LP may be ~0 until primary mint, bond-sell, or compound. Primary burn **reverts** if protocol LP insufficient (intentional).

---

## 5. Pricing, synthetic, thresholds (LOCKED)

### 5.1 Marks

| Mark | When | Use |
|------|------|-----|
| **Creation rate** | First bond only (and inert info) | Size first-bond DETF for join |
| **Reserve mid** | Live | CP mid from effective reserves; **seigniorage quotes only** — **never** threshold gates alone |
| **FD backing / synthetic** | Live | Fully diluted pair claim of **relevant reserve LP** ÷ **effective DETF supply** (includes **pending epoch expansion debt**), normalized by creation rate — see §5.5 |

### 5.2 Decimal scale (LOCKED)

All internal pricing, synthetic, thresholds (already WAD), creation rate, seigniorage boost, and expansion math run in **1e18-normalized** units. Scale to/from native decimals only at token boundary I/O.

### 5.3 Seigniorage quote shape after live (LOCKED — peer Single SE)

**Goal:** replicate Balancer `SingleStandardExchangeDETF` seigniorage economics on this host.

Canonical peer shape (`DETFUsageFeeLib` + fee oracle + curve quote):

```text
// 1) Boost pair notional by seigniorage incentive (oracle WAD)
pairBoosted = pairNotional * (1e18 + seigniorageIncentiveWad) / 1e18

// 2) Gross DETF from reserve-aware closed form on boosted notional
grossDetf = quoteDetfAgainstReserve(pairBoosted)
//   Live: CP closed-form analogue of peer out-given-in / mid-aware join quote
//   (exact fixed-point in impl plan; MUST match preview path)

// 3) Split (identical to peer _splitMintedDetf)
feeToDetf     = gross * usageFeeWad / 1e18
afterFee      = gross - feeToDetf
inventoryDetf = afterFee * (seigniorageIncentiveWad / 2) / 1e18
userDetf      = afterFee - inventoryDetf
```

| Path | Capital → reserve | Free DETF |
|------|-------------------|-----------|
| **Live primary mint** | **Single-sided** pair into protocol LP: hook `depositSingle(pairToken)` (or equivalent zap-in). **No** DETF self-leg join on this path (peer: vault-share-only join). | Mint `user` / `feeTo` / `inventory` only (supply ↑ by gross) |
| **Bond (live)** | **Proportional** `deposit(joinDetf, pair)` where `joinDetf` is the gross quote DETF self-leg; LP → bond NFT | **Also** mint free `user` / `feeTo` / `inventory` (peer bond double-mint of join + free legs) |
| **First bond** | Creation-rate sized join DETF + pair; LP → bond NFT | Same free legs from split of gross |

**`quoteDetfAgainstReserve` (economic LOCK):** closed-form DETF out for exact-in pair notional against **live effective reserves** (raw DETF balance × SE claim in pair), fee-aware as the hook/CP peer requires. **Not** tick-walk; **not** creation rate after live. Impl plan freezes fixed-point to match hook deposit math / ConstProdUtils spirit.

**Preview == execution** on closed-form routes (≤ few-wei only if SE multi-leg dust forces it; document).

### 5.4 Settlement `tokenIn` (primary mint & bond capital)

| `tokenIn` | Allowed | pairNotional |
|-----------|---------|--------------|
| `pairToken` | Yes | `amountIn` (scale to WAD) |
| `backingVaultShare` | Yes | SE preview share → pair |
| Other token ∈ SE `tokens()` | Yes | SE preview token → pair |
| Else | **`InvalidRoute`** | — |

**v1:** always settle to **pairToken** before hook deposit (hook buffers pair into SE).

### 5.5 Synthetic (gates + expansion) — **includes pending epoch debt** (LOCKED)

**Peg narrative:** abstract **1e18** means FD pair-backing per DETF equals **creation rate** (pair per DETF, both WAD).

**Problem without debt:** expansion accrues in whole epochs but free DETF is only minted on touch. Spot synthetic using `totalSupply` alone looks **too rich** until catch-up mints; then supply jumps and synthetic **cliffs down** (can overshoot mint/burn bands or mint more capital-backed DETF than “true” richness allows).

**Rule (LOCKED):** `syntheticPrice()` / gate inputs use **effective supply** = on-chain `totalSupply` + **pending expansion DETF** (unrealized whole epochs since `lastExpansionTimestamp`). Realizing the debt mints that same pending amount → synthetic is continuous at the mint (no surprise overshoot from the debt itself).

```text
// LP held for FD: protocol (rebasing package) + bond NFT vault + DETF diamond if any
// Exclude address(0) MINIMUM_LIQUIDITY residual unless held in counted set
fdPairWad = sum over counted LP of previewZapOutToPair(lp)   // WAD

// --- Spot (no debt) — internal helper only ---
S_spot = (fdPairWad * 1e18 / totalSupply) * 1e18 / creationPairPerDetfWad
// if totalSupply == 0: S_spot = 1e18 (or inert convention as peers)

// --- Pending epoch expansion debt (view; same formula as mint path §10.2) ---
pendingExpansionDetf = previewPendingExpansionMint()  // 0 if inert / Open / no epochs / no premium / unsown last
// Uses S_spot + epoch params for one-shot O(1) premium-closure × whole epochs
// (optional maxCatchUpEpochs applies here too)

effectiveSupply = totalSupply + pendingExpansionDetf
// if effectiveSupply == 0: synthetic = 1e18

synthetic = (fdPairWad * 1e18 / effectiveSupply) * 1e18 / creationPairPerDetfWad
// synthetic > 1e18 ⇒ richer than creation (above peg), after accounting for owed free DETF
```

| Mode | When live |
|------|-----------|
| **Policy** | Mint / bond-open DETF mint iff `synthetic > mintThreshold` (default 1.05e18). Burn free DETF iff `synthetic < burnThreshold` (default 0.95e18). Equality = deadband. **`synthetic` = debt-inclusive.** |
| **Open** | Threshold gates **always pass**. Pending expansion is **0** (Open never expands). |
| **First bond** | Synthetically **ungated** (both modes). No expansion debt before live seed of `lastExpansionTimestamp`. |

**Source of truth:** `ThresholdMode` + thresholds from **`PkgArgs` → resolve → storage only** (`DETFThresholdPolicy`). Fee oracle does **not** set thresholds.

**Gates use debt-inclusive synthetic only** — never reserve mid alone; never spot supply alone for Policy gates after live.

**Realize vs accrue (LOCKED v0.5):**

| Action | Rule |
|--------|------|
| **View / gates** | Always use debt-inclusive `synthetic` for Policy **primary mint** and **primary burn** gates |
| **Realize pending expansion** | **Only** on **reward / compound / bond** paths: `bond` (incl. first bond after seed), `claimRewards`, `compoundProtocolRewards`, and any internal reward-update that already hits the bond ledger. Mint `pendingExpansionDetf`, advance `lastExpansionTimestamp` |
| **Do not realize on** | **Primary mint** and **primary burn** entrypoints (debt stays unpaid; synthetic still counts it) |
| **Capital mint allowed?** | Debt-inclusive `synthetic` — large unpaid debt can **block** primary seigniorage mint without requiring the minter to clear expansion |
| **Realize when already ≤ mintThreshold?** | **Yes on realize-paths** — clear accrued debt even if debt-inclusive synthetic is already ≤ mintThreshold / in deadband (reward/compound/bond still clear) |

**Info surface:** `syntheticPrice()` (debt-inclusive), `pendingExpansionDetf()` (recommended), optional `syntheticPriceSpot()`.

### 5.6 Primary burn of DETF (LOCKED)

**Settlement: `pairToken` only.** Any other `tokenOut` → **`InvalidRoute`**.

Not sized by synthetic (synthetic only gates).

**LP basis (LOCKED v0.5 — effective supply):**

```text
// Protocol LP only (rebasing package). Do NOT include bond NFT user LP.
protocolLp = reserveLp.balanceOf(protocolLpHolder)
pending = previewPendingExpansionMint()           // same as §5.5
effectiveSupply = totalSupply + pending           // pre-burn; pending not yet minted
lpOut = detfBurned * protocolLp / effectiveSupply
// if protocolLp == 0 or lpOut == 0 → revert
```

**Rationale:** unpaid expansion free DETF is already “owed” dilution; burners share protocol LP against that larger free-float denominator (more conservative for protocol LP than on-chain supply alone). Diverges from Balancer peer’s on-chain-only denominator by design for this debt model.

**Execution:**

1. Require live + **debt-inclusive** burn gate (Open: always when live).  
2. Pull free DETF; compute `lpOut` with **effectiveSupply** (do **not** realize expansion here).  
3. Burn DETF.  
4. Usage fee on burn if peer path does; **no** mint-style inventory split on burn.  
5. `withdrawSingle(lpOut, pairToken)` → pay **pairToken**.  
6. Enforce `minOut`.

**Do not** size burn from creation rate while live.  
**Do not** draw on bond-NFT LP for primary burn.  
**Do not** clear expansion debt on burn.

---

## 6. Fees (two layers — do not conflate)

| Kind | What | Source |
|------|------|--------|
| **A. Reserve CP swap fee** | 0.3% on hook swaps / zap internal swaps | Hook law (retained by LPs) |
| **B. DETF protocol fees** | Usage fee, seigniorage incentive, mint split | Vault Fee Oracle |
| **C. SE usage fees** | On buffer/mint routes inside SE | SE + oracle |
| **D. Hook protocol growth** | Uni V2-style LP mint to feeTo on k growth | Hook `feeOracle` / `dexSwapFee` |

**Bond lock terms (LOCKED, peer):** fee oracle via `DETFBondNFTMathLib` — **revert if lock &lt; min**; **clamp to max** if longer (bonus at max).

**Fee-recipient NFT (LOCKED):** wire fee-recipient bond NFT as peer Single SE (claimable free DETF; **no** auto-compound in v1).

---

## 7. Primary mint after live (LOCKED)

1. **Do not** realize expansion debt / advance `lastExpansionTimestamp` (not a realize-path).  
2. **Debt-inclusive** Policy mint gate (`synthetic` §5.5). Open: ungated when live.  
3. Resolve `pairNotional` from `tokenIn` (WAD).  
4. Convert `tokenIn` → pairToken (SE as needed).  
5. Quote gross DETF (boost → `quoteDetfAgainstReserve` → split).  
6. **Deepen protocol LP:** hook **`depositSingle(pairToken)`**; LP to **rebasing / protocol holder**.  
7. Mint free DETF: user / feeTo / inventory → bond vault (if inventory &gt; 0).  
8. **Do not** auto-call `compoundProtocolRewards` on this path if that entry always realizes expansion (v1: keep expansion realize off primary mint; public compound / bond / claim clear debt).

**Invariant:** live primary mint does **not** require dual-sided proportional deposit; peer is single-sided external-leg join + free DETF mint.

---

## 8. Bond lifecycle (LOCKED)

### 8.1 Open (after live; first bond §4)

| Item | Rule |
|------|------|
| Access | Permissionless |
| Capital | pairToken / vault share / SE token → pair notional |
| **Price / Policy gate** | **None after live.** Bonds deepen LP liquidity; not gated on synthetic. First bond only establishes live (also ungated). |
| DETF economics | Join-sized DETF + free fee/inventory/user legs from seigniorage **split** of join quote (peer fee family) — **not** a mint-threshold gate |
| Join | Proportional hook `deposit`; **LP → bond NFT** |
| Expansion debt | **Realize** pending expansion on bond (reward-class path) before/with reward update |
| effectiveShares | **pair principal at open** × lock bonus only |
| claimRewards | Free DETF anytime while open (**realizes** expansion debt) |
| Partial close | **Forbidden** |

`acceptedBondTokens()`: at least `pairToken`, `backingVaultShare`, and SE `tokens()` accepted for capital (family list).

### 8.2 Maturity close (full only)

1. Pay pending rewards.  
2. Bond NFT withdraws **all** position LP.  
3. Prefer hook **`withdrawSingle(lp, pairToken)`** when zap-eligible; pay user **pairToken only**.  
   Fallback: proportional withdraw → burn/swap residual DETF → pair only.  
4. Retire NFT; stop accrual.

### 8.3 Sell → rebasing claim (full only)

1. Pay pending rewards.  
2. Transfer **hook LP** from bond NFT to **rebasing package** (prefer ERC-20 LP transfer).  
3. Mint rebasing claim from **Δ protocol LP contribution** valued as zap-out-to-pair (WAD).  
4. Credit protocol NFT id 0 principal weight (pair principal spirit) if peer ledger requires.  
5. Retire user NFT.

**Fallback if LP transfer blocked:** withdraw → rebasing `deposit` / `depositSingle`.

### 8.4 Protocol NFT id 0

- Reward ledger weight for inventory seigniorage / expansion.  
- Compound: §10.  
- No required dual position.

---

## 9. Rebasing claim (LOCKED)

### 9.1 Package

- Per-DETF-instance package under  
  `detf/protocols/dexes/uniswap/v4/common/` (bond NFT + rebasing shared with this family; **not** Balancer bond packages).  
- Ownable/operable owner = DETF diamond for privileged absorb/donate.  
- Pure Crane deploy (not vault registry).  
- **Holds protocol LP** (LOCK).

### 9.2 Who holds LP

| Holder | LP |
|--------|-----|
| User bond (open) | Bond NFT package |
| Protocol / claim reserve | **Rebasing package** |
| Primary mint joins | Protocol (rebasing) |
| Compound | Protocol (rebasing) |

### 9.3 Mint claim

| Path | Seigniorage DETF mint? | Mechanics |
|------|------------------------|-----------|
| Bond sell | No | Migrate LP → protocol; mint claim from contribution |
| New money (pair / SE token / share) | **No** | Settle to pair → hook `depositSingle(pair)` (or proportional if dual) → LP to protocol → mint claim |
| Free DETF | **No** | `depositSingle(DETF)` → LP to protocol → mint claim (price impact is user’s; preview includes impact) |

Claim shares: SE-style pro-rata of **zap-out-to-pair contribution**. First depositor inflation guards as peers.

### 9.4 Redeem claim (LOCKED)

**Apportioning (same reserve LP math as DETF burn spirit):**

```text
lpOut = claimSharesBurned * protocolLp / claimTotalSupply
// burn claim shares; burn/redeem protocol LP
// pairNotional = previewZapOutToPair(lpOut)   // single ruler for all tokenOut
```

**`tokenOut` options (user chooses unwrap depth):**

| `tokenOut` | Execution |
|------------|-----------|
| `pairToken` | Hook `withdrawSingle(lp, pairToken)` → pay pair |
| `backingVaultShare` | Withdraw such that user receives SE shares (proportional withdraw SE leg / unwrap path that leaves shares — exact in impl plan; **same `lpOut`**) |
| Token ∈ SE `tokens()` | Obtain pair (or shares) then SE `exchangeIn` / unwrap to `tokenOut` |
| Else | **`InvalidRoute`** |

`pairToken` is always ∈ SE tokens (buffer requirement) — redeem-to-pair is the default shallow path; other outs are optional SE unwrap of the same pair-notional claim.

**Preview == execution.**

---

## 10. Protocol compound & natural expansion (LOCKED for this family)

In scope of shared compound/expansion **program**. **Compound** follows shared LOCKED law. **Natural expansion for this family** uses the **deploy-time epoch form** below (premium-closure economics preserved; continuous `dt` + catch-up seconds/bps brakes are **not** used). Shared lib may grow an epoch API or a family helper; do not invent a second reward ledger.

### 10.1 Compound

| Item | Rule |
|------|------|
| Who | Protocol NFT id 0 pending free DETF only |
| Method | **Single-sided DETF into reserve**: hook `depositSingle(DETF)` → protocol LP ↑ |
| Claim | **0** new claim shares to protocol (depth for existing claim holders) |
| Trigger | Lazy on reward-updating touches + public `compoundProtocolRewards()` |
| Failure | Best-effort on lazy paths |

### 10.2 Natural expansion — epoch form (LOCKED)

| Item | Rule |
|------|------|
| When | Live + `thresholdMode == Policy`; pending accrues while **S_spot > peg** (algorithm); **primary** mint/burn gates use **debt-inclusive** synthetic (§5.5) |
| Open | **Never** expands; pending always 0 |
| Cadence | **Discrete epochs**; length fixed at deploy |
| Rate source | **`PkgArgs` only** — immutable; **not** fee oracle |
| Economic shape | **Premium-closure** per whole epoch × epoch count |
| Pending debt | Always in **synthetic** denominator (§5.5) |
| Distribution | Same effective-share weights as seigniorage inventory |
| **Realization paths** | **Only** bond / `claimRewards` / `compoundProtocolRewards` / bond-ledger reward updates — **not** primary mint or primary burn |
| Catch-up | All whole epochs; **`maxCatchUpEpochs = 0` → unlimited** (family default) |
| Shared law | **Planned amendment** of shared expansion PRD so all true DETFs can adopt this epoch form |
| Rewards use | Claim free DETF → optional rebasing claim deposit |

#### Deploy-time params (immutable)

| Field | Meaning |
|-------|---------|
| `expansionEpochLength` | Seconds per epoch. Must be **> 0** after resolve. |
| `expansionClosureRatePerYearWad` | **`R`**: fraction of **premium** closed per year (1e18). |
| `expansionMaxCatchUpEpochs` | `0` = unlimited full catch-up (family default). |
| Storage | `lastExpansionTimestamp` — seed on first expansion-eligible update after live |

**Arg resolve:** `expansionEpochLength == 0` → **8 hours**. `expansionClosureRatePerYearWad == 0` → **`0.10e18`** (gentle). Launch-rich templates **must set explicit `R`** (§10.4). Open / gates turn expansion off — not a zero rate.

#### Preview pending + per-touch mint (normative, O(1))

```text
// Shared helpers
YEAR = 365 days
closurePerEpochWad = expansionClosureRatePerYearWad * expansionEpochLength / YEAR

function previewPendingExpansionMint():
  if !live || Open || lastExpansionTimestamp == 0: return 0
  if now <= lastExpansionTimestamp: return 0
  epochs = (now - lastExpansionTimestamp) / expansionEpochLength
  if maxCatchUpEpochs > 0: epochs = min(epochs, maxCatchUpEpochs)
  if epochs == 0: return 0

  // One-shot premium-closure at S_spot (no circularity with pending)
  S_spot = fdPair * 1e18 / totalSupply / creation   // as §5.5 spot
  if S_spot <= 1e18: return 0
  premium = S_spot - 1e18
  mintPerEpoch = totalSupply * premium * closurePerEpochWad / (1e18 * S_spot)
  mint = mintPerEpoch * epochs
  return mint <= dust ? 0 : mint

// syntheticPrice() = fdPair / (totalSupply + previewPendingExpansionMint()) / creation   // §5.5

// On REALIZE paths only (bond / claimRewards / compoundProtocolRewards / bond reward update):
// Primary mint & primary burn call preview for gates but MUST NOT run this block.
pending = previewPendingExpansionMint()
if lastExpansionTimestamp == 0:
  lastExpansionTimestamp = now
  // seed only; no backlog from pre-live
else if pending > 0:
  mint free DETF `pending` → bond NFT vault reward balance
  epochs = ... same as preview ...
  lastExpansionTimestamp += epochs * expansionEpochLength
  // post-mint: on-chain supply matches prior debt-inclusive synthetic (debt alone)
// compound path: then try protocol compound (best-effort)
```

**Primary mint/burn:** may read debt-inclusive synthetic for gates; **must not** mint expansion or advance `lastExpansionTimestamp`.

**UI honesty (LOCKED product copy):**

- Report **run-rate token APY while rich** (state-dependent); it **decays** as premium closes.  
- **Do not** advertise constant multi-thousand % APY for a fixed multi-month / year horizon.  
- Token APY ≠ USD APY.

#### What not to do

- No second expansion / debt ERC-20 (pending is **implicit** in math + then minted free DETF).  
- No fee-oracle expansion params.  
- No continuous 1-day / 50 bps clamps (this family).  
- No expansion under Open.  
- No epoch loop in Solidity.  
- Do not use spot-only synthetic for Policy capital-mint gates after live.

### 10.3 Product targets (LOCKED intent)

| Target | Decision |
|--------|----------|
| **Launch-rich Policy** | Instance can sit **well above peg**; bonders earn high **token** expansion APY **while rich** |
| **Peg walk** | Size `R` so premium can fall to near mint-threshold band over **months–~1 year** (expansion-only ideal) |
| **Not a target** | Sustained **3–4 digit compounded token APY for a full year** while remaining rich — incompatible with premium-closure (APY dies as synthetic falls / gates stop) |
| **Early hot APY** | **Allowed** at high premium + high `R` + short epochs (UI: current run-rate only) |
| **Debt-inclusive synthetic** | Pending epochs always in synthetic so catch-up **does not** cliff-overshoot (§5.5) |
| **Bonder loop** | claim free DETF → optional `depositSingle(DETF)` into rebasing claim |

### 10.4 Reference tables — `R`, peg walk, APY (do not re-derive ad hoc)

Notation:

- **`R`** = `expansionClosureRatePerYearWad / 1e18` (e.g. `4.4` means `4.4e18` in PkgArgs).  
- **Premium** = `max(synthetic − 1, 0)`. Ideal expansion-only: `(S(t)−1) = (S0−1) e^{−R t}`.  
- **Half-life of premium** ≈ `0.693 / R` years.  
- **Approx annual supply print at constant S** (run-rate while stuck at that S):  
  `print ≈ ((S−1)/S) × R`  (fraction of supply / year).  
- **Rough compounded “token APY”** if that print all went to a fixed bonder base equal to full supply and compounded continuously: order-of **`e^{print} − 1`**. Real bonder APY is **higher** if few bonds share the mint, **lower** as S falls. **Illustrative only.**

#### A. Peg walk time (expansion-only, fixed `fdPair`)

| Start `S0` | Target `S` | Premium factor `k = (S0−1)/(S−1)` | `R` for **~1 year** | `R` for **~6 months** | PkgArgs `expansionClosureRatePerYearWad` (~1y) |
|------------|------------|-----------------------------------|---------------------|------------------------|------------------------------------------------|
| 1.20 | 1.05 | 4 | **~1.4** | **~2.8** | `~1.4e18` |
| 2.0 | 1.05 | 20 | **~3.0** | **~6.0** | `~3.0e18` |
| 3.0 | 1.05 | 40 | **~3.7** | **~7.4** | `~3.7e18` |
| 5.0 | 1.05 | 80 | **~4.4** | **~8.8** | `~4.4e18` |
| 5.0 | 1.05 | 80 | 1.0 → **~4.4 years** | — | `1e18` too slow for 1y |
| 5.0 | 1.05 | 80 | 0.10 → **~44 years** | — | `0.10e18` gentle only |

#### B. Run-rate supply print & illustrative token APY **at fixed S** (does not hold as S falls)

| Spot `S` | `R` | Approx print / supply / year | Illust. continuous compound if print were constant all year* |
|----------|-----|------------------------------|---------------------------------------------------------------|
| 1.20 | 0.10 | ~1.7% | ~1.7% |
| 1.20 | 1.4 | ~23% | ~26% |
| 2.0 | 3.0 | ~150% | ~350% |
| 5.0 | 4.4 | ~350% | ~3,200% (order **4-digit** early) |
| 5.0 | 8.8 | ~700% | very high early; peg walk ~6 mo |

\*This **overstates** multi-month realized APY because premium-closure **reduces** print as `S` falls. Use only to explain “early 3–4 digit possible at multi-x S + high R,” not year-long constant APY.

#### C. Epoch length (compounding optics, not peg speed if `R` annual is fixed)

| `expansionEpochLength` | Epochs / year | Role |
|------------------------|---------------|------|
| 1 days | ~365 | Gentle / simple |
| **8 hours** | **~1,095** | **Default resolve / OHM-like cadence** |
| 1 hours | ~8,760 | Hot launch UI granularity |
| 30 min | ~17,520 | Max “gamey”; same annual `R` ⇒ same peg path |

`closurePerEpochWad = R_wad * epochLength / YEAR` — **shorter epoch alone does not speed peg walk**.

#### D. Example full `PkgArgs` bundles (copy-paste intent)

| Bundle | Epoch | `R` (wad) | maxCatchUpEpochs | Intent |
|--------|-------|-----------|------------------|--------|
| **Gentle** | 8h (`28800`) or `0`→8h | `0` → `0.10e18` | `0` | Peer-like slow policy |
| **Launch-rich 1y from ~S=5** | `28800` (8h) | **`4.4e18`** | `0` | High early token APY; ~1y ideal peg walk from 5→~1.05 |
| **Launch-rich 1y from ~S=2** | `28800` | **`3.0e18`** | `0` | Milder rich |
| **Launch-rich 6mo from ~S=5** | `3600` (1h) | **`8.8e18`** | `0` | Faster walk; sharper dilution / cliffs |
| **TestBase** | **Two equal rows:** Gentle + Launch-rich 1y from ~S=5 | both | Matrix — neither preferred |

Always **Policy** mode for expansion. Seed `lastExpansionTimestamp` on first **realize-path** after live (typically first bond’s reward update). Confirm live `syntheticPrice()` (debt-inclusive) before marketing richness.

#### E. Operator checklist

1. Simulate first bond + free legs → measure **S**.  
2. Pick target horizon and row in table **A** → set **`R`**.  
3. Pick epoch from **C** (default 8h).  
4. Expect **early** high token APY only if **S** multi-x and **R** high (**B**); do not promise year-long 4-digit APY.  
5. Debt-inclusive synthetic means UI “synthetic” already drops as epochs accrue **before** someone claims.

---

## 11. Deploy & PkgArgs (LOCKED fields)

Typed surface: `IUniswapV4SingleStandardExchangeDETDFPkg.deployVault(PkgArgs args, uint256 mineNonce)`. The nonce is **not** a PkgArgs field. Caller premines via `UniswapV4DetfHookPremineLib`. Deploy arity SoT: [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md`](../../UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md).

### 11.1 Deploy sequence (postDeploy spirit)

DETF `postDeploy` deploys a **bootstrap** reserve hook only (no `deployPair`, no finalize, no children). Hook `postDeploy` does **not** init the product door. After `deployVault`, callers open the door on `IUniswapV4HookStagedPairInit` (`productTokensCp` + one TX), then `finalizeInitialization`, then `completeReserveBondNft` then `completeReserveClaim` on this `I*DETF`. TestBase `setUp` may call `UniswapV4DetfHookStagedInitLib.ensureReserveReadyCp`. SoT: [`UNISWAP_V4_SE_DETF_STAGED_HOOK_INIT_PRD.md`](../../UNISWAP_V4_SE_DETF_STAGED_HOOK_INIT_PRD.md).

1. Deploy DETF diamond via vault registry (inert, unwired).  
2. Deploy reserve hook (bootstrap only):  
   `(poolManager, feeOracle, standardExchange, pairToken, rawToken=DETF)`.  
3. Store creation rate, thresholds, mode, expansion params, child **package** addresses.  
4. Validate `pairToken ∈ SE.tokens()`; SE does not list DETF.  
5. Later (not in `postDeploy`): one `deployPair` + finalize on the hook; then two DETF wiring fns.

### 11.2 PkgArgs (normative)

| Field | Notes |
|-------|--------|
| `standardExchangeVault` | Backing SE |
| `pairToken` | Must ∈ SE tokens |
| `poolManager` | Uni V4 PoolManager |
| `creationPairPerDetfWad` | First-bond / peg reference (WAD) |
| `thresholdMode`, mint/burn thresholds | Shared policy resolve |
| `expansionEpochLength` | Seconds; `0` → family default (8 hours recommended) |
| `expansionClosureRatePerYearWad` | Premium closed per year (1e18); `0` → 10%/yr gentle default; launch-rich templates set explicit higher `R` |
| `expansionMaxCatchUpEpochs` | `0` = unlimited full whole-epoch catch-up (family default) |
| Bond NFT / rebasing package refs | Factory wiring |
| Hook salt namespace (optional) | Multi-instance hooks |
| Fee oracle | Manager / vault wiring |

**Not used:** listing TWAP seconds, widthMultiplier OOR, hooks=address(0) listing pool.

---

## 12. Public surface (normative groups)

| Group | Examples |
|-------|----------|
| **Info** | `isReserveLive`, `syntheticPrice` (**debt-inclusive**), `pendingExpansionDetf` (recommended), optional spot synthetic, thresholds, `isMintingAllowed` / `isBurningAllowed`, `creationPairPerDetfWad`, expansion getters, reserve/hook/SE |
| **Exchange in** | Mint DETF from pair/share/SE token; burn DETF→**pairToken only**; SE passthrough where peer allows |
| **Bond** | `bond`, maturity close, `sellPositionToDetfNft`, `claimRewards`, `acceptedBondTokens` |
| **Claim** | Direct deposit paths; redeem claim with `tokenOut` matrix §9.4 |
| **Compound / expansion** | `compoundProtocolRewards` (+ optional atomic peer); lazy update on touches |
| **Errors** | `InvalidRoute`, mint/burn not allowed, reserve not live, lock too short, min out, first-bond below MINIMUM_LIQUIDITY |

Exact selector layout follows Crane facet split (Info / In / Out / Bonding / …) in impl plan.

---

## 13. Package layout

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/
  standardExchange/
    constantProduct/
      single/
        UniswapV4SingleStandardExchangeDETF_PRD.md          # this file (internal law)
        UniswapV4SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md
        UniswapV4SingleStandardExchangeDETFDFPkg.sol
        UniswapV4SingleStandardExchangeDETFRepo.sol
        UniswapV4SingleStandardExchangeDETFCommon.sol
        … Facets / Targets / FactoryService / TestBase
    # former single/ listing-family draft — deleted (no liquidity-holding reserve)
  common/
    nft/      # Uni V4 DETF bond NFT (LP principal)
    rebasing/ # claim on protocol hook LP (holds protocol LP)
```

**Fresh codepath rule:** do not subclass Balancer Single SE contracts; reuse `detf/common/core/*` libs.

---

## 14. Canonical flows

1. **Deploy** — creation rate, Policy/Open, SE, hook, pool init plumbing, bond + rebasing.  
2. **First bond (live)** — permissionless; small capital OK if ≥ MINIMUM_LIQUIDITY; mint DETF at creation rate; proportional join; LP on NFT; live=true.  
3. **Second+ bonds** — market quote; **no** synthetic mint gate; LP on NFT; realize expansion + rewards.  
4. **Primary mint** — capital → free DETF + protocol LP zap-in; debt-inclusive Policy gate; does **not** realize expansion.  
5. **Primary burn** — burn free DETF → pair only; effectiveSupply basis; debt-inclusive burn gate; does **not** realize expansion.  
6. **Maturity** — withdraw LP; pair to user.  
7. **Sell bond** — LP to protocol; mint claim.  
8. **Direct claim** — pair/SE or free DETF via depositSingle; no seigniorage.  
9. **Redeem claim** — burn claim; same LP apportioning; pay pair / share / SE token.  
10. **Compound / expansion** — §10.  
11. **External swap** — public V4 pool DETF↔pair via hook (UI allowlist separate ops concern).

---

## 15. Testing expectations

1. Deploy inert; primary mint reverts; non-first bond reverts.  
2. Permissionless first bond at creation rate → live; mid ≈ creation; MINIMUM_LIQUIDITY edge.  
3. After first bond only: primary burn reverts (protocol LP empty) until mint/sell/compound.  
4. Second bond allowed when live without synthetic gate; primary mint Policy-gated (debt-inclusive); Open ungated for primary.  
5. Synthetic FD formula; mint/burn gates; first bond ungated; gates ignore mid-only.  
6. Preview == execution mint/bond/burn/claim.  
7. Seigniorage split matches peer ratios for same oracle fees (user/fee/inventory).  
8. Bond LP on NFT; claimRewards free DETF; full maturity pair-only; sell → claim.  
9. Claim redeem: pair, vaultShare, and one other SE token; bad `tokenOut` → `InvalidRoute`.  
10. DETF burn non-pair `tokenOut` → `InvalidRoute`.  
11. Protocol compound increases protocol LP / claim backing; best-effort join failure + retry.  
12. Natural expansion Policy only; Open never; unlimited whole-epoch catch-up; seed last on first realize-path post-live.  
12b. Debt-inclusive synthetic; primary mint blocked by pending debt without clearing it; bond/claim/compound clear debt; primary mint/burn do not.  
12c. Bond after live: **no** synthetic mint gate; still deepens LP.  
12d. Burn `lpOut` uses **effectiveSupply = totalSupply + pending**.  
12e. Test matrix: gentle **and** launch-rich expansion rows equal priority.  
13. Decimal scaling: 6-decimal pairToken first bond + mint/burn exactness.  
14. Real hook + real SE; hermetic + Robinhood/Base forks; no SUT mocks.  
15. Reject `pairToken` ∉ SE tokens; reject DETF in SE tokens.  
16. Price movement under **default** thresholds via real reserve trades + seigniorage dilution.  
17. Nested reentrancy → `IsLocked`.  
18. Residual free inventory zero on success paths where peers require it.

---

## 16. Differences vs peers

| | Balancer Single SE | Superseded UniV4 listing draft | **This family** |
|--|--------------------|--------------------------------|-----------------|
| Reserve | Weighted pool + BPT | Listing CL + OOR; SE inventory on diamond | **CP buffer hook + LP** |
| Self-leg | DETF in pool | DETF in listing only | **DETF raw leg in hook** |
| Principal | BPT | Dual OOR positions | **Hook LP** |
| Live | First bond | First primary mint | **Permissionless first bond** |
| Later bonds gated? | Policy mint gate (peer) | — | **No synthetic gate** (liquidity deepen) |
| Expansion realize | Lazy many touches | — | **Bond / claim / compound only** |
| Init price | Implicit first join | `sqrtPriceX96` listing | **`creationPairPerDetfWad` + first bond join** |
| Live primary mint | Vault-share single-sided join + free DETF | n/a | **Pair zap-in + free DETF** |
| Primary burn out | Vault share or SE token | Inventory path | **pairToken only** |
| Claim redeem out | Family rate path | ZapOut-to-pair | **pair / share / SE token** (same LP apportioning) |
| Synthetic | FD BPT claim / supply | TWAP/creation ratio | **FD LP zap-out / creation** |
| Route errors | Legacy `UnsupportedRoute` | — | **`InvalidRoute` only** |
| Public market | Balancer pool | Uni V4 CL | **Uni V4 + CP hook** |

---

## 17. Dependencies & sequencing

| Order | Work |
|-------|------|
| 1 | Hook PRD + hook implementation plan + **frozen deposit/withdraw/LP ABI** (or DoD green); Phase 0 SE routes as hook requires |
| 2 | This DETF PRD (this file) → LOCK |
| 3 | DETF implementation plan |
| 4 | Bond NFT + rebasing packages for **LP principal** (rebasing holds protocol LP) |
| 5 | DETF DFPkg + tests |

**Hard gate:** DETF package coding **must not** invent hook APIs — only call surfaces from the hook PRD / frozen ABI.

---

## 18. Definition of Done (product)

- [ ] Inert deploy; live only via permissionless first bond  
- [ ] Creation-rate first bond; mid ≈ creation; MINIMUM_LIQUIDITY handled  
- [ ] Live mint/bond seigniorage split peer-compatible; preview == execution  
- [ ] Primary burn pair-only from protocol LP / totalSupply; empty protocol LP reverts  
- [ ] Claim mint/redeem with tokenOut matrix; InvalidRoute elsewhere  
- [ ] Policy/Open on primary mint/burn with **debt-inclusive** synthetic; bonds ungated when live; expansion realize only bond/claim/compound; burn uses effectiveSupply; dual expansion TestBase rows  
- [ ] Protocol compound deepens protocol LP; claim backing can rise  
- [ ] Production-first tests §15 green (hermetic + at least one fork profile)  

---

## 19. Threat notes (product-level)

| Risk | Stance |
|------|--------|
| Permissionless first bond sniping / dust | No MEV protection v1; MINIMUM_LIQUIDITY revert; operators choose seed size |
| Donation of raw DETF or pair to hook | Synthetic/FD uses LP pro-rata zap-out; document donation can skew mid/FD — same class as Balancer donations |
| Primary burn insolvency | Protocol-LP-only; revert if empty — free DETF may be temporarily unburnable after first bond only |
| Expansion catch-up cliff | Full whole-epoch catch-up mints large free DETF after idle; **mitigated for synthetic** by debt-inclusive price (§5.5); optional `maxCatchUpEpochs`; high `R` intentional for launch-rich |
| Reentrancy via ERC-20 / SE / hook | Family diamond `nonReentrant` / `IsLocked` peer patterns |
| Fee stacking (hook swap + DETF usage + SE) | Documented multi-layer fees; not a bug |

---

## 20. Open items for implementation plan (not product blockers)

| Item | Guidance |
|------|----------|
| Exact `quoteDetfAgainstReserve` fixed-point | Match hook effective reserves + ConstProdUtils / deposit math; one shared preview path |
| Claim redeem → vaultShare path details | Same `lpOut`; minimize intermediate pair if hook can deliver SE shares cleanly |
| Permit2 on DETF surface | Optional v1; hook may already support Permit2 deposits |
| Epoch expansion lib surface | Shared lib API for whole-epoch premium-closure + pending preview (shared PRD amendment) |
| TestBase expansion PkgArgs | **Equal matrix:** gentle (8h, 10%/yr) **and** launch-rich (8h, R≈4.4e18) |
| Shared expansion PRD | **Amend soon** — epoch form + debt-inclusive synthetic as target for **all** true DETFs |

---

## 21. Revision history

| Version | Date | Notes |
|---------|------|-------|
| v0.1 | 2026-08-04 | Initial: CP buffer reserve; first bond live + creation rate; primary mint/burn + Policy/Open; LP bond/claim |
| v0.2 | 2026-08-04 | Hardening: co-located PRD law; permissionless first bond; protocol-LP-only burn; DETF burn pair-only; claim redeem pair/share/SE; InvalidRoute only; WAD decimal scale; peer seigniorage/live-mint patterns; protocol LP custody on rebasing; expansion rate discussion + shared defaults; surface/DoD/threats; AGENTS family + scope |
| v0.3 | 2026-08-04 | Epoch expansion: deploy-time immutable epoch length + annual premium-closure `R`; full whole-epoch catch-up; not fee-oracle; launch-rich peg-walk analysis and `R` sizing; PkgArgs/tests updated |
| v0.4 | 2026-08-04 | Pending epoch debt in synthetic (§5.5); product targets §10.3; reference tables §10.4 (R / peg walk / APY / PkgArgs bundles); no year-long 4-digit APY promise |
| v0.5 | 2026-08-04 | Bond ungated when live (liquidity deepen); expansion realize only bond/claim/compound; burn effectiveSupply; dual TestBase expansion rows; shared epoch amendment planned for all true DETFs; fee-recipient NFT like peer; unlimited catch-up |

---

## 22. Approval

| Role | Sign-off |
|------|----------|
| Product | Pending — v0.5 clarifications from open-item Q&A |
| Protocol | Pending |

**Status DRAFT v0.5 — product open items from review Q&A closed; ready for LOCK after sign-off; then implementation plan.**
