# Gas and size status

Effective local toolchain/configuration is captured in BASELINE.md and baseline-foundry.json. Production edits contain only internal library functions; they expose no deployed vault, facet, callback or money route. Library placeholder runtime sizes would not establish a product runtime-size gate.

Any per-test gas printed by Forge is harness gas, not an outer production transaction receipt. No product gas number, target-chain cap, RPC quote budget, rebalance budget, eight-leg compatibility or release margin is claimed. Those measurements remain pending the executable valuation/deployment/consumer paths and Gate C platform decisions. No gas cap or compiler setting was changed.

## First deployed scalar/SY checkpoint

`surfaces-tests-result.json` records compiled runtime sizes: package 8,018 bytes,
query facet 12,088, entry facet 2,211, exit facet 3,516, callback 3,909, native SY
5,344 and money library 21,585. These are below 24,576 bytes at that checkpoint;
subsequent changes require fresh measurement.

Early quote probe (`surfaces-tests.log`): three owned slots with no external depth
required 58 bitmap/swap steps. The first fixture-state quote used 651,248 gas;
a repeated warm quote used 543,786. These are isolated subcall measurements,
not outer transaction receipts or proofs of maximum-work/eight-leg acceptance.
Repeated full traversals are material: sequential consumer projection must reuse
unchanged opposing-sale value where exact, and maximum admitted work still needs
outer-transaction acceptance. No compiler, gas cap or harness limit changed.

## Family suite after the SEC-08 correction

`UniswapV4UpperLowerWingsStandardExchangeVaultArtifactSizes.t.sol` passed in
`family-suite-after-sec08.log`. That test rejects deployed family bytecode above
24,576 bytes. It does not record each component's exact size in this note.

Weighted join subcall gas, not an outer receipt: arities 3 through 7 reported
1,591,921; 1,683,503; 2,355,822; 2,447,327; and 3,131,263. Homogeneous eight-leg
joins reported 5,569,426 and 5,569,470.

`UniswapV4UpperLowerWingsStandardExchangeVaultOuterGas.t.sol` passed in
`family-suite-complete.log`. Estimated outer gas is measured call gas plus 21,000,
16 per calldata byte, and a cold-account allowance. Deposit 604,041; quote 98,997;
partial redeem 397,473; rebalance 2,590,106. The acceptance ceiling used is
15,099,494, 90% of the EIP-7825 cap 16,777,216. No target-chain activation block
was queried, so this is not a live receipt. The eight-leg subcall is also under
that ceiling and is still not an outer receipt.
