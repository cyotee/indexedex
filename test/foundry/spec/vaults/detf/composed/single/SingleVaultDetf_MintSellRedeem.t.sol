// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionDescriptor.sol";
import {PositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionManager.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/external/IWETH9.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {
    ISingleVaultDetfBonding
} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol";

import {SingleVaultDetfProductionBase} from "test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_ProductionBase.t.sol";

contract SingleVaultDetf_MintSellRedeem_Test is SingleVaultDetfProductionBase {
    ISingleVaultDetf internal detf;
    address internal detfAlice = makeAddr("detfAlice");
    address internal bootstrapBondHolder = makeAddr("bootstrapBondHolder");
    address internal reserveSeeder = makeAddr("reserveSeeder");

    int24 internal constant POSITION_TICK_LOWER = -60;
    int24 internal constant POSITION_TICK_UPPER = 60;
    uint128 internal constant POSITION_LIQUIDITY = 1e18;
    uint128 internal constant TEST_POSITION_LIQUIDITY = 1e15;
    uint128 internal constant REDEEM_TEST_POSITION_LIQUIDITY = 1e17;

    function setUp() public override {
        super.setUp();
        detf = _deploySingleVaultDetf();
        _bootstrapDetf();

        _fundWeth(detfAlice, 10_000e18);
        _fundRich(detfAlice, 10_000e18);
    }

    function test_mintWithRateAsset_revertsWhileBootstrapReserveRemainsInProtocolNft() public {
        uint256 amountIn = 1e18;

        vm.prank(detfAlice);
        rateAsset.approve(address(detf), amountIn);

        vm.expectRevert();
        vm.prank(detfAlice);
        detf.mintWithRateAsset(amountIn, detfAlice, false);
    }

    function test_sellNFT_transfersPrincipalShares_burnsNFT_mintsRichir() public {
        (IPositionManager positionManager, uint256 positionTokenId) = _createPosition(detfAlice, TEST_POSITION_LIQUIDITY);
        vm.prank(detfAlice);
        IERC721(address(positionManager)).approve(address(detf), positionTokenId);

        vm.prank(detfAlice);
        (uint256 tokenId, uint256 shares) = ISingleVaultDetfBonding(address(detf)).bondWithPosition(
            positionManager,
            positionTokenId,
            MIN_LOCK_DURATION,
            detfAlice,
            block.timestamp + 1 hours
        );

        IDETFNFTVault detfNFTVault = detf.detfNFTVault();
        uint256 protocolId = detfNFTVault.detfNFTId();
        uint256 protocolPrincipalBefore = detfNFTVault.originalSharesOf(protocolId);
        IRebasingClaimToken rebasingClaimToken = IRebasingClaimToken(address(detf.rebasingClaimToken()));
        uint256 rebasingClaimSharesBefore = rebasingClaimToken.sharesOf(detfAlice);

        vm.prank(detfAlice);
        uint256 rebasingClaimMinted = ISingleVaultDetfBonding(address(detf)).sellNFT(tokenId, detfAlice);

        assertEq(detfNFTVault.originalSharesOf(protocolId), protocolPrincipalBefore + shares, "protocol nft principal");
        assertEq(rebasingClaimToken.sharesOf(detfAlice), rebasingClaimSharesBefore + shares, "richir shares minted");
        assertEq(detfNFTVault.ownerOf(tokenId), address(0), "sold nft burned");
        assertGt(rebasingClaimMinted, 0, "richir minted");
        assertEq(rebasingClaimMinted, rebasingClaimToken.balanceOf(detfAlice), "richir balance amount");
    }

    function test_redeemPosition_unwindsThroughProtocolNftVault() public {
        for (uint256 i = 0; i < 5; ++i) {
            _bondTestPosition(reserveSeeder, TEST_POSITION_LIQUIDITY);
        }
        (IPositionManager positionManager, uint256 positionTokenId) = _createPosition(detfAlice, REDEEM_TEST_POSITION_LIQUIDITY);
        vm.prank(detfAlice);
        IERC721(address(positionManager)).approve(address(detf), positionTokenId);

        vm.prank(detfAlice);
        (uint256 tokenId,) = ISingleVaultDetfBonding(address(detf)).bondWithPosition(
            positionManager,
            positionTokenId,
            MIN_LOCK_DURATION,
            detfAlice,
            block.timestamp + 1 hours
        );

        vm.warp(block.timestamp + MIN_LOCK_DURATION + 1);

        IDETFNFTVault detfNFTVault = detf.detfNFTVault();
        uint256 wethBefore = rateAsset.balanceOf(detfAlice);
        vm.prank(detfAlice);
        uint256 wethOut = detfNFTVault.redeemPosition(tokenId, detfAlice, block.timestamp + 1 hours);

        assertGt(wethOut, 0, "weth redeemed");
        assertEq(rateAsset.balanceOf(detfAlice) - wethBefore, wethOut, "alice weth out");
        assertEq(detfNFTVault.ownerOf(tokenId), address(0), "bond nft burned on redeem");
    }

    function test_claimLiquidity_revertsWhenNotProtocolNftVault() public {
        vm.expectRevert(abi.encodeWithSelector(IProtocolDETFErrors.NotNFTVault.selector, detfAlice));
        vm.prank(detfAlice);
        IProtocolDETF(address(detf)).claimLiquidity(1e18, detfAlice);
    }

    function test_exchangeIn_wethToRichir_previewIsConservative() public {
        uint256 amountIn = 100e18;
        IERC20 rebasingClaimToken = IERC20(address(detf.rebasingClaimToken()));

        vm.prank(detfAlice);
        rateAsset.approve(address(detf), amountIn);

        uint256 previewOut = IStandardExchangeIn(address(detf)).previewExchangeIn(rateAsset, amountIn, rebasingClaimToken);

        vm.prank(detfAlice);
        uint256 rebasingClaimOut = IStandardExchangeIn(address(detf)).exchangeIn(
            rateAsset,
            amountIn,
            rebasingClaimToken,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );

        assertGt(previewOut, 0, "preview nonzero");
        assertGt(rebasingClaimOut, 0, "richir minted");
        assertLe(previewOut, rebasingClaimOut, "preview remains conservative");
        assertEq(detf.rebasingClaimToken().balanceOf(detfAlice), rebasingClaimOut, "alice richir balance");
        assertGt(detf.detfNFTVault().originalSharesOf(detf.detfNFTVault().detfNFTId()), 0, "protocol nft funded");
    }

    function test_exchangeIn_richToRichir_previewIsConservative() public {
        uint256 amountIn = 100e18;
        IERC20 rebasingClaimToken = IERC20(address(detf.rebasingClaimToken()));

        vm.prank(detfAlice);
        pairToken.approve(address(detf), amountIn);

        uint256 protocolSharesBefore = detf.detfNFTVault().originalSharesOf(detf.detfNFTVault().detfNFTId());
        uint256 previewOut = IStandardExchangeIn(address(detf)).previewExchangeIn(pairToken, amountIn, rebasingClaimToken);

        vm.prank(detfAlice);
        uint256 rebasingClaimOut = IStandardExchangeIn(address(detf)).exchangeIn(
            pairToken,
            amountIn,
            rebasingClaimToken,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );

        assertGt(previewOut, 0, "preview nonzero");
        assertGt(rebasingClaimOut, 0, "richir minted");
        assertLe(previewOut, rebasingClaimOut, "preview remains conservative");
        assertEq(detf.rebasingClaimToken().balanceOf(detfAlice), rebasingClaimOut, "alice richir balance");
        assertGt(
            detf.detfNFTVault().originalSharesOf(detf.detfNFTVault().detfNFTId()),
            protocolSharesBefore,
            "protocol nft funded"
        );
    }

    function _bootstrapDetf() internal {
        (IPositionManager positionManager, uint256 tokenId) = _createBootstrapPosition(bootstrapBondHolder);

        vm.prank(bootstrapBondHolder);
        ISingleVaultDetfBonding(address(detf)).bondWithPosition(
            positionManager, tokenId, MIN_LOCK_DURATION, bootstrapBondHolder, block.timestamp + 1 hours
        );
    }

    function _bondTestPosition(address owner_, uint128 liquidity_) internal returns (uint256 tokenId_, uint256 shares_) {
        (IPositionManager positionManager, uint256 positionTokenId) = _createPosition(owner_, liquidity_);
        vm.prank(owner_);
        IERC721(address(positionManager)).approve(address(detf), positionTokenId);
        vm.prank(owner_);
        (tokenId_, shares_) = ISingleVaultDetfBonding(address(detf)).bondWithPosition(
            positionManager,
            positionTokenId,
            MIN_LOCK_DURATION,
            owner_,
            block.timestamp + 1 hours
        );
    }


    function _createBootstrapPosition(address owner_) internal returns (IPositionManager positionManager_, uint256 tokenId_) {
        return _createPosition(owner_, POSITION_LIQUIDITY);
    }

    function _createPosition(address owner_, uint128 liquidity_) internal returns (IPositionManager positionManager_, uint256 tokenId_) {
        PositionDescriptor descriptor = new PositionDescriptor(poolManager, address(rateAsset), bytes32("ETH"));
        positionManager_ = IPositionManager(
            address(
                new PositionManager(
                    poolManager,
                    IAllowanceTransfer(address(permit2)),
                    100_000,
                    descriptor,
                    IWETH9(address(rateAsset))
                )
            )
        );

        tokenId_ = positionManager_.nextTokenId();

        uint128 amount0Max = type(uint128).max;
        uint128 amount1Max = type(uint128).max;

        _fundWeth(owner_, 10_000e18);
        _fundRich(owner_, 10_000e18);

        vm.startPrank(owner_);
        _approvePositionManager(address(rateAsset), positionManager_);
        _approvePositionManager(address(pairToken), positionManager_);

        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION), uint8(Actions.CLOSE_CURRENCY), uint8(Actions.CLOSE_CURRENCY)
        );
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            _buildPoolKey(),
            POSITION_TICK_LOWER,
            POSITION_TICK_UPPER,
            uint256(liquidity_),
            amount0Max,
            amount1Max,
            owner_,
            bytes("")
        );
        params[1] = abi.encode(_buildPoolKey().currency0);
        params[2] = abi.encode(_buildPoolKey().currency1);

        positionManager_.modifyLiquidities(abi.encode(actions, params), block.timestamp + 1 hours);
        IERC721(address(positionManager_)).approve(address(detf.underlyingVault()), tokenId_);
        vm.stopPrank();

        assertEq(IERC721(address(positionManager_)).ownerOf(tokenId_), owner_, "bootstrap position owner");
    }

    function _approvePositionManager(address token_, IPositionManager positionManager_) internal {
        IERC20(token_).approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            token_, address(positionManager_), type(uint160).max, type(uint48).max
        );
    }
}