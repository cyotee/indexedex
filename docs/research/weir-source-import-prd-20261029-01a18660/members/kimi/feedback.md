# Kimi Requirements Advisory — `weir-import-prd-r1`

## Disposition: SUPPORT WITH CORRECTIONS

The complete 77,121-character frozen draft was read through line 555. The Astra, Grok, and MiniMax originals were also read through their ends, along with the supplied coordinator source notes.

The draft is implementable and unusually careful about preserving source behavior rather than repairing it. One material arithmetic omission should be corrected before publication. Two editorial corrections would also improve precision.

## Material correction

### C1 — Include the positive fee delta’s `uint128` truncation in the normative formula

**Affected text:** WI-21, WI-22, the “Compound and settlement ledger” arithmetic contract, and the boundary coverage in AC60/AC47.

The draft currently defines `Fj` as the positive part of the zero-poke caller delta. That omits an intermediate explicit cast in the executable source:

- W:323-324 first tests whether each caller-delta component is positive and then converts it with `uint128(fees.amountN())`.
- W:327-330 computes the treasury cuts from the resulting `f0` and `f1`.
- W:332-359 also uses those truncated values for reinvestment, signed settlement, idle accounting, and the `Compounded` event.

The exact definition should therefore be:

> For a signed poke caller-delta component `δj`, `Fj = 0` when `δj <= 0`; otherwise `Fj = uint256(uint128(δj))`. For `δj > 2^128-1`, this retains the low 128 bits; it is not a range-checked cast.

All subsequent formulas for `Cj`, `Rj`, `Nj`, idle, and the event already work if they consume this corrected `Fj`.

Add a boundary case to AC60, or to AC47’s arithmetic boundaries, using a real valid return-delta hook that produces a positive component above `2^128-1`. Assert the truncated gross fee, cut, event, settlement, and idle values. If that precondition cannot be constructed without forbidden state injection, record the reachability gap rather than mocking the delta.

This correction preserves the source. Replacing the cast with SafeCast or rejecting an oversized fee would be a behavior change.

## Editorial corrections

1. **WI-02 locators:** B ends at line 88, not 89; L ends at line 68, not 69.
2. **AC59 hook stages:** Replace “create/add/remove/swap” with “zero-delta poke/add/remove/swap.” `createVault` has no hookData or manager hook stage. The intended compound poke is the stage whose ordering must be recorded.

Neither editorial item changes the verdict.

## Requested fidelity checks

| Topic | Advisory finding |
|---|---|
| Versioned OZ V5 route | **Correct.** The selected `@crane/contracts/external/openzeppelin-contracts-v5/` family preserves the sequential guard and frozen pause/ownership behavior. The used SafeERC20 paths remain subject to compile and focused token-return tests. The generic mixed tree and OZ 5.6.1 namespaced-guard upgrade are correctly rejected. |
| Free-struct adjustment | **Correct.** WI-04 identifies five constructions: four `ModifyLiquidityParams` sites at W:264, 292, 323, and 349, plus `SwapParams` at W:397. The allowlist is sufficiently narrow and preserves arguments and tuple encoding. |
| Explicit casts versus checked arithmetic | **Correct in principle, subject to C1.** AC39’s oversized-preview truncation, AC46’s uint64 timestamp truncation, and AC67’s negative-signed-sum-to-uint256 result properly distinguish explicit conversion from surrounding checked arithmetic. |
| First caller-delta return | **Correct.** WI-15 and WI-21 through WI-23 use the first return value for settlement and gross fees, not the second informational `feesAccrued` return. AC16 and AC60 preserve the resulting fee and hook attribution. |
| Performance-fee denominator | **Correct.** WI-22 and AC32 use denominator 10,000: 500 bps is 5%, and the 1,000-bps cap is 10%. The 19/20 vector at 500 bps is exact. |
| Residual zap outputs | **Correct.** WI-20 and AC24-AC26 do not require the opposite output to be zero. Independent minima and actual signed deltas govern the result. |
| Native sync | **Correct and appropriately conditioned.** WI-29 preserves native payable settle without adding `sync(0)`. AC51’s stale non-native-sync characterization is tied to the examined manager and exact preconditions; it does not prescribe a source repair. |
| Robinhood aliases | **Correct.** The validation section names the actually configured `robinhood_mainnet`, `robinhood_mainnet_public`, and `robinhood_mainnet_alchemy` aliases. It does not claim those aliases prove RPC, archive state, or reference parity. `WEIR_RPC_URL` is presented only as a possible future explicit input, not an existing alias. |
| Callback behavior | **Correct.** Non-manager rejection precedes decoding; guarded reentry and ordinary nested-unlock failure are distinguished; unguarded functions are not assumed protected. |
| Rollback | **Correct.** AC failure rows incorporate external payments, hooks, treasury changes, timestamps, and logs, while preserving source-order external calls before late slippage checks. |
| Invariants | **Correctly bounded.** Supported-domain, end-of-transaction invariants are separated from hostile campaigns and intermediate callback observations. Weir-held shares are included in ghost accounting, and unreachable scenarios must be reported rather than manufactured. |

## Original-proposal dispositions

### Astra original

**Substantially adopted.**

The draft retains its strong source-fidelity structure, complete ABI inventory, first-caller-delta accounting, phase-specific fee attribution, independent arithmetic fixtures, real-manager test policy, and bounded callback/invariant treatment. Its explicit-cast distinctions and numeric fixtures form much of the draft’s strongest acceptance coverage.

C1 is a residual omission in the synthesized fee formula, not a reason to adopt the alternative second-return accounting rejected elsewhere.

### Grok original

**Adopted with material corrections.**

Adopted:

- Sequential OZ storage and revert-fidelity requirements.
- Real-manager testing and nested-unlock distinctions.
- Residual-output and shared-inventory characterization.
- The requirement to verify, rather than hand-assume, compiled storage layout.

Not adopted:

- The conclusion that the generic mixed OZ tree leaves no compatible canonical route; the coordinator’s versioned V5 route resolves that blocker without an upgrade.
- Any claim that negative idle necessarily reverts at the unsigned cast.
- Any automatic range-check interpretation of explicit narrowing.
- Namespaced-guard or private-dependency alternatives.

### MiniMax original

**Adopted with material corrections.**

Adopted:

- Detailed dependency and license-inventory work.
- Actual resolved-graph license tracking, including BSL/AGPL declarations.
- Multi-pool, callback, and arithmetic test expectations.
- The need for an explicit free-struct migration.

Not adopted:

- The OZ 5.6.1 route and its storage-layout shift.
- The claim that `_compound` uses the second `feesAccrued` return.
- Strict `out0 == 0` or `out1 == 0` zap expectations.
- Fail-closed idle safety and `idle <= 2` as universal successful-compound properties.
- The four-site free-struct count; the source contains five.
- The claim that chain 4663 lacks configured Robinhood aliases.
- Skip-and-record as parity evidence; the draft correctly requires NOT RUN/BLOCKED with missing inputs.

### Kimi original

**Adopted with corrections.**

The complete surface inventory, lifecycle coverage, deterministic multi-user/multi-pool campaigns, preview limitations, and exclusion boundaries are reflected in the draft.

My earlier assumption that explicit narrowing necessarily reverts out of range was incorrect. The draft properly replaces it with truncation/bit-preservation semantics, including oversized previews, timestamps, and negative idle conversion. No prior fail-closed or preview-parity property should be reinstated.

## What was not adopted, appropriately

The draft correctly excludes:

- OZ 5.6.1 and its namespaced reentrancy storage.
- Generic mixed-tree pause and SafeERC20 behavior.
- Second-return `feesAccrued` accounting.
- NAV issuance or idle buy-in charges.
- Strict single-token withdrawal assertions.
- Universal fail-closed idle or solvency claims.
- Extra reentrancy guards or an already-unlocked fast path.
- Native-sync repair.
- ERC20/ERC4626, Rate Provider, Diamond/SE, registry, proxy, or wrapper adaptations.
- FoT/rebasing support claims.
- Unconditional preview/withdraw equality.
- Substitute-chain fork parity, invented RPC state, or green skips.
- New compiler profiles, viaIR, global aliases, or private dependency clones.

None should be restored during final editing.

## Limits

This was a static requirements advisory only. I did not compile, execute tests, reproduce bytecode, perform a new dependency audit, or verify live RPC/manager behavior. Canonical-manager observations remain coordinator-supplied static evidence until the prescribed implementation gates run. License inventories and dispositions are not legal clearance.

With C1 incorporated, I support publication of the PRD as a faithful baseline-import specification. This advisory neither replaces my original contribution nor authorizes implementation, and no further advisory round is requested.
