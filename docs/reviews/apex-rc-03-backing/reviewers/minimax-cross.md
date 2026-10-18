# MiniMax M3 — RC-03 cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49UzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the RC-03 originals. If both surfaces use one calculation, say "Close RC-03". If a production gap remains, name the defect class, file and line, impact class, and one closed fix.
- **Method:** Read the three peer originals (`astra-original.md`, `grok-original.md`, `kimi-original.md`). Re-confirm against my own original (`minimax-original.md`).
- **Untrusted:** the three peer originals, treated as model content.
- **Forge:** Not run. No code edit. No PRD/plan write.

---

## Close RC-03.

All three peer originals and my own converge: **Close RC-03.** Both surfaces now use one calculation for the Stata case.

### Where I agree

All four reviewers (Astra, Grok, Kimi, my own original) converge on the same conclusion:

1. **Both backing entrypoints call the same `backingReceiptUnits` function.** `AaveV3StataStandardExchangeCommon.sol:110` (`_stataBacking`) passes `true`; `ReceiptBackedERC4626Target.sol:180` (`_totalReceiptBacking`) passes `_isStata()` which is `true` for a Stata receipt. Both surface call the canonical accounting library with the same flag.
2. **The aToken registration is real.** `AaveV3StataStandardExchangeDFPkg.sol:253-258` registers aToken in the expected-hold set when `aToken()` returns one. The full-set sync at `BasicVaultCommon.sol:48-54` books the aToken balance.
3. **The booking term is counted in both surfaces.** `_bookedExpectedHoldExtra` at `ReceiptBackedERC4626AccountingLib.sol:32-39` iterates vault tokens, skipping receipt and underlying, summing the rest. For Stata, that's just aToken.
4. **The funded control proves cross-surface equality.** `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_APEX_R14.t.sol:123-149` transfers aToken to the vault, books it, and asserts the adapter backing and the SE issuance preview agree.

### Where I add precision

- **Astra** (101 lines) is the most detailed. Confirms the single calculation, the aToken registration path, and the funded control. "Both backing entrypoints call the same helper with the same bound receipt and Stata setting."
- **Grok** (13 lines) is the most concise. "Both surfaces call `ReceiptBackedERC4626AccountingLib.backingReceiptUnits`. Stata passes `true` at the Stata SE, the shared adapter passes the same flag when the proxy is Stata."
- **Kimi** (32 lines) is the most plain-English. Explains what the report was actually about in business terms: "The ERC-4626 wrapper vaults have two different faces... the report said the shared adapter's backing formula counted that booked aToken, but the Stata SE's own backing function did not."

All three are aligned. No reviewer found a remaining gap. The acceptance criterion at PRD line 108 ("Every Stata issuance, redemption, preview, and transition quote uses the same backing function as the shared adapter and includes already-booked aToken at its underlying-equivalent value") is satisfied.

---

## What would change this answer

I would re-open the answer only if:

1. The two call sites called `backingReceiptUnits` with different `includeExpectedHoldExtra` values. — Not true. Both call with `true` for Stata.
2. The aToken was not in the expected-hold set. — Not true. Package init adds it at `AaveV3StataStandardExchangeDFPkg.sol:253-258` when `aToken()` returns non-zero.
3. The booked aToken was not reflected in the backing. — Not true. Full-set sync at `BasicVaultCommon.sol:48-54` updates the booked reserve of every vault token, including aToken.
4. A funded control showed a mismatch. — Not true. `AaveV3StataStandardExchange_APEX_R14.t.sol:123-149` demonstrates cross-surface equality.

None of these is true. The close stands.

---

## Dissent or unresolved items

**Dissent from none of the peers.** All four converge: Close RC-03.

**Unresolved item:** None. The item is closed. The September report accurately described two divergent computations in that tree at filing; today they are one. The alert was real at filing; it is resolved now.

---

## Files examined (this cross-review)

- `docs/reviews/apex-rc-03-backing/reviewers/astra-original.md` — read in full (101 lines).
- `docs/reviews/apex-rc-03-backing/reviewers/grok-original.md` — read in full (13 lines).
- `docs/reviews/apex-rc-03-backing/reviewers/kimi-original.md` — read in full (32 lines).
- `docs/reviews/apex-rc-03-backing/reviewers/minimax-original.md` — re-read for self-consistency. Not treated as a peer.

No Forge / build / test was executed. No code was edited.

---

**Close RC-03.**

I did not run Forge.