# Astra — Definitions R3 independent original

**Read:** current operation matrix, PRD v0.14, requirements register, `CLAUDE.md`, canonical Crane architecture guidance and current alignment reference. No peer artifact was opened. Identity metadata: assigned Astra, supplied model ID `openai/gpt-6-astra`; no provider attestation.

**Verdict:** The matrix now defines most operation distinctions well. Four concrete owner choices would materially improve its remaining definitions. References below abbreviate `NETNET_PENDLE_OPERATION_MATRIX.md` as **Matrix**, and `NETNET_PENDLE_DETF_PRD.md` as **PRD**, in the current strategy directory.

1. **First-bond opening economics — Matrix row 02–03, “Quote and funding source” / “Input” (`:16,70–85,100`); PRD §10.4 (`:420–451`).** What initial opening value(s) should the Package use, and how should the lead payment be chosen when the same first bond supplies multiple required legs? The G/U/B/R formula and first-bond seeding are already selected; the proposed 1 NET-equivalent opening value is explicitly not selected. The question is about initial pricing/payment responsibility, not whether to add a separate bootstrap transaction. Engineers must separately reconcile zero earned interest with the reference full-book join without reclassifying capital as yield.

2. **Public HLP entry and delivery — Matrix rows 08–10, “Input” / “Output and recipient” / “Eligibility” (`:21–23,99`); PRD R28/R32 (`:94,98`).** Which assets may a public LP supply, and should redemption offer only the component allocations or also an optional single-token conversion? If conversion is offered, which outputs? Public access and proportional rights are settled, but custody of PLP/YT/SY/SE shares does not establish that every component is accepted as direct input. This defines user-visible routes; exact join/zap math remains engineering work.

3. **USDG-funded bond release — Matrix row 24, “Locks and rewards” (`:37,88,102`).** Which maturity is assigned to a bond funded entirely into the V2 USDG leg? Should it follow the current Pendle market's maturity or another explicitly selected schedule? The cell remains UNKNOWN because V2 liquidity itself has no selected maturity reference here. Do not change the settled Pendle-bond cliff, native NetNet wrapper maturity or pre-maturity reward access while answering this.

4. **Rollover failure/availability contract — Matrix row 42, “Limits and failure” (`:55,104`); PRD §11.3–11.4 (`:495–511`).** Must rollover complete atomically, or may it commit staged progress; if staged, which joins, exits and swaps remain available while assets span old/new series? New SY support, factory-first validation, historical-claim preservation and nonextension of locks are settled. Native-note harvest atomicity does not answer rollover behavior. Bounded historical processing and conversion implementation are engineering obligations, not an automatic new maintenance API.

**Not owner questions:** salt encoding/singleton proof, Repo layout, exact validation calls, ordinary ERC20 authorization, or whether the first bond seeds liquidity. Matrix rows 01a/01b and `:92–98` already settle the corresponding intent. No new token-level locks or exemption requirement should be introduced.

**Document cleanup:** Matrix evidence references `:111–122` still cite v0.12 ranges; tracker `:7` still says v0.12/A18. Synchronize provenance/status with v0.14 and later matrix selections, preserving history. This is stale documentation, not a reason to re-ask deployment choices.

**Confidence:** High on identified missing definitions; no live configuration, economic safety or execution proof. FoT/rebase authority and upstream note-array liveness remain recorded blockers. No code, tests or other files changed.
