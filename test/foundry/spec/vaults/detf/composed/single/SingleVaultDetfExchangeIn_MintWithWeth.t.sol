// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PositionDescriptor} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionDescriptor.sol";
import {PositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PositionManager.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {IWETH9} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/external/IWETH9.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISingleVaultDetf} from "contracts/interfaces/ISingleVaultDetf.sol";
import {
    ISingleVaultDetfBonding
} from "contracts/vaults/detf/composed/single/SingleVaultDetfBondingTarget.sol";

import {SingleVaultDetfProductionBase} from "test/foundry/spec/vaults/detf/composed/single/SingleVaultDetf_ProductionBase.t.sol";

contract SingleVaultDetfExchangeIn_MintWithWeth_Test is SingleVaultDetfProductionBase {
    ISingleVaultDetf internal detf;

    address internal detfAlice = makeAddr("detfAlice");
    address internal detfBob = makeAddr("detfBob");
    address internal bootstrapBondHolder = makeAddr("bootstrapBondHolder");
    address internal reserveSeeder = makeAddr("reserveSeeder");

    int24 internal constant POSITION_TICK_LOWER = -60;
    int24 internal constant POSITION_TICK_UPPER = 60;
    uint128 internal constant POSITION_LIQUIDITY = 5e18;
    uint128 internal constant TEST_POSITION_LIQUIDITY = 1e18;

    function setUp() public virtual override {
        super.setUp();

        detf = _deploySingleVaultDetf();
        _bootstrapDetf();

        for (uint256 i = 0; i < 12; ++i) {
            _bondTestPosition(reserveSeeder, TEST_POSITION_LIQUIDITY);
        }

        _fundWeth(detfAlice, 2_000_000e18);
        _fundRich(detfAlice, 2_000_000e18);
        _fundWeth(detfBob, 2_000_000e18);
        _fundRich(detfBob, 2_000_000e18);
    }

    function test_mintWithRateAsset_reverts_whenMintingNotAllowed() public {
        uint256 amountIn = 1e18;

        vm.prank(detfAlice);
        rateAsset.approve(address(detf), amountIn);

        vm.expectRevert();
        vm.prank(detfAlice);
        detf.mintWithRateAsset(amountIn, detfAlice, false);
    }

    function test_mintWithRateAsset_mintsDetf_whenMintingAllowed() public {
        _driveToMintEnabled(detf);

        uint256 amountIn = 1e16;
        uint256 wethBefore = rateAsset.balanceOf(detfAlice);
        uint256 detfBefore = IERC20(address(detf)).balanceOf(detfAlice);
        uint256 reserveBefore = IERC20(detf.reservePool()).balanceOf(address(detf));

        vm.startPrank(detfAlice);
        rateAsset.approve(address(detf), amountIn);
        uint256 detfMinted = detf.mintWithRateAsset(amountIn, detfAlice, false);
        vm.stopPrank();

        assertGt(detfMinted, 0, "detf minted");
        assertEq(IERC20(address(detf)).balanceOf(detfAlice) - detfBefore, detfMinted, "alice detf delta");
        assertEq(wethBefore - rateAsset.balanceOf(detfAlice), amountIn, "alice weth spent");
        assertGt(IERC20(detf.reservePool()).balanceOf(address(detf)), reserveBefore, "reserve pool funded");
    }

    function test_mintWithRateAsset_splitsMintAcrossUserFeeToAndBondVault() public {
        _driveToMintEnabled(detf);

        uint256 amountIn = 1e16;
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 aliceBefore = IERC20(address(detf)).balanceOf(detfAlice);
        uint256 feeToBefore = IERC20(address(detf)).balanceOf(feeTo);
        uint256 bondVaultBefore = IERC20(address(detf)).balanceOf(address(detf.detfNFTVault()));

        vm.startPrank(detfAlice);
        rateAsset.approve(address(detf), amountIn);
        uint256 detfMinted = detf.mintWithRateAsset(amountIn, detfAlice, false);
        vm.stopPrank();

        assertGt(detfMinted, 0, "user detf minted");
        assertEq(IERC20(address(detf)).balanceOf(detfAlice) - aliceBefore, detfMinted, "user received net detf");
        assertGt(IERC20(address(detf)).balanceOf(feeTo), feeToBefore, "feeTo received detf");
        assertGt(IERC20(address(detf)).balanceOf(address(detf.detfNFTVault())), bondVaultBefore, "bond vault received detf");
    }

    function test_donate_weth_addsReserveSharesToProtocolNft() public {
        uint256 amountIn = 1e16;
        uint256 protocolNftId = detf.detfNFTVault().detfNFTId();
        uint256 protocolSharesBefore = detf.detfNFTVault().originalSharesOf(protocolNftId);
        uint256 richirBefore = detf.rebasingClaimToken().balanceOf(detfAlice);

        vm.startPrank(detfAlice);
        rateAsset.approve(address(detf), amountIn);
        ISingleVaultDetfBonding(address(detf)).donate(rateAsset, amountIn, false);
        vm.stopPrank();

        assertGt(
            detf.detfNFTVault().originalSharesOf(protocolNftId),
            protocolSharesBefore,
            "protocol nft funded by weth donation"
        );
        assertEq(detf.rebasingClaimToken().balanceOf(detfAlice), richirBefore, "donation does not mint richir");
    }

    function test_donate_detf_burnsSupply_withoutAddingProtocolShares() public {
        uint256 detfAmount = _mintDetfFor(detfAlice, 1e16);
        uint256 protocolNftId = detf.detfNFTVault().detfNFTId();
        uint256 protocolSharesBefore = detf.detfNFTVault().originalSharesOf(protocolNftId);
        uint256 totalSupplyBefore = IERC20(address(detf)).totalSupply();

        vm.startPrank(detfAlice);
        IERC20(address(detf)).approve(address(detf), detfAmount);
        ISingleVaultDetfBonding(address(detf)).donate(IERC20(address(detf)), detfAmount, false);
        vm.stopPrank();

        assertEq(IERC20(address(detf)).balanceOf(detfAlice), 0, "alice detf donated");
        assertEq(IERC20(address(detf)).totalSupply(), totalSupplyBefore - detfAmount, "detf supply burned");
        assertEq(
            detf.detfNFTVault().originalSharesOf(protocolNftId),
            protocolSharesBefore,
            "detf donation does not add protocol reserve shares"
        );
    }

    function test_captureSeigniorage_convertsProtocolRewardsIntoReserveShares() public {
        _driveToMintEnabled(detf);

        (IPositionManager positionManager, uint256 positionTokenId) = _createPosition(detfAlice, TEST_POSITION_LIQUIDITY);
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

        vm.prank(detfAlice);
        ISingleVaultDetfBonding(address(detf)).sellNFT(tokenId, detfAlice);

        _mintDetfFor(detfBob, 1e16);

        uint256 protocolNftId = detf.detfNFTVault().detfNFTId();
        uint256 protocolPendingBefore = detf.detfNFTVault().pendingRewards(protocolNftId);
        uint256 protocolSharesBefore = detf.detfNFTVault().originalSharesOf(protocolNftId);

        assertGt(protocolPendingBefore, 0, "protocol nft should accrue pending detf rewards");

        uint256 bptReceived = ISingleVaultDetfBonding(address(detf)).captureSeigniorage();

        assertGt(bptReceived, 0, "seigniorage captured");
        assertEq(
            detf.detfNFTVault().originalSharesOf(protocolNftId),
            protocolSharesBefore + bptReceived,
            "protocol nft receives captured reserve shares"
        );
        assertEq(detf.detfNFTVault().pendingRewards(protocolNftId), 0, "capture consumes pending protocol rewards");
    }

    function test_previewExchangeIn_detfToWeth_reverts_whenBurningNotAllowed() public {
        uint256 detfAmount = _mintDetfFor(detfAlice, 1e16);

        vm.expectRevert();
        IStandardExchangeIn(address(detf)).previewExchangeIn(IERC20(address(detf)), detfAmount, rateAsset);
    }

    function test_previewExchangeOut_detfToWeth_reverts_whenBurningNotAllowed() public {
        _mintDetfFor(detfAlice, 1e16);

        vm.expectRevert();
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(detf)), rateAsset, 1e15);
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
    }

    function test_exchangeIn_richToRichir_previewIsConservative() public {
        uint256 amountIn = 100e18;
        IERC20 rebasingClaimToken = IERC20(address(detf.rebasingClaimToken()));

        vm.prank(detfAlice);
        pairToken.approve(address(detf), amountIn);

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
    }

    function test_exchangeIn_detfToWeth_reverts_whenBurningNotAllowed() public {
        _driveToMintEnabled(detf);
        uint256 detfAmount = _mintDetfFor(detfAlice, 1e16);

        vm.startPrank(detfAlice);
        IERC20(address(detf)).approve(address(detf), detfAmount);
        vm.expectRevert();
        IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(detf)),
            detfAmount,
            rateAsset,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _bootstrapDetf() internal {
        (IPositionManager positionManager, uint256 tokenId) = _createPosition(bootstrapBondHolder, POSITION_LIQUIDITY);

        vm.prank(bootstrapBondHolder);
        ISingleVaultDetfBonding(address(detf)).bondWithPosition(
            positionManager,
            tokenId,
            MIN_LOCK_DURATION,
            bootstrapBondHolder,
            block.timestamp + 1 hours
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

        _fundWeth(owner_, 1_000e18);
        _fundRich(owner_, 1_000e18);

        vm.startPrank(owner_);
        _approvePositionManager(address(rateAsset), positionManager_);
        _approvePositionManager(address(pairToken), positionManager_);

        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.CLOSE_CURRENCY),
            uint8(Actions.CLOSE_CURRENCY)
        );
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            _buildPoolKey(),
            POSITION_TICK_LOWER,
            POSITION_TICK_UPPER,
            uint256(liquidity_),
            type(uint128).max,
            type(uint128).max,
            owner_,
            bytes("")
        );
        params[1] = abi.encode(_buildPoolKey().currency0);
        params[2] = abi.encode(_buildPoolKey().currency1);

        positionManager_.modifyLiquidities(abi.encode(actions, params), block.timestamp + 1 hours);
        IERC721(address(positionManager_)).approve(address(detf.underlyingVault()), tokenId_);
        vm.stopPrank();
    }

    function _approvePositionManager(address token_, IPositionManager positionManager_) internal {
        IERC20(token_).approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            token_,
            address(positionManager_),
            type(uint160).max,
            type(uint48).max
        );
    }

    function _mintDetfFor(address actor_, uint256 wethAmount_) internal returns (uint256 detfMinted_) {
        _driveToMintEnabled(detf);

        vm.startPrank(actor_);
        rateAsset.approve(address(detf), wethAmount_);
        detfMinted_ = detf.mintWithRateAsset(wethAmount_, actor_, false);
        vm.stopPrank();
    }

    function _assertMintEnabled(IProtocolDETF detf_) internal view {
        assertGt(detf_.syntheticPrice(), detf_.mintThreshold(), "fixture should be above upper deadband bound");
        assertTrue(detf_.isMintingAllowed(), "minting should be enabled");
        assertFalse(detf_.isBurningAllowed(), "burning should be disabled");
    }

    function _driveToMintEnabled(IProtocolDETF detf_) internal {
        if (detf_.isMintingAllowed()) {
            return;
        }

        uint256[] memory steps = new uint256[](5);
        steps[0] = 5e18;
        steps[1] = 1e18;
        steps[2] = 5e17;
        steps[3] = 1e17;
        steps[4] = 5e16;

        uint256 iterations;
        while (!detf_.isMintingAllowed()) {
            for (uint256 i = 0; i < steps.length; ++i) {
                _fundRich(detfBob, steps[i]);
                vm.startPrank(detfBob);
                pairToken.approve(address(detf_), type(uint256).max);
                IStandardExchangeIn(address(detf_)).exchangeIn(
                    pairToken,
                    steps[i],
                    rateAsset,
                    0,
                    detfBob,
                    false,
                    block.timestamp + 1 hours
                );
                vm.stopPrank();
                if (detf_.isMintingAllowed()) {
                    break;
                }
            }
            iterations++;
            require(iterations < 60, "too many iterations seeking single-vault burn enabled");
        }
    }
}
