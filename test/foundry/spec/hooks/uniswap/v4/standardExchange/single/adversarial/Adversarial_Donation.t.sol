// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4SingleSEBufferHook_Adversarial as AdvBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/adversarial/TestBase_UniswapV4SingleSEBufferHook_Adversarial.sol";

contract Adversarial_Donation_Test is AdvBase {
    /// @notice A1: donate pairToken — wrap still SE-previewed; no free SE from donation.
    function test_A1_pairDonation_doesNotMintFreeSE() public {
        pairToken.mint(address(this), 100 ether);
        pairToken.transfer(hook, 50 ether);
        uint256 donated = pairToken.balanceOf(hook);
        assertEq(donated, 50 ether);

        uint256 amountIn = 10 ether;
        uint256 preview = buffer.previewWrap(amountIn);
        uint256 seBefore = IERC20(se).balanceOf(user);
        _wrapExactIn(amountIn);
        assertEq(IERC20(se).balanceOf(user) - seBefore, preview, "no free SE from donation");
        // Idle donation remains (O11)
        assertEq(pairToken.balanceOf(hook), donated, "donation idle OK");
    }

    /// @notice A2: donate SE shares — unwrap not credited free pair from idle SE.
    function test_A2_seDonation_doesNotCreditFreeUnwrap() public {
        // Mint SE to this contract via wrap on SE directly
        pairToken.mint(address(this), 100 ether);
        pairToken.approve(se, type(uint256).max);
        uint256 seGot = IERC20(se).balanceOf(address(this));
        // Fund SE balance: exchange
        IStandardExchangeIn_Local(se).exchangeIn(
            IERC20(address(pairToken)), 50 ether, IERC20(se), 0, address(this), false, block.timestamp
        );
        uint256 seAmt = IERC20(se).balanceOf(address(this)) - seGot;
        IERC20(se).transfer(hook, seAmt);
        uint256 donated = IERC20(se).balanceOf(hook);
        assertGt(donated, 0);

        uint256 seIn = 5 ether;
        uint256 preview = buffer.previewUnwrap(seIn);
        uint256 pairBefore = pairToken.balanceOf(user);
        _unwrapExactIn(seIn);
        assertEq(pairToken.balanceOf(user) - pairBefore, preview, "no free pair from SE donation");
        assertEq(IERC20(se).balanceOf(hook), donated, "SE donation idle OK");
    }

    /// @notice A3: donate then swap — idle stuck OK; not credited into swap accounting.
    function test_A3_donateThenSwap_idleNotCredited() public {
        pairToken.mint(address(this), 20 ether);
        pairToken.transfer(hook, 20 ether);
        uint256 pairDonated = pairToken.balanceOf(hook);

        _wrapExactIn(5 ether);
        _unwrapExactIn(2 ether);

        assertEq(pairToken.balanceOf(hook), pairDonated, "pair donation untouched by swaps");
    }

    /// @notice A3 exact-out: pair donation must not grief unwrapExactOut (settle delta only, O11).
    function test_A3_donateThenUnwrapExactOut_succeeds_idleRemains() public {
        pairToken.mint(address(this), 20 ether);
        pairToken.transfer(hook, 20 ether);
        uint256 pairDonated = pairToken.balanceOf(hook);
        assertEq(pairDonated, 20 ether);

        uint256 pairOut = 1 ether;
        uint256 seIn = buffer.previewUnwrapExactOut(pairOut);
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 pairBefore = pairToken.balanceOf(user);

        // Real path: exact-out unwrap via router (would CurrencyNotSettled if settle used full balanceOf)
        _unwrapExactOut(pairOut);

        assertEq(seBefore - IERC20(se).balanceOf(user), seIn, "spent SE == preview");
        assertEq(pairToken.balanceOf(user) - pairBefore, pairOut, "exact pair out");
        assertEq(pairToken.balanceOf(hook), pairDonated, "pair donation idle remains");
        assertEq(IERC20(se).balanceOf(hook), 0, "no SE residual on hook");
    }
}

interface IStandardExchangeIn_Local {
    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minOut,
        address to,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256);
}
