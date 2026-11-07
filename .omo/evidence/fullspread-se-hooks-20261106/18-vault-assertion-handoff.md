# Vault assertion source handoff

Date: 2026-11-07. This is source-only evidence for the bounded vault-test track.
No Forge, build, test, install, Git, deploy, artifact-writing command, or
delegation was performed. No runtime pass, gas result, release readiness, owner
approval, or completion of plan task 18 is asserted.

## Authority and scope

Requirements: only
`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.
Execution context:
`docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`,
especially the acceptance ledger and task 18.
The complete `18-acceptance-source-audit.md` was read with bounded reads;
overlapping reads recovered the long acceptance-table rows.

Repository router, assistant coding/deployment/testing rules, IndexedEx testing,
Crane testing/deployment/style guidance, the production FullSpread TestBase,
relevant package/factory lifecycle code, and each selected assertion's source
requirement were read before editing.

All Solidity edits are in
`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`
(abbreviated VT below). This file is the only evidence edit. No shared fixture,
production contract, hook source/test, configuration, plan, or PRD was edited.
The pre-existing quadratic tests and unrelated changes were left intact.

## Exact changed test inventory

Each name below belongs to its existing file's concrete production-first test
contract. A row records added source assertions, not an executed acceptance pass.

| Changed file under VT | Exact tests | Acceptance and assertion |
| --- | --- | --- |
| `Package.t.sol` | NEW `test_liveInstancesKeepSupplyBooksAndConfigurationIsolated` | FS-A04, authorized plan's live isolation extension. Two real registry/package instances use different initialized backing keys. Real deposits, swaps and collected fees mutate the first; the second's supply, custody, six family storage words, metadata and position bindings remain identical. A deposit into the second then preserves the first. Book values are observed with `vm.load`, never injected. |
| `Money.t.sol` | NEW `test_M14_oneSidedGenesisFloorAndFeeBothFaces` | FS-A05/11, FS-OWN-24/27. Each face bootstraps a fresh vault against real external liquidity. Actual added liquidity determines gross less the 1,000 floor; the 30% clamped fee and recipient net partition that gross exactly. No compound call or maintenance marker. |
| `Money.t.sol` | NEW `test_M10_bundleExitPaysExactBookedAndUnpaidClaimsBothOrders` | FS-A06/08/11, FS-OWN-30. Nonzero prior booked fees and fresh unpaid fees on both faces; independently floored principal/fee/book claims, exact recipient receipt, continuing-holder remainder, supply/liquidity burn, zero swaps and no compound call/marker, in both caller orders. |
| `Money.t.sol` | UPDATED `test_M07_passThroughBothWaysAndMinimumRollback` | FS-A11. Adds explicit zero compound-call expectation and absent Donation/Compounded markers beside the existing exact economic assertions. |
| `Money.t.sol` | UPDATED `test_M16_liveFeeToAndGlobalAndFunctionOperators` | FS-A39 and FS-OWN-14. After real feeTo rotation, direct old-owner donate/compound fail; funded new-owner donate and compound succeed without an operator grant to that owner. Donation debits exactly its declared input and maintenance does not mint supply. Existing appointment and selector-grant tests remain. An empty standalone compound is not required to emit a work marker. |
| `Callbacks.t.sol` | UPDATED `test_strangerCallbackReverts`, `test_uncommittedPayloadReverts` | FS-A18. Both negatives compare caller/vault/manager backing-token custody, supply, holder shares, position liquidity, all six family words and both vault manager deltas before/after. Existing error expectations remain unchanged. |
| `AlreadyUnlocked.t.sol` | UPDATED `test_borrowedExchangeInMintsAndClearsDeltas`, `test_borrowedExchangeLeavesForeignDebtOpen`, `test_borrowedExitToken0ReceiptMatchesLockedFromSameState`, `test_borrowedExitToken1ReceiptMatchesLockedFromSameState` | FS-A19/34. The existing non-SUT outer caller now observes BOTH backing-currency vault deltas immediately after the inner call, before its own settlement or relock. Tests assert both zero. Foreign-debt test still requires global count one and outer debt outstanding. |
| `AlreadyUnlocked.t.sol` | UPDATED `test_caughtBorrowedMinimumFailureRestoresVault`, `test_outerFailureRestoresBorrowedSwap` | FS-A23/36. Read-only snapshots include family books/reservations/guard, local custody, manager custody, full-range salt-zero position fee checkpoints and pool price. A finite input allowance makes its rollback observable. Caught failure observes caller token1 plus its intentional outer take and both allowances at inner return, then verifies exact outer repayment and restored vault state. Propagated outer failure restores caller token1, finite allowance and full vault/pool snapshot. |
| `AlreadyUnlocked.t.sol` | UPDATED `test_borrowedUnfundedCallerAndUnownedSharesRevert` | FS-A21. Another holder's real shares are parked on the vault before the unfunded caller tries mint and exit. Exact unowned-share error and unchanged parked shares/books/custody are retained/asserted. |
| `AlreadyUnlocked.t.sol` | UPDATED `test_borrowedBundleOutDonateAndCompoundReject`, `test_borrowedBundleRevertsAlreadyUnlocked` | FS-A22. All four existing `ManagerAlreadyUnlocked` negatives now compare vault/pool state, caller token balances, both allowances and post-revert vault deltas. Maintenance still runs through the actually appointed caller. |
| `AlreadyUnlocked.t.sol` | NEW `test_borrowedValueRejectsAtNonpayableBoundary` | FS-A20. An ETH-funded non-SUT contract forwards value inside an actual outer unlock and catches the ABI rejection. Empty returndata, ETH retention, restored vault snapshot, zero inner vault deltas and still-unlocked manager are asserted. No invented internal value error. |
| `AlreadyUnlocked.t.sol` | NEW `test_borrowedDisabledDirectMintRestoresState` | FS-A38. A direct disabled-vault mint inside a real outer unlock reverts the exact `VaultDisabled` error and preserves the vault/pool snapshot. This is distinct from successful hook-local input handling. |
| `AlreadyUnlocked.t.sol` | NEW `test_borrowedMintBothFacesMatchesLockedFromSameState` | FS-A33, FS-OWN-24/27. Each input face replays one snapshot through locked and borrowed dispatch. Exact recipient net, payer spend/refund, fee shares, gross/supply from actual liquidity, family books, manager custody and position/price snapshots agree. Borrowed dispatch has one outer unlock and zero vault callbacks; both inner vault deltas are zero. |
| `QuotesAndRate.t.sol` | UPDATED `test_economicViewsDisabledAndUnlocked` and its callback/view helper | FS-A32, FS-OWN-20. Stages real booked fees on both faces, distinct ambient unbooked transfers and fresh unpaid fees. Independently verifies deployed-only reserve arithmetic and invokes canonical/bundle previews in enabled/disabled and locked/unlocked combinations. The outer callback holds a real foreign currency0 debt while reading every view and then settles exactly that debt. |
| `QuotesAndRate.t.sol` | UPDATED `test_getRateAndExchangeOutAreAbsent` | FS-A09. Low-level inverse preview returns exactly 32 bytes decoding to zero, beside the existing enabled execution-negative and custody assertions. No refund ABI is introduced. |
| `Native.t.sol` | NEW `test_nativeShareExitPaysDistinctRecipientWethOnly` | FS-A10. A real native-backed vault burns caller shares and pays a distinct recipient exactly the returned WETH amount, with zero refund, no caller WETH payment and unchanged caller/recipient native ETH. Vault holds no raw ETH. |
| `BufferHookIntegration.t.sol` | REPLACED stale `test_disabledBufferedMintRevertsWhileUnlockedAndRollsBack` with `test_disabledBufferedInputBooksLocallyWithoutVaultMint` | FS-A38/42 and FS-HOOK-06. Positive paid face-to-raw swap on disabled SE: exact preview/recipient parity and payer debit, local face custody and rated face reserve increase by full input, unchanged SE supply/held shares/vault-face custody, zero face-input SE exchangeIn calls. Direct prohibited mint remains a separate new borrowed negative above. |
| `BufferHookIntegration.t.sol` | UPDATED `test_exactOutHookPaysNeitherToken` | FS-A28. Request exceeds ALL seeded local face custody by one face unit amount, instead of assuming a fixed output exceeds today's book. Requires the real SE inverse PREVIEW for the exact deficit and the wrapped `ExchangeOutNotAvailable` error. User custody, hook face/raw/share custody, SE/LP supplies and both reserve getters remain unchanged. This proves the inverse-preview boundary, NOT an executed SE exchangeOut call. |

The non-SUT `UnlockedExchangeCaller` extension lives in its existing VT file.
Its observations use live getters and manager transient reads. Family storage
snapshots are reads of the six words defined by the current FullSpread Repo
(booked[2], callbackHash, reserved[2], packed guard/initialized).
No SUT storage write, etch, replacement vault/manager, arbitrary sleep,
early-return passing branch, or prose-pinning test was introduced.

## Static results

The final per-file LSP requests used severity `all`.

| File under VT | LSP result |
| --- | --- |
| `Package.t.sol` | No diagnostics found. |
| `Money.t.sol` | No diagnostics found. |
| `Callbacks.t.sol` | No diagnostics found. |
| `QuotesAndRate.t.sol` | No diagnostics found. |
| `BufferHookIntegration.t.sol` | No diagnostics found. |
| `Native.t.sol` | No diagnostics found. |
| `AlreadyUnlocked.t.sol` | Freshness timeout: `Timed out waiting for fresh diagnostics ... within 3000ms.` An earlier intermediate revision returned no diagnostics, but that is NOT a clean result for the final revision. Final document-symbol lookup succeeded and included the added tests/helpers. Symbol parsing is not semantic validation. |

A directory diagnostic request was also attempted as a different route and
returned `No supported source files found in directory`. It does not supersede
the missing fresh per-file result. Final borrowed-suite semantic validation
remains blocked on fresh LSP diagnostics or the parent's serialized compile.
All edited assertion regions were inspected as source; no runtime command was
substituted for the authorized static-only boundary.

## Remaining gaps and precise boundaries

1. **FS-A03 repeated initialization remains blocked in this track.** The current
   package's `initAccount` checks its factory registration and argument identity
   before the initialized flag. The real factory calls it by delegatecall from
   proxy construction. Repeated production deployment returns the existing
   instance, and finalized proxies expose no init/delegatecall replay selector.
   Direct package calls only prove `InvalidInitializationContext`.
   Reaching `AlreadyInitialized` in the same legitimate account requires an
   authorized constructor-time replay-capable factory/proxy fixture extension,
   or an explicitly accepted package-context harness. Neither exists in the
   inspected deploy path. Changing shared factory/fixture code is outside the
   permitted paths; fabricating SUT code/storage or adding an init route is not
   an acceptable workaround. Existing lifecycle rejection tests were preserved,
   not relabelled as double-init proof.
2. **FS-A34 own-negative-debt sign case remains unconstructed.** Anyone can
   create the existing positive vault credit via real `settleFor`; an idle
   caller cannot use the manager's public API to assign debt to another
   address. Constructing a vault's negative debt before idle borrowed entry
   needs a legitimate vault-issued manager action/fixture seam. No such idle
   entrypoint was found in the inspected public surface. No vault
   impersonation, SUT storage injection or altered production was introduced.
   Both inner deltas and foreign debt are now explicitly observed; the positive
   own-credit rejection is retained, not advertised as a separate debt test.
3. **FS-A28 literal SE exchangeOut reachability is not claimed.** Current CP
   FullSpread inverse preview returns zero and the hook rejects at that preview
   boundary before execution. Forcing a successful inverse quote would falsify
   the authoritative FullSpread contract. Other families' exact-negative and
   stored-book assertions remain the parent's hook track.
4. **Hook-wide items stay with the parent.** The audit's remaining A25/26
   per-family/two-position receipt assertions, A29 target configurations,
   A31 executed gas/preview measurements, and A40-A48 validator/reentry/book,
   component-unit, repeated-exit, market-sequence, fee-alias and bootstrap
   matrices are not closed by these VT changes. They require assertions in
   the family adapters/shared behavior files outside this track, or actual
   artifact-backed execution owned by the parent. No existing matrix assertion
   was counted more broadly than its body.
5. **FS-A43/47 single-input incumbent-book snapshot order remains an owner
   decision.** No traded-alias rule, quote interface or unsupported sequential
   hook-quote support was added or endorsed. Same-backing-pool sequential
   composition remains unverified under FS-A30.
6. **Disable-axis scope:** the new local-input positive and direct borrowed
   negative use address disablement. Existing shared hook package-disable
   coverage was not modified or independently executed. Do not multiply this
   pair into all-family/all-disable-axis execution evidence.
7. **Runtime and final borrowed LSP remain pending.** Compilation, discovery,
   actual assertion results, gas, artifacts and concurrent-source
   reconciliation belong to the parent. No pre-existing runtime failure was
   classified from these source checks.

The audit's suggestions to exercise every individual invalid package input or
every possible assertion combination were not treated as new product behavior.
Existing invalid-component/lifecycle tests remain; this handoff does not claim
an exhaustive constructor mutation campaign.

## Exact serialized parent test command

After the parent has finished other Forge/artifact writers and refreshed all
runtime artifacts affected by its production edits, run this ONE process from
the shared checkout, with no concurrent build/test/artifact writer:

```bash
cd /Users/cyotee/Projects/indexedex && FOUNDRY_PROFILE=default forge test --use solar --isolate --threads 1 --match-path 'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/*.t.sol' -vv
```

This command includes the existing suites and inherited hook controls. It was
not run by this track. The parent must retain the real exit code, discovered
test identities, failures and actual runtime results before changing any
acceptance disposition. A green source/LSP result alone cannot close task 18.
