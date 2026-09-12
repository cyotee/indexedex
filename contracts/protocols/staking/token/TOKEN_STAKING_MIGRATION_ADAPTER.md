# Token staking migration adapter

`TokenStakingMigrationAdapter` is a standalone, immutable compatibility contract for the
historical staking migration ABI. The owner explicitly authorized constructor initialization
and ordinary `new` deployment, without a diamond, package or CREATE3.

```solidity
new TokenStakingMigrationAdapter(existingStaking, stakingToken, actualDetf, actualSDetf);
```

Constructor token arguments use `IERC20` for the staking token and actual DETF. It verifies
code presence, distinct addresses, staking-token binding, the DETF's claim-token binding,
the claim token's DETF backing and nine-decimal product units. It derives the existing
static wrapper from `actualDetf.stakingSY()` and verifies its code, nine decimals,
`yieldToken() == actualSDetf` and `assetInfo() == (TOKEN, actualDetf, 9)`.
`fundedStakingToken()` exposes real sDETF. The historical `rebasingClaimToken()` getter
intentionally exposes **static staking SY**, because legacy staking uses that getter to
choose its claim-vault asset. Deployment tooling must
independently verify the intended chain, addresses and deployed implementations. These
binding checks are not a code allowlist or an audit of arbitrary supplied contracts.

## Migration and withdrawal

The old staking contract treats its `targetDetf` as both an ERC20 and a legacy purchase
endpoint. Set that target to the adapter while staking remains in phase Staking. Continue
to identify the **actual DETF** as the protocol product in the registry, UI and reserve
chunk-sizing logic.

1. Native staking approves DTF to the adapter and invokes the historical six-argument
   `mint`. The adapter pulls and measures DTF, buys actual DETF through canonical Standard
   Exchange, and credits exactly the received DETF as nontransferable receipt units to staking.
2. Staking approves those units to the adapter itself and calls its seven-argument
   `exchangeIn`. The adapter consumes the complete approved batch and deposits its backing
   DETF into the existing staking SY through canonical `deposit`. SY internally acquires
   funded staking gons and issues static ownership units directly to staking.
3. Staking discovers static SY through `rebasingClaimToken()`, deploys its stored claim
   wrapper and deposits the received SY. Both adapter calls and wrapping occur inside the
   same native `migrateToClaimVault` transaction; any revert rolls back the entire chunk.
4. After all principal and rewards migrate, `withdrawClaim(stakeAmount)` on staking redeems
   the user's proportional wrapper shares directly to their wallet. It does not call the
   adapter. Partial exits are supported; the final staker receives all remaining vault shares.
5. The user redeems the received SY with
   `stakingSY.redeem(user, syAmount, actualSDetf, minimumSDetf, false)` to receive real sDETF.
   Redemption synchronizes funded rewards before valuing their static shares. The user needs
   no ERC20 approval for this direct owner redemption and can wait between claiming and
   redeeming without forfeiting ownership of subsequent funded growth.

Receipts and first-leg minimums use native DETF units. Second-leg outputs and native
`migrateToClaimVault` minimums use **SY units**, not sDETF units. All use nine decimals,
but SY and sDETF amounts are not interchangeable. Quote the entire native migration call
for accurate minimums because buying DETF can itself fund a rebase.

The adapter adds no fee. Canonical DETF pricing, fees, price gates and funding remain in
force. All nonzero operations require the pinned staking caller/recipient, supported tokens,
`pretransfer=false` and an unexpired deadline. Receipt approvals are limited to the adapter
and outstanding balance. Receipts cannot be transferred, partially consumed or overlapped.
Approvals to downstream contracts are exact and cleared after use. Both input and output
balance deltas are checked. Donations are neither credited nor swept; there is no rescue,
owner, upgrade, arbitrary calldata forwarding, Permit2 or external reward-token mechanism.

## Verification map

| Risk | Verification |
| --- | --- |
| Historical ABI differs from source | Fork uses original staking address and historical facet; adapter returns one mint uint256 and supports self-approval |
| Partial migration / lost rewards | Full original principal plus reward reserve, exact chunk debits, unchanged stake weights, final Wrapped phase |
| Unbacked receipts / replay | Exact DETF backing, full allowance consumption, zero settled supply, duplicate/partial batch rejection |
| Donation or pretransfer theft | Real production tokens, donated inventory retained, true pretransfer rejected, fuzzed donation/input amounts |
| Caller, recipient or route substitution | Exact custom-error tests for unauthorized callers, alternate recipients/tokens and third-party approvals |
| Minimum / deadline failures | Exact errors and atomic balance, approval, phase and receipt rollback |
| Stateful batch interleaving | Handler-driven mint, consume, donation and unauthorized-claim actions; backing and residual-authority invariants |
| Withdrawals | Historical package, original staking address, partial/full/final SY exits, redemption to real sDETF and subsequent canonical unstaking |
| Rebase timing | Settled versus pending-rebase claim/redemption equivalence, plus delayed SY redemption |

Diamond facet/package declarations are inapplicable to this explicitly approved monolith.
Permit signatures, public refunds and disable switches are absent. Reentrancy guards protect
both adapter money paths; all external callers other than the immutable staking address are
rejected. Arbitrary hostile dependency configurations and AMM economic manipulation remain
in the underlying products' test scope. The adapter supports the configured ordinary DTF;
it does not claim support for taxed or rebasing payment tokens and rejects transfer deltas
that differ from the requested amount.

Hermetic tests use registered production 60/20/20 composition components and the shared
`TestBase_FeeAccrualComposition`. Fork tests use the historical staking facet and claim
package with the already funded local DETF. Fork execution never broadcasts to the source
node. The fork RPC/block can be selected with `MIGRATION_ADAPTER_FORK_RPC` and
`MIGRATION_ADAPTER_FORK_BLOCK`; defaults refer to the recorded local rehearsal state.

```sh
forge build contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol
ETHERSCAN_API_KEY='' FOUNDRY_INVARIANT_RUNS=64 FOUNDRY_INVARIANT_DEPTH=32 FOUNDRY_INVARIANT_FAIL_ON_REVERT=true forge test --match-path 'test/foundry/spec/protocols/staking/token/TokenStakingMigrationAdapter.t.sol' --fuzz-runs 64 -vv
ETHERSCAN_API_KEY='' FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/robinhood_4663/TokenStakingMigrationAdapter_RobinhoodFork.t.sol' -vv
```

Persistent deployment and migration completion require their own confirmed receipts. Passing
an isolated fork test is not evidence that the running rehearsal node has migrated.

## Why the claim-vault asset is static SY

The owner approved the existing staking SY route on 2026-09-11 after fork testing exposed
underpayment in the historical claim wrapper when it directly held rebasing sDETF. The
wrapper calculates redemption before the asset transfer settles overdue rewards. In a
30-day regression, a 100-DTF holder received 251280508 raw sDETF versus 253445301 after
prior settlement. The difference stayed in the wrapper. A separate synchronization
transaction is insufficient if the user's withdrawal crosses another reward epoch.

Static SY fixes this boundary without changing the DETF, staking facet or stored claim-vault
package: a transfer can synchronize rewards, but cannot change the number of SY units held
by the wrapper or exiting user. The canonical SY redemption subsequently settles rewards
before converting those ownership units to actual sDETF. The existing local staking SY is
`0xce5b57f7c84825f789865719153684fC067fD6e7`; production construction derives it onchain.

The historical direct-sDETF experiment is recorded in
`.scratch/fee-accrual-migration/adapter/smoke-results.json`; those results predate this fix.
Updated verification belongs in `.scratch/fee-accrual-migration/adapter/verification.json`.

## Integration requirements

Launch scripts must track the adapter separately from actual DETF, real sDETF and staking
SY, validate all four bindings, and quote native migration minimums in SY. The UI must
identify the claim asset as staking SY, show its sDETF redemption value, and support both
native `withdrawClaim` and subsequent SY redemption. Reject zero-preview withdrawals:
microscopic legacy stake weights can round below one native SY unit.

The owner subsequently authorized persistent local execution. The adapter-aware stages
have now migrated the existing Anvil staking contract; the completion record below supersedes
the earlier test-only status. Frontend SY claim/redemption integration remains pending.

## Static SY verification — 2026-09-11

- Standalone build passed; deployed runtime is 6,396 bytes.
- Production-first adapter suite passed all 12 tests: 128 fuzz cases and 4,096 invariant
  calls, with zero unexpected reverts. Shared composition regression passed all three tests.
- Ordinary transactions on a disposable fork, with EIP-170 enabled, migrated the original
  223355050624580728299834717 raw DTF reserve in 60 native chunks. All deposits and rewards
  moved together, principal weights remained unchanged, and adapter residues/approvals
  cleared after every chunk.
- The 30-day pending-rebase claim plus SY redemption returned **253445300 raw sDETF**,
  exactly matching the independently pre-synchronized control. The original direct-sDETF
  wrapper lost 2164793 raw units in the corresponding timing comparison; static SY removes
  that timing-dependent loss. SY conversion still follows its canonical integer rounding.
- Partial/full/final claims, SY redemption and subsequent real sDETF unstaking passed on
  the historical package. Detailed transaction proof: `sy-smoke-results.json` beside the
  verification artifact. The disposable node was stopped afterward.

A second disposable transaction run also verified a 100-DTF depositor on the **original
staking address** after full-reserve migration. Partial and final claims returned 2,769 and
4,154 raw SY units. Their 6,923 static units remained unchanged during a 90-day wait;
redemption returned 7,190 raw sDETF with or without prior synchronization, versus 7,074
at claim time. Evidence: `sy-additional-results.json`.

The consolidated Foundry historical-fork suite passed **all seven tests**, including full
original-reserve migration, original-address user withdrawal, atomic minimum failure,
partial/full/final exits, settled and pending rebases, and delayed 90-day SY redemption.
Together with the 12 adapter tests and three composition regressions, **22 focused tests
passed**. No tests failed or skipped. Final hashes, logs and results are recorded in
`.scratch/fee-accrual-migration/adapter/verification.json`.

## Subsequent authorized local execution

Migration completed on the persistent port-8545 Anvil at block **60445063**. Adapter
`0x7F73efC0530DB6948a4535EbC77095897afCA1D0` was deployed and configured, then all deposits
and rewards migrated through **60 native staking calls**. Staking is Wrapped with zero
remaining DTF. Claim vault `0xca66c89624d89e1fa5619d9a4dda7f2be8e7bc10` holds existing
staking SY. All 62 setup/migration receipts, exact reserve/share totals and cleared adapter
balances/allowances were verified. See `.scratch/fee-accrual-staking-sy/MIGRATION_COMPLETE.md`
and its `deployments/migration-live-verification.json` for receipt-backed evidence.
