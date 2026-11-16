# Independent task 8 verification

Verdict: **confirmed**. `failure_class: none`. All five requested checks are supported by recorded execution and the inspected test assertions. This is verification of task 8, not the final repository gate or authorization to deploy.

Reviewed on November 15, 2026, in `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`. No Forge command, RPC, installation, implementation, delegation, commit, or product-file edit was performed. The completion claim was treated as untrusted.

The authoritative plan is `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md`, task 8 at lines 453-465. Its abbreviation table resolves:

- `$M`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration`
- `$T`: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration`
- `$K`: `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration`

Below, M, T and K denote those exact paths; log filenames are relative to this report's parent task-8 directory.

## Findings

No blocking product or harness finding was established for the requested checks. One intermediate artifact observation is stale: `adversarial-probes.json` records actor artifact SHA-256 `b504750fd5e6a6091f2be554a16c9ca1551960d1e4ff8f2f386fbaf74881de10` at `06:12:10.228Z`, whereas the current actor artifact hashes to `a22657542749fa934177315691bf47616b04388e634828d74fe022d7cb5888a6` and has modification time `06:15:54.080Z`. That intermediate hash is excluded from acceptance. It must not be described as the current artifact hash. The current ABI contains `callbackReason`; the final logged callback tests actually invoke that API. The final source hashes and raw logs match their recorded final bindings.

## 1. Exact happy command, roots and exit

Pass. `happy-5.log:1` contains the following exact argv before helper output at line 2:

```text
python3 scripts/forge-artifacts.py test "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration_Adversarial.sol" --test-root "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHostileContribution.t.sol" --test-root "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationOwnerBondCallbacks.t.sol" --test-root "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol" --test-root "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/invariant" -- -vv
```

These are the four plan roots, including the entire T/invariant directory. They are not replaced with a match-test or narrower contract selection. Line 3 records the Solar build; line 4 records the Solar test command. None of the requested roots is explicitly skipped. The current invariant root contains `MigrationNativeInvariant.t.sol`, whose two contracts both appear in the output.

There are 17 individual PASS records across five suites. `happy-5.log:6440` reports 17 passed, zero failed and zero skipped; line 6441 records `TASK8_HAPPY_EXIT=0`. Confirmation also relies on the assertions and successful actions below, not that count alone.

## 2. Substantive shared base and real SUT

Pass. `M/TestBase_UniswapV4DetfMigration_Adversarial.sol:20-62` implements hostile external-token deployment and a shared before/after state observation. Its digest covers payer/proxy token custody and allowances, booked donations, bond-held hook shares, allocations, immutable issuance, pricing getter outcome, owner-purchase prerequisite, activation, supply, actual receipt backing, full staking state, gons, next NFT ownership and proxy facet cuts.

Both `T/MigrationHostileContribution.t.sol:44-156` and `T/MigrationOwnerBondCallbacks.t.sol:51-121` inherit and use this setup and these assertions for real operations. They are substantive consumers, with six and two executed tests respectively.

The parent fixture deploys facets through component factories and registers parent/child packages through the vault registry (`M/TestBase_UniswapV4DetfMigration.sol:242-274`), then prepares children and deploys the actual package proxy (`:287-295`). The hostile token and owner wallet are external actors. A scoped search of 121 migration Solidity files found no `vm.etch`, `vm.store`, `vm.mockCall`, or direct `new UniswapV4DetfMigration...` construction. The inheritance matches were production Facet/Target/Policy composition, not test subclasses of the SUT.

## 3. Successful action witnesses

Pass. The counters advance after successful production calls, not merely attempted handler selection:

| Action | Raw evidence | Inspected execution/assertion |
| --- | --- | --- |
| Set A/B | `happy-5.log:5170`: 2 successful replacements | `M/invariant/MigrationNativeHandler.sol:70-89`; fixture explicitly calls both choices at `M/invariant/TestBase_MigrationStateful.sol:76-84`. |
| Configure | `happy-5.log:5171`: 1 | Handler `:114-131`, followed by record and accounting assertions. |
| Independent issuance | `happy-5.log:5172`: 1; active invariant `:6428`: 2 | Handler `:134-156` records returned bond IDs, principal and clocks after issuance. |
| Paid owner purchase | Passing native invariant plus its mandatory assertion | Stateful fixture `:57-58` buys the real bond; parent helper `:380-386` transfers capital, approves and calls `bond`; native suite `:23` requires a nonzero on-chain owner-first bond ID. This is a state witness, not a separately emitted purchase counter. |
| Activation | `happy-5.log:5173`: 1 | Handler `:182-189`; native suite requires exactly one successful activation and checks removed selectors. |
| Positive rewards | `happy-5.log:5175-5176`: 1 claim, 122238 units; `:6431-6432`: 2 claims, 366748 units | `M/invariant/MigrationNativeLedger.sol:140-176` compares exact expected due and actual receipt balance delta; zero claims have a different counter. |
| Surrender | `fork-4.log:4669-4678`: two NFT reload witnesses and two funded callbacks; `:4118-4172`: two successful surrenders for each of ten source domains | Legacy prelude executes surrender and both NFT takes; source-units suite requires positive per-domain successes and late funding rollback witnesses. |
| Harvest/recovery | `fork-4.log:4675`: 5 successful stages; `:4178-4179`: 8 admitted stages and one whole-batch rollback | `M/invariant/MigrationLegacyRecoveryHandler.sol:25-111,151-157` executes actual recovery calls, checks source receipts and fixed beneficiary, then increments counters. |

Both native invariant logs record 16 runs, 128 calls and zero handler reverts. Deterministic preludes and afterInvariant assertions ensure issuance/activation are reached even if random selection would omit them. Recorded configuration is seed `0x8`, 16 runs, depth 8; these settings were read, not rerun.

## 4. Hostile rejections and custody rollback

Pass. `hostile-rollback.log:1` records the exact same helper source and three hostile/surface roots, omitting only T/invariant as appropriate for failure QA. Helper output follows at line 2; Solar build/test commands are at lines 3-4. Lines 4225-4226 record 13 passes, zero failures/skips and `TASK8_HOSTILE_EXIT=0`.

The raw log individually records the required cases at lines 4214-4217 and 4221-4222. Their inspected bodies provide the exact error and custody oracles:

- Unauthorized pricing callback: `T/MigrationHostileContribution.t.sol:89-107` observes failed callback and exact `NotOwner(pairB)` bytes, then compares the complete book, configuration, supply and staking gons.
- Source spoofing: `:110-121` expects `UnsupportedWeightedSySource(block.chainid, pairB)`, compares the shared complete state digest, and requires no configured spoofed entitlement.
- Failed second child: `:124-140` submits two actual issuance requests, expects `ERC721InvalidReceiver(address(bonds))`, and compares both recipients' complete state digests. This checks rollback of the first child's effects when the second rejects.
- Contract-owner payment callback: `T/MigrationOwnerBondCallbacks.t.sol:26-47,53-86` checks exact `IsLocked`, `NotAuthorized` and `MigrationRewardsClosed` callback errors; short delivery expects exact `TransferDeltaInsufficient(1 ether, 1 ether - 1)` and compares custody, allowances, supply, staking and the shared digest.
- Booked/unbooked pretransfer negatives at `:91-121` preserve booked inventory and reject all prepaid purchase attempts; the genuine pull purchase cannot refund earlier inventory.

The -vv log supplies individual passing executions rather than a full revert trace. Exact expected error bytes and unchanged-state assertions are established by those executed test bodies and their matching source bindings, not by prose in the claim.

## 5. Executed residue and retained credit

Pass. `fork-4.log:5062` records PASS for `test_threeUnitsPay333Then334Then334OnActualProxy`. `K/invariant/MigrationLegacyInvariant.t.sol:171-212` deploys a distinct real registry proxy using a distinct owner salt, configures exactly 1001 native credit for three source units, actually transfers and approves those units, activates, and performs three one-unit surrenders. It checks actual returned credit and each funded bond principal as 333, 334, 334; exact start timestamps and 90-day duration; aggregate supply/backing increase of 1001; and zero remaining units/credit. This is execution, not a cited arithmetic example.

Repricing preservation is separately exercised: native handler `:70-89` snapshots all allocation/issuance records before setting pricing; `:348-366` checks stored credit against per-recipient retained credit and issued history against its original configuration. The fixture deliberately replaces an already issued recipient under B while keeping issuance A. Legacy suite `:35-57` checks the entire old NFT entitlement immediately after a setter and verifies stable original identity, unchanged supply/backing and unchanged source ownership on explicit reload. `fork-4.log:4669` records both NFT reload witnesses.

## Adversarial evidence handling and limits

| Probe | Independent disposition |
| --- | --- |
| misleading_success_output | Exact raw first-line argv, individual cases, nonzero action witnesses and terminal exit markers were required. In-memory controls removing the command or changing exit to 1 were rejected. Claim-only command text or aggregate pass counts were not accepted. |
| stale_state | All 10 final source hashes and 144 protected-file hashes match current bytes. The source-fingerprint preimage recomputes to `fff34a8dc3f181b39cd28d4f1a5fd38afab657bbad40ce1bd4b9e71ee273042e`. Initial bindings contain three older test versions and were not substituted for final bindings. |
| dirty_worktree | Read-only git status/diff inspection shows extensive inherited dirty and untracked work. It was not treated as a clean baseline or attributed wholly to task 8. The 144 protected-byte comparisons have no mismatch; no cleanup or reset was performed. Full unrelated-file attribution is outside this verification. |
| generated_or_cached_artifacts | Final raw helper logs record build before test, and required new callback behavior actually executes. All 19 delivered evidence files match recorded size/hash. The intermediate actor-artifact hash discrepancy is disclosed above and excluded; mutable out/cache metadata alone is not execution proof. |
| untrusted_external_text | The claim, coverage prose and probe conclusions were treated as assertions to check. No embedded instructions were followed. No external web or RPC text was consumed. |
| hung/flaky/cancel/interruptions | Not applicable to this verification: Forge was not rerun. Existing terminal exit markers were inspected; no fresh reliability claim is made. |

Task 7's witness-pin follow-up is not a task 8 failure. Protected claimed-SY witness/operator files match the task-8 baseline, including `claimed-sy-witness.test.ts`, `claimed-sy-witness.ts` and related operator files. No pin change by task 8 was established.

The claim remained 10797 bytes across reads and checks. Its SHA-256 is `860a56075800b59e82109c9765eeeb407881f4827eaf0ca2533092bec03f56f4`. A size change would require rereading it.

Primary raw-log SHA-256 values independently recomputed:

| Log | SHA-256 |
| --- | --- |
| happy-5.log | `5227d35f956f201eadc36a41116acbb08fa46524e0d2316ba8aef76bedb79911` |
| hostile-rollback.log | `de7fb54b41e548efb4ac31e321678cf9a45d90cf2ce1ced7020951f8f4f56864` |
| fork-4.log | `b589a8006d944c52a3c048f564535200f67d944b18206a0fdf85ec22094cbb01` |

Existing compiler/lint warnings and failed automatic submodule-initialization messages remain visible in the logs; they do not override the recorded final test exits. No dependency installation was attempted by this verifier. No mutation testing, fresh compilation, fresh fork, full-repository verification or public-chain validation is claimed.
