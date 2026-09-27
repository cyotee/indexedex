// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {CappedPausableERC4626} from "contracts/test/stubs/CappedPausableERC4626.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {ERC4626StandardExchangeCommon} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol";

/// @dev Production SE with a native ERC4626 yield/capacity dependency. No vault storage writes.
contract ERC4626StandardExchange_CreditPricing is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal asset;
    CappedPausableERC4626 internal protocol;
    AtomicPretransferCaller internal atomic;
    address internal se;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public override {
        super.setUp();
        asset = new SimpleMintableERC20("Asset", "AST");
        protocol = new CappedPausableERC4626(asset);
        se = _deployERC4626SE(address(protocol));
        atomic = new AtomicPretransferCaller();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0);
        vm.stopPrank();
        asset.mint(alice, 6);
        asset.mint(bob, 20);
        vm.startPrank(alice);
        asset.approve(se, 6);
        IStandardExchangeIn(se).exchangeIn(IERC20(address(asset)), 3, IERC20(se), 3, alice, false, block.timestamp);
        vm.stopPrank();
        asset.mint(address(this), 1);
        asset.approve(address(protocol), 1);
        protocol.simulateYield(1);
        protocol.setPaused(true);
        vm.prank(alice);
        assertEq(
            IStandardExchangeIn(se).exchangeIn(IERC20(address(asset)), 3, IERC20(se), 2, alice, false, block.timestamp),
            2
        );
        protocol.setPaused(false);
        vm.startPrank(bob);
        asset.approve(se, 20);
        asset.approve(address(atomic), 20);
        vm.stopPrank();
        assertEq(protocol.totalAssets(), 4);
        assertEq(protocol.totalSupply(), 3);
        assertEq(IERC20(se).totalSupply(), 5);
        assertEq(IBasicVault(se).reserveOfToken(address(asset)), 3);
    }

    function _assertCustody(uint256 refund_) internal view {
        assertEq(IERC20(se).balanceOf(alice), 5, "prior shares unchanged");
        assertEq(IERC20(se).balanceOf(bob), 3, "caller receives pre-investment quote");
        assertEq(IERC20(se).totalSupply(), 8);
        assertEq(protocol.totalAssets(), 11, "existing3 local plus caller4 are invested");
        assertEq(protocol.balanceOf(se), 7, "sweep and caller each mint2 native receipts");
        assertEq(asset.balanceOf(se), 0);
        assertEq(IBasicVault(se).reserveOfToken(address(asset)), 0);
        assertEq(IBasicVault(se).reserveOfToken(address(protocol)), 7);
        assertEq(asset.balanceOf(address(atomic)), refund_);
        assertEq(asset.balanceOf(bob) + refund_, 16, "only caller's4 assets spent");
        assertEq(
            asset.balanceOf(alice) + asset.balanceOf(bob) + asset.balanceOf(se) + asset.balanceOf(address(protocol))
                + asset.balanceOf(address(atomic)),
            27,
            "native asset conservation"
        );
        uint256 allClaim = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), 8, IERC20(address(asset)));
        assertEq(allClaim, 11, "issued shares remain fully backed");
    }

    function _exactIn(bool prepaid_) internal {
        uint256 quoted_ = IStandardExchangeIn(se).previewExchangeIn(IERC20(address(asset)), 4, IERC20(se));
        assertEq(quoted_, 3, "4 assets at pre-investment3/4 native rate");
        uint256 issued_;
        if (prepaid_) {
            issued_ = abi.decode(
                atomic.consumePretransfer(
                    IERC20(address(asset)),
                    bob,
                    se,
                    4,
                    abi.encodeCall(
                        IStandardExchangeIn.exchangeIn,
                        (IERC20(address(asset)), 4, IERC20(se), quoted_, bob, true, block.timestamp)
                    )
                ),
                (uint256)
            );
        } else {
            vm.prank(bob);
            issued_ = IStandardExchangeIn(se)
                .exchangeIn(IERC20(address(asset)), 4, IERC20(se), quoted_, bob, false, block.timestamp);
        }
        assertEq(issued_, quoted_);
        assertEq(protocol.convertToShares(4), 2, "post-investment conversion differs and must not reprice credit");
        _assertCustody(0);
    }

    function _exactOut(bool prepaid_) internal {
        uint256 quoted_ = IStandardExchangeOut(se).previewExchangeOut(IERC20(address(asset)), IERC20(se), 3);
        assertEq(quoted_, 4);
        uint256 paid_;
        if (prepaid_) {
            paid_ = abi.decode(
                atomic.consumePretransfer(
                    IERC20(address(asset)),
                    bob,
                    se,
                    7,
                    abi.encodeCall(
                        IStandardExchangeOut.exchangeOut,
                        (IERC20(address(asset)), 7, IERC20(se), 3, bob, true, block.timestamp)
                    )
                ),
                (uint256)
            );
        } else {
            vm.prank(bob);
            paid_ = IStandardExchangeOut(se)
                .exchangeOut(IERC20(address(asset)), quoted_, IERC20(se), 3, bob, false, block.timestamp);
        }
        assertEq(paid_, quoted_);
        assertEq(protocol.convertToShares(paid_), 2, "native conversion changed during the sweep");
        _assertCustody(prepaid_ ? 3 : 0);
    }

    function test_APEX_sweepExactInPullPricesCreditBeforeInvestment() public {
        _exactIn(false);
    }

    function test_APEX_sweepExactInPrepaidPricesCreditBeforeInvestment() public {
        _exactIn(true);
    }

    function test_APEX_sweepExactOutPullPricesCreditBeforeInvestment() public {
        _exactOut(false);
    }

    function test_APEX_sweepExactOutPrepaidPricesCreditBeforeInvestment() public {
        _exactOut(true);
    }
}
