// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfTarget} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol";
import {UniswapV4DetfCommon} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol";

/// @title UniswapV4DetfFacet
/// @notice Combined product facet for unified Uni V4 DETF.
contract UniswapV4DetfFacet is IFacet, UniswapV4DetfTarget {
    function facetName() external pure override returns (string memory) {
        return "UniswapV4DetfFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IUniswapV4Detf).interfaceId;
    }

    function facetFuncs() external pure override returns (bytes4[] memory) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        override
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4DetfFacet";
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IUniswapV4Detf).interfaceId;
        funcs_ = _allFuncs();
    }

    function _allFuncs() private pure returns (bytes4[] memory funcs_) {
        bytes4[] memory a = _funcsA();
        bytes4[] memory b = _funcsB();
        bytes4[] memory c = _funcsC();
        funcs_ = new bytes4[](a.length + b.length + c.length);
        for (uint256 i; i < a.length; ++i) {
            funcs_[i] = a[i];
        }
        for (uint256 j; j < b.length; ++j) {
            funcs_[a.length + j] = b[j];
        }
        for (uint256 k; k < c.length; ++k) {
            funcs_[a.length + b.length + k] = c[k];
        }
    }

    function _funcsA() private pure returns (bytes4[] memory f) {
        f = new bytes4[](16);
        f[0] = IStandardExchangeIn.exchangeIn.selector;
        f[1] = IStandardExchangeIn.previewExchangeIn.selector;
        f[2] = IUniswapV4Detf.mint.selector;
        f[3] = IUniswapV4Detf.previewMint.selector;
        f[4] = IUniswapV4Detf.burn.selector;
        f[5] = IUniswapV4Detf.previewBurn.selector;
        f[6] = IUniswapV4Detf.bond.selector;
        f[7] = IUniswapV4Detf.closeBondMature.selector;
        f[8] = IUniswapV4Detf.previewCloseBondMature.selector;
        f[9] = IUniswapV4Detf.donate.selector;
        f[10] = IUniswapV4Detf.sweepDust.selector;
        f[11] = IUniswapV4Detf.hook.selector;
        f[12] = IUniswapV4Detf.reservePool.selector;
        f[13] = IUniswapV4Detf.isReserveLive.selector;
        f[14] = IUniswapV4Detf.isReserveWired.selector;
        f[15] = IUniswapV4Detf.mintRoutes.selector;
    }

    function _funcsB() private pure returns (bytes4[] memory f) {
        f = new bytes4[](18);
        f[0] = IUniswapV4Detf.burnRoutes.selector;
        f[1] = IUniswapV4Detf.bondRoutes.selector;
        f[2] = IUniswapV4Detf.closeRoutes.selector;
        f[3] = IUniswapV4Detf.donateRoutes.selector;
        f[4] = IUniswapV4Detf.mintRouteMode.selector;
        f[5] = IUniswapV4Detf.burnRouteMode.selector;
        f[6] = IUniswapV4Detf.bondRouteMode.selector;
        f[7] = IUniswapV4Detf.closeRouteMode.selector;
        f[8] = IUniswapV4Detf.donateRouteMode.selector;
        f[9] = IUniswapV4Detf.creationPairPerDetfWad.selector;
        f[10] = IUniswapV4Detf.openingPairPerDetfWad.selector;
        f[11] = IUniswapV4Detf.mintThreshold.selector;
        f[12] = IUniswapV4Detf.burnThreshold.selector;
        f[13] = IUniswapV4Detf.thresholdMode.selector;
        f[14] = IUniswapV4Detf.syntheticPrice.selector;
        f[15] = IUniswapV4Detf.pendingExpansionDetf.selector;
        f[16] = IUniswapV4Detf.bondNftVault.selector;
        f[17] = IUniswapV4Detf.detfNFTVault.selector;
    }

    function _funcsC() private pure returns (bytes4[] memory f) {
        f = new bytes4[](18);
        f[0] = IUniswapV4Detf.rebasingClaimToken.selector;
        f[1] = IUniswapV4Detf.acceptedBondTokens.selector;
        f[2] = bytes4(keccak256("isMintingAllowed()"));
        f[3] = bytes4(keccak256("isMintingAllowed(address)"));
        f[4] = bytes4(keccak256("isBurningAllowed()"));
        f[5] = bytes4(keccak256("isBurningAllowed(address)"));
        f[6] = IUniswapV4Detf.compoundProtocolRewards.selector;
        f[7] = IUniswapV4Detf.joinDonatedCapital.selector;
        f[8] = IUniswapV4Detf.previewJoinDonatedCapital.selector;
        f[9] = IUniswapV4Detf.notifyReserveDonated.selector;
        f[10] = IUniswapV4Detf.completeReserveBondNft.selector;
        f[11] = IUniswapV4Detf.completeReserveClaim.selector;
        f[12] = UniswapV4DetfTarget.peekPairEq.selector;
        f[13] = UniswapV4DetfCommon.compoundProtocolRewardsAtomic.selector;
        f[14] = UniswapV4DetfCommon.sweepDustAtomic.selector;
        f[15] = UniswapV4DetfCommon.sweepPairToShare.selector;
        f[16] = IUniswapV4Detf.claimLiquidity.selector;
        f[17] = IUniswapV4Detf.previewClaimLiquidity.selector;
    }
}
