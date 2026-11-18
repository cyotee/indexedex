# Migration implementation audit - November 18, 2026

Status: the accepted Migration implementation scope is verified, including the
native lifecycle and mixed-record simulation. The repository-wide suite is not green: 1,249 pre-existing
ordinary V3 cases remain failing. This is not public-execution approval.

The governing plan is `../../MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`.
The owner's later instructions remove the
operator application, prohibit implicit sweeping, restrict explicit maintenance
to the current fee recipient, and move repeated reinvestment to the caller.

## Baseline

The full Solar build exited zero. The initial default-profile test run reported
27,626 passed and 1,250 failed. Its failures comprise the 1,249 previously
observed ordinary V3 cases and one weighted-LP recovery custody assertion.
The run also discovered fork tests through its compiled dependency graph;
it is not described as a purely hermetic result.

Current logs:

- `/tmp/indexedex-migration-audit-build.log`
- `/tmp/indexedex-migration-audit-hermetic.log`
- `/tmp/indexedex-migration-audit-script-red.log`
- `/tmp/indexedex-migration-audit-script-green.log`
- `/tmp/indexedex-migration-audit-weighted-lp-trace.log`
- `/tmp/indexedex-migration-audit-forks.log`

## Corrected findings and added evidence

- The operational Foundry stage lacked a current `InputsV3` pricing entry.
  The real-proxy regression failed before adding `setPricingV3` and passed
  afterward, proving full operand forwarding without repricing loaded credit.
- Two recovery assertions treated the parent self-token balance as immutable
  across a donation. The one-join workflow can legitimately refund self tokens.
  The revised witness reconciles the exact hook-to-parent refund, forbids
  spending earlier self-token custody, and still compares every other protected
  field with the original snapshot.
- The new observed 18/6 V3-pool witness compares actual SE shares/refunds,
  rated inflow, gross hook output and native9 user credit with canonical live
  previews. Its external liquidity is sized from funded native units, and its
  genesis anchor uses the smaller actual processed contribution.
- The nonempty legacy buffered-book witness preserves version-1 deposit
  operands, version-2 book identity and loaded credit across a current-book
  replacement.
- Address and package disable witnesses reject new capital while preserving
  mature Stage 1 principal, activated rewards, receipt-to-DETF exits, and every
  configured output in both SY burn modes. Direct receipt-to-underlying
  exchange is not an installed receipt route; underlying exits use the SY or
  parent routes.
- Native QA publication now has an explicit 31,900,000 transaction envelope;
  other native calls retain the 130-percent estimation margin. No node limit
  was raised.
- The native Stage B's two preflight negative claims advanced its simulated
  sender nonce under isolation. Snapshotting and restoring only those
  simulation-only probes preserves the real first broadcast nonce.
- The mixed-record scenario called the full test fixture from an ephemeral
  script contract. Forge rejected its use of `address(this)` as a fixture actor.
  The complete assertions now live in `MigrationMixedRecords.t.sol`, which
  exercises real registry-deployed proxies in the intended test context. The
  separate mined native lifecycle remains the broadcast evidence.
- Actual on-chain JSON/SVG was captured at creation, cliff-minus-one, exact
  unlock, after principal claim, and immediately before/after activation.
  All sixteen captured cards were rendered and inspected; no clipping or
  overlap was found. Cliff progress jumps from zero to full unlock, ordinary
  progress stays linear, and accrued versus claimable rewards remain distinct.

## Final results

| Gate | Observed result |
| --- | --- |
| Full Solar build | Exit 0 |
| Explicit hermetic gate | 27,570 passed; 1,249 failed; zero skipped, across 2,709 suites |
| Migration hermetic cases within that run | 274 passed; zero failed |
| Additional mixed-record lifecycle | Exit 0; one passed, zero failed/skipped; terminal activation reached; gas 9,278,916 |
| Complete pinned Migration forks | Exit 0; 184 passed; zero failed/skipped, across 31 suites |
| Native deployment/funding | 235 successful receipts; largest gas used 30,402,681; largest envelope 31,900,000 |
| Native principal/activation/reward lifecycle | 16 successful receipts; largest gas used 2,331,755 |
| Native administration cut | All 17 declared administration selectors were installed before activation and resolve to zero afterward |
| Native principal and reward transfers | Actual bond-to-wallet receipt transfers of 1,388,352,594 and 269,877,025 native sDETF units |
| Native explicit maintenance | Two separate successful caller transactions used 2,002,343 and 1,508,610 gas and added 77,318,293,536,970,222 and 1,113,592,255,254,979,558 reserve LP units |
| Metadata | Sixteen actual captured images inspected; five PNG comparison sheets retained |
| Diagnostics | No Solidity errors in checked edited files; no scoped whitespace errors |

The final hermetic command explicitly excludes fork paths/contracts. No failing
Migration test was skipped. The fork gate independently executes the full
Migration source directory. The remaining hermetic failure identities match the
previous ordinary V3 run; there are no newly failing identities.

The later rehearsal move changed only the QA script and added its standalone
test. A subsequent full Solar build exited zero, and that focused test passed.
The 274-case hermetic result and this additional passing case are separate runs,
not a claim that a 275-case combined run occurred. The build retains repository
warnings, including the existing unknown `fmt.skip` configuration key.

The 53 acceptance IDs, MIG-P01 through MIG-P15 and E1-E5 are mapped in
`coverage.md`. All fourteen source categories retain implementation and current
pinned witnesses. Earlier physical LP's admitted immutable-custody disposition
and other sources' conditional legacy authority remain as documented in the
source-route matrix; they are not promises that every asset can be liquidated
immediately.

## Remaining ordinary V3 failures

The 1,249 remaining failures are outside the Migration suites. Their error
classes are 925 `InvalidRoute`, 189 `FirstBondBelowMinimumLiquidity`, 84
`ZeroAmount`, 24 `MinAmountNotMet`, and 27 assertions expecting positive
donation previews.

Three unchanged representative tests were rerun with full traces:

- `UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18::test_DN10_previewEqualsExecute`:
  the underlying V3 preview returns zero shares and the complete 3,532,468
  native-unit input as refund; the donation test expects a positive quote.
- `UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P6_R9::test_H_OR_GV3_burn`:
  setup's bond conversion receives zero SE shares and all 100,000,000 input
  units back, then raises `InvalidRoute` before the burn is reached.
- `UniswapV4Detf_Quad_Univ3Se_Policy_B_P9_R18::test_D22_claimUngated`:
  first-bond preview receives zero shares/full refund for 100,000,000,000
  input units and raises `FirstBondBelowMinimumLiquidity`.

These traces establish a raw-input/fixture-domain mismatch with the current
V3 full-spread deposit behavior. The sizing rule in
`UniswapV3FullSpreadStandardExchangeVaultMath.sol:66-96` returns a complete
refund when it cannot consume the entire swap output while respecting the
remaining input budget. The positive ordinary-test expectations are not
fulfilled for these inputs. This audit preserves the owner's 49-percent swap
and input-only-refund policy; it does not silently change that separate SE
contract or alter test amounts to manufacture green results. The diagnostic
run is `/tmp/indexedex-migration-audit-ordinary-diagnosis.log`.

## Commands and provenance

The final gates used:

```sh
export PATH="$HOME/.foundry/bin:$PATH"
forge build --use solar
forge test --use solar --no-match-path '**/fork/**' --no-match-contract Fork -vv
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration \
  -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vv
```

Final logs are `/tmp/indexedex-migration-audit-final-build.log`,
`/tmp/indexedex-migration-audit-final-hermetic.log` and
`/tmp/indexedex-migration-audit-final-forks.log`. The subsequent rehearsal build
and test are `/tmp/indexedex-migration-audit-mixed-build.log` and
`/tmp/indexedex-migration-audit-mixed-records-green.log`; the failed script-context
attempt is `/tmp/indexedex-migration-audit-mixed-records.log`.
Native commands use the retained
`MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA`, isolated broadcast output,
`--use solar --broadcast --start-fresh --unlocked --isolate`,
the controlled dev sender, and `--gas-estimate-multiplier 130`.
`FOUNDRY_BLOCK_GAS_LIMIT=1000000000` supplies aggregate script-simulation
capacity; the actual node remains limited to 32,000,000.

`native-summary.json` contains current addresses, successful receipt counts,
actual payouts, per-sweep LP deltas and the full selector-removal readback.
`source-runtime-manifest.json` binds 70 current source files, 27 actual runtime
contracts, the dirty base revision and Solar version. Raw native transaction
creation inputs and receipts are retained under `native-broadcast/`.

Before the separate maintenance calls, the real local oracle owner used its
normal setter to choose the controlled dev account as current fee recipient.
That local setup transaction is preserved separately. No public oracle role
change, deployment, funding, activation, compensation or project commit occurred.
Operational datasets, selected live pricing and public authorization remain
separate from implementation verification.

The owned Anvil processes were stopped after terminal-state capture, and the
metadata inspection browser was disposed. Generated JSON evidence parses
successfully. JSON language-server diagnostics were unavailable because the
configured Biome executable is not installed; no dependency was installed for
this evidence-only check.

## Native attempt history

The owned Anvil is loopback port 18548, nonforked chain 31337, with the original
32,000,000 block gas limit and normal code-size enforcement. Initial node
inspection reported hardfork Bpo1 and block zero. Its terminal handle is
`bash_17`; that initial process was stopped before the successful fresh-node run.

The first attempts encountered Foundry's unfinished-broadcast recovery guard,
including its shared cache record. Broadcast output is now isolated under
`native-broadcast/`, and `--start-fresh` archived the earlier cache records
without deleting their evidence.

The first mined attempt failed at nonce 29:

- Hash: `0x7b1252b0b7bbd43f221d175b9d5c217e924b2949191381546b90d3687bc49ca7`.
- Receipt status: zero.
- Gas envelope: 2,151,991; gas used: 2,089,536.
- Call: `DiamondPackageCallBackFactory.deploy(address,bytes)` for the fee
  collector package.
- The call trace locates out-of-gas in the constructor's delegated factory
  initialization frame. This is a transaction-envelope failure, not proof
  that the deployment needs more than the 32-million ceiling.
- The generated plan also estimated a 34,203,016 envelope for the final
  Migration `deployVault`, which cannot be broadcast unchanged under that ceiling.

Replaying the initialization script against that partly initialized node with
`--isolate` hit an existing deterministic factory address. It is not a successful
rehearsal. The recorded prefix and failed receipt are preserved in this evidence
directory and the command logs.

An `anvil_reset` attempt then returned inconsistent fee guidance: the sender's
quoted fee was rejected as below the next block's base fee. No transaction was
accepted in that attempt. A fresh owned process restored consistent genesis
fees. The subsequent bounded Stage A and corrected-nonce Stage B are the
successful results above; earlier failures are not counted as successes.
