# Second audit remediation tracker

Decision date: 2026-10-22. Source report:
`IndexedEx_DiffReview_aca16198-2ba07631.md`.

Progress updated: **2026-11-07**, after completion of the current FullSpread
SE-hook implementation and verification plan.

This file records owner decisions, implementation evidence, and outstanding work.
Audit balances and deployment state describe the audit snapshot, not necessarily
the state at execution time. This progress update made no live RPC checks or
transactions. The containment and recovery probes below retain their original
block numbers; they are not November 7 balance or deployment attestations.

## Status

| Finding | Owner decision | Execution status |
| --- | --- | --- |
| APEX-2026-010 | Disable the retired SE package and the separately registered vulnerable vault; keep the previously disabled vault disabled. | Containment executed according to the owner and independently confirmed for all seven vaults at Robinhood block 95,154,306. No new live verification or transaction in this update. |
| APEX-2026-054 | Existing deployments cannot be upgraded. Disable the vulnerable underlying vaults; plan user-assisted recovery. | Fresh-instance hook approval/exit controls pass in the completed FullSpread work. Existing immutable positions are not repaired by those tests. Recovery contracts and atomic batches remain unimplemented/unvalidated in this tracker. |
| APEX-2026-037 | Keep the deprecated WETH-leg vault disabled; plan recovery through a user-deposit contract. | No re-enable, withdrawal, or migration authorized for execution by this work. |
| APEX-2026-011 | Historical October 23 retirement of the audited families; the subsequent current FullSpread implementation follows its own PRD. | Historical retirement closure retained. Current replacement source/regression verification is complete, including borrowed/own-unlock parity controls; see the November 7 evidence below. No deployment performed. |
| APEX-2026-041 | Historical retirement closure; current FullSpread must independently prove dust-tick liveness. | Current deposit/redemption and quote-parity dust-tick regressions pass. The old deletion is not used as proof of the new vault. |
| APEX-2026-042 | Historical retirement closure; current package must support no-return approval tokens. | Current `test_noReturnApproveTokenCanDepositThroughPackage` passes. This is fresh-instance evidence, not an upgrade of an audited deployment. |
| APEX-2026-051 | Historical retirement closure; current preview/execution behavior needs independent evidence. | Current shared-engine preview/execution and dust-tick controls pass under the current PRD. No fresh audit of unrelated families is claimed. |
| APEX-2026-012 | October 23 apportioned-reserve draft, followed by the October 24 entry-process correction and design pause. V3/V4 Wings remain a separate scope. | Design decision remains open. No V3 Wings implementation was found; V4 Wings `getRate` still uses the liquidation quote. The checkpoint does not authorize implementation or deployed-vault upgrades. |
| APEX-2026-022, 023 | V3 FullSpread remains; it is not covered by the V4 retirement or current V4 implementation. | Finding-specific V3 remediation/closure remains open in this tracker. New V4 regressions do not establish V3 closure. |
| APEX-2026-024, 025, 026, 040 | Wings exit sizing, rebalance loss cap, quote-work liveness and bootstrap/donation accounting remain separate findings. | No closure inherited from the FullSpread or hook work. Each needs its own Wings implementation/review evidence. |
| APEX-2026-036, 038, 039 | Existing-deployment pretransfer and standing-weight problems are not fixed by changing current source. | Deployment-level remediation/recovery remains separate. Passing current-source tests does not establish closure for immutable legacy contracts. |

## Completed implementation and verification - 2026-11-07

The current source under
`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`
is present and has completed its current implementation/testing plan. The
October retirement discussion below is historical; its deletion-based closure
does not certify this replacement, restore the old Pons family, or authorize
deployment.

Completed plan:
`docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`
(**24/24 tasks**).

Final evidence directory: `.omo/evidence/fullspread-se-hooks-20261106/`.

- `54-final-build.log`: plain Solar build passed, exit 0.
- `54-final-default.log` and `54-final-gates.log`: **2,660 suites,
  28,411 passed, zero failed/skipped, exit 0**.
- All **36 original failing identities** and **103 named controls for 42
  active acceptance rows** match passing tests. Five rows remain withdrawn;
  the remaining row records the disjoint-backing evidence boundary.
- The nine standalone and nine inherited FullSpread configurations contribute
  **373 passing cases** within that default total.
- All **36 cold composed routes** pass unchanged gas limits. The four formerly
  failing DETF burn/close calls pass their unchanged 30-million-gas call limits.
- Source-review blockers were repaired, including sequential-preview
  unknown-state propagation. `55-final-delta-gate-review.md` is **APPROVE**.
- All **77 affected product artifacts** fit runtime/initcode limits. The
  global `--sizes` command still exits 1 on **13 classified test/vendor
  artifacts**; see `49-size-classification.md`. This is not a green global
  size gate or a claim that those exceptions predate every task change.
- `56-final-summary.md`, `F1-compliance.md` through `F4-fidelity.md`, and
  `57-source-identity.json` record the final scope, review, receipts and source.

Delivered behavior includes paired-token membership and implicit SE shares,
native-component LP ownership and refunds, backed gross/net fee splitting,
per-required-leg pair-or-share genesis, continuing caller-funded single-leg
preparation, and the necessary DETF/Native SY integration. Explicit native
component joins on three families eliminate repeated residual conversions.
Unsupported sequential views fail closed while supported ordinary quotes
and actual execution remain positive.

Selected current regressions for the formerly retirement-closed findings:

| Finding | Current implementation evidence, passing in receipt 54 |
| --- | --- |
| 011 | `AlreadyUnlocked.t.sol`: `test_borrowedMintBothFacesMatchesLockedFromSameState`, both `test_borrowedExitToken*ReceiptMatchesLockedFromSameState` controls, and the current raw-liquidity/fee ownership controls. |
| 041 | `Money.t.sol`: `test_P08_dustTicksDepositAndRedeemComplete`; `QuotesAndRate.t.sol`: `test_dustTicksPreviewMatchesDepositAndRedeem`. |
| 042 | `Package.t.sol`: `test_noReturnApproveTokenCanDepositThroughPackage`. |
| 051 | The same P08/quote-parity controls exercise the current shared quote/execution engine; historical analytic-planner deletion is not the evidence. |

Those test files are under
`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`.
The current PRD's FS-TEST-04 yes/no/integration-only inventory remains the
scope boundary. This is verified implementation and regression evidence, not
a new audit of every second-review finding. V3, Wings and immutable-deployment
findings do not inherit closure from it. The PRD's accepted authorized
`compound`/`donate` sandwich exposure is not claimed removed, and disjoint-pool
tests do not prove same-backing-pool sequential safety.

## Remaining work

| Workstream | Findings | What remains |
| --- | --- | --- |
| User-assisted recovery and migration | 037, 054; deployment aspects of 010 | Finish the paused two-contract design: receipt/liability accounting, user rights, NFT reward attribution, compensation principal/ratio and new DETF backing, registry-owner authority, and atomic enable/withdraw/re-disable batches. Then authorize implementation and prove each supported route on a fork. |
| Other immutable-deployment exposure | 036, 038, 039 | Establish the applicable deployment-specific containment, recovery or replacement path and its evidence. Current-source fixes cannot upgrade these deployments. Keep actual principal recovery distinct from compensation issuance. |
| Wings accounting and associated findings | 012, 024, 025, 026, 040 | Resolve the paused design recommendation and the corrected entry-process premise. Once the design is accepted and implementation authorized, build the missing V3 Wings family, implement the agreed V4 behavior, and establish separate closure for exit sizing, rebalance, dust-tick liveness and bootstrap/donation accounting. |
| V3 FullSpread | 022, 023 | Resolve and verify the V3 borrowed/blocked-mode and maintenance findings. Preserve V3 FullSpread; the completed V4 program is not a V3 remediation receipt. |
| Repository-wide size gate | No new audit ID | Separately triage the 13 documented test/vendor size exceptions if a clean global `--sizes` gate is required. The affected product-size gate already passes; this is not unfinished FullSpread implementation. |

The next Wings decision is the recommendation recorded in
`docs/reviews/apex-012-design-recommendation-20261024/REPORT.md`, not automatic
implementation of the October 23 draft or automatic acceptance of its entry
swap. `APEX-2026-012-OPEN-QUESTIONS.md` records that pause and the rejected
question-1 premise. The migration decisions remain in the checkpoint at the
end of this file. Neither design is settled by a green regression suite.

No recovery contract, new compensation DETF, registry authority change,
re-enable, deployment or live recovery transaction is authorized by this
progress update.

## APEX-2026-054: immutable deployments and user-assisted recovery

Owner decision:

- Do not pursue upgrades of the existing vaults or hooks.
- Disable the vulnerable underlying SE vaults through the 010 containment.
- Plan a process in which users voluntarily deposit their deprecated tokens into
  a recovery contract. Preserve attribution of deposited tokens and recovered
  proceeds to their users.
- The recovery contract will orchestrate bounded batches that enable the relevant
  vault/package, withdraw what the deployed contracts permit, and disable it again.
  The enable, withdrawal, and re-disable sequence must complete in one transaction
  so the vulnerable vault is not left enabled between transactions.
- Recovery is conditional on a supported withdrawal path. Re-enabling a vault
  does not fix the missing hook-to-SE approval in 054. Demonstrate each proposed
  recovery route on a fork before claiming that principal is recoverable.

The audit reports `claimRewards` remains callable while normal principal closure
fails. Preserve existing reward entitlements in the future recovery design;
acceptance of bond NFTs or claim tokens, their rewards, and any replacement
entitlements still require a detailed design and tests.

## APEX-2026-037: deposit, enable, withdraw, disable

Owner decision:

- Keep `0x999DaE02D22E5FEe1c4508430D5196d31d631009` disabled.
- Users will voluntarily deposit deprecated vault tokens into a recovery contract.
- That contract will orchestrate enabling the required vault, withdrawing what can
  actually be recovered, and disabling the vault again in the same transaction.
- Do not independently re-enable the vault or treat a rebalance as a repair of
  its stale-reserve-credit vulnerability.

Before implementation, resolve the recovery contract's registry-owner authority.
Both disable setters are owner-only, not operator-authorized. Also account for
the effective disable OR rule: clearing a vault flag does not enable a vault whose
package remains disabled. Temporarily enabling a package affects every vault
registered under it. The recovery design must preserve the final disabled state
on both axes, bound withdrawal amounts/slippage, and account for recovered assets.
No ownership transfer or recovery-contract deployment is part of the present work.

## APEX-2026-010: containment script

Script:
`scripts/foundry/security/Script_DisableRetiredV4Vaults.s.sol:Script_DisableRetiredV4Vaults`.

Fixed network: Robinhood mainnet, chain ID `4663`.
Registry: `0x09682b00D873D913ada0bB69B4D4c9631810d0bc`.

| Action | Target |
| --- | --- |
| Disable package | `0x72b0243E3806eab5E30412cc93682f98f0d20eaE` |
| Disable separate vault | `0x64e0f5A5Cf0F579EFF0981A4fEDEA77964B74531` |
| Ensure existing vault-address disable remains set | `0x999DaE02D22E5FEe1c4508430D5196d31d631009` |

The package covers these five audited vaults:

- `0x201d31a56c58a3489beC218c7A899d59A07A35f0`
- `0xb7D4Bb379D361AD442CddEE53eA71a33957826A7`
- `0x3E33871A8740b294A48347BFFD8A5004E1578c0D`
- `0xabC9C5B5c8118a15A440Ac59a1C74A718E65681C`
- `0x17B5f1045Edf3b6215d0C38eB9FF50649d887D10`

The script validates the chain, current registry owner, and the six newly targeted
vault-to-package registrations before collecting any writes. Already-set flags
are skipped. Normally there are two transactions; a third is collected only if
the previously disabled vault's address flag needs restoring. All writes set
`disabled = true`; there is no enable, upgrade, withdrawal, or asset-transfer call.
The script verifies all seven audited vaults are effectively disabled afterward.

Containment blocks RICH mint/bond and hook buy/sell paths that use these underlying
vaults. It freezes backing rather than migrating it. Disabling only the DETFs is
insufficient because hook purchases can still feed the vulnerable SE.

### Simulation

From the repository root, use the existing `DEPLOYER_ADDRESS` configuration:

```bash
forge script scripts/foundry/security/Script_DisableRetiredV4Vaults.s.sol:Script_DisableRetiredV4Vaults --rpc-url robinhood_mainnet --sender "${DEPLOYER_ADDRESS:?DEPLOYER_ADDRESS must be set}" -vvv
```

This command does not broadcast. The entry point is `run()` with no arguments,
matching the existing launch scripts. The script reuses
`scripts/foundry/anvil_robinhood_main/DeploymentBase.sol`: `_loadConfig()` loads
`DEPLOYER_ADDRESS` (then the existing `SENDER`/`DEV_ADDRESS` fallbacks), and
`_broadcast()` uses `PRIVATE_KEY` when nonzero or parameterless
`vm.startBroadcast()` for the signer selected by Forge. It checks the configured
deployer against the current registry owner and rejects a nonzero private key
whose address differs from that deployer.

### Owner execution

After reviewing the simulation, the owner can execute the same command with
`--broadcast --slow`. With the repo's existing `PRIVATE_KEY` configuration, the
shared base supplies the signing key. If using a wallet imported through
`cast wallet` instead, select that keystore using `--account` or the
`ETH_KEYSTORE_ACCOUNT` environment variable. Importing a wallet does not by itself
select it for Forge, and `--sender` alone does not supply a signing key.

`cast wallet list` on this workstation lists the imported account `deployer`.
Select it explicitly with the following command (`PRIVATE_KEY=0` selects the
keystore rather than an ambient raw key):

```bash
PRIVATE_KEY=0 forge script scripts/foundry/security/Script_DisableRetiredV4Vaults.s.sol:Script_DisableRetiredV4Vaults --rpc-url robinhood_mainnet --sender "${DEPLOYER_ADDRESS:?DEPLOYER_ADDRESS must be set}" --account deployer --broadcast --slow -vvv
```

Signer selection must match `DEPLOYER_ADDRESS`. Do not use
`--skip-simulation`. The writes are separate owner transactions, not an atomic
batch; each independently reduces exposure. Check receipts if interrupted and
rerun to collect only the remaining disables.

After receipts confirm, verify actual RPC state independently:

```bash
forge script \
  scripts/foundry/security/Script_DisableRetiredV4Vaults.s.sol:Script_DisableRetiredV4Vaults \
  --rpc-url robinhood_mainnet --sig "verify()" -vvv
```

`verify()` is read-only and checks both the explicit disable flags and effective
disable state of all seven audited vaults. A successful simulation is not evidence
that live transactions were submitted or confirmed.

### Initial verification evidence (before signer-convention correction)

- Focused build passed:
  `FOUNDRY_PROFILE=fork forge build scripts/foundry/security/Script_DisableRetiredV4Vaults.s.sol test/foundry/fork/scripts/security/DisableRetiredV4Vaults.t.sol`.
- Real deployed-registry fork tests passed: **3 passed, 0 failed, 0 skipped**.
  Command:
  `FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test --test-root test/foundry/fork/scripts/security/DisableRetiredV4Vaults.t.sol -- -vvv`.
  Coverage: all seven effective disables, explicit package/vault flags,
  restoration of the frozen-vault flag, replay without disable events, and
  wrong-chain/wrong-owner rejection. Setup re-enables flags only on the local
  test fork to exercise all three writes; no live state is changed.
- `forge fmt --check` on the new Solidity files and `git diff --check` passed.
- Solidity LSP diagnostics are unavailable in this workspace; solc compilation
  passed. Foundry emits the existing `unknown skip config key in section fmt`
  warning from `foundry.toml`; this work does not change that configuration.
- The full hermetic suite was not run: this change adds an operational script and
  focused fork tests, with no production-contract edits.
- The exact documented owner-command simulation passed against Robinhood mainnet
  RPC state, exit code 0. Forge reported `SIMULATION COMPLETE` and all seven vaults
  effectively disabled in the simulated state. The dry-run artifact contains
  exactly two zero-value calls to the registry: package disable and separate-vault
  disable, both with `true`. The frozen vault already had its address flag set.
  Transaction hashes are null and receipts are empty; nothing was broadcast.
  Artifact:
  `broadcast/Script_DisableRetiredV4Vaults.s.sol/4663/dry-run/run-latest.json`.
  The broader script compilation also reported existing future-keyword,
  shadowing, contract-comparison deprecation, and unreachable-code warnings in
  unrelated sources. Those sources were not changed.

The initial dry-run evidence above did not establish live execution. The
subsequent owner-reported execution and independent block-95,154,306 checks
recorded below supersede that initial pending-broadcast status. This update
does not add transaction receipts or a new live-state check.

### Signer-convention correction

The initial implementation used `run(address)` and
`vm.startBroadcast(address)`, bypassing the shared base's `PRIVATE_KEY` loading.
The owner reported successful simulation followed by
`No associated wallet ... Unlocked wallets: []` during broadcast. That output does
not establish live execution or confirmed disables.

The corrected script now reuses the standard no-argument entry point, config
loader, and broadcaster. One regression test exercises the default broadcaster,
the configured private-key branch, signer mismatch, wrong owner/network, and
idempotent containment. These cases run sequentially within one test because
environment changes are process-global.

- Focused build passed.
- The corrected fork regression passed: **1 passed, 0 failed, 0 skipped**, covering
  all the cases above. The fixture uses Forge's actual default broadcaster and
  transfers registry ownership only on the local fork. No live ownership change
  is performed.
- Formatting and whitespace checks passed. Solidity LSP remains unavailable.
- The no-argument CLI simulation using `DEPLOYER_ADDRESS`, `PRIVATE_KEY=0`, and
  `--sender` passed with exit code 0 and `SIMULATION COMPLETE`. Its artifact
  contains exactly the two expected zero-value registry disable calls from the
  owner, null transaction hashes, and no receipts. All seven audited vaults were
  disabled in simulated state. No keystore was unlocked and nothing was
  broadcast during validation.

## Recovery feasibility investigation

Snapshot: Robinhood mainnet block **95,154,306**. All seven audited vaults were
effectively disabled in the live RPC state. The following state-changing probes
ran only on an isolated local Anvil fork, never on mainnet. No wallet keys were
used. Production contracts and scripts were not changed for this investigation.

### Direct ownership of legacy SE shares

The four vaults with nonzero supply expose Standard Exchange entry points,
including `exchangeIn` and `exchangeOutOneToMany`. Their deployed loupe reports no
ERC-4626 `redeem(uint256,address,address)` or
`withdraw(uint256,address,address)` selector.

Eight local transactions successfully redeemed existing SE shares: each funded
vault was tested independently into each of its two underlying ERC-20 faces.
For each trial:

1. Impersonate an actual on-chain holder only on the local fork, and approve the
   SE to spend that holder's SE shares.
2. Confirm the disabled control reverts `VaultDisabled(address)` (`0x1ba84b43`).
3. Clear the applicable package/address disable on the local fork.
4. Execute
   `exchangeIn(vault, shares, tokenOut, 1, holder, false, deadline)`.
5. Assert a successful transaction receipt, a positive recipient asset balance
   increase, an exact supply decrease equal to the shares supplied, and zero
   remaining shares for that holder.
6. Restore the pre-trial snapshot before testing the alternative output.

The minimum of 1 raw output unit was a diagnostic setting, not a recommended
production recovery limit. These are executable liquidation amounts at the
snapshot, not guarantees of fair value or recovery of original deposits.

| Vault | Existing holder tested | Raw SE shares burned | WETH received (raw wei) | Alternative output received (raw units) |
| --- | --- | --- | --- | --- |
| `0x201d31a56c58a3489beC218c7A899d59A07A35f0` | CP hook `0x1ca1771d04366761a2aEf7Ea26F9e18bC8bb6888` | `1833217760000000000` | `408009737469589` | `442337696918234192` PONS |
| `0xb7D4Bb379D361AD442CddEE53eA71a33957826A7` | CP hook `0x923877336b14662cfb5b3a60b14e7d716d54a888` | `240208335094234316501642770343998622608` | `10737959725810` | `118850873190007404147` DTF |
| `0x3E33871A8740b294A48347BFFD8A5004E1578c0D` | CP hook `0xbbc8d3c8cf1149c36769b4fb0d6d6f8d2d34a888` | `612211913088660205250593830` | `2` | `13872` PONS |
| `0x999DaE02D22E5FEe1c4508430D5196d31d631009` | Weighted hook `0x46E068c2393e189Fbc86632f67210aF253a42Aa8` | `2363429102804833127507538` | `390775976580939035` | `4195929573119770022329756` DTF |

The two output columns are alternative trials from identical initial state;
they cannot both be collected for the same shares. The `0x3E33...` claim is
effectively dust despite the large number of share units.

The other three disabled vaults (`0xabC9...`, `0x17B5...`, `0x64e0...`) had zero
share supply. No existing-holder redemption claim was demonstrated for them.

### This does not establish recovery of hook/DETF/bond positions

Most of the funded SE supply is held by hooks. Impersonating a hook to test the
underlying SE proves what that share holder could redeem if it could issue the
approval/call. It does not give users or a new recovery contract authority to
move shares held inside an immutable hook.

For the real matured bond ID 3 on RICH CP-DETF
`0xc2FBe67c474CE7ce273D31B9B3C1c57915642e28`, a local call by its actual NFT owner
still reverted `TransferFromFailed()` (`0x7939f424`) after the underlying package
was enabled. The hook
`0x25Ef9b3036Ac1faA5090bbFadC68b2EED0f56888` still had zero allowance to the SE
while holding `493973383033351884` SE shares. No artificial allowance was added
for this bond probe.

Therefore, direct legacy SE-share redemption is demonstrated; enabling alone
does not repair 054's existing bond-principal exit. A recovery contract accepting
DETF tokens, hook LP, claim tokens, or bond NFTs still needs a separately proven
way to obtain the underlying SE shares or assets through existing public routes.
An atomic enable/withdraw/disable recovery contract was not implemented or
validated by these direct-share probes.

### Actual EOA balances and the full-supply boundary

Both additional holder addresses below had zero deployed bytecode at the
snapshot; these were actual EOA share balances, not synthetic token funding:

- Holder `0xbab6a03be445094a10695772a79777407dcdc0e7`:
  - `0xb7D4...`: its `2021090200239501983` shares could not pass a minimum of
    1 raw unit on either underlying output; both calls reverted
    `UniswapV4ExchangeIn_SlippageExceeded()` (`0x5a1dcbd5`).
  - `0x3E33...`: its `1744193484583077507836448` shares successfully burned for
    exactly **1 raw PONS unit**. WETH output could not pass the 1-wei minimum.
- Holder `0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`:
  - `0x999D...`: its `869679629029` shares successfully burned for **145370 wei
    WETH**, or alternatively **1560802392611 raw DTF units**, from separate
    identical starting snapshots.

These checks show that a real EOA holding SE shares can use the ordinary
approve-and-exchange path, but tiny claims may be unexecutable or economically
worthless. A positive share balance does not guarantee useful recovery value.

An additional full-supply test used a refreshed fork at block **95,160,993**.
The public non-archive RPC had pruned an uncached slot at the earlier block, so
the new fork was used only for this boundary test:

1. Transfer the owner's existing remaining `0x999D...` shares to the existing
   weighted-hook holder, only on the local fork, so that holder owns exactly
   `2363429102805702807136567` shares: the complete supply.
2. Approve those shares and enable `0x999D...` locally.
3. Burn the complete supply through `exchangeIn(vault, supply, WETH, 1, ...)`.
   The transaction succeeded, paid **390775976581081256 wei WETH**, and left
   `totalSupply == 0`.
4. Execute the registry's address-disable setter with `true` again and assert
   `isDisabled(vault) == true`.

This confirms the 037 SE itself permits a complete-share exit. It still does not
prove that the immutable weighted hook can be instructed to hand over its shares
by a user or migration contract. The test impersonated that existing holder to
isolate the underlying SE's redemption behavior.

All enable, approval, share-transfer, withdrawal, and re-disable transactions
above were localhost-only. The tests did not implement an atomic recovery batch.
Final independent live RPC reads confirmed all seven vaults remain disabled.
The probe WebSocket was closed and the isolated Anvil process was stopped.

## APEX-2026-011: historical V4 FullSpread retirement

This section records the October 23 action against the then-audited source.
The current FullSpread implementation and its independent regression evidence
are recorded in the November 7 section above. Do not read the historical
deletion statements as a claim that the current source tree is absent.

Owner ruling 2026-10-23: do not repair the blocked-mode pricing mismatch. Deprecate
both V4 FullSpread families (hookless and Pons). UpperLowerWings is the comparable
replacement, but this change does not wire Wings into the retired launch stages.

- Sources, vault-specific tests, and launch stage bodies are deleted. Do not restore them.
- Fixture tests that only included a FullSpread SE were retargeted to an UpperLowerWings vault. They were not deleted. The historical `ponsSe` field is that Wings vault. Wings lists only its target token, so custom DETF routes in the staking fixture name the launch token, not WETH. A donate while the pool manager is unlocked cannot price that vault, so that test expects `RateProviderFailed` and no LP credit.
- Robinhood Phase 05 Stage 03 and the FullSpread instance stages were deleted, not left as revert stubs.
- The creation UI no longer selects either FullSpread package.
- V3 FullSpread is outside this ruling.
- APEX-2026-011 was latent at the audit snapshot. This retirement prevents new
  deployments; it does not change existing immutable contracts.
- APEX-2026-012 in UpperLowerWings remains open. Retiring FullSpread does not
  clear that finding.

### Audit results closed by this retirement (historical scope)

Source: `IndexedEx_DiffReview_aca16198-2ba07631.md`. These four results name only
the deleted V4 FullSpread families. None was deployed on Robinhood 4663.

| Finding | Severity | Why this retirement closes it |
| --- | --- | --- |
| APEX-2026-011 | High | Blocked-mode single-sided entry and zap exit lived in both V4 FullSpread families. Both trees are deleted. |
| APEX-2026-041 | Low | The 64-step quote cap and single-step exact-out lived in V4 FullSpread. That code is deleted. |
| APEX-2026-042 | Low | Both V4 FullSpread package `initAccount` paths made the raw `approve` to Permit2. Both packages are deleted. |
| APEX-2026-051 | Info | `AnalyticComposition._certify` lived only in the deleted hookless analytic planner. |

Not closed by this retirement:

- APEX-2026-023 is only partly touched. The V4 hookless maintenance path is gone. The V3 FullSpread path remains, and the executed proofs were on V3. V3 FullSpread stays open, including APEX-2026-022.
- UpperLowerWings findings stay open: APEX-2026-012, 024, 025, 026, and 040.
- Deployed pre-HEAD findings stay open as deployment problems: APEX-2026-010, 036, 037, 038, 039, and 054. Deleting source does not change those immutable contracts.

## APEX-2026-012: apportioned reserve

Owner ruling 2026-10-23: do not repair the live liquidation quote. Replace it.

PRD: `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`.

Later checkpoint, 2026-10-24: the owner rejected the premise that the existing
deposit sells target for the other token, and paused the design while
reconsidering the vault. The draft is not a decision-complete implementation
contract. The recommendation must be accepted or rejected before resuming its
open questions; see `APEX-2026-012-OPEN-QUESTIONS.md`.

- The same rule applies to both the Uniswap V3 and Uniswap V4 Upper Lower Wings SE vaults. One family does not close the other.
- A share is a fraction of every position the vault holds, core and both wings, not a quoted pile of target.
- Both proposed families accept and pay only the target token. The draft's entry-swap sentence is not a settled instruction: the October 24 correction rejected that premise for the existing deposit process. The exact entry/mint design remains open.
- Other token is sold only inside the acting holder's entry or exit. Harvest credits collected target fees and does not sell the other token.
- No V3 Upper Lower Wings source exists. This PRD requires that family to be built. V3 FullSpread stays in place.
- The remaining position taking that sale is intended. Tests must prove share fraction, not a constant target balance.
- `getRate` is the last settled target balance per share. It does not read `slot0` and does not preview the sale.
- This does not upgrade deployed vaults and does not close 024, 025, 026, or 040 by itself.
- Implementation is not authorized.
- Open questions, to be answered one by one: `docs/security/audit/second_review/APEX-2026-012-OPEN-QUESTIONS.md`.

Current-source check, 2026-11-07: no V3 Wings implementation was found in the
V3 source tree or the repository's Wings Solidity filenames. V4
`UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.getRate()` still
uses `Quote.quote(Common.quoteRequest()).value / supply`, not the proposed
settled counter. Passing the completed FullSpread regressions does not
implement this different Wings design.

## Migration design checkpoint - 2026-10-23

Status: **paused for a focused design phase**. This is a record of the discussion,
not a completed design, PRD, or implementation plan. Resume design discussion
before writing those documents or implementing contracts.

### Owner-directed design

- Use two contracts: one for deprecated SE vault migration and one for bond NFT
  migration. Both use ERC-6909 balances to aggregate and track user claims.
- The ERC-6909 token ID is the source contract address cast to `uint256`, using
  `uint256(uint160(sourceAddress))`. This applies to both SE vaults and bond NFT
  collections. Do not introduce a separate per-NFT receipt ID or hash the
  collection and underlying NFT ID into the ERC-6909 ID.
- The address-to-ID conversion needs no lookup mapping. This does not eliminate
  the need for reserve, liability, NFT custody, or processing-state accounting.

SE migration:

- Users approve through Permit2 and call a deposit function specifying the source
  SE vault address and amount.
- The migration contract checks the source address against an approved
  `AddressSet`, pulls the source SE shares, and records the user's claim through
  the corresponding ERC-6909 balance.
- Deposits can be collected while the source vault remains disabled. The earlier
  fork transaction demonstrated a disabled `0x999D...` share transfer; subsequent
  read-only checks confirmed nonzero `transfer()` and `approve()` succeed on all
  four funded disabled vaults. These checks do not grant access to hook-held
  shares.
- The intended processing sequence is to authorize registry access, temporarily
  enable the source, withdraw, optionally deposit the proceeds into another SE
  vault, and restore the disabled state atomically. The owner has not yet
  specified the detailed processing mechanics.

Bond NFT migration:

- Use the bond NFT collection address as the ERC-6909 ID. Deposit and claim
  functions also take the underlying NFT token ID to identify the position.
- ERC-6909 balances represent fungible, principal-denominated compensation claims
  pooled by collection, not ownership receipts for individual deposited NFTs.
- Compensate deposited bonds with liquid DETF tokens. This requires a new DETF
  family designed for the migration scenario; it is not an upgrade of the
  immutable deprecated deployments.
- Preserve the ability to claim legacy bond rewards where supported. The
  existing missing-approval problem still blocks the tested principal exit;
  compensation is a separate issuance mechanism, not recovery of that principal
  through the broken exit.
- A callable rewards function is not evidence of a positive or guaranteed payout
  for every NFT. Reward amounts and eligibility still need verification.

### Open design questions and unaccepted recommendations

The following have been raised but are **not settled owner decisions**:

- The precise bond principal basis: original purchased principal versus eligible
  outstanding/uncompensated principal. The assistant recommended the latter;
  the owner has not yet selected the calculation.
- The compensation ratio, new DETF funding/backing and issuance authority, and
  when migration receipts are exchanged or burned for liquid DETF.
- The exact SE receipt minting and claim formula. One raw deposited source share
  per receipt unit during collection was an assistant recommendation, not an
  approved rule covering every migration stage.
- Receipt transferability and whether each right follows the current receipt
  holder or remains attributed to the original depositor.
- Allocation of NFT-specific legacy rewards, including rewards accrued before
  deposit and any rewards accruing after deposit. Principal-weighted compensation
  balances do not, by themselves, define reward ownership.
- Per-NFT custody and compensation-credit tracking, duplicate-credit prevention,
  accepted bond types and reserved-role NFT eligibility, and whether/when an
  original NFT can be returned without creating another compensation claim.
- Whether SE deposits close before processing or remain open, and how one
  source-address ID can preserve equal rights across partial batches, different
  destination choices, or later deposits. Separate rounds or IDs have not been
  approved.
- Per-source reserve isolation, unsolicited transfers, rounding/dust, fees,
  partial claims, and the effect of removing a source from the deposit allowlist
  on existing claims.
- Permit2 signature/allowance mode, depositor and beneficiary binding, and any
  relayer support. Permit2 was proposed for SE ERC-20 deposits; NFT transfer
  authorization needs its own design.
- Registry authority: the deployed disable setters are owner-only. Ordinary
  operator authorization is insufficient. Resolve a workable authority model
  and preserve both package and address disable flags; package enabling affects
  every vault registered under that package.
- Processing routes, destination validation, deadlines, minimum outputs, failure
  handling, and proof that no vulnerable source is left enabled between
  transactions.

### Resumption boundary

Return to a focused design discussion using this checkpoint and the recovery
evidence above. Agree the accounting, rights, authority, compensation issuance,
and processing model first; then write the PRD and implementation plan. No
migration contract, new DETF family, registry ownership change, deployment, or
live recovery transaction is authorized by this checkpoint.
