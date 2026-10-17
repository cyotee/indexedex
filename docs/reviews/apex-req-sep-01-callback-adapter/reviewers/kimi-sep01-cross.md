# Kimi K3 — cross-review: REQ-SEP-01 callback adapter first passes

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t` (does not recall `ses_ebdf718feffemWQNf7wuTpapqX`). My original is `kimi-sep01.md`. The three peer originals were read in full as untrusted output; the controlling text (`docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:110-120`) and the test file were read directly this session. Nothing was edited.
- **Date:** 2026-10-16. I did not run Forge.

## Assigned question — "no owner question remains and the test-only fix is closed"

**Agree, unanimously.** All four passes independently conclude: no blocking owner question; the gap is exactly the helper reading the fixture `adapter` while the RC-01 test exercises `locked_`; the fix is test-only and closed by the PRD's acceptance criteria. Every pass verified the same structure: `locked_` deployed at `:495` and exercised at `:511`; helper hardcoding `address(adapter)` at `:110-122`; the other four call sites (`:330, :341, :374, :388`) correctly measuring the fixture they exercise; the rollback twin already naming `locked_` at `:552`. No pass claims a production allowance leak, and none adds a `catch`. MiniMax's added detail — the two instances are distinct CREATE3 deployments with different salts and pool bindings (`:607-616` vs the `setUp` fixture at `:73`) — is consistent with what I read and strengthens the identity-mismatch framing.

## The helper signature differs — the one signature the PRD must use

The four drafts propose four forms: mine `(IERC20 token_, address owner_)`, Grok's `(address exchange_, IERC20 token_)`, Astra's `(IStandardExchange subject_, IERC20 token_)`, MiniMax's `(IStandardExchange adapter_, IERC20 token_)`. One must be fixed:

> **`function _assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view`** — inside the body, replace every `address(adapter)` with `address(subject_)`; nothing else in the six assertions changes.

Reasons for this over the other three:

1. **Type safety:** the subjects are exchange adapters; both call-site variables (`adapter` at `:58`, `locked_` at `:495`) are already declared `IStandardExchange`, so the typed parameter accepts them with no cast and rejects an arbitrary address at compile time. Grok's and my `address` forms forfeit that.
2. **Minimal body diff:** the existing body already wraps the owner in `address(...)` at `:110, :114, :118`; the typed form keeps that pattern (`address(subject_)`), while the `address`-parameter forms delete the wrapping — a gratuitous reshape.
3. **Parameter name:** `subject_` (Astra) over `adapter_` (MiniMax) — a parameter named `adapter_` sits one underscore from the fixture member `adapter` it exists to disambiguate; that naming invites the exact confusion being fixed.
4. **Parameter order:** subject first, token second (Astra, MiniMax) — the call reads "assert no max allowances on this subject for this token"; no caller reorders arguments incorrectly because all five sites are rewritten in the same edit.

With that signature, the five call sites are exactly: `:330` and `:341` → `_assertNoMaxAllowances(adapter, bpt)`; `:374` and `:388` → `_assertNoMaxAllowances(adapter, dai)`; `:520` → `_assertNoMaxAllowances(locked_, IERC20(address(probe)))`. The four fixture calls keep their semantics; only `:520` changes meaning — the fix.

**Correction to my original:** I proposed `(IERC20 token_, address owner_)`. Astra's typed, subject-first form is better for reasons 1–3; I adopt it and withdraw mine. Grok's is functionally adequate but typed-less.

## Agreements worth restating as plan constraints

- The six assertion contents are untouched: three `!= max` guards (ERC20 router, ERC20 Permit2, Permit2 packed uint160) and three `== 0` resets; Astra's explicit guard is adopted — do not extend the helper to Permit2 nonce/expiry; the requirement concerns the packed amount only.
- What must not change (all four passes agree): the nested-entry lock witness `:514-516`, the in-flight route-budget assertions `:517-519`, outer success `:513`, join-consumed `:521` (MiniMax's note: it already names `locked_`; do not retarget it), the rollback twin `:525-552`, the probe implementation, the fixture member `adapter` itself (Astra's explicit prohibition on mutating the fixture to make the old helper accidentally inspect `locked_` — adopted; explicit subject passing is the repair), and all production files.
- No new test file, no production edit, no `catch`, and no claim of a production allowance leak — the PRD's non-goals, restated by every pass.

## Unresolved dissent

None. The only divergence was the helper signature, ruled on above; the fix is otherwise identical across all four passes. Consensus is not proof — the corrected assertions have not been run, and no pass claims they pass.

I did not run Forge.
