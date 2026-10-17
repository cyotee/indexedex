# Kimi K3 — REQ-SEP-04 targeted answer: is a blocking owner question left?

- **Label:** Replacement-session targeted answer, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read for this pass. The only inputs were `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (draft, owner answer dated 2026-10-16) and my own previously recorded file/line cites. Nothing was edited. This is not a new findings round.
- **Date:** 2026-10-16.

## What the PRD already closes

- **Production behavior — closed.** `:22-26` define both prepaid shapes exactly (exact-output: process the quote from unbooked value, refund `min(unbooked, declared maximum) − used`, never above the declaration; exact-input: process the declared `amountIn` from unbooked value, no refund above it, no equality revert; no shortfall fill from booked inventory; never the whole remainder). `:44-45` state the current paths already have this shape and `:26` forbids changing them, so the item is documentation-only. No implementer choice remains on behavior.
- **README — closed.** `:32-38` name the file, the two lines, and the verbatim replacement sentences, and `:30`/`:53` explicitly protect lines 3 and 56.
- **Exclusions — closed.** `:50-54`: no `contracts/protocols/dexes/uniswap/v4`, no Slipstream restoration, no caller-attribution ledger, no edits in the review session.
- **Interface signatures — closed.** `:40` forbids changing executable signatures in this item.

## The one blocking question

The PRD's remaining documentation order is `:40`: "Apply that same meaning to DETF interface comments that say an exact-input prepaid call refunds nothing or reverts unless the declaration equals the whole surplus." That sentence (a) does not name the files or lines — the review record identifies candidates such as `IUniswapV4Detf.sol:126,137`, `IMultiVaultWeightedDetfBonding.sol:11-48`, and `ISingleStandardExchangeDETFBonding.sol:12-21`, but the PRD does not adopt that list — and (b) says "apply that same meaning" without giving the replacement wording, so each comment's new text is left to the implementer. Separately, the PRD is silent on every other document the review record shows still stating a withdrawn sentence (for example `docs/audits/apex-2026-09-17-evidence.md:61`, `docs/agent/INDEXEDEX_AGENT_LAW.md:422`, and `uniswap-se-v2-liquidity-leak-fixes.md:63,202`); `:46` scopes "the remaining edit" to "the README and the named DETF comments," but no DETF comments are actually named anywhere in the PRD. A plan written today would have to let the implementer search for qualifying comments, choose which documents are in scope, and author the replacement sentences — three choices the council rule forbids.

**The one question, in plain English:**

> Exactly which files and lines, beyond README lines 32 and 38, must be rewritten under this item — the named DETF interface comments and any other document that still states the withdrawn equality-revert or unqualified never-refund sentence — and what is the verbatim replacement text for each, with every document not on that list declared out of scope?

**The one sentence that would close it:**

> "The complete edit list is: README lines 32 and 38 with the text already given; the exact-input prepaid comments in `IUniswapV4Detf.sol` (lines 126 and 137), `IMultiVaultWeightedDetfBonding.sol` (lines 11–48), and `ISingleStandardExchangeDETFBonding.sol` (lines 12–21), each replaced with the README line-32 meaning restated for that interface; all other documents are out of scope for this item."

(The owner may equally close it by listing different files or different wording; what must not be left open is the file list, the per-file replacement text, and the out-of-scope declaration for everything else.)

I did not run Forge.
