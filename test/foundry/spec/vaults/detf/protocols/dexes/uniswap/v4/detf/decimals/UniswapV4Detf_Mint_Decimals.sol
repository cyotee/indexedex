// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @notice T7.6 live mint Gross quote + D11 no DETF into reserve.
abstract contract UniswapV4Detf_Mint_Decimals is TestBase_UniswapV4Detf_Decimals {
    uint256 internal constant ONE_WAD = 1e18;

    function _defaultDetfArgs() internal view override returns (IUniswapV4Detf.PkgArgs memory args) {
        args = super._defaultDetfArgs();
        args.openingPairPerDetfWad = new uint256[](1);
        args.openingPairPerDetfWad[0] = 2.2e18;
    }

    function test_T7_6_liveMint_grossSwapQuote_d11() public {
        _firstBond(_uPair(100));
        uint256 mintIn = _uPair(10);
        assertTrue(detfInfo.isMintingAllowed(IERC20(address(pairToken))), "rich launch selects primary issuance");
        uint256 userPred = IStandardExchangeIn(detf).previewExchangeIn(IERC20(address(pairToken)), mintIn, IERC20(detf));
        uint256 lpPred = IUniswapV4SeBufferHook(reserveHook).previewJoinSingleAssetExactIn(address(pairToken), mintIn);
        assertGt(userPred, 0, "user");
        assertGt(lpPred, 0, "lp preview");

        uint256 p = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        uint256 boosted = Math.mulDiv(mintIn, ONE_WAD + p, ONE_WAD);
        uint256 swapQuote = IUniswapV4SeBufferHook(reserveHook).previewSwapExactIn(
            address(pairToken), detf, boosted
        );
        assertEq(userPred, Math.mulDiv(swapQuote, ONE_WAD - p, ONE_WAD), "ordinary net = floor((1-p) * boosted live quote)");
        uint256 reward = Math.mulDiv(swapQuote, p, ONE_WAD);
        uint256 backingBefore = IERC20(detf).balanceOf(detfInfo.rebasingClaimToken());

        uint256 detfBefore = IERC20(detf).balanceOf(detfUser);
        uint256 nftLpBefore = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault());
        uint256 supplyBefore = IERC20(detf).totalSupply();
        vm.startPrank(detfUser);
        uint256 userDetf = IStandardExchangeIn(address(detfInfo)).exchangeIn(IERC20(address(pairToken)), mintIn, IERC20(address(detfInfo)), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(userDetf, userPred, "preview==exec user");
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore, userDetf, "user DETF");
        uint256 nftLpDelta = IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()) - nftLpBefore;
        assertGt(nftLpDelta, 0, "LP joined");
        assertGe(nftLpDelta, lpPred, "LP delta >= join preview");
        // D11: Gross is minted to the user/pot, not joined as DETF self-leg.
        assertEq(IERC20(detf).balanceOf(detfUser) - detfBefore, userPred, "D11 user Gross split");
        assertEq(IERC20(detf).totalSupply() - supplyBefore, userDetf + reward, "D11 exact new issuance; no matching liquidity DETF");
        assertEq(IERC20(detf).balanceOf(detfInfo.rebasingClaimToken()) - backingBefore, reward, "ordinary reward pot actually funds staking");
        _assertNoJoinableDust();
    }
}
