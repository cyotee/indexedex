# Verification matrix

Latest local checkpoint: **136 passed / one failed / zero skipped, 137 tests in 18 suites**, using current production sources and gold factory fixtures. Evidence: [unfiltered regression log](evidence/focused-harness-unfiltered.log). Test presence and this bounded selection do not establish full protocol coverage.

| Area | Verification | Latest result |
|------|--------------|---------------|
| Universal close lifecycle | CP, Orbital, Weighted and Quad D25; unrelated/former-holder rejection and current-holder recipient choice | All 36 passed across five suites |
| CP canonical initialization | Invalid spacing, recovery, finalization, registration and bounded spacing fuzz | All 34 passed |
| CP public swap lock | Four real PoolManager input/output transfer callback regressions | All four passed |
| CP incoming capital and growth fees | No-growth intakes, real growth, SE-share parity, exact-output bounds | Nine passed; raw/pair exact-preview minimum still fails |
| CP zap reserve reconstruction | Both input directions and both currency orders; raw18/pair6, unequal reserves | All four passed after correcting invalid fixture decimals |
| Shared claim exact-output units | Non-unit rates, minimal input and actual DETF payout/configuration | All six passed |
| Shared claim accounting | Same-block backing, internal precision, zero issuance, zero backing and atomic rollback | All seven passed |
| Universal original principal | Bond, purchase, compound, minimum output and close across four bindings; five CP tiny-principal cases | All 25 passed |
| Shared NFT original-principal rounding | Downward issuance and configured decimal-offset cases | All five passed |
| Universal facet packaging | Selector coverage, factory routing and deployment sizes | All four passed |
| Universal NFT dispatcher | Approval and guarded transfer routes | Both passed |
| Selected production artifact freshness and size | Fourteen artifacts, 212 dependency-source hashes; runtime/base creation limits | All pass; artifact-freshness-latest.json and production-sizes-latest.json. Base creation sizes exclude constructor arguments |
| Launch script compatibility | Seven affected roots ABI-checked; fee-DETF package script bytecode generation | Pass; scripts were not executed or broadcast |
| Broader CP and universal lifecycle, decimal, Permit2 and adversarial matrix | Existing production-path suites beyond the focused selection | Broader rerun remains pending |
| Other shared-claim integrations and economic invariants | Other DETF families, independent invariant evidence | Incomplete; no full coverage claim |
| Fee Collector and deployed manager | Read-only chain ID, proxy presence, feeTo and collector owner | feeTo matches recorded collector at block 0x34c6dc1. Implementation identity and downstream accrual remain unreconciled |
| Gas and compilation/test efficiency | Matching-root build and unfiltered focused workflow | Six-source build: 144.98s wall. Warm test: compilation skipped, 484.08s wall. No controlled speedup or gas benchmark established |

The remaining raw/pair quote failure is preserved, not skipped or weakened. Exact generic post-transition quoting, universal claim-purchase balance previews, initial ownership of pre-existing unclaimed backing, wider invariants and deployed-source reconciliation remain open. See [the proposed quote design](PREVIEW_REMEDIATION_DESIGN.md) and the working report. No production-readiness conclusion is justified.
