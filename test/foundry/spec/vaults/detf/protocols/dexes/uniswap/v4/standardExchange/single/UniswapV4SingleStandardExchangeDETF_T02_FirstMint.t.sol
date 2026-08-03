// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

/// @dev T02: First primary mint → live.
contract UniswapV4SingleStandardExchangeDETF_T02_FirstMint is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        _deployBackingSeAndSeed();
        _deployDetfInstance(TickMath.getSqrtPriceAtTick(0), ThresholdMode.Policy);
    }

    function test_firstMint_pairToken_goesLive() public {
        assertFalse(_detfInfo().isReserveLive(), "pre-live");
        assertEq(IERC20Metadata(detfInstance).decimals(), 18);

        uint256 amountIn = 100 ether;
        // Fund pair and mint DETF.
        ERC20PermitMintableStub(address(pairToken)).mint(address(this), amountIn);
        pairToken.approve(detfInstance, amountIn);

        uint256 detfOut = IStandardExchangeIn(detfInstance).exchangeIn(
            pairToken,
            amountIn,
            IERC20(detfInstance),
            0,
            address(this),
            false,
            block.timestamp + 1 days
        );

        assertGt(detfOut, 0, "minted DETF");
        assertTrue(_detfInfo().isReserveLive(), "live after first mint");
        assertEq(IERC20(detfInstance).balanceOf(address(this)), detfOut);
        // Inventory shares on DETF.
        assertGt(IERC20(address(backingSeVault)).balanceOf(detfInstance), 0, "backing shares inventory");
        // Synthetic at creation fallback is 1e18.
        assertEq(_detfInfo().syntheticPrice(), 1e18);
        // Children wired.
        assertTrue(_detfInfo().bondNft() != address(0));
        assertTrue(_detfInfo().rebasingClaimToken() != address(0));
        assertTrue(_detfInfo().bondNft() != _detfInfo().rebasingClaimToken());
        assertTrue(address(backingSeVault) != _detfInfo().rebasingClaimToken());
    }
}
