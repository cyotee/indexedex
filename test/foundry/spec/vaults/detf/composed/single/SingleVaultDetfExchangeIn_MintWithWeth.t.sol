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

    function setUp() public override {
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

    function test_mintWithWeth_reverts_whenMintingNotAllowed() public {
        uint256 amountIn = 1e18;

        vm.prank(detfAlice);
        wethToken.approve(address(detf), amountIn);

        vm.expectRevert();
        vm.prank(detfAlice);
        detf.mintWithWeth(amountIn, detfAlice, false);
    }

    function test_mintWithWeth_mintsChir_whenMintingAllowed() public {
        _driveToMintEnabled(detf);

        uint256 amountIn = 1e16;
        uint256 wethBefore = wethToken.balanceOf(detfAlice);
        uint256 chirBefore = IERC20(address(detf)).balanceOf(detfAlice);
        uint256 reserveBefore = IERC20(detf.reservePool()).balanceOf(address(detf));

        vm.startPrank(detfAlice);
        wethToken.approve(address(detf), amountIn);
        uint256 chirMinted = detf.mintWithWeth(amountIn, detfAlice, false);
        vm.stopPrank();

        assertGt(chirMinted, 0, "chir minted");
        assertEq(IERC20(address(detf)).balanceOf(detfAlice) - chirBefore, chirMinted, "alice chir delta");
        assertEq(wethBefore - wethToken.balanceOf(detfAlice), amountIn, "alice weth spent");
        assertGt(IERC20(detf.reservePool()).balanceOf(address(detf)), reserveBefore, "reserve pool funded");
    }

    function test_mintWithWeth_splitsMintAcrossUserFeeToAndBondVault() public {
        _driveToMintEnabled(detf);

        uint256 amountIn = 1e16;
        address feeTo = address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
        uint256 aliceBefore = IERC20(address(detf)).balanceOf(detfAlice);
        uint256 feeToBefore = IERC20(address(detf)).balanceOf(feeTo);
        uint256 bondVaultBefore = IERC20(address(detf)).balanceOf(address(detf.protocolNFTVault()));

        vm.startPrank(detfAlice);
        wethToken.approve(address(detf), amountIn);
        uint256 chirMinted = detf.mintWithWeth(amountIn, detfAlice, false);
        vm.stopPrank();

        assertGt(chirMinted, 0, "user chir minted");
        assertEq(IERC20(address(detf)).balanceOf(detfAlice) - aliceBefore, chirMinted, "user received net chir");
        assertGt(IERC20(address(detf)).balanceOf(feeTo), feeToBefore, "feeTo received chir");
        assertGt(IERC20(address(detf)).balanceOf(address(detf.protocolNFTVault())), bondVaultBefore, "bond vault received chir");
    }

    function test_previewExchangeIn_chirToWeth_reverts_whenBurningNotAllowed() public {
        uint256 chirAmount = _mintChirFor(detfAlice, 1e16);

        vm.expectRevert();
        IStandardExchangeIn(address(detf)).previewExchangeIn(IERC20(address(detf)), chirAmount, wethToken);
    }

    function test_previewExchangeOut_chirToWeth_reverts_whenBurningNotAllowed() public {
        _mintChirFor(detfAlice, 1e16);

        vm.expectRevert();
        IStandardExchangeOut(address(detf)).previewExchangeOut(IERC20(address(detf)), wethToken, 1e15);
    }

    function test_exchangeIn_wethToRichir_previewIsConservative() public {
        uint256 amountIn = 100e18;
        IERC20 richirToken = IERC20(address(detf.richirToken()));

        vm.prank(detfAlice);
        wethToken.approve(address(detf), amountIn);

        uint256 previewOut = IStandardExchangeIn(address(detf)).previewExchangeIn(wethToken, amountIn, richirToken);

        vm.prank(detfAlice);
        uint256 richirOut = IStandardExchangeIn(address(detf)).exchangeIn(
            wethToken,
            amountIn,
            richirToken,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );

        assertGt(previewOut, 0, "preview nonzero");
        assertGt(richirOut, 0, "richir minted");
        assertLe(previewOut, richirOut, "preview remains conservative");
        assertEq(detf.richirToken().balanceOf(detfAlice), richirOut, "alice richir balance");
    }

    function test_exchangeIn_richToRichir_previewIsConservative() public {
        uint256 amountIn = 100e18;
        IERC20 richirToken = IERC20(address(detf.richirToken()));

        vm.prank(detfAlice);
        richToken.approve(address(detf), amountIn);

        uint256 previewOut = IStandardExchangeIn(address(detf)).previewExchangeIn(richToken, amountIn, richirToken);

        vm.prank(detfAlice);
        uint256 richirOut = IStandardExchangeIn(address(detf)).exchangeIn(
            richToken,
            amountIn,
            richirToken,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );

        assertGt(previewOut, 0, "preview nonzero");
        assertGt(richirOut, 0, "richir minted");
        assertLe(previewOut, richirOut, "preview remains conservative");
        assertEq(detf.richirToken().balanceOf(detfAlice), richirOut, "alice richir balance");
    }

    function test_exchangeIn_chirToWeth_reverts_whenBurningNotAllowed() public {
        _driveToMintEnabled(detf);
        uint256 chirAmount = _mintChirFor(detfAlice, 1e16);

        vm.startPrank(detfAlice);
        IERC20(address(detf)).approve(address(detf), chirAmount);
        vm.expectRevert();
        IStandardExchangeIn(address(detf)).exchangeIn(
            IERC20(address(detf)),
            chirAmount,
            wethToken,
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
        PositionDescriptor descriptor = new PositionDescriptor(poolManager, address(wethToken), bytes32("ETH"));
        positionManager_ = IPositionManager(
            address(
                new PositionManager(
                    poolManager,
                    IAllowanceTransfer(address(permit2)),
                    100_000,
                    descriptor,
                    IWETH9(address(wethToken))
                )
            )
        );

        tokenId_ = positionManager_.nextTokenId();

        _fundWeth(owner_, 1_000e18);
        _fundRich(owner_, 1_000e18);

        vm.startPrank(owner_);
        _approvePositionManager(address(wethToken), positionManager_);
        _approvePositionManager(address(richToken), positionManager_);

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
        IERC721(address(positionManager_)).approve(address(detf.wethRichVault()), tokenId_);
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

    function _mintChirFor(address actor_, uint256 wethAmount_) internal returns (uint256 chirMinted_) {
        _driveToMintEnabled(detf);

        vm.startPrank(actor_);
        wethToken.approve(address(detf), wethAmount_);
        chirMinted_ = detf.mintWithWeth(wethAmount_, actor_, false);
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
                richToken.approve(address(detf_), type(uint256).max);
                IStandardExchangeIn(address(detf_)).exchangeIn(
                    richToken,
                    steps[i],
                    wethToken,
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
