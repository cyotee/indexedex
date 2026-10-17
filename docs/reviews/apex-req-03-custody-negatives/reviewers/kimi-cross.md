# Kimi K3 — cross-review: REQ-03 custody negatives

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My original is `kimi-original.md` in this directory. The three peer originals were read in full as untrusted model output. The controlling text is Stage-1 REQ-03 (`docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:223-235`), re-read in my first pass. No code edited. This round's `REMEDIATION_PRD.md` was not read or written.
- **Date:** 2026-10-14. I did not run Forge; all verdicts are source readings.

## Point 1 — reentrancy bullet: already satisfied (Grok) or partial (Kimi, Astra, MiniMax)?

**Partial. I keep my P-1; I agree with Astra (REQ03-1) and MiniMax's verdict, and dissent from Grok's "already satisfied."**

Re-read evidence this round:

- The test's outer expectation is `SafeTransferLib.TransferFromFailed` (`RebasingAwareERC4626_Adversarial.t.sol:140`); the nested `IsLocked` equality lives inside the callback frame (`:30-31`), which then deliberately re-bubbles (`:32`).
- The production pull normalizes any token-call failure into that same outer selector: `pullAssets` uses `asset.safeTransferFrom(...)` (`RebasingAwareERC4626Common.sol:274-278`). So a nested frame that reverts for any reason — a wrong nested error, or a failed inner assertion — surfaces as the exact error the test expects. The file's own comment concedes the wrap (`:26-27`).
- Astra supplied the assertion-semantics evidence I lacked: forge-std `assertEq` uses native `vm.assert*` (`StdAssertions.sol`), and with the default `assertions_revert = true` the failure is a local revert that does not set the runner's global failure flag — so a failed inner assertion, bubbled and wrapped, still satisfies the outer `expectRevert`. That matches my inference; I cite Astra's documentation links as unverified-by-me external evidence but the production wrap at `:274-278` is enough on its own.
- Grok's account ("the nested check has already run") describes reachability, not oracle strength: the nested check running is not the nested check being able to fail the test. The no-partial-credit assertions (`:143-146`) are genuinely good and must be kept; they do not pin the error's identity.

**On fix direction, I agree with Astra and dissent from MiniMax's G2 shapes.** MiniMax proposes making the outer `expectRevert` pin `IsLocked` directly, e.g., by having the harness return success on `transferFrom` when the inner call reverts `IsLocked`, or reentering a path that does not call `transferFrom`. The wrap into `TransferFromFailed` is production API behavior of the vault's pull, not a harness artifact; routing around it either changes what the test exercises or demands a production change REQ-03 does not authorize. The sound repair is Astra's (and my P-1's): record the nested `(ok, reason)` where the wrap cannot erase it (test-contract storage before the deliberate re-bubble) and assert it after the outer call, keeping the outer transfer error as the production behavior and keeping `:143-146`. Astra's criterion 5 states this explicitly; MiniMax's acceptance criteria would push the pin in the wrong place.

One partial agreement with MiniMax's framing: a reader verifying the bullet from the outer `expectRevert` line alone would not see the nested pin — that is a real readability defect, but the substantive defect is the swallowed oracle, not the selector's location.

## Point 2 — must the fuzz success half also assert total supply?

**Yes. I agree with Astra (REQ03-2) and dissent from Grok and MiniMax's "already satisfied."**

The bullet's noun list is symmetric: "asserts shares, balances, and reserves **are unchanged on rejection and exact on success**" (REQ-03 `:233`). The test's own rejection half reads "shares" as including total issuance: it captures `supplyBefore` (`RebasingAwareERC4626_Fuzz.t.sol:65`) and asserts total supply unchanged on rejection (`:81`). The success half (`:96-100`) asserts the recipient's shares, the paid amount, both asset balances, and the reserve — but never asserts total supply, leaving the captured `supplyBefore` unused. Under the symmetric reading, exact shares on success includes exact total issuance (`supplyBefore + shares`); without it, an additional mint to another account would escape the oracle while every current assertion still passes. No such production behavior is claimed — Astra's read of the mint path (`RebasingAwareERC4626Common.sol:392` mints only to the receiver) makes this a coverage-precision gap, not a suspected defect.

I explicitly note the alternative: if the coordinator reads "shares" as the recipient's shares only, the bullet is satisfied as written and Astra's assertion is an optional strengthening. I adopt the symmetric reading because the test's rejection half already treats total supply as part of the named state. The closure cost is one assertion using the already-captured `:65` value; nothing else about the test changes.

## Point 3 — scanner gap: unverified only (Astra, Grok) or confirmed by cited escaping files (Kimi)?

**Confirmed gap, with one caveat preserved. I keep my first-pass position and dissent from Astra and Grok's "unverified"; MiniMax's own evidence completes the chain.**

What changed since the peers' texts: MiniMax located the family-level D16 inventory at `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:335`. I re-read that row this round: D16's SE vault set explicitly names "ERC-4626 SE" and "RebasingAware custody SE/SY." My first-pass escapes are regression files in those named families, read this round:

- `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol:332,335,383,409,559` — five bare `vm.expectRevert()` calls, no APEX marker (grep count 0), directory under neither fixed root (`scripts/apex_bare_expectrevert_scan.sh:14-17`).
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Accounting.t.sol:131,143` — bare `vm.expectRevert()`, no marker, same custody directory as the two named files but not itself named (`:18-21`).

The scanner exists to reject exactly this pattern under R2.4; files in enumerated D16 families carry it and escape selection. That is a demonstrated gap, not an inferred file list — I name two instances, not an inventory.

**Caveat preserved (partial agreement with Astra/Grok):** the clause says "the full D16 regression inventory *used for R2.4*." If the coordinator reads that as only the files cited as remediation evidence, a documented evidence manifest would still be needed to prove inclusion or exclusion of these two files; no such manifest was located by any pass. And the full family→test-file mapping remains uncodified — codifying it is part of the fix. On shape, MiniMax's G4 acceptance criteria (record the map, extend selection to cover it, keep roots/custody/regex) are the right closure and match my P-2's direction; Astra's caution against inventing the inventory is incorporated there.

## Disposition of my first-pass proposals

- P-1 (load-bearing nested-error pin): kept; converges with Astra-REQ03-1. MiniMax's G2 verdict agreed, its fix direction rejected.
- P-2 (scanner bound to a defined inventory): kept; strengthened from "demonstrated escapes, inventory unverified" to "gap confirmed at family level via D16 row `:335`; authoritative map still to be codified."
- Newly adopted: Astra-REQ03-2's success-side total-supply assertion (bullet 3 → partial). My first pass marked bullet 3 satisfied; Astra's symmetric reading and the unused `supplyBefore` capture changed my verdict.

## Unresolved dissent

- Grok holds the reentrancy bullet already satisfied; Astra, MiniMax (verdict), and I hold it partial. The dispute is about oracle strength, not about the production guard, which no pass questions.
- Grok and MiniMax hold the fuzz bullet satisfied; Astra and I hold it partial on the symmetric reading of `:233`. One-sentence textual question for the coordinator: does "shares ... exact on success" include total issuance, given the rejection half asserts it?

I did not run Forge.
