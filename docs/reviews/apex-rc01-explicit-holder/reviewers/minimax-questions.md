# MiniMax M3 — APEX RC-01 explicit-holder remediation PRD, owner-question review

- **Date:** 2026-10-11
- **Reviewer:** MiniMax M3
- **Target PRD:** `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md`
- **Question:** Does this PRD leave any requirement an implementer cannot settle without an owner decision?
- **Method:** Read the PRD in full. Re-read only the cited source lines that the PRD's wording depends on, to check for citation conflicts and to determine whether two incompatible implementations are permitted. No build, test, or shell.

## Answer

**The PRD is implementable without a further owner decision.** The Required repair directives, the acceptance criteria, and the non-goals together specify a verifiable end-state. The implementer can clear every bullet of the acceptance list from the source as it stands, by following the directives and choosing coherent interpretations of the small citation/scope ambiguities below.

No sentence in the PRD *requires* an answer from the owner. Three sentences are open to two readings, but the wrong reading on any of them does not recreate a self-call or reject an ordinary holder that the acceptance list would otherwise block. Those are scope/citation questions, not functional ones, and they are listed under "Residual risks" below.

## Residual risks that are not questions for the owner

The implementer should consciously decide each of these. None of them blocks the lock-down criteria. None of them, if the wrong choice is picked, reintroduces the bug the PRD is fixing.

### 1. The V4 `:121-155 and :195` citation crosses two functions

The PRD cites `UniswapV4StandardExchangeInBase.sol:121-155` and `:195`. The `_executeZapOutExactIn` function header is at `:121` and its body runs to `:155`. Line `:195` is inside `_executeFreeZapOutExactIn` (header `:157`), at its `_burn(address(this), sharesBurned)` line. The same burn-of-`address(this)` shape is repeated in both functions.

The PRD sentence "only to accept an explicit holder. Do not copy this function" leaves the implementer to read the two line ranges as either one settlement function spanning both, or two sibling functions. Reading the source resolves it: the two are siblings with separate signatures, and the implementer should add a holder to whichever is on the in-scope call path. The yield facet (OutMultiQueryTarget) reaches `_executeZapOutExactIn` directly via inheritance; the branched free path inside the same file (`_executeFreeZapOutExactIn`) is reached through that function. Both currently burn `address(this)` and both should be touched in the same shape if the implementer follows the literal scope. The wrong choice is harmless: it is either no-op (add a parameter that the call path already passes) or a partial change. It does not reintroduce a self-call.

### 2. The V3 `OutExecutionDelegate.executeZapOutWithdrawal` scope is independent of the bug path

The PRD scope lists `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:29-49` and says "Give it the holder argument." This function is the **Out zap-out** withdrawal engine, called by the V3 OutExecuteTarget. The yield-facet bug the PRD describes is at `OutQueryTarget.sol:39-50` (`_standardRoute`), and the vault-held redemption already routes through the **In** execution delegate's `executeZapOutExactIn` (which burns `address(this)` only — there is no holder choice on the accept path). So the cited function is not on the path that the PRD's "no self-call" and "no pretransfer flag as a stand-in for the holder" directives describe.

The implementer can:
- (a) Modify `executeZapOutWithdrawal` to take a holder argument, replacing the pretransfer-based choice at `:45/48`, and update the OutExecuteTarget caller to pass the holder.
- (b) Leave it alone. The bug is closed by fixing `OutQueryTarget._standardRoute` (don't stage shares and `delegatecall(exchangeIn, pretransferred=true)`), and `executeZapOutWithdrawal`'s pretransfer-flag choice is on a different code path that is not in scope for this defect.

Either choice meets every bullet of the acceptance list. Neither recreates a self-call or rejects an ordinary holder. The literal scope leans toward (a); the spirit of the PRD (no external exceptions, close the listed bugs) leans toward (b).

### 3. The Repair 1 directive adds a holder argument that is redundant for vault-held

Repair 1: "Add the holder as an argument to the existing settlement function."

For both V3 (`executeZapOutExactIn` / `_executeZapOutExactIn`) and V4 (`_executeZapOutExactIn`), the current burn is hardcoded to `address(this)`. Vault-held redemption is the only caller in scope for the explicit-holder change, and there the holder is always `address(this)`. The literal directive forces a shared-base-function signature change (the V4 `_executeZapOutExactIn` is also called from the In execution target's `exchangeIn`; the V3 `executeZapOutExactIn` is a CREATE3-deployed delegate). Updating those callers to pass `address(this)` is mechanical and does not affect any acceptance bullet.

The wrong choice — picking Repair 1 literally and adding a holder argument — is more invasive than strictly needed but does not introduce a self-call. The opposite choice — leaving the function alone — meets the acceptance list. Either way, the implementer settles it.

### 4. After deleting the `_secureShareDelivery` branch, the self-call case reverts with a generic ERC20 error

Repair 4 deletes `if (msg.sender == address(this) && !pretransferred)` from `_secureShareDelivery` (UniswapV4StandardExchangeCommon.sol:1302-1305). After deletion, that case falls through to `safeTransferFrom(msg.sender, address(this), amountIn)` and reverts with the standard ERC20 insufficient-allowance error (self-transferFrom). The PRD does not say whether to add an explicit revert with a custom error. This is a minor diagnostic-quality question; the function correctly rejects, just with a generic message. It does not recreate the bug.

### 5. For V3 ordinary redemption, the path after the fix determines whether the EOA must approve the vault first

Once the implementer removes the staged transfer + `pretransferred=true` trick from `OutQueryTarget._standardRoute`, ordinary redemption can land on either of two paths:

- (a) Delegatecall `super._standardRoute` (or equivalent internal-call path) which uses `pretransferred=false`. `exchangeIn` → `_secureShareDelivery(false)` → `safeTransferFrom(msg.sender, vault, amountIn)`. The EOA's redemption only succeeds if the EOA has approved the vault for the share amount beforehand. **The EOA is no longer burned without consent**, but a fresh EOA path now requires a prior `approve`. This matches ERC-4626-vault withdrawal, not the prior Pendle-style "SY burns the user's shares."
- (b) Modify `_executeZapOutExactIn` (or its V3 delegate wrapper) to accept a holder argument, then have the yield facet call it directly with `holder=msg.sender` for ordinary redemption. No approval needed; the burn happens on the caller's shares directly.

The acceptance criterion "A code-less holder can redeem that holder's own shares through ordinary redemption. The burn holder is that caller. The call is not rejected as `EOAPretransferNotAllowed`" is satisfied by both (a) and (b). Option (a) requires the EOA to approve first; option (b) does not. Neither reintroduces the bug. The PRD does not specify which.

This is the closest item to a question that affects an ordinary holder's redemption experience, but the wrong choice does not *reject* the holder — it requires a one-time prior approve. There is no acceptance bullet for "no approval required," so neither reading is functionally wrong.

## Citations and inline numbers I checked against the source

- `UniswapV4StandardExchangeInBase.sol:121-155` — verified; `_executeZapOutExactIn` header is at `:121` and its body ends at `:155`.
- `UniswapV4StandardExchangeInBase.sol:195` — verified; `:195` is the burn inside `_executeFreeZapOutExactIn` (header `:157`), not inside `_executeZapOutExactIn`. The same burn-of-`address(this)` pattern is at `:147` (inside `_executeZapOutExactIn`) and at `:195` (inside `_executeFreeZapOutExactIn`).
- `UniswapV4StandardExchangeCommon.sol:1299-1305` — verified; `_secureShareDelivery` header is at `:1299` and the `msg.sender == address(this) && !pretransferred` branch is at `:1302-1305`.
- `UniswapV4StandardExchangeOutMultiQueryTarget.sol:17-34` — verified; `_redeemVaultHeld` is `:17-25` and `_standardRoute` is `:27-35`. The external `exchangeIn` self-call is at `:22-24`.
- `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:37-54` — verified; the override is `:39-54` and the staged-transfer + `pretransferred=true` `delegatecall` is at `:45-50`.
- `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:29-49` — verified; the pretransfer-flag-based burn choice is at `:44-49` (`_burn(address(this), sharesBurned)` when pretransferred; `_burn(msg.sender, sharesBurned)` otherwise).
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56` — verified; the "fixed proxy self-call with `pretransferred=false`" sentence is present and should be rewritten per the PRD's repair #5.

The PRD's wording and the source line numbers are not in conflict. The ambiguities listed above are about scope and interpretation, not about line-number drift.

## What the implementer can settle on their own

- The two bug fixes (V4 yield facet external self-call at `OutMultiQueryTarget.sol:22-24`, V3 yield facet staged-transfer + `pretransferred=true` at `OutQueryTarget.sol:45-50`).
- The deletion of the `_secureShareDelivery` branch at `UniswapV4StandardExchangeCommon.sol:1302-1305`.
- The README comment fix at `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56`.
- The choice of routing for vault-held redemption (direct internal call where inheritance permits, delegatecall where it doesn't).
- The choice between super-style routing and direct settlement routing for ordinary redemption (the "approval vs. no-approval" trade-off above).
- Whether to also modify `executeZapOutWithdrawal` (V3 Out delegate) and/or `_executeFreeZapOutExactIn` (V4 InBase) — independent scope decisions that don't affect the bug or the acceptance list.

## Stop

No owner decision required. STOP.