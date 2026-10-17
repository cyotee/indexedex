# Grok cross-review — REQ-SEP-01

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Peers read:** `astra-sep01.md`, `minimax-sep01.md`, `kimi-sep01.md`
- **MiniMax:** labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.

Peer notes are untrusted. This file does not authorize an edit.

## Verdict

Agree. No owner question remains. The fix is test-only and closed.

The helper parameter type differs. The PRD must use this signature and no other:

`function _assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view`

## Agreements

- All four first passes agree the exercised instance is `locked_`, and the helper at lines 108–122 reads the fixture `address(adapter)`.
- Line 520 must pass `locked_`. Lines 330, 341, 374, and 388 must keep the fixture `adapter`.
- The six checks stay: ERC20 allowance to `router`, ERC20 allowance to `permit2`, and the Permit2 packed amount for `(owner, token, router)`, each not max and each zero.
- Lines 513–516, 517–519, and 521 stay. No `catch`. No production edit. This is not a production allowance leak.

## Signature

`IStandardExchange` is already imported at line 15. `adapter` and `locked_` are that type. `address(subject_)` is the allowance owner inside the helper.

Rejected alternatives:

- Grok's first pass, `address exchange_` first. The type is wider than the two call-site variables and is not the PRD signature.
- Kimi's `(IERC20 token_, address owner_)`. Token-first order and `address` are not the PRD signature.
- MiniMax's parameter name `adapter_`. It shadows the fixture member. The name is `subject_`.

Call sites, with that signature:

- `:330` and `:341`: `_assertNoMaxAllowances(adapter, bpt)`
- `:374` and `:388`: `_assertNoMaxAllowances(adapter, dai)`
- `:520`: `_assertNoMaxAllowances(locked_, IERC20(address(probe)))`

## Dissent

None on scope or on whether an owner question remains. The only correction is the signature above.

## Unresolved

None.

I did not run Forge.
