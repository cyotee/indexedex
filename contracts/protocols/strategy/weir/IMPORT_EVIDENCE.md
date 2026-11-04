# WeirVaults import evidence

Work order `weir-import-plan-final-r2`. PRD `weir-import-prd-owner-clarifications-20261029`. This ledger is not a safety clearance, not a legal clearance, and not archive proof.

Hermetic manager is a real `PoolManager`. Weir is `new WeirVaults(poolManager, treasury, owner)`. No CREATE3 manager. No mock, etch, storage injection, or `vm.mockCall` of Weir or the manager.

`test/foundry/spec/protocols/strategy/weir/WeirVaults_Callbacks.t.sol` uses the assignment labels, not the plan IDs. Rows below map by behavior.

## Commands

| Command | Result |
|---|---|
| `python3 contracts/protocols/strategy/weir/test/tools/check_fidelity.py --mode source` | Exit 0 before this ledger. Allowlist only, plus the recorded WI-06 frames |
| `python3 scripts/forge-artifacts.py build` on the three domain files | Exit 0. solc 0.8.35, optimizer on, runs 1, viaIR false |
| `FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test ... --test-root test/foundry/fork/protocols/strategy/weir` | Compile exit 0. Alias `robinhood_mainnet_alchemy` resolved from the login shell. `test_AC65_forkPreflight` passed: chain 4663, pin `76,197,114`, pin header, reference code, and reference `poolManager()`. `block.number` was a stale env value until `vm.roll` aligned it with the selected fork. No selected-pool parity trace. No substitute chain |

The confirming hermetic run is `python3 scripts/forge-artifacts.py test` on the three domain files and `--test-root test/foundry/spec/protocols/strategy/weir`. Result: 88 passed, 0 failed, 0 skipped.

## AC map

| AC | Status | Where |
|---|---|---|
| AC01 | PASS | `check_fidelity.py` exit 0. `evidence/import-transform.json` |
| AC02 | PASS as a recorded artifact compare | `evidence/abi-baseline.json`. 27 functions, constructor, receive, 11 events, 18 listed errors. Extra compiler `InvalidTick(int24)` is not a Weir method. No live `test_AC02` in this run |
| AC03 | PASS | Default build exit 0. viaIR false |
| AC04 | BLOCKED-RELEASE | `VENDOR.md` license section. 39 frozen entries recorded. Clearance was not run |
| AC05 | PASS | `test_AC05_validDeploy`, `test_AC05_zeroTreasury`, `test_AC05_zeroOwner`, `test_AC05_zeroManager` |
| AC06 | PASS | `test_AC06_twoKeysSharedCurrency`. Usable ticks are stored by `createVault`; this test does not read them back |
| AC07 | PASS | Duplicate create is `VaultExists`. Uninitialized create is `PoolNotInitialized`. `allVaults(count)` reverts with empty data. solc 0.8.35 with `via_ir=false` emits `PUSH0 DUP1 REVERT` for that generated getter, not `Panic(0x32)`. The assertion matches that getter. No custom getter was added |
| AC08 | PASS | `test_AC08_unknownAndEmptyCreated` |
| AC09 | PASS | `test_AC09_F0_payerNotRecipient`. Fixed shares `1047576`, liquidity `K`, manager cost `K` per side |
| AC10 | PASS | `test_AC10_raw1002` reverts `ZeroShares`. `test_AC10_raw1003` mints liquidity 1001, one share, refund 2 each |
| AC11 | PASS | Zero inputs roll back in `test_AC10_zeroDepositRollsBack`. `test_AC11_oneSidedFreshAndExisting` reverts `ZeroShares` for a fresh one-sided deposit and for a one-sided deposit into an existing F0 vault |
| AC12 | PASS | `test_AC12_secondPairedDeposit`. Second user receives `K`. `L = T = 2K`. Reserve gap 1000 |
| AC13 | PASS | `test_AC13_depositAfterRealFees`. Post-compound base. Second user receives `K`. Idle0 stays 19 |
| AC14 | PASS | `test_AC14_F3_idleDilution`. Second-user currency0 output is the oracle amount plus 9. Idle0 left at 10 |
| AC15 | PARTIAL | `test_AC15_balancedNoSwap` keeps slot0 unchanged and mints F0. Swap subcases stay blocked. No `swap-golden.json` was invented |
| AC16 | GAP | Tick oracle absent. Not run |
| AC17 | PASS | `test_AC17_minSharesEqualAndPlusOne`. Equality succeeds. `S+1` reverts `Slippage` and rolls back the auto-created vault |
| AC18 | PASS | Full transfer and overspend `Panic(0x11)` ran earlier. `test_AC18_selfWeirAndUnknownZero` keeps a self transfer unchanged, lets Weir hold 10 stranded shares, accepts an unknown zero transfer, and reverts `ZeroAddress` for a zero recipient |
| AC19 | PASS | `test_AC20_pausedDepositAndWithdraw`. Paused deposit is `EnforcedPause` before pull. Paused withdraw pays `F0_OUT` each |
| AC20 | PASS | Expired deposit and withdraw revert `Expired` before pull. Zero recipient reverts `ZeroAddress` before pull. `test_AC20_pauseBeforeDeadlineAndRecipient` is `EnforcedPause` when pause, expiry, and a zero recipient are combined, and the payer is not pulled |
| AC21 | PASS | `test_AC21_F0_fullWithdraw`. Output `(1047575, 1047575)`. Residual `L = T = 1000` |
| AC22 | PASS | `test_AC22_subsetAfterFees`. Burn and idle claim use post-compound floors. No last-user sweep |
| AC23 | GAP | No real exceptional construction reached zero removed liquidity, idle-only burn, or all-zero output. Not treated as a pass |
| AC24 | GAP | Tick oracle absent |
| AC25 | GAP | Tick oracle absent |
| AC26 | PASS | Equality, `min0+1`, and `test_AC26_min1PlusOne` all restore the F0 ledger on `Slippage` |
| AC27 | PASS | `test_AC27_orderedFaults`. Expired, `BadZap`, `ZeroAddress`, `NoVault`, `ZeroShares`, `Panic(0x11)` |
| AC28 | PASS | `test_AC28_emptyCompoundTwice`. Timestamp updates. No Weir event |
| AC29 | PASS | `test_AC29_unknownCompound`. `NoVault` before unlock |
| AC30 | PASS | `test_AC30_F1` gross 20, cut 1, idle 19. Second compound emits no Weir event and keeps idle 19 |
| AC31 | PASS | `test_AC31_F2`. Added liquidity 17. Idle `(2, 2)` |
| AC32 | PASS | Fee 0, fee 1000, and gross 19 ran earlier. `test_AC32_selfTreasury` records idle 19, holds physical 20, and a later compound does not book the extra 1 |
| AC33 | GAP | One-sided deployable price outside the stored range was not constructed |
| AC34 | PASS | Direct donation does not book. `test_AC34_selfRecipientWithdraw` pays `F0_OUT` each to Weir, leaves idle `(0, 0)`, and leaves `L = T = 1000` |
| AC35 | PASS | `test_AC35_sharedCurrencyIsolation`. Operating on the first vault leaves the second vault's idle, liquidity, and shares unchanged. Weir's shared-currency balance equals the selected idle |
| AC36 | PASS | `test_AC36_noAllowanceAndNoBalance`. `Error("allowance")` and `Error("balance")`. No vault created |
| AC37 | GAP | Tick oracle absent |
| AC38 | PASS | `test_AC38_previewFractionAndAll`. Zero, assigned, and total-share quotes match the independent amount oracle. No ownership check |
| AC39 | PASS | `test_AC39_shareCastFitsAndOverflow`. Shares `2^128+7` quote `(6, 6)`. Shares `2^236` panic `0x11`. Zero total returns `(0, 0)` |
| AC40 | PASS | `test_AC40_previewEqualsExecution`. No pending fees and no zap. Preview equals the F0 withdrawal `(1047575, 1047575)` |
| AC41 | PARTIAL | `test_AC41_pendingInside` reads gross 20 before compound and 0 after, with no state change on the view. Below, above, and wrap stay gaps |
| AC42 | PASS | `test_AC42_boundsOrderedAndReversed`. Copied library and independent oracle agree |
| AC43 | PASS | `test_AC43_interiorMin` includes the interior minimum and the two outer-boundary branches against the independent oracle |
| AC44 | PASS | `test_AC44_overflowBranch`. Both branches revert `Error("liquidity overflow")` |
| AC45 | PASS | `test_AC45_equalBoundsAndDivByZero`. Equal bounds revert with empty data. `A = 0` reverts `Panic(0x12)` |
| AC46 | PASS | `test_AC46_timestampWrapAndDeadline`. Stored timestamps `2^64-1`, 0, and 7. Deadline equality accepted. `t-1` is `Expired` and does not move the stored timestamp |
| AC47 | PASS | `test_AC47_fuzzOracleDomain` passed 16 configured runs. `test_AC47_overflowBounds` reverts `Error("liquidity overflow")` and `Panic(0x11)` through an external probe. `foundry.toml` was not edited |
| AC48 | PASS | Paired native deposit, balanced native zap, and the low, high, and ERC-20 value rejects all ran. The balanced zap matches F0 and does not move the price |
| AC49 | PARTIAL | `test_AC49_rejectingRefund` rolls back a nonzero native refund. Zero-refund construction was not reached |
| AC50 | PASS | `test_AC50_rejectingTake`. Top-level selector is `WrappedError`, and the payload contains `RejectedNative`. Shares and liquidity roll back. It is not Weir's raw `NativeTransferFailed` |
| AC51 | PASS | Pre-unlock sync and `test_AC51_syncDuringCallback` both return `NonzeroNativeValue` (`0xb0ec849e`). The during-callback sync rolls back with the deposit |
| AC52 | PASS | `test_AC52_feeBoundsAndPauseRepeat`. Non-owner is `OwnableUnauthorizedAccount`. Fees 0 and 1000 accepted. 1001 is `FeeTooHigh`. Zero treasury is `ZeroAddress`. Repeat pause and unpause use the OZ errors |
| AC53 | PASS | `test_AC53_twoStepAndRenounceWhilePaused`. Wrong accepter fails. Former owner cannot unpause |
| AC54 | PASS | Pull and hook reentry reach `ReentrancyGuardReentrantCall` and roll back. Take reentry wraps that selector in `WrappedError`. Refund reentry surfaces `NativeTransferFailed` because `_send` discards the inner data. `test_AC54_pauseInsideCallback` reaches `EnforcedPause` before the guard, and the pause rolls back with the failed deposit |
| AC55 | PASS | `test_AC55_falseExplicitAndEmpty` and `test_AC55_shortAndZeroDoNotCheckInbound`. False is `SafeERC20FailedOperation`. Explicit `HostileExplicit` bubbles. Empty return with delivery mints `F0_SHARES`. Short and zero, with and without 1 unit of pre-existing inventory, revert `CurrencyNotSettled` (`0x5212cba1`). The inventory unit is not spent |
| AC56 | PASS | Token-driven transfer moves the token's own shares: pull, pay, and refund move 3, and the payer keeps `K`. The owner callback sets the fee to 1000 and, on the next deposit, `transferOwnership` leaves that owner in place and sets the pending owner. Both survive the successful deposit |
| AC57 | PASS | `test_AC57_treasuryChangesBetweenTakes`. The native cut reaches the old treasury, that callback sets the next treasury, and the ERC-20 cut reaches the next treasury |
| AC58 | PASS | Outsider empty and malformed calldata revert `NotPoolManager` before decode. Nested compound reverts `AlreadyUnlocked`, including the caught return. Guarded reentry is reached before that unlock error in AC54 |
| AC59 | PASS | `test_AC59_hookOrder`. `createVault` makes no hook call. Zero liquidity skips the poke. A zero reinvestment compound pokes through the remove flags and does not add. The next compound pokes, then adds, with the supplied hookData |
| AC60 | GAP | Return-delta construction was not attempted. Not treated as a pass |
| AC61 | PASS | `test_AC61_creditPrecedesRefund` sees the recipient credited before the native refund. `test_AC61_debitPrecedesPayment` sees the caller already debited when the native take reaches the recipient |
| AC62 | PASS | `test_AC62_receive` accepts value and does not change the ledger. `test_AC62_nonpayableValue` fails `createVault` with value and empty revert data |
| AC63 | PASS for the split the plan allows | `invariant_AC63_supportedDomain` ran 16 times, 128 calls, 1 discarded deposit revert. Position liquidity matched, the assigned-share sum was `T - 1000`, idle and Weir token balances stayed 0, and the manager was locked. `test_AC63_scriptedDimensions` covers withdrawal, donation, compound, pause, owner transition, and the second pool. `success > 0` alone is not the result |
| AC64 | PARTIAL | `test_AC64_classifiedHostileCases` classifies false as `SafeERC20FailedOperation`, explicit revert as `HostileExplicit`, short and zero as `CurrencyNotSettled`, and empty return as success with `F0_SHARES`. Supported-domain invariants are not asserted on those failures. Partial fills remain a tick-oracle gap |
| AC65 | PARTIAL | `test_AC65_forkPreflight` passed on `robinhood_mainnet_alchemy` at pin `76,197,114`. Header, reference code, and reference `poolManager()` matched. `test_AC65_forkParitySelectedPool` is not in the suite, so there is no selected-pool parity trace. No `vm.skip`. `ROBINHOOD_MAIN.sol` was not edited |
| AC66 | PASS as this file | Every WI and AC has a row. Hermetic and fork statuses are separate |
| AC67 | GAP | Return-delta idle candidate was not attempted |
| AC68 | PASS | The six selected files were rehashed and match the frozen bytes: Ownable, Ownable2Step, Context, Pausable, ReentrancyGuard, and token IERC20. Storage layout is `evidence/storage-layout.json`. Token false, empty, explicit, short, and zero returns ran in AC55. Owner, pause, and guard cases ran in AC52, AC53, and AC54. SafeERC20 is not whole-file equal; the used path is the recorded v5.2 difference |
| AC69 | PARTIAL | `evidence/resolved-graphs.json` records the compiled graph. License disposition remains blocked-release |

## WI map

| WI | Status | Closes only if |
|---|---|---|
| WI-01 | PASS | Three domain files are at `contracts/protocols/strategy/weir/` |
| WI-02 | PASS | Allowlisted diff plus recorded WI-06 frames. Fidelity exit 0 |
| WI-03 | PASS | `VENDOR.md` has both hash columns and the missing-upstream note |
| WI-04 | PASS | Surface diffs, runtime reads, and the rerun six-file identity hashes agree. SafeERC20 remains a used-path match, not a whole-file match |
| WI-05 | BLOCKED-RELEASE | Declarations are recorded. Clearance was not run |
| WI-06 | PASS | `CompoundFrame` and `DepositFrame` only. Recorded in `import-transform.json` |
| WI-07 | PASS | No wrapper, registry, NAV, repair, or simulator in the domain diff |
| WI-08 | PARTIAL | AC06 and AC09 pass. AC07 out-of-bounds does not match `Panic(0x32)` |
| WI-09 | PARTIAL | ABI and storage artifacts exist. No live ABI test in the spec root |
| WI-10 | PARTIAL | AC05 and AC62 pass. AC02 is an artifact record, not a spec test |
| WI-11 | PASS | `NoVault`, `NotPoolManager`, `AlreadyUnlocked`, and `test_AC59_hookOrder` ran |
| WI-12 | PASS | F0 payer/recipient, minShares, native refund, and both AC61 observations ran |
| WI-13 | PASS | Genesis reserve is unassigned. AC09 and AC10 |
| WI-14 | PASS | AC12, AC13, and AC14 use post-compound floors. No NAV assertion |
| WI-15 | GAP | AC16 and AC60 were not run |
| WI-16 | PASS | Full, self, Weir-held, unknown-zero, and callback-driven transfers ran |
| WI-17 | PASS | Debit-before-unlock, minima, ordered withdraw faults, and the debit-before-payment observation ran |
| WI-18 | PARTIAL | No-zap floors ran. Zap and partial-fill rows are gaps |
| WI-19 | GAP | Swap direction was not executed. No `x*y=k` substitute |
| WI-20 | GAP | Tick limits and partial fills were not executed |
| WI-21 | PASS | Empty compound, F1, and timestamp wrap |
| WI-22 | PARTIAL | F1, F2, fee bounds, gross 19, and self-treasury ran. AC33 and AC67 remain gaps |
| WI-23 | PARTIAL | Compounded emitted only for positive harvest on F1 and F2. Exit-swap fees were not run |
| WI-24 | PASS | Idle dilution, fee cuts, direct donation, self-treasury, shared-currency isolation, and the invariant campaign ran |
| WI-25 | PARTIAL | Unknown vault, preview, cast, equality, and inside pending fees ran. Below, above, and wrap remain gaps |
| WI-26 | PASS | Pause covers deposit. Owner setters and repeat pause errors ran |
| WI-27 | PASS | Two-step ownership and renounce-while-paused |
| WI-28 | PASS | Pull, hook, take, refund, and pause-during-callback reentry ran, with the callback share transfer and both AC61 observations |
| WI-29 | PASS | Native value, rejecting take, hostile returns, pre-unlock sync, during-callback sync, and receive ran |
| WI-30 | PASS | Failing calls compare pre-state and post-state. AC54 pull, hook, take, refund, and pause-during-callback ran |
| WI-31 | PARTIAL | Library, cast, panic, fuzz, and hostile-token rows ran. AC41 fee-growth wrap did not |
| WI-32 | PASS | Hermetic tests and the invariant handler use a real `PoolManager` and `new WeirVaults`. No mock, etch, or storage injection |
| WI-33 | PARTIAL | `Behavior_WeirVaults.sol` exists. Success rows assert directly and do not all call it |
| WI-34 | PARTIAL | `WeirMathOracle` agrees with canonical `FullMath` on the checked vectors. Swap goldens do not exist |
| WI-35 | PASS as recorded limits | AC23, AC25, AC33, AC60, and AC67 stay gaps. AC55 and the constructed AC64 cases ran. Partial fills stay a gap. None of those gaps was marked pass |
| WI-36 | PASS for the configured limits | Fuzz runs 16. Invariant runs 16, depth 8, 128 calls. The script supplies the dimensions the handler does not call. `foundry.toml` was not edited |
| WI-37 | BLOCKED | Fork command ran under the fork profile. Missing alias is blocked, not skipped |

## Not claimed

The import is not claimed safe. It is not claimed legally clear. It is not claimed archive-proven. BUSL production use stays unresolved. `swap-golden.json` was not invented.
