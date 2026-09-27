# DEFINITIONS_R3 Grok original — matrix definition questions

| Field | Value |
| --- | --- |
| Researcher | Grok (independent first pass) |
| Routing | `xai/grok-4.6` — routing ID only, not provider attestation |
| Read | `CLAUDE.md:25–45`; `NETNET_PENDLE_OPERATION_MATRIX.md` (01a–44, policies 1–9, UNKNOWN register); `NETNET_PENDLE_DETF_PRD.md` **v0.14** (R09–R11, R32, R51, §§10.4, 11.1–11.4); `REQUIREMENTS_QUESTIONS.md` Q4–Q13 |
| Peers | **Not read** |
| Context7 | Unused (no new external API claim) |
| Status | Research only. Unauthorized. |

**Settled — do not reopen:** 01a/01b split; PkgInit oracle/NET/sNET/USDG/V2 pool/Pendle factory/custom V2 SE; PkgArgs market+Bond Depository+Staking; factory-first `PendleFactoryAwareRepo`; new SY allowed; salt `"NET-DETF"` singleton intended; first bond supplies initial HLP (R51); row 04 views; 05–07 ordinary ERC-20, no new token locks; SWAP vs BURN vs R41 vs HLP-EXIT vs R45 atomicity.

**Stale wording, not an owner question:** PRD R09 still says “stable underlying/SY identity”; v0.14 §11 `:459` and matrix 42 `:55` permit a **new SY address**. Matrix/§11 control.

**Engineer, not owner:** owned-book construction; 20 inverse; fee amounts; V2 selector inventory; note-array gas; PENDLE forward-fail; historical-series Repo layout (§11.2).

## Four necessary owner questions

### 1. Rows 02–03 · Input / Quote — first-bond **lead token and extra legs**
**Ask:** Which token is lead payment `A`, and which additional full-book legs must the first buyer supply in the same call (NET, sNET, USDG, PLP, YT, SE shares)?
**Evidence:** Matrix 02–03 Input is `UNKNOWN` (`:16`); register `:98–100` says custom payment composition remains open while “whether the first bond seeds liquidity” is closed. PRD R51 `:117` and §10.4 `:441–451` require a full-book join and extra `otherPayment` legs; **1 NET-equivalent `P0` is “proposal, not a selected numeric parameter.”**
**Why unanswered:** R51 selects *that* the first bond bootstraps, not *what* is paid. Q13 covers HLP admission valuation, not this Input vector.

### 2. Row 08 · Input — public HLP **join assets**
**Ask:** After the reserve is live, which assets may anyone deposit to mint HLP?
**Evidence:** Row 08 Input `UNKNOWN` (`:21`); register `:99`: “custody components do not prove the accepted join-token interface.” R32 (`PRD:98` in v0.12 numbering; matrix P3) selects public funded join, not the token list.
**Why unanswered:** Distinct from Q11 (who may join) and from 02–03 first-bond full-book. Do not assume NET-ENTRY/USDG-ENTRY apply to HLP mint.

### 3. Row 10 · Eligibility / Output — **single-output HLP exit**
**Ask:** Is converting an HLP-EXIT allocation into one user token (NET/sNET/USDG) **selected**, **rejected**, or **optional**? If selected, which outputs?
**Evidence:** Row 10 is “conditional”; Eligibility and Output are `UNKNOWN` (`:23`). Policy 7 `:86` allows optional conversion using only allocated components but does not select it. R28 is component-wise entitlements, not a cash exit.
**Why unanswered:** Q11 settled mint/redeem permission, not a single-asset exit. Leaving the row without a yes/no invents or hides a public endpoint.

### 4. Row 42 · Limits and failure / Eligibility — **atomic vs staged rollover**
**Ask:** Must `rollover(target)` be one atomic transaction, or a staged machine? If staged, which of rows 08–22/41 remain callable while old SY/YT claims are unsettled?
**Evidence:** Matrix 42 `:55` “staged/atomic policy remains unspecified.” PRD §11.3 item 1 `:499` lists this OPEN; §11.4 `:511` proposes atomic sequence **“not yet selected.”** New-SY conversion (item 4 `:503`) changes whether old-SY is a residual HLP component or must convert inside 42.
**Why unanswered:** Trigger, expiry gate, factory-first check, and new-SY *permission* are selected (`:497`). User-visible availability during roll is not. Not Q8/R45 (native-note atomicity “does not automatically choose rollover atomicity,” `:505`).

No other owner questions this pass. Expansion (row 36) remains Q7; cross-swap row 15 can stay UNKNOWN without blocking other definitions.
