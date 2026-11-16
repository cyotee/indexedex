# D1: never-staked Migration activation

The independent final-source artifact-first spec run reproduced
`MissingRewardWeight()` in
`MigrationCoreTest.test_activationRemovesEntireAdministrationAndKeepsQueries`.
The suite remains 102 passed, 1 failed, 0 skipped. The failing assertion was
not edited or disabled. No clean-base reproduction was performed; this is not
labeled a proven pre-existing defect.

## Source and law

- `DETF_ALIGNMENT_PRD.md:960-975` fixes standing fee/creator recipients,
  weight-based allocation, floor rounding, and funded receipt settlement.
  Zero ordinary stake does not authorize blocking distribution, a fixed
  percentage replacement, or a no-recipient carry-forward bucket.
- `DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md:200-229`
  explicitly defines ordinary weight as actual funded gons, O = Q, and
  preserves top-up-only standing weights. Its ordinary purchase ordering
  at lines 262-270 funds principal before allocating the reward.
- `common/claimToken/DETFFundedStakingRepo.sol:52-64` initializes addresses
  and the index, but no principal or standing weights. Lines 165-174 feed
  totalGons into the preserved top-up formula.
- `common/core/DETFSeigniorageShareLib.sol:24-26` returns zero deltas when
  ordinary effective weight is zero.
- `migration/UniswapV4DetfMigrationAllocationTarget.sol:227-310` joins the
  self-leg into the reserve and sets liveness without staking principal.
- `migration/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol:103-125`
  funds actual rewards and calls the inherited ledger distribution.
  `common/core/DETFFundedStakingMath.sol:79-88` rejects a positive reward
  when all three reward weights are zero.

Paths above are relative to `contracts/vaults/detf/`; the two law files
are directly beneath that directory.

## Bounded conclusion

The standing beneficiaries and settlement policy are settled. The inspected
composition provides no positive initial weight basis for the distinct
never-staked, donation-only Migration bootstrap. The existing zero-balance
case with retained positive standing weights is not this all-zero genesis.

Inference: selecting the reserve self-leg, first reward, or an arbitrary
normalization as a persistent genesis basis would add a numerical economic
choice not selected by the inspected O = Q contract. Absolute standing
weights affect later top-up dominance and fixed-point floors, even if an
initial ratio is similar. No seed is selected or implemented here. Neither
independent compensation nor fictitious principal is made a condition of
activation. Root's owner question remains pending.

D1 blocks unconditional ordinary-deposit acceptance; it does not erase the
separately passing Stage2 NFT/W-L custody and surrender checks.
