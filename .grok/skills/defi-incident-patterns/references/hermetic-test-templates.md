# Hermetic adversarial test templates (A0 / L / M / N / O)

**Contents**

- Rules
- NatSpec stubs
- Function skeletons (Foundry)

Copy into feature `adversarial/` suites. Extend product TestBase — never mock the SUT.

## Rules

1. Deploy via CREATE3 / FactoryService / **IndexedEx vault registry** as appropriate  
2. Drive real entry points (`exchangeIn`, `deposit`, `bond`, `redeemClaim`, …)  
3. Pass = exploit blocked **or** documented intentional risk with safety invariants  
4. Name tests `test_<ID>_<slug>()` for catalog greps  
5. Prefer exact selectors on reverts; assert residual free inventory  

## Suite NatSpec

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Incident-pattern P0 extensions: A0 empty vault, L AMM desync, M middleware, N TOCTOU, O signatures.
/// @dev Deferred: M* if no router/helper; O* if no permit; L2 if FoT underlyings forbidden.
///      Corpus study only: lib/DeFiHackLabs (not forge path). Method: crane-adversarial-testing.
abstract contract Adversarial_IncidentPatterns is TestBase_Feature_Adversarial {
    // implement concrete product TestBase_*_Adversarial
}
```

## A0 — empty vault / residual inventory

```solidity
/// @dev Pre-seed assets on instance with totalSupply==0 (or product-equivalent empty share state).
function test_A0_residualAssets_zeroSupply_firstMinterCannotDrain() public {
    address instance = _deployFreshEmptyShareInstance(); // product helper
    uint256 seed = 100e18;
    _donateUnderlying(instance, seed); // direct transfer — not mint path
    assertEq(_shareTotalSupply(instance), 0);

    uint256 attackerBefore = _underlyingBal(attacker);
    vm.startPrank(attacker);
    // attempt first mint/deposit at dust cost that would claim residual if buggy
    // ... product entry point ...
    vm.stopPrank();

    // Pass: attacker did not extract ~seed for free; residual still owned by vault policy
    assertLe(_underlyingBal(attacker) - attackerBefore, _maxAllowedDustProfit());
    // or expectRevert exact selector if mint blocked until init/bond
}
```

## E6 / F5 — surplus-refund & public structural reclaim

```solidity
/// @dev See also references/surplus-refund-structural-ops.md
function test_E6_surplusRefund_cannotDrainPriorInventory() public {
    address instance = _openLiveWithIdleInventory();
    uint256 prior = _idleInventory(instance);
    // attacker triggers residual-return / refund path (with or without overpay)
    // Pass: prior inventory unchanged (minus documented fee only); attacker net ≤ 0
    assertEq(_idleInventory(instance), prior);
}

function test_L1_F5_publicReclaim_cannotExtractTradingProceeds() public {
    address instance = _openLive();
    // pay for product via production entry; then call public migrate/reclaim/resize if any
    // Pass: cannot walk away with product + recovered payment / protocol surplus
}
```

## L — AMM desync

```solidity
function test_L1_untrackedSurplus_cannotFreeMint() public {
    address instance = _openLive();
    // Create balance > reserve / untracked surplus on priced inventory if product exposes it
    // Attempt mint/exchange that would credit surplus
    // Pass: no free shares/product; books match
}

function test_L2_feeOnTransfer_creditActualIn() public {
    // Only if product claims FoT support; else defer NatSpec
    // Deposit FoT token; assert shares from actualIn not nominal
}

function test_L3_pairReserveSkew_cannotFreeMintBeyondPolicy() public {
    address instance = _openLive();
    _swapUnderlying(/* skew */);
    // mint then reverse burn under default thresholds
    // Pass: no free lunch OR bounded seigniorage + victim unchanged + residual 0
}
```

## M — middleware / allowance

```solidity
function test_M1_userCalldata_cannotSpendAllowance() public {
    // If product has no forwarder: /// @dev Deferred M1: no router/helper surface
    // Else: prank attacker calling helper with target=WETH data=transferFrom(victim,...)
    // Pass: revert; victim allowance unused or unspendable
}

function test_M2_hostileSwapTarget_reverts() public {
    // issue/exchange helper with attacker-controlled swap target
    // Pass: allowlist revert or amountOut validation
}

function test_M3_noThirdPartyAllowanceSweep() public {
    // victim approved SUT; attacker tries to pull victim funds
    // Pass: revert without victim signature/intent
}
```

## N — quote–settle TOCTOU

```solidity
function test_N1_midFlowHook_cannotInflateCredit() public {
    // Multi-step path with callback/hook between quote and settle
    // Hostile hook mutates units/valuation mid-tx
    // Pass: revert or credit not inflated; inventory not drained to attacker
}

function test_N2_preview_matches_execute() public {
    // preview then execute same inputs
    // Pass: equal or documented tolerance
}
```

## O — signatures

```solidity
function test_O1_invalidOrZeroSigner_reverts() public {
    // permit with bad v/r/s or ecrecover→address(0)
    // Pass: exact revert; no allowance set
}

function test_O2_signatureReplay_reverts() public {
    // successful permit once; replay same payload
    // Pass: second call reverts
}

function test_O3_wrongDomain_reverts() public {
    // EIP-712 / Permit2 wrong domain separator
    // Pass: revert; no credit (also I5)
}
```

## Run

```bash
forge test --match-path 'test/foundry/spec/<feature>/adversarial/**' -vv
# rg "function test_A0_|function test_L1_|function test_M1_|function test_N1_|function test_O1_" test/...
```

## Related

- Crane `references/attack-catalog-template.md`
- Crane `references/implementation-test-dod.md`
- `theme-to-catalog.md`, `curated-incidents.md`
