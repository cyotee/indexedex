// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/tokens/ERC721/IERC721.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    IUniswapV4FullSpreadPonsFamilyHookLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
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
/// @notice Actual bidirectional Pons swaps, including the pool's frozen fee terms.
abstract contract PonsV4QuoteAssertions is Test {
    function _assertPonsSwapQuotes(address se_, IERC20 pair_, IERC20 launch_, uint256 amount_) internal {
        uint256 bought_ = _assertPonsExactIn(se_, pair_, launch_, amount_);
        _assertPonsExactIn(se_, launch_, pair_, bought_ / 4);
        // R2 admits only a one-core-step exact-output plus a placement certificate.
        // Walk down from bought/10000 until that domain accepts a positive amount.
        uint256 desired_ = bought_ / 10_000;
        if (desired_ == 0) desired_ = 1;
        uint256 quote_;
        while (true) {
            try IStandardExchangeOut(se_).previewExchangeOut(pair_, launch_, desired_) returns (uint256 quoted_) {
                quote_ = quoted_;
                break;
            } catch (bytes memory reason_) {
                if (desired_ == 1) {
                    assembly { revert(add(reason_, 0x20), mload(reason_)) }
                }
                desired_ /= 2;
                if (desired_ == 0) desired_ = 1;
            }
        }
        assertGt(quote_, 0);
        uint256 pairBefore_ = pair_.balanceOf(address(this));
        uint256 launchBefore_ = launch_.balanceOf(address(this));
        pair_.approve(se_, quote_);
        uint256 paid_ = IStandardExchangeOut(se_).exchangeOut(pair_, quote_, launch_, desired_, address(this), false, block.timestamp);
        assertEq(paid_, quote_, "exact-output quote includes frozen input-leg hook fee and tax");
        assertEq(pair_.balanceOf(address(this)), pairBefore_ - paid_);
        assertEq(launch_.balanceOf(address(this)), launchBefore_ + desired_);
    }

    function _assertPonsExactIn(address se_, IERC20 in_, IERC20 out_, uint256 amount_) private returns (uint256 received_) {
        uint256 quote_ = IStandardExchangeIn(se_).previewExchangeIn(in_, amount_, out_);
        assertGt(quote_, 0);
        uint256 before_ = out_.balanceOf(address(this));
        uint256 inputBefore_ = in_.balanceOf(address(this));
        in_.approve(se_, amount_);
        vm.expectRevert();
        IStandardExchangeIn(se_).exchangeIn(in_, amount_, out_, quote_ + 1, address(this), false, block.timestamp);
        assertEq(out_.balanceOf(address(this)), before_, "failed minimum rolls back output");
        assertEq(in_.balanceOf(address(this)), inputBefore_, "failed minimum rolls back input");
        assertEq(in_.allowance(address(this), se_), amount_, "failed minimum rolls back allowance");
        received_ = IStandardExchangeIn(se_).exchangeIn(in_, amount_, out_, quote_, address(this), false, block.timestamp);
        assertEq(received_, quote_, "exact-input quote includes frozen output-leg hook fee and tax");
        assertEq(out_.balanceOf(address(this)), before_ + received_);
        assertEq(in_.balanceOf(address(this)), inputBefore_ - amount_);
    }

    /// @dev The old successful two-leg EO inverse is superseded by plan R6, not silently dropped.
    function _assertTwoLegExactOutputRejected(address se_, IERC20 output_, address[9] memory accounts_) internal {
        IUniswapV4FullSpreadPonsFamilyHookLiquidReserve liquid_ = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve(se_);
        address[] memory tokens_ = IBasicVault(se_).vaultTokens();
        (uint256 deployed0_, uint256 deployed1_) = liquid_.deployedReserve();
        assertGt(liquid_.localReserve(tokens_[0]) + deployed0_, 0, "first backing leg");
        assertGt(liquid_.localReserve(tokens_[1]) + deployed1_, 0, "opposite backing leg");
        uint256 maximum_ = IERC20(se_).balanceOf(address(this));
        assertGt(maximum_, 0);
        bytes memory reason_ = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, se_, address(output_));
        bytes32 before_ = _ponsRollbackDigest(se_, address(output_), accounts_);
        vm.expectRevert(reason_);
        IStandardExchangeOut(se_).previewExchangeOut(IERC20(se_), output_, 1);
        assertEq(_ponsRollbackDigest(se_, address(output_), accounts_), before_, "preview state unchanged");
        vm.expectRevert(reason_);
        IStandardExchangeOut(se_).exchangeOut(IERC20(se_), maximum_, output_, 1, address(this), false, block.timestamp);
        assertEq(_ponsRollbackDigest(se_, address(output_), accounts_), before_, "unsupported EO rollback");
    }

    /// @dev Snapshot observable custody, supply, allowances, booking and quoted inventory.
    function _ponsRollbackDigest(address se_, address output_, address[9] memory accounts_) private view returns (bytes32 digest_) {
        (bytes memory state_, uint256 holderAssets_) = IStandardExchangeTransitionQuote(se_).quoteState(output_, address(0));
        digest_ = keccak256(abi.encode(state_, holderAssets_));
        address[] memory tokens_ = IBasicVault(se_).vaultTokens();
        for (uint256 i_; i_ <= tokens_.length; ++i_) {
            IERC20 token_ = IERC20(i_ == tokens_.length ? se_ : tokens_[i_]);
            digest_ = keccak256(abi.encode(digest_, token_.totalSupply(), IBasicVault(se_).reserveOfToken(address(token_))));
            for (uint256 j_; j_ < accounts_.length; ++j_) {
                digest_ = keccak256(abi.encode(digest_, accounts_[j_].balance,
                    token_.balanceOf(accounts_[j_]), token_.allowance(accounts_[j_], se_)));
            }
        }
    }

    /// @dev EI redemption remains supported independently of whether an EO inverse exists.
    function _assertShareExactInParity(address se_, IERC20 output_) internal {
        IERC20 share_ = IERC20(se_);
        uint256 shares_ = share_.balanceOf(address(this)) / 4;
        assertGt(shares_, 0);
        uint256 quote_ = IStandardExchangeIn(se_).previewExchangeIn(share_, shares_, output_);
        assertGt(quote_, 0);
        uint256 supply_ = share_.totalSupply();
        uint256 held_ = share_.balanceOf(address(this));
        uint256 before_ = output_.balanceOf(address(this));
        share_.approve(se_, shares_);
        uint256 paid_ = IStandardExchangeIn(se_).exchangeIn(share_, shares_, output_, quote_, address(this), false, block.timestamp);
        assertEq(paid_, quote_, "EI share redemption parity");
        assertEq(output_.balanceOf(address(this)), before_ + quote_);
        assertEq(share_.balanceOf(address(this)), held_ - shares_);
        assertEq(share_.totalSupply(), supply_ - shares_);
    }
}

contract UniswapV4StandardExchange_PonsV2Pool is TestBase_UniswapV4StandardExchange_PonsV2, PonsV4QuoteAssertions {
    function setUp() public override { super.setUp(); _activatePonsSe(); }
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

    function test_T10_policy_storedZeroInheritsLiveTypeDefault() public {
        IUniswapV4FullSpreadPonsFamilyHookLiquidReserve liquid_ = IUniswapV4FullSpreadPonsFamilyHookLiquidReserve(address(ponsSe));
        IVaultFeeOracleManager oracle_ = IVaultFeeOracleManager(address(indexedexManager));
        assertEq(liquid_.targetLiquidReservePercentage(), 0.2e18);
        vm.startPrank(owner);
        oracle_.setDefaultLiquidReservePercentageOfTypeId(type(IUniswapV4FullSpreadPonsFamilyHookLiquidReserve).interfaceId, 0.3e18);
        assertEq(liquid_.targetLiquidReservePercentage(), 0.3e18);
        oracle_.setLiquidReservePercentageOfVault(address(ponsSe), 0.4e18);
        assertEq(liquid_.targetLiquidReservePercentage(), 0.4e18);
        oracle_.setLiquidReservePercentageOfVault(address(ponsSe), 0);
        assertEq(liquid_.targetLiquidReservePercentage(), 0.3e18, "stored zero inherits type policy");
        vm.stopPrank();
    }

    function test_T10_4_previewExchangeIn_eq_exchangeIn_wethToShare() public {
        // Small-input parity case; execution must still satisfy the fixed composition protections.
        uint256 amountIn = 0.000001 ether;
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

    function test_T10_5_twoLegExactOutput_rejectsAndRollsBack() public {
        uint256 nft_ = ponsV2Locker.lockedPositions(launchToken);
        _assertTwoLegExactOutputRejected(address(ponsSe), IERC20(address(weth)),
            [address(this), address(ponsSe), address(poolManager), address(ponsPositionManager),
             address(ponsV2MemeHook), address(ponsV2FeeEscrow), address(ponsV2BuybackVault), address(ponsV2Locker), ponsV2FeeSink]
        );
        assertEq(ponsV2Locker.lockedPositions(launchToken), nft_);
        assertEq(IERC721(address(ponsPositionManager)).ownerOf(nft_), address(ponsV2Locker));
    }

    function test_T10_5_exactInputShareRedemptionParity() public {
        _assertShareExactInParity(address(ponsSe), IERC20(address(weth)));
    }

    function test_T10_6_swapOnSe_doesNotRevertFromMemeHookFee() public {
        uint256 amount_ = 0.25 ether;
        _wrapWeth(address(this), amount_);
        // A policy change applies only to future launches; this pool retains its frozen cuts.
        vm.prank(ponsV2Owner);
        ponsV2MemeHook.setHookFeeBps(777);
        _assertPonsSwapQuotes(address(ponsSe), IERC20(address(weth)), IERC20(launchToken), amount_);
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
        IUniswapV4FullSpreadPonsFamilyHookLiquidReserve liquid =
            IUniswapV4FullSpreadPonsFamilyHookLiquidReserve(address(ponsSe));
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
