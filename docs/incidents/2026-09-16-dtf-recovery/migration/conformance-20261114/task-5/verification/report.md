# Independent task 5 verification

Verdict: **confirmed**. Failure class: **none**. Confidence: **high** for the task 5 offline schema, preparation, and loader-selection boundary.

The producer's `task-5-done.json` was treated as an untrusted claim. The verifier inspected plan task 5, the five TypeScript diffs, the named assertions, preparation/provenance/quote/loader callers, raw producer logs, and an independent execution of the exact permitted command:

```sh
bun test --timeout 15000 ./scripts/recovery/dtf-migration/nft-contributions.test.ts ./scripts/recovery/dtf-migration/preparation.test.ts
```

Independent evidence: `rerun.log` beside this report. Bun 1.4.2 reported 56 pass, 0 fail, 1.65 seconds, `TEST_EXIT_CODE=0`; the monitor independently exited 0. No fixes, delegation, Forge, installs, commits, external RPC, signing, or public transactions were performed. The permitted suites use synthetic loopback wire fixtures.

## Mechanism and acceptance checks

1. `scripts/recovery/dtf-migration/schema.ts:50-55` restricts only the specified chain, collection, and token identity to explicit separate mode and the two exact originals. The preparation-input refinement applies that restriction to every NFT row. Address and integer normalization precede comparison. False and string `"combined"` are also rejected by the existing literal-true-or-absent field schema.
2. `payloads.ts:115-119` repeats the identity-specific check at the payload boundary. `preparation.ts:35-43` normalizes and validates provenance, then builds payloads, then quotes. Therefore a malformed target row cannot reach quote transport. The CLI cases assert exit 1, empty stdout, controlled INPUT/PROVENANCE errors, no transport methods, and ENOENT for the prepared directory. The printed zero transaction count is corroborated by those assertions and the inspected preparation path; it is not accepted as proof by itself.
3. `schema.ts:49` requires explicit proof. `provenance.ts:41-65` fingerprints the referenced bytes and compares the complete original tuple, including mode and wallet, to its source pointer before quotes. The named missing-proof, mismatched-proof, and wrong-wallet assertions passed. This establishes proof binding for the local fixtures; it does not establish historical allocation authority.
4. `payloads.ts:55-58` constructs ETH-only then DTF-only originals. `preparation.ts:43-59` takes credits from independently returned quotes and sums them. The original amounts are input originals, not quote credits. The happy assertion checks both exact contribution rows and the absence of a merged quote; it decodes the generated loader transaction.
5. `execution-plan.ts:59-63` selects the separate loader from the prepared mode. The positive control is an earlier-collection NFT with combined originals, for which the real planner emits `configureNftEntitlements`. The identity-specific guard leaves other configured NFT identities' existing options intact; the existing generic two-leg requirement for separate mode remains.

## Manual QA: PASS

The following fields are quoted from the complete JSON line in the independent `rerun.log`, parsed without tool-display line clipping:

```json
{
  "loader": "configureNftContributionEntitlements",
  "separateContributions": true,
  "decodedOriginalEth": "999999000000000",
  "decodedOriginalDtf": "362893857600000000000",
  "contributions": [
    {
      "originalEth": "999999000000000",
      "originalDtf": "0",
      "credit": "99999900000000"
    },
    {
      "originalEth": "0",
      "originalDtf": "362893857600000000000",
      "credit": "32990350690909090909"
    }
  ],
  "quotedCredit": "32990450690809090909",
  "combinedControl": "configureNftEntitlements"
}
```

There are exactly two nonzero original components, ETH then DTF, and no merged original component. The loader input contains the full pair so the separate loader can split it; that is not a combined-loader selection.

## Scope and dirty worktree

The task-owned diff consists of `schema.ts`, `payloads.ts`, `nft-contributions.test.ts`, `preparation.test.ts`, and `preparation.fixture.ts`. Its production edits add the input guards and move/re-export the collection constant. No task 5 production Solidity edit was found.

The observed Solidity diffs concern the concurrent manual pricing migration: expected-book parameters, pricing library/interface replacements, facet/target replacement, and stable original identity. In the inspected NFT allocation diff, contribution order and the one/two contribution branches remain; pricing calls change library. The legacy NFT library diff removes the pricing-book operand from original identity, without changing eligibility. These concurrent changes are outside this verdict and were preserved. No current Solidity compilation or current-source ABI compatibility claim is made: the permitted tests use warm ABI artifacts while the pricing worker changes the live source API.

Before verification, the verifier fingerprinted 4,112 existing files across task 1, task 2, task 3, and task 5 evidence. The subsequent comparison found no changed or missing file among those fingerprints. A second worktree status snapshot also retained every initially dirty/untracked path; concurrent workers added further Solidity changes. The targeted policy/NFT-target diff was empty, and the scoped five-file TypeScript `git diff --check` exited 0. Producer `happy.log`, `rejection.log`, and `generated-payload.json` were read but not overwritten. The verifier writes only beneath task-5/verification and the required verdict path.

## Adversarial classes

| Class | Observable result or applicability |
| --- | --- |
| malformed_input | PASS: absent, false, string combined, missing ETH, missing DTF, zero ETH, zero DTF, altered ETH, and altered DTF all rejected. Each CLI row recorded INPUT, zero transport requests, no prepared directory, and exit 1; named assertions were inspected. Missing/mismatched source proof also rejected before transport. |
| stale_state | PASS: the old combined NFT 3 fixture with originals 100/22 rejected with INPUT, zero transport requests, and no prepared directory. |
| dirty_worktree | PASS: all 4,112 fingerprinted task 1-3 and producer task 5 evidence files remained byte-identical. Concurrent Solidity changes were observed and preserved, without reverting, formatting, or compiling them. |
| misleading_success_output | PASS: inspected the named assertions, decoded loader fields, every rejection row, final 56/0 summary, TEST_EXIT_CODE=0, and monitor exit 0. The success header and producer completion status were not used as confirmation. |
| generated_or_cached_artifacts | Applicable limitation: the suite reads warm ABI artifacts to encode/decode transactions, not a cached prepared payload as its result. The accepted payload was generated in the independent run. No attestation that warm ABI artifacts match concurrent Solidity source is made or needed for this scoped input-boundary verdict. |
| hung_or_long_commands | Not applicable: the authorized test timeout remained 15000 and the run finished in 1.65 seconds. |
| flaky_tests | Not applicable: one deterministic test run was observed; no retry-based success claim. |
| untrusted_external_text | Not applicable: local fixtures only. |
| cancel_resume | Not applicable: no cancellation or resume scenario. |
| repeated_interruptions | Not applicable: no repeated interruption scenario. |

## Reproduction and limits

From the specified worktree, run the exact command above. For the positive result inspect `separate NFT preparation retains two quotes and encodes the two-bond loader` and its emitted task5Payload. For failure results inspect each `weighted NFT three rejects ... before transport and transaction creation` row plus the explicit matching-source-proof assertion. Removing the mode, either component, or changing either agreed amount must produce no prepared directory or loader plan.

The task 5 schema/preparation claim is confirmed. Actual on-chain two-bond issuance, current pricing-worker implementation, historical proof authority, wider suites, and current-source compilation are not asserted. The full Solidity diff is not a task ownership ledger; attribution here is based on the inspected changes and the explicitly concurrent pricing work described in the assignment.
