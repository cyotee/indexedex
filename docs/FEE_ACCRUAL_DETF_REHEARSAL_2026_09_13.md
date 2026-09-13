# Fee-accrual DETF staking migration rehearsal — 2026-09-13

Completed on local Anvil at http://127.0.0.1:8545, chain 4663. The latest-at-start
Robinhood block was **62,009,735**, hash
`0xbc4fc4df7e0eaa484c6060120503889ba1e01cc7fa83f7f57f388012aee77c47`.
The verified completed local block is **62,009,895**. No public transactions were sent.

## Confirmed outcome

- Original staking principal: **163,254,779.774397210420151710 DTF**.
- Remaining reward reserve: **1,871,918.739133821201130131 DTF**.
- Total converted together: **165,126,698.513531031621281841 DTF**.
- **59 successful native `migrateToClaimVault` transactions**; phase **Wrapped**;
  remaining staking-held DTF **zero**; original principal weights unchanged.
- Claim vault backing: **14.892973140 static staking SY**, reconciled exactly with
  migration events. The legacy staking contract holds **148929731400000000000**
  raw claim-vault shares. These SY units are redeemable for real sDETF; they are
  not interchangeable with the original DTF allocation units.
- Adapter receipts/balances are zero and all required allowances are cleared.
- Reused the existing CREATE3, diamond/hook factories, manager, collector and staking.
- The run confirms 72 package transactions, 86 composition/migration transactions,
  and one bootstrap-funding transaction. One earlier child-deployment transaction
  reverted for insufficient gas; it changed no staking funds or deployed contracts.

## Addresses

| Role | Address |
|---|---|
| Existing staking | `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00` |
| DTF-DETF | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` |
| sDTF-DETF | `0x4fa4974a8a09660258b8edd430b51c1620ebfe5c` |
| Static staking SY | `0xb55604cf4dcdabb362078e106d20f98512391edf` |
| Migration adapter | `0xaD830875D9e3E4A33f95d4Cb373cf198da0c8fe6` |
| Historical staking claim vault | `0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0` |
| Fee-free custody wrapper, 28 decimals | `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` |

## Configuration and bootstrap

The reserve weights are **60% DETF / 20% WETH / 20% DTF**, opening benchmarks are
**100× creation**, and the annual expansion closure rate is **10%**. The registered
custody vault is the reviewed fee-free SY/SE rebasing-aware ERC4626 with +10 offset.

The owner's approved funding transaction acquired 363 DTF and wrapped 0.001 ETH,
using a maximum native input of 0.0021 ETH and refunding unused ETH. The liquidity
seed consumed 0.000000001 WETH and 0.000701384425260685 DTF. The first bond consumed
**0.000999999 WETH and 362.893857600000000000 DTF**. No staking-held tokens funded
bootstrap.

After migration the settled synthetic prices were approximately **15.9056953274×
for WETH** and **7,244,775.80495× for DTF**, against a 1.05× mint threshold. These are
per-leg benchmark ratios, not USD prices or a forecast of future returns.

## Deployment issues resolved

1. The public RPC stopped serving a required historical storage read. The exact
   Anvil snapshot was restored against the configured Alchemy archive upstream.
   All 84 then-existing receipts, saved account balances/nonces/code/storage, and
   the latest local block were compared and preserved. Recovery and script changes
   use new reconciliation directories, retaining predecessor journals.
2. Atomic DETF plus child deployment used 34,049,995 gas. Robinhood's ArbGasInfo
   at the fork block reports a 32,000,000 execution-gas limit. The shared stage now
   deploys the deterministic registered bond NFT child first; the unchanged parent
   reuses it and initializes its reserved NFTs, sDETF and both SYs normally.
   Confirmed gas: **4,991,479 child / 29,289,533 parent**.
3. The stage uses a 100% parent estimate multiplier and an explicit 8,000,000 child
   gas budget. Final Forge transaction limits were 8,000,000 and 31,120,128.
   Simulation, EIP-170 and the 32-million execution limit remained enabled.
   No DETF or wrapper production bytecode change was needed for this repair.

The gas-accounting return is saved in `robinhood-gas-limits.json`; the precompile's
field implementation is in [OffchainLabs Nitro](https://github.com/OffchainLabs/nitro/blob/master/precompiles/ArbGasInfo.go).

## Validation

- The script change passed **16 composition/adapter tests**, including predeployed
  child reuse and adapter fuzz/invariant tests, plus **11 receipt-checker tests**.
  The earlier full 31,534-test hermetic gate was not repeated for this script-only fix.
- All five custody-wrapper facet runtimes and all four expansion-bearing DETF facet
  runtimes match the reviewed artifacts byte-for-byte.
- On a disposable fork, a real historical holder completed partial and full native
  claims, immediate SY redemption and redemption after 90 days. Pending expansion
  after that delay was **0.562008240 DETF**; delayed SY redemption retained funded
  growth and settled the pending expansion. All four user transactions succeeded.
- The persistent node metadata was identical before and after those disposable
  tests. No user claims were consumed on the review node.

## Evidence and scope

Run root: `.scratch/fee-accrual-rehearsal/20260913/`.

- `budget-composition/fee-accrual-journal.json`: final confirmed composition/migration journal.
- `budget-composition/migration-live-verification.json`: independent receipt, balance,
  allowance and runtime reconciliation.
- `packages/` and `archive-packages/`: original package records and archive recovery.
- `broadcast/`: Forge transaction records; recovery preserves earlier receipts separately.
- `claim-checks.json`: disposable user-transaction receipts and assertions.
- `after-migration-economics.json`, `bootstrap-dtf-inputs.json`: measured prices and token debits.
- `completed-anvil-state.json`, `completed-node.json`: recoverable completed state.
- `archive-recovery.json`, `staged-script-reconciliation.json`,
  `budget-script-reconciliation.json`: explicit state/source reconciliation.
- `staged-script-tests-final.log`: focused post-fix test results.

The frontend candidate is exported at
`budget-composition/phase09_stage02_fee_accrual_frontend_candidate.json`; its
`receiptVerified=false` flag correctly identifies Forge simulation output. The
independent verification above certifies the corresponding live deployment.
The checked-in frontend address bundle was not replaced by this rehearsal.
Public deployment remains subject to the owner's later agreement.
