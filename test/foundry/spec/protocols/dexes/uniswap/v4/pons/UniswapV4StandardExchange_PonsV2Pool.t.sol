// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/tokens/ERC721/IERC721.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    IUniswapV4StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";
import {
    TestBase_UniswapV4StandardExchange_PonsV2
} from "contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol";
import {
    GraduationPhase,
    IPonsV2LaunchFactory
} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";

/**
 * @title UniswapV4StandardExchange_PonsV2Pool
 * @notice T10.1–T10.7: Uni V4 SE wraps a pons v2 graduated pool (meme hook, fee 0).
 */
contract UniswapV4StandardExchange_PonsV2Pool is TestBase_UniswapV4StandardExchange_PonsV2 {
    using PoolIdLibrary for PoolKey;

    function test_T10_1_samePoolManager_ponsFactoryAndSePkg() public view {
        assertEq(
            address(ponsV2Factory.poolManager()),
            address(poolManager),
            "T10.1: factory PM != SE PkgInit PM"
        );
        (uint160 sqrtPriceX96,,,) =
            StateLibrary.getSlot0(IPoolManager(address(poolManager)), graduatedPoolKey.toId());
        assertGt(sqrtPriceX96, 0, "T10.1: graduated pool missing on that PM");
    }

    function test_T10_2_graduatedPoolKey_memeHook_feeZero() public view {
        IPonsV2LaunchFactory.LaunchedToken memory rec = ponsV2Factory.getLaunchedToken(launchToken);
        assertEq(uint8(rec.phase), uint8(GraduationPhase.PoolCreated), "T10.2: phase");
        assertEq(address(graduatedPoolKey.hooks), address(ponsV2MemeHook), "T10.2: meme hook");
        assertEq(uint256(graduatedPoolKey.fee), 0, "T10.2: fee == 0");
        assertEq(rec.pairToken, address(weth), "T10.2: WETH quote");
    }

    function test_T10_3_seDeployOnGraduatedKey_registers() public view {
        assertTrue(address(ponsSe) != address(0), "T10.3: vault");
        assertTrue(indexedexManager.isVault(address(ponsSe)), "T10.3: registered");
        address[] memory tokens = IBasicVault(address(ponsSe)).vaultTokens();
        assertEq(tokens.length, 2, "T10.3: two vault tokens");
        bool hasWeth = tokens[0] == address(weth) || tokens[1] == address(weth);
        bool hasLaunch = tokens[0] == launchToken || tokens[1] == launchToken;
        assertTrue(hasWeth, "T10.3: WETH face");
        assertTrue(hasLaunch, "T10.3: launch token face");
    }

    function test_T10_4_previewExchangeIn_eq_exchangeIn_wethToShare() public {
        uint256 amountIn = 1 ether;
        _wrapWeth(address(this), amountIn);
        IERC20(address(weth)).approve(address(ponsSe), amountIn);

        uint256 preview = IStandardExchangeIn(address(ponsSe)).previewExchangeIn(
            IERC20(address(weth)), amountIn, IERC20(address(ponsSe))
        );
        uint256 shares = IStandardExchangeIn(address(ponsSe)).exchangeIn(
            IERC20(address(weth)),
            amountIn,
            IERC20(address(ponsSe)),
            preview,
            address(this),
            false,
            _deadline()
        );
        assertEq(shares, preview, "T10.4: preview != execute");
        assertGt(shares, 0, "T10.4: shares");
    }

    function test_T10_5_previewExchangeOut_eq_exchangeOut() public {
        test_T10_4_previewExchangeIn_eq_exchangeIn_wethToShare();
        uint256 shares = IERC20(address(ponsSe)).balanceOf(address(this));
        uint256 wantOut = shares / 4;
        require(wantOut > 0, "T10.5: need shares");

        IERC20(address(ponsSe)).approve(address(ponsSe), shares);
        uint256 previewIn = IStandardExchangeOut(address(ponsSe)).previewExchangeOut(
            IERC20(address(ponsSe)), IERC20(address(weth)), wantOut
        );
        uint256 used = IStandardExchangeOut(address(ponsSe)).exchangeOut(
            IERC20(address(ponsSe)),
            previewIn,
            IERC20(address(weth)),
            wantOut,
            address(this),
            false,
            _deadline()
        );
        assertEq(used, previewIn, "T10.5: preview != execute");
        assertGt(used, 0, "T10.5: used shares");
    }

    function test_T10_6_swapOnSe_doesNotRevertFromMemeHookFee() public {
        uint256 amountIn = 0.25 ether;
        _wrapWeth(address(this), amountIn);
        IERC20(address(weth)).approve(address(ponsSe), amountIn);

        uint256 out = IStandardExchangeIn(address(ponsSe)).exchangeIn(
            IERC20(address(weth)),
            amountIn,
            IERC20(launchToken),
            0,
            address(this),
            false,
            _deadline()
        );
        assertGt(out, 0, "T10.6: launch token out");
    }

    function test_T10_7_lockerKeepsGraduationNft_seHasOwnPosition() public {
        uint256 lockerNft = ponsV2Locker.lockedPositions(launchToken);
        assertGt(lockerNft, 0, "T10.7: locker nft id");
        assertEq(
            IERC721(address(ponsPositionManager)).ownerOf(lockerNft),
            address(ponsV2Locker),
            "T10.7: locker still owns NFT"
        );

        test_T10_4_previewExchangeIn_eq_exchangeIn_wethToShare();
        IUniswapV4StandardExchangeLiquidReserve liquid =
            IUniswapV4StandardExchangeLiquidReserve(address(ponsSe));
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        if (dep0 + dep1 == 0 && _seLiquidity(address(ponsSe)) == 0) {
            liquid.rebalanceLiquidReserve();
            (dep0, dep1) = liquid.deployedReserve();
        }
        assertTrue(
            dep0 + dep1 > 0 || _seLiquidity(address(ponsSe)) > 0
                || liquid.localReserve(address(weth)) + liquid.localReserve(launchToken) > 0,
            "T10.7: SE own inventory"
        );
        assertEq(
            IERC721(address(ponsPositionManager)).ownerOf(lockerNft),
            address(ponsV2Locker),
            "T10.7: locker NFT unchanged"
        );
    }
}
