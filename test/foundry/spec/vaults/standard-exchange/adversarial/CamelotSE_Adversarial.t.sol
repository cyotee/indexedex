// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";

/// @notice Wave 2B SE adversarial P0 on production Camelot V2 Standard Exchange vault.
/// @dev Second protocol for ≥2 SE instances. C-class: CamelotV2StandardExchange_ReentrancyGuard.
contract CamelotSE_Adversarial_Test is TestBase_CamelotV2StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    address internal attacker;

    uint256 internal constant SEED = 1000 ether;
    uint256 internal constant TEST_AMT = 50 ether;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("camelotSeAttacker");
        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), 10_000 ether);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), 10_000 ether);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), SEED);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), SEED);
        vault = IStandardExchangeProxy(
            camelotV2StandardExchangeDFPkg.deployVault(
                IERC20(address(tokenA)), SEED, IERC20(address(tokenB)), SEED, address(this)
            )
        );
    }

    function test_A1_donateToken_cannotMintFreeShares() public {
        uint256 amount_ = TEST_AMT;
        deal(address(tokenA), attacker, amount_);
        uint256 sharesBefore_ = IERC20(address(vault)).balanceOf(attacker);
        vm.prank(attacker);
        tokenA.transfer(address(vault), amount_);
        assertEq(IERC20(address(vault)).balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
    }

    function test_E5_zeroAmount_reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)), 0, IERC20(address(tokenB)), 0, attacker, false, block.timestamp + 1 hours
        );
    }

    function test_F1_diamondCut_blocked() public {
        (bool ok,) = address(vault).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    function test_H3_minOutTooHigh_noFreeShares() public {
        uint256 amount_ = TEST_AMT;
        deal(address(tokenA), attacker, amount_);
        uint256 preview_ =
            vault.previewExchangeIn(IERC20(address(tokenA)), amount_, IERC20(address(tokenB)));
        vm.startPrank(attacker);
        tokenA.approve(address(vault), amount_);
        vm.expectRevert();
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tokenA)),
            amount_,
            IERC20(address(tokenB)),
            preview_ + type(uint128).max,
            attacker,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0, "H3 residual");
    }
}
