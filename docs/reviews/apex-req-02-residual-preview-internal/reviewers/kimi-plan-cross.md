# Kimi K3 — plan cross-review (REQ-02 residual preview)

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My own draft is `kimi-plan.md` in this directory; the three peer drafts were read in full as untrusted model output. The controlling PRD (`../REMEDIATION_PRD.md`, re-read in the first pass) controls over every draft, including mine.
- **Date:** 2026-10-14. **Scope:** only the three assigned points. I did not read `REMEDIATION_PRD.plan.md`. No code edited.

## Point 1 — keep `previewResidualBuffer` and flip it to `internal`, versus inline-and-delete

**Agree with Astra and Grok (and my own draft); dissent from MiniMax.**

The PRD's required repair is a visibility change to the existing function: "Change `previewResidualBuffer` in `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol` from `external` to `internal`. Keep the body a direct `previewExchangeIn`." The acceptance criteria require the function to persist ("`previewResidualBuffer` is `internal` and contains no `catch`"). The PRD's "inlined into the sweep" sentence ("Why internal") describes what Solidity already does with an `internal` library function — it is inlined into each calling contract, replacing today's DELEGATECALL — so the visibility flip is the whole mechanism. Grok states this correctly (`grok-plan.md` "What was re-read": external library functions are DELEGATECALLs; internal ones inline).

MiniMax's step 2 (`minimax-plan.md:62-104`) instead deletes the `ClaimLib.previewResidualBuffer(excess)` call from the three reached sweeps and pastes the quote body in, leaving the internal ClaimLib declaration with no callers (its own end-state rule: "The only hits must be the `internal` declaration in `ClaimLib`"). That is a larger edit to three production sweep files for zero behavioral gain, it strands the function the acceptance criteria still name, and it is internally inconsistent: MiniMax leaves the SeTarget copy "untouched" (`:98`), but SeTarget's sweep at `:485` still calls `ClaimLib.previewResidualBuffer`, which violates MiniMax's own "only hits" rule. Fix direction if MiniMax's text were ever adopted: drop step 2; the flip alone satisfies the PRD.

Verified this round: repo-wide grep over `contracts/` finds `previewResidualBuffer` in exactly five files (the ClaimLib declaration at `:384` and the four sweep call sites `DepositCommon:375`, `WithdrawalLib:138`, `Target:396`, `SeTarget:485`); no interface declares it. All four call sites compile against an `internal` library function unchanged, so the PRD step-3 stop-and-report contingency is expected to be unused but stays armed in all four drafts.

## Point 2 — which sweep copies a production TestBase hook actually reaches

**Agree with Grok (fully) and Astra (substantively); dissent from MiniMax's three-copy claim.**

Verified deployment shape: `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol:115-125` installs `seFacet`, `depositFacet`, `depositSingleFacet`, `depositPreviewFacet`, `withdrawFacet` via `PkgFactory.deployPackage`/`deployHook`. Facet→target inheritance (facet files under `facets/`): DepositFacet → DepositTarget → DepositCommon; DepositSingleFacet → DepositSingleTarget → DepositCommon; WithdrawFacet → WithdrawTarget; SeFacet → SeTarget. No contract in `contracts/` inherits the monolithic `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` (inheritance/import grep; only documentation/evidence files name it).

Reachable copies:

- **DepositCommon `_refundPairDust` (`:367-379`)** — reached from `_deposit` (`:491`), `_depositWithSeShares` (`:582`), `_depositSingle` (`:712`); public entries `deposit`/`joinProportional`/`joinUnbalanced`/`depositWithSeShares`/Permit2 variants on DepositTarget (`:21-138`) and `depositSingle` + variants on DepositSingleTarget (`:64-97`).
- **WithdrawalLib `refundPairDust` (`:131-142`)** — two verified linkages: (a) `withdraw` (`WithdrawTarget:477`) → `_withdraw` (`:507`) → wrapper `_refundPairDust` (`:338-340`) → `Withdrawal.refundPairDust`; same wrapper from `_withdrawSeShares` (`:575`), entry `withdrawSeShares` (`:497`); (b) `withdrawSingle` (`:486`) → `_withdrawSingle` (`:593`) → `_withdrawSingleFrom` (`:603-607`) → `Withdrawal.withdrawFrom` (`WithdrawalLib:26-27`), which calls `refundPairDust()` at `:66` after `syncReserves()`/`setKLast()` (`:64-65`). I re-read (b) this round; it upgrades the "linkage unconfirmed" note in my draft. Grok's further note that the SY exit path (`DepositSingleTarget._redeemVaultHeld:42-45`) also enters `withdrawFrom` is consistent with that file's earlier read; I did not re-verify its body this round and treat it as supplementary.

Unreachable copies:

- **Monolith Target `_refundPairDust` (`:388-400`)** — in-file callers exist (`:846`, `:971`, `:1139`, `:1215`), but no installed facet inherits the contract, so no production proxy route reaches them. **Dissent from MiniMax** (`minimax-plan.md:25,36`), which maps the proxy entries `single.deposit`/`single.withdraw`/`single.withdrawSingle` to the monolith's sweep. On the deployed diamond those selectors route to the split facets (DepositTarget/WithdrawTarget), not to the monolith; MiniMax's own citation (`single.deposit (line 846)`) is the monolith's *in-file* call site, not proxy routing. MiniMax double-counts one proxy entry as witnesses of two different copies. Astra's disposition ("source-local callers vs. installed-proxy reachability; recheck during implementation") is the careful version of the same conclusion and is acceptable.
- **SeTarget `_refundPairDust` (`:477-489`)** — no caller in the file (grep; all four drafts agree). Cite, do not add an entry.

Consequence for the test matrix: Case 1 and Case 2 are exercised against the DepositCommon copy (e.g. `deposit`) and the WithdrawalLib copy (e.g. `withdraw`; `withdrawSingle` is an equivalent entry on the same copy). The monolith-Target and SeTarget copies are cited as unreached. This matches my draft and Grok's; Astra's recheck instruction is compatible.

## Point 3 — may Case 2 fault a non-SUT harness `balanceOf`?

**I narrow my own draft toward the peers: the default is stop-and-report; the harness-fault construction requires an explicit coordinator ruling and is not the plan's default.**

Facts verified this round: the bound SE's preview path (`ERC4626StandardExchangeCommon.sol:35-70`) has no disable/pause check (no `_requireNotDisabled` anywhere in `contracts/vaults/standard/erc4626/`), `_requireNonZero` (`:38`) is unreachable from a sweep (excess ≥ 1 whenever quoted), and `SimpleYieldERC4626`'s quote math (`:102-132`) cannot revert. So no production state of the bound vault makes the sweep's `previewExchangeIn` revert — Grok, Astra, and MiniMax all reach this conclusion, and my draft's verification agrees.

The PRD anticipates exactly this: "If no production state makes that preview revert, stop. Report that the revert case was not reached. Do not mock the vault." (Case 2 step 5), and "A pause, a disabled vault, or another rejection the production vault already exposes may be used" (step 2) — a `vm.mockCallRevert` on the harness is not a vault state. My draft proposed faulting `pairProtocolVault.balanceOf(se)` (the non-SUT harness read inside `_receiptBacking()`, `ReceiptBackedERC4626AccountingLib.sol:23`) as the primary route, citing the accepted DETF precedent (`UniswapV4DetfLeftoverPreview.t.sol:91-97`). On cross-review I judge that precedent insufficient authority: it was written under a different PRD without this item's "state the vault already supports" language, and Astra's draft independently forbids mocking the quote dependency ("do not ... mock the vault/token quote"). Revised position: implement Case 1 fully; for Case 2, report not-reached with the evidence above, unless the coordinator explicitly accepts the harness-fault construction, in which case my draft's test shape (distinct fault selector, unchanged-balance assertions, `vm.clearMockedCalls()`) is the one to use.

**One correction to MiniMax within this point:** MiniMax's blocking question claims Case 1 may be unreachable because "`SimpleYieldERC4626.convertToShares` returns positive for any positive assets in that regime." That is arithmetic, and it is wrong: `SimpleYieldERC4626.sol:105` returns `(assets * supply) / totalAssetsStored`, which floors to 0 whenever `assets * supply < totalAssetsStored`. `simulateYield` (`:187-190`) raises `totalAssetsStored` without minting shares, so a wei-sized excess quotes zero — the same backing-inflation construction the council accepted in `UniswapV4DetfLeftoverPreview.t.sol:41-42`. Case 1 is reachable on the unmodified TestBase; MiniMax's option (a)/(b) dilemma is moot.

## Disposition of my own draft

- Point 1: unchanged (keep-and-flip).
- Point 2: unchanged in conclusion; the `withdrawSingle` → `withdrawFrom` → sweep-`:66` linkage is upgraded from "unconfirmed" to verified (`WithdrawTarget:603-607`, `WithdrawalLib:26-27,64-66`).
- Point 3: narrowed as above — harness-fault demoted from primary route to coordinator-gated alternative; stop-and-report is the default.

## Unresolved dissent

- MiniMax's inline-and-delete (point 1) and monolith-Target reachability (point 2) stand rejected on the re-read evidence above; if MiniMax maintains them, the disagreement is for the coordinator, not for further reviewer rounds.
- Case 2 harness-fault admissibility is a coordinator/owner reading of "a state the vault already supports" versus the DETF precedent; all four drafts otherwise agree the bound vault exposes no reverting preview state.

I did not run Forge.
