# Kimi planning advisory: coordinator archival receipt

Verbatim final response from Native task `st_01a18424`, advisory epoch 1, on frozen r1.

---

# Identity

Kimi, independent Native council planning member, maintaining the original exact global route `kimi-coding/k3.1-pro:high`.

# Draft under review

Reviewed the complete frozen draft:

- Draft ID: `pairtoken-se-stage-one-plan-20261028-01a1810f-r1`
- Path: `/Users/cyotee/Projects/indexedex/docs/research/pairtoken-se-stage-one-plan-20261028-01a1810f/coordinator/draft.md`
- Coordinator-supplied raw-file SHA-256: `e586652849499d117b97c01882e66651777a3cbf3a50a5cd2750ea4c01660737`

The hash is supplied provenance, not my independent attestation. I read only this draft and used prior conversation context; I did not reopen the PRD, sources, peer contributions, or my archived original.

# Disposition

**SUPPORT WITH CORRECTIONS.**

The draft fairly represents the substance of my original contribution and provides an executable, dependency-ordered work order. It preserves the operation ledger, exact caller-attributed issuance, fee checkpoints, proportional and terminal exits, native/wrapped adaptation, memory-only V4 projector, real-manager fixtures, independent arithmetic controls, complete A01–A70 mapping, and artifact-first release discipline.

Two changes to my original are appropriate corrections rather than fidelity losses:

1. The draft correctly expands `MaintenanceWorkLimit` to exhaustion anywhere in the **complete normal withdrawal candidate**, including its final sale, rather than my narrower maintenance-only interpretation.
2. The draft correctly retains wide intermediate `Vraw` and narrows only the final public SY rate. My original narrowing of the converted basket value could have rejected a representable final rate merely because an intermediate exceeded 256 bits.

The 60-selector manifest is internally consistent: 20 reused selectors plus 19 family, four SE, 16 SY, and one callback selector. Every acceptance ID has a named primary case and substantive evidence requirement. The plan also correctly labels deployment-network and practical gas budgets as open release inputs rather than claiming feasibility from Foundry’s test configuration.

The corrections below concern source-dependent implementation details and validation precision, not the selected economics or overall architecture.

# Concerns

## 1. Verify the factory/adaptor lifecycle API before treating P4 as executable

Section 3.2 makes concrete assertions about:

- `DiamondFactoryPackageAdaptor` delegatecall contexts.
- Factory-context execution of `calcSalt` and `processArgs`.
- `pkgOfAccount(address(this))` and `pkgArgsOfAccount(address(this))` during proxy initialization.

These APIs and call contexts cannot be verified from the draft alone. They are plausible implementation details, but the initialization design depends on them. Make confirmation of their exact signatures, return values, and caller context an explicit P0/P1 prerequisite. If `pkgArgsOfAccount` or the assumed context is unavailable, the implementation must use the actual factory authentication mechanism rather than weakening package/argument identity checks.

Similarly, the statement that `Behavior_IDiamondFactoryPackage.sol` was absent is unverifiable in this pass. Avoiding a fictional import is correct; the family-local package Behavior is an acceptable substitute provided it covers the complete declaration and lifecycle surface.

## 2. Confirm the exact artifact-helper command forms

Section 8 shows multiple production sources in one invocation:

```bash
python3 scripts/forge-artifacts.py plan "$P/${F}Math.sol" "$P/${F}Planner.sol" --test-root "$T"
python3 scripts/forge-artifacts.py test "$P/${F}Math.sol" "$P/${F}Planner.sol" --test-root "$T" -- -vv
```

The admitted workflow I previously saw documented a singular `<edited-source.sol>` argument. The draft may reflect a more complete inspection of the script, but that cannot be established here. Before using these commands as release evidence, confirm the script’s actual positional-argument cardinality and `--` forwarding behavior. If it accepts only one edited source, run it once per changed source with the relevant test roots. Do not let a command-form error bypass the artifact-first requirement.

The following are also source claims not independently verified in this advisory:

- `forge build "$P" --sizes` as the intended focused size command.
- `scripts/size_oversize_facets.py` exiting zero despite oversize findings.
- Solc 0.8.35, optimizer runs 1, and `via_ir false` as the observed current configuration.

These claims should be checked against the current repository when implementation begins; none changes the plan’s economics.

## 3. Restore an explicit canonical NatSpec/selector verification gate

The typed manifest and prohibition on handwritten hashes are good, but Section 8 omits the committed canonical NatSpec/selector verification step from its command/evidence list. Add that verification to P7 using the repository’s actual committed workflow and centrally verified values. This should cover new family methods, errors, events, interface IDs, and composed proxy declarations. The exact script path should be confirmed rather than invented in this advisory.

## 4. Keep the two economic refinements intact during conflict resolution

These are not defects, but they are important enough to preserve explicitly:

- Do not revert Section 5.4 to a maintenance-stage-only work-limit interpretation. Section 7.3 correctly requires both partially consumed maintenance budgets and final-sale exhaustion cases.
- Do not simplify Section 6.3 back to 256-bit `Vraw`. Its wide post-conversion value and final-only narrowing are necessary for the specified mathematical result. The proposed restoring division is auditable as an initial implementation, and the required wide-intermediate/final-overflow controls are correctly identified.

No other substantive economic, ledger, projector, acceptance-coverage, or release-limit defect was found in the frozen draft.

# What was not adopted from others

I did not read the other members’ originals in this pass, so I cannot independently assess their complete sets of rejected or omitted recommendations. The draft’s statements about Astra, MiniMax, and the partially available Grok contribution are coordinator-provided provenance, not independently verified comparisons.

Relative to my own original:

- No material architectural or testing requirement was omitted.
- The more granular facet decomposition is an acceptable replacement for my initial four-family-facet starting point and retains the same selector closure.
- The whole-candidate WorkLimit interpretation properly supersedes my narrower wording.
- The wide-intermediate SY valuation properly supersedes my earlier final-value narrowing.
- The explicit avoidance of non-limiting-leg quotient overflow in `qCredit` is a useful strengthening of the issuance work order.
- The guard-first SY preview wrappers and unconditional exact-output error precedence are clearly stated interpretations that should remain pinned by the proposed busy-context tests.

The draft’s rejection of an alleged baseline principal-sign defect does not conflict with my original. Its formula `principalDelta = callerDelta - feesAccrued` is consistent with the baseline behavior previously inspected.

# Limits

This was one draft-only advisory pass. I did not independently verify the supplied draft hash, current factory/adaptor APIs, script interfaces, compiler settings, source-file absence claims, or any implementation behavior. No research, additional file reads, commands, tests, builds, writes, or delegation were performed.

This advisory supports the frozen draft with the corrections above; it does not replace my original contribution, certify implementation feasibility, or authorize implementation or deployment. No further review round is requested.
