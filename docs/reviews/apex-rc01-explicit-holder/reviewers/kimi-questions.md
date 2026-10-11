# Kimi K3 — implementability questions for the RC-01 explicit-holder PRD

- **Date:** 2026-10-11. Reviewer: Kimi K3.
- **Scope honored:** RC-01 self-call/explicit-holder only. No Camelot, Rocket, DETF, selector, or package-deletion content was reviewed here. Cited source was re-read only where a PRD sentence conflicted with that source or admitted two incompatible implementations.
- **Method note:** source facts below were verified by direct reads on the current tree. No shell, tests, or edits.

## Verdict

The PRD is implementable without a further owner decision **except for one scope/citation conflict on the V3 FullSpread side** (Q1). Everything else an implementer might hesitate over is settled either by the PRD's own repair steps or by its behavioral acceptance criteria. Residual risks that are not questions are listed at the end.

## Q1 — Which V3 settlement function receives the holder argument, and is the file it lives in actually in scope?

**Question (owner-answerable in one sentence):** Should the holder argument be added to the V3 FullSpread *IN-side* exact-in settlement (`_executeZapOutExactIn` in `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:183-228`, burns at `:204` and `:224`, wrapped by `InExecutionDelegate.sol:19-25`) — the function both SY redemption branches actually reach — and is that file in scope, instead of the OUT execution delegate the PRD names?

**The PRD sentence that does not settle it:** the in-scope bullet — "The V3 settlement burn that currently chooses `address(this)` or `msg.sender` from the pretransfer flag (`UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:29-49`). Give it the holder argument. Do not add a self-call to avoid that edit."

**Why the sentence conflicts with the source it cites:**

- SY redemption never reaches the cited function. `redeem` → the `_standardRoute` override (`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:39-54`) → delegatecall to `exchangeIn` → `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:58-61` routes share-in/token-out to `_delegateExecuteZapOutExactIn` → the IN execution delegate's `executeZapOutExactIn` → `_executeZapOutExactIn` in InBase. The burns on that path (`InBase.sol:204,224`) are hardcoded to `address(this)`; there is no `msg.sender`/flag choice there at all.
- The cited OUT delegate function (`executeZapOutWithdrawal`, `OutExecutionDelegate.sol:14-70`) is reachable only from the public `exchangeOut` zap-out-withdrawal route (`OutExecuteTarget.sol:135-153`). Its flag-dependent burn selection (`:44-49`, `:59-64`) is the *legitimate* public-route behavior the PRD's own repair steps 4 and 6 say to preserve: a real true-flag delivery authenticates the caller and burns vault-held prepaid shares; a false-flag delivery pulls and burns the caller. That function is not the defect and not on any yield-redemption path.
- The V3 in-scope list names `OutQueryTarget.sol:37-54` and the OUT delegate only. Neither `UniswapV3FullSpreadStandardExchangeVaultInBase.sol` nor `UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol` appears in the in-scope list, yet the holder argument must land in InBase for the repair to function. (Verified: the V3 yield facet inherits InBase — `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:16` — so repair step 2's "calls that function directly when the facet already inherits it" is available; it is the same settlement function, but it is the IN-side one.)

**The two incompatible implementations it permits:**

1. Add the holder parameter to `_executeZapOutExactIn` in InBase (propagated through the IN delegate wrapper), call it directly from the yield facet with `address(this)` for vault-held redemption and with the original caller for ordinary redemption, and leave the OUT delegate untouched. This satisfies every acceptance bullet but exceeds the named in-scope files and disregards the literal :42 citation.
2. Follow :42 literally: add the holder parameter to the OUT delegate's `executeZapOutWithdrawal` and thread it from `exchangeOut` callers. No SY redemption path uses that function, so the ordinary-redemption override still has no holder-accepting settlement to call.

**Why the wrong choice recreates the defect or rejects an ordinary holder:** under (2), the only way ordinary SY redemption can still execute is the current staged design — move the caller's shares onto the vault, then delegatecall `exchangeIn` with `pretransferred=true` (`OutQueryTarget.sol:45-49`). That is exactly the forbidden flag-as-holder substitution, and because `delegatecall` preserves the original caller, a code-less holder still hits `requirePretransferCaller` (the pretransfer gate on that route, e.g. `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-867`) and is rejected with `EOAPretransferNotAllowed` — failing the acceptance bullet "A code-less holder can redeem that holder's own shares through ordinary redemption. The burn holder is that caller. The call is not rejected as `EOAPretransferNotAllowed`." Alternatively, an implementer who notices the mismatch but treats the in-scope list as a hard edit boundary is blocked. Either way the PRD text does not settle it; the acceptance criteria imply (1), but the scope boundary contradicts it, so this needs the owner's one-sentence ruling rather than an implementer's guess.

## Questions considered and dismissed as settled by the PRD itself

- **Legacy V4 mechanism:** settled. The yield facet inherits the settlement (`UniswapV4StandardExchangeOutBase.sol:22-23` is `UniswapV4StandardExchangeInBase`); the burns are hardcoded to `address(this)` (`UniswapV4StandardExchangeInBase.sol:147,195`); the self-call branch to delete is `_secureShareDelivery` (`UniswapV4StandardExchangeCommon.sol:1299-1305`); the instructing comment sits at `UniswapV4StandardExchangeOutMultiQueryTarget.sol:20-24`. Repair steps 1–5 and the "call directly when the facet already inherits it" rule determine the implementation. No owner input needed.
- **Ordinary-redemption shape on both families:** settled by acceptance. Deleting the V3/legacy-V4 `_standardRoute` override and falling back to the base route (`NativeStandardYieldTarget.sol:65-69`) would make share delivery a `transferFrom` pull (allowance-gated) with the burn subject being the vault after delivery — contradicting "The burn holder is that caller." Rewriting the override to pass the original caller into explicit-holder settlement is therefore forced; the PRD does not leave a choice.
- **Public zap-out routes after the holder parameter exists:** settled by repairs 4 and 6 — real false-flag deliveries still pull from the caller, real true-flag deliveries still authenticate and credit only unbooked value, and `requirePretransferCaller` stays on genuine external pretransfer entries. The existing `exchangeIn`/`exchangeOut` callers pass the holder that matches their documented delivery semantics.
- **Hookless/Pons/Wings/ERC-4626/constant-product families:** the base-route carve-out (PRD paragraph after repair 7) explicitly permits their `delegatecall` to `exchangeIn` with `pretransferred=false`, and the non-goal forbids editing their settlement. No decision needed.

## Residual risks that are not questions

- **Legacy V4 locked-branch preview self-call:** `_executeZapOutExactIn` performs an external self-call to `previewExchangeIn` when the pool manager cannot be unlocked (`UniswapV4StandardExchangeInBase.sol:137-139`). That is a read of a view quote, not holder discovery through `exchangeIn`, so the PRD neither forbids nor repairs it. An implementer should not "fix" it under this item; noting it so it is not mistaken for in-scope recurrence.
- **Deleting the `_secureShareDelivery` self-call branch** assumes no non-yield production caller relies on it. The PRD's override-search instruction covers yield redemption; if an unrelated caller depended on the branch, it would surface at build/test time. Discovery risk, not an ambiguity.
- **The PRD's rationale sentence** that the base route "does not select the vault as holder" is imprecise for hookless/Pons, where the false-flag route pulls the caller's shares onto the vault before settlement burns them — economically the vault transiently holds them. The instruction to leave those families alone is nonetheless explicit, so this is a wording imprecision, not an implementation fork. The ordinary-holder acceptance bullet is scoped to legacy V4 and V3 FullSpread only, so it does not force changes on hookless/Pons.

**Stop.**
