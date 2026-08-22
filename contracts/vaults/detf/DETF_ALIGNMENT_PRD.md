# Product Requirements Document (PRD)

## Title

**DETF alignment** — working product law for planned work on **all** true DETF families

## Status

**DRAFT — D1–D31 locked. Implementation plan opened 2026-08-19.** This is the single working PRD for upcoming DETF work. Only decisions in §0 are accepted. New topics are discussed, then written here. Implement only from [`DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md). Reserve donation (D29) is specified in [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md). Implement D15/D25/D29/D30/D31 and N10 only from [`DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md) Stages **I–O**. Uni V4 owner ops while PoolManager is locked are D30. Expansion realize-then-gate on mint/burn/redeem/close is D31.

| Field | Value |
|-------|--------|
| **Status** | **DRAFT** — 2026-08-22. D1–D31 locked. Impl plan opened. Bond free-`U` uses plan launch default L1 |
| **Home** | This file, co-located with the DETF tree: `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` |
| **Scope** | Every true DETF under `contracts/vaults/detf/protocols/dexes/**` |
| **This file** | Cross-family product law. Append locked decisions here. Do not open a sibling PRD for the same questions |
| **Impl / test plan** | [`DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Not this file** | Per-family **curve, reserve token set, and mint `tokenIn` list** (stay in family PRDs; see §16). Directory layout ([`DETF_DIRECTORY_REORGANIZATION_PRD.md`](./DETF_DIRECTORY_REORGANIZATION_PRD.md)). Protocol compound and natural expansion (already LOCKED in [`docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md)) except where D2/D10/D15 cross-cut. Reserve donation process: [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md) (D29 lock row here). |

---

## 0. Locked decisions

| ID | Topic | Decision | Date |
|----|-------|----------|------|
| **D1** | DualLiquidity | **Delete DualLiquidity entirely.** It is not a true DETF. Do not convert it. Do not keep a pro-rata BPT vault in the DETF tree. | 2026-08-18 |
| **D2** | Fee/creator shares | After any event that changes `O` (everyone’s `effectiveShares` except ids 1 and 2), top up ids **1** and **2** so they hold `f` and `c` of the new total. Award **effective shares only**. Formula in §3. Includes user bonds, sell-in, `buyClaim`, compound, and other `addToDETFNFT`. | 2026-08-19 |
| **D3** | Pot from free `userDetf` | Live mint: `U` **is** the D8 `Gross`. Split as before: user `1 - p`, pot `p`. The **entire** pot-side goes to bond-holder inventory. No DETF mint to `feeTo()` or creator; they claim that pot via ids 1 and 2 (D2). | 2026-08-19 |
| **D4** | Pot from bond join DETF; not expansion | On a bond, also mint **additional** `p * joinDetf` into the pot. Join amount into the reserve is unchanged. **Natural supply expansion does not take `p`** (it already pays the pot in full). This `p` rule **replaces** `_splitMintedDetf.inventoryDetf`. | 2026-08-18 |
| **D5** | Oracle sources for `p`, `f`, `c` | `p` **is** the resolved `seigniorageIncentivePercentageOfVault`. Bond terms stay lock-bonus only. Add oracle `f` / `c` (3-tier, same as other fees) plus tuple getters for bond/mint. Creator **address** is not on the oracle (DETF `PkgArgs`). | 2026-08-18 |
| **D6** | Initial `p`, `f`, `c` | No hardcoded product default in constants. Initial oracle globals come from **PkgArgs at oracle/manager deploy**. First values: `p = 5e16` (5% of minted DETF into the pot). Of the pot: purchasers `60%`, feeTo+creator `40%`. Of that `40%`: creator `70%` (`c = 28e16`), `feeTo` `30%` (`f = 12e16`). | 2026-08-18 |
| **D7** | Reserved bond NFT ids | Token id **0** = protocol / rebasing-claim reserve. Id **1** = `feeTo()` standing bond. Id **2** = creator standing bond. User bonds start at **3**. Ids **1** and **2** **must not** be sold to the protocol for rebasing claim. | 2026-08-18 |
| **D8** | Mint / burn quote | **Live only.** Every true DETF sizes **free** liquid DETF (and the burn return) from the **same curve and live reserves as the reserve pool**. Mint quote applies the seigniorage **capital bonus to amount in**, then runs that curve. Physical join still uses unboosted capital. Empty first bond does **not** use this quote (family creation / weights). Bonds do **not** use this bonus (D24). | 2026-08-19 |
| **D9** | DETF-owned reserve liquidity | **Uni V4:** the DETF instance must be the **only** party that can add or remove reserve liquidity. Hooks: **MultiStepOwnable** + deploy flag **owner-only add/remove LP**. DETF instances deploy hooks with that flag on; owner = the DETF. **Balancer V3:** keep the **current open public join**. Allowed to deviate for now. | 2026-08-19 |
| **D10** | Reserve shares, sell-in, rebasing claim | Bond principal is **ERC-4626** on reserve LP; lock bonus applies only to `effectiveShares`. Sell-to-claim **transfers `originalShares` to token id 0**. Claim token is 4626 on id 0 (shares of shares). Rebase quotes **DETF extractable** = **zap-out to DETF** of that holder’s slice of id 0 LP **plus** id 0 pending rewards. Conversion: physical NFT LP / `totalOriginalShares` + `decimalOffset` (no protocol-effective haircut). | 2026-08-22 |
| **D11** | Live mint vs bond join | Liquid mint does **not** mint DETF into the reserve. Bond is the **only** path that mints **new** DETF directly into liquidity. That join amount `G` is **unboosted** matching DETF (D24). Live mint may still join **non-DETF** capital; that LP sits in the NFT and **changes NAV** of existing `originalShares` (no new NFT shares for that deposit). | 2026-08-19 |
| **D12** | Burn burns DETF | `exchangeIn`/`exchangeOut` redeem of DETF **burns** that DETF. It is not a swap of DETF into the pool (Composed’s shipped path is out of spec). | 2026-08-19 |
| **D13** | LP in the NFT; 4626 like V4 SE | Reserve LP is held by the **bond NFT vault**. Liquidity add/remove goes **through the NFT**, which mints/burns 4626 `originalShares` so the ledger stays consistent (N10 conversion). DETF burn sizes LP as V4 SE: `lpOut = detfIn * nftLp / detfSupply` (after expansion mint-on-update) and **dilutes** originalShares holders. Live mint (D11) is the unassigned-LP exception. | 2026-08-22 |
| **D14** | No DETF to `feeTo` on mint/burn | Mint does not mint free DETF to `feeTo()`. Burn does not transfer DETF to `feeTo()`. `feeTo` earns only via token id 1 (D2). | 2026-08-19 |
| **D15** | Claim redeem = DETF only | Redeem **only for DETF**. Quote = pending + **zap-out to DETF** of the holder’s id 0 LP slice. Pay **pending first**. Compound leftover pending to id 0. Shortfall: proportional withdraw, then **buy DETF on the residual reserve** (exact-out = remaining shortfall) with withdrawn non-DETF, rejoin leftover to id 0. Owner host swap (D30), not the public router. | 2026-08-22 |
| **D16** | First bond | First bond **must** fund **all non-DETF** reserve legs (plus the DETF self-leg). Ungated. That is how the instance goes live. | 2026-08-19 |
| **D17** | Ids 1 and 2 | Always `claimRewards`. **Never** sell-to-protocol. **Never** redeem for capital/LP. | 2026-08-19 |
| **D18** | `buyClaim` is `exchangeIn` | DETF → claim is `exchangeIn`. **No new DETF mint.** The user’s DETF is **moved into liquidity** (self-leg join). NFT credits **id 0** 4626 for that LP. Only **bonds** mint new DETF into the pool. | 2026-08-19 |
| **D19** | `feeTo()` change | Do **not** transfer token id 1 when oracle `feeTo()` changes. Id 1 stays with the address that received it at wire. | 2026-08-19 |
| **D20** | DETF burn `tokenOut` | Burn may pay **any reserve token**, or the **SE buffer / rate asset** of a vault-share leg. Quote with D8 on the **DETF–tokenOut** pair (that leg’s curve). | 2026-08-19 |
| **D21** | `creator == 0` | If `PkgArgs.creator` is `address(0)`, mint token id **2** to `feeTo()`. `feeTo` then holds ids **1 and 2** (recovery if the deployer omitted a creator). Do not skip id 2 or force `c = 0`. | 2026-08-19 |
| **D22** | Claim paths ungated | `exchangeIn` DETF ↔ rebasing claim is **not** subject to mint/burn synthetic threshold gates. Live-only is enough. | 2026-08-19 |
| **D23** | Exact-out | If a **closed-form** exact-out exists on that family’s reserve curve, support it. If not, keep reverting `InvalidRoute`. No binary-search solvers. | 2026-08-19 |
| **D24** | Bonus vs bond matching | Free mint/burn and bond join are **different processes**. Live **mint** applies the **amountIn bonus** (D8) so expanding supply can move price. Live **burn** contracts supply (D12/D20; D8 bonus still off on burn). A bond mints **unboosted** proportional matching DETF (`G`) into liquidity to **deepen** the book, not to move price. Do not size `G` from a D8 boosted quote. | 2026-08-19 |
| **D25** | Mature close | Global. A mature user bond (id ≥ 3) `convertToAssets(originalShares)` → **proportional** reserve withdraw → **rejoin the withdrawn DETF** to the reserve and **credit originalShares to id 0** → send the **remaining** (non-DETF) tokens to the user. Do **not** burn that DETF. Not D20. Distinct from sell-to-claim (D10). | 2026-08-22 |
| **D26** | `PkgArgs.creator` | Every true DETF family `PkgArgs` has `address creator`. Wire mints token id 2 to that address. `creator == 0` still follows D21. | 2026-08-19 |
| **D27** | Live-mint `U` = D8 `Gross` | Q2 locked. On a live liquid mint, `U` is the entire D8 `Gross`. D3 then splits it. The non-user slice is **only** pot (old `feeToDetf` + `inventoryDetf` destinations merge). See §9. | 2026-08-19 |
| **D28** | Ids 1–2 claim tests | Every family must prove `feeTo` (id 1) and creator (id 2) **can** `claimRewards`, and that after D2 share top-ups and pot deposits they receive **only** their `effectiveShares` share of **new** pot. No leak that pays them more than due. Ship gate. Matrix in §20. | 2026-08-19 |
| **D29** | Reserve donation | Permissionless donate of joinable capital (`pairToken` / `vaultShare` / family mint-bond tokens / DETF / already-minted reserve LP) onto the Bond NFT. **No DETF mint. New `originalShares` to id 0 only.** Public function is on the Bond NFT; Uni V4 host join stays DETF-only (D9). Distinct from D11 live mint. Full law: [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md). | 2026-08-22 |
| **D30** | Owner host ops while locked | Uni V4 DETF-reserve hooks (and Balancer analog inside Vault unlock) must let the **owner (the DETF diamond)** add/remove LP and **swap exact-in/exact-out** between reserve legs **while PoolManager / Vault is already unlocked**. Do not use Uniswap SwapRouter or a nested `unlock` if one is open. Required for D15’s residual DETF buy and D29 join. Owner `depositSingle` at hook `MINIMUM_LIQUIDITY` is allowed and **must mint lpOut > 0**. | 2026-08-22 |
| **D31** | Expansion then gate | Live **mint**, live **burn**, **redeemClaim**, and **closeBondMature** **realize pending natural expansion first** (Policy; Open is a no-op). Then recompute synthetic from **minted** `totalSupply` and apply Policy mint/burn gates. If the post-realize synthetic fails the gate, the **whole tx reverts** (expansion does not stick). Desired: expansion can block a mint/burn that would overshoot the band. Donate does **not** realize. | 2026-08-22 |

---

## 1. Intent

True DETFs share one product shape: the diamond is the share ERC-20, a reserve with a DETF self-leg prices mint/burn, and bond NFTs lock principal and weight seigniorage / expansion by `effectiveShares`.

Shipped families do not follow one process. This PRD is where we lock the common law, then implement it on every remaining family. DualLiquidity is the first lock because it cannot be aligned (see §2). User-bond top-up of `feeTo` and creator effective shares is locked as a method in §3. The pot is funded from free `userDetf` (D3) and from bond join DETF (D4), not from expansion. Oracle mapping is §6; initial `p`/`f`/`c` are §7; reserved NFT ids are §8. Mint/burn quote is §10. DETF-only reserve LP is §11 (Balancer open-join exception in D9). Reserve-share / rebasing claim law is §14. Mint vs bond join, burn, NFT custody, claim redeem, first bond, and `exchangeIn` claim are §15. Mint/burn bonus vs unboosted bond `G` is §17. Mature close is §18. `PkgArgs.creator` is §19. Ids 1–2 claim tests are §20 (D28). Reserve donation is §21 (D29). Owner host ops while locked are §22 (D30). Expansion realize-then-gate is §23 (D31). **What is universal vs family-specific is §16.** Live-mint `U` = D8 `Gross` is §9 (D27).

The DETF owns liquidity through Bond NFT `originalShares`. Users buy that ownership by bonding capital plus unboosted matching DETF (`G`). Token id 0 is the protocol slice; the rebasing claim token is a 4626 on id 0. Ids 1 and 2 never provided reserve capital: they cannot close or sell, and they take only a fee-oracle cut of minted DETF rewards (D2/D17). Protocol-acquired LP (sell-in, `buyClaim`, mature-close DETF rejoin, donate) is booked on id 0. Free liquid DETF is a second claim on the same NFT LP (D13).

**In-scope families (after D1):**

| Host | Family |
|------|--------|
| Balancer V3 | Single SE, multi-vault weighted, mixed-buffer, composed stable |
| Uni V4 | Single SE CP, Orbital, Weighted, Curve Quad Stable |

---

## 2. D1 — Delete DualLiquidity (LOCKED)

`DualLiquidityLinkedCrossVersionUniswapVault` is **removed**. It has no bond NFT. Usage fees are ERC-20 share inflation to `feeTo()`. It is a pro-rata BPT vault that was only layout-co-located under `detf/`. It will not be repaired into a true DETF.

Do **not**:

- Add a bond NFT, claim token, thresholds, or seigniorage to DualLiquidity.
- Leave a deprecated-but-shipping package, facet, or DFPkg.
- Relocate the Solidity outside `detf/` as a surviving product.

### 2.1 Delete surface (inventory, not an impl checklist)

| Surface | Path / note |
|---------|-------------|
| Production Solidity | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Fork TestBase + suite | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Family product docs | `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Agent law | [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../../../docs/agent/INDEXEDEX_AGENT_LAW.md) family table, directory map, TestBase list |
| Inventories | `docs/DETF_POOL_INTEGRATION_INVENTORY.md`, content inventory, codebase map, skill catalog if they list the family |
| Research | `research/scenarios/dualLiquidityLinkedCrossVersion/`, CCA rehearsal DualLiquidity bootstrap. Historical findings may stay as history. They must stop treating DualLiquidity as a live product. |

Exact file list and link-fix width belong in a later implementation plan.

### 2.2 Consequences

- The DETF family table lists only true DETFs.
- DualLiquidity is not a behavioral reference for new families.
- Nested-SE matrices that used DualLiquidity as a leg use another production SE or true DETF instead.

### 2.3 Supersedes (product existence only)

- [`docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md`](../../../docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md)
- [`DualLiquidity_CrossVersion_Directory_Move_PRD.md`](../../../docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidity_CrossVersion_Directory_Move_PRD.md)

Those files stay until the delete pass removes them. Do not implement DualLiquidity features against them after 2026-08-18.

---

## 3. D2 — Fee/creator effective shares on a new user bond (LOCKED)

`feeTo()` and the DETF creator do **not** receive a DETF mint. They hold standing bond NFTs and claim the same pot every other bonder claims: inventory DETF and natural expansion paid on `effectiveShares`.

After **any** change to `O` (user bond open, sell-in to id 0, `buyClaim` / `exchangeIn` DETF→claim, protocol compound `addToDETFNFT`, other principal 4626 mint), re-run the same top-up so ids 1 and 2 stay at `f` and `c`. Mint the user’s `effectiveShares` first when the event is a user bond, then top up.

`f` and `c` are WAD fractions (`1e18` = 100%). Their values are **not** locked. Constraint: `f + c < 1e18`.

### 3.1 Symbols

| Symbol | Meaning |
|--------|---------|
| `f` | Target fraction of total `effectiveShares` for the `feeTo` NFT |
| `c` | Target fraction of total `effectiveShares` for the creator NFT |
| `F0`, `C0` | Those NFTs' `effectiveShares` **before** this top-up |
| `O` | Sum of `effectiveShares` of **everyone except** the fee and creator NFTs, **after** the user's new shares are on the ledger (other users + protocol NFT + this user bond) |
| `T` | Implied new total `effectiveShares` after the top-up |
| `dF`, `dC` | Shares to add to the fee NFT and the creator NFT |

### 3.2 Formula (normative)

```
T  = O * 1e18 / (1e18 - f - c)
F* = T * f / 1e18
C* = T * c / 1e18
dF = F* > F0 ? F* - F0 : 0
dC = C* > C0 ? C* - C0 : 0
```

Integer math: **floor** each division (`mulDiv`). Do not add shares if the target is already at or above (`dF` / `dC` are never negative on this path). Flooring may leave realized weights slightly under `f` and `c`. That is required. Do not round up.

After the add:

```
F0 + dF ≈ f * (O + dF + dC)
C0 + dC ≈ c * (O + dF + dC)
```

If `f == 0` then `dF == 0`. If `c == 0` then `dC == 0`.

### 3.3 Order

1. Open the user bond (`createPosition` / `createPositionWithEffectiveBase`). User `effectiveShares` now sit in `O`.
2. Read `O`, `F0`, `C0`.
3. Compute `dF`, `dC`.
4. Add `dF` / `dC` as **effective-share weight only** on the standing fee and creator NFTs. Do not mint DETF to `feeTo()` or the creator. Do not give those NFTs redeemable reserve principal on this path.

### 3.4 Worked example

First user bond mints `100e18` effective shares. No prior positions. `f = 0.10e18`, `c = 0.05e18`.

```
O  = 100e18
T  = 100e18 * 1e18 / 0.85e18 = 117.647...e18
F* = 11.764...e18
C* = 5.882...e18
```

Fee NFT gets `11.764...e18`, creator NFT gets `5.882...e18`. Fee is 10% of the new total, creator is 5%, user (and any protocol principal) is the remaining 85%.

### 3.5 What D2 does not lock

- How the standing NFTs are created at wire (ids 0–2). Id 1 does **not** migrate on `feeTo()` change (D19).

---

## 4. D3 — Bond-holder pot is a cut of free `userDetf` (LOCKED)

`p` is a WAD fraction of **free DETF** (`U`) **when that route mints free DETF**. On a **live liquid mint**, `U` **is** the D8 `Gross` (D27). Whether a bond mints free `U` is **not locked** (§9.2). It is **not** a fraction of:

- join / self-leg DETF minted into the reserve
- BPT or hook LP (bond principal)
- the user’s bond `originalShares` / `effectiveShares`

**Redirect, not extra inflation.** Split as before, destination unified:

```
user wallet      = U * (1e18 - p) / 1e18
bond-holder pot  = U * p / 1e18
```

The pot-side is **only** minted to the bond NFT vault as inventory (reward token). That includes what shipped code called `feeToDetf` **and** `inventoryDetf`. `feeTo()` and the creator do **not** receive a DETF mint. They claim this pot via token ids 1 and 2 (D2).

`p` is the oracle seigniorage incentive (D5/D6). Floor `mulDiv`. If `U == 0` (a route that mints no free user DETF), the pot from this rule is 0.

Whenever a route mints free `U`, this redirect applies. Bond join DETF is funded by **D4**, not by this redirect.

---

## 5. D4 — Additional pot mint on bond join DETF; expansion excluded (LOCKED)

Bond join / self-leg DETF (`detfForPool_` / `detfForJoin_`) stays in the reserve. It is not liquid user DETF. It still **counts** as minted DETF for the seigniorage share to existing bond holders.

If a bond mints `G` DETF into the reserve (the **unboosted** proportional self-leg, D24):

```
join into reserve     = G          (unchanged)
additional pot mint   = G * p / 1e18
```

That additional amount is minted to the bond NFT vault as inventory. It is **new supply**, not taken out of `G`. Floor `mulDiv`. If `G == 0` (BPT-only lock, no self-leg mint), this term is 0.

**Natural supply expansion is excluded.** Expansion is already minted wholly into the bond-holder pot. Do not mint `p * expansion` on top.

**This `p` rule replaces the current `inventoryDetf` half-incentive** in `_splitMintedDetf`. Do not keep both. `feeToDetf` remains removed (D2/D3). After D3+D4 the pot is only:

| Source | How the pot is funded |
|--------|------------------------|
| Free `userDetf` (mint or bond) | D3 redirect: `p * U` |
| Bond join DETF | D4 additional: `p * G` |
| Natural expansion | Full expansion mint into the pot; **no** extra `p` |

BPT/LP principal is still not a base (it is not DETF).

---

## 6. D5 — Vault Fee Oracle: `p` / `f` / `c` (LOCKED)

### 6.1 Existing fields (do not invent new ones for these)

| Role | Oracle field | Notes |
|------|----------------|-------|
| Lock-duration bonus for the **purchaser** | `BondTerms` (`minLockDuration`, `maxLockDuration`, `minBonusPercentage`, `maxBonusPercentage`) | Already used by `DETFBondNFTMathLib._calcBonusMultiplier`. Not `p`/`f`/`c`. |
| **`p`** (pot size) | `seigniorageIncentivePercentageOfVault` (3-tier) | Initial global from oracle PkgArgs (D6), not a Solidity constant. Replaces the old “half incentive → `inventoryDetf`” reading of this field. |
| Collector address | `feeTo()` | Owner of the fee-recipient bond NFT. Not a percentage. |

### 6.2 New fields: `f` and `c`

Add the same 3-tier pattern (vault → type → global; stored `0` = unset). WAD. **`f + c < 1e18`** at every tier that is set (reject a write that would resolve to `f + c >= 1e18`).

| Role | Proposed names (Query / Manager) |
|------|----------------------------------|
| **`f`** (`feeTo` weight of the pot) | `defaultSeigniorageFeeToSharePercentage` / `…OfTypeId` / `seigniorageFeeToSharePercentageOfVault` · `setDefault…` / `set…OfTypeId` / `setSeigniorageFeeToSharePercentageOfVault` |
| **`c`** (creator weight of the pot) | `defaultSeigniorageCreatorSharePercentage` / `…OfTypeId` / `seigniorageCreatorSharePercentageOfVault` · matching setters |

Optional atomic setters (enforce `f + c < 1e18` in one tx):

- `setDefaultSeignioragePotShares(uint256 f, uint256 c)`
- `setDefaultSeignioragePotSharesOfTypeId(bytes4, uint256 f, uint256 c)`
- `setSeignioragePotSharesOfVault(address, uint256 f, uint256 c)`

Creator **recipient address** is deploy-time `PkgArgs` on the DETF instance, not an oracle value.

### 6.3 Tuple getters (minimize oracle calls)

Keep existing singles (`bondTermsOfVault`, `seigniorageIncentivePercentageOfVault`, `feeTo`, and the new `f`/`c` singles). Add:

| Function | Returns | Call site |
|----------|---------|-----------|
| `seigniorageSplitOfVault(address)` | `(p, f, c)` | Live mint (needs `p`; `f`/`c` unused unless that path also touches shares) |
| `seigniorageSplitAndFeeToOfVault(address)` | `(feeTo, p, f, c)` | Mint or wire that also needs the collector |
| `bondTermsAndSeigniorageOfVault(address)` | `(feeTo, BondTerms terms, p, f, c)` | **Bond** (lock bonus + D3/D4 pot + D2 top-up in one call) |

Existing `seigniorageIncentivePercentageOfVaultAndFeeTo` and `bondTermsAndFeeToOfVault` stay. DETF bond/mint paths should prefer the new tuples.

### 6.4 What D5 does not lock

- Implementation of the new oracle selectors (product/API only). Initial numbers are D6. Usage fee on DETF mint/burn is **off** (D14).

---

## 7. D6 — Initial `p`, `f`, `c` from oracle PkgArgs (LOCKED)

Do **not** treat `DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE` (or any new `DEFAULT_*` for `f`/`c`) as product law. The Vault Fee Oracle’s **first** global values are written from **PkgArgs at oracle/manager deploy** (`IndexedexManagerDFPkg.PkgArgs` today). Later vault/type overrides still use the 3-tier setters.

**First PkgArgs values** (WAD), from the public nested percents:

| Public line | Stored |
|-------------|--------|
| 5% of minted DETF into the bond-holder pot | `p = 5e16` |
| Of that pot, purchasers get 60% | `1 - f - c = 0.60e18` |
| Of that pot, `feeTo` + creator get 40% | `f + c = 0.40e18` |
| Of that 40%, creator 70% | `c = 28e16` (0.28 = 0.40 × 0.70) |
| Of that 40%, `feeTo` 30% | `f = 12e16` (0.12 = 0.40 × 0.30) |

Check: `f + c = 0.40e18 < 1e18`. D2 then keeps ids 1 and 2 at those weights after each user bond.

Post-deploy, the oracle owner may still change globals / type / vault overrides. D6 only locks the **initial** PkgArgs and forbids a hardcoded constant as the source of truth.

---

## 8. D7 — Reserved bond NFT token ids (LOCKED)

On every true DETF bond vault, these ids are **fixed**:

| Token id | Role | Owner | Redeemable BPT/LP | Sell → rebasing claim |
|----------|------|-------|-------------------|------------------------|
| **0** | Protocol / rebasing-claim reserve | Bond vault (`address(this)`) | Yes (claim backing) | N/A (already protocol) |
| **1** | `feeTo()` standing reward bond | `feeOracle.feeTo()` | No | **Forbidden** |
| **2** | Creator standing reward bond | DETF `PkgArgs.creator` | No | **Forbidden** |
| **≥ 3** | User bonds | Purchaser | Yes (family principal) | Allowed when mature |

Wire path mints **0, then 1, then 2** before any user `createPosition`. User bonds must not receive ids 0–2.

`sellPositionToDetfNft` (and any equivalent) **reverts** for token ids **1** and **2**. They only `claimRewards` on the pot. Id 0 remains the only principal that backs the rebasing claim token.

**Sentinel:** today’s code often treats `detfNftId == 0` as “unwired”. Under D7, 0 is a **valid** protocol id. Wired-state must use a dedicated flag or “bond vault address set”, not `id == 0`.

---

## 9. D27 — Live-mint `U` is the D8 `Gross`; whole split to the pot (LOCKED)

Q2 is locked. This is **not** about bond `G` (D24).

### 9.1 Live mint

`p` is the oracle `seigniorageIncentivePercentageOfVault` (D5/D6). On a **live liquid mint**:

1. **D8 size.** `Gross = curve(amountIn * (1 + p))`. User deposits unboosted `amountIn`. No DETF into the pool (D11).
2. **`U = Gross`.** There is no leftover usage-fee peel and no half-incentive `inventoryDetf` as a second base.
3. **D3 split, as before**, but the **entire** non-user slice is bond-holder inventory:

```
user wallet      = Gross * (1e18 - p) / 1e18
bond-holder pot  = Gross * p / 1e18
total minted     = Gross
```

Do **not** mint `feeToDetf` to `feeTo()`. Do **not** mint DETF to the creator. Those addresses share this pot only by holding token ids **1** and **2** and calling `claimRewards` (D2, D7, D14). That is why those standing NFTs exist.

Floor `mulDiv`. Same `p` enlarges the D8 quote and then cuts the pot from `Gross`. On a linear book the user can receive slightly less than an unboosted quote; that is accepted.

### 9.2 What D27 does not lock

Whether a **bond** still mints free `U` to the bonder’s wallet (shipped families mint extra `userDetf` from a split of `G`). D24 only forbids boosting `G`. If bonds keep a free split, this same destination rule applies: user slice to the user, **all** of the old `feeToDetf` + `inventoryDetf` to the pot, plus D4’s `p * G`. If the bond incentive is only matching `G`, then `U = 0` on bonds and the pot from a bond is only D4.

The impl plan uses **launch default L1**: bonds still mint free `U = G`, D3 + D4 both run. Amend this section if product wants `U = 0` on bonds instead.

---

## 10. D8 — Quote: bonus on amount in, same curve as the reserve (LOCKED)

**Applies only when the reserve is live** (first bond done, D16). Empty-pool / first-bond sizing stays family-owned (creation rate, weights, amp + first amounts). Do not run the live-curve + amountIn bonus on an empty book.

**Applies only to free liquid mint and burn**, not to bond join `G` (D24).

Every in-scope family uses this process for **how much free liquid DETF to mint** (and the inverse spirit for **burn return**):

1. Take the user’s real capital (`amountIn`: vault shares, buffer, or pair, as the family defines).
2. Apply the seigniorage **capital bonus to amount in**: `amountInBoosted = amountIn * (1 + p)` where `p` is the oracle seigniorage incentive (D5/D6).
3. Compute amount out with the **same curve and live reserves** as the reserve host (Balancer weighted / stable math, or Uni V4 hook book).
4. That out is **gross** DETF. **`U = Gross` (D27).** D3 splits it: user `(1 - p) * Gross`, pot `p * Gross`. The pot-side is inventory only (no `feeTo` mint). The user still only **deposits unboosted** capital. The bonus is a **quote** incentive, not extra tokens into the pool. D4 (`p * G`) is a **bond** term and is not part of this mint path.

Shipped Single SE / MVW / MixedBuffer / Composed / Uni V4 already quote this way on live mint. MixedBuffer also **joins gross DETF** on live mint; that join behavior is **not** required by D8 (D11). D8 is the quote rule only.

Burn must be honest against the same book: payout is what that curve can return from reserves the DETF can actually remove. Uni V4: that is DETF-controlled LP (D9). Balancer: public join is still allowed (D9 exception); coverability is therefore not the same invariant. D20 still: capital bonus does **not** apply on burn unless a later lock says otherwise.

Do not size bond matching DETF with this process.

**D31 (mint/burn execute):** before the D8 quote and before the Policy gate, **realize pending expansion** (mint expansion DETF to the Bond NFT, Policy only). Then gate on synthetic computed from the **post-realize** `totalSupply`. Views `isMintingAllowed` / `isBurningAllowed` must match: they count pending expansion in the denominator so they equal post-realize synthetic without minting in the view. If realize + gate fails, the whole tx reverts.

---

## 11. D9 — Only the DETF may add or remove reserve liquidity (LOCKED)

If outsiders can add LP, the reserve curve sees liquidity the DETF cannot withdraw. Mint/burn quotes (D8) would then not be coverable.

**Invariant:** for every true DETF, the liquidity that appears in the reserve quote is liquidity **only that DETF instance** can add or remove.

### 11.1 Uni V4 hooks (implementation required)

Hooks used as a DETF reserve must support:

- **MultiStepOwnable** (Crane operable / ERC-8023 pattern), owner set to the **DETF diamond**.
- A **deploy-time flag** (hook `PkgArgs`) that locks add/remove liquidity to **`onlyOwner`**.
- When the flag is on: no permissionless `addLiquidity` / `removeLiquidity` / native V4 `modifyLiquidity` for third parties. Swaps may stay public (volume).
- When the flag is off: existing permissionless LP behavior (non-DETF hook uses).

**Every Uni V4 DETF instance deploys its reserve hook with the flag on.** Owner = that DETF. The DETF remains unowned/immutable; the hook is owned by the DETF, not by an EOA.

Applies to CP, Orbital, Weighted, and Curve Quad buffer hooks (package path, not leftover monomorph CREATE3 unless that hook is still the reserve).

### 11.2 Balancer V3 families (open liquidity, for now)

**Leave Balancer DETFs on their current open public join.** Outsiders may add and remove liquidity on the reserve pool. That is an allowed deviation from the Uni V4 owner-only rule. Do not add pool hooks, router allowlists, or DETF-held-only BPT in this alignment pass in order to close Balancer join.

Coverability of a D8 burn quote against Balancer reserves is therefore **not** the Uni V4 invariant. Accept that until a later lock.

Applies to Single SE, multi-vault weighted, mixed-buffer, and composed stable.

### 11.3 Owner ops while the host is locked (D30)

Public swaps stay permissionless (default **yes**). The DETF, as hook owner, also needs **private** swap and LP add/remove that work when Uniswap `PoolManager` is **already unlocked** (this transaction is inside `unlockCallback`, or a nested liquidity op). Claim redeem (D15) must **buy DETF** on the residual reserve after a proportional LP withdraw; donate (D29) must `depositSingle` in the same class of tx. Neither may call Uniswap SwapRouter or start a second `PoolManager.unlock` if one is open.

**Required on every Uni V4 hook used as a DETF reserve** (CP, Orbital, Weighted, Curve Quad buffer packages):

- Owner-only exact-in and exact-out swap between reserve legs (DETF/raw ↔ pair / buffer legs).
- Owner-only `deposit` / `depositSingle` / `withdraw` / `withdrawSingle` (already D9 `onlyOwner` when the flag is on).
- If `PoolManager` is locked: settle on the **current** unlock or use **internal book settlement** (same class as zap internal swaps). If it is not locked: the owner may open a normal unlock.
- Non-owner cannot use this path.

Balancer: the analog is a swap/join/exit **inside** an already-open Vault unlock, not a nested Router call.

### 11.4 What D9 / D30 do not lock

- Whether hook **swaps** stay permissionless for the public (default **yes**).
- Ownership transfer of the hook after DETF deploy (default: **no**; DETF is immutable owner).
- Implementation of MultiStepOwnable on each hook package.
- A later pass that might close Balancer join. Not this PRD’s current law.

---

## 14. D10 — ERC-4626 reserve shares, sell-in, rebasing claim (LOCKED)

Applies to **every** true DETF family.

### 14.1 Bond purchasers (token id ≥ 3)

Reserve LP from the join (`G`: BPT or hook LP) is the **asset**. The bond vault mints **original shares** with standard ERC-4626:

```
if totalOriginalShares == 0 or totalLp == 0:  originalShares = G
else:                                         originalShares = G * totalOriginalShares / totalLp
```

Lock-duration bonus (existing `BondTerms` curve) applies **only** to reward weight:

```
effectiveShares = originalShares * lockBonus / 1e18
```

Do **not** use open-time mids (or any other numeraire) as `effectiveBase` for this ledger. Orbital / Weighted / Quad `createPositionWithEffectiveBase(mid)` is superseded for reserve-share accounting.

Ids **1** and **2** still receive D2 **effective-share** top-ups only. They do not receive redeemable `originalShares` of reserve LP.

### 14.2 Sell bond → rebasing claim

When a mature user bond is sold to the protocol:

1. `originalShares` of that NFT are **transferred** to token id **0** (debit user, credit protocol). Not a fresh 1:1 LP mint onto id 0 if the exchange rate has moved.
2. The user’s lock **bonus weight is burned** (effective shares of the user NFT go away; id 0 is not credited the bonus).
3. Physical LP stays in the **bond NFT vault** (D13). The claim token does **not** take custody; it calls the NFT to withdraw.
4. The rebasing claim token mints to the seller with ERC-4626 against id 0 **before** the transfer:

```
if protocolOriginal == 0:  claimShares = originalSharesMoved
else:                      claimShares = originalSharesMoved * totalClaimShares / protocolOriginal
```

Ids 1 and 2 cannot take this path (D7).

### 14.3 Rebasing token: shares of shares

Claim holders own **shares of token id 0’s originalShares**. Id 0 owns a 4626 slice of reserve LP. That is shares of shares. They do not own user-bond LP until that bond is sold in.

Redeem of claim burns claim shares and releases a pro-rata slice of id 0 `originalShares` (then unwind).

### 14.4 Rebase quotes DETF extractable

The claim token **rebases in DETF**, not in rateAsset. `balanceOf` / `redemptionRate` quote how much **DETF** that holder can extract, as the sum of:

1. **Liquidity unwind (zap-out to DETF):** DETF from that holder’s slice of id 0’s reserve LP if that slice were fully unwound to DETF on the reserve curve: the DETF self-leg of a proportional withdraw **plus** converting the other exit legs to DETF on the **residual** book (other originalShares still in the pool). Not DETF-leg-only.
2. **Bond-holder rewards:** that holder’s pro-rata slice of **pending DETF** on token id 0 (`pendingRewards(0)`), the same pot D3/D4/expansion pay into.

```
totalDetf  = zapOutToDetf(lpOf(id 0)) + pendingRewards(0)
rate       = totalDetf / totalClaimShares     (1e18 if totalClaimShares == 0)
balanceOf  = claimShares * rate / 1e18
```

`zapOutToDetf` and D15 execute **must use the same identity**. The last-resort DETF buy is that zap-out’s pair→DETF leg; it is not a third product path. In the normal case (residual LP remains) the leftover non-DETF from the proportional withdraw is exactly what that buy needs.

Protocol compound may still auto-compound id 0’s pending into reserve LP (existing compound law). After compound, (2) falls and (1) rises; the DETF quote should stay continuous aside from curve fees/slippage.

Shipped claim tokens that preview **rateAsset** via `previewExchangeIn(BPT → rateAsset)`, that **omit** id 0 pending rewards, or that quote **only** the DETF leg of a proportional withdraw are **out of spec** under D10.

### 14.5 4626 conversion (N10)

`convertToAssets(s)` / `convertToShares(lp)`:

- Numerator / assets: `lpToken.balanceOf(bondNft)` (physical LP on the NFT).
- Denominator / shares: **`totalOriginalShares`**. Never `totalShares` (effective). **Do not** subtract protocol / id 0 effective shares from the denominator.
- `s` is **originalShares**, never `effectiveShares`.
- Keep existing `BetterMath` + `decimalOffset`.
- Mature close and claim `lpOut` must pass originalShares into this conversion.

Shipped `DETFNFTVaultRepo._totalLpReserveForConversion` that haircuts protocol effective shares while using all physical LP is **out of spec**. That overpays user bonds and leaks id 0 LP (donate, D25 rejoin, `buyClaim`) to users.

---

## 15. D11–D18 — mint join, burn, custody, claim, `exchangeIn` (LOCKED)

### 15.1 D11 — Liquid mint vs bond

| Action | DETF self-leg into reserve? |
|--------|------------------------------|
| User buys **newly minted DETF** (`exchangeIn` → DETF) | **No new DETF** into the pool. Non-DETF capital may join. New LP is held by the NFT **without** minting new `originalShares` for that deposit: existing bond shares’ claim on LP **changes** (4626 NAV). Free DETF size uses D8 (live + amountIn bonus). |
| User **buys a bond** | **Yes.** Newly minted join DETF `G` goes into liquidity with the non-DETF legs. `G` is **unboosted** proportional matching (D24). User gets 4626 `originalShares`. |
| `exchangeIn` DETF → claim | **No new DETF mint.** Provided DETF is joined as self-leg. NFT mints `originalShares` to **id 0**. |

D8’s boosted `amountIn` is **quote-only on free mint/burn**. Mixed-buffer live mint that joins `gross` DETF is **out of spec**. **Only bonds** mint new DETF directly into liquidity, and that amount is not D8-boosted.

### 15.2 D12 — Burn burns supply

Redeeming DETF **burns** the DETF the user provided. Composed’s shipped path (swap DETF into the reserve, supply unchanged) is **not** the product. See the discussion note in the session that recorded this lock: D8/D10 assume a smaller DETF supply and a proportional LP exit, not a DEX sale of DETF.

### 15.3 D13 — NFT holds LP; V4 SE 4626

All reserve LP (BPT or hook LP) is **owned by the bond NFT vault**. The DETF and the rebasing token do **not** hold idle LP. They call the NFT to add/remove liquidity. The NFT mints/burns 4626 `originalShares` on those movements so `originalShares` stay a claim on remaining LP.

Sizing a **DETF burn** (after expansion mint-on-update, so pending expansion is already DETF in the pot / `totalSupply`):

```
lpOut = detfIn * nftLp / detfTotalSupply
```

Same shape as Uni V4 Standard Exchange (`sharesBurned * reserves / totalShares`). Do **not** use diamond `balanceOf` BPT or `supply + unminted expansion`. Then remove along the **DETF–tokenOut** curve (D20); **rejoin all other legs**.

Live-mint capital deposits increase NFT `totalLp` **without** a matching `originalShares` mint (D11). Bond mints 4626 to the **user** id. DETF→claim, donate, protocol compound, and mature-close DETF rejoin mint 4626 to **id 0**.

Free DETF burn still sizes LP as `detfIn * nftLp / detfSupply` (this section). That second claim dilutes every originalShares holder, including id 0. Accepted.

### 15.4 D14 — No `feeTo` DETF on mint or burn

Mint does not `_mintDetf(_feeTo(), …)`. Burn does not `safeTransfer(_feeTo(), feeDetf)`. Oracle `usageFeeOfVault` is unused on these DETF mint/burn paths. `feeTo`’s DETF income is **only** `claimRewards` on token id 1.

### 15.5 D15 — Claim redeem is DETF, rewards first, zap-out fill

`exchangeIn(claim, amount, DETF, …)` / `redeem`. User receives **DETF only**.

`owed` = this holder’s claim on `pendingRewards(id 0) + zapOutToDetf(id 0 LP slice)` (D10 §14.4). Preview and execute share that identity. Zap-out’s leftover→DETF leg uses **post-withdraw** residual reserves and the **same trading fee as public swaps** (Uni V4 CP: 0.3%).

1. **Realize pending expansion** (D31). Expansion DETF is minted to the Bond NFT and enters the `rewardPerShares` ledger. Open: no-op.
2. Pull claim tokens; burn claim shares (D10 4626). `lpOut` = `convertToAssets` of the released id 0 originalShares (N10).
3. **Harvest all** id 0 pending DETF (not this holder’s pro-rata only). Pay as much as possible toward `owed`. Leftover pending: compound to id 0 (self-leg join, 4626 to id 0).
4. If harvested pending ≥ `owed`: **do not** withdraw LP. Credit that `lpOut` back to id 0 (`addToDETFNFT`). Pay `owed`. Done.
5. If still short: proportional withdraw of `lpOut`. Keep the DETF leg.
6. **Buy DETF** on the **residual** reserve. Exact-out = remaining shortfall. Pay with withdrawn non-DETF. Do **not** redeem other bonders’ `originalShares`. Owner host swap (D30), not Uniswap SwapRouter.
7. **Sell order:** after the proportional withdraw, snapshot each leftover non-DETF token’s **DETF-buying power** (preview exact-in of the full leftover → DETF on the residual book). Sort descending once. Do not re-sort after each fill. For each leftover in that order: if it cannot fill the remaining shortfall even sold in full, sell **all** of it (exact-in); else sell exact-out only the remainder and **stop**. Uni V4 CP: the only leftover is `pairToken`.
8. Rejoin leftover non-DETF and leftover DETF to the NFT; `originalShares` to id 0. Owner `depositSingle` at hook `MINIMUM_LIQUIDITY` is allowed and **must mint lpOut > 0** (same zap math as a live zap). Zero LP reverts; do not skip the rejoin.
9. Pay DETF only. `minOut` still applies. No rateAsset redeem.

Claim redeem is **not** Policy mint/burn gated (D22). Expansion realize still runs so the claim holder is paid from id 0 inventory that includes id 0’s share of that expansion.

**Last exit** (this withdraw empties NFT-held LP; hook may retain `MINIMUM_LIQUIDITY` on `address(0)`): skip the residual buy. Pay pending + DETF from the proportional withdraw. Owner `depositSingle` leftover pair to id 0 (D30 MIN exception; **lpOut > 0** or revert). Never send pair to the redeemer.

Do not auto-compound pending **before** step 3 in this transaction. Do not add a D20 user-burn of free DETF as a redeem path.

### 15.6 D16 — First bond

Permissionless first bond must supply **every non-DETF reserve leg** (and mint the DETF self-leg into the pool). That creates protocol reserve and sets live. Synthetically ungated (existing threshold law). Later bonds may be single-leg as each family already allows.

### 15.7 D17 — Token ids 1 and 2

Always allowed to `claimRewards`. Forbidden: `sellPositionToDetfNft`, mature close / capital redeem, any path that pulls their LP (they have none). User bonds (id ≥ 3) still sell-to-claim when mature (D7/D10) and close when mature (D25).

### 15.8 D18 — Claim via `IStandardExchange`

`tokenIn = DETF`, `tokenOut = rebasingClaim` is a supported `exchangeIn` (and matching preview). **Do not mint DETF.** Join the **provided** DETF as the self-leg; NFT 4626-mints `originalShares` to id 0; mint claim shares (D10). Only **bonds** mint new DETF into the pool.

### 15.9 D19 — `feeTo()` change

Token id 1 is not transferred, reminted, or reassigned when `feeOracle.feeTo()` changes. The original recipient keeps `claimRewards` on id 1. A later collector does not earn on this instance unless they already hold id 1.

### 15.10 D20 — DETF burn `tokenOut`

`exchangeIn(DETF, amount, tokenOut)` may use any token in the reserve, or the **buffer / rate asset** of an SE vault-share leg. Size the burn with D8: capital bonus does **not** apply on burn; quote **outGivenIn / inGivenOut** on the **DETF–tokenOut** book (that leg). Invalid `tokenOut` → `InvalidRoute`.

### 15.11 D21 — Creator omitted

Wire token id 2 to `PkgArgs.creator` when nonzero. If `creator == address(0)`, mint id 2 to `feeOracle.feeTo()` (same address as id 1). Both NFTs keep their D2 weights (`f` on 1, `c` on 2). This is a deploy recovery path, not a second fee product.

### 15.12 D22 — No mint/burn gates on claim

`exchangeIn(DETF → claim)` and `exchangeIn(claim → DETF)` do **not** call `isMintingAllowed` / `isBurningAllowed`. They require the instance **live** (first bond done). Policy/Open gates stay on liquid DETF mint/burn only.

### 15.13 D23 — Exact-out

`exchangeOut` / exact-out mint or burn: implement when the reserve host has a **closed-form** `inGivenOut` (or family equivalent) on that DETF–token pair. Weighted and constant-product typically do; do not add a binary-search solver. No closed form → `InvalidRoute`.

### 15.14 D25 — Mature close (see §18)

`closeBondMature` on id ≥ 3 is the D25 process, not a D20 single-sided burn.

### 15.15 D26 — `PkgArgs.creator` (see §19)

Every family `PkgArgs` includes `creator`. D21 still covers `address(0)`.

---

## 16. Universal vs family-specific (LOCKED index)

This is the stipulation asked for: **one process**, **family-owned curve and token set**.

### 16.1 Must be the same on every true DETF

Bond NFTs (ids 0 / 1 / 2 / ≥3), D2 weights, pot funding (D3/D4), no DETF to `feeTo` on mint/burn, ERC-4626 + lock bonus, sell-in of `originalShares` to id 0, claim = shares of id 0, rebase in DETF, live mint does not mint DETF into the pool, only bonds mint new DETF into liquidity and that `G` is **unboosted matching** (D24), DETF→claim moves provided DETF in (no new mint), burn **burns** DETF, LP lives in the NFT, burn LP size `detfIn * nftLp / supply`, claim redeem pending-then-compound-then-prop-withdraw-then-buy-DETF-on-residual-then-rejoin, first bond funds **all** non-DETF legs, ids 1–2 claim-only, claim `exchangeIn` ungated, `feeTo` change does not move id 1, `creator` on every family `PkgArgs` (D26), `creator == 0` mints id 2 to `feeTo`, quote shape D8 (bonus on **live free mint** `amountIn` only), mature close is proportional withdraw then **rejoin withdrawn DETF to id 0** then send the rest (D25), exact-out only if closed-form, **D28 claim-share tests on ids 1 and 2**, **D29 reserve donation** (Bond NFT public `donate`, DETF-only host join, no DETF mint, **originalShares to id 0**), **D30 owner host swap/LP while locked**, **D31 expansion then mint/burn gate**.

Uni V4: DETF-only add/remove LP. Balancer: open public join allowed (D9).

Policy/Open gates, protocol compound (id 0 only), and natural expansion stay as in the compound/threshold PRDs, except D15’s redeem order, D22 (claim ungated), and **D31** (realize expansion on mint/burn/redeem/close before the gate).

### 16.2 Family-owned (do not “standardize away”)

| Concern | Who defines it | Law |
|---------|----------------|-----|
| **Reserve curve** | Family | D8: use **this instance’s** reserve book. Weighted, mixed-buffer stable, composed-of-BPTs, Uni V4 CP, orbital sphere, V4 weighted, quad StableSwap. |
| **Reserve token set** | Family | Which legs sit next to the DETF self-leg. |
| **Live mint `tokenIn`** | Family | Vault share, buffer, pair, or SE zap **into** a reserve leg. Not share↔share on the DETF. Donate (D29) uses this same list plus **DETF** and reserve `lpToken`. |
| **Burn `tokenOut`** | Family ∩ D20 | Any **reserve** token, or that SE leg’s buffer/rate asset. Quote DETF–`tokenOut` on **that** curve. |
| **First-bond capital** | Family | The concrete non-DETF legs D16 requires (see §16.3). |
| **Empty-pool / first-bond quote** | Family | Pool is empty: **Uni V4 uses `openingPairPerDetfWad`** (0 → creation at init). Synthetic peg stays **`creationPairPerDetfWad`**. **D8 does not run here.** D8’s live curve + amountIn bonus applies **after** live, and only to free mint/burn. Balancer Single SE / MVW: weights (`detfWeight` / `vaultWeights`). Mixed-buffer: amp + first-bond amounts. Composed: existing reserve + first join. Do **not** add a Uni-style opening field to Balancer families. |
| **Closed-form exact-out?** | Family curve | D23: implement if the host has `inGivenOut`; else `InvalidRoute`. |
| **Synthetic / expansion numeraire** | Family + existing PRDs | Single synthetic vs per-route / all-legs-rich (Weighted, Quad). |
| **SE passthrough** (no DETF mint/burn) | Family extra | Not required for conformance. |
| **Mature close token set** | Family ∩ D25 | Process is universal (prop withdraw, rejoin DETF to id 0, send rest). Which non-DETF tokens appear in “the rest” is that family’s reserve list. |

Family PRDs that contradict §16.1 (e.g. MixedBuffer “burn buffer only”, MVW “first bond is BPT-only”, Uni V4 mid-based `effectiveBase`, Composed swap-not-burn, claim redeem to rateAsset) are **superseded** on those points.

### 16.3 First-bond non-DETF legs (family)

| Family | Non-DETF legs the first bond must fund |
|--------|----------------------------------------|
| Balancer Single SE | The SE **vault share** |
| Multi-vault weighted | **Every** vault-share leg (not “BPT-only first bond”) |
| Mixed-buffer | **Buffer** + **every** vault-share leg |
| Composed stable | Every non-DETF token the reserve actually lists (family PRD) |
| Uni V4 CP | The **pair** token |
| Uni V4 Orbital | **Both** external pairs |
| Uni V4 Weighted | **Every** configured pair |
| Uni V4 Curve Quad | **All three** external pairs |

Plus the DETF self-leg in every case.

### 16.4 Residual (not a new product fork)

- Wire ceremony for minting ids 0–2 (implementation).  
- Unused `UniV4DetfBondNft` package (delete or ignore; not DualLiquidity).  
- Preview == execute on closed-form routes (existing testing law).  
- Nested DETF-as-SE remains allowed and opaque.  
- Slippage `minOut` on D25 and bond free `U` are **launch-defaulted** in the impl plan (L1, L2). Amend this PRD if product rejects those defaults.

---

## 17. D24 — Free mint/burn bonus vs bond matching `G` (LOCKED)

These are two processes. Do not size one from the other.

### 17.1 Free mint / burn (price)

Purpose: **expand or contract DETF supply** so the reserve price can move.

- **Mint (live):** D8. Bonus on `amountIn`, then the live reserve curve. No new DETF into the pool (D11). Physical capital deposited is unboosted.
- **Burn:** D12 / D13 / D20. Burns DETF. Does **not** use the D8 amountIn bonus unless a later lock says so.

### 17.2 Bond join (depth)

Purpose: **deepen liquidity**, not move the price.

Given the user’s non-DETF capital (one or more legs the family allows):

```
G = unboosted DETF required to join those legs proportionally
    against live reserve balances
```

Mint `G` into the reserve with the user’s capital. Do **not** apply `(1 + p)` to the capital before this quote. Do **not** take D8 `Gross` and treat it as `G`.

First bond, empty pool: family creation / weights / first amounts (D16, §16.2). Still no D8 bonus on `G`.

D4 still applies: additional pot mint `p * G`. `G` is this unboosted matching amount.

Lock-duration bonus remains on `effectiveShares` only (D10). It is not a DETF mint bonus and not part of `G`.

### 17.3 What D24 does not lock

- Whether a bond also mints free `U` to the user’s wallet (§9.2). Live-mint `U = Gross` is D27.

---

## 18. D25 — Mature close: proportional withdraw, rejoin DETF to id 0, send the rest (LOCKED)

Global. Replaces family-specific single-sided mature close (shipped Single SE `tokenOut`, Orbital consolidate-to-capital, MixedBuffer buffer-only, and any D20-shaped close). **Overrides** any earlier D25 text that burned the withdrawn DETF.

Sell-to-claim (D10) is unchanged and remains a **different** mature path: transfer `originalShares` to id 0, mint claim shares. No LP withdraw.

### 18.1 Process (id ≥ 3, mature)

1. **Realize pending expansion** (D31). Then `claimRewards` on that NFT so the bonder receives **their `effectiveShares` slice** of that expansion (and any other pending) as free DETF. Do not destroy it with the retire.
2. `lp = convertToAssets(originalShares)` (ERC-4626, D10 / N10). Input is originalShares, not effectiveShares.
3. Through the NFT (D13): **proportional** withdraw of `lp` from the reserve. Every reserve leg comes out, including the DETF self-leg.
4. **Rejoin** the DETF that came out of that withdraw as the self-leg. Credit **originalShares to id 0** (`addToDETFNFT`, 1×). Do **not** burn that DETF. Do **not** send it to the user. Owner `depositSingle` at hook `MINIMUM_LIQUIDITY` is allowed and **must mint lpOut > 0**. D2 then runs.
5. Send **every remaining withdrawn token** (all non-DETF legs) to the user. **Basket.** Do not consolidate to a single `tokenOut` / buffer. Balancer family close text that swaps leftover legs into one settlement asset is **superseded**.
6. Retire the NFT (burn that id’s `originalShares` / `effectiveShares`).

Ids 1 and 2 cannot take this path (D17). Close is not Policy mint/burn gated.

### 18.2 What the user receives

Free DETF from step 1 (`claimRewards`, including their expansion share) **plus** the basket of non-DETF tokens from the proportional exit. Which non-DETF tokens exist is family-owned (§16.2). The process is not. The protocol keeps the DETF self-leg on id 0.

Do not:

- Quote D8 or D20 on this path.
- Rejoin non-DETF and pay a single `tokenOut` (that is liquid burn / old close).
- Burn withdrawn DETF or leave it in the diamond, the NFT, or the user’s wallet.

Slippage: launch default L2 (`minAmountsOut` array, DETF slot **must be 0**). Preview must match execute.

---

## 19. D26 — `creator` on every family `PkgArgs` (LOCKED)

Every true DETF family’s deploy `PkgArgs` (the interface struct, not a hidden repo field) includes:

```
address creator;
```

Wire mints token id **2** to `creator` when nonzero. If `creator == address(0)`, D21: mint id 2 to `feeTo()`.

Shipped Balancer and Uni V4 family `PkgArgs` that omit this field are **out of spec**. Add it on every in-scope family, including Single SE, MVW, mixed-buffer, composed stable, and all Uni V4 families.

Creator address is **not** an oracle value (D5). `c` (weight) is oracle; recipient is this field.

---

## 20. D28 — `feeTo` / creator claim tests (LOCKED)

Required on **every** in-scope family. Production-first gold TestBase. No mock of the DETF, bond NFT, fee oracle, manager, or registry. Do not treat Composed’s existing “fee NFT claimed > 0” smoke as this suite.

**Due amount** for a token id after a pot increment `Δ` that landed while that id held `E` effective shares and total effective was `T`:

```
due = floor(Δ * E / T)
```

Same `rewardPerShares` / `userRewardPerSharePaid` ledger as other bonds:

```
pending = floor(E * (rewardPerShares - paid) / 1e18)
```

D2 top-ups add **effective shares only** on ids 1 and 2. New shares must **not** inherit historical `rewardPerShares` as claimable (first stake: `paid = current rps`; add-to-stake: preserve prior pending only, do not invent extra).

### 20.1 Ship-gate matrix

| ID | Must prove |
|----|------------|
| **FC1** | After a live mint (D3 pot) and/or a bond (D4 pot) and/or expansion, `ownerOf(1)` can `claimRewards(1)` and `ownerOf(2)` can `claimRewards(2)`. Claimed DETF > 0 when `Δ > 0` and `E > 0`. |
| **FC2** | `claimRewards(id) == pendingRewards(id)` immediately before the call (exact). Balance delta of the recipient equals the return value. |
| **FC3** | After one closed pot deposit `Δ` and **no** intervening D2 top-up, `claimed(1) + claimed(2) + Σ claimed(user ids) + pending(0)` equals `Δ` within **one wei per position** (floor). Id 1’s take is `floor(Δ * F / T)`, id 2’s is `floor(Δ * C / T)`. |
| **FC4** | After D2 adds shares to ids 1 and 2, those **new** shares do **not** raise pending on **old** pot. Snapshot `pending` before the top-up; after top-up (and before a new pot mint) pending is unchanged except documented 1-wei rebase dust. |
| **FC5** | After that top-up, a **new** pot deposit `Δ2` is split at the **new** weights. Id 1 cannot collect more than `floor(Δ2 * F' / T')` from `Δ2` plus its preserved old pending. Same for id 2 with `C'`. |
| **FC6** | Second `claimRewards` on the same id with no new pot returns **0**. No second DETF transfer. |
| **FC7** | Non-owner of id 1 / id 2 reverts (`NotBondHolder` or family equivalent). Cannot claim another id’s rewards (feeTo cannot claim id 2 when owners differ; neither can claim a user id). |
| **FC8** | Ids 1 and 2 still cannot `sellPositionToDetfNft` or `closeBondMature`. Those paths are not a leak around the share cap. |
| **FC9** | D2 top-up does **not** mint `originalShares` on ids 1 or 2. `convertToAssets` / redeemable LP on those ids stays 0. |
| **FC10** | D19: after oracle `feeTo()` changes, the **original** owner of id 1 still claims; the new `feeTo()` cannot `claimRewards(1)`. |
| **FC11** | `creator == 0` (D21): `feeTo` owns ids 1 and 2. Claiming both pays `due(1) + due(2)` (`f + c` of `T`), not `2 * due(1)` and not the whole pot. |
| **FC12** | Conservation across two pot waves and two D2 top-ups: sum of all successful `claimRewards` (ids 0, 1, 2, ≥3) never exceeds total DETF minted into the pot. Floor dust only. |

`assertGt(claimed, 0)` alone **fails** FC3–FC6 and FC11–FC12.

### 20.2 Test files (plan)

Per family: `<Family>_Alignment_FeeCreatorClaim.t.sol` with `test_FC1_` … `test_FC12_`. Helpers on the family TestBase. See the impl plan Stage C/D/F.

---

## 21. D29 — Reserve donation (LOCKED)

Joinable capital (`pairToken` / buffer / rateAsset, `vaultShare`, family mint/bond tokens, **DETF**, or already-minted reserve LP) may be pushed into a **live** DETF without minting DETF. Physical reserve LP on the NFT rises. New 4626 `originalShares` are minted **only to token id 0** at the current conversion rate (N10). User-bond `convertToAssets` stays flat. Ids 1 and 2 still have zero redeemable LP; D2 tops up their **effectiveShares** because id 0 changed `O`.

Donate(DETF) is a self-leg join of **existing** DETF (no burn, no claim mint). That is `buyClaim` without paying the donor in claim tokens.

**Public function lives on the Bond NFT** (`detf/common/bondNft`), because that vault already holds the LP (D13). **Host join stays on the DETF diamond** (`onlyBondNft`). Uni V4 hooks remain owner-only add/remove (D9); the NFT must not call `depositSingle`. `IDetf.donate` is a FeeCollector forwarder onto the NFT (`minLpOut = 0`; pretransfer destination is the NFT; event donor is the collector).

Donate is not a bond, not live mint (D11 still unassigned LP + free DETF to the caller), not protocol compound, and not expansion realize. Full process, family join table, conversion rule (N10), and ship-gate tests: [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md).

Do **not** treat idle ERC-20 on the DETF diamond or a raw `vaultShare` transfer to the hook as donate.

---

## 22. D30 — Owner host ops while PoolManager / Vault is locked (LOCKED)

Normative detail is §11.3. Summary:

- DETF is the Uni V4 reserve-hook owner. Public swaps stay public. Add/remove LP stays owner-only when `ownerOnlyLiquidity` is on (D9).
- D15 must **buy DETF** on the residual book after a proportional LP withdraw. D29 must `depositSingle` in the same class of transaction. Uniswap SwapRouter / a nested `PoolManager.unlock` will fail if the manager is already unlocked.
- Every Uni V4 DETF-reserve hook (CP, Orbital, Weighted, Curve Quad buffer) exposes **owner-only** exact-in/exact-out swap and LP add/remove that settle on the **current** unlock or via internal book settlement (zap-internal class). Non-owner cannot use that path.
- Balancer analog: swap/join/exit inside an already-open Vault unlock, not a nested Router call.

Owner `depositSingle` / `deposit` when hook `totalSupply == MINIMUM_LIQUIDITY`: **allowed for the owner only**. Same zap math as a live zap (impact against dust accepted). **lpOut must be > 0** or revert. Public zaps still revert at MIN (hook D79). This is how D25 DETF rejoin and D15 leftover rejoin stay LP on the NFT.

Family hook PRDs must carry this lock. Co-located starting point: [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](../../hooks/uniswap/v4/standardExchange/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md) D88–D89.

---

## 23. D31 — Realize expansion, then gate (LOCKED)

Cross-cut of the compound/expansion PRD. **Mint/burn quote, split, D11 join, D13 burn sizing, Policy vs Open inequalities, and pot rewards do not change.** What changes is **when** expansion is minted relative to the gate.

| Path | Realize expansion first? | Then Policy mint/burn gate? |
|------|--------------------------|------------------------------|
| Live mint | **Yes** | **Yes** (post-realize synthetic) |
| Live burn | **Yes** | **Yes** (post-realize synthetic) |
| `redeemClaim` | **Yes** | **No** (D22) |
| `closeBondMature` | **Yes** | **No** |
| Bond | **Yes** (already) | **No** |
| Donate | **No** | **No** |
| Open mode | Realize is a no-op | Mint/burn gates always pass when live |

Execute order on live mint/burn:

1. Require live.
2. Realize pending expansion (mint DETF to the Bond NFT; `rewardPerShares` updates). Open: skip.
3. Compute synthetic from **minted** `totalSupply` (pending expansion is now 0).
4. Policy: mint iff `synthetic > mintThreshold`; burn iff `synthetic < burnThreshold`. Fail → **revert the whole tx**, including the expansion mint. That can block the mint/burn that triggered realize. **Desired** (stops overshooting the band).
5. Proceed with the existing mint or burn process.

Views: `isMintingAllowed` / `isBurningAllowed` count pending expansion in the denominator so they equal step 3 without minting in the view.

Close: after realize, `claimRewards` on that user NFT pays **that bonder’s** expansion (and other pending) as free DETF, then the LP unwind.

Redeem: after realize, harvest **all** id 0 pending (includes id 0’s expansion slice) toward `owed`. Other bonders keep expansion on their own pending.

---

## 12. Non-goals (until explicitly unlocked)

- Implementing any topic before it is locked in §0 and listed in the impl plan.
- Converting DualLiquidity into a true DETF.
- Changing compound / expansion Phase 1–2 law except where a later lock here forces a cross-reference.
- Deleting unused `UniV4DetfBondNft` (decide separately).

---

## 13. How this file grows

1. Discuss one topic.
2. Write the decision into §0 with an ID and date.
3. Expand the matching section with normative text.
4. Only then open an implementation-and-test plan.

§9.2 (bond free `U`) stays open as product; the impl plan uses launch default L1 until this PRD changes it. §16 is the universal vs family index. D25 (rejoin DETF to id 0, basket), D15 (zap-out buy), D29 (id 0 originalShares), D30 (owner-during-lock), and D31 (expansion then gate) override earlier rows dated before 2026-08-22. Execute [`DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md) Stages **I–O**.
