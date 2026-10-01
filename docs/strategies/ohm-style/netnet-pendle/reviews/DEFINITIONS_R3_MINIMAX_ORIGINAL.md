# MiniMax M3 — Definitions R3 first pass (DEFINITIONS only)

- Identity: `minimax/MiniMax-M3` (council-minimax, independent). Provider attestation: not claimed.
- Source: PRD `v0.14`, REQUIREMENTS_QUESTIONS.md (A11–A18), NETNET_PENDLE_OPERATION_MATRIX.md (R2 council consolidation), CLAUDE.md, canonical skill/PRDs read directly.
- Scope: only genuine missing operation definitions or contradictory current requirements. No invented fees/caps/permissions/public endpoints. Owner-economic separated from engineer specification.

## At most four prioritized owner questions

### Q1. HLP exit-conversion output set — is the supported output the same as the DETF R22 set (NET/sNET/USDG only), or distinct?

**Where the gap is.** `NETNET_PENDLE_OPERATION_MATRIX.md` row 10 (`Convert an HLP exit into one output (conditional variant) [P3]`) leaves the conversion output set UNKNOWN in the Input/Output columns, with `Output: UNKNOWN` and `Quote: Only that exit's component allocations`. PRD v0.14 R28 (`The hook issues its own fungible LP shares…`) and §7.1 line 264 (`Conversion of an allocated component to the supported user output does not enlarge the share being redeemed.`) select the operation but never enumerate the output set for it. R22 (`Standard multi-token DETF sell/redemption routes output NET, sNET or USDG only`) is the DETF-out output set, not the HLP-exit conversion output set. **Why this is a real product question, not engineering:** the output set determines which component allocations must be supported through conversion and whether LP holders receive the same restricted output set as liquid DETF holders or a different (broader) one. The matrix already separates the two surfaces; the owner has not chosen.

### Q2. First-bond input token composition — may the bootstrap bond be denominated in NET, sNET, USDG, or only one of these?

**Where the gap is.** `NETNET_PENDLE_OPERATION_MATRIX.md` row 02-03 (`First DETF bond: initialize hook liquidity…`) lists `Input: UNKNOWN` and the cell text says "Exact custom first-bond asset amounts/component mapping and zero-interest initialization remain engineering specification work; hence the input cell is UNKNOWN". PRD R51 (`The first bond supplies initial hook liquidity and activates the reserve within the bond transaction; Reuse the reference's linear configured opening quote…`) selects the pricing math (`G`, `U`, `B`, `R`) but does not state whether the **input** token composition is fixed or selectable. R03 (`All NET and sNET paid in…use Keep YT; USDG paid in funds canonical NET/USDG V2 liquidity`) covers swap/bond routing, not the bootstrap first bond's acceptable input. **Why this is a real product question:** the first bond initializes the reserve and supplies initial HLP — which currency that bootstrap uses determines the initial composition of the hook book. A NET-first first bond produces a different hook book from a USDG-first first bond. The matrix flags this as UNKNOWN rather than engineering; the owner has not chosen.

### Q3. NET-DETF self-leg representation — literal `tokens()` member of the Weighted hook, or accounting-only?

**Where the gap is.** `NETNET_PENDLE_OPERATION_MATRIX.md` multiple rows note "self-leg representation UNKNOWN": rows 04 (previews), 08 (HLP mint), 09 (HLP exit). PRD §4 line 151: `Exact reserve self-leg representation remains O10; do not duplicate or silently omit it.` This is an explicit OPEN marker predating v0.14 and not resolved in v0.14. PRD v0.14 §4.3 line 187: `Copy the calculation model…Construct the NET-DETF-owned reserve book before burn/reinvestment quotation; map interest, Pendle positions, retained YT, USDG SE shares and the self-leg into the reference balances/rates/weights.` The math reuse is selected (R48), but how NET-DETF enters those balances is O10. **Why this is a real product question:** a literal `tokens()` member means a true V4 trading currency with its own weight and curve; accounting-only means a virtual leg. The choice changes `joinUnbalanced`/quote math, self-leg representation in `readTokens()`, and what can be rebalanced vs only claimed.

### Q4. Bond NFT retirement — atomic with final claim, sequential, or persistent until owner-driven purge?

**Where the gap is.** `NETNET_PENDLE_OPERATION_MATRIX.md` row 31 (`Combined/final claim and NFT retirement (conditional surface; internal retirement) [P5,P6]`) is explicitly labelled `conditional`, with `Retirement must not erase undischarged rights` and `retirement predicate: UNKNOWN`. PRD v0.14 R20 and R45 cover atomic collection/Keep-YT/mint/stake for **native notes**, and R44 covers NFT transfer with obligations/capabilities preserved, but **no PRD requirement specifies retirement semantics** after final principal + reward claims. **Why this is a real product question:** if NFT persists after final claim, who purges it (only the holder, or anyone via a public burn surface)? If it auto-burns at final claim, what protects against burning a position with undischarged native-note installments still owed? If it auto-burns only after both principal+reward AND any owed native installments are cleared, the predicate needs owner specification. The matrix cannot mark this `internal retirement` UNKNOWN without owner decision because the predicate determines whether a public retirement surface exists.

## Items deliberately not asked (engineering, not owner)

- V2 SE parity matrix selector enumeration (`R34` exhaustive selector inventory).
- Hook-LP admission/transfer valuation exact formula (line 154, O10 sub-engineering).
- Bond calculation trace exact parameters (`R47` chain).
- Rollover atomic-vs-staged transition (O07).
- Note-array DoS resolution (O08).
- PENDLE forwarding-failure handling.
- V2 SE permit/pretransfer/donation modes (explicitly NOT inferred).

## Stale wording flagged

- PRD v0.14 title: "historical Pendle claim preservation, old/new SY accounting and explicit rollover specification gaps". Matrix row 42 (Rollover) says "a changed SY address alone is not grounds for rejection" but does not record the v0.14 historical-claim-preservation rule nor the old/new SY accounting rule. These should be reconciled into the matrix at consolidation, not re-asked of the owner here.
- The matrix R2 consolidation preserved four originals unchanged per the cross-review rules; this pass does not amend the matrix file.

## Saved path
- `docs/strategies/ohm-style/netnet-pendle/reviews/DEFINITIONS_R3_MINIMAX_ORIGINAL.md`
- Other files: read-only. No shell/tests/code/config/delegation. No peer artifacts read. No new external API claims required Context7. PRD, tracker, matrix, original drafts, code and configuration unchanged. **Implementation unauthorized.**
