# Phase04 core correction: F1 and V1

Date: 2026-11-10. Producer disposition: **F1 corrected; V1 executable proof
gap closed; ready for independent verification.** No independent acceptance
is asserted by this producer report.

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
Existing base: `6e27ecaa242c4acca132e3575a160514aad07b11`.
No commit, delegation, dependency/configuration edit, public action, or
historical-evidence edit was performed. Current-owner genesis, contribution
permissionlessness, frozen pricing and all prior policy remain unchanged.
The original full-plan gates, including E1/E2, remain open.

## 1. Exact change and source binding

Repository-relative aliases:

- M: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- D: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- TM: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- Evidence paths below are relative to this report's directory.

| Authored source | Change |
| --- | --- |
| `M/UniswapV4DetfMigrationAllocationTarget.sol:26-34,181-186` | Inherit the ordinary internal target to call its real `_firstBondOtherPayment`; explicitly retain the five existing Migration policy dispatches. Reject a non-anchor whose pre-conversion equivalent is below the canonical payment for the actual generated self amount. Reuse `InvalidGenesisLeg`; no interface change. |
| `M/TestBase_UniswapV4DetfMigration.sol` | Make `_seedMigrationPool` virtual for legitimate decimal-aware external pool seeding. Its default body is unchanged. |
| `TM/MigrationGenesisCapital.t.sol` | Nine actual registry-proxy F1 tests and shared observable capital-state snapshots. |
| `TM/MigrationPermit2.t.sol` | Fifteen actual proxy/canonical Permit2 tests. |
| `TM/MigrationPermit2Callback.sol` | Controllable external ERC20 only, propagating a real forbidden token callback. |

The canonical helper is `D/UniswapV4DetfTarget.sol:854-859`: opening price
with creation-price fallback, `Math.mulDiv(detf,opening,1e9)`, followed by
the canonical native-decimal conversion. This helper is called directly,
not copied or reconstructed in production. The anchor remains sized by
`_openingBondQuote`; all equivalent previews precede conversion, and the
existing `_convertGenesis` still checks actual consumption against preview.
The new comparison is strictly `<`: equality and adequate excess remain
valid. A later-leg rejection reverts earlier conversion and approval effects.

Final allocation-target SHA-256:
`4f56ac1d008cee074b9f6a2660b41c30f894d4645f890fe743e1c8f73e1b563e`.

`runtime/correction-sources.json` binds all five authored source files.
`runtime/current-artifact-source-binding.json` binds **932 unique artifact
files and 2,482 current source files**, checking every metadata source
Keccak against the actual file, artifact SHA-256, Solar compiler identity
and absence of viaIR. Mismatches: **zero**.
`runtime/final-preservation-check.json` confirms these artifacts did not
drift after script and trace execution.

Only the allocation target and TestBase differ among the 45 previously
reviewed source paths: `runtime/reviewed-source-deltas.json`.
All 101 fingerprinted historical reports, witnesses, logs and receipt files
remain unchanged. In particular, the independent `verification/report.md`,
`verification/GenesisWitness.s.sol`, and its original counterexample log
remain intact. No historical witness was rewritten to turn green.

## 2. F1: genuine red, then passing boundaries

Before any production edit, the new actual-proxy
`test_F1_historicalUnderfundingRejectsAtomically` ran against allocation
source SHA-256
`c3e7d28ef1532a8056dbf7261e73439bef506830f2d20c01ae2f59fd36b63da6`.
The parent payment preview required `100 * 10^18` other-leg units for the
`100 * 10^18` anchor. Genesis with only `1 * 10^18` other units succeeded,
so the regression failed with **“next call did not revert as expected”**:
0 passed, 1 failed, exit **1**.
See `runtime/f1-fail-before-02.log`, including source/test hashes.

The preceding attempt, `runtime/f1-fail-before.log`, exited **2** before
execution because a short external-fixture artifact name resolved to four
sources. The retry used the exact existing fixture path. That setup failure
is retained and is not the fail-before behavioral proof.

Corrected F1 coverage:

| Actual test boundary | Result |
| --- | --- |
| Historical 100/1 selection, required minimum 100 | Exact `InvalidGenesisLeg(otherPair)`; complete observable capital snapshot unchanged. |
| Required minimum minus one native unit | Atomic rejection. |
| Equality and one native unit excess | Successful full-book reserve, exactly `100e9` native self supply, no receipt principal, fixed bond LP custody. |
| Alternate anchor | First-leg underfunding rejects; equality succeeds. |
| Actual six-decimal other token | Minimum is `100e6`, not `100e18`; one native unit short rejects and equality succeeds. |
| Direct SE-share anchor | Real share acquisition and pre-conversion public pair-equivalent quote determine actual self mint; booking does not change the quote. |
| Consumed-capital parity | Actual `MigrationCapitalConsumed` amounts equal supplied input minus the SE's pre-conversion preview refund for both legs. |

`MigrationGenesisCapitalBase._capitalState` at TM line 39 includes parent
liveness/bootstrap supply, funded staking state, six token supplies, donation
budgets, balances of seven relevant holders, and parent/payer/bond allowances
to the relevant holders. This includes the hook and both real production
SEs. Failed attempts restore those observations exactly; earlier donations
remain booked. These are genuine calls, not storage snapshots injected into
the subject.

The six-decimal fixture uses the real WETH/V3/SE/hook stack. Its pool seed
liquidity uses the geometric mean of native inventories; no pool or SE
subject is replaced.

## 3. V1: genuine Permit2, exact domains and actual rollback

The installed production selectors execute through the real bond proxy:

- `donateWithPermit2Allowance(address,uint256,uint256,uint256)`
- `donateWithPermit2Signature(address,uint256,uint256,uint256,bytes)`

Their production canonical address remains
`0x000000000022D473030F116dDEE9F6B43aC78BA3`.
The successful fixture calls the existing
`forge-std/src/StdCheats.sol:895-914` `deployCodeTo` mechanism with the
current Solar artifact for
`lib/crane/contracts/protocols/utils/permit2/BetterPermit2.sol`.
That mechanism executes the genuine counterparty constructor **at the
canonical address**, then installs its returned runtime there. It does not
copy a foreign deployment's cached domain, patch immutable bytes, replace a
signature verifier, or etch/mutate/impersonate any production subject.
This is existing external fixture machinery, requiring no additional setup
authority or shared-file change.

The runtime Keccak-256 at canonical Permit2 in the successful test fixture is:
`0x584b3dfa0888b6e2ba8f0a3a47011aa3c53dcd8a819c8dd1963e00cbcc82ba6a`.
The independently constructed signing domain is
`EIP712Domain(string name,uint256 chainId,address verifyingContract)`,
name `Permit2`, verifying contract the canonical address. Actual domains:

| Chain ID | Domain separator |
| --- | --- |
| 31337, execution chain | `0x4d553c58ae79a6c4ba64f0e690a5d1cd2deff8c6b91cf38300e0f2b76f9ee346` |
| 1 | `0x866a5aba21966af95d6c7ab78eb2b2fc913915c28be3b9aa07cc04ff903e3f28` |
| 31338 | `0xd39117098c7fdd9b7eb1fa23b1f6296122c98bb236a734d2beeb44bdad389f2b` |

Both cached-chain and changed-chain behavior are checked. Signatures bind
the real bond proxy spender, amount, nonce and deadline. A signature formed
on 31338 is rejected on 31337 without consuming its nonce.

### Positive measured results, each on a fresh real fixture

| Observation | Allowance route | Signature route |
| --- | ---: | ---: |
| Actual donor contribution-token debit | 10,000,000,000,000,000 | 10,000,000,000,000,000 |
| ERC20 approval before / after | 10e18 / 9.99e18 | 10e18 / 9.99e18 |
| Permit2 allowance before / after | 1e18 / 0.99e18 | 1e18 / 1e18 |
| Signed-allowance nonce | 0, unchanged | 0, unchanged |
| Signature nonce bitmap word 0 | 0, unchanged | 0 -> 128, nonce 7 consumed |
| Reported primary donation LP, equal to preview | 1,555,724,301,217,996 | 1,555,724,301,217,996 |
| Actual bond LP increase, including canonical residual joins | 1,770,544,802,207,521 | 1,770,544,802,207,521 |

The latter delta is reconciled exactly against all actual LP mint events
to the bond, rather than incorrectly equating primary-join output with the
additional residual joins in join/notify. The donor receives no LP,
DETF principal or receipt gons. Parent supply and total staking gons remain
unchanged. Temporary bond-to-parent and parent-to-hook allowances clear.

### Isolated negatives

The fifteen tests include successful allowance/signature donations and
domain identity, plus: expired outer allowance-route deadline; expired
Permit2 allowance with a valid outer deadline; a funded/approved caller
with no donor allowance; expired signed permit with a valid outer deadline;
wrong spender, wrong funded/approved caller, wrong chain-domain signature;
replay after a committed successful donation; and downstream minimum and
callback failure for **each** route.

Minimum failures occur after genuine transfers and reserve execution.
Callback failures occur during the actual bond-to-parent token pull:
the external token attempts the real locked-parent `synchronizeRewards`
callback, is rejected, and propagates the failure through the canonical
`TransferFromFailed()` wrapper. No fake successful callback is recorded.
The tests require the real callback to occur.

`_permitState` at TM line 83 combines the complete capital-state fingerprint
with donor balance, ERC20 approval, Permit2 amount/expiration/nonce,
signature bitmap, donor product balances and both child phases. Every
failed route compares before/after state exactly. Minimum/callback cases
then successfully reuse the same restored allowance or signature nonce.
Replay preserves the already committed first donation.

Actual numeric observations, not merely revert names, are retained in
`runtime/permit2-quantitative-evidence.json`,
`runtime/permit2-reserve-state-observations.json`, and the full
`runtime/permit2-state-traces.log`. The bounded extra trace run executed
15 tests, 1 suite, exit **0**, solely to record detailed passing state reads.
It did not repeat the large combined suite.

Permit2 proof is through real Foundry-deployed production proxies with the
genuine canonical counterparty. It is not a claim that the unchanged
two-stage local QA script deploys its CREATE3 Permit2 at that canonical
address. No newly exposed production phase/caller defect required a repair;
parent/bond policy targets remain unchanged.

## 4. Commands, exits and counts

Selected binary: `/Users/cyotee/.foundry/bin/forge`, version
`1.9.1-nightly`, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`.
Artifact compiler:
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`. No viaIR.

Every test pass below used the artifact-first helper, which builds concrete
runtime artifacts before executing tests. Full commands/environment are in
`runtime/commands.json`; expanded Solar commands and skip selections are
also in the raw logs.

| Run | Actual executed result | Exit | Log |
| --- | --- | ---: | --- |
| New historical F1 regression on defective source | 0 passed, 1 failed for missing rejection | 1 | `runtime/f1-fail-before-02.log` |
| First correction/fixture integration attempt | 11 passed, 8 failed, 3 suites | 1 | `runtime/correction-first.log` |
| Second changed-input attempt | 16 passed, 7 failed, 3 suites | 1 | `runtime/correction-second.log` |
| Complete corrected focused TM | **83 passed, 13 suites, 0 failed/skipped** | **0** | `runtime/focused.log` |
| Established combined roots | **10,102 passed, 612 suites, 0 failed/skipped** | **0** | `runtime/combined-and-qa-build.log` |
| Corrected local QA script build | Successful Solar build | **0** | Same log |
| Bounded detailed Permit2 state trace | **15 passed, 1 suite, 0 failed/skipped** | **0** | `runtime/permit2-state-traces.log` |
| Fresh Stage A | **230 successful mined receipts** | **0** | `runtime/stage-a.log` |
| Fresh Stage B | **16 successful mined receipts** | **0** | `runtime/stage-b.log` |

Focused reproduction from the worktree:

```sh
export PATH=/Users/cyotee/.foundry/bin:$PATH
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration \
  -- -vv
```

The combined command uses that same edited source and the exact thirteen
established roots recorded in `runtime/commands.json`: ordinary V4 DETF,
common DETF, TM, V3 InQuery declaration, weighted Swap/Scale/Fees/
RefundCallback/OwnerDuringLock/SeBufferAbi, ERC4626 TransitionQuote, and
V3 FullRangeBook/Previews. It ran once on the corrected inputs.

Fresh clean Solidity diagnostics were obtained for all five authored source
files; earlier freshness timeouts are not relabeled clean observations.
See `runtime/diagnostics-and-source-locations.json`.
The existing unrelated compiler warnings and `fmt.skip` warning remain in
the raw logs; no warning or test was suppressed. JSON Biome LSP is not
installed; no dependency/configuration change was made. Evidence JSON was
serialized from parsed data.

## 5. Fresh corrected-production owned18548 QA

Owned node instance:
`0x86c73d741983bdf3fbff119692d28fb7951dd9b3b335e8105e9dd94a00fd477a`.
Endpoint `http://127.0.0.1:18548`, chain 31337, 100,000,000 block gas,
unlocked standard dev accounts, no fork/private key, EIP-170 enforcement on.
The node used native genesis balance 1,000,000 ETH per account, then actually
wrapped WETH. The mintable contribution currency remains an external fixture,
not historical recovery provenance.

Separate fresh broadcasts and script journals are under `runtime/`.
The new script cache was seeded from the warm Solidity/ABI caches without
copying any prior script journal. All prior attempts and warm artifacts
were retained.

Exact requested stage argv, under the node-bound guard/environment recorded
in `runtime/stage-a-command.txt` and `runtime/stage-b-command.txt`:

```sh
FOUNDRY_BLOCK_GAS_LIMIT=1000000000 forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA --sig 'deployAndIssue()' --rpc-url http://127.0.0.1:18548 --broadcast --unlocked --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266

FOUNDRY_BLOCK_GAS_LIMIT=1000000000 forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA --sig 'exerciseAfterCliff(address)' "$MIGRATION_PARENT" --rpc-url http://127.0.0.1:18548 --broadcast --unlocked --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
```

The parent was derived from the unique **mined**
`MigrationReserveBootstrapped` event:
`0x406cd20cb6f03f51cd303a3d14d6b1fbbcccab88`.
The actual contract owner is
`0xD8c0e1DF4Cb2a23Eb2949A193374F6524c12D9aE`, controlled by the unlocked
dev account; the role beneficiary is separately
`0xc02C5970BC54EB54442C421C7DE43Eec12481C5D`.
Addresses repeat deterministic prior addresses, but all receipts belong to
this new captured node instance.

Every transaction's from/to/input/nonce/value, success receipt and mined
block hash were compared against this node. Mismatches: zero.
Stage A's actual configuration ID is
`0xbd7d54a99ab363eae09d2a4ecb5f19efe56d43dd2d02e42c28c7e265d3615771`;
the owner fixture reads it on-chain before issuance. Genesis supply is
100,000,000,000 native DETF; issued principal is 1,201,585,232, with equal
actual held receipt backing. No supply is attributed to configuration alone.

Issued timestamp: **1794353395**. After Stage A, the actual latest timestamp
was **1794353396**. `evm_increaseTime(7776001)` followed by `evm_mine`
produced **1802129397**, exactly **7,776,001** seconds later. These are mined
node timestamps, not a simulation-only warp. The wrong actual CLI endpoint
18549 was rejected with exit **64**, nonce unchanged, before broadcasting.

Fresh mined behavior:

| Observation | Result |
| --- | ---: |
| Principal-only payment before activation | 1,201,585,232 sDETF; reward field exactly 0 |
| Activated original NFT reward | 1,065,857,776 sDETF |
| Deferred wallet release | 9,810,261 sDETF |
| Captured role release to actual beneficiary | 717,112,024 sDETF |
| Departed SY holder's native RT | 2,903,655,350,914,193,571,309,238 |
| RT redemption to different receiver | 5,529,754 sDETF |
| Redemption fraction retained for RT owner | 394,395,608,778,125,083,915,324,042,509,108,970 gons |
| Sub-RT native remainder call at this index | 0, correctly retained; not claimed positive payment |
| Repeated SY reward claim | 0 |
| Ordinary new bond 4 | Unmarked, ordinary terms |

The old NFT 3 is canonically retired after complete payment; a subsequent
`positionOf(3)` read correctly returns `ERC721NonexistentToken(3)`.
The actual before/after activation metadata events are decoded in
`runtime/metadata-captures.json`; no new visual-rendering acceptance is
claimed for this allocation-only production correction.

Parent selector count changes **96 -> 91**; child counts stay receipt 44,
bond 42, raw SY 42, staking SY 42, RT 22. Exactly the five installed admin
selectors disappear: `0xec55c474`, `0x161d9afc`, `0xccff9894`,
`0x787642e8`, `0xe9dc9e6d`. Administration interface `0xa71d1a99` becomes
unsupported and direct calls to all five absent selectors reject.

All 22 live facet runtimes, five actual factory-bound package runtimes and
three linked libraries match current artifacts with only compiler-declared
link/immutable locations masked. Links are independently checked.
The corrected allocation facet is **20,183 bytes**, below **24,576**;
the parent package is 16,632 bytes. No size-limit bypass was used.
See `runtime/live-runtime-binding.json`.

Final actual backing is 2,696,982,231 native DETF, with allocation/staking
dust 2/1. `runtime/conservation.json` enumerates observed receipt holders
and verifies physical gons equal T, escrow equals beneficiary domains plus
E (U is zero in this rehearsal), E equals RT supply times 1e18, bond/SY
attribution equals physical custody, and backing equals floor(T/k) plus
both dust classes. All seven equalities pass.

## 6. Retained attempts, limits and cleanup

Retained nonpassing setup/proof attempts:

1. The ambiguous external token artifact path caused the first helper
   invocation to exit before tests; the exact path resolved it.
2. The initial six-decimal fixture used 18-decimal liquidity geometry and
   failed its real pool seed. Only the legitimate reusable seed hook and
   external fixture liquidity were corrected.
3. The repository's old precompiled `DeployPermit2` runtime returned an
   incorrect cached domain for the test chain. The domain test caught it
   and real signatures failed. It was replaced by constructor-at-canonical
   execution of the genuine current artifact, not by signing the wrong
   domain or patching a verifier.
4. Timestamp 1 made an allowance expiration of zero mean “now,” not expired.
   A deterministic later timestamp isolates the intended expiry rejection.
5. Initial LP expectations conflated reported primary-join LP with subsequent
   residual-join minting. Final tests require exact primary preview parity
   and independently reconcile the full LP delta from actual mint events.
6. The callback's inner authorization error is canonically wrapped as
   `TransferFromFailed`; final expectations match the actual path while
   requiring the genuine callback and complete rollback.
7. Readback helpers initially queried the already retired NFT and guessed
   single-contract artifact directories for interfaces/libraries declared
   in multi-contract files. Those read-only probe errors were corrected;
   no transaction, production behavior or test was weakened.
8. One monitor registration had an invalid filter regex and started no
   command; it was corrected before execution.

No unresolved attributable test, production, receipt, source-binding or QA
failure remains. The strict test checks protect actual capital, funding,
custody and signature contracts; no prose/source pin or test-only production
configuration surface was added. Existing large production/TestBase files
were not refactored beyond the required narrow changes.

`runtime/cleanup.json` records the owned Anvil stopped, no listener on 18548,
no matching owned Anvil process, and the empty owned TMPDIR removed.
The stop tool reported EPERM removing its terminal monitor-state file;
independent port/process probes confirmed actual shutdown. No other
session's process or port was stopped. Warm `out/`, `cache_forge/`, separate
script cache, every receipt/log/attempt, and shared links remain.
No required command or cleanup is pending.

**F1: corrected with source-bound failing-before and passing-after evidence.**
**V1: genuine canonical Permit2 allowance/signature success and isolated
rollback evidence complete.** Independent verification must still execute
the former underfunding case against the correction and inspect these
bindings; this producer does not impersonate that verifier.

E1/E2, actual legacy custody/attribution and source forks, surrender,
recovery/harvest, actual-recovery configuration, operator/resume workflows,
operational gas/batch limits and full release gates remain open exactly as
before. This bounded correction neither completes the original migration
plan nor authorizes public deployment, funding, activation or compensation.
