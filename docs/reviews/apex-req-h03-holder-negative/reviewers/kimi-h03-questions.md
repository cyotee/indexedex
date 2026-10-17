# Kimi K3 — REQ-H03 requirements check: is an implementer choice left? (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Sole input: `docs/reviews/apex-req-h03-holder-negative/REMEDIATION_PRD.md` (59 lines, read in full this round), against the current source lines it cites. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-16.

## Answer: No blocking question.

Every requirement is pinned to a single legal outcome:

**REQ-H03-1 (production burn, `ERC20Repo.sol:360-365`).** The acceptance criteria fix the whole body: read `currentBalance` before any storage write (`:31`); the exact revert with exact arguments (`:32`); the exact mutation order — balance assignment, then supply subtraction, then the existing emit (`:33`); delete both the commented `_decreaseBalanceOf` call and the inline `-=` (`:34`, with the double-decrease rationale); and explicitly **do not** call `_decreaseBalanceOf` (`:35`, because that helper adds an `ERC20InvalidSender` check this item excludes — a real trap, closed by name). The overload is named (`_burn(Storage, address, uint256)`); the default overload at `:376` delegates and needs no mention. `_mint`, `_transfer`, and `_decreaseBalanceOf` are frozen (`:36`). The remaining shared-library effect — `_burn` is Crane-wide, so every `ERC20Repo` consumer inherits the named error — is stated by the PRD's own target and required outcome ("A short burn raises the named ERC-20 balance error", `:18`), and the supply-short panic residual is acknowledged in the non-goals (`:37`). Per the assignment's own rule, a stated shared-library effect is not a question.

**REQ-H03-2 (test, `…HeldRedeem.t.sol:147`).** Import path (`@crane/contracts/interfaces/IERC20Errors.sol`), the verbatim replacement line with arguments `(holder, 0, 1)`, the preserved call and three balance assertions, the preserved code-less success tests, and the stop-and-report-on-different-bytes rule are all written out (`:46-50`). `Panic(uint256)` is explicitly excluded (`:51`). Closed.

**No orphaned mechanics.** The one thing the PRD does not mention is the Crane submodule sync for the `lib/crane` edit. That is workflow, not a requirement ambiguity: this repository already settled the pattern in REQ-SEP-04 (edit the Crane source, sync the pin), and the later plan can state it in one line without asking anyone anything. Not a blocking question.

**Dissent note recorded:** the PRD's dissent section (`:55`) accurately describes the history — MiniMax and I first named this ERC-20 error and then retracted to the panic reading; the owner ruling supersedes that retraction. My retraction is on record in `kimi-h03-cross.md`; this check treats the current PRD as controlling.

I did not run Forge.
