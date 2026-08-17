# Product Requirements Document (PRD)

## Title

**UniswapV4StandardExchangeOrbitalDETF** — true DETF with Uniswap V4 **Standard Exchange Orbital Buffer** reserve

## Status

**DRAFT v0.6** — Co-design Q1–Q17 closed; v0.6 locks FD extractable residual (incl. DETF→rateAsset), dual-capital close = residual composition, multi-leg `effectiveShares` via open-time sphere mids, mature-only sell at DETF surface (+ optional shared flag), burn usage fee, dust, creation-rate/`rateAsset` validation. Ready for product LOCK sign-off.

| Related | Role |
|---------|------|
| **This family impl plan** | [`UniswapV4StandardExchangeOrbitalDETF_IMPLEMENTATION_AND_TEST_PLAN.md`](./UniswapV4StandardExchangeOrbitalDETF_IMPLEMENTATION_AND_TEST_PLAN.md) (implementor SoT once stamped) |
| **Reserve hook (mandatory dependency)** | [`UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md`](../../../../../../../../../hooks/uniswap/v4/standardExchange/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md) |
| **Behavioral DETF peer (primary)** | [`UniswapV4SingleStandardExchangeDETF_PRD.md`](../constantProduct/single/UniswapV4SingleStandardExchangeDETF_PRD.md) — seigniorage, live/first bond, synthetic + epoch expansion, bond/claim, compound |
| **Behavioral DETF peer (code)** | Balancer `SingleStandardExchangeDETF` under `detf/…/balancer/v3/standardExchange/single/` |
| **Hook topology / process peer** | Orbital sphere + three doors + buffer-last + zap-in; Single SE BCP only as historical 2-leg contrast |
| **Shared core** | `detf/common/core/*` (`DETFThresholdPolicy`, `DETFUsageFeeLib`, `DETFBondNFTMathLib`, expansion/compound helpers) |
| **Shared compound / expansion law** | `docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` (this family **in scope**; epoch form + debt-inclusive synthetic as peer CP DETF) |
| **Shared Uni V4 DETF packages** | `detf/protocols/dexes/uniswap/v4/common/` — bond NFT + rebasing (LP principal); **share with CP family** |
| **AGENTS.md** | DETF families — common expectations; product docs co-located with code |
| **Skill** | `indexedex-uniswap-v4-hook-packages` (hook package deploy); `indexedex-testing` (DETF tests) |

**Short name:** UniV4 SE Orbital DETF (orbital buffer reserve family).

**Do not conflate with:**

| Package | Role |
|---------|------|
| `UniswapV4SingleStandardExchangeDETF` | Same true-DETF economics; **2-leg CP** reserve (DETF raw × one pair) |
| Former listing-family Uni V4 Single SE DETF | Deleted — listing CL + OOR with no liquidity-holding reserve |
| Raw `UniswapV4OrbitalSwapHook` | No SE buffering — not a DETF reserve host for this family |
| Balancer multi-vault weighted / mixed-buffer | Multi-SE valuation on Balancer hosts — different reserve topology |

---

## 0. Intent

### 0.1 Why this family

The UniV4 Single SE CP DETF lists **DETF ↔ one pairToken** under a constant-product buffer hook. Product goal for **this** family:

1. **List DETF against two external underlyings** on Uniswap V4 (three-door orbital market: DETF/A, A/B, DETF/B).  
2. **Optionally buffer each external leg** into a Standard Exchange (yield-aware claim / optional rate provider) under the hood — **1 or 2 SE vaults**; a leg may also be a **bare ERC-20** (raw inventory on the hook). **≥1 SE required** so this family is always a true *Standard Exchange* Orbital DETF (yield-aware on at least one external leg). Pure dual-bare (no SE) is **out of scope** for v1 — not a separate product config here.  
3. Keep true-DETF law: diamond is the share ERC-20; seigniorage vs a reserve that includes a **DETF self-leg**; bond principal = **fungible hook LP**; rebasing claim on protocol-owned LP.  
4. Start the reserve at a **deploy-time multi-leg creation rate** (may seed rich / off peg).  
5. Reuse CP-family **epoch expansion + debt-inclusive synthetic**.

The reserve host is:

**`UniswapV4StandardExchangeOrbitalBufferHook`**

- Pool currencies: **exactly three** ERC-20s in **caller-supplied binding order**  
- **DETF binding (LOCKED):**
  - Exactly **one** leg is the **DETF self-leg**: raw only (`standardExchange = 0`, no rate provider on that leg).  
  - The other **two** legs are **external pair tokens** (`pairToken0`, `pairToken1` in product naming — not necessarily binding indices 0/1).  
  - Each external leg: **optional** SE (`address(0)` ⇒ bare raw token inventory) + **optional** rate provider **only if** SE is set.  
  - **At least one** of the two external legs **must** have a non-zero SE (Q12). Both bare **reverts** at deploy.  
  - Non-zero SE addresses **pairwise distinct** (hook D5a).  
  - **Free binding order:** DETF may occupy any of the three binding indices as the unique raw self-leg (Q10).  
- Sphere AMM on **effective reserves** (raw face and/or SE claim / shares×rate)  
- Fungible hook LP ≈ BPT  
- Multipath `addLiquidity` / `removeLiquidity` + **zap-in** (`depositSingle`); **no zap-out on hook in v1**  
- Three Uni V4 pair doors share one book  

**Primary product difference vs CP family:** reserve is a **3-asset orbital sphere** with **two** external legs (0–2 SE-buffered), not a 2-asset CP book with one pair.

### 0.2 Product one-liner

A **true DETF**: diamond **is** the DETF ERC-20; seigniorage mint/burn vs a **Uni V4 Orbital SE Buffer reserve** with DETF self-leg + two external pair legs (bare and/or SE-buffered); bond principal = **hook LP**; rebasing claim = pro-rata claim on **protocol-owned hook LP**; Policy/Open synthetic gates; **permissionless** first **bond** establishes live at **deploy-time creation rates**; Policy natural expansion is **immutable epoch premium-closure** paid to bonders.

### 0.3 Goals

1. Ship DETF package under  
   `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/`.  
2. Wire **two** external pair tokens + **1–2** distinct backing SEs (≥1 required) + optional rate providers via **`PkgArgs` → hook package deploy** (create pools in hook postDeploy) + **one** Orbital SE Buffer Hook with raw DETF self-leg.  
3. Primary mint/burn + bond + **maturity** close and **post-maturity** sell→claim + direct claim paths (adapted to 3-leg host).  
4. Deploy-time **creation rates** for empty-reserve first join; synthetic + Policy/Open thereafter.  
5. Seigniorage inventory → bond reward ledger (**same split spirit as Balancer / CP UniV4 DETF**); protocol compound into reserve LP via single-sided DETF zap-in when hook allows.  
6. **Natural expansion (Policy):** same epoch premium-closure form as CP UniV4 DETF peer (§10).  
7. Production-first tests; no SUT mocks.

### 0.4 Non-goals (v1)

1. Implementing the reserve hook inside this package (hook is a dependency).  
2. Dual-OOR CL listing bonds / app-level listing oracle.  
3. More than **two** external pair legs (hook is fixed at 3 assets; DETF + 2 pairs fills the instance).  
4. Binding DETF as a buffered SE leg (self-leg is **raw** only).  
5. Same SE address on two legs (forbidden by hook D5a).  
6. Balancer BPT reserve.  
7. Native ETH as a pool currency (use WETH if needed).  
8. Cross-chain.  
9. Subclassing Balancer DETF contracts, CP UniV4 DETF contracts, or hook contracts.  
10. Guaranteeing peg, APY, or first-bond holder parity with later bonders.  
11. Relying on hook **zap-out** (`withdrawSingle`) — **out of hook v1**; DETF must settle burns/claims without that API (see §5.6, §9).  
12. MEV protection / commit-reveal on permissionless first bond.  
13. Treating V4 `sqrtPriceX96` as product mid after first bond.  
14. Family-local bond NFT / rebasing packages when shared Uni V4 common packages suffice (Q8).  
15. **Both-bare** deploy (zero SEs) — use a different product if needed; this family requires **≥1 SE**.  
16. Fee-on-transfer / rebasing **pair** tokens as pool currencies (hook forbids; DETF restates).  
17. Protocol “rebalance to restore full book” surface when zap-in is blocked after partial book — v1 accepts **mint/compound blocked until external flow restores full book**.

---

## 1. Locked product decisions (summary)

| Topic | Decision |
|-------|----------|
| Family type name | **`UniswapV4StandardExchangeOrbitalDETF`** |
| Package path | `detf/protocols/dexes/uniswap/v4/standardExchange/orbital/` (PRD co-located) |
| True DETF | **Yes** — diamond is share ERC-20; reserve includes DETF self-leg |
| Reserve host | **`UniswapV4StandardExchangeOrbitalBufferHook` only** |
| Binding order | **Free** — DETF is the unique **raw** self-leg at **any** binding index; two external pairs fill the other indices (Q10) |
| External legs | **Two** pair tokens always; each may be **bare** (SE=0) or **SE-buffered** (Q2) |
| SE slots | **At least one** non-zero SE on an external leg; at most two; non-zero SEs **pairwise distinct**. **Both-bare forbidden** (Q12) |
| Rate providers | **Optional** per SE-buffered leg only; when set, **must rate SE shares → that leg’s pairToken** (1e18 pair per share peer). Not on DETF or bare legs (Q7, Q15) |
| Primary mint quote | Capital always **rated into the funded pair-leg units** (pair face, or SE share→pair via claim/RP), then seigniorage quote against reserve for that leg. **No** forced convert through `rateAsset` mid (Q15) |
| PkgArgs → hook | DETF DFPkg passes tokens / SEs / RPs / poolManager / feeOracle / mineNonce into hook package `deployHookVault` + pool init |
| Backing SEs | Settlement SEs for mint/bond capital are the **same** instances bound on the hook for that pair |
| Live | **Permissionless first successful bond** that joins reserve LP (synthetically ungated) |
| First bond capital | **Requires both external pair legs** funded (pair tokens and/or SE-accepted capital that settles to both) (Q1) |
| Creation rates | **Deploy-time `PkgArgs`** — both **`> 0`** (WAD); size first-bond DETF + pair legs so initial sphere mids ≈ creation (see §4.3) |
| Seigniorage | Peer Single SE / CP DETF: boost on **funded pair-leg notional** (Q15) → `quoteDetfAgainstReserve` → usage fee → half-incentive inventory / user / feeTo. **Not** rateAsset mid convert |
| Primary mint (live) | **Either external pair** (or capital settled into that pair / its SE) via hook **`depositSingle`**; **revert if not zap-eligible** (Q2, Q4). Partial book: no protocol rebalance surface in v1 |
| Primary burn | **Burn only user-provided free DETF** when under peg (Policy). Multipath `removeLiquidity` of protocol LP + residual pair settle; **redeposit** DETF returned from remove into protocol LP (Q3). **Usage fee on burn: yes** (oracle peer path). Dust of non-`tokenOut` after consolidate → user with `tokenOut` when dustable, else stay on diamond (documented) |
| Bond (after live) | **No Policy/synthetic price gate**; **single-leg funding OK** (raise liquidity) (Q5); multipath maxes; may mint free seigniorage legs; **does realize** expansion debt |
| Bond principal | **Hook LP** on shared Uni V4 bond NFT package |
| Bond `effectiveShares` | **RateAsset-valued principal at open** × lock bonus: each funded external pair notional converted to rateAsset at **open-time sphere mids** (closed-form), then summed (Q18) |
| **Sell bond → rebasing claim** | **Only after maturity** — pre-maturity sell **reverts**. **New DETF-wide standard** (this family first). **Enforced on DETF surface** always; shared common package **may** take optional `requireMature` flag without forcing CP until CP migrates (Q19) |
| **Pre-maturity principal exit** | **None** — only `claimRewards` while locked (Q14) |
| **Maturity close settlement** | Pay the **bond capital token(s)** recorded on the NFT at open (Q13). Prop remove → redeposit DETF → single capital: consolidate other pair → capital token; **dual capital: pay residual remove composition of both pairs** (not open-time notionals) (Q20) |
| **Post-maturity hold** | Exit **optional forever** — no forced close (Q16) |
| **Bond NFT transfer** | **Free ERC-721 transfer** anytime (incl. marketplaces); buyer inherits lock + capital-token metadata (Q17). No soulbound-while-locked |
| Claim redeem | Protocol-LP apportioning; settle matrix §9; **redeposit** DETF returned from remove; **`InvalidRoute`** else (Q3). Prefer **clean vaultShare path** when `tokenOut` is a share |
| Free DETF → claim | Hook **`depositSingle(DETF)`** when zap-eligible; no seigniorage |
| Expansion realize paths | **Only** bond / `claimRewards` / `compoundProtocolRewards` (+ reward updates). **Not** primary mint/burn |
| Compound if not zap-eligible | **Skip** (no revert) — leave pending; highly unlikely after dual-leg first bond (Q6) |
| Route errors | **`InvalidRoute`** for bad routes; plus stable family errors for not-live, not-mature, not-zap-eligible, first-bond-needs-both-pairs, protocol-LP-empty, lock-too-short, min-out (see §12) |
| Fixed-point | Scale to **1e18** internal; scale back for transfers |
| Instance governance | Immutable / unowned after deploy |
| DETF DFPkg path | IndexedEx manager vault registry |
| Hook / children deploy | Hook: registry `deployHookVault` + hook diamond factory; bond NFT + rebasing: pure Crane; owner = DETF diamond |
| Bond NFT / rebasing | **Share** `uniswap/v4/common/` packages with CP family (Q8); mature-only via DETF + optional shared flag (Q19) |
| Fee-recipient NFT | Wire like Balancer Single SE / CP UniV4 DETF; **same** mature-only principal rules if they hold a bond |
| Compound | Protocol NFT only → single-sided DETF join (`depositSingle(DETF)`) when zap-eligible |
| Natural expansion | Deploy-time epochs + premium-closure; unlimited whole-epoch catch-up (`maxCatchUpEpochs=0`); **not** fee oracle |
| Synthetic + epoch debt | Pending expansion in synthetic denominator (§5.5) |
| FD / synthetic ruler | **`previewLpToRateAsset`** = multipath remove preview + **full residual consolidate to rateAsset** including **DETF self-leg → rateAsset** via sphere (Q9 / Q21). Execution redeposit of DETF is separate protocol-depth policy |
| Numeraire for synthetic | Deploy-time **`rateAsset`** ∈ `{pairToken0, pairToken1}`; if omitted / zero → **`pairToken0`** (explicit preferred) |
| Peg narrative | Abstract **1e18** = FD rateAsset backing per DETF equals **creation rate of rateAsset** only; the other pair floats freely relative (no required invariant between the two creation rates beyond both `> 0`) |
| Test matrix | Gentle **and** launch-rich expansion equal priority; **1 SE + bare** and **2 SE** configs required; **no** both-bare production path; **RP on/off** optional rows; bare `rateAsset` + buffered other leg is a first-class row |

---

## 2. Role vocabulary (LOCKED)

| Role | Name | Meaning |
|------|------|---------|
| DETF share / diamond | `detfToken` / `address(this)` | ERC-20; reserve **raw** self-leg at **some** binding index |
| Pair leg A / B | `pairToken0` / `pairToken1` | The two external ERC-20s (product names); map to hook binding indices at deploy |
| Bare pair leg | pair with `standardExchange_i == 0` | Hook holds **face ERC-20** as that leg’s book |
| Buffered pair leg | pair with non-zero SE | Hook holds **SE shares**; free pair is dust only |
| Backing SE 0 / 1 | `standardExchange0` / `standardExchange1` | Optional SE for each pair; **must not** list DETF; **distinct** when both non-zero |
| SE share 0 / 1 | `vaultShare0` / `vaultShare1` | Present only when that SE is set |
| Rate provider 0 / 1 | `rateProvider0` / `rateProvider1` | Optional; non-zero **only if** corresponding SE set |
| Rate asset / numeraire | `rateAsset` | Deploy-time ∈ `{pairToken0, pairToken1}`; synthetic peg + default burn/claim ruler |
| Other pair | `pairTokenOther` | The external pair that is not `rateAsset` |
| Reserve | `reserveHook` / `reservePool` | Orbital SE Buffer Hook + its three V4 doors |
| Reserve principal | `reserveLp` / hook LP | Fungible LP from reserve hook (BPT analogue) |
| Bond NFT | `bondNft` | Shared Uni V4 package; holds user `reserveLp` while open |
| Protocol principal | protocol-owned `reserveLp` | Held by **shared** rebasing package |
| Rebasing claim | `rebasingClaimToken` | ERC-20 claim on protocol `reserveLp` |
| Creation rates | `creationPair0PerDetfWad`, `creationPair1PerDetfWad` | Deploy-time empty-book join rates (WAD) for each external pair vs DETF; **both must be > 0** |
| Effective reserves | hook `effectiveReserve(i)` | Sphere inputs per binding index |
| Bond capital metadata | per-`tokenId` capital pair set | External pair address(es) funded at open (after SE settle); drives maturity close mode |

**Anti-patterns:** brand tickers; pair ∉ SE tokens when SE set; DETF listed in any SE; same SE on two legs; RP without SE; RP on bare/DETF legs; inventing hook APIs; treating V4 mid as product mid; burning DETF returned from multipath remove (must redeposit); FoT/rebasing pair tokens; both-bare deploy.

---

## 3. Topology (LOCKED)

```text
                    ┌──────────────────────────────────────────────┐
                    │ UniswapV4StandardExchangeOrbitalDETF          │
                    │ diamond = detfToken ERC-20                    │
                    │ immutable / unowned after deploy              │
                    └───────────────────┬──────────────────────────┘
                                        │
     ┌──────────────────────────────────┼──────────────────────────────────┐
     │                                  │                                  │
     v                                  v                                  v
┌──────────────┐              ┌─────────────────────────┐        ┌─────────────────┐
│ SE ×0–2      │              │ Reserve Orbital Hook      │        │ Bond NFT pkg    │
│ (distinct)   │◄─buffer?─────│ 3 tokens: DETF raw +      │──LP───►│ (shared common) │
│ or bare legs │              │ pair0 + pair1             │        │ user LP + rewards│
└──────────────┘              │ each pair: bare or SE+RP? │        └────────┬────────┘
                              │ sphere on e0,e1,e2        │                 │ sell
                              │ fungible LP; 3 V4 doors   │                 │
                              └──────────┬────────────────┘                 v
                                         │ protocol LP             ┌─────────────────┐
                                         v                         │ migrate LP →    │
                              ┌─────────────────────┐              │ protocol        │
                              │ Rebasing claim pkg   │◄─────────────│ (shared common) │
                              │ holds protocol LP    │  deposit     └─────────────────┘
                              │ redeem matrix §9     │
                              └─────────────────────┘
```

**Public market (three doors, one room):**

```text
Pool DETF/pair0  ──┐
Pool pair0/pair1 ──┼──► same reserve hook (shared effective reserves + L²)
Pool DETF/pair1  ──┘
```

**Opacity:** DETF production talks to `IStandardExchange*`, reserve hook ABI, bond NFT APIs, rebasing APIs, fee oracle, shared DETF libs. DFPkg wires hook package deploy from `PkgArgs`. Product mid is **never** V4 `sqrtPriceX96` after first bond.

**Same SE instances:** Settlement for mint/bond capital uses the SEs bound on the hook for the corresponding pair token (when set).

---

## 4. Liveness & first bond (LOCKED)

### 4.1 States

| State | Condition |
|-------|-----------|
| **Inert** | Deployed; reserve hook bound; three V4 doors may be initialized with plumbing; **no** successful bond yet; primary mint/burn blocked; non-first bonds blocked |
| **Live** | First **successful bond** completed that minted DETF for join and placed **reserve LP** on the bond NFT; `isReserveLive = true` |

### 4.2 First bond access (LOCKED)

**Permissionless.** Any address may establish live with a successful first bond.  
No product min notional beyond hook **MINIMUM_LIQUIDITY** / first-mint constraints (≥2 positive legs on multipath; sum WAD effective used > MINIMUM_LIQUIDITY).  
If first mint would fail hook geometric / MIN liquidity constraints, **revert** with a clear product error (cannot go live).  
No MEV protection in v1; operators should seed with a **small but viable** multipath first bond. **No holder-parity guarantee** between first and later bonders.

### 4.3 Creation rates (deploy-time)

| Field | Meaning |
|-------|---------|
| **`creationPair0PerDetfWad`** | After decimal normalize to 1e18, how much **pairToken0** (WAD) equals **1e18 DETF** at empty-book join |
| **`creationPair1PerDetfWad`** | Same for **pairToken1** |
| Storage | Resolved from `PkgArgs` at deploy; **immutable** on instance |
| **Validation (LOCKED)** | Both rates **must be `> 0`**. Zero or either missing ⇒ deploy/init **reverts**. No product max; operators choose seed richness. **No required invariant** between the two rates (cross-pair relative price is free). |

#### Decimal convention (LOCKED — peer CP DETF)

1. Convert amounts to **internal WAD (1e18)** for all pricing, synthetic, creation-rate, and seigniorage math.  
2. Creation rates stored and consumed **only in WAD space**.  
3. Scale back to native decimals for ERC-20 transfers and hook calls.

**Example:** Want “1 DETF = 2 USDC and 1 DETF = 0.001 WETH” at seed →  
`creationPair0PerDetfWad = 2e18` (USDC), `creationPair1PerDetfWad = 0.001e18` (WETH) after WAD normalize of each asset.

**Peg narrative (LOCKED):** abstract **1e18** synthetic means FD **rateAsset** backing per DETF equals **creation rate of `rateAsset` only**. The non-rateAsset pair has no separate peg invariant.

### 4.4 First bond mechanics (LOCKED — Q1)

First bond is **synthetically ungated** (Policy and Open).

**Requires both external pair legs** with non-zero capital after settlement (pair tokens, vault shares, and/or SE-accepted tokens that resolve to **both** `pairToken0` and `pairToken1`). Single-pair first bond **reverts**.

1. User supplies capital resolving to **both** pair-notionals \(C_0, C_1 > 0\) in WAD.  
2. **Mint DETF for join** using **creation rates only** (not market sphere mid):

```text
// WAD space — join DETF sized so empty multipath ratio matches creation
detfFrom0 = pair0NotionalWad * 1e18 / creationPair0PerDetfWad
detfFrom1 = pair1NotionalWad * 1e18 / creationPair1PerDetfWad
// Common join size: min of implied DETF amounts; excess pair refunded by hook clamp
detfForJoinWad = min(detfFrom0, detfFrom1)
require detfForJoinWad > 0
```

3. Apply **peer mint modifiers** on the join-sized gross (seigniorage split for free legs — same as CP DETF spirit). Free `user` / `feeTo` / `inventory` DETF is **not** joined into the reserve; only **join-sized** DETF enters the multipath.  
4. Settle capital to **native pair tokens** (convert SE tokens/shares → pair when SE set; bare legs are already native).  
5. Reserve hook **`addLiquidity`** multipath with join DETF on self-leg index + both pairs on external indices (binding-order maxes). Buffer SE legs last (hook law).  
6. **LP → bond NFT package** for `tokenId`; record **capital-token metadata** (both external pairs + open notionals optional for analytics; mode = dual capital) and **effectiveShares** (Q18).  
7. Set **`isReserveLive = true`**.

**Empty book / mids (LOCKED):** hook first mint sets radius \(R\); join DETF sized by creation rates so **book** effective mids ≈ creation rates at the multipath join (modulo SE buffer fees / dust). Free seigniorage legs **intentionally** sit outside the pool and do **not** re-size the join; any later free-float or inventory mint into claim/compound can move mids — **no holder-parity guarantee**. Dual-leg seed is intended to establish a **full book** so primary mint zap-in is available immediately after live.

### 4.5 After live

- **Primary mint/burn:** subject to Policy/Open **debt-inclusive** synthetic gates (Open: ungated).  
- **Further bonds (after live):** **no synthetic / Policy mint gate.** Bonds **deepen liquidity** — **single external pair (or DETF+one pair multipath maxes) OK** (Q5). Purpose is to raise liquidity; users need not fund both pairs on every bond.  
- Bond paths **may still** mint free DETF legs from the seigniorage split of the join quote.  
- Bond / `claimRewards` / `compoundProtocolRewards` **realize** pending expansion debt (§10). Primary mint/burn **do not**.  
- Reserve mids from sphere **effective** reserves.  
- Creation rates remain **peg reference** for synthetic; **not** used to size later mints.  
- **Live does not imply burnable depth:** first-bond LP sits on the NFT; protocol LP may be ~0 until primary mint, bond-sell, or compound. Primary burn **reverts** if protocol LP insufficient (intentional).

---

## 5. Pricing, synthetic, thresholds (LOCKED)

### 5.1 Marks

| Mark | When | Use |
|------|------|-----|
| **Creation rates** | First bond only (and inert info) | Size first-bond DETF for multipath join |
| **Reserve mids** | Live | Sphere mids from effective reserves; **seigniorage quotes only** — **never** threshold gates alone |
| **FD backing / synthetic** | Live | Fully diluted **rateAsset** claim of **relevant reserve LP** ÷ **effective DETF supply** (includes **pending epoch expansion debt**), normalized by creation rate of `rateAsset` — §5.5 |

### 5.2 Decimal scale (LOCKED)

All internal pricing, synthetic, thresholds, creation rates, seigniorage boost, and expansion math run in **1e18-normalized** units. Scale to/from native decimals only at token boundary I/O.

### 5.3 Seigniorage quote shape after live (LOCKED — peer spirit + Q15)

**Goal:** replicate Balancer / CP UniV4 DETF seigniorage economics on this host, with **per-leg rating**.

**Normative capital rating (Q15):**

1. Identify which **external pair leg** the `tokenIn` funds (`pairToken0` or `pairToken1`).  
2. Convert `tokenIn` amount → **pair-leg units** for that leg only:  
   - **pairToken itself:** face amount (WAD).  
   - **SE vault share:** always **rate** to pair units — if RP set: `shares × getRate() / 1e18` (then toWad); if no RP: fee-inclusive SE unwrap/claim preview to pair.  
   - **Other token ∈ SE.tokens():** SE route → pair, then same as pair face.  
3. **Do not** convert that pair notional through `rateAsset` mid for the mint quote. The other leg / rateAsset mapping is irrelevant except that **each leg uses its own correct rate**.  
4. Boost that **pair-leg notional** by seigniorage incentive; **`quoteDetfAgainstReserve(pairLeg, pairNotionalBoosted)`** closed-form against live effective reserves for that capital leg.  
5. Peer `_splitMintedDetf` for free legs.

```text
// LOCKED Q15 — per funded pair leg
pairNotionalWad = rateTokenInToPairLeg(tokenIn, amountIn)  // never skip rate on SE shares
pairBoosted     = pairNotionalWad * (1e18 + seigniorageIncentiveWad) / 1e18
grossDetf       = quoteDetfAgainstReserve(fundedPairLeg, pairBoosted)
// Split peer:
feeToDetf / inventoryDetf / userDetf from gross
```

| Path | Capital → reserve | Free DETF |
|------|-------------------|-----------|
| **Live primary mint** | Rate capital → pair units → hook **`depositSingle(pairToken_i)`** (zap-in). **No** DETF self-leg join on this path. | Mint `user` / `feeTo` / `inventory` only |
| **Bond (live)** | Rate capital → pair units; multipath join DETF + pair maxes; LP → bond NFT; **record capital token(s)** | **Also** mint free legs from split |
| **First bond** | Creation-rate sized join DETF + **both** pairs; LP → bond NFT; record both capitals | Same free legs from split of gross |

**`quoteDetfAgainstReserve` (economic LOCK):** closed-form DETF **gross** for exact-in **pair-leg** notional against **live effective reserves**, fee-aware as the hook/sphere requires.

**Economic identity (LOCKED Q22):** gross DETF is the seigniorage mint size such that the **pair-leg capital**, if joined single-sided via the same economic path as live primary mint (`depositSingle` impact on the sphere / effective reserves), backs that DETF at the **post-impact** reserve mid for that leg — i.e. the inverse of “how much DETF the reserve prices for this pair in under current book,” not creation rate and not a forced convert through the other pair / rateAsset. **Not** “DETF that would be co-joined in a multipath max with this pair for target LP” unless that identity is proven equal under the frozen fixed-point. **Not** tick-walk. Impl plan freezes fixed-point to match hook `depositSingle` / sphere math and asserts preview == execution on mint.

**Rate providers (LOCKED Q15 + hook law):** when set on a buffered leg, RP **must** express **SE shares → that leg’s pairToken** (Balancer SE RP peer). Product purpose: Uniswap V4 exposes **pair tokens** as pool currencies; SE inventory is rated **as** that pair for effective reserves and mint/bond capital.

**Preview == execution** on closed-form routes (≤ few-wei only if SE multi-leg dust forces it; document).

### 5.4 Settlement `tokenIn` (primary mint & bond capital) — LOCKED Q2 + Q15

| `tokenIn` | Allowed | Notional resolution |
|-----------|---------|---------------------|
| `pairToken0` | Yes | amount → pair0 WAD (face) |
| `pairToken1` | Yes | amount → pair1 WAD (face) |
| `vaultShare0` / `vaultShare1` | Yes **if** corresponding SE set | **Always rate** share → pair units (RP or SE claim) |
| Other token ∈ SE_i `tokens()` | Yes **if** SE_i set | SE → pair, then face pair WAD |
| Else | **`InvalidRoute`** | — |

**Primary mint:** user may mint with **either** external pair (or capital that settles/rates to that pair). Hook path = **`depositSingle` of the native pair token** after settle.

**v1:** settle/buffer to the **native pair token** before hook deposit. Bare legs: no SE hop. Buffered legs: rate SE shares; buffer pair last per hook.

### 5.5 Synthetic (gates + expansion) — **includes pending epoch debt** (LOCKED)

**Peg narrative:** abstract **1e18** means FD **rateAsset**-backing per DETF equals **creation rate of rateAsset** (pair per DETF, both WAD).

**Rule (LOCKED peer CP DETF):** `syntheticPrice()` / gate inputs use **effective supply** = on-chain `totalSupply` + **pending expansion DETF**.

**`previewLpToRateAsset` (LOCKED Q9 + Q21 — full extractable residual):**

FD measures the **rateAsset claim of LP** as if a multipath remove’s **entire residual composition** were consolidated to `rateAsset` via closed-form sphere exact-in (fee-aware). This matches CP-peer “zap residual to settlement asset” spirit without hook zap-out.

```text
// For a given lp amount (protocol-counted LP only — bond NFT LP included when peer FD does):
// 1) preview multipath removeLiquidity(lp) → (a_detf, a_pair0, a_pair1) in binding order
// 2) Map to product legs (DETF, pairToken0, pairToken1)
// 3) FULL residual → rateAsset (LOCKED — do NOT drop DETF self-leg):
//      rateAsset face += a_rateAsset
//      other pair  → sphere exact-in sell into rateAsset
//      DETF self   → sphere exact-in sell into rateAsset
//    (same fee-aware closed forms as residual settle on burn/claim; order frozen in impl plan)
// 4) Execution paths that REDEPOSIT returned DETF for protocol depth are SEPARATE from FD.
//    FD answers “what is this LP extractable for in rateAsset?” not “what remains after redeposit.”

fdRateAssetWad = sum over counted LP of previewLpToRateAsset(lp)

S_spot = (fdRateAssetWad * 1e18 / totalSupply) * 1e18 / creationRateAssetPerDetfWad
// creationRateAssetPerDetfWad = creationPair0 or creationPair1 matching rateAsset

pendingExpansionDetf = previewPendingExpansionMint()
effectiveSupply = totalSupply + pendingExpansionDetf

synthetic = (fdRateAssetWad * 1e18 / effectiveSupply) * 1e18 / creationRateAssetPerDetfWad
```

**Why include DETF→rateAsset in FD:** excluding the self-leg systematically understates extractable backing on a 3-leg book (easier burn / harder mint than true claim). Peer CP zap-out to pair includes self-leg impact; this family must too. **Redeposit on burn/claim** remains mandatory for **protocol self-leg depth** — it does not redefine FD.

| Mode | When live |
|------|-----------|
| **Policy** | Primary mint iff `synthetic > mintThreshold` (default 1.05e18). Primary burn iff `synthetic < burnThreshold` (default 0.95e18). Equality = deadband. **`synthetic` = debt-inclusive.** Bonds after live: **no** synthetic mint gate. |
| **Open** | Threshold gates **always pass**. Pending expansion is **0**. |
| **First bond** | Synthetically **ungated**. |

**Source of truth:** `ThresholdMode` + thresholds from **`PkgArgs` → resolve → storage only**. Fee oracle does **not** set thresholds.

**Realize vs accrue:** realize only on bond / claimRewards / compound; **not** on primary mint/burn.

**Info surface:** `syntheticPrice()` (debt-inclusive), `pendingExpansionDetf()`, optional `syntheticPriceSpot()`, `rateAsset()`, creation rate getters, pair/SE/RP getters, binding indices.

### 5.6 Primary burn of DETF (LOCKED — Q3)

**When:** Policy burn gate (`synthetic < burnThreshold`) or Open when live.  
**Settlement:** user chooses `tokenOut ∈ {pairToken0, pairToken1}` (and optionally SE unwrap of that pair — §9.4). Else **`InvalidRoute`**.

**Why diverge from CP:** Orbital hook v1 has **no `withdrawSingle` / zap-out**. DETF implements residual consolidation at the DETF layer.

**LP basis (peer debt model):**

```text
protocolLp = reserveLp.balanceOf(protocolLpHolder)
pending = previewPendingExpansionMint()
effectiveSupply = totalSupply + pending
lpOut = detfBurned * protocolLp / effectiveSupply
// if protocolLp == 0 or lpOut == 0 → revert
```

**Execution (LOCKED Q3 + burn fee/dust/redeposit):**

1. Require live + **debt-inclusive** burn gate (Open: always when live).  
2. Pull **user-provided free DETF** (`detfBurned`); compute `lpOut` with **effectiveSupply** (**do not** realize expansion).  
3. **Burn only `detfBurned`** (the free DETF the user is redeeming).  
4. **Usage fee on burn: YES** — apply vault fee oracle burn usage fee as Balancer Single SE / CP UniV4 DETF peer (`DETFUsageFeeLib` path). **No** mint-style inventory / seigniorage split on burn.  
5. **`removeLiquidity(lpOut, …)`** on reserve hook → receive multipath amounts including a DETF self-leg slice.  
6. **Redeposit** all **DETF returned from remove** into protocol reserve LP so protocol **keeps self-leg depth**:  
   - **Prefer** hook **`depositSingle(DETF)`** when zap-eligible.  
   - **Else** multipath `addLiquidity` with DETF max and zero other maxes **if the hook accepts** that shape on a live book.  
   - **Else** full tx **reverts** (atomicity: user must not lose burned free DETF without payout).  
   - **Do not** burn returned DETF. **Do not** pay returned DETF to the burner.  
7. **Consolidate residual non-`tokenOut` pair leg** into `tokenOut` via hook SE In/Out / sphere exact-in.  
8. Pay **`tokenOut` only**. **Dust policy (LOCKED):** any remaining dust of `tokenOut` after settle goes to the user; dust of the other pair that cannot be economically consolidated (below min swap / dust threshold frozen in plan) may remain on the DETF diamond and is **not** a user claim in v1 — document in NatSpec; tests assert no material free inventory of user capital on success paths.  
9. Enforce `minOut`.

**Do not** size burn from creation rate while live.  
**Do not** draw on bond-NFT LP for primary burn.  
**Do not** clear expansion debt on burn.  
**Do not** invent hook `withdrawSingle` in this package.

---

## 6. Fees (two layers — do not conflate)

| Kind | What | Source |
|------|------|--------|
| **A. Reserve sphere trading fee** | Live `dexSwapFeeOfVault(hook)` residual in book | Hook law (orbital dual-channel) |
| **B. Hook protocol growth** | Live `usageFeeOfVault(hook)` LP mint to feeTo on k growth | Hook law |
| **C. DETF protocol fees** | Usage fee, seigniorage incentive, mint split | Vault Fee Oracle on DETF |
| **D. SE usage fees** | On buffer/mint routes inside each SE (when set) | SE + oracle |

**Bond lock terms (LOCKED, peer):** fee oracle via `DETFBondNFTMathLib` — **revert if lock < min**; **clamp to max** if longer (bonus at max).

**Fee-recipient NFT (LOCKED):** wire fee-recipient bond NFT as peer (claimable free DETF; **no** auto-compound in v1).

---

## 7. Primary mint after live (LOCKED — Q2, Q4)

1. **Do not** realize expansion debt / advance `lastExpansionTimestamp`.  
2. **Debt-inclusive** Policy mint gate (`synthetic` §5.5). Open: ungated when live.  
3. Resolve notional from `tokenIn` (WAD); settle to an **external pair leg**.  
4. Quote gross DETF (boost → `quoteDetfAgainstReserve` → split).  
5. **Deepen protocol LP:** hook **`depositSingle(pairLeg)`**.  
   - **If not zap-eligible:** **revert** (Q4). First bond dual-leg seed is designed so this is available when live.  
   - **Partial book after live (LOCKED):** single-leg later bonds or public door trades may leave a leg with zero effective reserve so zap-in blocks. **v1 has no protocol rebalance API.** Primary mint (and compound) stay blocked until external flow restores a full book (further dual-leg bond, door swaps, etc.). Operators/integrators must treat this as product law, not a bug.  
6. Mint free DETF: user / feeTo / inventory → bond vault (if inventory > 0).  
7. **Do not** auto-call `compoundProtocolRewards` on this path if that entry always realizes expansion (v1 peer: keep expansion realize off primary mint).

**Invariant:** live primary mint does **not** require multipath dual-pair deposit; peer is single-sided external-leg join + free DETF mint.

---

## 8. Bond lifecycle (LOCKED)

### 8.1 Open (after live; first bond §4)

| Item | Rule |
|------|------|
| Access | Permissionless |
| Capital | **First bond:** both external pairs. **Later bonds:** **one or both** external pairs (and/or SE capital settling to them); multipath maxes (Q5) |
| **Price / Policy gate** | **None after live.** Bonds deepen LP liquidity. |
| DETF economics | Join-sized DETF + free fee/inventory/user legs from seigniorage **split** |
| Join | Hook multipath `addLiquidity`; **LP → bond NFT** |
| Expansion debt | **Realize** pending expansion on bond before/with reward update |
| **effectiveShares (LOCKED Q18)** | **RateAsset-valued principal at open × lock bonus only.** Convert each funded **external** pair notional (after SE settle, WAD) to rateAsset at **open-time sphere mids** (closed-form exact-in / mid as plan freezes — same fee-aware family as residual settle). Sum converted legs = rateAsset principal. **Do not** use creation rates for this FX after live. DETF join leg is **not** bond capital and does **not** add to effectiveShares. |
| claimRewards | Free DETF anytime while open (**realizes** expansion debt) — **not** a principal exit |
| Partial close | **Forbidden** |
| **Pre-maturity principal exit** | **Forbidden** — no early close, no early sell→claim (Q14) |
| **Sell → rebasing claim** | **Forbidden until maturity** (§8.3) |
| **NFT transfer** | **Allowed** anytime (ERC-721, incl. secondary markets); inherits unlock + capital-token metadata (Q17). **No** soulbound-while-locked |
| **Capital token metadata (LOCKED)** | On open, record the set of **external pair addresses** funded (after SE settle) and whether mode is **single** or **dual** capital. Notionals optional for analytics; **not** required for dual close proportion (Q20). Storage layout is plan-only; product requires at least the address set + mode |

`acceptedBondTokens()`: at least both pair tokens; vault shares for each set SE; tokens from each set SE; not DETF as bond capital (DETF is minted for join).

### 8.2 Maturity (LOCKED)

A bond is **mature** when `block.timestamp >= unlockTime` (lock terms from fee oracle / bond open — peer clamp/revert law unchanged).

**Post-maturity hold (Q16):** the NFT may remain unexited **indefinitely**. Maturity only **unlocks** exit options; nothing auto-closes or force-exits.

At maturity the holder chooses **exactly one** full exit (partial still forbidden):

| Exit | API spirit | Result |
|------|------------|--------|
| **Maturity close** | Withdraw principal as the **bond capital token(s)** recorded at open | §8.2.1 |
| **Sell → rebasing claim** | Convert principal LP into rebasing claim | §8.3 — **only when mature** |

Pre-maturity: **only** `claimRewards` (and remaining lock / free NFT transfer). **No** principal exit of any kind (Q14).

#### 8.2.1 Maturity close (full only — capital token out) — LOCKED Q13 + Q20

**Bond capital token map (normative):**  
On bond open, store per `tokenId` the **external pair address(es)** the user paid with (after any SE → pair settle) and single vs dual mode. Not DETF. Not hook LP.

| Capital at open | Stored | Maturity close payout |
|-----------------|--------|------------------------|
| **Single** external pair (typical later bond) | One `capitalToken` address; mode=single | Prop remove → **redeposit DETF** into protocol LP → **sell the other non-DETF pair leg** via sphere/SE In-Out into `capitalToken` → pay user **only** `capitalToken` (user accepts sphere impact). Never return both pairs on single-capital bonds |
| **Both** external pairs (first bond / dual fund) | Both pair addresses; mode=dual | Prop remove → **redeposit DETF** → pay user **both** residual external pair amounts from the remove **as-is** (**residual composition at close**, not open-time notionals / fixed weights) (Q20) |

**Dual-capital proportion (LOCKED Q20):** “Proportionally” means **whatever multipath remove yields** for the two external legs after redeposit DETF — i.e. current LP residual composition. Sphere trading between open and close may skew residual vs open funding; the holder takes that mark-to-market. **Do not** rebalance to open-time capital weights.

1. Require **mature**.  
2. Pay pending rewards.  
3. Bond NFT withdraws **all** position LP.  
4. Multipath `removeLiquidity`.  
5. **Redeposit** all returned DETF self-leg into protocol LP (same redeposit ladder as burn §5.6 step 6).  
6. Settle non-DETF legs per table above to the recorded capital token(s).  
7. Retire NFT; stop accrual.

**Do not** default maturity close to `rateAsset` unless that was the bond’s capital token.

### 8.3 Sell → rebasing claim (full only — **post-maturity only**)

**DETF-wide standard (LOCKED for this family; first adopter):**  
Bond holders **must not** sell their bond for rebasing claim tokens **until the bond has matured**. Pre-maturity `sellPositionToDetfNft` / peer sell path **reverts** (e.g. `BondNotMature` / family equivalent). Other DETF families adopt this law in separate changes; do not treat early-sell peers as product law for this family.

**Enforcement vs shared packages (LOCKED Q19):**

1. **Mandatory:** this DETF’s bonding surface **always** checks maturity before any sell→claim or principal migration.  
2. **Shared** `uniswap/v4/common/` bond NFT package **should** accept an optional deploy-time / init **`requireMatureForSell`** (or equivalent) so co-owned packages can encode the gate without forking.  
3. **CP family** may keep early-sell until its migration PR; shared package must not **force** mature-only on CP until CP opts in.  
4. This family sets the flag **true** (or equivalent) when wiring the shared package. DETF-level check remains even if the flag is missing (defense in depth).

1. Require **mature** (same unlock predicate as §8.2).  
2. Pay pending rewards.  
3. Transfer **hook LP** from bond NFT to **rebasing package** (prefer ERC-20 LP transfer).  
4. Mint rebasing claim from **Δ protocol LP contribution** valued as **`previewLpToRateAsset`** (full extractable residual per §5.5 / Q21).  
5. Credit protocol NFT id 0 principal weight if peer ledger requires.  
6. Retire user NFT.

**Fallback if LP transfer blocked:** removeLiquidity → redeposit DETF self-leg → rebasing deposit paths for residual pairs / LP re-mint as plan freezes — still **only when mature**.

### 8.4 Protocol NFT id 0 & fee-recipient

- Protocol NFT id 0: reward ledger weight for inventory seigniorage / expansion; compound §10; no required dual position.  
- **Fee-recipient NFT (LOCKED):** wire as peer (claimable free DETF; no auto-compound v1). If the fee recipient holds a bond position, **same** mature-only principal exit rules apply — no special early-exit privilege.

---

## 9. Rebasing claim (LOCKED — Q3, Q8)

### 9.1 Package

- **Share** Uni V4 DETF bond NFT + rebasing packages under  
  `detf/protocols/dexes/uniswap/v4/common/` with the CP family (Q8).  
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
| Bond sell (**post-maturity only**) | No | Migrate LP → protocol; mint claim from contribution. Pre-maturity sell **reverts** (§8.3) |
| New money (pair / SE token / share) | **No** | Settle to pair → hook `depositSingle(pair)` when zap-eligible → LP to protocol → mint claim |
| Free DETF | **No** | `depositSingle(DETF)` → LP to protocol → mint claim (price impact is user’s; preview includes impact) |

Claim shares: SE-style pro-rata of **LP→rateAsset contribution**. First depositor inflation guards as peers.

### 9.4 Redeem claim (LOCKED Q3)

**Apportioning:**

```text
lpOut = claimSharesBurned * protocolLp / claimTotalSupply
// burn claim shares only (not DETF from remove)
// removeLiquidity(lpOut)
// REDEPOSIT all DETF returned from remove into protocol LP (keep self-leg depth)
// residual pairs → consolidate to tokenOut
```

**`tokenOut` options (user chooses unwrap depth):**

| `tokenOut` | Execution |
|------------|-----------|
| `rateAsset` (pair0 or pair1) | Multipath remove + **redeposit DETF** + residual consolidate → pay rateAsset |
| Other pair leg | Same structure → that pair |
| `vaultShare_i` | Only if SE_i set; **prefer clean share path** (leave as SE shares without unwrap→rebuffer round-trip) when residual is already buffered shares or can be obtained without destructive unwrap; unwrap only when needed for the chosen out — **same `lpOut`** |
| Token ∈ SE_i `tokens()` | Only if SE_i set; obtain pair then SE path |
| Else | **`InvalidRoute`** |

**Preview == execution** on every closed-form redeem route (incl. maturity close previews when exposed).  
**Never burn DETF withdrawn on claim redeem** — only burn claim shares; redeposit self-leg DETF (same redeposit ladder as §5.6 step 6).

---

## 10. Protocol compound & natural expansion (LOCKED)

**Same product law as CP UniV4 DETF §10** for epoch expansion. Compound rules:

### 10.1 Compound (LOCKED Q6)

| Item | Rule |
|------|------|
| Who | Protocol NFT id 0 pending free DETF only |
| Method | **Single-sided DETF into reserve**: hook `depositSingle(DETF)` when **zap-eligible** → protocol LP ↑ |
| Claim | **0** new claim shares to protocol |
| Trigger | Lazy on reward-updating touches + public `compoundProtocolRewards()` |
| If not zap-eligible | **Skip** compounding (do **not** revert). Leave pending DETF for a later successful zap-in. Dual-leg first bond makes this rare. |
| Failure (join reverts) | Best-effort on lazy paths; public compound may still surface join failure if zap-eligible but join fails — plan freezes |

### 10.2 Natural expansion — epoch form

Identical to CP UniV4 DETF peer:

- Policy + live only; Open never expands.  
- Deploy-time `expansionEpochLength`, `expansionClosureRatePerYearWad`, `expansionMaxCatchUpEpochs`.  
- Resolve defaults: epoch `0` → **8 hours**; `R == 0` → **0.10e18**; `maxCatchUpEpochs == 0` → unlimited.  
- Pending debt always in synthetic denominator.  
- Realize **only** on bond / claimRewards / compound / bond reward updates.  
- Premium-closure O(1) formula using `S_spot` then debt-inclusive synthetic for gates.

Reference tables for launch-rich `R` sizing: **copy CP UniV4 DETF §10.3–§10.4** (do not re-derive ad hoc). Use `rateAsset` creation rate as peg reference.

---

## 11. Deploy & PkgArgs (LOCKED)

Typed surface: `IUniswapV4StandardExchangeOrbitalDETDFPkg.deployVault(PkgArgs args, uint256 mineNonce)`. The nonce is **not** a PkgArgs field. Caller premines via `UniswapV4DetfHookPremineLib`. Deploy arity SoT: [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md`](../UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md).

### 11.1 Deploy sequence (postDeploy spirit)

1. Deploy DETF diamond via vault registry (inert).  
2. From **`PkgArgs`**, deploy reserve Orbital SE Buffer Hook via registry `deployHookVault`:  
   - three tokens (DETF + pair0 + pair1 in chosen binding order)  
   - SE slots (0–2 non-zero on external legs only)  
   - optional rate providers (only with SE)  
   - poolManager, feeOracle, mineNonce / salt fields  
3. Hook **postDeploy** initializes **all three** V4 pair doors (`DYNAMIC_FEE_FLAG`, plumbing sqrtPrice).  
4. Deploy **shared** bond NFT + rebasing packages (owner=DETF); rebasing is protocol LP holder.  
5. Store creation rates, `rateAsset` (default pair0 if omit/zero), thresholds, mode, expansion params, binding index of DETF.  
6. Validate: pairs distinct; DETF raw only; pair ∈ SE tokens when SE set; SEs distinct when both set; RP only with SE; **≥1 SE set** (reject both bare); **both creation rates `> 0`**; `rateAsset` ∈ {pair0, pair1}; no FoT/rebasing pairs.

### 11.2 PkgArgs (normative)

| Field | Notes |
|-------|--------|
| `pairToken0` / `pairToken1` | Two external ERC-20s; pairwise distinct; ≠ DETF; **not** FoT/rebasing |
| `standardExchange0` / `standardExchange1` | `address(0)` = bare leg; else SE for that pair; non-zero SEs distinct; **require ≥1 non-zero SE** (Q12) |
| `rateProvider0` / `rateProvider1` | Optional; non-zero only if corresponding SE set; **must** rate shares → that leg’s pairToken |
| `detfBindingIndex` or equivalent | Which hook index is DETF raw self-leg (0, 1, or 2) — **free order (Q10)** |
| `rateAsset` | Must be `pairToken0` or `pairToken1`. **If omitted / `address(0)` → `pairToken0`**. Explicit value preferred in production deploy scripts |
| `poolManager` | Uni V4 PoolManager |
| `creationPair0PerDetfWad` / `creationPair1PerDetfWad` | First-bond / peg reference (WAD); **both `> 0`** or deploy reverts |
| `thresholdMode`, mint/burn thresholds | Shared policy resolve |
| `expansionEpochLength` | Seconds; `0` → 8 hours |
| `expansionClosureRatePerYearWad` | Premium closed per year; `0` → 10%/yr gentle |
| `expansionMaxCatchUpEpochs` | `0` = unlimited |
| Bond NFT / rebasing package refs | Shared common package wiring; **`requireMatureForSell = true`** (or equivalent) for this family (Q19) |
| Hook salt / mineNonce / product binding | Passed through to hook package |
| Fee oracle | Manager / vault wiring |

**Not used:** listing TWAP seconds; CL width; monomorph CREATE3 hook factory as primary path.

---

## 12. Public surface (normative groups)

| Group | Examples |
|-------|----------|
| **Info** | `isReserveLive`, `syntheticPrice` (**debt-inclusive**), optional `syntheticPriceSpot()`, `pendingExpansionDetf`, thresholds, `isMintingAllowed` / `isBurningAllowed`, creation rates, `rateAsset`, pairs, SEs, RPs, DETF binding index, reserve hook, expansion getters |
| **Exchange in** | Mint DETF from either pair / share / SE token; burn free DETF→`tokenOut` ∈ pair legs (+ SE unwrap matrix) |
| **Bond** | `bond`, maturity close, `sellPositionToDetfNft` (**mature only**), `claimRewards`, `acceptedBondTokens` |
| **Claim** | Direct deposit paths; redeem claim with `tokenOut` matrix §9.4 |
| **Compound / expansion** | `compoundProtocolRewards` (skip if not zap-eligible); lazy update on touches |
| **Previews (LOCKED)** | Every closed-form execution path exposes a view preview with **preview == execution** (≤ few-wei only if SE multi-leg dust forces it; document): mint, burn, bond, claim deposit/redeem, maturity close (single and dual capital outs), sell→claim contribution |
| **Errors (stable family)** | `InvalidRoute`; mint/burn not allowed; reserve not live; lock too short; **`BondNotMature`** (sell/close); min out; **`FirstBondRequiresBothPairs`**; **`NotZapEligible`** (primary mint); **`ProtocolLpEmpty`** / insufficient protocol LP (burn); redeposit failure surfaces as full revert (no partial success) |

Exact selector layout follows Crane facet split (Info / In / Out / Bonding / …) in impl plan.

---

## 13. Package layout

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/
  standardExchange/
    orbital/
      UniswapV4StandardExchangeOrbitalDETF_PRD.md          # this file (internal law)
      UniswapV4StandardExchangeOrbitalDETF_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on
      UniswapV4StandardExchangeOrbitalDETFDFPkg.sol
      UniswapV4StandardExchangeOrbitalDETFRepo.sol
      UniswapV4StandardExchangeOrbitalDETFCommon.sol
      … Facets / Targets / FactoryService / TestBase
    constantProduct/single/   # peer CP DETF family — do not subclass
  common/
    nft/      # Uni V4 DETF bond NFT (LP principal) — SHARED
    rebasing/ # claim on protocol hook LP — SHARED
```

**Fresh codepath rule:** do not subclass CP UniV4 DETF or Balancer Single SE contracts; reuse `detf/common/core/*` libs and shared Uni V4 common packages.

---

## 14. Canonical flows

1. **Deploy** — creation rates, rateAsset, Policy/Open, 0–2 SEs + optional RPs via PkgArgs → orbital hook + three doors, shared bond + rebasing.  
2. **First bond (live)** — permissionless; **both** pair legs required; mint DETF at creation rates; multipath join; LP on NFT; live=true.  
3. **Second+ bonds** — market quote; **no** synthetic mint gate; **single-leg OK**; LP on NFT; realize expansion + rewards.  
4. **Primary mint** — either pair → free DETF + protocol LP zap-in; **revert if not zap-eligible**; debt-inclusive Policy gate; does **not** realize expansion.  
5. **Primary burn** — burn **user free DETF only** → multipath remove → **redeposit returned DETF** → residual consolidate → chosen pair; effectiveSupply basis.  
6. **Maturity close** — after unlock (optional forever): withdraw LP; redeposit DETF; pay recorded **capital token(s)** per §8.2.1.  
7. **Sell bond → claim** — **only after maturity**: LP to protocol; mint claim. Pre-maturity sell **and** early close revert.  
8. **Direct claim** — pair/SE or free DETF via depositSingle; no seigniorage.  
9. **Redeem claim** — burn claim shares; remove LP; **redeposit DETF**; pay pair / share / SE token.  
10. **Compound / expansion** — §10 (skip compound if not zap-eligible).  
11. **External swap** — public V4 doors via orbital hook.

---

## 15. Testing expectations

1. Deploy inert; primary mint reverts; non-first bond reverts.  
2. Permissionless first bond at creation rates → live; **both pairs required** (single-pair first bond reverts); mids ≈ creation; MINIMUM_LIQUIDITY edge.  
3. After first bond only: primary burn reverts (protocol LP empty) until mint/sell/compound.  
4. Second bond allowed when live without synthetic gate; **single-pair bond succeeds**; primary mint Policy-gated; Open ungated for primary.  
5. Synthetic FD via multipath remove + **full residual → rateAsset including DETF self-leg**; mint/burn gates; first bond ungated; assert FD includes self-leg value (not pairs-only).  
6. Preview == execution mint/bond/burn/claim/maturity close (single + dual)/sell→claim contribution.  
7. Seigniorage split matches peer ratios for same oracle fees; burn applies usage fee.  
8. Bond LP on NFT; claimRewards free DETF while locked; pre-maturity **any** principal exit reverts; NFT transferable mid-lock; post-maturity close pays capital token(s) **or** sell→claim; mature hold indefinite; dual-capital close pays residual composition (skew mid then assert not open notionals).  
9. Claim redeem: rateAsset, other pair, vaultShare (if SE; prefer clean share path), SE token; **returned DETF redeposited** (supply/protocol LP invariants).  
10. Primary burn: only user free DETF burned; returned DETF redeposited (ladder); invalid `tokenOut` → `InvalidRoute`.  
11. Protocol compound increases protocol LP when zap-eligible; **skips without revert** when not (force partial book in adversarial/unit path if possible).  
12. Natural expansion Policy only; Open never; dual expansion TestBase rows.  
13. Decimal scaling: 6-decimal + 18-decimal pairs.  
14. Real orbital hook package + real SEs; hermetic + fork smoke; no SUT mocks.  
15. Config matrix: **1 SE + 1 bare**, **2 SE** (both required in DoD); **reject both-bare** at deploy; bare rateAsset + buffered other leg; RP on/off for ≥1 buffered config; reject same SE twice; reject RP without SE; reject DETF in SE tokens; reject creation rate 0.  
16. Price movement under **default** thresholds via real reserve trades + seigniorage dilution.  
17. Nested reentrancy → `IsLocked`.  
18. Residual free inventory zero on success paths where peers require it (dust policy documented).  
19. Three V4 doors swap after live.  
20. Primary mint via `depositSingle` each pair leg; mint reverts when not zap-eligible; partial-book mint stays blocked (no rebalance helper).  
21. Free binding order: at least one TestBase row with DETF not at binding index 0.  
22. `effectiveShares` multi-leg bond uses open-time rateAsset valuation (not creation rates).

---

## 16. Differences vs peers

| | Balancer Single SE | UniV4 CP SE DETF | **This family** |
|--|--------------------|------------------|-----------------|
| Reserve | Weighted pool + BPT | **CP buffer hook + LP** (2 currencies) | **Orbital SE buffer hook + LP** (3 currencies) |
| External legs | Multi-token vault share join | **One** pairToken | **Two** pairs; **1–2 SEs** (≥1 required; one bare OK) |
| Self-leg | DETF in pool | DETF raw leg | **DETF raw leg** (any binding index) |
| Principal | BPT | Hook LP | **Hook LP** (shared packages) |
| Live | First bond | Permissionless first bond | **Permissionless first bond (both pairs)** |
| Later bonds | Policy mint gate (peer) | **No** synthetic gate | **No** synthetic gate; **single-leg OK** |
| Expansion realize | Lazy many touches | Bond / claim / compound only | **Same as CP UniV4 DETF** |
| Init price | Implicit first join | `creationPairPerDetfWad` | **`creationPair0/1PerDetfWad`** |
| Live primary mint | Vault-share single-sided | Pair **zap-in** | Either pair **zap-in**; **revert if not zap-eligible** |
| Primary burn out | Vault share / SE token | **pairToken** via hook zap-out | Pair via multipath remove + residual; **redeposit DETF from remove** |
| Claim redeem | Family rate path | pair / share / SE | Same outs; **redeposit DETF from remove** |
| Sell bond → claim | Peer may allow early sell | Peer may allow early sell | **Mature only** (new DETF-wide standard; first adopter) |
| Synthetic | FD BPT claim / supply | FD LP zap-out / creation | **FD LP→rateAsset (remove + full residual sells incl. DETF self-leg)** |
| Public market | Balancer pool | Uni V4 + CP hook (1 pool) | **Uni V4 + orbital hook (3 doors)** |
| Route errors | Legacy `UnsupportedRoute` | **`InvalidRoute` only** | **`InvalidRoute` + family errors** (not-mature, not-zap-eligible, …) |
| Sell→claim gate | Peer may allow early sell (transitional) | Peer may allow early sell (transitional) | **Mature only** (first adopter; DETF gate + optional shared flag) |

---

## 17. Dependencies & sequencing

| Order | Work |
|-------|------|
| 1 | Orbital SE Buffer Hook PRD + implementation plan + **frozen ABI** (or DoD green) |
| 2 | This DETF PRD → **LOCK** after sign-off |
| 3 | DETF implementation plan |
| 4 | Shared bond NFT + rebasing packages for **LP principal** (CP family co-ownership) |
| 5 | DETF DFPkg + tests |

**Hard gate:** DETF package coding **must not** invent hook APIs — only call surfaces from the orbital hook PRD / frozen ABI.

---

## 18. Definition of Done (product)

- [ ] Inert deploy; live only via permissionless first bond with **both** pairs  
- [ ] Creation-rate first bond (both rates `> 0`); mids ≈ creation at join; MINIMUM_LIQUIDITY handled  
- [ ] Live mint (either pair) / bond seigniorage split peer-compatible; preview == execution  
- [ ] Primary mint reverts when not zap-eligible; partial book has no protocol rebalance  
- [ ] Primary burn burns only user free DETF; usage fee applied; redeposits DETF from remove (ladder); pair settlement from protocol LP / effectiveSupply  
- [ ] Claim redeem redeposits DETF from remove; tokenOut matrix; InvalidRoute elsewhere  
- [ ] Sell→claim and maturity close **revert pre-maturity**; succeed post-maturity; single capital consolidates; dual capital pays residual composition; NFT transfer preserves metadata  
- [ ] Later bonds single-leg OK; first bond dual-leg required; multi-leg `effectiveShares` via open-time sphere mids  
- [ ] Compound skips when not zap-eligible (no revert)  
- [ ] Policy/Open debt-inclusive synthetic with **FD full residual incl. DETF→rateAsset**; expansion realize only bond/claim/compound  
- [ ] PkgArgs deploys hook with **1–2** SEs + optional RPs + free DETF binding index; both-bare reverts; rateAsset default pair0  
- [ ] Shared common bond/rebasing packages; mature-only DETF gate + shared flag true for this family  
- [ ] Production-first tests §15 green (hermetic + at least one fork profile)  

---

## 19. Threat notes (product-level)

| Risk | Stance |
|------|--------|
| Permissionless first bond sniping / dust | No MEV protection v1; MINIMUM_LIQUIDITY revert; operators choose seed size |
| Donation of raw DETF or SE shares to hook | Synthetic/FD uses LP pro-rata **full extractable** rateAsset value (incl. self-leg); document dilution |
| Primary burn insolvency | Protocol-LP-only; revert if empty |
| Residual settle impact on burn | User accepts sphere impact consolidating other pair → tokenOut; previews must include it |
| Redeposit path failure on burn/claim | Full tx reverts after redeposit ladder exhausted (no partial: user must not lose burned free DETF without payout — plan freezes atomicity order) |
| Expansion catch-up cliff | Debt-inclusive synthetic; optional maxCatchUpEpochs; high R intentional for launch-rich |
| Reentrancy via ERC-20 / SE / hook | Family diamond `nonReentrant` / `IsLocked` peer patterns |
| Fee stacking | Documented multi-layer fees (sphere + hook growth + DETF usage + SE); burn usage fee is intentional |
| Partial book after single-leg later bonds | Blocks zap-in mint/compound until full book restored externally; **no** protocol rebalance in v1; first bond dual-leg mitigates at launch |
| Distinct SE / bare-leg configs | Deploy validation + matrix coverage |
| Early sell→claim (pre-maturity) | **Forbidden** under new DETF-wide standard; DETF gate + optional shared flag — no partial principal migration |
| Dual-capital close skew | Holder takes residual mark-to-market; not open-weight rebalance |
| Shared package early-sell drift | DETF-level maturity check is mandatory even if shared flag missing or CP still early-sell |

---

## 20. Clarification lock table (resolved)

| ID | Topic | Locked value |
|----|--------|--------------|
| **Q1** | First bond capital | **Both external pair legs required** |
| **Q2** | Mint capital + SE matrix | **Either pair** (and SE-settled capital into that pair). **0–2 SEs**; bare token OK; optional RP per SE leg; **PkgArgs → hook package** deploy |
| **Q3** | DETF from multipath remove | **Never burn returned DETF.** **Burn only user-provided free DETF** on primary burn. **Redeposit** returned DETF on burn and on claim redeem so protocol keeps self-leg depth |
| **Q4** | Mint when not zap-eligible | **Revert** |
| **Q5** | Later bonds single-leg | **Allowed** (raise liquidity) |
| **Q6** | Compound when not zap-eligible | **Skip; do not revert** |
| **Q7** | Rate providers | **Optional everywhere** (when SE set); DoD includes RP on/off rows |
| **Q8** | Bond NFT + rebasing | **Share** Uni V4 `common/` packages with CP family |
| **Q9** | `previewLpToRateAsset` | **Multipath remove preview + full residual → rateAsset** (pairs **and** DETF self-leg). See Q21 |
| **Q10** | DETF binding index | **Free order** — DETF may be any of three indices as unique raw self-leg |
| **Q11 / DETF-wide** | Sell bond → rebasing claim | **Only after maturity.** Pre-maturity sell reverts. This family is **first adopter** of the new DETF-wide standard; other families updated separately |
| **Q12** | Minimum SEs | **≥1 SE required** so the family is always a true *SE* Orbital DETF (yield-aware on ≥1 external leg). Both-bare deploy reverts. Pure dual-bare is out of scope v1. DoD: 1 SE+bare and 2 SE |
| **Q13** | Maturity close `tokenOut` | **Capital token(s) recorded per NFT at open** — not free-choice rateAsset. Single capital: prop remove, redeposit DETF, sell other pair → capital token. Dual capital: residual both pairs after redeposit DETF (Q20) |
| **Q14** | Pre-maturity principal exit | **None** — only `claimRewards` |
| **Q15** | Mint / bond capital rating | Capital **always rated into the funded pair-leg units**. SE vault shares **always** rate→pair (RP or claim). Quote DETF from that pair notional — **no** forced convert via `rateAsset` mid. RPs target **pairToken of that SE leg** only |
| **Q16** | Post-maturity hold | **Indefinite** — exit optional forever |
| **Q17** | Bond NFT transfer | **Free ERC-721** anytime (incl. markets); inherits lock + capital metadata; not soulbound-while-locked |
| **Q18** | Bond `effectiveShares` | Sum of funded external pair notionals **converted to rateAsset at open-time sphere mids** × lock bonus. DETF join leg excluded |
| **Q19** | Mature-only vs shared packages | **DETF surface always gates.** Shared common package gets optional `requireMatureForSell` (this family sets true); CP may keep early-sell until migration |
| **Q20** | Dual-capital close proportion | **Residual remove composition at close** (mark-to-market), not open-time notionals / fixed weights |
| **Q21** | FD self-leg | **Include DETF→rateAsset** in FD extractable residual. Redeposit is execution depth policy only — does not redefine FD |
| **Q22** | `quoteDetfAgainstReserve` identity | Gross DETF = fee-aware inverse of single-sided pair capital vs live book (primary-mint / depositSingle spirit); **not** creation rate; **not** rateAsset mid convert; fixed-point in plan |
| **Q23** | Burn usage fee | **Yes** — oracle peer path; no mint-style inventory split on burn |
| **Q24** | Redeposit ladder | Prefer `depositSingle(DETF)`; else multipath DETF-only max if hook accepts; else full revert |
| **Q25** | Partial book / no rebalance | Mint and compound stay blocked until external flow restores full book; no protocol rebalance API in v1 |
| **Q26** | Creation rates / rateAsset | Both creation rates `> 0`; `rateAsset` omit/zero → pairToken0 |

**Plan-only remaining (not product forks):** bond NFT storage layout/slots for capital token set + mode; atomic order of burn-then-remove-then-redeposit; fixed-point of `quoteDetfAgainstReserve` and residual sphere sells; multipath max array order for free DETF index; dust thresholds for uneconomic residual pair dust; exact shared-package flag name/ABI.

---

## 21. Revision history

| Version | Date | Notes |
|---------|------|-------|
| **v0.1** | 2026-08-05 | First draft: CP UniV4 DETF economics + Orbital SE Buffer Hook reserve; OPEN Q1–Q10 |
| **v0.2** | 2026-08-05 | Locked Q1–Q10: dual-leg first bond; either-pair mint; 0–2 SE + bare + optional RP via PkgArgs; burn only user free DETF + redeposit remove DETF; mint reverts if not zap-eligible; single-leg later bonds; compound skip if not zap-eligible; optional RPs; shared common packages; FD remove+sells; free DETF binding order |
| **v0.3** | 2026-08-05 | **DETF-wide standard (first adopter):** sell bond → rebasing claim **only after maturity**; pre-maturity sell reverts; maturity close remains the pair-capital exit |
| **v0.4** | 2026-08-05 | Q12 ≥1 SE; Q13 maturity pays bond capital token(s) per NFT; Q14 no pre-maturity principal exit; Q16 indefinite mature hold; Q17 free NFT transfer; Q15 still open |
| **v0.5** | 2026-08-05 | Q15: capital always rated to funded pair-leg units; SE shares always rate→pair; RPs target pairToken; no rateAsset mid for mint quote |
| **v0.6** | 2026-08-05 | Review LOCK pass: FD full residual incl. DETF→rateAsset (Q21); dual close = residual composition (Q20); effectiveShares open-time sphere mids (Q18); mature-only DETF + optional shared flag (Q19); burn usage fee yes (Q23); redeposit ladder (Q24); partial book no rebalance (Q25); creation rates >0 / rateAsset default (Q26); quote identity (Q22); dust/previews/errors/non-goals tightened |

---

## 22. Approval

| Role | Sign-off |
|------|----------|
| Product | Pending — v0.6 co-design + review locks closed |
| Protocol | Pending |

**Status DRAFT v0.6 — product co-design and review ambiguities locked; ready for LOCK after sign-off; then implementation plan.**
