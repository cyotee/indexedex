# Astra — REQ-V4-01 owner-question pass

**Ready. No owner decision is needed before writing the bounded PRD.** The recorded requirement already selects an internal call to the existing inherited settlement. Size pressure is expressly a report condition, not an implementer's option to retain delegation.

## Basis

- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:68-80` requires the inherited `_executeZapOutExactIn`, the already-selected holder, no self-call, and no holder-taking execution-delegate wrapper as the yield path. It expressly leaves V3, hookless, and Pons alone.
- `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md:17,23-25,78-85` selects internal reuse of one settlement engine, vault-held versus original-caller ownership, and preservation of real external-pretransfer authorization.
- Its plan `:13,63-70,140` repeats the internal-call requirement, preserves settlement protections, and forbids returning to delegation to meet the 24,576-byte limit.
- Current `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol:11-23` already passes the correct holder into `_settleNamedHolder`; lines 26-35 contain the delegate hop, result decoding, and subsequent TWAP update.
- The existing internal declaration at `UniswapV4StandardExchangeInBase.sol:146-152` already accepts the required five arguments in the needed order.
- The V3 contrast, `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:26-30`, already calls its inherited settlement directly from the guarded helper.

## Mechanical closure the PRD should state

These are specifications to carry forward, not questions for the owner:

1. **Exact edit site and call:** In legacy V4 `_settleNamedHolder`, replace the delegatecall, manual revert bubbling, and result decoding with an internal call to `_executeZapOutExactIn`, assigning its result to `amount_`. Pass the existing `tokenOut_`, `shares_`, `minimum_`, `receiver_`, and `holder_` in that order. Keep the existing helper name and signature; no new function or error naming decision is required.
2. **Preserve sequencing:** Retain the helper's existing `nonReentrant` guard and the `_pokeBoundPoolTwap()` call after successful settlement. Do not copy V3's immediate-return line literally and thereby skip V4's TWAP update. Do not add a second nested lock or another settlement implementation.
3. **Preserve holder selection and unrelated routes:** Leave `_redeemVaultHeld` passing `address(this)` and ordinary share redemption passing `msg.sender`. Do not move shares to the vault or set a pretransfer flag to reuse settlement. Preserve non-share dispatch and the existing public exchange wrappers; do not delete their delegate infrastructure merely because the yield hop is removed. The holder-taking wrapper must not remain the yield route.
4. **Bound the requirement:** Do not turn REQ-V4-01 into a family redesign, legacy-V4 deletion, or a rewrite of V3/hookless/Pons. Keep the separately tracked disable-check obligation distinct rather than asking the implementer to reinterpret it as part of choosing a settlement mechanism.
5. **Size and verification disposition:** Refresh affected production artifacts, check the affected deployed runtime sizes, and run the production-path holder regressions in the later authorized session. If any affected deployed unit exceeds 24,576 bytes, stop and report its identity and measured size; do not restore the hop, introduce a self-call, duplicate the engine, or silently choose another architecture. Report actual commands/results and do not claim closure on an oversized or unverified build.

**Blocking questions:** None. **Non-blocking owner questions:** None.

A measured size failure could require a later scoped decision, but the current instruction already tells the implementer what to do if that happens. It is not a reason to defer authoring this PRD or ask the owner to select the internal call again. This pass did not inspect the full family or certify runtime size. No reviewer notes were read, and no PRD or code was written; only this assigned questions report was saved.

I did not run Forge.
