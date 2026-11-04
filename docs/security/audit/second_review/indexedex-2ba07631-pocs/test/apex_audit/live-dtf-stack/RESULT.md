# Live-variant analysis: DTF stack, Robinhood mainnet 4663

- **Date:** 2026-10-21. Fork tip about L2 block 94.13M.
- **Test file:** `targets/indexedex-2ba07631/test/apex_audit/live-dtf-stack/LiveDtfStack.t.sol`. 6/6 tests pass. The log is in `run-output.txt` in the same directory.
- **Fork method:** a local Foundry fork of the public RPC at its tip. Reads only; nothing was broadcast.
  - The shared anvil on the audit runner `127.0.0.1:8545` could not be used. It is pinned at block 94071615, and upstream only keeps about 5-8k blocks of state, so every account it has not cached fails with "historical state not available".
  - `setUp` takes the URL from `LIVE_FORK_URL`. The default is the public RPC.
- **Compile workaround:** other agents' directories in the shared slots currently hit stack-too-deep. The runs used `--skip` on `bal-detf-bond-unlock`, `staking-no-killswitch`, `live-cp-hooks`, `p4-*`, `live-old-v4se` and `h2-admin-upgrade`.

## Which source the deployed code matches
- **Provenance:** the deploy manifest `deployments/robinhood_main_fee_accrual` was committed at 799f28e5 (2026-09-13). `git diff 799f28e5 aca16198 -- contracts` is empty, so the baseline worktree `/tmp/sloc/idx-aca` (aca16198) is the deployed source.
- **Loupe check:** the live loupe facets match the fee-accrual package manifest, as recorded in the census.
- **Wiring:**
  - DETF `0x4a5cFDC2`, reserve = weighted hook `0x46E068c2` (60/20/20).
  - Hook token 0: WETH, through the liquidity SE `0x999DaE02` (disabled), with rate provider `0xCae3`.
  - Hook token 1: DETF, a raw leg with no rate provider.
  - Hook token 2: DTF, through the custody SE `0x2E9C1F70`, with rate provider `0xd5D7` (rate 1e18).
  - Mint and bond routes accept DTF and WETH. The burn route accepts DTF only.
- **DETF parameters:** `ownerOnlyLiquidity=true`, `syntheticPrice` 8.04-8.08e18 (the mint gate is open, burn is closed), seigniorage 1%, dexSwapFee 0.03%.
- **Balances at the fork:**
  - Custody: 13.6-14.8M DTF. This was 21.96M at census. A user sold 1075 DETF for 8.34M DTF in tx 0xf3842f…, and later DTF mints added some back.
  - Hook: 7298 DETF.
  - sDTF: 7471 DETF.
  - Custody self-share balance: 0. Hook face-token balances: 0. SY and claimVault self-balances: 0.

## Per-root-cause table
| Root cause (P3 / P2 survivor / P5a / prior) | Present in deployed DTF-stack code? | Live exploitable now? | Evidence |
|---|---|---|---|
| fs-blocked-entry-spot-mint | No: FullSpread is not deployed | n/a | census |
| fs-blocked-exit-sleeve-amgm | No | n/a | census |
| v3fs-blocked-mode-callback-cp | No | n/a | census |
| fs-maintenance-at-spot-jit | No | n/a | census |
| wings-spot-nav / liquidity-depth-jit | No: Wings is not deployed | n/a | census |
| wings-forced-dump-rebalance | No | n/a | |
| wings-quote-step-cap-dos | No | n/a | |
| crane-erc4626facet-mint / staking-erc4626 free mint | No. The custody ERC4626 selectors are the rebasingAware facet 0xDbcE, not the generic Crane facet. totalAssets==balance | n/a | loupe |
| staking-rebalance-requeue-pending | No: no staking SEs | n/a | |
| rawleg-rp-swap / hunt-raw-leg-rp-unconverted-swap-io | No. Pre-HEAD forbids a rate provider on a raw leg. The live DETF raw leg has rp=0 | n/a | `rateProvider(1)=0` |
| rawleg-rp-lp-and-fee / rate-driven-protocol-fee-dilution | No: no quad, orbital, dual or CP hooks in this stack | n/a | |
| hook-midstate-reentrancy | No: Balancer buffer / DUAL only. Weighted swaps are nonReentrant | n/a | |
| balancer-buffer-computebalance-domain / balancer-router-permit-overpull | No | n/a | |
| dual-identity-outleg-zero / orbital-identity-outleg-zero (P5a) | No DUAL or orbital hook. Weighted exits are ownerOnly | n/a | |
| receiptbacked-first-deposit-inflation / b07 usage-fee bypass | No. claimVault 0xAf5C has supply > 0 and is not ReceiptBacked | n/a | |
| hunt-analytic-certify-alias-impact-noop | No | n/a | |
| hunt-twap-retroactive-current-tick | The oracle package exists, but nothing in the DTF stack consumes it | n/a | |
| se-rate-provider-full-book-manipulable | Partially: the hook rates its SE legs with providers. The liquidity-SE rate follows base-pool spot, but WETH-leg swaps revert (VaultDisabled). The custody rate can only be raised by gifting to the hook, which holds 100% | No | test_B |
| **detf-spot-mint-gate** | **Yes.** `UniswapV4DetfCommon._quoteMintGross` prices mints from the spot hook quote, and the gate is open at 8x | **No.** The 3rd-leg dump (P3's lever) needs the WETH leg, which reverts `VaultDisabled(0x999DaE02)`. The same-leg DTF sandwich loses money once the inventory is revalued (worse than control in every case). A full atomic cycle starting with DTF only is never profitable: best PnL ≤ 0 over d ∈ {1000, 2000} DETF, m ∈ {1M, 3M} DTF, k ∈ {0, 1, 3} | test_B, test_C, test_F (REFUTED by execution) |
| detf-bond-spot-valuation | Yes, same code | No. P3 refuted it on weighted 60/20/20, and the WETH bond route reverts. Not re-run on the live fork | P3 detf-bond-spot |
| hunt-detf-entry-no-unlock-gate / hunt-weighted-hook-forces-pons-blocked-mint / hunt-comp-hook-blocked-pons-conduit | The hook and DETF code are present. The SE behind the WETH leg is the old V4 SE (not Pons), and it is disabled | No: reverts | test_B |
| hunt-hook-swap-blocked-sleeve-dos | n/a for the old V4 SE | n/a | |
| **prepaid-credit-refund-sweep (APEX-003)** | **Yes, broader than HEAD.** The baseline `takeShares` refunds `prepaid-amount` to msg.sender on both exact-in and exact-out, and there is no EOA gate | Mechanism confirmed on the live fork. **Current exposure is 0**: the self-share balance is 0, and the hook is the only holder and acts atomically | test_A: a hypothetical victim pretransfers 1M DTF of shares, and the attacker (capital 0) takes 1,000,000 DTF. The LP/hook is untouched |
| protocol-value-as-unbooked-credit | Checked custody (balance == totalAssets), sDTF (2 wei surplus), SY/claimVault (self 0) and bond-NFT `donate(pretransferred)` (only LP, which reverts, and sDTF, which is protected) | No | cast |
| sy-redeem-internalbalance-unattributed | DETFSY is present, and the SY self-balance is 0 | No | cast |
| APEX-001 (liquidity SE 0x999DaE02) | Yes | No: disabled. It reopens on re-enable (census: U=48,199 DTF) | census, test_B |
| APEX-007 weighted-hook dust refund | Yes (`_refundBufferedDust` pays msg.sender) | No: the hook's face balances are 0 (informational) | cast |
| b05 / b06 / b07-v3fs-fake-pool / b02 (P5a) | No | n/a | |

## New, specific to the deployed configuration
**N1 (low; conditional on an admin re-enabling the vault). The frozen WETH leg has drifted far from market. Re-enabling 0x999DaE02 opens an immediate drain of the hook's reserves.**
- **Cause:**
  - DTF-only mints keep joining DTF into the hook's DTF leg, because the gate is open and the WETH route reverts.
  - Nobody can arbitrage the WETH leg while it is frozen.
  - At the fork, the hook valued DETF at about 6093 DTF (about 0.00042 WETH) through the DTF leg, but sold it for WETH at about 0.000148 WETH.
- **What-if test (test_D/test_E):** the owner calls `setVaultAddressDisabled(0x999DaE02,false)` as setup. That is the only privileged step, and it models the owner's own action. An unprivileged contract then loops WETH→DETF (hook) → DTF (hook) → WETH (liquidity SE swap).
  - A single loop of 0.1 WETH returns 0.2006 WETH.
  - 4 loops starting from 0.1 WETH end with 0.2141 WETH. That is **+0.114 WETH net**, with no inventory left over and no LP minted or burned.
- **Hook side:** custody DTF went from 14.83M to 10.46M (-4.37M DTF, about 0.30 WETH), and the hook gained 0.988e24 liquidity-SE shares (about 0.143 WETH at rate 1.4457e-7). The net hook loss is about **0.16 WETH**, paid by the protocol-owned reserve that backs DETF and sDTF.
- **Growth:** the gap widens with every DTF-only mint. Custody grew 1.2M DTF while this analysis was running.
- **Re-enable also reopens APEX-001** on the same vault.
- **Fix:** do not simply re-enable. Either rebalance the WETH leg first (`ownerSwapExactIn`), or migrate the WETH leg off the old V4 SE. Pause DTF-route mints until then.

**N2 (info). Previews disagree with execution while the vault is disabled.**
- `DETF.previewExchangeIn(WETH→DETF)` returns 67.7e9 for 0.01 WETH, and `hook.previewExchangeIn` gives a similar figure.
- Execution reverts with `VaultDisabled`. Integrators and the UI will show quotes that cannot be executed.

## Bottom line
- Of the HEAD-diff root causes, only detf-spot-mint, detf-bond-spot and APEX-003 exist in the deployed DTF-stack code.
- detf-spot-mint and detf-bond-spot are not exploitable live: the kill switch blocks the needed leg, and execution refutes the remaining variants.
- APEX-003 is real in the deployed code, but there is nothing for it to take today.
- The only economically meaningful live finding is N1, and it needs an admin action first (about 0.11 WETH to an attacker, about 0.16 WETH lost from the reserve, growing over time).

## Reviewer note (2026-10-21)
- Re-ran on the audit runner: 6/6 pass, and the numbers reproduce exactly (block 26239815/26239836).
- Added a fair-price victim assertion to test_E. Both the DTF and the liquidity-SE share are valued at pre-attack marginal prices taken from the SE previews.
  - Hook value delta: -0.15628 WETH (asserted < 0).
  - Attacker net: +0.11412 WETH.
- No cheats during the attack. The only privileged step is the owner's re-enable, done in setup. The attacker uses its own 0.1 WETH and ends with WETH only. The hook holds about 100% of the liquidity-SE supply, so the loss falls on the protocol reserve.
