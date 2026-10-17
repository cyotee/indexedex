# Astra — rewritten legacy V4 design: owner-question pass

**Ready for implementation planning. No owner question remains on the product decisions in this document.** I read `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md` in full. No other reviewers' notes were read. This response is not an implementation plan or authorization to implement.

## Decisions already closed

- **Architecture and ownership:** Lines 19-33 name the six internal libraries, callback target/facet, and shared error declaration. Lines 37-63 fix selector owners and package-cut order. The previous alternatives are not choices for the implementer.
- **Execution reuse:** Lines 67-80 require internal operations, removal of both delegates and their wiring, and no self-call reuse. The callback facet is the sole selected protocol-callback owner.
- **Custody baseline:** Lines 17 and 113 expressly preserve the current stored-reserve pretransfer calculation and prohibit a new local-credit slot or repair of that residual here. My earlier alternative is not adopted; no question should ask the owner to select it again.
- **Policy corrections:** Lines 71-72 and D6/D8 select the SY disable check and propagation of unexpected rebalance failures, while retaining bounded no-op/partial adjustment.
- **Compatibility and scope:** Lines 86 and 102 keep `NativeStandardYieldTarget.sol` and restrict other-family changes to the specified mechanical import migration. Lines 106 and 115 select fresh instances without migration or storage-compatibility claims.
- **Size disposition:** Line 92 fixes the hard and advisory thresholds and the stop/report response. Line 94 explicitly treats the old size figure as unverified. No owner decision is needed before a measurement exists.

## Mechanical closures the later plan must state

These are steps for specifying execution of the selected design, not unresolved product questions:

1. **Literal source mapping:** Assign the existing functions to the six already-named libraries and retained thin targets, following their recorded responsibilities. Specify the dependency order and how callers are updated before the old bases/delegates are deleted. Do not offer alternative libraries, partitions, or replacement delegate mechanisms.
2. **Exact ABI inventory:** Expand the twelve existing SY query/discovery selectors and seven reserve selectors referenced at lines 59-60 into their exact existing interface members, and preserve the other rows and cut order verbatim. Update declarations, package wiring, FactoryService, and the production TestBase together. Enumeration is source verification, not permission to move selectors.
3. **Lifecycle placement:** Keep ordinary deposit/redemption orchestration and blocked-sleeve behavior outside callback-only manager settlement. The PoolOps responsibility at line 26 must not be interpreted as forcing every deposit to open an unlock: line 11 preserves the supported funded-sleeve behavior. Preserve caller validation on the dedicated callback and the existing operation decoding.
4. **Behavior-preserving transfers:** Preserve holder arguments, quote rounding, supported routes, events/errors, ordinary guards, TWAP behavior, and the explicitly retained pretransfer calculation. Add the selected SY disable check; do not quietly broaden this redesign into the excluded residual correction.
5. **Deletion boundaries:** Name the exact functions/files/wiring from lines 77-84. Keep import decrease/collect, shared repo fields, and the compatibility aggregate. Implement the source-search contingency at lines 83 and 88 literally: report an existing consumer and do not delete that component contrary to the stated condition.
6. **Shared declarations:** State the mechanical import/error-declaration edits that preserve existing signatures and other-family behavior, without deleting the compatibility aggregate or restructuring V3, hookless, or Pons.
7. **Verification and stop conditions:** Name affected artifact refreshes, deployed-runtime measurements, production-proxy regression suites, and recorded command/results requirements using repository rules. Measure the selected design; do not treat a hard-limit failure as permission to choose another architecture. A build, test, or consumer-inventory obstruction must be reported rather than hidden by scope expansion.

## Questions

**Blocking owner questions: None.**

**Non-blocking owner questions: None.**

The rewritten document resolves the previously assumed decisions and explicitly rejects the competing architecture and accounting alternatives. Remaining work is to map and sequence the specified design against source, not to obtain another economic or scope ruling. This readiness statement does not certify compilation, runtime size, or test results. Only this assigned questions report was written; no PRD, plan, or code was edited.

I did not run Forge.
