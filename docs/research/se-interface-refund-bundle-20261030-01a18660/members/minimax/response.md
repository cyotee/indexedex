# MiniMax member response

## Identity

- Role in this council: council member, MiniMax seat.
- Requested Native selection for this seat: `minimax/MiniMax-M3` with adaptive thinking, not a selectable depth.
- No other Native identity (task id, conversation id, account, billing route, reasoning depth) was exposed to this member, so none is asserted here. Where the coordinator's record differs, the coordinator's record governs.
- Owned artifact for this pass: `docs/research/se-interface-refund-bundle-20261030-01a18660/members/minimax/response.md`.
- This is a research contribution. It grants no implementation authority.

## Question and targets

**Question.** Should the Standard Exchange interface set be redefined so that one `previewExchange`/`exchange` family covers swaps, deposits, and withdrawals, including a same-token refund when an input cannot be fully consumed, and what exact interface definitions does the council recommend?

**Required targets read for this response.** All eight files named in the brief were read from the repository, not from memory:

- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`
- `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol`
- `contracts/interfaces/IStandardExchange.sol`
- `contracts/interfaces/IStandardExchangeInMulti.sol`
- `contracts/interfaces/IStandardExchangeOutMulti.sol`
- `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol`
- `contracts/vaults/basic/IBasicVault.sol`

**Optional context read.** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` and `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.

**Admitted scope honoured.** Read-only on project code and configuration. No implementation, no test, no build, no deploy, no wallet, no Git. The only execution performed was a local read-only keyword/selector computation (`cast sig`, a pure keccak hash of an ASCII signature string); it compiles nothing, runs no project code, and touches no repository state.

## Evidence

Each item below was read or computed in this session.

### E1. The current canonical single-token surface and what it already says about refunds

`IStandardExchangeIn.exchangeIn` returns `uint256 amountOut` only. Its `pretransferred` comment states: *"The declared input is processed only when present unbooked input covers it. Tokens above the declaration are not refunded. A difference between the declaration and the whole surplus does not by itself revert. Booked inventory does not fill a shortfall."* There is no refund return, and the exact-input path never refunds.

`IStandardExchangeOut.exchangeOut` returns `uint256 amountIn` only. Its comment states: *"Exact-output pretransfer refunds only `min(unrecorded balance, maxAmountIn) - used` to `msg.sender`. False-flag exact-output pulls quoted used and refunds nothing."* So a refund already exists on the exact-output pretransfer path, it is already denominated in the input token, and it is already bounded by the caller's ceiling — but it is not observable to the integrator, because it is not a named return and `unrecorded balance` is internal vault state.

`IStandardExchangeErrors` carries `DeadlineExceeded`, `MaxAmountExceeded`, `MinAmountNotMet`, `InvalidRoute`, `RouteNotSupported`, `AmountOutNotMet`, `UnknownReserve`. It declares only errors, so it has no functions and therefore no ERC-165 interface id of its own; the two route interfaces that inherit it each declare one.

### E2. `lib/crane` is a separate repository, and the exchange surface is heavily implemented

`.gitmodules` declares `lib/crane` as a git submodule pointing at `https://github.com/cyotee/crane` at `90203dbc261abe7b6cf03a46cdb8e8c3869b43f2`. `IStandardExchangeIn` and `IStandardExchangeOut` live in that submodule, so a change to their ABI is a cross-repository change.

`grep` over `contracts/` and `lib/` finds **61 `exchangeIn` / `exchangeOut` function definitions across 60 files** (58 production targets, one test stub, one routing library), spanning DETF vaults, Uniswap V4 buffer hooks, Morpho Blue, ERC-4626, Aerodrome, Camelot, Balancer V3, Uniswap V2, Aave, Lido, Rocket Pool, EtherFi, and the Standard Exchange vault families.

`type(IStandardExchangeIn).interfaceId` and `type(IStandardExchangeOut).interfaceId` are advertised in ERC-165 interface lists in at least eight facet files: the V3 full-spread `InFacet` and `InMultiFacet`, the V4 pairToken `MoneyFacet`, `QuoteFacet` and `OutFacet`, and the V4 upperLowerWings `InFacet` and `OutFacet`; the pairToken package behavior test also asserts them.

`IStandardExchange` is a pure aggregate (`is IStandardExchangeIn, IStandardExchangeOut`) with no functions of its own and no `@custom:interfaceid` tag.

### E3. The documented selector and interface-id tags in the two canonical interfaces are stale — reproduced exactly

`IStandardExchangeIn` documents `@custom:selector 0x89d61912` for `previewExchangeIn` and `0x05562cc8` for `exchangeIn`, with `@custom:interfaceid 0x8c8035da`. `IStandardExchangeOut` documents `0xdb149bc5` for `previewExchangeOut` and `0x612d4427` for `exchangeOut`, with `@custom:interfaceid 0xba39dfe2`.

Computed with `cast sig` over the *current* signatures:

| Symbol | Current signature | Computed selector | Tag in file | Match |
| --- | --- | --- | --- | --- |
| `previewExchangeIn` | `(address,uint256,address)` | `0x89d61912` | `0x89d61912` | yes |
| `exchangeIn` | `(address,uint256,address,uint256,address,bool,uint256)` | `0xd02d3063` | `0x05562cc8` | **no** |
| `previewExchangeOut` | `(address,address,uint256)` | `0xdb149bc5` | `0xdb149bc5` | yes |
| `exchangeOut` | `(address,uint256,address,uint256,address,bool,uint256)` | `0xbbac8477` | `0x612d4427` | **no** |

The stale tags are internally consistent with an *older* signature that had no `deadline` parameter: `exchangeIn(address,uint256,address,uint256,address,bool)` hashes to `0x05562cc8` and `exchangeOut(address,uint256,address,uint256,address,bool)` hashes to `0x612d4427`, and each XORs with its preview selector to reproduce the documented interface ids exactly. The tags therefore predate the addition of `deadline`.

The live ERC-165 ids implied by the current signatures are `0x59fb2971` for `IStandardExchangeIn` and `0x60b81fb2` for `IStandardExchangeOut`. `IStandardExchangeInMulti` (`0x20f1017d`) and `IStandardExchangeOutMulti` (`0xc4e1f64c`) carry no `@custom:interfaceid` tag at all, and neither does `IStandardExchangeMultiAssetLiquidity`.

### E4. The multi routes already exist, are dual-only, and explicitly do not refund

`IStandardExchangeInMulti.exchangeInManyToOne(address[] tokenIn, uint256[] amountsIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline)` returns `uint256 amountOut` only, and its `pretransferred` comment repeats *"Tokens above the declaration are not refunded."* Its `tokenIn` is caller-supplied and documented as *"Input token addresses in the vault's declared order. V4 uses PoolKey order with WETH as the ERC20 face of a native currency."* `amountsIn` *"Must be the same length as tokenIn."*

`IStandardExchangeOutMulti.exchangeOutOneToMany(IERC20 tokenIn, uint256 maxAmountIn, address[] tokensOut, uint256[] amountsOut, address recipient, bool pretransferred, uint256 deadline)` is exact-output: `tokenIn` *"Must be vault shares (`address(this)`)"*, `amountsOut` are exact, `maxAmountIn` is the ceiling, and the refund is `min(unrecorded balance, maxAmountIn) - used`, unnamed.

The V3 full-spread implementation confirms the shape: `_isDualPoolCurrencies` requires exactly two tokens in ascending order equal to `_token0()`/`_token1()`, `_dualAmountsPositive` requires both amounts strictly positive, and `_requireExactDelivery` reverts with `TransferDeltaInsufficient` on any shortfall — i.e. today a bundle leg is all-or-revert. The one-to-many exit computes `sharesToBurn` from both legs and requires `s0 == s1` or it reverts `ExchangeOutNotAvailable`.

### E5. The refund mechanism and its safety rule already exist in the vault layer

`contracts/utils/LocalCreditLib.sol` defines the canonical arithmetic: `available(balance, booked) = balance > booked ? balance - booked : 0` and `budget(available, maximum) = min(available, maximum)`. `contracts/interfaces/ISecurePullErrors.sol` states the invariant directly: *"Surplus refunds (E6) pay only this-call unused inbound, never booked `R`."*

`UniswapV3FullSpreadStandardExchangeVaultCommon._secureTokenTransfer` implements the pull path (pulls `amountIn`, requires `actualIn == amountIn`, else `TransferDeltaInsufficient`) and the pretransfer path (requires `available(balanceOf, reserveOfToken) >= amountIn`). `_pretransferCredit` is `budget(available(...), maximum)`. `_refundUnusedShares` pays `delivered - used` back to a recipient.

The pairToken family already runs an explicit refund ledger. `UniswapV4PairTokenStandardExchangeVaultExecution` maintains `run.state.inventory.refund.amount0` and pays it with `_send(run_, address(0), msg.sender, refund)` — a raw-ETH transfer when the input was native. `_send` checks the recipient's balance delta and the vault's own balance delta and reverts `SettlementMismatch` if the transfer did not land exactly. `Math.pairedQuote` computes *accepted* amounts against two maxima, and the `depositPair` interface comment says: *"Deposit accepted portions of two maxima after incumbent maintenance. Native pools require amount0Max as msg.value and refund only unused ETH."*

The pairToken disclosure convention is therefore already "used vs remainder", not "refund": `previewDepositPair(amount0Max_, amount1Max_)` returns `(shares, used0, used1)`; `previewZapCredit(tokenIn_, amountIn_)` returns `(shares, credit0, credit1, uncredited0, uncredited1)`; the `PairDeposited` event carries `used0, used1`; the `ZapCredit` event carries `uncredited0, uncredited1`. `depositPair` itself returns only `uint256 shares` — the refund is evented, never returned. That is precisely the gap the owner identified.

### E6. `vaultTokens()` is the canonical, vault-owned token list, and it excludes the share token

`IBasicVault.vaultTokens()` returns `address[] memory tokens_` and is documented as *"Returns the tokens this vault will accept/produce for exchanges."* `MultiAssetBasicVaultRepo` stores it as an `AddressSet` (insertion-ordered) under slot `keccak256(abi.encode("indexedex.vaults.basic"))`, with `reserves()` indexed in the same order.

The V3 full-spread package initializes it with exactly two entries: `tokens[0] = token0; tokens[1] = token1;`. The share token is **not** in the list, even though `_syncVaultReserves` books a reserve for `address(this)`. So `vaultTokens()` order covers the vault's underlying tokens only, and the share token is the token *paid* on an exit, not one of the `amountsIn` legs.

### E7. The native/ERC-20 face convention is already decided in the code

The V4 pairToken package builds its token list with `_faces(poolKey)`: `faces_[0] = Currency.unwrap(key_.currency0); if (faces_[0] == address(0)) faces_[0] = WRAPPED_NATIVE; faces_[1] = Currency.unwrap(key_.currency1);`. So the vault-level token list uses the **wrapped ERC-20 face** for a native currency, while `address(0)` is used as the internal native sentinel inside the execution and quote layers (`_validToken`, `_balance`, `_value`).

The existing multi-route comments agree: *"V4 uses PoolKey order with WETH as the ERC20 face of a native currency."* The `WithdrawalSale` event comment is explicit that the *interface* accepts both representations: *"tokenOut identifies the requested raw-native or ERC-20-face representation."* So the repo's convention is: **ERC-20 face canonical for lists and reserves; `address(0)` accepted as a raw-native alias at the execution boundary; the refund follows the caller's representation.**

### E8. `IStandardExchangeMultiAssetLiquidity` forbids merging, and its shape is a different operation

Its header states: *"Canonical `IStandardExchangeIn` / `IStandardExchangeOut` remain **swap-only**. This interface is a separate liquidity extension — do not merge selectors into In/Out."* Its surface is `joinProportional` / `exitProportional` / `joinUnbalanced` / `joinSingleAssetExactIn` / `exitSingleAssetExactBptIn` / `exitSingleAssetExactTokenOut` and aliases — i.e. inventory routes (tokens ⇄ shares), documented as *"1:1 with the host hook liquidity ABI when used by Uni V4 SE Weighted Buffer Hook."* It is product-scoped, not Standard-Exchange-scoped.

### E9. The newest family does not use the canonical Standard Exchange interfaces at all

`contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol` declares its own surface (`depositPair`, `redeemPair`, `donate`, `compound`, `previewZapCredit`, `previewWithdrawalMode`, `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `maxZapBps`, …) and does not inherit `IStandardExchangeIn` or `IStandardExchangeOut`. The owner-proposed bundle family is therefore not a mutation of a surface the newest vault uses — it is a chance to give the newest family the canonical interface it currently lacks.

### E10. Nothing named `*Bundle*` exists yet

`grep` for `BundleInForSingleOut`, `BundleOut`, and `previewExchangeBundle` across `contracts/` and `lib/` returns no matches. Both proposed bundle interfaces are entirely new surface.

## Assumptions

Each of these is a **recommendation by this member**, not an owner decision, and each is resolved in a specific direction so the definitions below are unambiguous.

- **A1 — The refund return does not change `exchangeIn` / `exchangeOut`.** Recommendation: the refund appears only on new functions, because Solidity cannot overload by return type and changing a return type changes the selector. Evidence E1, E2, E3.
- **A2 — "Array of tokens they expect to receive back" means addresses *and* amounts.** Recommendation: two parallel arrays, `tokensOut[]` and `amountsOut[]`, because the route is exact-output and an exact-output route must pin the output amounts. This matches the existing `exchangeOutOneToMany(tokensOut, amountsOut)` precedent.
- **A3 — `exchangeBundleOut` is exact-output.** Recommendation: the caller pins the output amounts; the vault quotes the input and the charge is bounded by `maxAmountIn`. Rationale: (i) the `In`/`Out` naming convention in this codebase means "the caller pins the input amount" for `...In...` and "the caller pins the output amount" for `...Out...`; (ii) `exchangeOutOneToMany`, the closest analogue, is exact-output; (iii) the owner's description names an address for the pay token and no amount, which is only coherent if the input is quoted.
- **A4 — `vaultTokens()` order is the only legal input order, and the caller does not pass a token array for the inputs.** Recommendation: `amountsIn` is positional against `IBasicVault.vaultTokens()`, and `amountsIn.length` must equal `vaultTokens().length`. Rationale: it removes the possibility of a caller-supplied list disagreeing with the vault's book, and it lets one call site work across every vault of the family. Evidence E6.
- **A5 — Output order is free; input order is not.** Recommendation: `exchangeBundleOut` takes `tokensOut[]` in the caller's order with explicit amounts, matched by address rather than by position, and the vault rejects any token it cannot deliver on that route.
- **A6 — The Standard Exchange surface stays ERC-20-faced.** Recommendation: the token lists and the refund are denominated in ERC-20 faces; `address(0)` is not a legal token in these interfaces, and native value entry remains a separate, product-level surface (the pairToken family already owns it with a `payable` `depositPair`). Rationale: `vaultTokens()` and `reserveOfToken` book ERC-20 balances, the multi routes already document the WETH face, and the owner requires the refund to be processable by every integration. Cost of this choice, stated plainly: an integrator that wants to enter a V4 native pool must wrap to the ERC-20 face, exactly as the existing multi routes require. Evidence E7.
- **A7 — A zero leg is legal.** Recommendation: `amountsIn[i] == 0` means "this leg is not supplied"; nothing is pulled, nothing is consumed, and `amountsInRefund[i] == 0`. This makes the bundle route a strict generalization that also covers the single-token case.
- **A8 — Previews return the expected refund only where the refund is a function of the vault's own plan.** Recommendation: exact-input previews return the expected refund; exact-output previews do not, because that refund is bounded by the caller's `maxAmountIn` and by the caller's own unbooked credit and therefore is not quotable from the vault's quote alone. Evidence E5, E1.
- **A9 — New errors live with the new interfaces.** Recommendation: no edit to `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol`, so the shared framework change is zero and the submodule is untouched. Evidence E2.
- **A10 — The liquidity extension stays out of the unified family.** Recommendation: `IStandardExchangeMultiAssetLiquidity` is not inherited by the aggregate interface and its selectors are not merged. Evidence E8.

## Coverage

**Covered, with evidence.** The current canonical surface and its refund comments (E1). The cost of a breaking ABI change and the cross-repository position of `lib/crane` (E2). The stale selector and interface-id metadata (E3). The existing multi routes, their dual-only shape, their token-array convention, and their "not refunded" clause (E4). The refund arithmetic, the "never booked `R`" invariant, the settlement check, and the pairToken's used/uncredited disclosure convention (E5). `vaultTokens()` as the canonical vault-owned order and the exclusion of the share token (E6). The native/ERC-20 face convention (E7). The liquidity extension's non-merge lock and its different operation shape (E8). The absence of any existing bundle interface (E10). The newest family's use of a private surface rather than the canonical one (E9).

**Deliberately not covered.** No implementation, no test, no build, no deploy, no Git, no wallet, no configuration change — all prohibited by the brief. No public web search; the question is answerable entirely from the repository, and the brief does not require it. No re-derivation of the full-spread PRD's economics, position sizing, or zap limits: those are product law for the V4 full-spread family, not interface law, and the brief forbids treating the optional notes as the interface law. No decision on the deprecated multi interfaces' removal date, which is a migration-plan question for the owner.

**Gaps the owner must close.** Two decisions are load-bearing and are not mine to make: (i) whether the legacy `exchangeIn` / `exchangeOut` stay in the advertised ERC-165 set once the refund-aware variants exist, or whether the legacy pair is retired in the same change; (ii) whether the refund is paid to `msg.sender` always, or whether a separate `refundRecipient` parameter is added. This response assumes `msg.sender` throughout, matching the existing exact-output behavior.

## Conclusions

### C0. Direct answer

**Recommendation: yes, redefine the Standard Exchange interface set — but additively, not by mutation.**

The owner is right that the standard has a gap: the canonical surface has no way to tell an integrator that an input was only partly consumed, even though the exact-output pretransfer path already performs such a refund internally and even though the newest vault family already runs an explicit refund ledger and an "uncredited remainder" disclosure. The gap is real and worth closing at the standard level.

But the redefinition should be **additive**: `IStandardExchangeIn` and `IStandardExchangeOut` keep their selectors and their strict meaning, and the refund-aware and bundle routes are new interfaces beside them. The reason is not preference; it is that the two canonical interfaces live in a git submodule that is a separate repository, they are advertised by ERC-165 in at least eight facet files, and they have 61 implementations across 60 files in this monorepo. A return-type change is a selector change (E2, E3), so "extend `exchangeIn` in place" is not available as a cheap option.

The unified family is delivered as a **narrowly-typed function family under one naming law**, not as one mega-function. A single `previewExchange`/`exchange` with a mode enum would need a union argument struct that carries swap, deposit, and withdrawal fields simultaneously, would have to encode three different slippage vocabularies (`minAmountOut`, `maxAmountIn`, `sharesMin`, `amountsMin`) in one blob, and would give the integrator strictly less type safety than the current per-mode interfaces. The single-integration-point goal is met by an aggregate interface that inherits the leaves, which is exactly the pattern `IStandardExchange` already uses.

### C1. The refund law (recommended NatSpec text, to be carried by every new execution function)

> A Standard Exchange execution returns the amount of the caller's declared input that the vault did not consume and returned to the caller in the same call, denominated in the input token. `refund = declaredInput - consumedInput`, per input token, and `consumedInput <= declaredInput`. The refund is paid to `msg.sender` in the same call. A refund is funded only by input that arrived in this call; booked vault reserves never fund a refund. Input above the declaration is never refunded. A vault that cannot consume the whole declared input executes with the part it can consume and refunds the remainder; it does not revert on the unconsumed remainder alone.

Supporting clauses:

- The refund follows the token the user provided, so an integration that can process every underlying token can process the refund (owner's constraint). Evidence E7.
- The "never booked `R`" rule is the existing `ISecurePullErrors` invariant and must survive into the new routes. Evidence E5.
- The settlement check must survive too: after paying a refund the vault should assert that the refund landed exactly, as `UniswapV4PairTokenStandardExchangeVaultExecution._send` does, and revert `RefundNotSettled(expected, actual)` otherwise. Evidence E5.
- The exact-output refund is bounded by the caller's ceiling and by the caller's own unbooked credit, and is mirrored from the existing rule `min(unrecorded balance, maxAmountIn) - used`. Evidence E1, E5.
- Pretransfer discipline is unchanged: atomic transfer-and-consume, `EOAPretransferNotAllowed()` for callers with no bytecode, and the declaration bounds the credit.

### C2. Recommended interface definitions

Four new files. None of them edits an existing file.

#### C2.1 `contracts/interfaces/IStandardExchangeRefundable.sol` — NEW, sits beside `IStandardExchangeIn` / `IStandardExchangeOut`

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title IStandardExchangeRefundable
 * @notice Refund-aware single-token Standard Exchange routes.
 * @dev Sits beside `IStandardExchangeIn` and `IStandardExchangeOut`. Those two keep their
 *      current selectors and their current strict meaning: the vault consumes the whole
 *      declared input or the call reverts. This interface adds the lenient meaning: the
 *      vault may consume less than the declared input, executes anyway, and returns the
 *      unconsumed part to the caller in the same token inside the same call.
 * @custom:interfaceid 0xc174ea8b
 */
interface IStandardExchangeRefundable {
    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice A declared refund did not settle exactly.
     * @param expected The refund amount the vault said it would pay.
     * @param actual The refund amount the vault could prove it paid.
     */
    error RefundNotSettled(uint256 expected, uint256 actual);

    /* ---------------------------------------------------------------------- */
    /*                                FUNCTIONS                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Quote an exact-input exchange and the refund it would leave behind.
     * @param tokenIn The token the caller provides to the vault for an exchange.
     * @param amountIn The amount of `tokenIn` the caller declares.
     * @param tokenOut The token the caller wishes to receive.
     * @return amountOut The amount of `tokenOut` the caller would receive.
     * @return amountInRefund The amount of `tokenIn` the vault would not consume and would return.
     * @custom:signature previewExchangeInWithRefund(address,uint256,address)
     * @custom:selector 0xc2bbe93f
     */
    function previewExchangeInWithRefund(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountInRefund);

    /**
     * @notice Exact-input exchange that refunds the unconsumed part of `amountIn` in `tokenIn`.
     * @dev `amountInRefund == amountIn - consumed` and `consumed <= amountIn`. The refund is
     *      paid to `msg.sender` in the same call, in `tokenIn`, from input that arrived in this
     *      call only; booked vault reserves never fund a refund. Input above the declaration is
     *      never refunded. A vault that cannot consume the whole declared input executes with
     *      the part it can consume and refunds the remainder; it does not revert on the
     *      unconsumed remainder alone. The vault settles the refund exactly or reverts
     *      `RefundNotSettled(expected, actual)`.
     * @param tokenIn The token provided to the vault for an exchange.
     * @param amountIn The amount of `tokenIn` the caller declares.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @param minAmountOut The minimum amount of `tokenOut` the caller is willing to accept.
     * @param recipient The address to receive the `tokenOut` tokens.
     * @param pretransferred Integrating-contract flag only. The caller must transfer and consume atomically; staged use is at integrator risk with no ownership or timing guarantee. Callers with no bytecode revert `EOAPretransferNotAllowed()`. The declared input is processed only when present unbooked input covers it. Booked inventory does not fill a shortfall.
     * @param deadline The timestamp after which the transaction will revert.
     * @return amountOut The amount of `tokenOut` the caller received.
     * @return amountInRefund The amount of `tokenIn` returned to the caller in this call.
     * @custom:signature exchangeInWithRefund(address,uint256,address,uint256,address,bool,uint256)
     * @custom:selector 0xa5d52038
     */
    function exchangeInWithRefund(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountInRefund);

    /**
     * @notice Exact-output exchange that names the unused part of the provided input.
     * @dev The refund is bounded by `maxAmountIn` and by the caller's own unbooked credit, so it
     *      is not a function of the vault's quote and no preview states it. On the pretransfer
     *      path it is `min(unrecorded balance, maxAmountIn) - used`; on the pull path the vault
     *      pulls only what it consumes and the refund is zero.
     * @param tokenIn The token provided to the vault for an exchange.
     * @param maxAmountIn The maximum amount of `tokenIn` the caller is willing to provide.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @param amountOut The amount of `tokenOut` the caller wishes to receive.
     * @param recipient The address to receive the `tokenOut` tokens.
     * @param pretransferred Integrating-contract flag only. Transfer-and-consume must be atomic to avoid exposing resting credit; staged use is at integrator risk with no ownership or timing guarantee. Callers with no bytecode revert `EOAPretransferNotAllowed()`. Booked holder backing is never pretransfer credit.
     * @param deadline The timestamp after which the transaction will revert.
     * @return amountIn The amount of `tokenIn` the caller consumed.
     * @return amountInRefund The amount of `tokenIn` returned to the caller in this call.
     * @custom:signature exchangeOutWithRefund(address,uint256,address,uint256,address,bool,uint256)
     * @custom:selector 0xa61a238c
     */
    function exchangeOutWithRefund(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn, uint256 amountInRefund);
}
```

**Relation:** sits beside `IStandardExchangeIn` and `IStandardExchangeOut`. It replaces nothing. It extends the *family*, not the existing functions.

**Computed interface id:** `0xc174ea8b` = `0xc2bbe93f ^ 0xa5d52038 ^ 0xa61a238c`. Verify with `type(IStandardExchangeRefundable).interfaceId` at implementation time.

#### C2.2 `contracts/interfaces/IStandardExchangeBundleInForSingleOut.sol` — NEW, supersedes `IStandardExchangeInMulti`

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title IStandardExchangeBundleInForSingleOut
 * @notice Many-token-in, single-token-out Standard Exchange route, with a per-leg refund.
 * @dev Generalizes `IStandardExchangeInMulti` to any number of vault tokens and adds the
 *      per-leg refund that the multi route explicitly does not provide. `amountsIn` is
 *      positional against the vault's own `vaultTokens()` order; the caller passes no token
 *      array, so a caller cannot disagree with the vault's book. The vault MUST implement
 *      `IBasicVault.vaultTokens()` for this route to be callable.
 * @custom:interfaceid 0x2576ed1a
 */
interface IStandardExchangeBundleInForSingleOut {
    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice The supplied amounts do not line up with the vault's token list.
     * @param expected The number of entries in `vaultTokens()`.
     * @param actual The number of entries the caller supplied.
     */
    error BundleAmountsLengthMismatch(uint256 expected, uint256 actual);

    /**
     * @notice A token is not one this route can use.
     * @param token The unsupported token.
     */
    error TokenNotSupported(address token);

    /* ---------------------------------------------------------------------- */
    /*                                FUNCTIONS                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Quote a many-in, single-out exchange and the per-leg refunds it would leave.
     * @param amountsIn The amounts of each vault token the caller declares, in `vaultTokens()` order. Must be the same length as `vaultTokens()`. A zero entry means that leg is not supplied.
     * @param tokenOut The single token the caller wishes to receive.
     * @return amountOut The amount of `tokenOut` the caller would receive.
     * @return amountsInRefund The per-leg refunds, in `vaultTokens()` order. `amountsInRefund[i] == amountsIn[i] - consumed[i]`.
     * @custom:signature previewExchangeBundleInForSingleOut(uint256[],address)
     * @custom:selector 0xc2fe8c7c
     */
    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut, uint256[] memory amountsInRefund);

    /**
     * @notice Many-in, single-out exchange that refunds each unconsumed leg in its own token.
     * @dev Each leg is settled independently: `amountsInRefund[i] == amountsIn[i] - consumed[i]`
     *      with `consumed[i] <= amountsIn[i]`, paid to `msg.sender` in the same call in the same
     *      token the caller supplied for that leg. Refunds are funded only by input that arrived
     *      in this call; booked vault reserves never fund a refund. Input above a declaration is
     *      never refunded. A leg that cannot be fully consumed does not revert the call on its
     *      own. The vault settles every refund exactly or reverts `RefundNotSettled(expected, actual)`.
     * @param amountsIn The amounts of each vault token the caller declares, in `vaultTokens()` order. Must be the same length as `vaultTokens()`. A zero entry means that leg is not supplied.
     * @param tokenOut The single token the caller wishes to receive.
     * @param minAmountOut The minimum amount of `tokenOut` the caller is willing to accept.
     * @param recipient The address to receive the `tokenOut` tokens.
     * @param pretransferred Integrating-contract flag only. The caller must transfer and consume atomically; staged use is at integrator risk with no ownership or timing guarantee. Callers with no bytecode revert `EOAPretransferNotAllowed()`. The declared input is processed only when present unbooked input covers it. Booked inventory does not fill a shortfall.
     * @param deadline The timestamp after which the transaction will revert.
     * @return amountOut The amount of `tokenOut` the caller received.
     * @return amountsInRefund The per-leg refunds, in `vaultTokens()` order.
     * @custom:signature exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)
     * @custom:selector 0xe7886166
     */
    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsInRefund);
}
```

**Relation:** sits beside `IStandardExchangeInMulti`, and **supersedes it** as the canonical many-in/one-out route. It does not replace `IStandardExchangeInMulti` in the same change: `exchangeInManyToOne` takes a caller-supplied token array, is dual-only, requires both amounts strictly positive, and never refunds; `exchangeBundleInForSingleOut` takes amounts in the vault's own order, accepts any arity, permits a zero leg, and refunds per leg. Recommended sequence: ship the bundle route as canonical, mark `IStandardExchangeInMulti` deprecated in NatSpec, re-express the multi implementations on top of the bundle route, and retire `IStandardExchangeInMulti` later. Removing it in the same change is not recommended — it would break integrators for no gain.

**Computed interface id:** `0x2576ed1a` = `0xc2fe8c7c ^ 0xe7886166`.

#### C2.3 `contracts/interfaces/IStandardExchangeBundleOut.sol` — NEW, supersedes `IStandardExchangeOutMulti`

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/**
 * @title IStandardExchangeBundleOut
 * @notice Single-token-in, many-token-out Standard Exchange route, with a named input refund.
 * @dev Generalizes `IStandardExchangeOutMulti` to any number of output tokens. The route is
 *      exact-output: the caller pins the exact `amountsOut` it wants to receive and the vault
 *      quotes and charges the single input, bounded by `maxAmountIn`. The caller supplies the
 *      output tokens as explicit addresses with explicit amounts, matched by address rather
 *      than by position, so the output order is the caller's choice.
 * @custom:interfaceid 0x2cb69aac
 */
interface IStandardExchangeBundleOut {
    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice The supplied output token and amount arrays do not line up.
     * @param expected The number of entries in one array.
     * @param actual The number of entries in the other.
     */
    error BundleTokensLengthMismatch(uint256 expected, uint256 actual);

    /**
     * @notice A token is not one this route can use.
     * @param token The unsupported token.
     */
    error TokenNotSupported(address token);

    /* ---------------------------------------------------------------------- */
    /*                                FUNCTIONS                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Quote an exact-output exchange into a bundle of tokens.
     * @param tokenIn The single token the caller pays with.
     * @param tokensOut The output tokens the caller wants to receive. Matched by address, not by position.
     * @param amountsOut The exact amount of each entry of `tokensOut` the caller wants to receive. Must be the same length as `tokensOut`.
     * @return amountIn The amount of `tokenIn` the exchange would cost.
     * @custom:signature previewExchangeBundleOut(address,address[],uint256[])
     * @custom:selector 0x3d2faecd
     */
    function previewExchangeBundleOut(
        IERC20 tokenIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut
    ) external view returns (uint256 amountIn);

    /**
     * @notice Exact-output exchange into a bundle of tokens, naming the unused part of the input.
     * @dev The outputs are exact: the vault delivers every requested amount or the call reverts.
     *      The refund is of the single input token only: `amountInRefund == provided - consumed`,
     *      bounded by `maxAmountIn` and by the caller's own unbooked credit, paid to `msg.sender`
     *      in the same call. Refunds are funded only by input that arrived in this call; booked
     *      vault reserves never fund a refund. The vault settles the refund exactly or reverts
     *      `RefundNotSettled(expected, actual)`.
     * @param tokenIn The single token the caller pays with.
     * @param maxAmountIn The maximum amount of `tokenIn` the caller is willing to provide.
     * @param tokensOut The output tokens the caller wants to receive. Matched by address, not by position.
     * @param amountsOut The exact amount of each entry of `tokensOut` the caller wants to receive. Must be the same length as `tokensOut`.
     * @param recipient The address to receive the output tokens.
     * @param pretransferred Integrating-contract flag only. Transfer-and-consume must be atomic to avoid exposing resting credit; staged use is at integrator risk with no ownership or timing guarantee. Callers with no bytecode revert `EOAPretransferNotAllowed()`. Booked holder backing is never pretransfer credit. Amounts above `maxAmountIn` are never refunded.
     * @param deadline The timestamp after which the transaction will revert.
     * @return amountIn The amount of `tokenIn` the caller consumed.
     * @return amountInRefund The amount of `tokenIn` returned to the caller in this call.
     * @custom:signature exchangeBundleOut(address,uint256,address[],uint256[],address,bool,uint256)
     * @custom:selector 0x11993461
     */
    function exchangeBundleOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountIn, uint256 amountInRefund);
}
```

**Relation:** sits beside `IStandardExchangeOutMulti`, and **supersedes it** as the canonical one-in/many-out route, on the same migration sequence as C2.2.

**Computed interface id:** `0x2cb69aac` = `0x3d2faecd ^ 0x11993461`.

#### C2.4 `contracts/interfaces/IStandardExchangeFull.sol` — NEW aggregate, sits beside `IStandardExchange`

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeRefundable} from "./IStandardExchangeRefundable.sol";
import {IStandardExchangeBundleInForSingleOut} from "./IStandardExchangeBundleInForSingleOut.sol";
import {IStandardExchangeBundleOut} from "./IStandardExchangeBundleOut.sol";

/**
 * @title IStandardExchangeFull
 * @notice The canonical Standard Exchange surface: swaps, multi-leg swaps, and the
 *         refund-aware single-token and bundle routes, behind one integration type.
 * @dev This aggregate exists so an integrator holds one interface type while still making
 *      narrowly typed calls. It deliberately does NOT inherit `IStandardExchangeInMulti` or
 *      `IStandardExchangeOutMulti`: the bundle routes supersede them. It deliberately does NOT
 *      inherit `IStandardExchangeMultiAssetLiquidity`: that interface is a separate liquidity
 *      extension and its own header forbids merging its selectors into In/Out.
 *      Note for ERC-165: Solidity's `type(I).interfaceId` XORs only the functions declared in
 *      the interface itself and excludes inherited ones, so an aggregate that only inherits has
 *      no usable id of its own. Verify this at implementation time and advertise the leaf
 *      interface ids (`0x59fb2971`, `0x60b81fb2`, `0xc174ea8b`, `0x2576ed1a`, `0x2cb69aac`)
 *      rather than an aggregate id.
 */
interface IStandardExchangeFull is
    IStandardExchangeIn,
    IStandardExchangeOut,
    IStandardExchangeRefundable,
    IStandardExchangeBundleInForSingleOut,
    IStandardExchangeBundleOut
{}
```

**Relation:** sits beside `IStandardExchange`, which is left untouched so that the meaning of `supportsInterface(IStandardExchange)` does not change for existing integrators. Extending `IStandardExchange` in place was considered and rejected: it would silently change what a vault must implement to claim that id.

### C3. Relation table — every current surface

| Current surface | Recommendation | Relation |
| --- | --- | --- |
| `IStandardExchangeIn` (`lib/crane`) | Keep both functions and both selectors. Update NatSpec only: state the refund law, state that `exchangeIn` keeps its strict meaning, and point at `IStandardExchangeRefundable`. Correct the stale `@custom:selector` for `exchangeIn` to `0xd02d3063` and `@custom:interfaceid` to `0x59fb2971`. | **Extends** (documentation and metadata only; no selector change) |
| `IStandardExchangeOut` (`lib/crane`) | Keep both functions and both selectors. Update NatSpec only: name the existing pretransfer refund and point at `exchangeOutWithRefund`. Correct the stale `@custom:selector` for `exchangeOut` to `0xbbac8477` and `@custom:interfaceid` to `0x60b81fb2`. | **Extends** (documentation and metadata only; no selector change) |
| `IStandardExchangeErrors` (`lib/crane`) | Leave untouched. New errors live in the new interfaces (A9). | **Sits beside**, unchanged |
| `IStandardExchange` (`contracts/interfaces`) | Leave untouched. `IStandardExchangeFull` replaces its role as the integration type. | **Sits beside**, unchanged |
| `IStandardExchangeInMulti` (`contracts/interfaces`) | Keep, mark deprecated. Its capability is generalized by `IStandardExchangeBundleInForSingleOut`. Add the missing `@custom:interfaceid 0x20f1017d`. | **Sits beside**, superseded by C2.2 |
| `IStandardExchangeOutMulti` (`contracts/interfaces`) | Keep, mark deprecated. Its capability is generalized by `IStandardExchangeBundleOut`. Add the missing `@custom:interfaceid 0xc4e1f64c`. | **Sits beside**, superseded by C2.3 |
| `IStandardExchangeMultiAssetLiquidity` (`contracts/interfaces`) | Leave untouched and out of the aggregate. Its own header forbids merging. Add the missing `@custom:interfaceid`. | **Sits beside**, unchanged, explicitly not merged |
| `IStandardExchangeRefundable` (new) | New refund-aware single-token routes. | **Sits beside** In/Out |
| `IStandardExchangeBundleInForSingleOut` (new) | New many-in/one-out route with per-leg refunds. | **Sits beside**, supersedes `IStandardExchangeInMulti` |
| `IStandardExchangeBundleOut` (new) | New one-in/many-out route with a named input refund. | **Sits beside**, supersedes `IStandardExchangeOutMulti` |
| `IStandardExchangeFull` (new) | The single integration type. | **Sits beside** `IStandardExchange` |

### C4. How the family covers "swaps, deposits, and withdrawals" — and where the boundary is

**Recommendation: the Standard Exchange family is the *conversion* surface; the liquidity extension stays the *inventory* surface.** The family already covers all three money shapes the owner named, without merging the liquidity extension:

- **Swap** — `exchangeIn` / `exchangeOut` (token → token) and `exchangeInWithRefund` / `exchangeOutWithRefund`.
- **Deposit** — `exchangeIn` and `exchangeInWithRefund` with `tokenOut` being the vault's share token, and `exchangeBundleInForSingleOut` with `tokenOut` being the share token, which is the generalized many-token deposit.
- **Withdrawal** — `exchangeOut` and `exchangeOutWithRefund` with `tokenIn` being the share token, and `exchangeBundleOut` with `tokenIn` being the share token and `tokensOut` the vault's tokens, which is the generalized many-token withdrawal.

The boundary is that `IStandardExchangeMultiAssetLiquidity` is not a conversion surface: it is a 1:1 mirror of the Uni V4 SE Weighted Buffer hook liquidity ABI and its own header forbids merging its selectors into In/Out (E8). Merging it would break a stated lock and would mix two different economic operations (inventory proportion versus conversion) into one family. The owner should treat "one family covers swaps, deposits, and withdrawals" as satisfied by the conversion routes above, and the Weighted Buffer liquidity ABI as an adjacent, deliberately separate standard.

### C5. Answers to the specific ambiguities the brief required to be resolved

1. **"Array of tokens they expect to receive back" — addresses, amounts, or both?** Recommendation: **both**, as parallel arrays `tokensOut[]` and `amountsOut[]`, matching the existing `exchangeOutOneToMany(tokensOut, amountsOut)` precedent and required because the route is exact-output.
2. **Does the refund return change `exchangeIn` / `exchangeOut`?** Recommendation: **no.** It applies only to new functions. Changing a return type changes the selector, and the existing pair is advertised by ERC-165 in eight facets and implemented in 61 places across 60 files in a separate-repository submodule (E2, E3).
3. **Relation to `IStandardExchangeInMulti` / `IStandardExchangeOutMulti`.** Recommendation: the new bundle interfaces are their generalized, refund-aware successors. Keep both legacy interfaces alive but deprecated; migrate implementations; retire later. The legacy multi route's "surplus input is not refunded" clause stays true of the legacy function and becomes false of its successor.
4. **Relation to `IStandardExchangeMultiAssetLiquidity`.** Recommendation: untouched and not merged (E8).
5. **Native ETH as `address(0)` versus an ERC-20 face.** Recommendation: **ERC-20 face** in the Standard Exchange surface. `vaultTokens()` lists the wrapped face, `reserveOfToken` books ERC-20 balances, the multi routes already document the WETH face, and the refund must be processable by every integration. `address(0)` remains the internal native sentinel in the execution layer and the raw-native alias the pairToken interface already accepts at its own boundary (E7). The cost is that an integrator entering a V4 native pool wraps to the ERC-20 face, exactly as today.
6. **Is `vaultTokens()` order the only legal input order?** Recommendation: **yes** for inputs, and the caller passes no token array for inputs, so there is no second order to choose. Output order is free and matched by address.
7. **What does the preview return for a refund, given a preview cannot transfer?** Recommendation: the expected refund, as a value, on the exact-input routes only — `previewExchangeInWithRefund` returns `(amountOut, amountInRefund)` and `previewExchangeBundleInForSingleOut` returns `(amountOut, amountsInRefund[])`. The vault can compute these because the refund is a function of the declared input and its own plan (its caps and its quote). The exact-output previews do not state a refund, because there it is a function of the caller's `maxAmountIn` and the caller's own unbooked credit, which the vault's quote does not determine. The previewed refund is advisory; the execution return is authoritative.

### C6. Two defects found in the admitted interfaces, worth fixing in the same redefinition

These are findings about the admitted targets, not about the owner's proposal.

1. **Stale selector and interface-id metadata in `lib/crane`** (E3). `IStandardExchangeIn` and `IStandardExchangeOut` carry `@custom:selector` and `@custom:interfaceid` tags computed before the `deadline` parameter was added. The tags are internally consistent with the six-parameter signatures `exchangeIn(address,uint256,address,uint256,address,bool)` and `exchangeOut(address,uint256,address,uint256,address,bool)`, and they are wrong for the current six-plus-one-parameter signatures. Live ids are `0x59fb2971` and `0x60b81fb2`. Because the vault facets advertise `type(IStandardExchangeIn).interfaceId`, the advertised id and the documented id already disagree in the repository today.
2. **Missing `@custom:interfaceid` tags** on `IStandardExchangeInMulti` (`0x20f1017d`), `IStandardExchangeOutMulti` (`0xc4e1f64c`), `IStandardExchangeMultiAssetLiquidity` (its id must be computed from its own selectors at implementation time; it declares twenty functions), and on the aggregate `IStandardExchange`. The Crane NatSpec standard requires the tag on every ERC-165 interface.

## Limits

- **This is a recommendation, not an owner decision.** Every resolution labelled "Recommendation" above is this member's proposal and is open to the owner, including A1 through A10 and the C5 answers. The coordinator's draft is the synthesis; the final text is the coordinator's revision.
- **Nothing here was implemented, built, or tested.** The definitions in C2 are interface text only. No facet, target, DFPkg, test, or deployment was changed, and no compile was run against them. The selectors and interface ids were computed by hashing the signature strings; they have not been confirmed by compiling a Solidity `type(I).interfaceId`, so they must be re-verified at implementation time.
- **The `IStandardExchangeFull` id caveat is unverified.** The statement that Solidity's `type(I).interfaceId` excludes inherited functions is from the language specification, not from a compile performed here. It is flagged in the interface comment as something to verify before any ERC-165 registration relies on it.
- **The `0x2cb69aac` and `0x2576ed1a` values assume the argument shapes chosen in C2.** If the owner changes a parameter type or order, both the selectors and the interface ids change with it.
- **The scope of the redefinition was deliberately held to the interface set.** No conclusion is offered here on the V4 full-spread PRD's zap caps, tick-move limits, position sizing, or fee handling; those are product law and were read only as context. The `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` file is explicitly not interface law.
- **Two owner decisions remain open and are not mine to make:** whether the legacy `exchangeIn` / `exchangeOut` remain in the advertised ERC-165 set after the refund-aware variants ship, and whether the refund recipient is always `msg.sender` or becomes a parameter. This response assumes `msg.sender` throughout, matching the existing exact-output behavior.
- **The migration of the 61 existing implementations is out of scope.** This response recommends the shape and the sequence; it does not estimate the work, and the `lib/crane` submodule change would need its own repository-level review.
- **No peer responses were read and none are reflected here.** This is the independent first pass.
