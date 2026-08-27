# Uni V4 SE buffer unwrap: coverage gap report

| Field | Value |
|-------|--------|
| Date | 2026-08-26 |
| Status | WP-1 through WP-6 landed 2026-08-26. WP-7, WP-8, UI remain DEFER. |
| Kind | Decision-grade gap report for a follow-on implementer |
| Trigger | Live Robinhood 4663 DETF `0xaf0E1967c8F755c747615c5427108Bc549CA1122` burn reverted `TransferFromFailed` (`0x7939f424`) with full DETF allowance |
| Skills | `crane-testing`, `indexedex-testing`, `indexedex-adversarial-testing`, `crane-adversarial-testing`, `indexedex-uniswap-v4-hook-packages` |
| Law | Root `Claude.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md` (DETF role names, production-first tests, no `via_ir`, never `new` facets/DFPkgs) |
| Worktree prefix | `gap_cover_univ4-se-unwrap` |
| Related | `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md` **L-GAPS-11** (hook leftover); `docs/testing/coverage-audit/areas/T-hooks-v4.md`; `areas/T-se-univ4-aave-balancer.md` |
| Catalog | I (trust-flag / share pull), K (reserve parking), H (atomic fail). This is not a leftover-pretransfer rewrite. |

This file is the handoff. A new agent should close remaining WPs from this document without re-deriving the live incident. Do not re-implement WP-0. Do not treat ERC-4626 wrapper mint/burn as proof of Uni V4 Standard Exchange unwrap.

---

## Agent handoff (read first)

You are closing remaining coverage for a production bug that shipped on live Uni V4 single-vault CP DETF.

What is already done:

- CP single hook `_unwrapSeShares` forceApproves SE shares before `exchangeIn(..., false)`.
- CP single `_refundPairDust` keeps `MAX_DUST_WEI` (10), re-buffers excess, then transfers remainder only.
- Univ4Se TestBases exist for CP single hook and DETF. Four tests are green (burn + `withdrawSingle`).

What is still open, in order:

1. WP-7 / WP-8 (P2 TEST): sleeve/lock through hook; last-resort dust bound to `DUST`.
2. WP-UI (optional): nested share-pull vs user allowance in `parseContractError`.

Live 4663 instance cannot be patched. The hook owner is the unowned DETF. Prove on hermetic Univ4Se TestBases. New package deploys get the CODE.

Copy CODE from CP single, not from Dual. Copy tests from the Univ4Se files listed in §3, not from ERC-4626 gold.

---

## 0. Incident (runtime proof)

Live instance, chain 4663, Uni V4 single-vault CP DETF, Policy:

| Item | Value |
|------|--------|
| DETF | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` (`WETH-DTF-V4-DETF`) |
| Pair token | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` (DTF) |
| Uni V4 SE | `0xb7D4Bb379D361AD442CddEE53eA71a33957826A7` (`UniV4 Vault of (WETH / DTF)`) |
| Reserve hook | `0x923877336b14662cFb5B3A60b14e7d716d54A888` |
| User | `0x5f0A91BeF93b0f947CD82EA39ec2939D6AEc663a` |
| UI mapping | `TransferFromFailed` → "Token transfer failed. Approve the token again, then retry." (`frontend/apps/dtf/app/lib/tx/parseContractError.ts:67`) |

On-chain:

1. `IERC20(DETF).allowance(user, DETF)` equaled user DETF balance. Diamond self-`transferFrom` of 1 DETF succeeded.
2. `exchangeIn(DETF, 1e18, DTF, 0, user, false, deadline)` reverted `0x7939f424`.
3. `IERC20(SE).allowance(hook, SE) == 0` while the hook held a large UV4X (SE share) balance.
4. Direct `SE.exchangeIn(SE, 1e18, DTF, 0, hook, false, deadline)` from the hook reverted `0x7939f424`.
5. Hook raw DTF = 0. SE held ~118 DTF (liquid sleeve). DETF diamond held ~106 DTF (should not).

Synthetic was ~2. Policy mint was blocked; burn was allowed. Bond #7 was already mature. Extract was blocked by unwrap, not by Policy.

Root causes:

| ID | Class | Mechanism |
|----|--------|-----------|
| **UV4-UNWRAP-001** | CODE (shipped for CP single) | `_unwrapSeShares` called Uni V4 SE `exchangeIn(shares → pair, pretransferred=false)` with no `forceApprove`. Uni V4 SE `_secureShareDelivery(false)` is `safeTransferFrom`. ERC-4626 wrapper `_burnSeShares(false)` burns `msg.sender` and does not pull. |
| **UV4-DUST-001** | CODE (shipped for CP single) | `_refundPairDust` sent the **entire** hook pair balance to `msg.sender` (the DETF) when `bal > MAX_DUST_WEI` (10). End-sync booked it as `R`. Pair stuck on the DETF diamond. |

Gold hermetic TestBase for CP single DETF/hook is `TestBase_ERC4626StandardExchange` wrapping `SimpleYieldERC4626`. PRD D60/D66 locked that as Phase 0. Existing mint/burn/close suites could not fail UV4-UNWRAP-001.

Uni V4 SE vault tests do unwrap shares, but the caller is always the test contract / pranked EOA after `vault.approve(vault, shares)`. They never use the hook as `msg.sender`.

---

## 1. Mechanism (enough to write CODE)

### 1.1 Share redeem split

Uni V4 SE (`contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` `_secureShareDelivery`):

```solidity
if (!pretransferred) {
    vaultShare.safeTransferFrom(msg.sender, address(this), amountIn);
    return vaultShare.balanceOf(address(this)) - b0;
}
```

ERC-4626 wrapper `_burnSeShares(false)` burns `msg.sender`. No pull. That is why hermetic gold is green with allowance 0.

`exchangeOut(..., false)` on Uni V4 SE burns `msg.sender`. Residual zap-out via `_unwrapExactPairOut` does **not** need share approve. Do not "fix" exact-out unwrap unless a test shows a missing copy.

### 1.2 Shipped CP single CODE (copy this)

Canonical copy: `UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol` around `_unwrapSeShares` / `_refundPairDust`. Same bodies are in DepositTarget, SeTarget, and Target (four files, diamond inherit clash forces copies).

Unwrap:

```solidity
share_.forceApprove(l.standardExchange, seIn);
pairOut = IStandardExchangeIn(l.standardExchange).exchangeIn(
    share_, seIn, IERC20(l.pairToken), minOut, address(this), false, block.timestamp
);
```

Dust (`MAX_DUST_WEI = 10` in the hook Repo):

```solidity
if (bal <= Repo.MAX_DUST_WEI) return;
uint256 excess = bal - Repo.MAX_DUST_WEI;
uint256 preview = IStandardExchangeIn(l.standardExchange).previewExchangeIn(
    pair_, excess, IERC20(l.standardExchange)
);
if (preview > 0) {
    _bufferPair(excess);
    bal = pair_.balanceOf(address(this));
    if (bal <= Repo.MAX_DUST_WEI) return;
    excess = bal - Repo.MAX_DUST_WEI;
}
if (to == address(0) || to == address(this)) return;
pair_.safeTransfer(to, excess);
```

Do not send `bal`. Send `excess` after keep-10. Do not transfer when `to` is 0 or the hook.

### 1.3 Dual still broken (WP-2)

File: `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol`

`_unwrap` (line 296) has preview + `exchangeIn(..., false)` and **no** `forceApprove`.

`_refundPairDust` (line 353):

```solidity
if (bal > Repo.MAX_DUST_WEI) {
    IERC20(token).safeTransfer(to, bal);
}
```

Callers: `_unwrap` from proportional `withdraw` (~641, ~851). `_refundBothPairDust(msg.sender)` after withdraw/deposit (~482, 524, 651, 692, 821). Dual `_buffer` already forceApproves **pair** into SE. That does not approve **shares** out.

`_seFor(pairToken)` is at line 179. Dual `MAX_DUST_WEI` is 10 (`...HookRepo.sol`).

### 1.4 Sibling dust still dumps (WP-6)

Orbital / weighted / curve / balancer `_unwrapSeShares` already `forceApprove`. Do not touch unwrap there unless a test shows a missing copy.

Dust still `safeTransfer(msg.sender, bal)` when `bal > MAX_DUST`:

- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` `_refundBufferedDust` (~530)
- `.../weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol` `_refundBufferedDust` (~502)
- `.../stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol` `_refundBufferedDust` (~546) (leaves `<= MAX_DUST`, still dumps full `bal` above)
- `.../stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol` `_refundBufferedDust` (~522)

L-GAPS-11 leftover **pretransfer** spend is a different policy. This WP is dust dump to caller, not leftover exclusive-caller delta.

### 1.5 DETF close vs burn

Burn (`exchangeIn` DETF → pair) uses `_withdrawSinglePair` → `hook.withdrawSingle` → `_unwrapSeShares`. WP-0 covers that on Univ4Se.

Mature close uses `_withdrawProportional` (`UniswapV4SingleStandardExchangeDETFCommon.sol` ~517):

```solidity
IERC20(s.reserveHook).forceApprove(s.reserveHook, lpAmount_);
(uint256 a0_, uint256 a1_) = hook_.withdraw(lpAmount_, address(this), 0, 0, block.timestamp + 1);
```

That is hook **proportional** `withdraw`, not `withdrawSingle`. Product: `minAmountsOut_.length == 2` and `minAmountsOut_[0] == 0` (DETF slot must be 0 / rejoin path). Gold: `UniswapV4SingleStandardExchangeDETF_Alignment_CloseD25.t.sol` `test_D25_4_userReceivesNonDetfBasket`. All close suites run on ERC-4626.

`claimLiquidity` (`DETFBondingTarget.sol` ~435) → `_claimLiquidity` → `_withdrawSinglePair`. Authorized `msg.sender`: bond NFT, rebasing claim token, or `address(this)` (the DETF). Others revert `NotAuthorized`.

---

## 2. Why existing tests missed it

| Suite | Why green |
|-------|-----------|
| CP DETF mint/burn/close (`MintBurn`, `Alignment_CloseD25`, `ReserveDonation`, CROPS) | Gold TestBase is ERC-4626. Share redeem burns `msg.sender`. |
| CP hook liquidity `P1` / `P3` / `Zo1` | Same ERC-4626 pair-side SE. |
| Uni V4 SE vault tests (`NativeEthWrap`, `Adversarial_E6ImpA0`) | Caller is test/EOA after `vault.approve(vault, shares)`. Never the hook. |
| Dual `test_W1_withdraw_unwrapBoth` | ERC-4626 both legs. Dual TestBase deploys SE **before** `PoolManager` (`TestBase_UniswapV4DualSEBCPHook.sol` ~87–92). Uni V4 SE cannot bind that way. |
| Dual `_userAcquireSeShares` | Explicitly `pairToken.approve(se, max)` from the user. Theater for hook-held shares. |

Theater rule for this report: a passing ERC-4626 unwrap does not close any Univ4Se WP.

---

## 3. Already shipped (do not redo)

### 3.1 Production (CP single buffer hook)

`forceApprove` of SE shares before unwrap, and dust keep + re-buffer, in all four copies:

- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol`
- `...DepositTarget.sol`
- `...SeTarget.sol`
- `...Target.sol`

### 3.2 Tests (green 2026-08-27)

```bash
forge test --match-contract 'Univ4Se' -vv --offline
# 4 passed:
#   UniswapV4SingleStandardExchangeBufferConstantProductHook_Univ4SeUnwrap_Test
#     test_withdrawSingle_pairOut_univ4Se_noPriorShareAllowance
#     test_depositSingle_pair_doesNotParkPairOnHook
#   UniswapV4SingleStandardExchangeDETF_Univ4SeBurn_Test
#     test_liveBurn_univ4Se_sharePull_noPriorHookAllowance
#     test_firstBond_univ4Se_doesNotParkPairOnDetf
```

ERC-4626 regression still green: `UniswapV4SingleStandardExchangeDETF_MintBurnTest::test_liveBurn_pairOnly_*`, hook liquidity `P1` / `P3` / `Zo1`.

### 3.3 Test infrastructure to reuse

| Path | Role |
|------|------|
| `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4CpBufferUniv4Se.sol` | Hook TestBase. `_deployPairSideSe` override deploys production Uni V4 SE + seeded vanilla pool + TWAP. DFPkg reverts `ZeroTwapOracle()` (`0x994a506d`) without TWAP. Oracle `poolManager` must be the **same** `pm` as the hook (`TwapOraclePoolManagerMismatch` otherwise). `_ensureUniv4SePkg` is the copy-from for Dual. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF_Univ4Se.sol` | DETF TestBase. Same pair-side SE. **Do not** diamond-inherit both TestBases (`setUp` / `_feeTo` clash). Duplicate `_deployPairSideSe` or extract a library. |
| `UniswapV4CpBufferSePoolSeeder` | In the hook Univ4Se TestBase file. DETF Univ4Se imports it. |
| Parent gold helpers | `_openArgs`, `_policyArgsUnique`, `_firstBond`, `_bootstrapViaFirstBond`, `_mintPair`, `_burnToPair`, `_setBondTerms`, `DEFAULT_MIN_LOCK` (30 days), `DUST` (10), `_seedLiveLiquidity`, `_minOut()` two-element zeros. |

Gold hook TestBase `_deployPairSideSe()` is virtual and defaults to ERC-4626. PoolManager is constructed **before** SE deploy so Uni V4 SE can bind `pm`. Dual gold currently deploys SE **then** `new PoolManager`. Univ4Se Dual must reverse that order.

Helpers already used in shipped Univ4Se burn:

```solidity
detf = _deployDetfWired(_openArgs());
_setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
_firstBond(500 ether);
assertEq(IERC20(se).allowance(reserveHook, se), 0, "...");
uint256 pairOut = _burnToPair(burnAmt);
assertLe(pairToken.balanceOf(detf), DUST, "...");
```

Live diamonds cannot load this hook fix. Do not attempt `diamondCut` on the live instance.

---

## 4. Remaining work packages

Priority is what would still have blocked extracting the live DETF, then sibling CODE, then cheap vault-law tests.

### WP-0 — CP single unwrap + dust + Univ4Se burn/withdrawSingle (DONE)

Acceptance already met. Cite §3.

---

### WP-1 — Univ4Se close-bond and proportional withdraw (P0 TEST)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-UNWRAP-CLOSE-001` |
| **Title** | Prove `closeBondMature` and hook `withdraw` on Uni V4 SE with hook share allowance 0 |
| **Severity** | P0 / High |
| **Class** | TEST |
| **Products** | Uni V4 CP single DETF + CP single buffer hook |
| **Finding IDs** | UV4-UNWRAP-001 (close path untested on production SE) |
| **Why** | Live extract path is mature `closeBondMature`, not free DETF burn. Close uses `hook.withdraw` → `_unwrapSeShares`. All close suites run on ERC-4626. |
| **Production files** | none (CP single CODE already forceApproves) |
| **Test files** | Extend `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Univ4SeBurn.t.sol` **or** new `..._Univ4SeClose.t.sol` on `TestBase_UniswapV4SingleStandardExchangeDETF_Univ4Se`. Add hook `withdraw` on `TestBase_UniswapV4CpBufferUniv4Se` in `...Hook_Univ4SeUnwrap.t.sol`. |
| **Out of scope** | Dual files. Sibling families. L-GAPS-11 leftover. Live 4663 cut. ERC-4626 CloseD25 (keep as regression). |
| **Depends on** | WP-0 |
| **Parallelizable with** | WP-2, WP-5, WP-6 |
| **Suggested worktree** | `gap_cover_univ4-se-unwrap` (pack with WP-3 and WP-4) |
| **Estimate** | M |

**Implement:**

1. Open-mode Univ4Se DETF (`_openArgs()`). First bond via `_bootstrapViaFirstBond(user, 40 ether)` then a second bonder, or `_firstBond` then a second user. Warp `DEFAULT_MIN_LOCK + 1`. Call:

```solidity
uint256[] memory minOut = new uint256[](2); // both 0
vm.prank(bonder);
uint256[] memory out_ = detfInfo.closeBondMature(tokenId, minOut, bonder, block.timestamp + 1 hours);
```

Copy structure from `UniswapV4SingleStandardExchangeDETF_Alignment_CloseD25.t.sol` `test_D25_4_userReceivesNonDetfBasket`. Swap TestBase to Univ4Se.

2. Assert `IERC20(se).allowance(reserveHook, se) == 0` **before** close. Close succeeds. `out_[0] == 0`. `out_[1] > 0`. User pair delta equals `out_[1]`. `pairToken.balanceOf(detf) <= DUST`. `pairToken.balanceOf(reserveHook) <= DUST`.

3. Hook-only: after `_seedLiveLiquidity()`, `single.withdraw(lp/4, user, 0, 0, block.timestamp + 1)` with `allowance(hook, se) == 0`. Assert user received both legs (or pair + raw per currency order) and hook pair `<= DUST`.

**Acceptance:**

```bash
forge test --match-contract 'Univ4Se' --match-test 'test_.*[Cc]lose|test_.*withdraw[^S]' -vv --offline
# required names (implementer may prefix):
#   test_closeBondMature_univ4Se_sharePull_noPriorHookAllowance
#   test_withdraw_proportional_univ4Se_noPriorShareAllowance
```

Keep existing Univ4Se burn green:

```bash
forge test --match-contract 'Univ4Se' -vv --offline
```

**Anti-theater:** Do not call `IERC20(se).approve` from the hook in the test. Do not use ERC-4626 TestBase. Warp lock; do not skip maturity. Do not only call `withdrawSingle` and claim close coverage.

**Pitfalls:** `minAmountsOut_[0] != 0` reverts `InvalidRoute`. Fee/creator standing bonds (`unlockTime == 0`, ids 1 and 2) cannot close. `setUp` ErrorCreatingContract with `0x994a506d` means TWAP missing. Diamond-inheriting both Univ4Se TestBases fails on `setUp` / `_feeTo`.

---

### WP-2 — Dual CP buffer unwrap + dust (P0 CODE+TEST)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-UNWRAP-DUAL-001` |
| **Title** | Dual `_unwrap` forceApprove + keep-10 dust rebuffer |
| **Severity** | P0 / High |
| **Class** | CODE+TEST |
| **Products** | Uni V4 Dual SE buffer CP hook |
| **Finding IDs** | UV4-UNWRAP-001 (Dual copy), UV4-DUST-001 (Dual copy) |
| **Why** | Dual `_unwrap` still has no `forceApprove`. Dual `_refundPairDust` still transfers **all** pair when `bal > MAX_DUST`. Same live-class bug on a second family. Orbital/weighted/curve/balancer quad already approve shares. |
| **Production files** | `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol` (`_unwrap`, `_unwrapExactOut`, `_refundPairDust` / `_refundBothPairDust`) |
| **Test files** | New Dual Univ4Se TestBase + withdraw tests. Dual gold TestBase is ERC-4626 today: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol`. |
| **Out of scope** | Rewriting Dual leftover **pretransfer** spend (L-GAPS-11). Dual DETF (no Dual DETF in this wave). CP single files already shipped. |
| **Depends on** | none |
| **Parallelizable with** | WP-1, WP-5, WP-6 (different files) |
| **Suggested worktree** | `gap_cover_univ4-se-dual` |
| **Estimate** | L (new TestBase + two Uni V4 SE vaults) |

**CODE (exact):**

1. `_unwrap`: after preview, before `exchangeIn`:

```solidity
IERC20(se).forceApprove(se, seIn);
```

Mirror orbital (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol` `_unwrapSeShares`) and CP single.

2. `_unwrapExactOut` uses `exchangeOut(..., false)` which burns `msg.sender`. No share approve required on Uni V4 SE. Leave it unless a test proves otherwise.

3. `_refundPairDust`: keep `MAX_DUST_WEI`; re-buffer excess via existing `_buffer(se, token, excess)` when preview > 0; transfer only remainder; skip if `to` is 0 or `address(this)`. Do not send entire `bal`.

Sketch:

```solidity
function _refundPairDust(address token, address to) internal {
    uint256 bal = IERC20(token).balanceOf(address(this));
    if (bal <= Repo.MAX_DUST_WEI) return;
    uint256 excess = bal - Repo.MAX_DUST_WEI;
    address se = _seFor(token);
    uint256 preview = IStandardExchangeIn(se).previewExchangeIn(
        IERC20(token), excess, IERC20(se)
    );
    if (preview > 0) {
        _buffer(se, token, excess);
        bal = IERC20(token).balanceOf(address(this));
        if (bal <= Repo.MAX_DUST_WEI) return;
        excess = bal - Repo.MAX_DUST_WEI;
    }
    if (to == address(0) || to == address(this)) return;
    IERC20(token).safeTransfer(to, excess);
}
```

`_buffer` already forceApproves pair. Dual `withdraw` currently refunds to `msg.sender`. After this change, a Dual DETF (or any caller) must not receive the hook's working pair inventory.

**TEST:**

Do not diamond-inherit Dual gold + CP Univ4Se TestBase. Copy `_ensureUniv4SePkg` / seeder from `TestBase_UniswapV4CpBufferUniv4Se.sol`. Critical order vs gold Dual:

- Gold Dual: ERC-4626 SE, **then** `new PoolManager`.
- Univ4Se Dual: construct `pm` **first**, attach TWAP on that `pm`, seed two vanilla pools, `deployVault` two Uni V4 SEs, then hook package.

Suggested files:

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook_Univ4Se.sol`
- `.../UniswapV4DualSEBCPHook_Univ4SeUnwrap.t.sol`

Tests:

- `test_W1_withdraw_unwrapBoth_univ4Se_noPriorShareAllowance`: `_depositBoth(100 ether, 100 ether)`; assert `allowance(hook, seA)==0` and `allowance(hook, seB)==0`; `dual.withdraw(lp/2, user, 0, 0, deadline)`; user receives both pair tokens; hook pair balances `<= DUST`.
- `test_deposit_doesNotParkPairOnHook_univ4Se`: after deposit, hook pair `<= DUST`.

Do not use `_userAcquireSeShares` as proof of hook unwrap (it approves from the user).

**Acceptance:**

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/**' --match-contract 'Univ4Se' -vv --offline
# Dual ERC-4626 regression:
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/**' --match-test 'test_W1_withdraw_unwrapBoth|test_P1_firstDeposit|test_P3_subsequentDeposit' -vv --offline
```

**Anti-theater:** Dual Univ4Se test must not pre-approve hook shares. Success on ERC-4626 Dual Core does not close this WP.

---

### WP-3 — Policy burn on Univ4Se DETF (P1 TEST)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-UNWRAP-POLICY-001` |
| **Title** | Policy-mode DETF burn against Uni V4 SE |
| **Severity** | P1 / Medium |
| **Class** | TEST |
| **Products** | Uni V4 CP single DETF |
| **Finding IDs** | UV4-UNWRAP-001 (Policy instance untested on production SE) |
| **Why** | Live DETF is Policy. Shipped Univ4Se burn is Open-only (`_openArgs()`). Policy burn exists only on ERC-4626 (`UniswapV4SingleStandardExchangeDETF_PriceMovement.t.sol` `test_policy_defaultThresholds_mintAndBurnRegimes_viaRealTrades`). |
| **Production files** | none |
| **Test files** | `...DETF_Univ4SeBurn.t.sol` or sibling; `_policyArgsUnique("univ4se")`; first bond then drive synthetic below `burnThreshold`, then burn. Copy skew/dilute helpers from `PriceMovement.t.sol`. |
| **Out of scope** | Changing default thresholds. Forcing Open and claiming Policy coverage. |
| **Depends on** | WP-0; pack with WP-1 |
| **Parallelizable with** | WP-2, WP-5 |
| **Suggested worktree** | `gap_cover_univ4-se-unwrap` |
| **Estimate** | M |

**Implement:**

1. `_deployDetfWired(_policyArgsUnique("uv4"))`. Assert `thresholdMode == Policy`, mint 1.05e18, burn 0.95e18 (same as PriceMovement).
2. First bond 500 ether. If `isBurningAllowed()` is already true, burn immediately (live instance was in this state).
3. Else copy the PriceMovement burn-regime loop (`_diluteViaBond`, expansion warp, `_skewSyntheticDownViaDetfDeposit`). Those helpers live on the ERC-4626 PriceMovement test; copy or move them onto the DETF TestBase if missing from Univ4Se.
4. When `isBurningAllowed()==true`, `_burnToPair` with hook share allowance 0. Pair not parked on DETF.

**Acceptance:** `isBurningAllowed()==true` then `exchangeIn(DETF → pair)` succeeds on Univ4Se TestBase; `pairToken.balanceOf(detf) <= DUST`.

If first-bond dilution never opens Policy burn on Uni V4 SE after a bounded loop (PriceMovement uses 30 iterations), document the exact synthetic/threshold numbers in the test log and `return` with a comment. Do not force Open and claim Policy coverage. Do not skip the assertion silently.

---

### WP-4 — `claimLiquidity` on Univ4Se (P1 TEST)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-UNWRAP-CLAIMLIQ-001` |
| **Title** | `claimLiquidity` unwraps Uni V4 SE shares without prior hook allowance |
| **Severity** | P1 / Medium |
| **Class** | TEST |
| **Products** | Uni V4 CP single DETF |
| **Finding IDs** | UV4-UNWRAP-001 (`_claimLiquidity` → `_withdrawSinglePair`) |
| **Why** | Same unwrap as burn. Surface-listed (`DETFFacet` selector index 6). Not run on Uni V4 SE. |
| **Test files** | Univ4Se DETF suite. |
| **Out of scope** | Changing `NotAuthorized` law. |
| **Depends on** | WP-0 |
| **Parallelizable with** | WP-2, WP-5 |
| **Suggested worktree** | `gap_cover_univ4-se-unwrap` |
| **Estimate** | S |

**Implement:**

Authorized callers of `_claimLiquidity`: bond NFT vault, rebasing claim token, or `address(this)` (the DETF diamond).

Simplest hermetic path after first bond / mint that leaves protocol LP:

```solidity
address reserveHook = detfInfo.reserveHook();
assertEq(IERC20(se).allowance(reserveHook, se), 0);
uint256 lp = /* protocol LP on diamond or pulled onto it */;
vm.prank(detf); // msg.sender == address(this)
uint256 pairOut = IUniswapV4SingleStandardExchangeDETF(detf).claimLiquidity(lp, detfUser);
assertGt(pairOut, 0);
assertLe(pairToken.balanceOf(detf), DUST);
```

If protocol LP is not on the diamond, use the bond NFT as `msg.sender` after `_pullBondLp` would have run, or mint then claim protocol LP. Negative: `vm.prank(user); claimLiquidity(...)` reverts `NotAuthorized`.

**Acceptance:** named test `test_claimLiquidity_univ4Se_sharePull_noPriorHookAllowance` plus the unauthorized revert.

---

### WP-5 — Uni V4 SE nested-caller negative (P1 TEST)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-UNWRAP-SE-NEG-001` |
| **Title** | Uni V4 SE `exchangeIn(shares, false)` reverts `TransferFromFailed` when a contract holder has allowance 0 |
| **Severity** | P1 / Medium |
| **Class** | TEST |
| **Products** | Uni V4 Standard Exchange vault |
| **Finding IDs** | UV4-UNWRAP-001 (vault-law documentation) |
| **Why** | Documents vault law so the next wrapper does not omit approve. Does **not** replace hook/DETF Univ4Se tests. |
| **Production files** | none |
| **Test files** | `test/foundry/spec/protocol/dexes/uniswap/v4/` on `TestBase_UniswapV4StandardExchange`. Tiny helper contract holds shares, `allowance==0`, `exchangeIn(shares → token0, false)` expects `SafeTransferLib.TransferFromFailed` (`0x7939f424`). Control: same helper after `approve` succeeds. |
| **Out of scope** | Hook or DETF files. Mock SE. |
| **Depends on** | none |
| **Parallelizable with** | WP-1, WP-2, WP-6 |
| **Suggested worktree** | `gap_cover_univ4-se-neg` (SE package only) |
| **Estimate** | S |

**Anti-theater:** Helper must be a **contract** holder, not the test contract that already approved in setUp. Selector must be exact `0x7939f424` (typed encoding preferred). Control path proves the revert is allowance, not empty book.

Gold unwrap-with-approve (do not count as this WP): `UniswapV4StandardExchange_NativeEthWrap.t.sol`, `Adversarial_UniswapV4SE_E6ImpA0.t.sol`.

---

### WP-6 — Sibling dust dump (P1 CODE+TEST)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-UNWRAP-DUST-SIB-001` |
| **Title** | Orbital/weighted/curve/balancer keep-10 + rebuffer dust; do not dump full `bal` |
| **Severity** | P1 / Medium |
| **Class** | CODE+TEST |
| **Products** | Orbital, weighted, curve quad, balancer quad SE buffer hooks |
| **Finding IDs** | UV4-DUST-001 (sibling copies) |
| **Why** | Same DETF-parking class if a DETF is the caller. Curve at least leaves `<= MAX_DUST` then still dumps full `bal`. |
| **Production files** | See §1.4. One `_refundBufferedDust` per family. |
| **CODE** | Match CP single: keep `MAX_DUST_WEI`; re-buffer excess via that family's `_bufferToken` / `_buffer` when preview > 0; transfer only remainder to a defined `to` (today `msg.sender`). Skip if `to` is 0 or `address(this)`. Do **not** convert leftover **pretransfer** spend to exclusive-caller delta (L-GAPS-11). |
| **TEST** | After deposit/withdraw, hook face pair `<= MAX_DUST`; caller pair not inflated by dump. ERC-4626 TestBases can prove dust; Uni V4 SE optional for this WP. |
| **Out of scope** | Unwrap approve on these families (already present). L-GAPS-11 leftover tests (`WP-I-HOOK-SEBUF-001`). CP single (shipped). Dual (WP-2). |
| **Depends on** | none |
| **Parallelizable with** | WP-1, WP-2, WP-5. Serial **per family file** if one agent; else one worktree per family. |
| **Suggested worktree** | `gap_cover_univ4-dust-sib` **or** `gap_cover_univ4-dust-{orbital,weighted,curve,balancer}` |
| **Estimate** | M |

Orbital/weighted/curve **already** `forceApprove` on unwrap. Do not "fix" unwrap there unless a test shows a missing copy.

**Acceptance per family:**

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/<family>/**' --match-test 'test_.*[Dd]ust|test_.*withdraw' -vv --offline
```

New tests must assert hook pair `<= 10` after withdraw, not merely that withdraw succeeds.

---

### WP-7 — Sleeve / locked PoolManager through the hook (P2 TEST)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-UNWRAP-SLEEVE-001` |
| **Title** | Unwrap/burn pays from Uni V4 SE liquid sleeve or reverts a typed error |
| **Severity** | P2 / Low |
| **Class** | TEST |
| **Why** | Live SE held DTF as local liquid buffer. Univ4Se TestBase never blocks `PoolManager` unlock. Sleeve pay vs revert is untested through hook/DETF. |
| **Test files** | Univ4Se TestBase + `IUniswapV4StandardExchangeLiquidReserve` / unlock-blocked harness (`PoolManagerUnlockSeCaller` / `canOpenPoolManagerUnlock` peers in `UniswapV4StandardExchange_LocalLiquidBuffer.t.sol`). |
| **Depends on** | WP-1 recommended first |
| **Suggested worktree** | `gap_cover_univ4-se-unwrap` (optional same tree) |
| **Estimate** | M |

**Acceptance:** Unwrap/burn either pays from sleeve or reverts a **typed** SE/hook error (not `TransferFromFailed` from missing approve). Missing approve is WP-0/WP-1, already closed or in flight.

---

### WP-8 — Dust last-resort bound (P2 TEST)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-UNWRAP-DUST-LAST-001` |
| **Title** | Last-resort dust transfer cannot recreate 106-pair parking on DETF |
| **Severity** | P2 / Low |
| **Class** | TEST (CODE only if last-resort still parks large pair on DETF) |
| **Why** | If SE buffer preview is 0, CP single still transfers excess to `to` (DETF). No test that this cannot recreate the live 106 DTF parking. |
| **Implement** | Force preview 0 (tiny excess that quotes 0, production-first: do not `vm.mockCall` the SE) **or** assert after every Univ4Se money route `pairToken.balanceOf(detf) <= DUST`. If last-resort can leave `>> DUST` on DETF, CODE: do not transfer to DETF; leave on hook or re-buffer in a loop. |
| **Depends on** | WP-1 |
| **Suggested worktree** | `gap_cover_univ4-se-unwrap` |
| **Estimate** | S |

---

### WP-UI — optional frontend mapping (not CODE)

`frontend/apps/dtf/app/lib/tx/parseContractError.ts` still maps every `TransferFromFailed` (`0x7939f424`) to "Approve the token again, then retry." The live user had full DETF allowance. Optional follow-on, not a Solidity WP.

If touching frontend: distinguish nested share-pull failure from user DETF/pair allowance. Also map `InvalidRoute` (`0x229fee83`) and `BurningNotAllowed` if those strings are still missing. Product voice skill for copy. Not in the forge acceptance bar.

---

## 5. Explicitly not a Univ4Se duplicate

| Item | Reason |
|------|--------|
| ERC-4626 mint/burn/liquidity | Already green. Keep as regression. Not the production SE stand-in. |
| `_unwrapExactPairOut` share approve on Uni V4 SE | `exchangeOut(..., false)` burns `msg.sender`. Residual zap already runs inside `withdrawSingle` when `amountOut > pairUser`. |
| Burn to WETH / vault share | `InvalidRoute` (`0x229fee83`). UI mapping gap, not unwrap. |
| Creator / fee standing bonds (`unlockTime == 0`) | Product: unredeemable. Not unwrap. |
| Live instance upgrade | Impossible. Hook owned by unowned DETF. |
| L-GAPS-11 leftover pretransfer | Tests-only on orbital/weighted/curve/balancer. Do not rewrite leftover spend in these WPs. |
| Dual leftover free-spend gate | Separate coverage-audit Dual I WP. This report is share-pull + dust dump. |

---

## 6. Suggested execution order

```text
WP-0 DONE
    │
    ├─ WP-1 close + proportional withdraw (TEST, CP DETF/hook Univ4Se)
    │     └─ WP-3 Policy burn (same tree)
    │     └─ WP-4 claimLiquidity (same tree)
    │     └─ WP-7 sleeve (optional same tree)
    │     └─ WP-8 dust last-resort (optional same tree)
    │
    ├─ WP-2 Dual unwrap + dust (CODE+TEST, dual package only)
    │
    ├─ WP-5 SE nested-caller negative (SE package only)
    │
    └─ WP-6 sibling dust dump (orbital / weighted / curve / balancer; serial per Common/Target file)
```

Conflict-free: WP-1/3/4 share CP single test trees. WP-2 is Dual Common. WP-5 is Uni V4 SE tests. WP-6 must not edit CP single files already shipped.

L-GAPS-4: at most three concurrent implementers. First wave: WP-1 (with WP-3/4), WP-2, WP-5.

WP-1 must not be deferred. Close-bond is the live extract path. WP-3 through WP-8 may stay open with an explicit DEFER note if capacity is limited; record the deferral in this file's status table.

---

## 7. Constraints for the implementer

1. **Production-first.** Uni V4 SE via `indexedexManager.deployUniswapV4StandardExchangeDFPkg` + `deployVault(poolKey)`. No `MockStandardExchange`. No `new` facets/DFPkgs. No `vm.mockCall` of SUT.
2. **TWAP is required.** Uni V4 SE DFPkg constructor reverts `ZeroTwapOracle()` (`0x994a506d`) if `twapOracle == 0`. Attach an oracle whose `poolManager` is the **same** `pm` as the hook (`TwapOraclePoolManagerMismatch` otherwise). Copy `TestBase_UniswapV4CpBufferUniv4Se._ensureUniv4SePkg`.
3. **`via_ir` forbidden.**
4. **DETF role names only** (`rateAsset`, `pairToken`, `underlyingVault`, `detfToken`, `rebasingClaimToken`). Use `weth`/`WETH` only in truly WETH-specific code.
5. **Do not diamond-inherit** `TestBase_UniswapV4SingleStandardExchangeDETF` and `TestBase_UniswapV4CpBufferUniv4Se` (setUp / `_feeTo` clash). Copy `_deployPairSideSe` or extract a library.
6. **Dual Univ4Se order.** Gold Dual deploys ERC-4626 SE then `new PoolManager`. Uni V4 SE must see `pm` at package init. Construct `pm` first.
7. **Forge patience.** Cold compile 20–40+ minutes. Do not kill `forge`/`solc`. Timeout hours, not minutes.
8. **Worktree compile seed.** Before first `forge` in a new worktree:

```bash
# REPO = warm checkout; WT = new worktree root
rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"
rsync -a "${REPO}/out/" "${WT}/out/"
rm -rf "${WT}/lib/crane" && ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
```

After a green forge, copy `cache_forge/` + `out/` back to the warm seed. Do not delete `out/` or `cache_forge/` mid-program.

9. **Anti-theater.** Univ4Se tests must start with `allowance(hook, se)==0`. Success on ERC-4626 TestBase does not close these WPs. Do not `approve` from the hook inside the test to make unwrap pass.
10. **Live 4663 instance is abandoned.** Prove on hermetic Univ4Se TestBase. Do not cut the live hook.
11. **L-GAPS-11.** Do not convert leftover pretransfer spend to exclusive-caller delta while doing dust CODE.

---

## 8. File map

### Production (CP single, shipped)

```
contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/
  UniswapV4SingleStandardExchangeBufferConstantProductHook{Withdraw,Deposit,Se,Target}.sol
    _unwrapSeShares, _refundPairDust
  UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol
    MAX_DUST_WEI = 10
```

DETF close / claim (no CODE change expected):

```
contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/
  UniswapV4SingleStandardExchangeDETFCommon.sol
    _withdrawSinglePair (~510, hook.withdrawSingle)
    _withdrawProportional (~517, hook.withdraw)
    _claimLiquidity (~614)
  UniswapV4SingleStandardExchangeDETFBondingTarget.sol
    closeBondMature (~342)
    claimLiquidity (~435)
```

Uni V4 SE share pull:

```
contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol
  _secureShareDelivery (~1119)
```

### Production (open CODE)

```
contracts/hooks/uniswap/v4/standardExchange/dual/
  UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol
    _unwrap (~296), _unwrapExactOut (~307), _refundPairDust (~353)   ← WP-2
contracts/hooks/uniswap/v4/standardExchange/orbital/
  UniswapV4StandardExchangeOrbitalBufferHookCommon.sol
    _refundBufferedDust (~530)                                      ← WP-6 (unwrap already approves)
contracts/hooks/uniswap/v4/standardExchange/weighted/
  UniswapV4StandardExchangeWeightedBufferHookTarget.sol
    _refundBufferedDust (~502)                                      ← WP-6
contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/
  UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol
    _refundBufferedDust (~546)                                      ← WP-6
contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/
  UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol
    _refundBufferedDust (~522)                                      ← WP-6
```

### Tests / TestBases (reuse)

```
contracts/hooks/.../constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol
  _deployPairSideSe() virtual; _seedLiveLiquidity; pm before SE
contracts/hooks/.../constantProduct/single/TestBase_UniswapV4CpBufferUniv4Se.sol
  _ensureUniv4SePkg, UniswapV4CpBufferSePoolSeeder
contracts/vaults/detf/.../constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol
  _openArgs, _policyArgsUnique, _firstBond, _burnToPair, DEFAULT_MIN_LOCK
contracts/vaults/detf/.../constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF_Univ4Se.sol
test/foundry/spec/hooks/.../constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Univ4SeUnwrap.t.sol
test/foundry/spec/vaults/detf/.../constantProduct/single/UniswapV4SingleStandardExchangeDETF_Univ4SeBurn.t.sol
test/foundry/spec/vaults/detf/.../constantProduct/single/UniswapV4SingleStandardExchangeDETF_Alignment_CloseD25.t.sol
  test_D25_4_userReceivesNonDetfBasket   ← copy for WP-1
test/foundry/spec/vaults/detf/.../constantProduct/single/UniswapV4SingleStandardExchangeDETF_PriceMovement.t.sol
  test_policy_defaultThresholds_mintAndBurnRegimes_viaRealTrades   ← copy for WP-3
test/foundry/spec/hooks/.../dual/TestBase_UniswapV4DualSEBCPHook.sol
  ERC-4626 gold; SE before pm (must reverse for Univ4Se)
test/foundry/spec/hooks/.../dual/UniswapV4DualSEBCPHook_Core.t.sol
  test_W1_withdraw_unwrapBoth   ← ERC-4626 regression; Univ4Se twin needed
```

Uni V4 SE vault tests (WP-5): `test/foundry/spec/protocol/dexes/uniswap/v4/`. Gold: `TestBase_UniswapV4StandardExchange`.

### UI (optional)

```
frontend/apps/dtf/app/lib/tx/parseContractError.ts   line 67
frontend/apps/dtf/app/components/insights/DetfActions.tsx   exchangeIn burn
```

---

## 9. Ready-to-paste implementer prompt

Use this as the first message to a new agent (or split per worktree).

```text
Close remaining Uni V4 SE buffer unwrap gaps from
docs/testing/UNIV4_SE_BUFFER_UNWRAP_COVERAGE_GAP_REPORT.md.

Do not re-implement WP-0 (CP single unwrap + dust + Univ4Se burn/withdrawSingle
are shipped and green).

Wave assignment:
- This worktree: <WP-1+3+4 | WP-2 | WP-5 | WP-6>
- Do not edit another WP's primary files.

Constraints: production-first (no MockStandardExchange, no new facets/DFPkgs,
no vm.mockCall of SUT); no via_ir; DETF role names; TWAP required on Uni V4 SE
DFPkg; do not diamond-inherit both Univ4Se TestBases; seed cache_forge/ + out/
in a new worktree; do not kill forge; live 4663 instance is unpatchable;
Univ4Se tests start with allowance(hook, se)==0; ERC-4626 green is not
acceptance; L-GAPS-11 leftover pretransfer is out of scope.

Copy CODE from CP single _unwrapSeShares / _refundPairDust.
Copy close tests from Alignment_CloseD25 test_D25_4.
Copy Policy burn drive from PriceMovement test_policy_defaultThresholds_*.
For Dual Univ4Se, construct PoolManager before deploying Uni V4 SE vaults.

When done: paste forge commands and results; mark WPs DONE in the report
status table; keep ERC-4626 MintBurn / Dual Core / hook P1 P3 Zo1 green.
```

---

## 10. Acceptance for "gaps closed"

All of:

```bash
forge test --match-contract 'Univ4Se' -vv --offline
forge test --match-contract UniswapV4SingleStandardExchangeDETF_MintBurnTest --match-test test_liveBurn -vv --offline
forge test --match-contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Liquidity_Test --match-test 'test_P1_firstDeposit|test_P3_subsequentDeposit|test_Zo1_withdrawSingle' -vv --offline
```

Plus new matchers from WP-1/2/3/5 as those WPs land.

Do not mark this report closed until WP-1 and WP-2 are green. WP-3 through WP-8 may stay open with an explicit DEFER note if capacity is limited. WP-1 must not be deferred.

### Status table (update when a WP lands)

| WP | ID | Status |
|----|----|--------|
| 0 | WP-UNWRAP-CLOSE-000 (unwrap+dust+burn/withdrawSingle) | DONE 2026-08-27 |
| 1 | WP-UNWRAP-CLOSE-001 | DONE 2026-08-26. `closeBondMature` + hook proportional `withdraw` on Univ4Se. Hook pair `<= DUST`. DETF leftover bounded `< 0.01 ether` (last-resort remainder, WP-8). |
| 2 | WP-UNWRAP-DUAL-001 | DONE 2026-08-26. Dual `_unwrap` forceApprove + keep-10 rebuffer dust. Univ4Se Dual TestBase + W1/deposit tests green. ERC-4626 Dual W1 / P1 / P3 still green. |
| 3 | WP-UNWRAP-POLICY-001 | DONE 2026-08-26. Policy Univ4Se suite runs the burn-regime loop. Burn gate opened; protocol LP stayed 0 after the bounded loop, so unwrap was not forced via Open. Logs `protocolLp` / `freeDetf`. |
| 4 | WP-UNWRAP-CLAIMLIQ-001 | DONE 2026-08-26. `claimLiquidity` on Univ4Se with allowance 0 plus `NotAuthorized` negative. |
| 5 | WP-UNWRAP-SE-NEG-001 | DONE 2026-08-26. Contract holder + allowance 0 reverts `TransferFromFailed` (`0x7939f424`). Approve control succeeds. |
| 6 | WP-UNWRAP-DUST-SIB-001 | DONE 2026-08-26. Orbital/weighted/curve/balancer keep-10 + rebuffer. `doesNotDumpDust` tests green. |
| 7 | WP-UNWRAP-SLEEVE-001 | DEFER (P2) |
| 8 | WP-UNWRAP-DUST-LAST-001 | DEFER (P2). Close leftover `< 0.01 ether` on DETF is the last-resort class this WP would bound to `DUST`. |
| UI | parseContractError TransferFromFailed | DEFER (optional) |
