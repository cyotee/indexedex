Title: Handle pool-init path in previewClaimLiquidity + tests
ID: IDXEX-101
Status: Ready
Priority: Medium
Dependencies: IDXEX-064

Summary
- Add a branch to previewClaimLiquidity to handle poolTotalSupply == 0 to match the underwrite/init execution logic, and add tests for uninitialized pool previews.

Problem
- previewClaimLiquidity may assume the pool is initialized which can give misleading previews when poolTotalSupply == 0. The execution path handles pool init differently and must be mirrored by the preview to ensure callers get accurate estimates.

Goal
- Ensure previewClaimLiquidity returns the same value the execution path would produce when pool is uninitialized.

Acceptance Criteria
- previewClaimLiquidity correctly handles the pool-init scenario and unit tests cover the init-case.

Notes
- Depends on IDXEX-064 which fixed the balance source.
