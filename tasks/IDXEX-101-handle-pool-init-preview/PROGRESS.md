Last checkpoint: Not started

Next step: Implement poolTotalSupply == 0 branch in previewClaimLiquidity and add unit tests for uninitialized pool preview.

Implementation notes:
- Reuse test fixtures from Seigniorage tests to create an uninitialized pool and assert preview==execution.
