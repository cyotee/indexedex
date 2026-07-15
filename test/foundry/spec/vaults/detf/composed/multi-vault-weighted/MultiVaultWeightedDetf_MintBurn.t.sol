// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";

contract MultiVaultWeightedDetf_MintBurn_Test is TestBase_MultiVaultWeightedDetf {
    address internal openDetf;
    IMultiVaultWeightedDetfInfo internal openInfo;
    IMultiVaultWeightedDetfBonding internal openBonding;
    IStandardExchangeIn internal openEx;

    function setUp() public virtual override {
        super.setUp();
        openDetf = _deployOpenThresholdDetf();
        openInfo = IMultiVaultWeightedDetfInfo(openDetf);
        openBonding = IMultiVaultWeightedDetfBonding(openDetf);
        openEx = IStandardExchangeIn(openDetf);
    }

    function test_mint_previewEqualsExecution() public {
        _goLiveViaBptBond(openDetf, alice, 1_000e18);
        assertTrue(openInfo.isMintingAllowed(), "mint open");

        uint256 seShares_ = _fundSeShares0(bob, 200e18);
        uint256 preview_ = openEx.previewExchangeIn(seShare0, seShares_, IERC20(openDetf));

        vm.startPrank(bob);
        seShare0.approve(openDetf, seShares_);
        uint256 out_ = openEx.exchangeIn(
            seShare0, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(out_ > 0, "minted");
        assertEq(preview_, out_, "preview == execution exact");
        _assertNoFreeInventory(openDetf);
    }

    function test_burn_previewEqualsExecution() public {
        _goLiveViaBptBond(openDetf, alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 200e18);
        vm.startPrank(bob);
        seShare0.approve(openDetf, seShares_);
        openEx.exchangeIn(seShare0, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        uint256 detfBal_ = IERC20(openDetf).balanceOf(bob);
        uint256 burnAmt_ = detfBal_ / 2;
        uint256 preview_ = openEx.previewExchangeIn(IERC20(openDetf), burnAmt_, seShare0);
        IERC20(openDetf).approve(openDetf, burnAmt_);
        uint256 out_ =
            openEx.exchangeIn(IERC20(openDetf), burnAmt_, seShare0, 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertTrue(out_ > 0, "burned to shares");
        assertEq(preview_, out_, "burn preview == execution exact");
        _assertNoFreeInventory(openDetf);
    }

    function test_invalidRoute_rateAssetAsMint() public {
        _goLiveViaBptBond(openDetf, alice, 500e18);
        dai.mint(bob, 1e18);
        vm.startPrank(bob);
        dai.approve(openDetf, 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiVaultWeightedDetfRepo.InvalidRoute.selector, address(dai), openDetf
            )
        );
        openEx.exchangeIn(dai, 1e18, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_invalidRoute_shareToShare() public {
        _goLiveViaBptBond(openDetf, alice, 500e18);
        uint256 seShares_ = _fundSeShares0(bob, 50e18);
        vm.startPrank(bob);
        seShare0.approve(openDetf, seShares_);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiVaultWeightedDetfRepo.InvalidRoute.selector, address(seShare0), address(seShare0)
            )
        );
        openEx.exchangeIn(seShare0, seShares_, seShare0, 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_invalidRoute_exactOut() public {
        _goLiveViaBptBond(openDetf, alice, 500e18);
        // previewExchangeOut must InvalidRoute (binary search not implemented)
        (bool ok, bytes memory ret) = openDetf.staticcall(
            abi.encodeWithSignature(
                "previewExchangeOut(address,address,uint256)", address(seShare0), openDetf, 1e18
            )
        );
        assertFalse(ok, "exact-out preview must revert");
        // Prefer InvalidRoute when bubbled
        if (ret.length >= 4) {
            bytes4 sel;
            assembly {
                sel := mload(add(ret, 32))
            }
            assertEq(
                sel,
                MultiVaultWeightedDetfRepo.InvalidRoute.selector,
                "InvalidRoute selector"
            );
        }
    }
}
