// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_ERC4626MorphoHermetic} from
    "contracts/test/bases/TestBase_ERC4626MorphoHermetic.sol";

/**
 * @title ERC4626StandardExchange_Morpho_Test
 * @notice Production Morpho MetaMorpho as protocol vault: vaultTokens, wrap/unwrap, real interest.
 */
contract ERC4626StandardExchange_Morpho_Test is TestBase_ERC4626MorphoHermetic {
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;
    address internal user = address(0xBEEF);

    function setUp() public override {
        TestBase_ERC4626MorphoHermetic.setUp();
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);
        _seedMorphoVaultLiquidity(100_000 ether);
        _mintLoan(user, 50_000 ether);
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
        uint256 amountIn = 100 ether;
        uint256 preview = seIn.previewExchangeIn(
            IERC20(address(loanToken)), amountIn, IERC20(se)
        );
        vm.prank(user);
        uint256 seOutAmt = seIn.exchangeIn(
            IERC20(address(loanToken)),
            amountIn,
            IERC20(se),
            preview,
            user,
            false,
            block.timestamp
        );
        assertEq(seOutAmt, preview);

        uint256 unwrapPreview =
            seIn.previewExchangeIn(IERC20(se), seOutAmt / 2, IERC20(address(loanToken)));
        vm.prank(user);
        uint256 uOut = seIn.exchangeIn(
            IERC20(se),
            seOutAmt / 2,
            IERC20(address(loanToken)),
            unwrapPreview,
            user,
            false,
            block.timestamp
        );
        assertEq(uOut, unwrapPreview);
    }

    /// @notice I1 booked: wrap books morphoVault reserve; free pretransfer cannot mint.
    function test_I1_pretransferred_noTransfer_bookedReserve_reverts() public {
        uint256 wrapIn_ = 100 ether;
        vm.prank(user);
        seIn.exchangeIn(
            IERC20(address(loanToken)), wrapIn_, IERC20(se), 0, user, false, block.timestamp
        );

        uint256 claimed_ = 1 ether;
        uint256 supplyBefore_ = IERC20(se).totalSupply();
        uint256 invBefore_ = IERC20(address(morphoVault)).balanceOf(se);
        assertGe(invBefore_, claimed_, "booked protocolVault inventory");

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        seIn.exchangeIn(
            IERC20(address(morphoVault)), claimed_, IERC20(se), 0, user, true, block.timestamp
        );

        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I1: no free SE mint");
        assertEq(IERC20(address(morphoVault)).balanceOf(se), invBefore_, "I1: inventory unmoved");
    }

    function test_Morpho_interestStrictIncrease_unwrap() public {
        uint256 amountIn = 200 ether;
        vm.prank(user);
        uint256 seAmt = seIn.exchangeIn(
            IERC20(address(loanToken)),
            amountIn,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        uint256 half = seAmt / 2;
        uint256 beforeOut =
            seIn.previewExchangeIn(IERC20(se), half, IERC20(address(loanToken)));

        _accrueMorphoInterest();

        uint256 afterOut =
            seIn.previewExchangeIn(IERC20(se), half, IERC20(address(loanToken)));
        assertGt(afterOut, beforeOut, "Morpho interest increases unwrap claim");
    }
}
