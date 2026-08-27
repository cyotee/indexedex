# Product Requirements Document (PRD)

## Title

**DETF instance I/O routing** — deploy-time mint, burn, bond, close, and donate route tables; Uni V4 hook quote + ABI unification (§15)

## Status

**DRAFT v0.16** — 2026-08-26. Uni V4 **v1 law** is **§16**. Implementation kickoff: [`DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md) (`/goal`). Stages: [`DETF_INSTANCE_IO_ROUTING_PROGRAM.md`](./DETF_INSTANCE_IO_ROUTING_PROGRAM.md). Do not spawn subagents against this PRD as if it were a slice map.

| Field | Value |
|-------|--------|
| **Status** | **DRAFT v0.16** — 2026-08-26. v1 Uni V4 locked in §16. Dust sweep **R19**. **R20** pons v2 graduated pool as Uni V4 SE fixture. |
| **Home** | `contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md` |
| **Scope** | (1) Proposed **universal** I/O routing law for every true DETF under `contracts/vaults/detf/protocols/dexes/**`. (2) **v1 implement:** Uni V4 **SE buffer hook** reserve DETF (one DFPkg) + §15.12 hooks (CP single, Orbital, Weighted, Curve Quad, Dual SE CP ABI-only). **Not** Balancer-hosted DETFs. |
| **Depends on** | [`DETF_ALIGNMENT_PRD.md`](./DETF_ALIGNMENT_PRD.md) D9, D11, D12, D13, D15, D16, D18, D22, D23, D25, D29, D30, D31; [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md); agent law token policy, opacity, unowned instances, **pricing engine = reserve host** |
| **If accepted** | Alignment `D*` row pointing here. Edit **D20**, **D25 remainder** (Default basket; Custom close is **exactly one** hook pair token + leftover swaps), **§16.2**, donation **N6/N7 seating**. **Do not** edit common `DETFNFTVault` donate booking (N4/N11 stay for Balancer). Uni V4 family PRDs superseded by the one DETF DFPkg + §15.12 hook ABI. |
| **Not this file** | Protocol compound and natural expansion **formulas** (already LOCKED). ThresholdMode Policy/Open **encoding**. Balancer family **curves**. A Morpho/Euler **loop vault** (later DETF package). Claiming anything except DETF (D15/D18/D22 stay). |
| **Packages (v1)** | DETF: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` (`IUniswapV4Detf`, `UniswapV4DetfDFPkg`). Bond NFT: `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/` (R12a). Hooks stay in existing CP / orbital / weighted / quad trees. |
| **Impl / test plan** | [`DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md) (`/goal`). Stages 00–09: [`DETF_INSTANCE_IO_ROUTING_PROGRAM.md`](./DETF_INSTANCE_IO_ROUTING_PROGRAM.md). |

**Short name:** instance I/O routing (+ Uni V4 host quote).

---

## Living progress log

| Date | Note |
|------|------|
| 2026-08-26 | v0.16: **R20** required tests: wrap a **pons v2** graduated Uniswap V4 pool (Crane `TestBase_PonsFamilyV2`, meme hook, fee 0) as a Uni V4 SE vault `PoolKey`, then use that vault as a bound SE on the unified DETF. Not optional. IndexedEx `test/` has no pons coverage today. |
| 2026-08-26 | v0.15: **R19** diamond dust. DETF must not hold joinable inventory at rest. Sweep joins into the reserve; LP to Bond NFT; **no** originalShares mint to any bond id (unassigned LP, same booking as R12a). Public `sweepDust` + end of money paths, best-effort, after `isReserveLive` only. `/goal` impl plan file added. |
| 2026-08-26 | v0.14: Shared ABI paths `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol` + `IDetfReserveQuote.sol`. `firstJoinMustBeFullBook() = true` on CP, Orbital, Weighted, Quad, Dual; `requiredFirstBondTokens()` = full `tokens()` list (Dual: both pairs); `joinSingleAssetExactIn` reverts until `isLive()`. Impl program: numbered stages, CP hook pathfinder, then DETF; other hooks parallel after 00. |
| 2026-08-26 | v0.13: Hook and DETF store pair tokens and bound Standard Exchanges in Crane `AddressSet` (`AddressSetRepo._contains` / `_add`). Hook classifies a join/swap address as DETF self-leg, pair, or SE vault (share), then looks up the other via `standardExchangeOf` / `pairOfStandardExchange`. No runtime scan of `tokens()` for membership. Do not use OpenZeppelin `EnumerableSet`. |
| 2026-08-26 | v0.12: Review locks. Custom `IoRoute.vault` ⊆ hook-configured SEs; token may be share or that SE's `tokens()`, not only the hook pair. Mint Gross = convert to that vault's hook pair, then `previewSwapExactIn(pair, detf, pairEq*(1+p))`. R12a = **new** Uni V4 Bond NFT package (do not edit common `DETFNFTVault`). Custom close = **exactly one** `hook.tokens()` pair; leftovers `ownerSwapExactIn` in `tokens()` order. Hook DFPkg first; DETF `PkgArgs` has `hook` and reads lists from the hook. `joinUnbalanced(address[] tokens, uint256[] amounts)`. DETF user ABI exact-in only. Paths: `uniswap/v4/detf/` + `uniswap/v4/bondNft/`. Morpho looping = later package. |
| 2026-08-26 | v0.11: v1 = Uni V4 hooks §15.12 + **one** DETF DFPkg. Seating = **SE then hook join shares**. No DETF passthrough. Custom close length 0 **rejected**. Morpho-illiquid close = later package. Balancer I/O tables = later. Implementor checklist §16. |
| 2026-08-26 | v0.10: Unified Uni V4 DETF close = D25 non-DETF basket. Default mint/burn/bond tokens = hook pairs + bound SE **shares** only (not SE `vaultTokens()` underlyings). Donate Default = mint ∪ bond. Dual SE CP implements §15.12, no DETF bind. One fee view: `tradingFeeWad()`. |
| 2026-08-26 | v0.8: H2 return 0 on unquotable views. Public swap ABI = preview + ownerSwap only (no hook `swapExact*`). H7 = one Uni V4 DETF DFPkg. Bond G sizing still needs a plain-language lock. |
| 2026-08-26 | v0.7: §15.12 full standardized hook interface set. No legacy deposit/withdraw/addLiquidity/flexible/Permit2 hook fns. All Uni V4 SE buffer hooks implement this set only (plus ERC-20 LP). |
| 2026-08-26 | v0.6: Join/exit ABI locked (§15.11). Names: joinUnbalanced / exitProportional / joinSingleAssetExactIn. No depositSingle alias. Amount arrays in `tokens()` order. B6 flexible not on DETF-required ABI. |
| 2026-08-26 | v0.5: Locked quote ABI picks (§15.10): hook returns finished synthetic (ctx from DETF); mint = swap quote; dedicated burn preview; owned LP = Bond NFT only (diamond/claim LP is a bug); DETF applies `p` then calls hook. |
| 2026-08-26 | v0.4: §15 Uni V4 hook quote interface + standardized hook ABI. Balancer DETFs out of this redesign. DETF passes accounting args; hook runs curve math. Open questions H1–H18. |
| 2026-08-26 | v0.3: tentative per-family change orders (§14). Shared NFT donate booking; Weighted is the Morpho/TT host; Single SE already zaps; MixedBuffer burn is already D20-wide; Quad close already one-token (tension with D25 basket). |
| 2026-08-26 | v0.2: split donate **seating** (route tables) from donate **4626 booking**. Proposed booking: extra LP is unassigned when `totalOriginalShares > 0` (NAV up for every originalShares holder, not minted to id 0). Reopens D29/N4/N11. |
| 2026-08-26 | v0.1 from design discussion: instance route tables (mint, burn, bond-in, close, donate); deploy-time only; first bond still all legs; claim DETF-only; donate must not override the I/O strategy. |

---

## 0. Intent

Shipped families hard-code who may mint, who may burn, and which Standard Exchange leg seats the capital. Mixed-buffer burns **buffer only**. Multi-vault weighted mints and burns **vault shares only**. Agent law treats rate-asset mint on the DETF as out of scope unless a family documents a zap. Alignment §16.2 leaves the mint `tokenIn` list in family PRDs. Donation **N6** accepts family live-mint / bond capital **and** each SE vault’s `tokens()`.

That means an instance cannot say:

- live mint accepts only token `X`, and seats it in SE vault `Y`;
- live burn pays only token `W`, taken from SE vault `Z`;
- later bonds accept listed payment tokens, each mapped to one SE vault;
- public donate cannot fatten a leg the deployer kept off those doors.

The management strategy **is** those doors. A deployer who wants a Uni V4 TT/ETH vault as the only seigniorage rail, and a Morpho WETH vault only as bond capital, cannot express that today. Donate of Morpho `loanToken` or Morpho vault shares would still seat the Morpho leg (N6). Live burn of DETF can still pay any reserve token (D20). Mature close still sends the full non-DETF basket (D25).

This PRD makes **I/O policy instance data**, frozen in `PkgArgs` at deploy, stored on the diamond, unowned after `postDeploy`. Families remain the **reserve host and math**. They stop being the only place the mint/burn token set lives.

### 0.1 Goals

1. One product law: every true DETF instance has deploy-time **route tables** for live mint, live burn, post-live bond inbound, mature close outbound, and donate inbound.
2. Each capital route is `{ token, vault }`: the ERC-20 the caller pays or receives, and the configured SE leg that **processes** it (`IStandardExchange` in/out, then reserve join/exit of **vault shares**).
3. Mint table and burn table are **independent**. Bond-in is a third table. Close-out is a fourth. Donate is a fifth that **cannot open a door the other inbound tables did not open**.
4. Rebasing claim stays DETF-only: `buyClaim` / redeem claim are DETF ↔ claim. Claim token is not a mint, burn, bond, close, or donate capital token.
5. First bond still funds **every** non-DETF reserve leg plus the DETF self-leg (D16). Route tables apply **after** `isReserveLive`.
6. Instances stay immutable and unowned. Tables are `PkgArgs` → `processArgs` resolve → storage. No post-deploy setter.
7. Opacity: DETF production code still talks only to `IStandardExchange*` / share ERC-20 / reserve host ABI. The table holds addresses and roles, not Morpho or Uni types.
8. Closed-form only. If the mapped vault cannot preview `token ↔ vaultShare` without a solver, the route is illegal at **deploy**.
9. Uni V4 Default tables: hook pairs + bound SE **shares** only (§15.13). Balancer defaults (§10/§14) apply only in the follow-on I/O pass.

### 0.2 Non-goals (v1)

1. Post-deploy mutation of any route table. Wrong tables → abandon the instance.
2. Holder or owner “management” calls that rebalance legs or rewrite doors.
3. Binary-search / approximate exact-out (D23 unchanged).
4. Putting rebasing claim, native ETH, or fee-on-transfer tokens on any table. Token policy still forbids FoT and rebasing **underlyings** even if listed; listing does not create an exception.
5. A `PkgArgs` allowlist of token *classes* (the locked token-policy rule). These tables are **routes**, not a weird-token allowlist.
6. Collapsing **Balancer** DETF families in v1. Uni V4 CP/Orbital/Weighted/Quad DETF packages **do** collapse to one DFPkg (H7). Balancer packages stay until a follow-on I/O-table pass.
7. Balancer I/O route tables in v1 (deferred). Uni V4 `IoRoute.vault` is always an `IStandardExchange` (SE first, then hook join of shares).
8. Implementing a Morpho (or Euler) leverage loop inside the DETF. Nested SE vaults may loop; this file only says which tokens hit which vault.
9. Changing protocol compound (DETF self-leg join only) or natural expansion.
10. Closing the Balancer V3 **public pool join** hole (alignment D9 exception). Outsiders can still mint reserve BPT on Balancer without these tables. That residual is documented, not solved here.
11. Guaranteeing that a listed burn or close route can pay when the mapped vault has no cash (Morpho utilization, Uni V4 lock). `InvalidRoute` vs `InsufficientLiquidity` stays the vault’s error. The table does not create cash.

---

## 1. Decisions (`R*`) — **LOCKED for Uni V4 v1**; Balancer I/O follow-on

IDs are `R*` so they do not collide with alignment `D*` or donation `N*`.

| ID | Topic | Decision |
|----|-------|----------|
| **R1** | Scope | Instance I/O routing is **universal law** for true DETFs. Family PRDs no longer own the mint/burn token set once this file is accepted. Family PRDs still own curve, reserve token list, first-bond quote, and host encoding of a route. |
| **R2** | When | Tables bind at deploy (`PkgArgs` → resolve → storage). After `postDeploy` the instance is unowned. No setter. Getters return **resolved** tables (same pattern as `DETFThresholdPolicy` stored thresholds). |
| **R3** | Route row | `IoRoute { IERC20 token; IStandardExchange vault; }`. `vault` must be one of the instance’s configured SE legs. `token` must be in that vault’s `tokens()` **or** be that vault’s share ERC-20 (`address(vault)` when the diamond is the share). |
| **R4** | Five tables | `mintRoutes`, `burnRoutes`, `bondRoutes`, `closeRoutes`, `donateRoutes`. Mint and burn are **not** required to be inverses. |
| **R5** | Processor | **Uni V4 v1:** see §16. Live mint / donate capital: pull `token`; if not already `vault`’s share: `vault.exchangeIn(token → share)`; then `hook.joinSingleAssetExactIn(share)` (D11: no DETF into the reserve). Live burn: D12; `previewBurnToToken` / `exitProportional` then rejoin DETF (H10/H20). First and later bond: **one** `joinUnbalanced(tokens, amounts)` with G DETF + capital (pair **or** share). Close: §6 / §16.5. Donate: §5. **Vault constraint:** `IoRoute.vault` must be `hook.standardExchangeOf(t)` for some non-DETF `t` in `hook.tokens()`. Token may be that vault’s share or a token in that vault’s `tokens()` (not only the hook pair). Cannot name an SE the hook does not list. R6: one row per token per table. Morpho-loop SEs that are **not** on the hook are a later package. |
| **R6** | One vault per token per table | Duplicate `token` on the same table reverts at `processArgs`, even to two vaults. One TT cannot mean both Uni V4 SE and Morpho SE on mint. |
| **R7** | Empty vs default | Each table has `RouteTableMode { Default = 0, Custom = 1 }`. **Never** infer Custom from a zero-length array (same lesson as ThresholdMode vs zero thresholds). `Default` → `processArgs` writes the **family default** rows into storage. `Custom` mint/burn/bond/donate → the provided array is the law, including **length 0** (that surface is closed after live, except first bond / claim / DETF+`lpToken` donate as in R12). `Custom` **close** is **not** length 0: `closeRoutes.length` must be **exactly 1** (§6 / §16.5). |
| **R8** | Family defaults | Default mint/burn/bond rows are today’s family routes (appendix §10). Default `closeRoutes` = D25 basket (all non-DETF reserve tokens as withdrawn). Default `donateRoutes` = resolved `mintRoutes ∪ bondRoutes` (same `{token, vault}` rows). |
| **R9** | First bond | **Ignores** mint/burn/bond/donate/close tables. Still D16: every non-DETF reserve leg plus DETF self-leg. Ungated. |
| **R10** | Claim | Rebasing claim mint and burn only against **DETF**. Not on any `IoRoute` table. D15/D18/D22 unchanged. |
| **R11** | Forbidden tokens on tables | `address(0)`, native ETH, `detfToken` as a **capital** mint/burn `token` (DETF is the seigniorage output, not a mint `tokenIn`; burn `tokenIn` is DETF by definition, not a burn-route `token`), rebasing claim, FoT. `detfToken` remains a **donate** token (self-leg join, N5) and a `buyClaim` input without sitting on `mintRoutes`. |
| **R12** | Donate vs strategy | Donate **must not** open an inbound door the instance did not already open. See §5.1–§5.4. |
| **R12a** | Donate LP booking | Physical LP from a successful donate join is **unassigned** when `totalOriginalShares > 0`: no new `originalShares` mint. `convertToAssets` of **every** existing originalShares holder rises (id 0 and user bonds id ≥ 3). Ids 1 and 2 still have zero originalShares and do not receive principal. When `totalOriginalShares == 0`, credit id 0 at 1:1 (N14) so the next bond cannot swallow the gift. This **reopens** alignment D29 / donation N4/N11. See §5.5. |
| **R13** | Close vs D25 | D25 **process** stays: proportional withdraw, rejoin withdrawn DETF to id 0, do not burn that DETF. The **remainder token set** is `closeRoutes` when mode is Custom. See §6. |
| **R14** | Closed form | `processArgs` (or an explicit deploy-time probe the TestBase must also run) requires that each row’s vault preview for `token ↔ vaultShare` is a supported SE route. If not: revert deploy. Runtime still `InvalidRoute` for anything not in the resolved table. |
| **R15** | Opacity | No Morpho / Uni / Euler types in DETF production sources. Mapped `vault` is `IStandardExchange`. |
| **R16** | Token policy | Unchanged. A listed token that is FoT or a rebasing underlying is still illegal as `rateAsset` / `pairToken` / configured underlying. Proof remains `test_L2_FoT_forbidden` with a real FoT as the configured token, not a mock SUT. |
| **R17** | Getters | `mintRoutes()`, `burnRoutes()`, `bondRoutes()`, `closeRoutes()`, `donateRoutes()`, plus per-table mode. `acceptedBondTokens()` returns the **token** column of resolved `bondRoutes` (and still whatever D16 required for first-bond views if the family splits that). |
| **R18** | Skew | Single-door mint/burn is accepted. Synthetic, Policy gates, and expansion still see **all** reserve legs. A Morpho leg the public cannot mint or burn can still open or close the mint gate. |
| **R19** | Diamond dust | The DETF diamond **must not** hold joinable inventory at rest (hook `tokens()`, bound SE shares, hook LP). After live, leftover of those assets is **swept into the reserve** when a join can succeed. LP goes to the Bond NFT. **No** `addToDETFNFT` / originalShares mint to id 0, ids 1–2, or user bonds. Unassigned LP (same booking as R12a when `totalOriginalShares > 0`). When `totalOriginalShares == 0`, credit id 0 at 1:1 (N14) so the next bond cannot swallow the LP. Not a donate of a caller’s tokens: this is residual already on the diamond. Unknown / non-joinable ERC-20s are left (do not swap airdrops into the pool). See §16.10. |
| **R20** | pons v2 pool fixture | Uni V4 SE vaults **must** be proven against a **pons v2 graduated** Uniswap V4 pool, not only a hookless or IndexedEx-hook pool. Product path: Crane `lib/crane/contracts/protocols/launchpads/ponsFamily/v2` + hermetic `TestBase_PonsFamilyV2`. SE `PkgArgs.poolKey` is that graduated pool (meme hook, `fee == 0`). The unified DETF then uses that SE as a bound `IStandardExchange`. See §16.11. **Not present in IndexedEx `test/` today.** |

---

## 2. Why tables, not family if/else

The product is: **the deployer names the management strategy**. That strategy is which tokens may enter, which tokens may leave, and which SE vault executes each move.

Doing that only in a new family would require a family per strategy. Doing it as a boolean “TT-only” on Weighted DETF would not generalize (bond WETH into Morpho, burn TT from Uni V4, donate TT only). Five tables cover:

| Table | Question |
|-------|----------|
| `mintRoutes` | What may create free DETF after live, and which vault seats it? |
| `burnRoutes` | What does burning free DETF pay, and which vault is exited? |
| `bondRoutes` | What may pay a **later** bond, and which vault seats it? |
| `closeRoutes` | What may a mature bonder take home after D25 rejoin of DETF? |
| `donateRoutes` | What may be donated into the reserve without minting DETF, and which vault seats it? Booking is §5.5, not this table. |

Protocol compound is not a sixth table. It remains DETF self-leg join.

---

## 3. Deploy encoding

### 3.1 Who configures

The **deployer** of that instance, via `PkgArgs`. Not DETF holders. Not an operator. Not the fee oracle.

Anyone can deploy another instance with different tables (registry / manager DFPkg path). That is the only “user configuration.”

### 3.2 `PkgArgs` fields (logical)

**Uni V4 v1 (normative).** Interface: `IUniswapV4Detf`. Hook DFPkg deploys first. DETF `PkgArgs` does **not** repeat pair tokens, weights, amp, or Standard Exchange lists. Those are read from the hook.

Hook DFPkg must be given the CREATE3-predicted DETF address as (1) the DETF reserve currency in `tokens()` and (2) hook owner (D9). DETF `processArgs` does **not** transfer hook ownership.

```solidity
enum RouteTableMode { Default, Custom } // 0 = Default. Never infer Custom from empty arrays.

struct IoRoute {
    IERC20 token;
    IStandardExchange vault;
}

struct PkgArgs {
    string name;
    string symbol;
    address hook; // already deployed §15.12 hook
    uint256[] creationPairPerDetfWad; // length = hook.tokens().length - 1; hook.tokens() order skipping DETF; each > 0
    uint256[] openingPairPerDetfWad;  // empty → all creation; else same length; 0 in a slot → that slot's creation
    uint256 mintThreshold;            // 0 → 1.05e18
    uint256 burnThreshold;            // 0 → 0.95e18
    ThresholdMode thresholdMode;      // 0 = Policy
    uint256 expansionEpochLength;     // 0 → 8 hours
    uint256 expansionClosureRatePerYearWad; // 0 → 0.10e18
    uint256 expansionMaxCatchUpEpochs;      // 0 = unlimited
    address creator;                  // D26; 0 → feeTo owns id 2
    string claimName;
    string claimSymbol;
    string bondName;
    string bondSymbol;
    RouteTableMode mintRouteMode;
    IoRoute[] mintRoutes;   // ignored unless Custom
    RouteTableMode burnRouteMode;
    IoRoute[] burnRoutes;
    RouteTableMode bondRouteMode;
    IoRoute[] bondRoutes;
    RouteTableMode closeRouteMode;
    IoRoute[] closeRoutes;
    RouteTableMode donateRouteMode;
    IoRoute[] donateRoutes;
}
```

`RouteTableMode` is stored on the instance. Omitted / zero mode is **Default**, never Custom.

### 3.3 `processArgs` validation (normative)

**Hook (Uni V4 v1), before tables:**

1. `hook != address(0)` and `hook.code.length > 0`.
2. `hook.tokens()` length `n ∈ [2, 8]`. `address(this)` appears in `tokens()` **exactly once** (Dual SE CP has no this-DETF leg → revert).
3. For every non-DETF `t` in `tokens()`: `standardExchangeOf(t) != address(0)` (bare pair cannot bind).
4. Hook owner is this DETF (already set at hook deploy). Else revert. No ownership transfer in DETF `postDeploy`.
5. `creationPairPerDetfWad.length == n - 1`. Each element `> 0`. Indexed in `tokens()` order skipping DETF.
6. `openingPairPerDetfWad` empty or length `n - 1`. Empty → copy creation. Per-slot `0` → that slot’s creation. Store the resolved array.
7. ThresholdMode / threshold resolve: existing `DETFThresholdPolicy` (zero mode = Policy; zero thresholds → 1.05e18 / 0.95e18; `mintThreshold > burnThreshold`).
8. Expansion zeros resolve via existing epoch lib. Store resolved.

**For each table** that is Custom, and for Default tables after expansion to §15.13 rows:

1. `vault != address(0)` and `hookStandardExchanges._contains(vault)` (Crane `AddressSetRepo`, §16.9). Equivalent to `vault == hook.standardExchangeOf(t)` for some non-DETF `t`. No SE the hook does not list. Do not walk `hook.tokens()` to prove this.
2. `token != address(0)`.
3. `token` is `address(vault)` (share) **or** is in that vault’s `tokens()` / `vaultTokens()`.
4. No duplicate `token` in that table.
5. R11 forbidden tokens (`address(0)`, native ETH, DETF as mint/burn capital token, rebasing claim, FoT as configured token — FoT proof is the L2 test, not a `processArgs` allowlist).
6. Custom `donateRoutes`: every row’s `{token, vault}` is **equal** to a row in the **resolved** `mintRoutes` or **resolved** `bondRoutes`. Donate cannot introduce a new token or a different vault for a token already mapped inbound. See §5 for DETF and `lpToken`, which are not donate-table rows.
7. Custom `closeRoutes`: **length == 1**. `token` is a non-DETF entry of `hook.tokens()`. `vault == hook.standardExchangeOf(token)`. Not DETF, not a share, not an SE underlying missing from `hook.tokens()`.
8. If Custom mint or burn or bond or donate has length 0, that live surface is closed. First bond still works. Claim still works. Custom close length 0 **reverts** (rule 7).
9. Closed-form: each mint/burn/bond/donate row must be a supported `IStandardExchange` route for that vault (share ↔ `token` if `token` is not the share). Probe: `previewExchangeIn` / `previewExchangeOut` (or share identity). Deploy reverts if the preview reverts or is not a supported route. Close Custom row does not require an SE preview (settlement is hook swaps).

### 3.4 Runtime

Anything not in the resolved table for that operation: `InvalidRoute(tokenIn, tokenOut)` **only**. Do not emit `UnsupportedRoute`. Do not fall back to “any vault share” or “any SE `tokens()`”.

Preview and execution share one quote path (existing testing law).

---

## 4. Surfaces after live

### 4.1 Live mint (D8, D11)

`tokenIn` must appear on `mintRoutes`. Processor = that row’s `vault`. `tokenOut` is DETF.

Seat: if `tokenIn` is already `vaultShare`, join shares. Else `vault.exchangeIn(tokenIn → vaultShare)`, then join shares. No DETF minted into the reserve (D11).

### 4.2 Live burn (D12, D8)

`tokenIn` is DETF. `tokenOut` must appear on `burnRoutes`. Processor = that row’s `vault`.

Exit that vault’s share from the reserve (single-sided), then `exchangeOut` to `tokenOut` if needed. DETF is burned.

If the mapped vault cannot pay (`InsufficientLiquidity`, utilization, host lock), the burn **reverts**. It does not try another vault.

### 4.3 Later bonds

`tokenIn` must appear on `bondRoutes`. Processor = that row’s `vault`. Bond matching DETF `G` is **pool-mix** (H6), not a swap. Live book: if reserves are 2 DETF per 1 hook pair, 10 pair-equivalent → G = 20 DETF. Empty book (should not occur after first bond except MIN dust): `openingPairPerDetfWad` for that pair (0 → `creationPairPerDetfWad`); `G = pairEq * 1e18 / opening`. First bond: R9 / §16.4. Execution is **one** `joinUnbalanced` (§16.4), never `joinSingleAssetExactIn`.

`acceptedBondTokens()` after live is the token column of resolved `bondRoutes`. Uni V4 v1 Default does **not** include hook LP (Q13).

### 4.4 Not on these tables

| Path | Law |
|------|-----|
| DETF ↔ rebasing claim | D15 / D18 / D22 |
| Protocol `compoundProtocolRewards` | DETF self-leg only |
| Natural expansion | Reward ledger; not I/O routing |
| `vaultShare_i ↔ vaultShare_j` on the DETF | Still out of scope; use the reserve host / SE router |

---

## 5. Donate must not override the strategy

Two different questions:

1. **Seating (this PRD’s tables):** which tokens may be donated, and which SE vault processes them.
2. **Booking (4626):** after that LP sits on the Bond NFT, who owns the extra principal.

`donateRoutes` only answers (1). It is not a “gift to token id 0” map.

Donation **process** (public surface, `onlyBondNft` join, no DETF mint, live only, no expansion realize) stays [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md) except **N4, N6, N7 seating vault, N11** as revised below.

**This file replaces donation N6 token set** (when accepted). **This file proposes to replace N4/N11 booking** (§5.5).

### 5.1 Allowed donate tokens

| Token | Allowed? | Processor |
|-------|----------|-----------|
| Row on resolved `donateRoutes` | Yes | That row’s `vault` (same seating as mint/bond for that pair) |
| DETF (`address(this)`) | Yes, always | Self-leg join (N5/N7). Not a way to seat an SE vault. |
| Reserve `lpToken` | Yes, always | Pull inbound LP delta only (N15). Does not pick an SE vault. Booking is §5.5. |
| Anything else | **No.** `InvalidRoute`. | |

`donateRoutes` Custom cannot list DETF or `lpToken` (R11 / this table). Those two stay implicit so FeeCollector and keepers can still gift DETF or already-minted LP without copying family defaults.

### 5.2 `donateRoutes` subset rule (R12)

Resolved `donateRoutes` ⊆ resolved `mintRoutes` ∪ resolved `bondRoutes` as **set of `{token, vault}` pairs**.

Consequences:

- If mint is TT → Uni V4 SE and bond is WETH → Morpho SE, Default donate allows **both** (R8). The deployer who does not want Morpho fattened without a lock sets `donateRouteMode = Custom` with only TT → Uni V4 SE, or with length 0.
- Custom donate **cannot** map TT → Morpho SE if mint/bond mapped TT → Uni V4 SE.
- Custom donate **cannot** accept Morpho vault shares if neither mint nor bond lists that share (or that vault’s `loanToken` as the paired token for that vault).
- Length-0 Custom donate: only DETF self-leg and `lpToken`. No SE capital donate.

That is the “do not override management” rule: donate cannot invent a new inbound rail, and cannot retarget a token at a different vault.

### 5.3 What donate still may do

Single-sided seating still skews weights (donation N2 non-goal). Richer backing can still open a Policy mint gate (donation N10 non-goal). Those are not overrides of **which vault** is used.

### 5.4 Residual: Balancer public join

Alignment D9 still allows public Balancer joins. A third party can mint reserve BPT and transfer it. Calling `donate(lpToken)` then books **this-call inbound LP delta** (N15). That does not call `exchangeIn` on an SE vault; it is existing pool LP. This PRD does not close D9. Uni V4 owner-only LP (D9) does not have that hole.

### 5.5 LP booking: unassigned vs id 0 (proposed revision of D29)

**What alignment D29 and donation N4/N11 say today (locked 2026-08-22):** after the join, mint new `originalShares` to **token id 0** at `convertToShares(ΔL)`. User-bond `convertToAssets` stays **flat**. Id 0’s share count rises. Claim (4626 on id 0) captures the gift. Donation non-goal 8 forbids giving donated LP to user bonds. Alignment §15.3 groups donate with `buyClaim`, protocol compound, and D25 DETF rejoin as **id 0 mints**. It explicitly distinguishes that from **D11 live mint**, which joins LP **without** new originalShares so existing bonds’ NAV **changes**.

That is a real product choice, not a wording slip in this routing PRD. It is also **not** “apportion extra reserve LP across all bond principal.”

**What this draft wants instead (R12a):** donate is a gift to **the reserve book the bonds already own**.

| `totalOriginalShares` | Booking |
|-----------------------|---------|
| `> 0` | Join LP onto the NFT. **Do not** `addToDETFNFT`. Same unassigned-LP rule as D11’s capital join, but **no** DETF minted to the donor. Every existing originalShares holder’s `convertToAssets` rises in proportion to their originalShares: **id 0 and user bonds (id ≥ 3)**. |
| `== 0` | Credit id 0 at 1:1 for ΔL (keep N14). Otherwise the next bond can swallow the gift via D10’s empty-share branch. |

Ids **1** and **2** still have zero originalShares (D17). They do not receive donated principal under either booking. They only `claimRewards`.

**Who this subsidizes:** FeeCollector / hook `feeTo` / keeper donate of TT then raises **bonder principal** and id 0 together, not claim-only. Claim still improves because id 0’s assets rise, but id 0 no longer captures 100% of ΔL.

**D13 burn** still sizes `lpOut = detfIn * nftLp / detfSupply` against **all** physical NFT LP, including unassigned donate LP. Free DETF burn dilutes every originalShares holder. Same as D11 unassigned mint capital. Accepted.

**R12a is locked.** Do not ship D29 id-0 mint for donate.

---

## 6. Mature close (D25 remainder)

D25 process steps 1–4 and 6 are unchanged: realize expansion and `claimRewards`; proportional reserve withdraw for `convertToAssets(originalShares)`; rejoin withdrawn **DETF** to the reserve; credit those originalShares to id 0; **do not burn** that DETF; retire the NFT. Close is not Policy mint/burn gated.

Slippage: launch default L2. Default close: `minAmountsOut.length == hook.tokens().length`; the DETF index **must be 0**. Custom close: `minAmountsOut.length == 1` (the settlement token). Whole transaction reverts if `exitProportional`, DETF rejoin, a leftover swap, or `minOut` fails.

### 6.1 Default close

`closeRouteMode = Default`: pay the user every **non-DETF** `hook.tokens()` amount from that withdraw (and SE shares if those came out). **No swaps.** `previewCloseBondMature` / `closeBondMature` return `amountsOut` in `hook.tokens()` order (DETF slot 0).

### 6.2 Custom close (Uni V4 v1)

`closeRoutes.length` must be **exactly 1** (`processArgs` reverts otherwise). That token is one non-DETF address from `hook.tokens()`. `vault == hook.standardExchangeOf(token)`. Not DETF, not a share, not an SE underlying absent from `hook.tokens()`.

After the proportional withdraw and DETF rejoin:

1. Let `closeToken` be that one token. The withdrawn amount of `closeToken` is already payable.
2. Walk `hook.tokens()` from index 0 to `n-1`. Skip the DETF self-leg. Skip `closeToken`. For every other token with withdrawn amount `> 0`, call `hook.ownerSwapExactIn(leftoverToken, closeToken, amount, minOut=0, deadline)`. No Standard Exchange `exchangeOut` on this path.
3. Send the user the close-token balance from this withdraw (original + swap proceeds). Return `amountsOut` length 1.
4. Any swap preview 0, `InvalidRoute`, or execution failure **reverts the whole close**. Do not skip a leftover. Do not rejoin leftover non-DETF instead of swapping.

Morpho-cash / redeem-vault-share-on-close is **out of this package**.

### 6.3 Close vs live burn

`burnRoutes` do not imply `closeRoutes`. Live burn can be one pair while Default close still pays the full basket, or Custom close can settle to a different pair. Set both tables if they should match.

---

## 7. Worked example (Uni V4 v1, not a product brand)

Instance: unified Uni V4 DETF. Hook `tokens()` = `[DETF, TT, WETH]`. `standardExchangeOf(TT) = se0`, `standardExchangeOf(WETH) = se1`. Both SEs are on the hook. First bond still `joinUnbalanced` of every required leg plus DETF self-leg.

| Table | Mode | Rows |
|-------|------|------|
| mint | Custom | `{TT, se0}` |
| burn | Custom | `{TT, se0}` |
| bond | Custom | `{TT, se0}`, `{WETH, se1}` |
| close | Custom | `{TT, se0}` only (length 1) |
| donate | Custom | `{TT, se0}` only (subset of mint ∪ bond) |

Live seigniorage never takes WETH. Later bonds may take WETH into `se1`. Donate cannot take WETH. Custom close: after DETF rejoin, `ownerSwapExactIn(WETH, TT, …)` then pay TT. Claim is still DETF.

Custom **may** add `{weth, se0}` only if `weth` is in `se0.tokens()` (or is `se0`’s share) and WETH is not already a row (R6). Custom **may not** name an SE absent from the hook. A Morpho-loop vault that is not `standardExchangeOf` of a hook token is a **later package**.

---

## 8. Family encoding

### 8.1 Balancer-hosted families (Single SE, Weighted, MixedBuffer, Composed)

`IoRoute.vault` is the SE diamond. Reserve join/exit is that leg’s vault share. **Follow-on I/O pass, not Uni V4 v1.**

MixedBuffer today: mint buffer or shares, burn buffer only. That becomes Default tables, not special-case Solidity.

### 8.2 Uni V4 buffer-hook families

The hook buffers a pair token into a bound SE. **v1 encoding:** `IoRoute.vault` is always an `IStandardExchange` the hook already lists (`standardExchangeOf` of some non-DETF `tokens()` entry). Token may be that vault’s share or a token in that vault’s `tokens()`. Execution: §16. One Uni V4 DETF DFPkg. Old CP/Orbital/Weighted/Quad DETF packages are not extended. No pair-index encoding.

### 8.3 Nested DETF as an SE leg

Allowed. The outer table points at the inner DETF as `IStandardExchange`. Inner instance has its own tables. Opacity: outer does not read inner tables.

---

## 9. What this supersedes (when LOCKED)

| Current law | After this PRD |
|-------------|----------------|
| Agent law: rateAsset mint on DETF usually out of scope unless the family documents a zap | Zap is legal **iff** `{rateAsset, vault}` is a resolved mint (or bond) row and R14 holds |
| Alignment §16.2: mint `tokenIn` list is family-owned | Instance-owned; family supplies **defaults** only |
| Alignment D20: burn may pay any reserve token or SE buffer / rate asset | Burn may pay only `burnRoutes` tokens |
| Donation N6: family mint/bond capital **and** SE `tokens()` | N6 = R12 + §5.1–§5.2 (donateRoutes subset, plus DETF and `lpToken`) |
| Donation N7 seating | Seating vault is the route row, not “matching leg by inference” if that inference disagrees with the table |
| Alignment D29 / donation N4/N11: new originalShares to id 0, user NAV flat | **R12a:** unassigned LP when `totalOriginalShares > 0` (NAV up for all originalShares); id 0 1:1 only when `O == 0` |
| Donation non-goal 8: do not give donated LP to user bonds | **Dropped** if R12a is accepted. User bonds **do** share the NAV increase |
| Alignment D25 remainder | Process stays; remainder set is Default basket or Custom `closeRoutes` |

Unchanged: D9, D11, D12, D13, D15, D16, D18, D22, D23, D24, D31, protocol compound, ThresholdMode, token policy, unowned instances, CREATE3 / registry deploy.

---

## 10. Family default rows (normative once locked)

Used when the table’s mode is Default. Resolve and **store** concrete `IoRoute`s so getters do not re-infer.

| Family | Default mint | Default burn | Default bond-in |
|--------|--------------|--------------|-----------------|
| Balancer Single SE | `{vaultShare, se}` | `{vaultShare, se}` | `{vaultShare, se}` (plus reserve BPT if that family already accepts BPT as bond capital) |
| Multi-vault weighted | one row per leg `{vaultShare_i, vault_i}` | same | same (plus BPT if already accepted) |
| Mixed-buffer | `{bufferToken, each vault that lists it}` **and** `{vaultShare_i, vault_i}` as today | `{bufferToken, buffer-processing vault}` only (today’s burn buffer only) | family `acceptedBondTokens` today |
| Composed stable | today’s mint token set as rows | today’s burn set | today’s bond set |
| Uni V4 Single SE CP | pairToken and/or bound SE share per family PRD | same | family first-bond / later-bond tokens |
| Uni V4 Orbital / Weighted / Quad | per-pair rows from family PRD | per-pair | per-pair |

Default close: D25 full non-DETF basket (no extra zap). Default donate: union of resolved mint and bond rows.

If a family PRD and this table disagree after lock, **this file wins** on I/O; the family PRD wins on curve and first-bond quote.

**§14** (tentative change orders) is the reviewed default. Where §10 and §14 disagree, §14 wins until we iterate.

---

## 11. Implications the deployer must accept

1. **Skew is the strategy.** Mint-only-TT into Uni V4 fatten that share leg. Burn-only-TT drains it. Other legs move on first bond, later bonds, Custom close, protocol DETF compound, and allowed donate.
2. **Gates still see the whole book.** Policy synthetic includes legs the public cannot touch.
3. **Close is the only public unwind** for a leg omitted from burn. If that vault cannot `exchangeOut`, mature close reverts for everyone who would receive that token, unless Custom close omits the leg and rejoins it.
4. **Length-0 Custom mint** means no live seigniorage mint. The instance can still live off first bond, later bonds, donate, and expansion.
5. **Donate Default is not conservative.** Default donate = mint ∪ bond. Deployers who want “Morpho only via bond lock” must Custom-donate.

---

## 12. Questions — **LOCKED**

| # | Lock |
|---|------|
| Q1 | Tables apply to exact-in **and** exact-out. |
| Q2 | Custom mint may list shares only. |
| Q3 | Uni V4 v1 Default later-bond does **not** include hook LP. Balancer BPT-as-bond is follow-on (today’s Weighted list). |
| Q4 | v1 Uni V4 close: hook `exitProportional` fail → **whole tx reverts**. Morpho-cash close = **later DETF package**. |
| Q5 | Custom `closeRoutes.length` must be **exactly 1**. Length 0 or > 1 → `processArgs` reverts. Settlement = leftover hook-pair swaps into that one `hook.tokens()` pair (§6.2). |
| Q6 | FeeCollector donate of a token not on donateRoutes and not DETF/LP → **reverts**. No exception. |
| Q7 | **v1 = Uni V4** (hooks + one DETF). Balancer I/O tables **later**. |
| Q8 | Default donate = mint ∪ bond. |
| Q9 | donate(DETF) and `buyClaim` **always** allowed. No flag to forbid self-leg donate in v1. |
| Q10 | When this PRD is accepted, **edit alignment D20** (and D25 remainder, §16.2) to point here. **Do not** change D29 / N4 on common `DETFNFTVault`. R12a is the Uni V4 Bond NFT package only. |
| Q11 | Donate booking **R12a** on `…/uniswap/v4/bondNft/` (unassigned NAV-up; `O==0` credits id 0). |
| Q12 | Compound, `buyClaim`, D25 DETF rejoin still mint originalShares to **id 0**. |
| Q13 | Hook LP donate implicit. No fake `IoRoute.vault`. |
| Q14 | §15 / §16. |

---

## 13. Acceptance (Uni V4 v1)

v1 law is **§16**. §14 Balancer rows are **follow-on**, not v1 work.

Implementation-and-test plan (separate file) may be written for: §15.12 hooks → one Uni V4 DETF DFPkg → Bond NFT R12a donate booking on that NFT. Production-first. No SUT mocks. `via_ir` forbidden.

Do not treat Balancer I/O tables as in-scope until a follow-on PRD revision.

---

## 14. Family change orders

**v1:** Uni V4 CP / Orbital / Weighted / Quad **DETF packages are replaced** by the one DFPkg in §16. §14.5–§14.8 are historical notes only.

**Follow-on (not v1):** §14.1–§14.4 Balancer I/O tables. Do not implement those in the Uni V4 plan.

Reviewed 2026-08-26 against shipped Targets.

### 14.0 Shared (every true DETF)

**Preserve**

- Unowned instance, registry DFPkg deploy, opacity (`IStandardExchange*` only).
- Diamond is the DETF ERC-20. Reserve has a DETF self-leg. Bond NFT holds reserve LP (D13).
- Ids **1** and **2**: zero originalShares forever; `claimRewards` only; never mature close; never sell-to-claim (D17). Confirmed.
- Id 0: protocol / rebasing-claim principal. `buyClaim`, protocol compound, D25 DETF rejoin still mint originalShares to id 0 (Q12).
- D8 live mint/burn quote, D11 no DETF into the pool on live mint, D12 burn burns DETF, D16 first bond funds every non-DETF reserve leg, D24 unboosted bond `G`, D31 realize-then-gate on mint/burn/redeem/close (donate does not realize).
- ThresholdMode, protocol compound (DETF self-leg), natural expansion.
- Claim: DETF ↔ rebasing claim only (D15/D18/D22). Not on route tables.
- Token policy. Closed-form exact-out or `InvalidRoute` (D23).
- Family **curve, reserve token set, first-bond quote, synthetic method** (single vs per-route / all-legs-rich).

**Change (once)**

- `PkgArgs` route-table fields + `RouteTableMode` (R2/R7). `processArgs` validates R3–R14. Storage getters return **resolved** rows.
- Live mint/burn/later-bond/`joinDonatedCapital` consult resolved tables. Not a live walk of `vault.tokens()` unless that walk is exactly the Default encoding.
- `acceptedBondTokens()` = token column of resolved `bondRoutes` (plus implicit first-bond needs, which stay D16 and are not this getter’s job after live).
- Donate seating: R12 subset rule. Donate **booking**: R12a on the **new** Uni V4 Bond NFT (`…/uniswap/v4/bondNft/`). Do **not** edit common `DETFNFTVault` `_creditId0`. Balancer families keep N4/N11.
- Custom `closeRoutes`: Uni V4 v1 = exactly one `hook.tokens()` pair + leftover `ownerSwapExactIn` (§6.2). Default close = D25 basket (Quad `capitalToken`-only is superseded for the unified package).
- Reserve `lpToken` / BPT / hook LP as later-bond or donate capital is **not** an `IoRoute.vault` row. Implicit, like donate(DETF): no SE processor (Q13).

**Uni V4 DETF v1: no passthrough.** `exchangeIn` is mint, burn, or `InvalidRoute`. Pair↔share is the SE vault or Uniswap V4 doors.

**Q13 locked:** Hook LP / BPT as donate or later-bond capital is **implicit** (no `IoRoute.vault`). Uni V4 v1: donate(hook LP) allowed; later-bond of hook LP is **off** Default (pairs + shares only). Balancer Weighted Default bond-includes-BPT is follow-on.

---

### 14.1 Balancer Single Standard Exchange DETF

Path: `…/balancer/v3/standardExchange/single/`.

**Today**

| Surface | Shipped |
|---------|---------|
| Mint | Vault share **or** any token on the SE’s `vaultTokens()`, zapped via nested `exchangeIn` → share, then D11 share join. |
| Burn | Share **or** those same SE tokens via nested `exchangeOut`. |
| Bond (later) | Same as mint (share or SE tokens). **Not** DETF. **Not** reserve BPT. |
| `acceptedBondTokens` | Share + SE `vaultTokens()` (skips DETF). |
| First bond | SE vault share + DETF self-leg (D16). |
| Donate join | Allowlisted / share / DETF (peer of mint). |
| Close | D25 basket: non-DETF remainder is the vault-share leg (plus dust). |
| Extra | SE passthrough (both legs allowlisted, neither is DETF). |

This family **already** has an allowlist. It is **derived at runtime** from `vault.tokens()`, not frozen in `PkgArgs`.

**Default tables (reproduce today)**

- Mint = burn = bond-in = `{vaultShare, se}` plus `{token, se}` for each `token` in `se.vaultTokens()` except DETF and the share.
- Close Default = D25 basket (vault share).
- Donate Default = mint ∪ bond (same rows).

**Preserve:** Weighted-pool two-token reserve (DETF + share), D8 vs that curve, first-bond share+self-leg, passthrough, nested zap **machinery** (`_nestedExchangeInPush`).

**Change:** Freeze the allowlist as resolved `IoRoute`s at deploy instead of re-reading `vaultTokens()` every call. Custom can drop the zap rows (share-only, like Weighted) or drop the share row (rate-asset only). `UnsupportedRoute` on this family should become `InvalidRoute` when touching these tables (cleanup, not product).

**Fit for the TT/Morpho idea:** one SE only. Cannot host two legs. Not the Morpho+UniV4 instance. Still the simplest Balancer encoding of `IoRoute`.

---

### 14.2 Multi-vault weighted DETF

Path: `…/balancer/v3/multi-vault-weighted/`.

**Today**

| Surface | Shipped |
|---------|---------|
| Mint | **Vault shares only.** Rate asset → `InvalidRoute`. |
| Burn | **That vault’s share only.** Prop BPT exit, rejoin DETF + other shares, pay target share. No zap out to rate asset. |
| Bond (later) | Per-leg vault share **or** reserve BPT. |
| `acceptedBondTokens` | BPT first, then each vault share. |
| First bond | `initializeReserve`: **every** vault-share amount + unboosted DETF `G`. |
| Donate join | DETF self-leg **or** a vault share. **Not** rate assets. Stricter than donation N6. |
| Close | D25: every vault-share leg in the basket. |
| Extra | No SE passthrough. |

**Default tables**

- Mint = burn = `{vaultShare_i, vault_i}` for each configured leg.
- Bond-in = those rows **plus implicit reserve BPT** (Q13).
- Donate Default = mint ∪ bond **capital that has a vault**: shares only, unless we also allow implicit BPT donate (today `joinDonatedCapital` **rejects** BPT). Straw man Default donate = share rows only, matching shipped join, **not** N6’s SE `tokens()`.
- Close Default = D25 all vault shares.

**Preserve:** Weighted reserve (DETF + N shares), per-leg rate providers / rateAssets, D8 on the weighted book, `initializeReserve`, single-sided live mint of shares (D11), burn rejoin-others, no share↔share, synthetic over all legs, first bond all shares.

**Change:** `PkgArgs` tables so Custom can add `{rateAsset, vault}` zaps (nested `exchangeIn` like Single SE, per mapped vault). That is the **TT → Uni V4 SE / WETH → Morpho SE** instance. Custom burn `{TT, uniV4Se}` needs share exit **then** `exchangeOut` to TT (new on this family). Custom donate subset. Custom close can omit Morpho shares (rejoin id 0) or pay Morpho `loanToken` if the vault can `exchangeOut`.

**Primary host for the hypothetical DETF.** Implement tables here first among multi-leg Balancer families.

**Family-specific iterate:** Default donate today ≠ donation N6 (no rate-asset donate). Keep shipped-join as Default (conservative) or widen Default to N6. Straw man: keep shipped-join.

---

### 14.3 Mixed-buffer multi-vault stable DETF

Path: `…/balancer/v3/mixedBuffer/`.

**Today**

| Surface | Shipped |
|---------|---------|
| Mint | `bufferToken` **or** any vault share. Buffer mint zaps through `underlyingVaults[0]` then joins shares (`_joinLiveNonDetfBuffer`). |
| Burn | Alignment D20: **buffer or a vault share** (`_burnTokenOutKind`). Family PRD “burn buffer only” is **already superseded** in code. ExchangeIn comment still says buffer-only; OutTarget is wider. |
| Bond | Buffer, each vault share, reserve BPT. |
| First bond | `bootstrapFirstBond`: buffer + every vault share + DETF self-leg. |
| Close | D25 basket: buffer + shares. |

**Default tables**

- Mint = `{bufferToken, vaults[0]}` (today’s zap vault) **and** `{vaultShare_i, vault_i}`.
- Burn = `{bufferToken, vaults[0]}` **and** `{vaultShare_i, vault_i}` (shipped D20, not the old PRD).
- Bond-in = mint rows + implicit BPT.
- Close Default = D25 buffer + shares.

**Preserve:** MixedBuffer stable reserve (DETF unpaired + buffer + shares), amp, bootstrap first bond, buffer as shared rate asset, like-kind vault targets.

**Change:** Tables. Custom burn-buffer-only is how to restore the old family PRD. Custom can pin buffer processing to a vault other than `[0]` (today hard-coded). Do not silently change Default burn back to buffer-only; that would regress shipped D20 tests.

**Fit for TT/Morpho:** only if TT and Morpho WETH are treated as like-kind, which they are not. Not the host for that instance.

---

### 14.4 Composed stable common DETF

Path: `…/balancer/v3/stable/common/`.

**Today**

| Surface | Shipped |
|---------|---------|
| Mint | Routed `baseToken` per configured **route** (nested pool BPT selection, `_previewRoutedPoolBpt`). |
| Burn | DETF → settle to a `tokenOut` via reserve exit (`_previewExitSettle`). Alignment superseded old swap-not-burn. |
| Bond | Unique route `baseToken`s (`acceptedBondTokens` dedupes). |
| NFT | Family still has a **Composed-specific** bond NFT package. Donation interface comment: public donate is on production `detf/common/bondNft`, “Not Composed NFT.” |

**Encoding:** Rows are not always `{token, IStandardExchange}`. A route’s processor may be a nested Balancer pool / BPT, not an SE diamond. Tentative: family keeps its route struct as the **encoding** of `IoRoute` (token + route index). Do not pretend every processor is `IStandardExchange`.

**Preserve:** Composed stable reserve of nested like-kind legs, routed mint, D8-style quote vs synthetic ETH, claim package split (rebasing DETF token types in this tree).

**Change:** Five tables conceptually; Custom can disable a route. Wire donate seating/booking to the **common** NFT if this family is still on the old NFT. That NFT migration may already be an alignment item; this PRD does not own it, but R12a only ships on `DETFNFTVault`.

**Iterate:** confirm Composed is on common Bond NFT or still on `ComposedStableCommonDetfBondNFTVault`. Change order for donate booking depends on that.

---

### 14.5 Uni V4 Single SE CP buffer DETF

Path: `…/uniswap/v4/standardExchange/constantProduct/single/`.

**Today**

| Surface | Shipped |
|---------|---------|
| Mint | Pair / vault share / SE `tokens()`, settled to `pairToken`, then hook `depositSingle(pair)`. |
| Burn | Family PRD: **pairToken only**. Code path `_burnDetfExactIn` (confirm vs D20 widen). |
| Bond | Pair (and SE-accepted that settle to pair). `acceptedBondTokens` includes pair. |
| First bond | Pair + DETF self-leg at creation/opening rate. Permissionless. |
| Donate join | DETF → `depositSingle` DETF; else settle to pair → `depositSingle` pair. Rejects donating hook LP as `token` (must use NFT `lpToken` path). |
| Extra | SE passthrough. |
| Host | Uni V4 buffer hook; D9 owner-only LP; D30 owner ops while PoolManager locked. |

**Default tables:** mint = bond = pair + share + SE tokens of the **bound** SE, all with `vault = boundSe`. Burn Default = `{pairToken, boundSe}` if code/PRD pair-only; if D20 already widened, match code.

**Preserve:** CP hook math, `creationPairPerDetfWad` / `openingPairPerDetfWad`, D9/D30, permissionless first bond, pair as synthetic numeraire, passthrough, settle-to-pair zap machinery.

**Change:** Freeze allowlist in `PkgArgs`. Custom pair-only mint is a subset. Encoding: `IoRoute.vault` **is** the one bound SE. Donate booking via common NFT (R12a). Close Default = D25 non-DETF remainder (pair / share as withdrawn).

**Lock:** Uni V4 `update` / hook session: join still DETF-owned (D9). Tables do not let the NFT call the hook.

---

### 14.6 Uni V4 SE Orbital DETF

Path: `…/uniswap/v4/standardExchange/orbital/`.

**Today**

| Surface | Shipped |
|---------|---------|
| Mint | Token allowlisted on a pair leg → settle to that pair → `depositSingle`. Two SEs. |
| Burn | Pair **or** that leg’s share / SE token (`_isBurnTokenOutSupported`). Residual consolidate. |
| Bond | `pairToken0`, `pairToken1`, and vault shares if set. |
| First bond | **Both** external pairs (D16). |
| Extra | SE passthrough per leg. |
| Gates | Per-route synthetic vs the funded pair. |

**Default:** mint/bond = `{pair_k, se_k}` and `{share_k, se_k}` (and SE tokens of `se_k` if today allowlisted). Burn = shipped burn set (pairs + shares/SE). Close Default = D25 both non-DETF legs (alignment superseded Orbital dual-residual-to-one-capital).

**Preserve:** 3-leg orbital sphere, exactly two external pairs, per-route synthetic, first bond both pairs, D9/D30, passthrough.

**Change:** Tables; Custom can close one pair to public mint. Encoding: `vault` = that pair’s bound SE (two addresses). Same pair token must not map to two vaults (R6).

---

### 14.7 Uni V4 SE Weighted DETF

Path: `…/uniswap/v4/standardExchange/weighted/`.

**Today**

| Surface | Shipped |
|---------|---------|
| Mint | Allowlisted pair / share / SE token → settle to that pair → `depositSingle`. 1–7 pairs. |
| Burn | Pair (per-route synthetic gate `_isBurningAllowed(outIdx)`). Prop exit, redeposit DETF, residual to pair. |
| Bond | `acceptedBondTokens` = **pair tokens only** (not shares). Tighter than Orbital. |
| First bond | **Every** configured pair. |
| Expansion | All-legs-rich (no whole-DETF `rateAsset`). |

**Default:** mint = allowlisted settle-to-pair set; burn = pairs; bond-in = **pairs only** (match getter). Do not add shares to Default bond just to match Orbital.

**Preserve:** Weighted buffer hook, `n∈[2,8]`, per-route synthetic, all-legs-rich expansion, first bond all pairs, D9/D30.

**Change:** Tables. Custom can mint-only-one-pair (skew). Encoding: `vault = se[i]` for pair `i`.

---

### 14.8 Uni V4 SE Curve Quad Stable DETF

Path: `…/uniswap/v4/standardExchange/stable/quad/curve/`.

**Today**

| Surface | Shipped / family PRD |
|---------|----------------------|
| Mint | Any of three pairs (or capital settled into that pair / its SE). Hook `depositSingle` / join single-asset. |
| Burn | Prop remove + **rejoin DETF**; consolidate residual to `tokenOut` pair. Hook `withdrawSingle` **forbidden** on DETF burn. |
| Bond (later) | Exactly **one** external pair; mint join DETF + `joinUnbalanced`. |
| First bond | **All three** external pairs (hook full book). |
| Close | Family PRD: NFT stores **`capitalToken`**; mature close pays **that one pair**. Alignment D25 basket **conflicts**. |

**Default mint/burn/bond:** three `{pair_k, se_k}` (plus share/SE tokens if Q14 buffered-leg capital is shipped). Bond later still one pair per tx; the **table** lists which pairs are legal, not “all three in one later bond.”

**Close:** Tentative Default = that bond’s stored `capitalToken` (family Q7/Q18), **not** D25 three-token basket. Custom `closeRoutes` is a second filter/zap. **Iterate:** this is the sharp D25 vs family-close fight. This I/O PRD’s close table is closer to Quad’s existing close than to D25 basket.

**Preserve:** 4-asset StableSwap hook, `baseAmp`, like-kind convention, per-route synthetic, all-legs-rich expansion, first bond all three pairs, no `withdrawSingle` on burn, no whole-DETF `rateAsset`.

**Change:** Tables. Encoding like Weighted (three SEs). Do not reintroduce a global rateAsset field.

---

### 14.9 Cross-family comparison (tentative)

| Family | Default mint width | Default burn width | Zap today? | `IoRoute.vault` | First impl? |
|--------|--------------------|--------------------|------------|-----------------|-------------|
| Single SE | Share + SE tokens | Share + SE tokens | **Yes** | One SE | Encoding gold |
| Weighted (Balancer) | Shares only | Shares only | **No** | N SEs | **Product gold** (TT/Morpho) |
| MixedBuffer | Buffer + shares | Buffer + shares (D20) | Buffer via vault[0] | N SEs | After Weighted |
| Composed | Route baseTokens | Exit settle tokenOut | Routed pools | Route index, not always SE | After NFT confirm |
| Uni V4 CP | Pair + share + SE tokens | Pair (PRD) | Settle to pair | One bound SE | After Balancer |
| Uni V4 Orbital | Two pairs + shares | Pairs + shares/SE | Per-leg settle | Two SEs | With other V4 |
| Uni V4 Weighted | Pairs + share + SE | Pairs | Per-leg settle | 1–7 SEs | With other V4 |
| Uni V4 Quad | Three pairs | Pair `tokenOut` | Per-leg settle | Three SEs | Close-law first |

---

### 14.10 Suggested implementation sequence (not a plan file)

1. **Uni V4 Bond NFT (R12a)** in `…/uniswap/v4/bondNft/`. Common `DETFNFTVault` unchanged.
2. **Shared route-table lib** (validate, resolve Default, getters).
3. **Multi-vault weighted** Custom `{token, vault}` zaps: mint/burn/bond/donate/close. This is the Morpho/TT configuration.
4. **Single SE:** replace runtime `vaultTokens()` allowlist with the same lib (behavior-preserving Default).
5. **MixedBuffer:** Default = shipped D20 burn; Custom can restore buffer-only.
6. **Composed:** after NFT identity confirmed.
7. **Uni V4 families:** same policy, pair-index encoding, D9/D30 untouched. Quad close vs D25 resolved before code.

Until §14 is agreed, this sequence is a sketch only.

---

## 15. Uni V4 hook quote + standardized hook ABI (iterate)

**Scope:** Uni V4 **SE buffer hook** DETFs only (CP single, Orbital, Weighted, Curve Quad Stable). **Balancer-hosted DETFs are out.** They keep Vault balances + `BalancerV3WeightedPoolQuote` / router query. Dual SE CP buffer (no DETF family) is not a DETF; if we standardize SE buffer hooks it should still implement the same quote ABI so a later DETF can bind it.

**Status:** Hook ABI **§15.12** + instance defaults **§15.13** + v1 sheet **§16**. Dual SE CP implements the ABI; no DETF bind.

### 15.1 Intent

Agent law: pricing engine = reserve host. Uni V4 DETF families differ mainly because each hook has a different curve, and the DETF reimplements or wraps that curve instead of calling one ABI.

Today:

- **CP DETF** reads `rawReserve` / `reserveCurrency*` and runs `ConstProdUtils._saleQuote` locally. It does **not** call hook `previewSwapExactIn`.
- **Weighted DETF** already uses hook previews for live mint (`previewDepositSingle` then `previewExitSingleAssetExactBptIn(DETF)`, fallback swap). Comment: no WeightedMath in the DETF. Synthetic FD uses `previewExitProportional(totalLp)` then DETF converts residual legs to the path pair.
- **Orbital DETF** prefers `IStandardExchangeIn.previewExchangeIn` on the hook, then `previewSwapExactIn`.
- **Quad** math libs already quote swaps; DETF still has family `_quoteDetfAgainstReserve` / `_syntheticVs`.

Hook preview signatures already diverge (`zeroForOne` vs token addresses; `previewDeposit*` vs `previewJoin*`; `previewWithdraw` vs `previewExitProportional`). That ABI drift is what would block a single Uni V4 DETF package even after quotes exist.

**Goals**

1. One **view** quote ABI on every Uni V4 SE buffer hook used as a DETF reserve.
2. DETF supplies **accounting arguments** the hook cannot know (supply, pending expansion, owned LP, creation rate). The hook runs **its** curve on **its** effective reserves (buffer + SE shares, not raw V4 pool balances alone). Seigniorage `p` is applied by the DETF **before** the mint swap quote (H9 locked).
3. **Standardize the rest** of the DETF-facing hook surface (swap, join/exit, single-asset, owner-during-lock, token list, first-book constraints) so remaining family differences are data, not Solidity forks.
4. Keep D11 / D24 / D13 LP sizing / ThresholdMode / seigniorage split as DETF policy unless an H-question explicitly moves a piece.

**Non-goals (until an H-question moves them)**

- Replacing Balancer DETFs.
- Hook-owned Policy gates (hook must not read DETF storage to decide mint/burn allowed).
- Balancer-style `querySwap` that executes and reverts. Quotes stay `view` and closed-form (D23).
- Subclassing one Uni V4 DETF family from another. A unified package would be a **new** DFPkg talking only to the standard hook ABI + `IStandardExchange` legs.

### 15.2 Split of knowledge (**locked**)

| Knows | DETF / NFT | Hook |
|-------|------------|------|
| Curve, fees, effective reserves, SE buffer | | Yes |
| `previewSwap` / join / exit matching execution | | Yes |
| DETF `totalSupply`, pending expansion | Yes | Only if passed in |
| Owned LP | Yes: **Bond NFT `balanceOf` only** (H19). Pass that number in. | Does not scan wallets. |
| Creation / opening rates | `PkgArgs` | Passed in for synthetic (H1-B). Not stored on the hook in v1 (H17). |
| Seigniorage `p` (fee oracle) | Yes. DETF multiplies mint `amountIn` by `(1+p)` **before** the hook call (H9 **locked**). | Hook does not know `p`. |
| ThresholdMode, I/O tables, claim, compound | Yes | No |
| D9 owner-only LP, D30 owner swap while PoolManager unlocked | DETF is owner | Hook enforces |

**H1 locked (2026-08-26): B.** Hook returns **finished synthetic** from a context the DETF fills. Hook does **not** read DETF storage.

```text
struct DetfQuoteCtx {
    uint256 detfTotalSupply;
    uint256 pendingExpansion;      // 0 for spot synthetic; views must match D31
    uint256 ownedLp;               // Bond NFT LP balance only (H19)
    uint256 creationPairPerDetfWad; // for this numeraire
}
hook.previewSynthetic(ctx, numeraire) → wad   // 1e18 peg units
```

Hook internally redeems `ownedLp` to `numeraire` on its curve, then `S = (fdWad / (supply + pending)) / creation`. DETF is responsible for passing the same `pendingExpansion` that D31 views use (stale ctx is a DETF bug, not a hook read).

Mint/burn **curve** (locked 2026-08-26):

```text
// Mint gross (D8), before split. Quote the hook pair of this route's vault, not
// necessarily the token the user paid. pair = unique non-DETF t in hook.tokens()
// with standardExchangeOf(t) == vault.
// pairEq = amountIn if tokenIn == pair;
//        = previewExchangeOut(share → pair) if tokenIn == share;
//        = previewExchangeOut(exchangeIn(tokenIn → share) → pair) otherwise.
boostedIn = pairEq * (1 + p)     // DETF only
grossDetf = hook.previewSwapExactIn(pair, detfToken, boostedIn)
// Execute still joins shares (joinSingleAssetExactIn). Nobody swaps.
// Gross is minted to user/pot (D27/D3). D11: do not join Gross.

// Bond G (H6): NOT a swap. Size G so join mix matches current reserves
// (empty book: G = pairEq * 1e18 / openingPairPerDetfWad).
// Execution: one joinUnbalanced (DETF G + capital as pair or share).

// Burn: NOT a swap of detfIn through the pool.
lpOut = detfIn * nftLp / detfSupply    // DETF, D13, after D31
tokenOutAmt = hook.previewBurnToToken(lpOut, tokenOut)
// Hook: prop exit lpOut, rejoin DETF, residual → tokenOut. No withdrawSingle(DETF) (H10).
```

### 15.3 Quote function names

See **§15.12** (the only hook ABI). Mint gross is `previewSwapExactIn`. Synthetic is `previewSynthetic`. Burn is `previewBurnToToken`. Token addresses, not `zeroForOne`. No second swap formula.

### 15.4 Hook surface

See **§15.12**. There is no second, larger “router” ABI. CP/Orbital/Weighted/Quad (and Dual SE CP) implement **that set**. Old names are removed, not wrapped as public extras.

### 15.5 What this does not collapse by itself

Even with §15.3–15.4, these stay **explicit product decisions** (see H-questions):

1. One Uni V4 DETF DFPkg vs four families that share a lib. **LOCKED H7:** one DFPkg.
2. Per-route Policy gates vs one synthetic.
3. All-legs-rich expansion (Weighted/Quad) vs single-numeraire expansion (CP).
4. Quad burn: prop + rejoin DETF, never `withdrawSingle`.
5. I/O route tables (§1–§14): independent. A unified DETF still needs mint/burn/bond/close/donate maps. `IoRoute.vault` on V4 is the bound SE for that pair (`standardExchangeOf`).
6. Creation vs opening rates (peg vs empty-book first bond).
7. D9 owner-only add/remove. Balancer public join is irrelevant here.

A unified package is feasible **if** H4, H5, H8 are on the hook and I/O tables + threshold/expansion stay `PkgArgs`. That is a new family in the directory map, not an edit of CP DETF that the others subclass.

### 15.6 Interaction with I/O routing

§14.5–§14.8 Default tables stay valid if we do **not** collapse packages.

If we **do** collapse (H7 = one package):

- `IoRoute.vault` = `hook.standardExchangeOf(token)` when the token is a pair or that SE’s share / `tokens()`.
- Hook is **not** an `IoRoute.vault` (it is the reserve host, like Balancer Vault).
- Implicit donate/bond of hook LP remains Q13 (no SE processor).
- Custom TT-only mint still zaps through the Uni V4 **SE vault**, then the DETF joins **pair** (or share) on the hook. Do not teach the hook I/O tables.

### 15.7 Decisions for lock (proposed, `H*`)

| ID | Topic | Straw man |
|----|-------|-----------|
| **H1** | Synthetic: DETF divides FD vs hook `previewSynthetic(ctx)` | **LOCKED B:** hook returns finished synthetic from DETF-filled ctx |
| **H2** | Failed / empty preview | **LOCKED:** return **0**. DETF uses creation/opening before live; after live a 0 quote is a fail the DETF must turn into its own revert |
| **H3** | Pre-live mint quote | DETF creation/opening rates. Hook quotes only when `isLive` / non-zero reserves |
| **H4** | Unbalanced / full-book join as capability | **LOCKED true** on CP, Orbital, Weighted, Quad, Dual. `joinSingleAssetExactIn` reverts until `isLive()` |
| **H5** | `requiredFirstBondTokens()` | **LOCKED:** full `tokens()` list. Quad/Weighted/Orbital/CP: DETF + every pair. Dual: both pairs |
| **H6** | Bond `G` vs mint gross | **LOCKED:** mint gross = boosted swap of the hook pair. Bond `G` = **match current reserve mix** (join ratio), not a swap quote. Empty book: `G = pairEq * 1e18 / opening`. Execution: one `joinUnbalanced` with G DETF + capital (pair or share). Never `joinSingleAssetExactIn` on bond. |
| **H7** | One Uni V4 DETF package vs four + shared quote lib | **LOCKED:** one new Uni V4 DETF DFPkg. Existing CP/Orbital/Weighted/Quad DETF packages are abandoned (instances stay). Hook flags + I/O tables + `PkgArgs` creation rates |
| **H8** | One synthetic vs per-route | **LOCKED:** Policy mint/burn uses synthetic **vs the pair in this tx** (`previewSynthetic(ctx, tokenOut or pair of tokenIn)`). A DETF can be mintable in A and not in B. **Expansion** stays all-legs-rich when `syntheticNumeraires().length > 1` (do not infer mint-gate from expansion) |
| **H9** | `p` on the hook | **LOCKED No.** DETF applies D8 boost before `previewSwapExactIn` |
| **H10** | Quad `withdrawSingle` on DETF burn | **Still forbidden.** Redeem-LP-to-token for burn must be prop-exit + residual, not single-asset withdraw of DETF |
| **H11** | CP `zeroForOne` | **LOCKED deleted.** Token-address swap preview only |
| **H12** | Dual SE CP hook | Implement quote ABI; no DETF bind in v1 |
| **H13** | Owner D30 selectors | Same as public swap preview book/fee. One owner swap function name |
| **H14** | Fresh DETF DFPkg if H7 = collapse | **Yes.** Do not subclass Orbital from CP |
| **H15** | I/O tables vs hook | Tables stay on DETF. Hook does not store mint allowlists |
| **H16** | Preview gas / external calls | Accept one extra view per mint/burn vs inlined math |
| **H17** | Hook stores creation rates | **No** in v1 (stay DETF `PkgArgs`). Passing them in ctx is enough for H1-B if chosen |
| **H18** | `IStandardExchange` on the hook vs separate `IDetfReserveQuote` | Separate quote interface. SE In/Out may forward. DETF mint/burn quote calls **quote interface**, not nested SE, so pair-face mint does not depend on SE being the hook |
| **H19** | Owned LP wallets | **LOCKED:** Bond NFT balance only. LP on DETF diamond or rebasing claim is a **bug**; fix in this pass (see §15.10). Transient pull onto diamond for a hook withdraw must return leftover LP to the NFT in the same tx |
| **H20** | Mint quote shape / burn function | **LOCKED:** mint Gross = `previewSwapExactIn(pair, detf, pairEq*(1+p))` for the route’s hook pair. Burn = dedicated `previewBurnToToken`. Not join-then-exit. Not a `rejoinDetf` flag on one redeem |

### 15.8 H-questions (locked; kept for history)

Do not treat the straw-man column as open. v1 locks are §15.7 and §16.

| # | Question | Why it matters | Straw man |
|---|---------|----------------|-----------|
| H1 | Who divides FD by supply? | Policy gates | **LOCKED B:** hook `previewSynthetic(ctx)` |
| H2 | 0 vs revert on bad preview | Bootstrap vs live error handling | Return 0 |
| H3 | Pre-live quotes | First bond must not use a live curve | DETF opening/creation only |
| H4 | Capability flags vs four packages | Collapse vs lib-only | Flags on hook |
| H5 | First-bond token list on hook | Quad MIN book vs CP pair | `requiredFirstBondTokens()` |
| H6 | Bond `G` formula vs swap preview | D24 unboosted matching vs D8 boosted seigniorage | Separate calls; hook unaware of `p` |
| H7 | One DFPkg or four | Directory map, tests, deprecation of CP/Orbital/Weighted/Quad DETF packages | **LOCKED:** one DFPkg at `uniswap/v4/detf/` |
| H8 | Numeraires + all-legs-rich | Expansion and Policy on Weighted/Quad | **LOCKED:** gates per path; expansion still all-legs-rich if more than one numeraire |
| H9 | Boost on hook | Would couple fee oracle to hook | **LOCKED No** |
| H10 | Quad burn path | `withdrawSingle` vs prop+rejoin | Keep forbid withdrawSingle |
| H11 | CP ABI break | Existing tests/UI using `zeroForOne` | **LOCKED deleted.** Token-address swap preview only |
| H12 | Dual SE hook | ABI consistency without a DETF | Quote ABI yes, DETF no |
| H13 | D30 selector unification | DETF owner ops while unlocked | One name, same fee |
| H14 | Fresh package if collapse | Fresh-codepath rule | New DFPkg |
| H15 | I/O tables on hook | Would fight §1–§14 | DETF only |
| H16 | Gas | Extra `staticcall`s | Accept |
| H17 | Creation rates on hook | Peg vs empty book; immutability | Stay `PkgArgs` |
| H18 | Quote iface vs SE iface | Pair mint must not require hook==SE | Separate `IDetfReserveQuote` |

**Further concerns to define explicitly in review (no straw man yet)**

- **Owned LP definition:** **LOCKED H19** NFT only. Remaining: inventory tests that diamond and claim `balanceOf(hook LP) == 0` at rest (after every successful mint/burn/bond/close/donate/compound).
- **Rate providers:** **LOCKED.** Hook effective reserves already include SE NAV. DETF does not call `getRate` before `previewSynthetic` / `previewSwapExactIn`.
- **Self-leg token:** **LOCKED.** `processArgs` requires `address(this)` in `hook.tokens()` exactly once. That is the bound raw DETF. Hook does not read DETF storage. Dual SE CP fails this check.
- **Exact-out mint/burn (D23):** only if hook `previewSwapExactOut` is closed-form. I/O tables still apply (Q1).
- **Deprecation:** **LOCKED.** Existing Uni V4 DETF instances stay. No migrate. Old packages are not extended.
- **Testing:** hook unit tests own curve identity; DETF tests own preview==execute against **hook preview**, not a second math copy.
- **Opacity:** DETF production sources import **quote + SE + Bond NFT + host LP** ABIs. No Orbital math, no ConstProd, no WeightedMath in the unified DETF.
- **Staged init / hook mining:** unchanged (separate PRDs). Quote ABI must work after staged init when reserves are still dust.
- **MINIMUM_LIQUIDITY / NotLive:** first bond and D25 rejoin already special-case MIN LP. Quote returning 0 at MIN must not be treated as creation-rate mint after live (H3 vs live-dust).

### 15.9 Suggested review order (historical)

v0.12: H7 collapse, join ABI, I/O tables, and donate NFT are locked in §16. §14.5–§14.8 are historical notes for the abandoned Uni V4 DETF packages. Do not implement those change orders; implement the one DFPkg.

### 15.11 Join / exit ABI (**J1–J3 locked** 2026-08-26)

Goal: one DETF-facing liquidity surface so Uni V4 DETF execution (first bond, D11 join, compound, D25/burn rejoin) does not switch on hook family. Quote ABI is §15.10. This is **execution + matching previews**.

**Locks**

| ID | Topic | Lock |
|----|-------|------|
| **J1** | Names | Weighted/Quad vocabulary. **No aliases.** Do not keep `depositSingle` / `deposit` / `addLiquidity` / `withdraw` / `removeLiquidity` on the DETF-facing interface. Migrate hooks and DETFs, then delete the old names from that ABI. Other non-DETF callers may keep wrappers only until they migrate; the **required** interface does not include them. |
| **J2** | Amounts | `joinProportional` / `exitProportional` / single-asset exact-out joins that take a `uint256[]` use `tokens()` order; `amounts.length == tokens().length` or revert. **`joinUnbalanced` is different:** parallel `address[] tokens` and `uint256[] amounts` (§15.12). CP `n=2`, Orbital 3, Quad 4, Weighted 2–8. No `a0,a1,a2` overloads. |
| **J3** | B6 flexible | **Not** on the required ABI. DETF passes token addresses (`joinSingleAssetExactIn(tokenIn, amount)`). Pair vs SE share is which address, from I/O tables. Per-leg `amountIsSeShare` flags stay off-ABI extras for routers if a hook still wants them. |

**Required DETF-facing liquidity ABI**

```text
tokens() → address[]                         // stable order; includes DETF self-leg

joinUnbalanced(address[] tokens, uint256[] amounts, address to, uint256 sharesMin, uint256 deadline)
  → uint256 shares

exitProportional(uint256 shares, address to, uint256[] amountsMin, uint256 deadline)
  → uint256[] amounts                        // same order as tokens()

joinSingleAssetExactIn(address tokenIn, uint256 amountIn, address to, uint256 sharesMin, uint256 deadline)
  → uint256 shares

previewJoinUnbalanced(address[] tokens, uint256[] amounts) → shares
previewExitProportional(uint256 shares) → amounts[]
previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn) → shares
```

DETF usage:

| Path | Call |
|------|------|
| First bond / later bond | `joinUnbalanced(tokens, amounts)` (H5 which legs must be non-zero on first) |
| Live mint D11, donate capital, compound, DETF rejoin | `joinSingleAssetExactIn` |
| Burn / D25 prop exit | `exitProportional`, then `joinSingleAssetExactIn(DETF, …)` as needed; **not** `withdrawSingle` (H10) |

The full hook ABI, including liquidity, is **§15.12**. §15.11 only recorded J1–J3. It does not license leftover public names.

**Migration:** Old selectors are **deleted** from hook diamonds after the new set is cut. Internals may keep math; the ABI must not. CP `deposit`/`withdraw` and Orbital `addLiquidity`/`removeLiquidity` become private/internal only, then disappear from interfaces.

**Capability flags** still H4/H5: Quad may revert `joinSingleAssetExactIn` until full book; CP can single-join after live. DETF reads `requiredFirstBondTokens()` / `firstJoinMustBeFullBook()`.

### 15.10 Quote ABI locks (2026-08-26 Q&A)

You can collapse **quotes** to one Uni V4 hook interface. H7 is **LOCKED**: one Uni V4 DETF DFPkg. Existing CP/Orbital/Weighted/Quad DETF packages are abandoned (instances stay). Balancer DETFs are not collapsed.

| Pick | Lock |
|------|------|
| Synthetic | `previewSynthetic(DetfQuoteCtx, numeraire) → wad`. Ctx: `detfTotalSupply`, `pendingExpansion`, `ownedLp` (NFT only), `creationPairPerDetfWad`. Hook does not read DETF storage. |
| Mint gross | `previewSwapExactIn(pair, detf, pairEq * (1+p))`. `pair` is the hook `tokens()` entry for this route’s vault. DETF applies `p`. Not join-then-exit. |
| Bond `G` | **Match pool mix**, not swap. If the book is 2 DETF per 1 pair, 10 pair → G = 20 DETF. Empty book: opening/creation rate. |
| Burn | `previewBurnToToken(lpAmount, tokenOut)`. DETF sets `lpAmount = detfIn * nftLp / supply`. Hook prop-exits, rejoins DETF, residual to `tokenOut`. |
| `p` | Never a hook argument. |
| Owned LP | `IERC20(hook).balanceOf(bondNft)` only. |

**Custody bug (this pass, not a quote-ABI option):** CP / Orbital / Weighted `_fdPairWad` / `totalOwned_` today add `balanceOf(DETF diamond)` and `balanceOf(rebasingClaim)`. That is illegal under H19/D13. If those wallets hold hook LP at rest, tests must fail and paths must send LP to the NFT. Transient `_pullNftLp` onto the diamond for a hook withdraw is allowed only if leftover LP is pushed back to the NFT in the same transaction.

### 15.12 Standardized Uni V4 SE buffer hook interfaces (normative draft)

**Law:** Every Uni V4 SE buffer hook (CP, Orbital, Weighted, Curve Quad, Dual SE CP) implements **this set and nothing else** on its public liquidity/swap/quote/discovery surface. **One copy of the ABI:**

- `contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol`
- `contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol` (H18: `DetfQuoteCtx`, `previewSynthetic`, `previewBurnToToken`)

Family folders keep curve-only extras (weights, amp). They must not duplicate these signatures. The hook diamond is the LP ERC-20 (plus permit as for other IndexedEx ERC-20s). Curve math stays inside the hook. There is no family-specific public name and no “router extra” selector.

H2 and H5 are **locked** in §15.7. They affect **behavior** of functions listed here, not extra functions. Empty/unquotable **view** previews return **0**. `requiredFirstBondTokens()` is on this ABI.

Solidity names below are the ABI. Split across files in implementation if needed; the **union is the product**.

#### Discovery

```solidity
function tokens() external view returns (address[] memory);
// Stable order. Includes the DETF (raw) leg when this hook is a DETF reserve.
// amounts[] for join/exit use this order. Length n ∈ [2, 8].

function standardExchangeOf(address token) external view returns (address);
// Bound IStandardExchange for that pair/buffer token. address(0) if the leg is bare.

function syntheticNumeraires() external view returns (address[] memory);
// Tokens legal as previewSynthetic / Policy path pair. CP: one pair. Weighted/Quad: each external pair.

function requiredFirstBondTokens() external view returns (address[] memory);
// Full tokens() list. CP/Orbital/Weighted/Quad: DETF + every pair. Dual SE CP: both pairs (no DETF).

function firstJoinMustBeFullBook() external view returns (bool);
// LOCKED true on CP, Orbital, Weighted, Quad, Dual. joinSingleAssetExactIn reverts until isLive().

function isLive() external view returns (bool);

function tradingFeeWad() external view returns (uint256);
// One fee getter. 0.3% = 3e15. No pips, no parallel dexSwapFee / tradingFeePercent.
```

#### 15.12.1 Hook storage: pair vs Standard Exchange (`AddressSetRepo`)

**LOCKED.** Every Uni V4 SE buffer hook Repo stores pair tokens and bound Standard Exchanges as Crane `AddressSet` values. Import `@crane/contracts/utils/collections/sets/AddressSetRepo.sol`. `using AddressSetRepo for AddressSet`. Do **not** use OpenZeppelin `EnumerableSet`. Do **not** scan `tokens()` in a loop to ask “is this a pair?” or “is this an SE vault?” at runtime.

Normative hook `Storage` fields (names may match a family Repo; the membership and maps are required):

```solidity
address detfToken; // DETF self-leg; address(0) only on Dual SE CP (no DETF bind)
address[] tokens;  // stable tokens() order; includes detfToken when set
AddressSet pairTokens;          // non-DETF tokens() entries
AddressSet standardExchanges;   // hook.standardExchangeOf of those pairs (share identity when the diamond is the share)
mapping(address pair => address se) standardExchangeOf;
mapping(address se => address pair) pairOfStandardExchange;
```

**Init (hook `processArgs` / initialize, once):** for each non-DETF `t` in `tokens()` in that order: `pairTokens._add(t)`; `se =` bound Standard Exchange; revert if `se == address(0)` when this hook will bind a DETF; `standardExchanges._add(se)`; `standardExchangeOf[t] = se`; `pairOfStandardExchange[se] = t`. Then:

- `pairTokens` and `standardExchanges` must be **disjoint**. Overlap → revert deploy.
- `detfToken` must not be in either set.
- Two pairs must not share one SE (`pairOfStandardExchange` would collide) → revert deploy.

`tokens()` returns the stored array. `standardExchangeOf(token)` is the mapping (0 if unknown). No extra public “isPair” getter is required; joins/swaps use the sets internally.

**Classify an address** (`joinUnbalanced` / `joinSingleAssetExactIn` / swap `tokenIn`/`tokenOut`). One path, no discretion:

1. If `addr == detfToken` and `detfToken != address(0)`: DETF self-leg. No SE lookup.
2. Else if `pairTokens._contains(addr)`: **pair**. Matching vault is `standardExchangeOf[addr]`.
3. Else if `standardExchanges._contains(addr)`: **SE vault / share**. Matching pair is `pairOfStandardExchange[addr]`.
4. Else: `InvalidRoute`.

Same-leg twice in `joinUnbalanced`: resolve each input to a `tokens()` index (DETF index, or the pair’s index whether the caller passed the pair or the share). Duplicate index → revert.

`joinSingleAssetExactIn(tokenIn)`: classify; pair amount is buffered through that SE; share amount is the already-exchanged share of that same leg.

#### Swap (public AMM + D30)

Token addresses. Same book and fee for preview, public swap, and owner swap. No `zeroForOne`.

```solidity
function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
    external view returns (uint256 amountOut);

function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
    external view returns (uint256 amountIn);

function ownerSwapExactIn(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut,
    uint256 deadline
) external returns (uint256 amountOut);

function ownerSwapExactOut(
    address tokenIn,
    address tokenOut,
    uint256 amountOut,
    uint256 maxAmountIn,
    uint256 deadline
) external returns (uint256 amountIn);
```

Public trading is **Uniswap PoolManager** (V4 doors + `beforeSwap`). There is **no** public `swapExactIn` / `swapExactOut` on the hook (v0.8). `ownerSwap*` is D30: same math as `previewSwap*`, callable by the hook owner (the DETF) while PoolManager is already unlocked. No nested `unlock`. If a curve has no closed-form exact-out, `previewSwapExactOut` / `ownerSwapExactOut` revert `InvalidRoute` (D23). Do not add a solver.

#### Liquidity (Weighted/Quad names, arrays, no aliases)

For `joinProportional` / `exitProportional`: `amounts` / `amountsMin` length **equals** `tokens().length`. For functions that take a token address, `tokenIn` / `tokenOut` is either a `tokens()` entry or that leg’s SE share (`standardExchangeOf` ≠ 0). No `amountIsSeShare` flags.

```solidity
function previewJoinProportional(uint256[] calldata amounts)
    external view returns (uint256 shares, uint256[] memory usedAmounts);

function joinProportional(
    uint256[] calldata amounts,
    address to,
    uint256 sharesMin,
    uint256 deadline
) external returns (uint256 shares, uint256[] memory usedAmounts);

function previewJoinUnbalanced(address[] calldata tokens, uint256[] calldata amounts)
    external view returns (uint256 shares);

function joinUnbalanced(
    address[] calldata tokens,
    uint256[] calldata amounts,
    address to,
    uint256 sharesMin,
    uint256 deadline
) external returns (uint256 shares);
// tokens.length == amounts.length, both > 0.
// No duplicate tokens[i].
// Classify each tokens[i] with §15.12.1 AddressSets (DETF self-leg, pair, or SE share).
// Pair and that pair's share must not both appear (same tokens() index twice) — revert.
// Every amounts[i] > 0 (omit unused legs; do not pass 0).
// Caller-chosen order.
// A pair requirement in requiredFirstBondTokens() is satisfied by that pair OR that pair's share.

function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
    external view returns (uint256 shares);

function joinSingleAssetExactIn(
    address tokenIn,
    uint256 amountIn,
    address to,
    uint256 sharesMin,
    uint256 deadline
) external returns (uint256 shares);

function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
    external view returns (uint256 amountIn);

function joinSingleAssetExactOut(
    address tokenIn,
    uint256 sharesOut,
    address to,
    uint256 amountInMax,
    uint256 deadline
) external returns (uint256 amountIn);

function previewExitProportional(uint256 shares)
    external view returns (uint256[] memory amounts);

function exitProportional(
    uint256 shares,
    address to,
    uint256[] calldata amountsMin,
    uint256 deadline
) external returns (uint256[] memory amounts);

function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
    external view returns (uint256 amountOut);

function exitSingleAssetExactBptIn(
    address tokenOut,
    uint256 sharesIn,
    address to,
    uint256 amountOutMin,
    uint256 deadline
) external returns (uint256 amountOut);

function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
    external view returns (uint256 sharesIn);

function exitSingleAssetExactTokenOut(
    address tokenOut,
    uint256 amountOut,
    address to,
    uint256 sharesInMax,
    uint256 deadline
) external returns (uint256 sharesIn);
```

DETF call map: first and later bond → `joinUnbalanced(tokens, amounts)`; live mint / donate capital / compound / DETF rejoin → `joinSingleAssetExactIn`; D25 / burn principal → `exitProportional` then `joinSingleAssetExactIn(DETF)` as needed. **H10:** DETF burn **must not** call `exitSingleAsset*`. Those functions still exist for ordinary LP; they are not omitted.

Exact-out join/exit: implement if the curve has closed form; else revert `InvalidRoute`. Same as swaps. No binary search.

#### DETF quotes (on every SE buffer hook)

Hook does not read DETF storage. Caller passes ctx / lpAmount.

```solidity
struct DetfQuoteCtx {
    uint256 detfTotalSupply;
    uint256 pendingExpansion;
    uint256 ownedLp;                 // Bond NFT LP only
    uint256 creationPairPerDetfWad;  // for this numeraire
}

function previewSynthetic(DetfQuoteCtx calldata ctx, address numeraire)
    external view returns (uint256 wad);

function previewBurnToToken(uint256 lpAmount, address tokenOut)
    external view returns (uint256 amountOut);
```

`previewBurnToToken` = proportional exit of `lpAmount`, rejoin DETF, residual to `tokenOut` (H10). `previewSynthetic` = value `ctx.ownedLp` fully into `numeraire` (including converting the DETF leg), then `S = (fdWad / (supply + pending)) / creation`.

#### LP token

The hook diamond **is** the ERC-20 / permit LP. No `lpToken()` getter required beyond `address(hook)`.

#### Deleted (must not appear on the hook interface)

These names are **out**. Do not keep them as aliases, router extras, or “until callers migrate” public functions. Rewrite callers, then drop selectors.

| Deleted | Replaced by |
|---------|-------------|
| `deposit`, `deposit(a0,a1)`, `depositWithPermit2*` | `joinProportional` / `joinUnbalanced` |
| `depositSingle`, `depositSingleWithPermit2*` | `joinSingleAssetExactIn` |
| `addLiquidity(a0,a1,a2,…)` | `joinUnbalanced` |
| `withdraw(lp, min0, min1)`, `removeLiquidity(…, min0,min1,min2)` | `exitProportional` |
| `withdrawSingle`, `withdrawSingleExactOut` | `exitSingleAssetExactBptIn` / `exitSingleAssetExactTokenOut` |
| `previewDeposit*`, `previewWithdraw*`, `previewAddLiquidity`, `previewRemoveLiquidity` | matching `previewJoin*` / `previewExit*` |
| `previewSwapExactIn(bool zeroForOne, uint256)` | `previewSwapExactIn(address,address,uint256)` |
| `depositFlexible`, `withdrawFlexible`, `join*Flexible`, `exit*Flexible`, `depositWithSeShares`, `withdrawSeShares` | `tokenIn` is the pair **or** the SE share address |
| Hook `*WithPermit2*` | Caller approves the hook (or Permit2-approves, then the hook `transferFrom`s). No extra hook selectors |
| `isZapEligible` as a DETF branch | `joinSingleAssetExactIn` succeeds or reverts; H4/H5 flags for empty book |

V4 `beforeSwap` / `afterSwap` / PoolManager callbacks stay. They are Uniswap hook callbacks, not a second product ABI.

#### Technically not extra functions

- **Curve parameters** (weights, amp, R, fee pips): immutables / views already on the hook for ops. Not a second join API. Canonical fee view: **`tradingFeeWad()`** only. Do not add `tradingFeePercent` or `dexSwapFee`.
- **Staged init** (`ensurePairPools`, `isInitializationFinalized`): keep as the existing staged-init interface. Out of this liquidity ABI; do not re-encode as join.
- **IStandardExchangeIn/Out** on the hook: **out of this set.** Quote and swap are `previewSwap*` / `ownerSwap*`. There is no public `swapExact*` (v0.8). Buffering pair→SE is inside join/swap. H18: DETF does not mint by calling SE **on the hook**.

That is the complete public product surface for these hooks. Anything not listed is removed or is ERC-20/permit/introspection/ownership already shared with every Crane diamond.

**Dual SE CP** implements this same set in v1. No Uni V4 DETF `PkgArgs` may bind Dual until a later product lock.

### 15.13 Unified Uni V4 DETF instance defaults (locked 2026-08-26)

Applies to the **one** Uni V4 DETF DFPkg (H7).

| Topic | Lock |
|-------|------|
| Mature close | **Default:** D25 basket. Prop exit LP, rejoin DETF to id 0, pay **all remaining non-DETF** `tokens()` legs (and SE shares if those came out). No swaps. Not Quad `capitalToken`-only. **Custom:** exactly one non-DETF `hook.tokens()` pair; leftover pairs `ownerSwapExactIn` in `tokens()` order into that token (§6.2). Morpho-illiquid close is a **later package**. |
| Default mint / burn / later-bond tokens | **Pair tokens + bound SE shares only.** For each pair `t` in `hook.tokens()` except DETF: `{t, standardExchangeOf(t)}` (SE must be non-zero in v1; bare pair legs **revert deploy**). Plus `{share, se}` for that SE. **Do not** list SE `vaultTokens()` underlyings on Default. Custom **may** list an SE underlying that is not a hook pair, if `vault` is a hook-configured SE and R3 holds. Custom **may not** name an SE missing from the hook. R6: one row per token per table. |
| Live mint / donate capital | **SE `exchangeIn` then `hook.joinSingleAssetExactIn(share)`**. If `token` is already the share, skip `exchangeIn`. D11: no DETF into the reserve on mint. Donate DETF: `joinSingleAssetExactIn(DETF)`. Donate hook LP: pull only. |
| Bond | **One `joinUnbalanced(tokens, amounts)`.** Never `joinSingleAssetExactIn` on bond. Capital token in the array is the hook pair **or** that pair’s share (after `exchangeIn` if the user paid another token on that vault). |
| Default donate | Resolved mint ∪ later-bond (same `{token, vault}` rows). DETF self-leg and hook LP stay implicit. |
| First bond | `requiredFirstBondTokens()` / `firstJoinMustBeFullBook()` from the hook. Ungated. Route tables apply after live. Empty-book **G** per pair: `openingPairPerDetfWad` (0 → that pair’s `creationPairPerDetfWad`). |
| Passthrough | **None.** |
| Bare pair (no SE) | **Cannot bind** this DETF to a hook that has `standardExchangeOf(t) == 0` for any external `tokens()` leg. `processArgs` reverts. Follows SE-first seating + `IoRoute.vault != 0`. |

---

## 16. Uni V4 v1 implementor sheet (no discretion)

Do not invent a fourth path. If a case is not listed, it is **InvalidRoute** or **processArgs revert**. Where this section conflicts with §1–§15, **this section wins**.

### 16.1 In scope / out

| In v1 | Out of v1 (do not build) |
|-------|--------------------------|
| §15.12 on CP, Orbital, Weighted, Curve Quad, Dual SE CP hooks | Balancer DETF I/O tables |
| One Uni V4 DETF DFPkg at `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` (`IUniswapV4Detf`, `UniswapV4DetfDFPkg`) | Extending old CP/Orbital/Weighted/Quad DETF packages |
| New Bond NFT DFPkg at `…/uniswap/v4/bondNft/` with R12a donate booking | Editing common `DETFNFTVault` `_creditId0` |
| I/O tables on that DETF | Morpho-loop DETF package; Morpho-illiquid close |
| Hook DFPkg first; DETF `PkgArgs.hook` is that address | Dual SE as `PkgArgs.hook` |
| Crane `AddressSetRepo` for pair vs SE membership on hook and DETF (§15.12.1, §16.9) | OpenZeppelin `EnumerableSet`; scanning `tokens()` for membership |
| R19 diamond dust sweep (unassigned LP) | Leaving joinable ERC-20s or hook LP on the DETF diamond at rest |
| DETF user mint/burn/bond/donate/close **exact-in only** | Public `swapExact*` on the hook |
| | `mintExactOut` / `burnExactOut` / `bondExactOut` on the DETF |
| | Legacy hook names in §15.12 deleted table |
| | `via_ir`; SUT mocks |

Deploy order: hook DFPkg (CREATE3-predicted DETF address as DETF currency **and** hook owner) → DETF DFPkg (`indexedexManager.deploy*DFPkg`) → Bond NFT + claim in `postDeploy` as peers do. Never `new` facets/DFPkgs.

`IDetf` single-leg getters (`pairToken()`, `rateAsset()`, `underlyingVault()`) are **not** this package’s discovery API (n can be > 1). Discovery is `hook.tokens()`, `hook.standardExchangeOf`, and the route-table getters. Keep `IDetf` for donate forwarder, thresholds, `acceptedBondTokens`, `detfNFTVault`, `rebasingClaimToken`. Do not implement `mintWithRateAsset`. `reservePool()` returns `hook` (same alias as today’s CP `reserveHook`).

### 16.2 Live mint

User ABI (exact-in only). Same pull modes as today’s Uni V4 `bond` / donate: `pretransferred` on the DETF for mint; no native ETH; Permit2 is the existing pull helper, not extra hook selectors.

```text
previewMint(tokenIn, amountIn) → (grossDetf, userDetf, lpOut)
mint(tokenIn, amountIn, minUserDetf, recipient, pretransferred, deadline) → userDetf
```

Also reachable as `IStandardExchangeIn.previewExchangeIn` / `exchangeIn` with `tokenOut = DETF`. Exact-out mint is `InvalidRoute`.

Steps:

1. `tokenIn` on resolved `mintRoutes` else `InvalidRoute`. Row vault = `V`.
2. Realize expansion (D31). Policy gate vs `previewSynthetic(ctx, pair)` where `pair` is the unique non-DETF `t` in `hook.tokens()` with `standardExchangeOf(t) == V`. Open: gate passes. Inert: revert as today. `isMintingAllowed(tokenIn)` is this gate. No-arg `isMintingAllowed()` is true iff **some** resolved mintRoutes token passes.
3. `pairEq` as in §15.2. If a required SE preview reverts or returns 0 after live: `InvalidRoute`.
4. Pull `tokenIn`. If not share: `V.exchangeIn(tokenIn → share)`.
5. `lpOut = hook.joinSingleAssetExactIn(share, shareAmount, to=bondNft, sharesMin, deadline)`. Do **not** join DETF (D11).
6. `grossDetf = hook.previewSwapExactIn(pair, detf, pairEq * (1+p))`. Oracle `p` as D5/D6. D27: `U = Gross`. D3 split: user `(1-p)*Gross` (existing pot cut), pot `p*Gross` inventory. Mint Gross DETF to user/pot. **Do not** join Gross.
7. If `userDetf < minUserDetf`: revert `MinAmountNotMet`.
8. Preview == execute: `grossDetf` equals minted Gross; NFT LP delta equals `previewJoinSingleAssetExactIn(share, unboosted share amount)`. Two checks, two numbers.

### 16.3 Live burn

```text
previewBurn(detfIn, tokenOut) → amountOut
burn(detfIn, tokenOut, minAmountOut, recipient, deadline) → amountOut
```

`IStandardExchangeOut` with `tokenIn = DETF`. Exact-out burn is `InvalidRoute`.

1. `tokenOut` on resolved `burnRoutes` else `InvalidRoute`.
2. D31 then Policy gate vs synthetic of that row’s hook pair. `isBurningAllowed(tokenOut)` / no-arg exists analogously.
3. `lpOut = detfIn * nftLp / detfSupply` (D13, after D31). Pull LP from NFT onto the diamond; leftover LP back to the NFT in the same tx (H19).
4. Execute `previewBurnToToken(lpOut, tokenOut)`: `exitProportional` + `joinSingleAssetExactIn(DETF)` of withdrawn DETF + residual to `tokenOut`. **Not** `exitSingleAsset*`. If `tokenOut` is an SE share or SE underlying, residual conversion is the hook path then `V.exchangeOut` as needed so the user receives `tokenOut`. If that cannot pay: revert (do not try another vault).
5. Burn DETF (D12). `amountOut < minAmountOut` → `MinAmountNotMet`.

### 16.4 Bond

```text
bond(tokenIn, amountIn, lockDuration, recipient, pretransferred, deadline)
  → (tokenId, shares)
```

Same signature as today’s Uni V4 CP `bond`. Lock duration: revert if `< min`; clamp to max (existing oracle law). No `bondExactOut`.

**First bond (R9, ungated):** ignore route tables. `joinUnbalanced` with every `requiredFirstBondTokens()` address present **or** that pair’s share substituting for the pair. If `firstJoinMustBeFullBook()`, every non-DETF `tokens()` leg is funded (pair or share, not both) and DETF G > 0. Empty-book amounts and G follow existing Uni V4 opening/creation law (`UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_PRD.md`): per-pair `openingPairPerDetfWad` (0 → creation). Do **not** invent a new first-bond formula. Hook reverts if the full-book flag is violated. `to = bondNft`.

**Later bond:**

1. `tokenIn` on resolved `bondRoutes` else `InvalidRoute`. Vault `V`. `pair` as in mint.
2. Pull `tokenIn`. Convert to the capital token passed into `joinUnbalanced`:
   - if `tokenIn` is `pair` or the share of `V`: use it as-is;
   - else `V.exchangeIn(tokenIn → share)` and pass the share.
3. `pairEq` as in mint (for G). Live mix: `G = reserveDetf * pairEq / reservePairEffective` (integer; same rounding as current Weighted/CP matching join — document ≤1 wei in tests if the host forces it). Empty book: `G = pairEq * 1e18 / openingPairPerDetfWad`. D24: G is unboosted. D4: additional pot mint `p * G` (not part of the join amounts).
4. One call: `hook.joinUnbalanced([detf, capitalToken], [G, capitalAmount], to=bondNft, sharesMin, deadline)`. Never `joinSingleAssetExactIn` on bond. Never two joins.

`acceptedBondTokens()` after live = token column of resolved `bondRoutes`. Default does not include hook LP.

### 16.5 Close

`closeBondMature(tokenId, minAmountsOut, recipient, deadline)` and `previewCloseBondMature(tokenId)` as today’s Uni V4 surface.

Default: §6.1. `minAmountsOut.length == hook.tokens().length`; DETF index **0**. Return `amountsOut` in `tokens()` order.

Custom: §6.2. `minAmountsOut.length == 1`. Return `amountsOut` length 1 (settlement token). Leftover swaps: `ownerSwapExactIn` in `tokens()` order, skip DETF and the close token.

Ids 1 and 2 cannot close (D17). Not Policy gated. Fail → whole tx reverts.

### 16.6 Donate (this DETF’s Bond NFT)

Public `donate` is on the **new** Uni V4 Bond NFT, not common `DETFNFTVault`. `IDetf.donate` forwards onto that NFT (`minLpOut = 0`; pretransfer destination is the NFT; event donor is the collector). N15 funding modes stay (transferFrom, Permit2 allowance, Permit2 signature, pretransferred surplus). No native ETH.

Seating: §5.1–§5.2. Execution of non-LP capital: same as live mint join (`exchangeIn` if needed, `joinSingleAssetExactIn(share)` or `joinSingleAssetExactIn(DETF)`). No DETF mint. No D31 realize.

**R12a booking (this NFT only):**

| `totalOriginalShares` | Booking |
|-----------------------|---------|
| `> 0` | Join LP onto the NFT. **Do not** `addToDETFNFT`. Every existing originalShares holder’s `convertToAssets` rises (id 0 and user bonds id ≥ 3). |
| `== 0` | Credit id 0 at 1:1 for ΔL (N14). |

Ids 1 and 2 still zero originalShares. Common `DETFNFTVault` used by Balancer families is **unchanged** (still N4 id-0 mint).

### 16.7 Errors and views

New I/O surfaces: **`InvalidRoute` only**. Do not emit `UnsupportedRoute`.

Hook empty/unquotable **view** previews return **0** (H2). After live, the DETF turns 0 Gross / 0 burn-out / 0 synthetic used as a gate input into `InvalidRoute` or the existing `MintingNotAllowed` / `BurningNotAllowed`. Pre-live mint/burn stay blocked as today. First-bond quotes use opening/creation, not a 0 live curve.

Getters: `mintRoutes()`, `burnRoutes()`, `bondRoutes()`, `closeRoutes()`, `donateRoutes()`, plus `mintRouteMode()` … `donateRouteMode()`. All return **resolved** rows. `hook()`, `creationPairPerDetfWad()` / `openingPairPerDetfWad()` as stored arrays (opening fully resolved, never 0).

### 16.8 Tests that must exist (not optional)

- Diamond and claim `balanceOf(hook LP) == 0` after every successful mint, burn, bond, close, donate, compound, and after `sweepDust`.
- Diamond `balanceOf` each `hook.tokens()` entry and each bound SE share is 0 after those paths when a join of that residual was possible (R19). A leftover that cannot join (below host min, `isLive()==false`) may remain until `sweepDust` can join it.
- `test_L2_FoT_forbidden` with a real FoT as configured pair.
- Preview == execute on mint Gross, burn-to-token, join, exit, later-bond G join.
- Custom mint token that is an SE `tokens()` underlying **not** in `hook.tokens()`, vault a hook-configured SE; Default tables still omit that underlying.
- Custom cannot deploy with `vault` absent from `hook.standardExchangeOf` of every non-DETF `tokens()` entry.
- Custom close length 1: leftovers swap in `tokens()` order into that pair; Default close still pays the basket with no swaps.
- Dual SE hook implements §15.12; DETF deploy with Dual as hook **reverts** (`address(this)` not in `tokens()`).
- New Bond NFT: donate with `totalOriginalShares > 0` does not mint originalShares; user `convertToAssets` rises. Common `DETFNFTVault` donate still credits id 0 (regression).
- `joinUnbalanced` pair+share of the same leg reverts.
- Exact-out mint/burn on the DETF is `InvalidRoute` or omitted.
- Hook init: `pairTokens` and `standardExchanges` disjoint; `detfToken` in neither; two pairs do not share one SE.
- Classify: `joinSingleAssetExactIn` / `joinUnbalanced` / swap with a pair, with that pair’s SE share, and with an unknown address (`InvalidRoute`). `_contains` is the membership check (no `tokens()` scan).
- DETF `processArgs`: `IoRoute.vault` `_contains` in the hook-SE set; unknown vault reverts without walking `hook.tokens()`.
- **R20:** hermetic pons v2 graduated pool wrapped as Uni V4 SE (same PoolManager); DETF first bond + mint/burn against that SE. See §16.11 / stage 10.

### 16.9 Address sets on the DETF (same library)

The unified DETF Repo also uses Crane `AddressSetRepo` (same import, `using` clause). Fill once in `processArgs`. Runtime membership is `_contains`, not an array walk.

**Copied from the hook (after hook checks in §3.3):**

- `AddressSet hookPairTokens` — same members as the hook’s `pairTokens`.
- `AddressSet hookStandardExchanges` — same members as the hook’s `standardExchanges`.

`IoRoute.vault` is legal iff `hookStandardExchanges._contains(vault)`. Do not re-read every `hook.tokens()[i]` on each mint.

**Resolved route tables:** for each of mint / burn / bond / close / donate, store:

- `AddressSet` of the resolved **token** column (insertion order = stored row order for getters);
- `mapping(address token => IStandardExchange vault)` for that table.

Runtime: `mintRoutes` hit iff `mintTokens._contains(tokenIn)`; vault is `mintVaultOf[tokenIn]`. Same for burn (`tokenOut`), later bond, donate, Custom close. Getters `mintRoutes()` etc. rebuild `IoRoute[]` from `_values()` plus the mapping (or store the resolved array as well if that is cheaper; membership must still be the set).

Do not put DETF or hook LP in these table sets (those donate paths stay implicit).

### 16.10 Diamond dust (R19)

The DETF diamond is not a wallet for reserve inventory. H19 already: hook LP at rest lives on the Bond NFT only. R19 extends that to **joinable ERC-20s** sitting on the diamond.

**Joinable (sweep these):**

1. Hook LP (`address(hook)`): transfer the diamond’s LP balance to the Bond NFT (same inbound-LP-delta booking as donate of `lpToken`). Do not join; it is already LP.
2. DETF (`address(this)`): `joinSingleAssetExactIn(DETF)` to the Bond NFT, after live.
3. Bound SE share (`hookStandardExchanges._contains`): `joinSingleAssetExactIn(share)` to the Bond NFT, after live.
4. Hook pair (`hookPairTokens._contains`): `exchangeIn` to share if the pair is not itself the join token, then `joinSingleAssetExactIn` (mint/donate seating). After live only (`joinSingleAssetExactIn` reverts until `isLive()`).

**Not joinable:** any other ERC-20. Leave it. Do not `ownerSwap` it into a pair to force a join.

**When:**

- End of every successful live mint, burn, later bond, close, donate, protocol compound, `buyClaim`, `redeemClaim`. Best-effort: a failed sweep **must not** revert the user operation (same spirit as protocol-compound join failure). Emit nothing required; leftover remains for the public call.
- Public `sweepDust()` (or family-equivalent) after live. Permissionless. No DETF mint. Does not realize expansion. Tries joinable residuals in this order: hook LP, then `hook.tokens()` index 0..n-1, then any `hookStandardExchanges` member not already covered. Each join is best-effort (continue on revert). No-op if nothing joinable.

**Booking:** R12a. Unassigned LP when `totalOriginalShares > 0` (no originalShares mint to any id). `O == 0` → id 0 at 1:1 (N14). Ids 1 and 2 never get originalShares. This is **not** a gift to a chosen bonder.

**Transient:** pull of NFT LP onto the diamond for a hook withdraw is still allowed if leftover LP returns to the NFT in the **same** transaction (H19). That leftover is not “dust” if it is returned before the tx ends.

**Pre-live:** do not `joinSingleAssetExactIn`. Hook LP on the diamond still pushes to the NFT if any exists. Other residuals wait until live.

### 16.11 pons v2 graduated pool as Uni V4 SE (R20)

**Gap:** IndexedEx `test/` does not import `TestBase_PonsFamilyV2` or wrap a pons pool. Crane hermetic specs launch the curve; they do not deploy an IndexedEx Uni V4 SE on the graduated `PoolKey`. TWAP oracle docs mention pons pools as **foreign** pools for `update`, not as the SE bound pool.

**Required fixture (hermetic, production-first):**

1. Inherit Crane `TestBase_PonsFamilyV2` (`lib/crane/contracts/protocols/launchpads/ponsFamily/v2/test/bases/TestBase_PonsFamilyV2.sol`). Real factory, meme hook, locker, V4 `PoolManager`. Not a mock launchpad.
2. Approve **WETH** as a v2 pair token and launch with `pairToken = WETH` (ERC-20 quote). Do **not** use native ETH (`address(0)`) as the SE bound pool in v1 of this fixture unless Uni V4 SE already has a passing native-currency suite. Native quote is a follow-on row.
3. Size a launch config so graduation is feasible in a hermetic test (smaller `supply` / `phantomQuote` / `graduationThreshold` than live 1e9 if full sell-out is too heavy). Still real `launchToken` + curve buys + `createGraduatedPool` (or auto-grad on the finishing buy). Phase must be `PoolCreated`.
4. Read the graduated `PoolKey`: launch token + WETH, `fee == 0`, `hooks == PonsV2MemeHook`. Locker holds the graduation position (no withdraw). That is the pool.
5. Deploy IndexedEx `UniswapV4StandardExchangeDFPkg.deployVault(that PoolKey)` via manager/registry. The SE adds **its own** positions; it does not steal locker LP.
6. SE `exchangeIn` / `exchangeOut` preview==execute on that pool (meme hook `afterSwap` fees apply; pool fee field is 0).
7. Unified DETF: bind that SE as `standardExchangeOf` for the launch-token (or WETH) pair on the CP pathfinder hook. First bond, live mint of the launch token or vault share, live burn. Diamond dust R19 still holds.

**Two packages, one PoolKey:**

| Pool | Hook | Who provides LP |
|------|------|-----------------|
| pons graduated V4 pool | `PonsV2MemeHook` | Launch locker (permanent) + Uni V4 SE vault positions |
| DETF buffer-hook reserve | IndexedEx SE buffer hook (§15.12) | Bond NFT (D13) |

Do not set `PonsV2MemeHook` as the DETF reserve hook. Do not require the pons pool to implement `previewSynthetic`.

**Fork:** optional later (`FOUNDRY_PROFILE=fork`, Robinhood 4663) once v2 addresses are published. Not a v1 DoD. Hermetic Crane stack is the ship gate.

**Naming:** product is **pons** (lowercase). Path/type: `ponsFamily` / `PonsV2*` / `TestBase_PonsFamilyV2`.


