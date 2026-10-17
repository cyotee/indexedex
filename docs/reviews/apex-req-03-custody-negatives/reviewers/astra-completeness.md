# Astra — REQ-03 PRD completeness review

**Status:** Independent first pass; requirements review only. I re-read `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` in full and the relevant current test/scanner sections. No reviewer files were read. No source or coordinator PRD was edited.

## Conclusion

**No remaining question or unresolved implementation-blocking decision identified.** The current PRD now closes the observation-versus-rollback design and fixes the scanner inventory explicitly. No additional sentence is needed to close those choices.

This is a requirements-completeness conclusion, not a claim that the implementation has been completed or tested. Ordinary coding details do not require another product or acceptance decision.

## Decisions already closed

### REQ-03-R1 — observation and rollback are separate calls

PRD lines 28 and 30-35 specify all previously material choices:

- The locked subject and nested deposit are the same rebasing vault under test, not an underlying vault or another family.
- The observation callback records the attempted nested deposit and its rejection, returns without reverting, and lets the outer deposit finish.
- Assertions read the surviving record after that call and fail for a wrong error or nested success.
- A separate existing rollback test continues to expect `TransferFromFailed` and preserves its no-partial-credit assertions.

Current `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:28-32` still combines callback assertions with a deliberate revert; lines 128-146 contain the rollback test. The revised PRD unambiguously directs the implementer to separate those roles rather than choose among incompatible observation mechanisms. Callback/record identifiers are routine coding details, not missing owner decisions.

**Sentence to add:** None.

### REQ-03-R2 — one exact total-supply assertion

PRD lines 43-46 explicitly require successful total supply to equal captured supply plus requested shares, while preserving the existing rejection and success assertions and fuzz domain.

Current `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Fuzz.t.sol:65` already captures `supplyBefore`; lines 85-100 restore the prepared state and perform the successful call and existing checks. Neither the reference state nor the expected quantity remains an implementer policy choice. My earlier interpretation of the broader Stage-1 wording does not override this explicit requirement.

**Sentence to add:** None.

### REQ-03-R3 — the PRD supplies the selection inventory

PRD lines 54-71 provide the owner-selected directory list. Lines 73-77 require recursive selection without dependence on an APEX marker, retain the existing custody inclusions, prohibit adding or dropping directories, and keep bare-expectation rejection without rewriting those tests.

Current `scripts/apex_bare_expectrevert_scan.sh:14-26` already supplies the recursive-root selection mechanism alongside explicit custody inclusions and the existing marker-based selection. The bounded change is to add the listed roots, not to invent a family-to-file map or redesign unrelated selection behavior. The earlier inventory uncertainty is therefore closed by the current PRD, not delegated to the implementer.

The possibility that the expanded scanner reports existing violations is not an unanswered completion decision: PRD line 76 expressly requires rejection while excluding test rewrites from this item. A nonzero check result caused by correctly detected existing bare expectations must not be “fixed” by weakening selection or silently broadening this remediation.

**Sentence to add:** None.

## Scope boundary

Ownership, the production bytecode guard, and existing minimality rejection assertions remain explicitly closed/non-goals. No new product work, scanner file list, production change, or additional acceptance gate is proposed. Only this assigned Markdown report was written.

I did not run Forge.
