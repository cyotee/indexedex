// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    SingleVaultDetfExchangeIn_MintWithWeth_Test
} from "test/foundry/spec/vaults/detf/composed/single/SingleVaultDetfExchangeIn_MintWithWeth.t.sol";

/// @notice Wave 3D L1 property fuzz for SingleVaultDetf (production Uni V4 SE path).
/// forge-config: default.fuzz.runs = 32
contract SingleVaultDetf_Fuzz_Test is SingleVaultDetfExchangeIn_MintWithWeth_Test {
    address internal fuzzActor;

    function setUp() public override {
        super.setUp();
        fuzzActor = makeAddr("svFuzz");
    }

    /// @notice P-BOUND / P-CONS soft: mint with bounded rateAsset amounts yields non-zero or clean revert.
    function testFuzz_mintWithRateAsset_safe(uint256 amountSeed) public {
        uint256 amount = bound(amountSeed, 1e15, 50e18);
        deal(address(rateAsset), fuzzActor, amount, true);

        uint256 before_ = IERC20(address(detf)).balanceOf(fuzzActor);
        vm.startPrank(fuzzActor);
        rateAsset.approve(address(detf), amount);
        try IStandardExchangeIn(address(detf)).exchangeIn(
            rateAsset, amount, IERC20(address(detf)), 0, fuzzActor, false, block.timestamp + 1 hours
        ) returns (uint256 out_) {
            assertTrue(out_ > 0, "minted");
            assertEq(IERC20(address(detf)).balanceOf(fuzzActor), before_ + out_, "balance credit");
        } catch {
            // gates / liquidity may reject
        }
        vm.stopPrank();
        assertEq(IERC20(address(detf)).balanceOf(address(detf)), 0, "P-RESID free detf");
    }

    /// @notice P-NODILUTE: third-party mint does not reduce another holder's DETF balance.
    function testFuzz_holderBalance_notDiluted(uint256 aSeed, uint256 bSeed) public {
        uint256 aAmt = bound(aSeed, 5e18, 40e18);
        uint256 bAmt = bound(bSeed, 5e18, 40e18);
        address a = makeAddr("svHoldA");
        address b = makeAddr("svHoldB");

        deal(address(rateAsset), a, aAmt, true);
        vm.startPrank(a);
        rateAsset.approve(address(detf), aAmt);
        try IStandardExchangeIn(address(detf)).exchangeIn(
            rateAsset, aAmt, IERC20(address(detf)), 0, a, false, block.timestamp + 1 hours
        ) {} catch {
            vm.stopPrank();
            return;
        }
        vm.stopPrank();
        uint256 balA = IERC20(address(detf)).balanceOf(a);
        if (balA == 0) return;

        deal(address(rateAsset), b, bAmt, true);
        vm.startPrank(b);
        rateAsset.approve(address(detf), bAmt);
        try IStandardExchangeIn(address(detf)).exchangeIn(
            rateAsset, bAmt, IERC20(address(detf)), 0, b, false, block.timestamp + 1 hours
        ) {} catch {}
        vm.stopPrank();

        assertEq(IERC20(address(detf)).balanceOf(a), balA, "P-NODILUTE");
    }
}
