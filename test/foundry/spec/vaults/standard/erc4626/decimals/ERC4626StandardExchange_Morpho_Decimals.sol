// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_ERC4626MorphoHermetic_Decimals} from
    "contracts/test/bases/TestBase_ERC4626MorphoHermetic_Decimals.sol";

/// @notice ERC-4626 SE over Morpho MetaMorpho with a non-18 loan token.
abstract contract ERC4626StandardExchange_Morpho_Decimals is TestBase_ERC4626MorphoHermetic_Decimals {
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;
    address internal user = address(0xBEEF);

    function setUp() public virtual override {
        TestBase_ERC4626MorphoHermetic_Decimals.setUp();
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);
        _seedMorphoVaultLiquidity(_u(100_000));
        _mintLoan(user, _u(50_000));
        vm.prank(user);
        loanToken.approve(se, type(uint256).max);
    }

    function test_Morpho_vaultTokens_membership() public view {
        address[] memory tokens = IBasicVault(se).vaultTokens();
        bool hasVault;
        bool hasAsset;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == address(morphoVault)) hasVault = true;
            if (tokens[i] == address(loanToken)) hasAsset = true;
        }
        assertTrue(hasVault && hasAsset);
    }

    function test_Morpho_wrapUnwrap_previewEqualsExecution() public {
        uint256 amountIn = _u(100);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), amountIn, IERC20(se));
        vm.prank(user);
        uint256 seOutAmt = seIn.exchangeIn(
            IERC20(address(loanToken)), amountIn, IERC20(se), preview, user, false, block.timestamp
        );
        assertEq(seOutAmt, preview);
        uint256 unwrapPreview = seIn.previewExchangeIn(IERC20(se), seOutAmt / 2, IERC20(address(loanToken)));
        vm.prank(user);
        uint256 uOut = seIn.exchangeIn(
            IERC20(se), seOutAmt / 2, IERC20(address(loanToken)), unwrapPreview, user, false, block.timestamp
        );
        assertEq(uOut, unwrapPreview);
    }

    function test_I1_pretransferred_noTransfer_bookedReserve_reverts() public {
        uint256 wrapIn_ = _u(100);
        vm.prank(user);
        seIn.exchangeIn(IERC20(address(loanToken)), wrapIn_, IERC20(se), 0, user, false, block.timestamp);
        uint256 claimed_ = _u(1);
        uint256 supplyBefore_ = IERC20(se).totalSupply();
        uint256 invBefore_ = IERC20(address(morphoVault)).balanceOf(se);
        assertGe(invBefore_, claimed_, "booked protocolVault inventory");
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        seIn.exchangeIn(IERC20(address(morphoVault)), claimed_, IERC20(se), 0, user, true, block.timestamp);
        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I1: no free SE mint");
        assertEq(IERC20(address(morphoVault)).balanceOf(se), invBefore_, "I1: inventory unmoved");
    }

    function test_Morpho_interestStrictIncrease_unwrap() public {
        uint256 amountIn = _u(200);
        vm.prank(user);
        uint256 seAmt = seIn.exchangeIn(
            IERC20(address(loanToken)), amountIn, IERC20(se), 0, user, false, block.timestamp
        );
        uint256 half = seAmt / 2;
        uint256 beforeOut = seIn.previewExchangeIn(IERC20(se), half, IERC20(address(loanToken)));
        _accrueMorphoInterest();
        uint256 afterOut = seIn.previewExchangeIn(IERC20(se), half, IERC20(address(loanToken)));
        assertGt(afterOut, beforeOut, "Morpho interest increases unwrap claim");
    }
}
