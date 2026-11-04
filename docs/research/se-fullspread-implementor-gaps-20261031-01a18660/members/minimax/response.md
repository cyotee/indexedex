# Implementor gaps in the updated full-spread Standard Exchange PRD

## Identity

- Member: MiniMax (`minimax/MiniMax-M3`), independent council member, profile: research.
- Run: `se-fullspread-implementor-gaps-20261031-01a18660`. Output: `members/minimax/response.md` only.
- Read: the brief, the updated PRD (`fullspread-se-prd-weir-align-r1`), the function-review file, `WeirVaults.sol`. Wrote only this file. Did not edit the PRD, the review file, or the brief. Did not read peer responses. Did not delegate. Ran no Forge, Git, install, or deployment.
- Posture: research, not review. Each gap below names the PRD section, quotes the deferring sentence, and states why two competent implementors would ship different money, storage, selector, or route behavior while both claiming the PRD. Where an owner lock or a cited `WeirVaults.sol` function settles the sentence, I give exact replacement prose; where nothing settles it, I ask one owner question. I invent no cap, fee, holder, return field, or selector.

## Question and targets

Question: which sentences in the updated full-spread PRD still force an implementor to choose a product behavior, and what exact owner question or closing recommendation removes that choice?

Targets read in full:

1. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` (401 lines).
2. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` (66 lines).
3. `contracts/protocols/strategy/weir/WeirVaults.sol` (449 lines).

Supporting repo reads, all read-only and none edited: `contracts/vaults/basic/IBasicVault.sol`, `contracts/vaults/basic/MultiAssetBasicVaultRepo.sol`, `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol`, `contracts/interfaces/IVaultFeeOracleQuery.sol`, `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol`, `contracts/interfaces/IStandardExchangeInMulti.sol`, `contracts/interfaces/IStandardExchangeOutMulti.sol`, `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `lib/crane/contracts/interfaces/IWETHAware.sol`, `lib/crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2RouterAwareRepo.sol`, `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md` (§7.6.3), `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` (S1-NATIVE-01), and `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_EXECUTION_EVIDENCE.md`.

Not read: the two accepted reports that FS-OWN-08 and FS-OWN-09 defer to (`se-interface-refund-bundle-20261030-01a18660/REPORT.md`, `se-paired-money-necessity-20261030-01a18660/REPORT.md`). They are outside the brief's target list and I could not rule out embedded peer content. Every conclusion that depends on the accepted bundle-route signatures is marked in Limits.

### Verdicts on the brief's minimum inventory

| # | Inventory item | Verdict |
| --- | --- | --- |
| 1 | Genesis floor representation beyond the cited `_deposit` supply rule | **CONFIRM** — MG-01 |
| 2 | Positive credit in the unselected currency on a one-token route | **CONFIRM** — MG-02, closable by R2 |
| 3 | Sleeve refill, shortfall, locked-caller spend (FS-OWN-04) | **CONFIRM** — MG-03, MG-04 |
| 4 | `poolManager` as `PkgInit` field and the aware-repo write path (FS-OWN-01) | **CONFIRM** — MG-05 |
| 5 | Where the `wrappedNative` package binding is stored (FS-OWN-10) | **CONFIRM** — MG-06 |
| 6 | Raw ETH entry and exit (FS-OWN-09) | **CONFIRM, and a PRD conflict to correct** — MG-07 |
| 7 | `queryFacet` still under function review | **CONFIRM** — MG-09; the family selector set is closable by R4 |
| 8 | FS-OWN-07's "other semantics are not specified" | **CORRECT** — `IBasicVault` has exactly three members, so the sentence is not a general semantics gap. The real gaps are MG-10 and MG-11 |
| 9 | A later rate policy (FS-OWN-03) | **REJECT** — not a gap under the brief's rule; no behavior is forced today |
| 10 | Pro-rata idle on the accepted one-token exit | **CONFIRM** — MG-12 |

Seven further gaps found outside the inventory: MG-08, MG-11, MG-13, MG-14, MG-15, MG-16, MG-17.

## Evidence

- **E1.** `WeirVaults.sol` `_deposit` sets `v.totalShares = MIN_SHARES` and, after the liquidity modification, `v.totalShares += frame.shares` while `v.liquidity += frame.liq`. `MIN_SHARES` is `1_000` and is "locked forever on the first deposit". `deposit` credits only `frame.shares` to `p.recipient`. The floor is therefore part of the same counter the existing-supply branch divides by, and nobody holds it.
- **E2.** `WeirVaults.sol` `_deposit` settles both currencies to the payer: `_settle(v.key.currency0, frame.net0, depositor); _settle(v.key.currency1, frame.net1, depositor);`, and `deposit` unlocks with `abi.encode(Action.DEPOSIT, id, abi.encode(p, msg.sender))`, so `depositor` is `msg.sender`, not `p.recipient`. `deposit` then returns `(amount - used)` of each currency to `msg.sender` by transfer, not through a return value.
- **E3.** `WeirVaults.sol` `_deposit` never writes `v.idle0`/`v.idle1`; only `_compound` does (`v.idle0 = uint256(int256(v.idle0) + frame.net0)`). `_compound` reinvests `frame.r0 = frame.f0 - frame.cut0 + v.idle0` into liquidity, so a compound empties the local balance.
- **E4.** `WeirVaults.sol` `_withdraw` pays `v.idle0 * w.shares / v.totalShares` and `v.idle1 * w.shares / v.totalShares` in both currencies, then converts only when `w.zapTo` is 1 or 2. `zapTo` is the only mechanism that turns an unwanted leg into the selected one.
- **E5.** `WeirVaults.sol` `_balance` swaps **half** of the imbalance (`x = (a0 - a1 restated in token0 terms) / 2`, or `x = (a1 - a0in1) / 2`, each with an early return when `x == 0`) and `_deposit` computes `frame.liq` as `LiquidityAmounts.getLiquidityForAmounts(sqrtP, tickLower, tickUpper, a0 - 2, a1 - 2)`. The 2-wei haircut and the half-swap are part of the issuance arithmetic.
- **E6.** `WeirVaults.sol` `_withdraw` leaves `v.liquidity = 1000` and `v.totalShares = 1000` after every redeemable share is burned, so the genesis branch (`v.totalShares == 0`) is unreachable and the existing-supply branch stays live with denominator `1000`.
- **E7.** `contracts/vaults/basic/IBasicVault.sol` declares exactly three members: `vaultTokens()`, `reserveOfToken(address)`, `reserves()`. There is no fourth member whose semantics are left open.
- **E8.** `contracts/vaults/basic/MultiAssetBasicVaultRepo.sol` uses `STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.basic"))`, stores `AddressSet _vaultTokens` and `mapping(address token => uint256 balance) _reserveOfToken`, and exposes `_initialize(address[] memory tokens)` and `_vaultTokens()`. `MultiAssetBasicVaultFacet.sol:37-38` installs `IBasicVault.vaultTokens.selector` and `IBasicVault.reserveOfToken.selector`. The shared `vaultTokens()` therefore returns a stored token set, and the shared `reserveOfToken` returns a stored balance. The PRD's FS-OWN-07 description is accurate.
- **E9.** `contracts/interfaces/IVaultFeeOracleQuery.sol:168` declares `liquidReservePercentageOfVault(address vault)`, implemented at `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol:322` with WAD denominators and a three-tier fallback where a stored `0` means "unset". The FS-OWN-04 source exists.
- **E10.** The Crane Aware pattern is a storage library bound to a slot plus a facet: `lib/crane/contracts/protocols/dexes/uniswap/v2/aware/UniswapV2RouterAwareRepo.sol` holds `struct Storage { IUniswapV2Router router; }` with `_layoutStruct(bytes32)`. `lib/crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol` and `WETHAwareFacet.sol` do the same for WETH, exposing `IWETHAware.weth()` (`lib/crane/contracts/interfaces/IWETHAware.sol`). `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/` exists and is empty (0 entries), as the PRD states.
- **E11.** The Standard Exchange convention for V4 native pools: `contracts/interfaces/IStandardExchangeInMulti.sol` and `IStandardExchangeOutMulti.sol` both state "V4 uses PoolKey order with WETH as the ERC20 face of a native currency", and the sibling baseline PRD S1-NATIVE-01 states "The canonical SE methods are nonpayable and accept ERC-20 addresses" and "Define their currency faces in PoolKey order: `C0 = wrappedNative` when currency0 is native".
- **E12.** An existing SE consumer of the reserve views: `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md` §7.6.3 fixes `reserveOfToken(rawToken) → rawReserve()`, `reserveOfToken(pairToken) → seClaimSupply()`, and `reserveOfToken(other) → 0 (or revert — plan picks one; prefer 0 peer vault)`. The repo's own convention is explicitly undecided for a token outside the vault's token set.
- **E13.** `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` shows `InArgs { IERC20 tokenIn; uint256 amountIn; IERC20 tokenOut; uint256 minAmountOut; address recipient; bool pretransferred; uint256 deadline; }`. The accepted route carries a `recipient` that is not necessarily the payer, which is the source of the fork in MG-02.
- **E14.** The repo's current multi-asset route names differ from the PRD's: `previewExchangeInManyToOne` / `exchangeOutOneToMany` exist today, while the PRD uses `exchangeBundleInForSingleOut` / `exchangeBundleOut`, which come from the accepted report the PRD defers to (see Limits).
- **E15.** The sibling baseline's `donate(address,uint256)` was a MoneyFacet selector writing the multi-asset repo (`family / ERC20Repo / MultiAssetBasicVaultRepo`, execution evidence table). This family forbids that stored balance, so "the vault's book" in the review file has no home here (MG-15).

## Gaps

**MG-01 — The genesis floor has no representation on this family's single ERC-20 supply.** (inventory 1)
- PRD section: §1.3 FS-OWN-04/FS-OWN-07 (no), §5 FS-MONEY-01 genesis bullets, §8 FS-A05.
- Quote: "When `v.totalShares == 0`, the source rejects `frame.liq <= MIN_SHARES`, assigns `frame.shares = frame.liq - MIN_SHARES`, and sets `v.totalShares = MIN_SHARES`. ... After the liquidity modification, the function adds `frame.liq` to `v.liquidity` and `frame.shares` to `v.totalShares`. ... `deposit` credits only `frame.shares` to `p.recipient`. The floor is supply that is not credited to that recipient. This update does not add a second share ledger, pick a holder address, or rescale the constant."
- Why two implementors diverge: Weir has two counters (`v.totalShares` and `sharesOf`); this family has one ERC-20 supply and is forbidden a second ledger and a holder address. So the floor must be mapped onto that one supply, and the PRD does not say how. One implementor makes `totalSupply()` include the floor (1,000 shares held by no address, so `sum(balanceOf) < totalSupply()`), and keeps the existing-supply denominator at `totalSupply()`. The other keeps `totalSupply()` equal to minted shares only and defines the denominator as `MIN_SHARES + totalSupply()`. The branches differ in the reported total supply, in the share price any external reader computes, and in the state of a vault whose redeemable shares are exhausted: after E6 the position still holds 1,000 units of liquidity, and in the first branch that residual value is visible in `totalSupply()`, while in the second it is outside the supply and belongs to nobody at all. The PRD's "The floor is supply" fixes the arithmetic (E1) but not this representation.
- Disposition: owner question **Q1**; the settled half is recommendation **R1**.

**MG-02 — A positive credit in the unselected currency has no named channel and no named recipient.** (inventory 2)
- PRD section: §1.2 FS-X04, §5 FS-MONEY-01 first and last bullets, §1.3 FS-OWN-08, §5 FS-UNLOCK-02.
- Quote: "Unused declared input is returned to the payer. A positive credit is returned to the depositor and is not booked without shares." and "A positive credit goes back to the depositor. Shares are credited to `p.recipient`, who need not be the payer." and "`previewExchangeIn` and `exchangeIn` keep their current parameters and return `(uint256 amountOut, uint256 amountRefunded)`."
- Why two implementors diverge: the credit is in a currency the depositor did not declare, so it cannot be reported inside `amountRefunded`, which is one uint256 in the input currency (FS-OWN-08), and the PRD names no transfer for it either. One implementor transfers it to the payer, exactly as Weir does (E2). Another leaves it in the vault as idle, which redistributes it pro-rata to all holders on exit. A third pays it to `recipient`, because FS-UNLOCK-02 says "Output is paid to `recipient`". The first and second differ by the whole credit in the redeeming user's pocket; the first and third differ by who is paid. The PRD's "returned to the depositor" names an amount but not a currency, a channel, or a recipient.
- Disposition: closed by recommendation **R2** (the cited `_deposit` settles to the payer). The `recipient` reading is ruled out by that same source.

**MG-03 — The sleeve target and the compound rule contradict each other.** (inventory 3a)
- PRD section: §1.3 FS-OWN-04 versus §5 FS-MONEY-01 compound bullet.
- Quote: "The target percentage is `IVaultFeeOracleQuery.liquidReservePercentageOfVault(address(this))`. ... Apply that same percentage to each underlying token's owned amount. ... Refill, shortfall, and whether a locked caller may spend the sleeve are not specified." and "`_compound` harvests fees by a zero-liquidity modification and reinvests the remainder plus idle."
- Why two implementors diverge: FS-OWN-04 states a target that must sit locally; FS-MONEY-01 states that compound reinvests the remainder *plus idle*, which empties the local balance on every compound (E3). One implementor mirrors Weir exactly, so the sleeve is drained to zero by the first compound and the target is never met, making the percentage and the oracle read decorative. The other holds the target back out of the reinvestment, which changes what compound does, what idle means afterwards, and every later share-price computation, and which the PRD does not authorize anywhere. Weir cannot settle this: Weir has no sleeve and no target percentage. The oracle value also has a documented "unset = 0" case (E9) that the PRD does not interpret for the target.
- Disposition: owner question **Q2**.

**MG-04 — Whether a user call may spend the sleeve, and what it does to the user's payout.** (inventory 3b/3c)
- PRD section: §1.3 FS-OWN-04, §5 FS-MONEY-01 withdrawal bullet, §8 FS-A11.
- Quote: "Refill, shortfall, and whether a locked caller may spend the sleeve are not specified." and "`_withdraw` removes liquidity in proportion to shares and pays pro-rata idle."
- Why two implementors diverge: every user call finds the PoolManager locked, so "a locked caller may spend the sleeve" is the question of whether a redemption is paid out of the local balance. Weir's `_withdraw` pays pro-rata idle from the local balance (E4), which drains the sleeve below the target on every redemption. One implementor mirrors that and lets the target lapse. The other honours the target by withholding `liquidReservePercentageOfVault(address(this))` of each token from the payout, which reduces what the redeeming user receives and is a different money outcome. The "shortfall" half is equally open: nothing says whether a vault below target must report, top up, or is allowed to sit there.
- Disposition: owner question **Q3**.

**MG-05 — The PoolManager binding has no runtime source and no write path.** (inventory 4)
- PRD section: §1.3 FS-OWN-01, §4 FS-PKG-01 and FS-PKG-02, §3 FS-FACET-01.
- Quote: "A `poolManager` address may still be a package binding. How that address is written into the aware repo is not decided here." and "The `poolManager` field is an address binding, not permission to install a family `poolManager()` selector. FS-OWN-01 does not yet say whether that field stays or the aware facet becomes a package input." and "The PoolManager binding comes from the Protocol Aware pair in FS-OWN-01, not from a family `poolManager()` selector."
- Why two implementors diverge: the installed cut in FS-FACET-01 contains no aware facet, so nothing in the package reads an aware repo, yet FS-PKG-02 says the binding comes from the aware pair. One implementor keeps `poolManager` in `PkgInit` and writes it into the V4 aware repo's slot during initialization, following the Crane Aware pattern (E10), which requires the aware facet to join the package and therefore changes the cut, `bindingHash` and the manifest FS-A01 asserts. Another keeps the field and reads it from the family repo, which makes FS-PKG-02's sentence wrong. A third deploys the aware repo as its own contract and binds *that* address, moving the PoolManager's address into a contract the package does not own. The three differ in the deploy flow, in `bindingHash`, in the validation rule "a pool key that is not initialized on the bound manager", and in the FS-A01 selector manifest.
- Disposition: owner question **Q4**.

**MG-06 — The `wrappedNative` binding has no declared home.** (inventory 5)
- PRD section: §1.3 FS-OWN-10, §4 FS-PKG-01 and FS-PKG-02.
- Quote: "This lock does not remove a package address binding, does not decide where that binding is stored, and does not publish an internal compound-or-collect branch." and "A wrapped-native address that is incompatible or collides with the other currency face. `InvalidWrappedNative`."
- Why two implementors diverge: the binding is mandatory at deploy and is read at runtime for a native pool, but its storage is undecided. One implementor holds it in the family repo beside the other `PkgInit` addresses. Another uses the Crane WETH aware pattern (E10), which stores it in `WETHAwareRepo`'s slot and exposes `IWETHAware.weth()` — that adds a `weth()` selector to the diamond and therefore to the FS-A01 manifest, which the PRD never mentions. A third puts it in the V4 aware repo, although a wrapper is not a V4 component under FS-OWN-01's own description. These differ in storage layout and in the installed selector set.
- Disposition: owner question **Q5**.

**MG-07 — Two PRD sentences require a raw-ETH path that an owner lock forbids.** (inventory 6)
- PRD section: §5 FS-MONEY-01 closing bullets versus §1.3 FS-OWN-09 and FS-OWN-10; §8 FS-A10.
- Quote: "Native ETH stays, including native-currency pools and actual ETH payout. A wrapped-native boundary does not remove native operation." and "Native pool entry and payout move ETH, except the inherited wrapper boundary." against the lock: "Raw ETH is not decided and no extension is added." and "The accepted routes use the ERC-20 face on `vaultTokens()`."
- Why two implementors diverge: FS-MONEY-01 and FS-A10 read as "ETH moves at the user boundary"; FS-OWN-09 and FS-OWN-10 read as "the routes are ERC-20 faces only and no payable extension is added". An implementor who follows FS-A10 builds a payable entry and an ETH payout, which is exactly the "extension" FS-OWN-09 forbids and which the accepted Standard Exchange routes do not have (E11, E13). An implementor who follows the locks ships ERC-20-only routes and then fails FS-A10. The phrase "the inherited wrapper boundary" is never defined anywhere in the PRD, so neither reading can be checked. The locks win under the PRD's own precedence rule, so FS-MONEY-01 and FS-A10 are the sentences that must change.
- Disposition: closed by recommendation **R3**, which corrects both sentences.

**MG-08 — The native leg has two possible units and the PRD never picks one.** (new)
- PRD section: §1.3 FS-OWN-04 and FS-OWN-07, §5 FS-MONEY-01 native bullets, §8 FS-A10.
- Quote: "`localReserves()` returns the actual local balances of the underlying tokens." and "`reserves()` returns the local-plus-deployed amount of each vault token, in `vaultTokens()` order."
- Why two implementors diverge: for a native leg the "vault token" is the wrapper's ERC-20 face (E11), the deployed amount is native ETH held by the pool, and the local amount may be native ETH or the face. One implementor keeps native in the local balance and reports wei, matching the sibling baseline's "native booked reserves are ETH measured in wei, not a fictitious ERC-20 balance at address zero". The other holds the face and reports the face balance. If the local term is in one currency and the deployed term in the other, `reserves()` sums two units; the ratio is 1:1 for WETH/ETH, so the error is invisible in value and visible in code, in `reserveOfToken`, and in anything that compares the face balance with the pool's native delta.
- Disposition: owner question **Q6**.

**MG-09 — The query facet's selector set is open, and `poolKey()` exposure is undecided.** (inventory 7)
- PRD section: §3 FS-FACET-01 `queryFacet` row, §4 FS-ARCH-01, §1.3 FS-OWN-02, FS-OWN-06, FS-OWN-10.
- Quote: "Still under function review. Do not install `poolManager()` (FS-OWN-01), a family-only `poolKey()` (FS-OWN-02), `rateAsset()`, `getRate()` (FS-OWN-03), or a family `wrappedNative()` (FS-OWN-10)." and "`poolKey()` stays as information, not as a full-spread-only getter. It belongs to a reusable Uniswap V4 Position Repo for one position in one pool."
- Why two implementors diverge: the locks do determine the family query selectors that must exist — `tickLower()`, `tickUpper()`, `positionLiquidity()` (FS-OWN-06) and `localReserves()` (FS-OWN-04) — so that list is closable (R4). What is not decided is whether the diamond exposes `poolKey()` at all. FS-OWN-02 forbids a *family-only* `poolKey()` and FS-A01 asserts only that a "family-only `poolKey()`" is absent, so a shared Uniswap V4 Position facet carrying `poolKey()` is permitted; but if the Position Repo follows the Crane storage-library pattern (E10) it has no external getter unless a facet is installed, which adds a package input and changes the cut and the FS-A01 manifest. One implementor ships a four-selector query facet and no `poolKey()`; another adds a V4 Position facet and exposes `poolKey()`.
- Disposition: the family selector set is closed by recommendation **R4**; the package membership is owner question **Q7**.

**MG-10 — `reserveOfToken` for a token outside `vaultTokens()` is undefined, and a hook reads it.** (inventory 8, corrected)
- PRD section: §1.2 FS-OWN-07 row, §1.3 FS-OWN-07.
- Quote: "`IBasicVault.reserves()` is the local-plus-deployed view, on a custom facet. Its other semantics are not specified." and "The custom facet exposes only `reserveOfToken` and `reserves`."
- Why two implementors diverge: `IBasicVault` has exactly three members (E7), so the family facet must answer `reserveOfToken` for *any* token, including the share itself and any foreign token. One implementor returns 0; another reverts. The repo's own SE consumer documents the same fork as unresolved and prefers 0 for a peer vault (E12), so neither branch is wrong by precedent. FS-HOOK-01 binds this vault as the buffered leg in six hook families, so the answer is read by hook code. The inventory framing of "other semantics" is not the real issue; the per-token answer outside the token set is.
- Disposition: owner question **Q8**.

**MG-11 — Initialization never says how the shared `vaultTokens()` gets populated.** (new; part of inventory 8)
- PRD section: §4 FS-PKG-02, §1.3 FS-OWN-07, §4 FS-ARCH-01.
- Quote: "Initialization installs the name, symbol, pool key, and full-range ticks. It does not store a designated rate token." and "Reuse `vaultTokens()` from `MultiAssetBasicVaultFacet`. Do not reimplement it."
- Why two implementors diverge: the shared getter reads the stored token set in `MultiAssetBasicVaultRepo` (E8), and the PRD's initialization list does not include writing it. An implementor who does not write that set ships a vault whose `vaultTokens()` is empty, which silently breaks `reserves()` (defined in `vaultTokens()` order), the `amountsIn` order FS-OWN-09 requires, and the `vaultTokens()` order the review file fixes. Another implementor stores the token list in the family repo and re-implements the getter, which FS-OWN-07 forbids. The only conformant route — calling `MultiAssetBasicVaultRepo._initialize` with the two faces — is never written down, and it also means writing into the shared `indexedex.vaults.basic` slot that FS-A04 does not mention.
- Disposition: closed by recommendation **R5**.

**MG-12 — The one-token exit has no home for the pro-rata idle of the currency the user did not select.** (inventory 10)
- PRD section: §5 FS-MONEY-01 withdrawal bullet, §8 FS-A08 and FS-A11.
- Quote: "`_withdraw` removes liquidity in proportion to shares and pays pro-rata idle. This family does not install `zapTo`. The accepted one-token exit still pays only the selected token or reverts. A bundle exit can pay both currencies." and "Single-token exit pays only the selected token or reverts. Shares are not burned if it reverts."
- Why two implementors diverge: Weir pays pro-rata idle in both currencies and converts the unwanted leg only through `zapTo` (E4), and `zapTo` is not installed. One implementor leaves the unwanted currency's pro-rata idle in the vault, so the redeeming user silently forfeits it and the remaining holders gain it at their next exit; another reverts whenever that idle is non-zero, so the exit is unavailable in exactly the state where the user has idle dust. "or reverts" in the PRD does not say which of these it means, and the two are different money outcomes and different route availability.
- Disposition: owner question **Q9**.

**MG-13 — The entry balancing rule and the liquidity formula are never stated.** (new)
- PRD section: §5 FS-MONEY-01 entry-swap bullet, §1.2 FS-X04.
- Quote: "The entry swap, when one is needed, uses `_swap`. Its price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`." and "Single-token entry does not require the selected swap to consume its entire input."
- Why two implementors diverge: the PRD names the swap function and its price limit but never says how much is traded or how the added liquidity is derived. Weir trades half the imbalance and computes the added liquidity with a 2-wei haircut on each amount (E5). One implementor mirrors that. Another swaps the entire single-sided input, which is the common single-token-entry design, and computes liquidity without the haircut. The two mint different shares for the same deposit and leave different local balances, and the difference is exactly the share count a depositor receives.
- Disposition: closed by recommendation **R6**.

**MG-14 — The state of an exhausted vault, and whether it can take deposits again, is unstated.** (new)
- PRD section: §5 FS-MONEY-01 genesis and existing-supply bullets, §8 FS-A05.
- Quote: "When `v.totalShares == 0`, the source rejects `frame.liq <= MIN_SHARES`, assigns `frame.shares = frame.liq - MIN_SHARES`, and sets `v.totalShares = MIN_SHARES`." and "For an existing supply, `frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity`."
- Why two implementors diverge: after every redeemable share is burned, the vault keeps the floor's residual supply and residual liquidity (E6), so the genesis branch is unreachable and the existing-supply branch stays live with the floor in both numerator and denominator. One implementor mirrors that, so a later depositor is diluted by the floor's retained liquidity and the vault never returns to a clean genesis. Another adds a re-genesis branch for "no redeemable shares outstanding", minting `frame.liq - MIN_SHARES` against a reset floor, which is a different issuance rule for the same deposit. The PRD's "the source rejects `frame.liq <= MIN_SHARES`" is written as if a genesis can recur; it cannot.
- Disposition: the arithmetic is closed by recommendation **R7**. Whether the owner wants a re-entry rule is an owner decision, not an implementor one.

**MG-15 — `donate` has no destination and "the vault's book" does not exist here.** (new)
- PRD section: §1.3 FS-OWN-09, §3 FS-FACET-01 money facet row, §5 FS-MONEY-01.
- Quote: "Keep `donate` and `compound`. `donate` is an explicit exception and is not a Weir function." and, in the review file, "`donate(token, amount)` stays. It adds tokens to the vault's book and mints no shares."
- Why two implementors diverge: this family forbids the multi-asset stored balance (E8) and has no per-user book, so "the vault's book" names nothing implementable here. One implementor transfers the tokens into the vault's local balance as idle, which makes them pro-rata redeemable and visible in `localReserves()`. Another routes them into the position, which requires the manager unlocked, changes the share price immediately, and keeps them out of `localReserves()`. A third writes them into the multi-asset repo, which FS-OWN-07 forbids. The PRD also never says whether `donate` may run while the manager is locked, which is the whole point of a donation that does not need the pool.
- Disposition: owner question **Q10**.

**MG-16 — Idle is either a stored counter or the actual balance, and the PRD uses both words.** (new)
- PRD section: §5 FS-MONEY-01 compound and withdrawal bullets, §1.3 FS-OWN-04.
- Quote: "`_compound` harvests fees by a zero-liquidity modification and reinvests the remainder plus idle. Leftover is held as idle." and "`localReserves()` returns the actual local balances of the underlying tokens."
- Why two implementors diverge: Weir keeps `idle0`/`idle1` counters, but this PRD's only idle-facing view returns "the actual local balances". One implementor keeps a counter for the family and pays out the counter, so a donation that moved only the balance is stranded: `localReserves()` shows it, the exit does not pay it, and the two views disagree. The other derives idle from the actual balance, so every donated token is pro-rata redeemable and the views always agree. This decides whether a donation is a gift to all holders or a stranded balance, and it decides whether `localReserves()` and the redemption payout can ever differ.
- Disposition: owner question **Q11**.

**MG-17 — The committed reserves snapshot has no commit point.** (new)
- PRD section: §8 FS-A32, §1.3 FS-OWN-07.
- Quote: "Busy-vault economic views revert. An idle vault answers while the manager is unlocked. Basic reserves return the last committed snapshot."
- Why two implementors diverge: `reserves()` and `reserveOfToken()` cannot be computed live while the manager is mid-unlock, so they are snapshots, while `localReserves()` is live by FS-OWN-04. Nothing says when the snapshot is written: after each planned action, once at the end of the operation, or only when the position changes. An implementor who commits per action and one who commits per operation publish different reserve values for the same vault at the same moment, and `reserves()` can disagree with `localReserves()` for an unbounded window.
- Disposition: owner question **Q12**.

## Questions for the owner

One question each, in gap order. Q10–Q12 are new behavior choices, not clarifications of existing text.

- **Q1 (MG-01).** Is the 1,000-share genesis floor part of this vault's ERC-20 `totalSupply()` — held by no address, so `sum(balanceOf) < totalSupply()` — or is it outside the ERC-20 supply with the existing-supply denominator defined as `MIN_SHARES + totalSupply()`?
- **Q2 (MG-03).** After `_compound` harvests and reinvests, must the vault keep `liquidReservePercentageOfVault(address(this))` of each underlying token's owned amount in local balances, and if so is that amount withheld from the reinvestment rather than deployed?
- **Q3 (MG-04).** When a redemption is paid, does the vault pay the user out of the local balance and let the sleeve fall below the target, or does it retain `liquidReservePercentageOfVault(address(this))` of each token locally and reduce the user's payout by that amount?
- **Q4 (MG-05).** Which artifact is the runtime source of the PoolManager address, and who writes it: the `PkgInit` field written into the V4 aware repo's slot at initialization, the `PkgInit` field held in the family repo, or a separately deployed aware repo contract whose address is the bound field?
- **Q5 (MG-06).** Where is the `wrappedNative` binding read from at runtime — the family repo, the Crane WETH aware repo, which would add `weth()` to the installed selectors, or the V4 aware repo?
- **Q6 (MG-08).** For a native pool leg, does the vault hold native ETH in its local balance and report it in wei in `localReserves()` and `reserves()`, or does it hold the wrapper's ERC-20 face and report that?
- **Q7 (MG-09).** Does the full-spread package install a Uniswap V4 Position facet that exposes `poolKey()` from the Position Repo, or is the Position Repo storage-only, with the family query facet exposing `tickLower()`, `tickUpper()`, `positionLiquidity()` and `localReserves()`?
- **Q8 (MG-10).** What does `reserveOfToken(address)` return for a token that is not in `vaultTokens()`, including the share itself: 0, or a revert?
- **Q9 (MG-12).** When a one-token exit is requested and the vault holds pro-rata idle in the currency the user did not select, does the exit pay only the selected token and leave that idle in the vault for the remaining holders, or does the exit revert?
- **Q10 (MG-15).** Does `donate(token, amount)` transfer the tokens into the vault's local balance as idle that is paid out pro-rata on exit, or does it add them to the position, and may it run while the PoolManager is locked?
- **Q11 (MG-16).** Is idle a stored counter, as in Weir's `idle0`/`idle1`, or is it the vault's actual local balance, so that every donated amount is pro-rata redeemable?
- **Q12 (MG-17).** When is the committed reserves snapshot written: after each planned action, once at the end of the operation, or only when the position changes?

## Recommendations that close a gap

Each is exact replacement prose, with the lock or source line that authorizes it.

- **R1 — FS-MONEY-01, genesis floor (closes the settled half of MG-01).**
  > The floor is part of the same supply counter that the existing-supply branch divides by. `_deposit` sets `v.totalShares = MIN_SHARES` and then adds `frame.shares` to it, so the denominator in the existing-supply branch includes the floor. The floor is credited to no holder, is never redeemable, and is never rescaled.

  Authority: `WeirVaults.sol` `_deposit` — `v.totalShares = MIN_SHARES; ... v.totalShares += frame.shares;` and `sharesOf[id][p.recipient] += frame.shares;`, with `MIN_SHARES = 1_000` marked "locked forever on the first deposit".

- **R2 — FS-MONEY-01, positive credit (closes MG-02).**
  > A positive net delta in any currency, including a currency the depositor did not declare, is transferred out of the vault to the payer of the declared input, exactly as `_deposit` settles `frame.net0` and `frame.net1` to `depositor`. It is not added to idle, is not converted, and is not included in `amountRefunded`, which reports only the unused part of the declared input currency. On the borrowed path the payer is the caller, and `recipient` receives only the route output.

  Authority: `WeirVaults.sol` `_deposit` — `_settle(v.key.currency0, frame.net0, depositor); _settle(v.key.currency1, frame.net1, depositor);` with `abi.encode(p, msg.sender)` in the unlock payload; `deposit` returning `amount - used` of each currency by transfer rather than through a return value. FS-OWN-08 fixes the only return pair.

- **R3 — FS-MONEY-01 and FS-A10, native (closes MG-07).**
  Replace the FS-MONEY-01 sentences "Native ETH stays, including native-currency pools and actual ETH payout. A wrapped-native boundary does not remove native operation." with:
  > Native ETH stays in the pool. A native pool's currency0 is `address(0)` and its ERC-20 face is the `wrappedNative` binding; `vaultTokens()` carries that face at the native leg's index. The accepted entry and exit routes are nonpayable and ERC-20 only: they pull and pay the ERC-20 faces. This family installs no raw-ETH entry and no raw-ETH exit, and the vault converts between a face and the native currency inside its own unlock.

  Replace FS-A10 "Native pool entry and payout move ETH, except the inherited wrapper boundary." with:
  > A native-pool entry and exit move the ERC-20 face of the native leg, never raw ETH, and never `msg.value`. The vault's internal accounting for the native leg is in native wei.

  Authority: FS-OWN-09 ("Raw ETH is not decided and no extension is added"), FS-OWN-10 ("The accepted routes use the ERC-20 face on `vaultTokens()`"), the review file's "`vaultTokens()` order must stay stable, with the wrapped face at a native leg's index", and the Standard Exchange convention already in the repo — `contracts/interfaces/IStandardExchangeInMulti.sol` ("V4 uses PoolKey order with WETH as the ERC20 face of a native currency") and the sibling baseline's "The canonical SE methods are nonpayable and accept ERC-20 addresses". FS-MONEY-01's "actual ETH payout" is removed because under the locks the user never receives ETH.

- **R4 — FS-FACET-01, query facet (closes the settled part of MG-09).**
  > The family query facet installs exactly `tickLower()`, `tickUpper()`, `positionLiquidity()` and `localReserves()`.

  Authority: FS-OWN-06 ("Keep `tickLower()` and `tickUpper()`... Keep `positionLiquidity()`"), FS-OWN-04 ("`localReserves()` returns the actual local balances of the underlying tokens"), FS-OWN-01 and FS-OWN-03 and FS-OWN-10 (the exclusions already listed in the same table row). This adds no selector that a lock does not already keep; Q7 covers whether a shared V4 Position facet is added beside it.

- **R5 — FS-PKG-02, initialization (closes MG-11).**
  > Initialization also calls `MultiAssetBasicVaultRepo._initialize` with the two currency faces, in PoolKey order, with the wrapped face at a native leg's index, so the shared `vaultTokens()` getter returns them. The multi-asset `_reserveOfToken` mapping is never written; `reserveOfToken` and `reserves` come from the family facet.

  Authority: FS-OWN-07 ("Reuse `vaultTokens()` from `MultiAssetBasicVaultFacet`. Do not reimplement it." and "Do not install the multi-asset reserve functions."), FS-PKG-02's initialization requirement, and `contracts/vaults/basic/MultiAssetBasicVaultRepo.sol` — `STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.basic"))`, `AddressSet _vaultTokens`, `function _initialize(address[] memory tokens)`.

- **R6 — FS-MONEY-01, entry balancing (closes MG-13).**
  > The entry balancing mirrors `_balance`: the vault trades half of the imbalance in the pool with `_swap`, and the added liquidity is the `LiquidityAmounts.getLiquidityForAmounts` value `_deposit` computes at the current pool price and the stored ticks, with each amount reduced by 2 wei.

  Authority: `WeirVaults.sol` `_balance` — `x = (a0 - ...) / 2` and `x = (a1 - a0in1) / 2`, both with an early return when `x == 0` — and `_deposit` — `frame.a0 > 2 ? frame.a0 - 2 : 0`, `frame.a1 > 2 ? frame.a1 - 2 : 0`. FS-X04's "does not require the selected swap to consume its entire input" is the half-swap's consequence, not a substitute for stating it.

- **R7 — FS-MONEY-01, exhausted vault (closes the arithmetic of MG-14).**
  > A vault whose redeemable shares are exhausted keeps the floor's residual supply and residual liquidity. The genesis branch is reachable only before the first deposit, and a later deposit uses the existing-supply branch. This PRD adds no re-genesis branch and no second share ledger.

  Authority: `WeirVaults.sol` `_deposit` — the branch condition `v.totalShares == 0` and the else branch `(uint256(frame.liq) * v.totalShares) / v.liquidity` — combined with `_withdraw`'s `v.totalShares = total - w.shares` and `v.liquidity -= liq`, which leave both counters at 1,000.

## Limits

- This is research. Nothing here is an implementation, an approval, a safety clearance, or an owner decision. The twelve questions are the owner's to answer; the seven recommendations are replacement prose to be accepted or rejected by the coordinator and the owner, not applied by me.
- I read the PRD, the review file and `WeirVaults.sol` in full, and a bounded set of repo sources for grounding. I did not read the two accepted reports the PRD defers to (`se-interface-refund-bundle-20261030-01a18660/REPORT.md`, `se-paired-money-necessity-20261030-01a18660/REPORT.md`). Consequently: the exact signatures of `exchangeBundleInForSingleOut`, `previewExchangeBundleInForSingleOut`, `exchangeBundleOut` and `previewExchangeBundleOut` are taken from the PRD's prose, not from the accepted interface; the repo currently ships different names for the multi-asset routes (`previewExchangeInManyToOne`, `exchangeOutOneToMany`, E14). MG-02, MG-12 and Q9 depend on the bundle routes accepting a single-token exit and a single-currency entry; if the accepted bundle interfaces differ from the PRD's description, those three need re-reading against the report.
- The repo's current multi-asset SE interfaces and the sibling PairToken baseline are used as evidence of existing convention only. They carry no authority for this family, which FS-OWN-01 through FS-OWN-10 and §2 keep independent of PairToken.
- I did not evaluate the hook packages' current code, so I cannot say whether any of them actually calls `reserveOfToken` on this vault or requires a rate provider for it. MG-10 (Q8) and the FS-A26 tension noted below are raised from the documented hook contract, not from executed hook behaviour, and no hook row was executed.
- Two non-gap observations, recorded because they will fail a build rather than a review. First, FS-A26 requires the FS-HOOK-02 fixture to complete, while FS-HOOK-02 step 1 and FS-A29 allow that bind to be an unresolved FS-HOOK-04 record; under the brief's rule this is a hook-record procedure and not a gap, but FS-A26 lacks the escape clause FS-A29 has, and an implementor must choose between a red row and a recorded exception. Second, FS-ARCH-01's file list still names "SY money, SY query" facet and target files that FS-OWN-05 drops; that is file layout and not a gap under the brief's rule, but the list contradicts a lock.
- The error identity for the genesis rejection (`frame.liq <= MIN_SHARES`) is also unstated: Weir raises `ZeroShares`, and this PRD's error list names only `InvalidUnlockedContext()` and `SettlementMismatch()`. I did not raise it as a gap because the accepted SE routes carry their own inherited errors and the PRD's error list reads as an enumeration of new errors only; if the owner wants that closed, it belongs with the FS-OWN-08 return-ABI migration.
- I ran no Forge, Git, install, or deployment, and I did not build, test, or simulate any of the states described here. Every divergence claim is a reading of the PRD text against the cited source lines; the arithmetic in E1–E6 was read from `WeirVaults.sol`, not executed.
