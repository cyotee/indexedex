# MATRIX_R2 Grok original — NetNet/Pendle operation cells

| Field | Value |
| --- | --- |
| Researcher | Grok (independent first pass) |
| Routing metadata | `xai/grok-4.6` — routing ID only, **not** provider attestation |
| Round | Fresh human-authorized matrix R2; **not** recovery of prior inventories |
| Spec | `NETNET_PENDLE_DETF_PRD.md` **v0.12**; `REQUIREMENTS_QUESTIONS.md` (A11–A18 / Q register); 11-column `NETNET_PENDLE_OPERATION_MATRIX.md` |
| Law read | `CLAUDE.md:25–46`; `docs/agent/RESEARCH_COUNCIL.md`; `docs/agent/SKILL_CATALOG.md` (discovery only) |
| Status | Draft research. Not frozen, implementation-authorized, or executable. |
| Peer artifacts | **Not read** |

**Method:** fill from selected R01–R50 / §§4–13. Uncertain cells are exactly **UNKNOWN**. An operation is a **behavior**, not a new public selector. Exact-in/out and **≥1 vs &lt;1** are **variants**. Internal ops are marked **INTERNAL**. Public hook **swaps** ≠ standard-interface **contraction**. Hook-LP rights ≠ liquid DETF rights. Dedicated **R41** is zero-incentive at **any** price. Reward claims ≠ principal claims. Native-note path is **atomic**. Donation / rescue / admin / sweep / Permit2 are **not inferred**.

**O01** (FoT NET / rebase sNET as 4626 `asset`) remains an **authority blocker** for implementation; it is not an extra matrix row.

## Candidate 11-column table

| Operation and purpose | Actor and authority | Input | Output and recipient | Eligibility | Quote and funding source | Fees and incentives | Accounting effects | Locks and rewards | Limits and failure | Important edge cases |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Deploy package + canonical USDG-SE bind** | Deployment package (not hook); no post-deploy setter | Package args: DETF, staking, NFT, hook, configured V2 SE | Live proxies; hook holds SE **share** config | Package **rejects** SE that is not the designated canonical NET/USDG V2 strategy identity | Binding evidence **UNKNOWN** (query/registry). Empty correctly configured SE may still identify | Oracle **reused**; numerical fee defaults **UNKNOWN** | No runtime vault-switch. Hook does **not** assert NetNet binding | None | Wrong SE → package revert | O01 unresolved. Other-DETF currencies **not** registered |
| **First-bond / family bootstrap** | **UNKNOWN** (inert until first bond / family bootstrap) | NET/sNET (Keep YT) or USDG (V2) | Funded staked DETF under bond NFT | Instance inert beforehand (`CLAUDE.md:44`; R15) | R47 chain: `UniswapV4DetfCommon` purchase quote + `DETFFundedBondTarget.createFundedPosition` | Duration bonus **only if** oracle terms compatible; **UNKNOWN** for first bond | Mint DETF; sNET-DETF holds backing | Principal cliff = assigned Pendle maturity (R18); rewards claimable (R50) | Unfunded pull reverts (`DETFFundedBondTarget:114`) | R17 next-epoch seconds vs oracle **min duration** = compatibility boundary, not silent extend |
| **Mint hook LP** (public join) | **Anyone** with funded components + allowance (R32) | Attributable `L,Y,C,V` (and **UNKNOWN** self-leg) | Fungible hook LP to minter | Funded join rules; **not** DETF-only | Copy Weighted/`WeightedMath` join (R48, §4.3). Admission must price existing accrued income | **Usage fee on mint**; oracle key = **hook** `address(this)` (R36) | `H` up. **Does not mint NET-DETF** | No bond lock on hook-LP entry | Slippage/mins **UNKNOWN** | Zero-income bootstrap **UNKNOWN**. Other DETFs hold **same LP**, not extra currencies (R35) |
| **Redeem hook LP** (component exit) | LP owner or allowance | `h` hook LP | `r=h/H` of `L,Y,C,V` to redeemer (§7.1) | Owns/authorized `h` | Per-component `floor(h*X/H)`; **not** cash-first of others’ `C` | Conversion costs attributed to **this** exit only | Burn `h`; debit components | Accrued value already in LP (R42) | Cannot consume other LPs’ income in lieu of own principal | Single-asset conversion uses **only** allocated components. Distinct from DETF contraction |
| **Transfer hook LP** | Holder | Hook LP | LP to recipient | ERC-20/721-style ownership **UNKNOWN** exact iface | N/A | **UNKNOWN** | All accrued value travels; **no** seller-retained historical `C` (R42) | None added | Checkpoint implementation **UNKNOWN** | Pendle `userInterest` stays at **hook address** |
| **Public hook swap** (management/arbitrage; **not** contraction) | Anyone | NET/sNET → Keep YT; USDG → V2 SE (R03). DETF-in remains **inventory** | External asset or **existing** DETF; NET-out/sNET-out from **interest inventory only** (R49) | Valid settlement; expired LP **deposit** blocked (R10) | Weighted/Balancer baseline (R48). Public curve vs owned-book **UNKNOWN** | Swap/usage fees **UNKNOWN**. **No** R27 `p` | No DETF mint/burn. Incoming NET/sNET → Pendle; USDG → `V` | N/A | `minOut` fail reverts. **Must not fully drain** interest leg or substitute Pendle principal | Ordinary DETF→ext leaves DETF outstanding. **≠** §7.4 contraction. Hook-LP exit **may** exhaust own `r·C` |
| **ERC-4626 deposit/mint** (sNET → existing DETF) | User / owner | sNET (`asset()`) | Existing DETF to receiver | **UNKNOWN** `maxDeposit`/`maxMint` | Reserve-pool swap; **not** fresh mint (R37, §7.4) | DETF usage-fee key = DETF `address(this)` (R36); amount **UNKNOWN** | Supply-neutral exchange | Does not unlock bonds | Revert on limit/min | Share token **is** DETF. Strict 4626 certification **not** required |
| **ERC-4626 redeem / withdraw** (peg **variants**) | Owner, approved, or `owner`+allowance | Redeem: exact DETF `q`. Withdraw: exact net sNET | sNET to receiver | **≥1** NET/DETF → ordinary swap. **&lt;1** → eligible contraction. Equality is **swap** (R38) | ≥1: public/reserve swap. &lt;1: owned-hook-LP book; `qQuote=floor(q*(1e18+p)/1e18)`; burn **actual `q`** (R27/R39) | `p` from oracle, DETF key; **once**. No output uplift | ≥1: no burn. &lt;1: burn `q` only | Locks not bypassed | Insufficient owned-book delivery → **full atomic revert** (no D39) | Authoritative price reference **UNKNOWN**. Inverse for withdraw **UNKNOWN**. **≠** public hook swap row |
| **SY deposit / redeem** (NET/sNET/USDG ↔ DETF) | User; `burnFromInternalBalance` auth **UNKNOWN** detail | Deposit: NET/sNET/USDG (R03 routing). Redeem: DETF | Existing DETF in; NET/sNET/USDG out | Same ≥1 / &lt;1 branch as §7.4 | Same swap vs owned-book contraction | Same `p` only on eligible contraction | Share = DETF; no wrapper | Same | `minTokenOut` reverts whole tx (R22) | Intermediary PT/YT/LP **not** user outputs |
| **SE DETF → NET/sNET/USDG** (installed surfaces only) | User of **actually installed** V2/DETF SE routes | DETF | User-selected NET, sNET, or USDG | Installed exact-in; exact-out **only if** that variant is exposed | Shared contraction calc **when eligible**; else ordinary swap | Tax **inside NetNet V2 SE**, not hook (R06/R34) | Same burn/swap split as §7.4 | Same | Unsupported exact-out stays unsupported | **R34:** retain every **supported** reference feature. **Do not invent** donate/rescue/admin/sweep. Permit/pretransfer **UNKNOWN** until pinned selector matrix (E14) |
| **Fresh-capital Pendle bond** (NET/sNET) | User | NET/sNET | Newly minted DETF, staked; NFT to user | Fresh capital only (R15) | Keep YT then **R47** purchase/split/duration quote **unchanged unless incompatible** | Bond-side duration bonus per `DETFBondNFTMathLib` **if** terms valid; **no** contraction `p` on this purchase | sNET-DETF holds DETF | Principal **cliff to Pendle maturity**; **rewards claimable before** (R50) | Unfunded/minOut revert | Copying `DETFFundedStakingMath` **linear principal** would **conflict**; adapt **release predicate only** (§10.3) |
| **Fresh-capital USDG bond** | User | USDG | Staked DETF / NFT | Fresh capital | USDG → V2 SE shares in hook; then R47 | Tax in SE | `V` in hook book | USDG-bond detailed schedule **UNKNOWN** (O03 remainder) | Tax/delivery fail reverts | Not a second Keep-YT destination for the same USDG (R03 exclusive) |
| **Stake liquid DETF / unstake unlocked** | Holder | Liquid DETF in; sNET-DETF out (and reverse) | 1:1 held DETF | Existing **liquid** DETF; locked principal **cannot** unstake early (R50) | 1:1 in held DETF | **UNKNOWN** | sNET-DETF holds backing including minted rewards (R43) | Stake liquid: **no new lock** (R15) | **UNKNOWN** checkpoint iface | Unstake is **not** R41. Do not spend other users’ backing |
| **Dedicated reinvestment R41** (zero incentive, **any** price) | Participant: wallet DETF **or** own staked slice | Actual DETF `q` | New funded bond/stake to **same** participant | Any peg. Own tokens only. **Not** a public contraction endpoint | Owned-book burn with **`quoteInput=q`** (no `p`), then **normal** R47 bond calc (R41/R46/R47) | **Never** contraction bonus, including nested steps. Bond calc **kept** | Burn `q`; mint replacement; staked path **debits that participant only** | Next processed NET epoch (R17); cap assigned Pendle maturity | Atomic rollback of old claims | Wallet 40 does **not** debit staked 100 (§10.2). Independent **contraction then bond** is **not this op** (R46) |
| **Eligible standard-interface contraction** (below peg only) | DETF holder via 4626/SY/SE **only** — **no** `contractSupply` | Actual DETF `q` | NET/sNET/USDG from **owned** reserve realization | Price **strictly &lt;1** NET/DETF | Owned-hook-LP book; `qQuote=floor(q*(1+p)/WAD)`; `F` bounded by withdrawable owned components (R39) | `p` quotation-only; never minted/burned | Burn **`q` only**; supply down | Not a lock bypass; not R41 | Unfunded → full revert; **no** swap fallback | **≠** public hook swap. Composing this **then** a later normal bond **keeps** both economics (R46) — **not** a caller ban |
| **Reward-only claim** (pre-maturity) | NFT owner / approved (`DETFFundedBondTarget:169–170` pattern) | None (funded reward entitlement) | sNET-DETF (or DETF-denominated rewards) to recipient | Rewards funded and claimable **before** maturity (R50) | Funded rewards only; projected unminted **excluded** | **UNKNOWN** | Debit reward gons; **principal remains** in sNET-DETF | Principal still locked; maturity **not** reset | Zero rewards valid | Native-note proceeds **are not** staking rewards (R45/§10.3) |
| **Principal claim at full maturity** | NFT owner / approved | Mature position | Principal DETF/sDETF to recipient | Position-specific: Pendle cliff **or** native NetNet full vest (R18–R19) | Funded principal | **UNKNOWN** | Release principal; retire if paid | No interim **linear** principal | Before maturity → revert | Do **not** import Universal linear `_claim` principal schedule |
| **External NetNet bond purchase** | Holder-authorized composition | Proceeds of DETF-out **swap or eligible contraction** | Native `deposit(...)` note; NFT controls entitlement | User elects; not proportional LP claim (R12/R44) | Payment conversion USDG vs V2-LP **UNKNOWN**. RFV for LP pay | `maxPriceWad` + **UNKNOWN** extra mins | Note exclusive until harvest; not common `C` | Native vest (verify 2d vs 5d **UNKNOWN**) | Atomic **purchase** fail restores inputs | `notes[to]` grief / aggregate `redeem` = engineering (O08). Markets 0=USDG, 1=V2 LP |
| **NFT transfer** | Owner / approved | Custom NFT | NFT to new owner | Transferable (R44) | N/A | **UNKNOWN** | Control only; no duplicate claims | All locks, obligations, capabilities travel; **maturity unchanged** | **UNKNOWN** retirement | Does **not** transfer native non-transferable notes |
| **Atomic native collect → Keep YT → mint → stake** | NFT holder | Vested native installment | Staked DETF under **same** NFT | Vesting due; active (successor) market | Keep YT then R47 mint from **actual** contribution | No raw-NET payout; no contraction `p` unless user **separately** contracted upstream | After success: assets **common**; NFT controls stake | Native maturity retained; rewards claimable | **Any** step fail reverts **including collection** (R45) | No deferred pending NET. Failed harvest leaves installment **unclaimed** in depository |
| **Permissionless PENDLE harvest** (public hook) | **Anyone** | None | PENDLE to **live** oracle `feeTo()` | Hook is earner | Market `redeemRewards(hook)` (or equiv.) | Caller **no** cut | Fee-owned PENDLE **excluded** from strategy `C` (or payable once) | N/A | Forward-failure handling **UNKNOWN** | Third-party native claim still owed to `feeTo()`. **≠** YT interest. Do not sweep unrelated tokens |
| **`rollover(targetMarket)`** (public on **hook**) | Anyone | Compatible successor market | Successor inventory; existing hook LP represents **rolled** book | **Revert if current market still active** (R09). Compatible SY/asset identity; **new** PT/YT | Residual old PT/SY/YT handling **UNKNOWN** | Maintenance incentive **UNKNOWN** | Settle claims; preserve proportional LP ownership, not old raw quantities | Do **not** extend ordinary or native locks; matured unclaimed do **not** block | Incompatible target reverts | Atomic vs staged **UNKNOWN** (O07). Late native notes use **active** successor |
| **INTERNAL: YT/SY interest into `C`** | Hook (caller **UNKNOWN**: swap/join/keeper) | Pendle due interest | Increases interest inventory `C` | **UNKNOWN** trigger | Once-counted claim→cash | Not PENDLE (R13) | Harvest ≠ accounting gain | N/A | **UNKNOWN** | Public NET/sNET-out may spend `C` but not empty it (R49) |
| **INTERNAL: automatic expansion** | Epoch/DETF processing | **UNKNOWN** | Minted DETF to **UNKNOWN** recipients | Automatic (R23); NET-state sync (R08) | **Equation UNKNOWN** (O05/Q7) | Not contraction `p`; do not mint recursive seigniorage because `p` was used in a burn | Supply ↑; report separate from burns | **UNKNOWN** snapshots | **UNKNOWN** | No D39 fallback. No D52 catch-up caps |
| **INTERNAL: post-expiry PT realize / no expired LP deposit** | Protocol / funding path | Mature PT / expired market | Underlying to hook book where valid | Market expired (R10) | **UNKNOWN** | **UNKNOWN** | Block **LP deposits** into expired market; keep historical claims | Ordinary bonds at Pendle maturity already releasable | Public swap availability **UNKNOWN** from actual routes | **Not** a liquid-DETF proportional LP right |

## Citations

- PRD v0.12 R03–R06, R09–R15, R17–R19, R22–R28, R32–R50; controlling text `:18`, `:26`; architecture `:20`; §§4.1–4.3, 5–6, 7.1–7.5, 8–13, O01–O10, A24–A33.
- `NETNET_PENDLE_OPERATION_MATRIX.md` 11 headers (empty body).
- `REQUIREMENTS_QUESTIONS.md` Q4–Q13 remainders: price/owned-book math, R41 mapping, expansion eq, self-leg, V2 conversion, note liveness, bootstrap valuation.
- Bond calc: `DETFFundedBondTarget.sol:93–125,143–188`; `UniswapV4DetfCommon.sol:104–109,126–135,267–289`; `DETFBondNFTMathLib.sol:17–50`; linear principal conflict `DETFFundedStakingMath.sol:96–116` (PRD E15 / §10.3).
- Weighted: `UniswapV4StandardExchangeWeightedBufferHookMath.sol:115–122,186–207`; `WeightedMath.sol` (PRD E16 / R48).
- V2 reference start: `UniswapV2StandardExchangeDFPkg.sol` (E14) — **matrix not completed**.
- Oracle: `IVaultFeeOracleQuery.sol`; `_quoteMintGross` is mint **precedent**, not burn impl (E12).
- Law: `CLAUDE.md:44–45` inert-until-first-bond; FoT/rebase ban.

No new external API claims this round; Context7 not used.

## Gaps (explicit)

1. Authoritative **NET-per-DETF** price for R38.
2. Owned-book construction / fee-tax order / exact-out inverse (O09).
3. **Expansion** recipients and formula (O05).
4. This DETF **self-leg** in hook `tokens()` (O10).
5. Public swap **fee** amounts; whether public curve = whole shared hook or DETF-owned book.
6. R41 **size/eligibility** beyond “participant’s own”; duration vs oracle min for R17.
7. USDG-bond **release map**; external-bond **payment conversion**.
8. Rollover **atomic vs staged**; residual series; SY address vs equivalent.
9. PENDLE **forward failure**; other reward tokens.
10. V2 **installed selector matrix**; permit/pretransfer presence = **UNKNOWN**, not assumed.
11. Bootstrap / first-bond **liveness terms**.
12. ERC-4626/SY **`max*` / preview** truth table.
13. Interest-leg **residual** when `C→0` (steepen vs revert) — requirement is never **fully drain**; exact remainder **UNKNOWN**.
14. NFT **retirement** (O03/O08).
15. Live pins: `BOND_VEST`, pair/oracle, Pendle market.

## Not selected / not inferred

- Dedicated `contractSupply` / tender / keeper buyback.
- D39 fallback; liquid proportional DETF→hook-LP claim; extra DETF trading currencies.
- Premint vs uncollected notes; raw-NET payout; deferred harvested-NET.
- Caller bans / cooldowns on composing contraction **then** normal bond (R46).
- Donation, rescue, admin pause/sweep, or Permit2 **unless** later shown on the **pinned installed** V2/DETF surface.
- Strict ERC-4626 / Pendle-SY **certification** as a product gate.
