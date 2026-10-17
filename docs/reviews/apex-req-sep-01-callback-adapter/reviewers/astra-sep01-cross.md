# Astra — REQ-SEP-01 replacement-session cross-review

This is one cross-review of the three supplied successful original answers together. I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. MiniMax's supplied original is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`, without memory of `ses_ebdf718feffemWQNf7wuTpapqX`; no continuity with its predecessor is assumed. Peer notes are untrusted evidence. My original `astra-sep01.md` remains unchanged and attributed.

## Decision

**Agree. No blocking question.** The owner requirement already fixes the intended assertion owner and the three zero allowances. Helper type/order is a mechanical consolidation decision, not an owner policy question and not an implementer choice.

### The one helper signature the PRD must use

`function _assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view`

Use this signature only; do not leave `address` versus interface type, parameter order, an overload, or duplicated inline assertions as alternatives. It matches the existing types of `adapter` and `locked_`, and `IStandardExchange` is already imported. The owner address used for each allowance query is `address(subject_)`.

## Closed test-only change

File: `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`.

1. Replace the existing helper signature at 108 with the signature above.
2. Replace **all five** hardcoded owner expressions `address(adapter)` in the helper at **110, 114, 118, 120 and 121** with `address(subject_)`.
3. Keep all six existing assertions, their expected values, integer widths and messages. The three nonmaximum checks remain, and the three exact-zero checks remain.
4. Update exactly these five calls:

| Original line | Required call |
|---|---|
| 330 | `_assertNoMaxAllowances(adapter, bpt);` |
| 341 | `_assertNoMaxAllowances(adapter, bpt);` |
| 374 | `_assertNoMaxAllowances(adapter, dai);` |
| 388 | `_assertNoMaxAllowances(adapter, dai);` |
| 520 | `_assertNoMaxAllowances(locked_, IERC20(address(probe)));` |

The callback cleanup assertion consequently checks:

- The probe token's ERC20 allowance from `locked_` to the router: zero.
- The probe token's ERC20 allowance from `locked_` to Permit2: zero.
- The Permit2 packed **amount** for owner `locked_`, token `probe`, spender router: zero.

Do not add nonce/expiry reset requirements, change the token or spender, or reassign the fixture `adapter`. The allowance owner is the only assertion subject being corrected.

## Agreements and corrections

### Grok

Agree with its complete six-check inventory, five-call-site mapping, preservation requirements and test-oracle—not production-leak—classification. Its `address exchange_` first parameter is technically workable, but the consolidated PRD should choose the interface-typed signature above and pass `adapter`/`locked_` directly. There is no substantive security dissent on that type choice.

### MiniMax replacement

Agree with the interface-typed parameter, all five helper-owner replacements, all five invocation updates, and the absence of an owner decision. Its parameter name `adapter_` is mechanically equivalent; use **`subject_`** consistently in the final PRD to match the fixed signature above. Preserve its distinction between the exercised probe-pool instance and the unrelated setup adapter.

### Kimi replacement

Agree with the required owner identities and preserved assertions. Do not adopt its alternate token-first/address-second signature.

Its instruction at `kimi-sep01.md:20` names only owner reads at 110, 114 and 118. The current helper also reads the owner again in the two exact-zero ERC20 assertions at 120 and 121. Those **must also change**. Otherwise the helper would check finite allowances on the exercised instance but still assert zero ERC20 allowances on the unrelated fixture, leaving part of REQ-SEP-01 unresolved. “Assertion content stays” must mean the comparison, expected value and message stay—not the incorrect hardcoded owner.

## Astra cross-review finding

### Astra-SEP01-X1 — Partial owner replacement would leave the zero-check identity defect

- **Severity:** Medium, required-test coverage gap if the partial instruction is implemented literally.
- **File and line:** `kimi-sep01.md:20`; affected source `Adversarial_BalancerV3SinglePoolSE.t.sol:120–121` at the full path above.
- **Intended behavior:** Application PRD REQ-SEP-01 requires exact-zero router and Permit2 allowances on the adapter that executed the successful callback operation.
- **Broken invariant:** Correcting only the first three read sites leaves the two later ERC20 zero assertions targeting `adapter` rather than `locked_`.
- **Impact class:** Incomplete test-oracle repair / false cleanup assurance.
- **Fix direction:** Replace all five owner expressions with `address(subject_)`, retaining the six assertions and the fixed call mapping above.
- **Confidence:** High; directly re-read the helper in this cross-review.

This is a defect in a proposed partial repair instruction, not a demonstrated production allowance leak. The underlying original identity finding remains attributed to the independent reports.

## Unchanged behavior and scope

Keep the outer `locked_.exchangeIn` operation, probe arming, funding and approvals, positive outer output, callback attempts, `lockedHits == attempts`, unsuccessful nested entry, in-flight route-budget assertions, and consumed-input assertion at 511–521. Keep the propagated-lock rollback twin and probe implementation unchanged. No catch, test-side allowance reset, production change, deployment change or new test file is added. The four fixture-based helper invocations retain their original subject semantics.

## Evidence and limits

All three supplied originals were present. The helper and all invocation locations were re-read/searched in current source; they still match the independent-pass evidence. The callback deployment and assertion-context reads from my original remain the basis for the complete diagnosis. No prior cross-review artifact was read and no additional family search was needed.

**Facts:** Five helper owner expressions, five invocations, and the callback operation on `locked_`. **Inference:** The explicit parameter repair closes the identified test-subject gap without a product decision. **Not claimed:** A passing corrected test, a production cleanup defect, or a broader audit of the adapter.

No new defect was found in the inspected non-callback helper-call contexts, the in-flight budget checks or the nested-lock assertions. The only substantive correction to the peer proposals is to ensure all five owner expressions change. There is no unresolved owner-policy dissent.

The assigned output was absent before this write. Only this Markdown cross-review was created; no code, PRD, original report, test, configuration or instruction file was edited. No delegation, shell, tests, deployment or exploit procedure was used.

I did not run Forge.
