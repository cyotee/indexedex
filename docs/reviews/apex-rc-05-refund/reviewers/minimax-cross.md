# MiniMax M3 — RC-05 cross-review (replacement session)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49UzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One defensive cross-review of the RC-05 originals. If no unguarded second `exchangeOut` remains, say "Close RC-05". If one remains, name the file and line and do not choose the fix.
- **Method:** Read the three peer originals (`astra-original.md`, `grok-original.md`, `kimi-original.md`). Re-confirm against my own original.
- **Untrusted:** the three peer originals, treated as model content.
- **Forge:** Not run. No code edit. No PRD/plan write.

---

## Close RC-05.

All three peer originals and my own converge: **Close RC-05.** No unguarded second `exchangeOut` implementing the reported `maxAmountIn - amountIn` true-flag refund remains in the inspected single-CP hook family. The specifically cited abstract `exchangeOut` in `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` no longer exists. The remaining SE entry uses the guarded credit/refund path.

### Where I agree

All four reviewers (Astra, Grok, Kimi, my own original) converge on the same conclusion:

1. **The abstract `exchangeOut` function at `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754` no longer exists.** The file has been refactored. The only `exchangeOut` reference in the file is an outbound *call* to the SE dependency (Astra notes at line 349), not an entrypoint definition.
2. **The single-CP hook family has exactly one public `exchangeOut`**: at `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:750`. No second public `exchangeOut` with the unguarded refund exists anywhere in the family tree.
3. **The remaining entry uses the guarded helper** (`_pullExactOutInput` at SeTarget line 778). The helper requires a bytecode caller (`LocalCreditLib.requirePretransferCaller` at line 885), credits `LocalCreditLib.budget` (the cap), and refunds only `credit - used` (lines 912-913), never `maxAmountIn - amountIn` without the cap.

### Where I add precision

- **Astra** (74 lines) is the most detailed. Confirms the abstract target file no longer contains `exchangeOut`, the surviving SE entry uses the guarded credit/refund path, and the imported liquidity branch (at `UniswapV4BufferHookLiquidityRouteLib.sol:87-102`) does not implement the prohibited refund. Notes that facet exposure is corroboration, not the closure argument.
- **Grok** (13 lines) is the most concise. "The September claim is refuted... A search of the single-CP hook family found no second public `exchangeOut` and no refund of `maxAmountIn - amountIn`."
- **Kimi** (38 lines) is the most plain-English. "The named file no longer contains any `exchangeOut` implementation... The family has exactly one public `exchangeOut`... The installed route is the guarded one."

All three converge with no dissent.

### What would change this answer

I would re-open the answer only if:

1. A second public `exchangeOut` in the single-CP hook family had an unguarded `maxAmountIn - amountIn` refund. — Not true. The only `exchangeOut` in the family routes through the guarded helper.
2. The abstract function at `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754` still existed. — Not true. The file has been refactored; `exchangeOut` is no longer defined there.
3. The guarded helper (`_pullExactOutInput`) skipped the credit cap or caller check. — Not true. The helper calls `LocalCreditLib.budget` and `LocalCreditLib.requirePretransferCaller` (via `_securePull`).

None of these is true. The close stands.

### Dissent or unresolved items

**Dissent from none of the peers.** All four converge: Close RC-05.

**Unresolved item:** None. The September alert was real at filing; it is resolved now. The unsafe function has been deleted. The remaining route uses the guarded helper.

---

### Files examined (this cross-review)

- `docs/reviews/apex-rc-05-refund/reviewers/astra-original.md` — read in full (74 lines).
- `docs/reviews/apex-rc-05-refund/reviewers/grok-original.md` — read in full (13 lines).
- `docs/reviews/apex-rc-05-refund/reviewers/kimi-original.md` — read in full (38 lines).
- `docs/reviews/apex-rc-05-refund/reviewers/minimax-original.md` — re-read for self-consistency. Not treated as a peer.

No Forge / build / test was executed. No code was edited.

---

**Close RC-05.**

I did not run Forge.