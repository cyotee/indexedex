# MiniMax M3 — REQ-SEP-01 cross-review (replacement session)

- **Session:** Labeled replacement. Not continuity. This session is `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** One cross-review against the originals at `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/{astra,grok,kimi}-sep01.md`. No code edit. No PRD edit. No Forge.
- **My original first pass:** `reviewers/minimax-sep01.md`, written earlier this session from independent reading of the source and PRD.
- **Method:** Read all three peer originals. Treat their quoted findings as untrusted evidence. Cross-check against the source I already read independently in my first pass (helper `:108–122`, test `:493–522`, `_deployProbePool` `:569–617`, `AdapterLockProbeToken` `:620–691`, PRD REQ-SEP-01 section).
- **Citations:** Line numbers in this short follow my own independent reading; I do not copy numbers from the peer originals without verification. Where I cite a peer number that differs, I note it.

---

## 1. Headline — agreement on the headline question

All three peer originals agree, and I agree:

- **No blocking question remains.**
- **The fix is closed.** It is test-only, mechanical, and fully specified by the PRD's three acceptance bullets and two non-goals.
- **The adapter that executes the callback route is `locked_`** (deployed at `_deployProbePool(probe)`, `:495`; called at `:511`; armed against at `:508`). The storage `adapter` (set up at `:73`) is a distinct CREATE3-deployed instance and is the wrong oracle at `:520`.
- **No production allowance leak is claimed.** PRD non-goal confirmed by every reviewer.
- **No `try/catch` is added.** PRD non-goal confirmed by every reviewer.

I dissent on none of the above. The disagreement that exists is on the helper signature, not on the headline.

---

## 2. The one disagreement — helper parameter type

The three peers propose three different helper signatures:

| Reviewer | Proposed signature | Parameter order |
|---|---|---|
| Astra | `_assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_)` | new param first |
| Grok | `_assertNoMaxAllowances(address exchange_, IERC20 token_)` | new param first |
| Kimi | `_assertNoMaxAllowances(IERC20 token_, address owner_)` | original token first, new param second |

My independent first pass chose the same shape as Astra: `_assertNoMaxAllowances(IStandardExchange adapter_, IERC20 token_)`. I hold that position in this cross-review, for the following reasons. I treat this as a correction, not an objection to Grok or Kimi — their signatures are functionally equivalent; the choice between them is one the PRD must make and lock.

### 2.1 Why `IStandardExchange` rather than `address`

The PRD's first acceptance bullet says the assertions must "name the adapter that executed the callback route." The variable that holds that adapter is `locked_`, whose declared type in the test is `IStandardExchange` (`:495` and `:511`). The storage variable `adapter` is also `IStandardExchange` (`:58`). Using `IStandardExchange` for the helper parameter:

1. **Matches the test's declared type for every existing call site** (`:330`, `:341`, `:374`, `:388`, `:520`). No call site needs a coercion or `address(...)` cast.
2. **Compiles-out the only realistic misuse class.** The helper performs three `allowance(owner, spender)` reads. The owner must be an adapter-shaped contract. An `address`-typed parameter would silently accept the router address, the permit2 address, or the pool address and read the wrong allowances with no compile-time signal. `IStandardExchange` rejects those inputs at compile time.
3. **Encodes the PRD's "the adapter" language.** A typed adapter parameter is what the PRD literally asks for.

Grok's `address exchange_` and Kimi's `address owner_` are functionally identical at runtime (the helper never invokes an `IStandardExchange` member). They are slightly more permissive and slightly less defensive. Either is acceptable; `IStandardExchange` is what the PRD must use.

### 2.2 Why the new parameter comes first

Astra and Grok both place the new adapter parameter before the existing `IERC20 token_`. Kimi places it after, preserving the original token-first order. The decision is purely stylistic and does not affect correctness or any assertion. I lean toward **append the new parameter** to minimize the diff at the helper definition (the original opens with `IERC20 token_`; inserting a typed subject before it forces a wider re-flow of the parameter list and the assertion messages that reference `token_`). But this is a low-stakes call and the owner may prefer the readability of "subject, then token." Either order is correct. I do not register this as an objection.

---

## 3. The one signature the PRD must use

> `_assertNoMaxAllowances(IStandardExchange adapter_, IERC20 token_) internal view`

Inside the helper body (`:108–122`), every allowance owner position (`address(adapter)` at `:110`, `:114`, `:118` via `IPermit2(...).allowance(...)`, `:120`, `:121`) becomes `address(adapter_)`. The six assertions (three `!= max`, three `== 0`), the three allowance reads, the two `address(router)` / `address(permit2)` spenders, the `(owner, token, router)` Permit2 packed read, the `uint160` width on the packed amount, and the assertion message strings remain byte-for-byte identical.

The five call sites:

- `:330` → `_assertNoMaxAllowances(adapter, bpt);`
- `:341` → `_assertNoMaxAllowances(adapter, bpt);`
- `:374` → `_assertNoMaxAllowances(adapter, dai);`
- `:388` → `_assertNoMaxAllowances(adapter, dai);`
- `:520` → `_assertNoMaxAllowances(locked_, IERC20(address(probe)));` — this is the bug fix; the helper now reads `address(locked_)`, the adapter that actually executed the callback route.

---

## 4. What must not change (full consensus)

All three peers and my original converge on the same "must not change" list. I record it once here for the plan:

- The nested-entry lock assertions at `:514–516` ("callback stages ran", `lockedHits() == attempts()`, `assertFalse(probe.succeeded())`). PRD acceptance bullet 3.
- Outer success at `:513` (`assertGt(out_, 0, "outer join completes")`).
- The in-flight route-budget assertions at `:517–519` (`probe.inFlightRouter() == amountIn_`, `probe.inFlightPermit2() == amountIn_`, `probe.inFlightRouter() != type(uint256).max`).
- The final `probe.balanceOf(address(locked_)) == 0` ("join input was consumed") at `:521` — already correctly names `locked_`. Must not be retargeted to `address(adapter)`.
- The rollback twin `test_RC01_callback_propagatedLock_rollsBack` at `:525–552`. In particular, `:552` already asserts `probe.allowance(address(locked_), address(router)) == 0` and is the pattern the helper should now follow.
- The `AdapterLockProbeToken` implementation at `:620–691` and its constructor inputs at `:494` (`router` and `permit2`).
- The helper's `internal view` nature.
- All other tests in the file. The four non-callback callers at `:330`, `:341`, `:374`, `:388` continue to pass `adapter`, the instance they exercise.
- No new `try/catch`. No production-side code change. No test-side allowance-reset before asserting cleanup. No claim of a production allowance leak.

---

## 5. Specific objections and corrections

### 5.1 Agreement with specific corrections noted in peer originals

- **Grok line 28 ("`address(adapter)`" at `:330` and `:341`):** correct. The token argument at those sites is `bpt` (BPT), and the adapter under test is the storage `adapter` (via `_assertLargeLiquidation`, `:317–342`). The ERC20 allowances checked are `bpt.allowance(address(adapter), address(router))` and `bpt.allowance(address(adapter), address(permit2))`. Both are correct as written today and remain so after the helper signature change.
- **Kimi lines 14–15 (note that `:552` already names `locked_` correctly):** confirmed. The rollback twin is the de-facto template the helper now has to match.
- **Astra lines 18–19 (helper hardcodes `address(adapter)` in five allowance positions, `:110, :114, :118, :120, :121`):** I count the same five positions in my own independent reading. Agreed.

### 5.2 Cross-PRD evidence I re-checked

- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` lines 110–120 (REQ-SEP-01 section): the acceptance bullets and non-goals are what I quoted in my first pass. The PRD does not specify a helper signature; it specifies (a) the assertions must name the adapter under test, (b) router and Permit2 allowances must be zero after success, (c) the nested-entry lock assertion must remain, and (d) no `catch`, no production-allowance-leak claim. The signature must therefore be inferred from these bullets; `IStandardExchange` is the inference that fits every bullet and the test's existing type declarations.

### 5.3 No peer-original finding changes my view

I find no evidence in any of the three peer originals that would push me to revise my first pass. The disagreement is a legitimate signature-shape choice; the rest is convergent.

---

## 6. Dissent or unresolved items

None. The fix is closed, the signature is locked by my recommendation above, and every non-goal is respected by every reviewer.

---

## 7. Files examined (this cross-review)

- `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/astra-sep01.md` — read in full.
- `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/grok-sep01.md` — read in full.
- `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/kimi-sep01.md` — read in full.
- `docs/reviews/apex-req-sep-01-callback-adapter/reviewers/minimax-sep01.md` — my own original; re-read for self-consistency. Not treated as a peer.
- No source files were re-read for this cross-review; my line citations are inherited from my first pass and re-verified against the source I already loaded. Where peers cited lines that matched mine, the convergence is noted; where they differed, I re-confirmed against the source on disk.

No Forge / build / test was executed.

---

I did not run Forge.