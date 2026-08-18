// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4SingleStandardExchangeDETFExchangeInTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFExchangeInTarget.sol";
import {
    UniswapV4SingleStandardExchangeDETFBondingTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFBondingTarget.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @dev Combined facet for exchange / bond / info (size-checked in Phase 6).
contract UniswapV4SingleStandardExchangeDETFFacet is
    IFacet,
    UniswapV4SingleStandardExchangeDETFExchangeInTarget,
    UniswapV4SingleStandardExchangeDETFBondingTarget
{
    function facetName() external pure returns (string memory) {
        return "UniswapV4SingleStandardExchangeDETFFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IUniswapV4SingleStandardExchangeDETF).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory) {
        return _allFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "UniswapV4SingleStandardExchangeDETFFacet";
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IUniswapV4SingleStandardExchangeDETF).interfaceId;
        funcs_ = _allFuncs();
    }

    /// @dev Build selector list in two halves to avoid stack-too-deep in pure ABI encoder.
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
        f[2] = IUniswapV4SingleStandardExchangeDETF.bond.selector;
        f[3] = IUniswapV4SingleStandardExchangeDETF.sellPositionToDetfNft.selector;
        f[4] = IUniswapV4SingleStandardExchangeDETF.claimRewards.selector;
        f[5] = IUniswapV4SingleStandardExchangeDETF.redeemClaim.selector;
        f[6] = IUniswapV4SingleStandardExchangeDETF.claimLiquidity.selector;
        f[7] = IUniswapV4SingleStandardExchangeDETF.isReserveLive.selector;
        f[8] = IUniswapV4SingleStandardExchangeDETF.standardExchangeVault.selector;
        f[9] = IUniswapV4SingleStandardExchangeDETF.standardExchangeVaultShare.selector;
        f[10] = IUniswapV4SingleStandardExchangeDETF.pairToken.selector;
        f[11] = IUniswapV4SingleStandardExchangeDETF.reserveHook.selector;
        f[12] = IUniswapV4SingleStandardExchangeDETF.reservePool.selector;
        f[13] = IUniswapV4SingleStandardExchangeDETF.syntheticPrice.selector;
        f[14] = IUniswapV4SingleStandardExchangeDETF.pendingExpansionDetf.selector;
        f[15] = IUniswapV4SingleStandardExchangeDETF.mintThreshold.selector;
    }

    function _funcsB() private pure returns (bytes4[] memory f) {
        f = new bytes4[](17);
        f[0] = IUniswapV4SingleStandardExchangeDETF.burnThreshold.selector;
        f[1] = IUniswapV4SingleStandardExchangeDETF.thresholdMode.selector;
        f[2] = IUniswapV4SingleStandardExchangeDETF.isMintingAllowed.selector;
        f[3] = IUniswapV4SingleStandardExchangeDETF.isBurningAllowed.selector;
        f[4] = IUniswapV4SingleStandardExchangeDETF.bondNftVault.selector;
        f[5] = IUniswapV4SingleStandardExchangeDETF.rebasingClaimToken.selector;
        f[6] = IUniswapV4SingleStandardExchangeDETF.feeRecipientNftId.selector;
        f[7] = IUniswapV4SingleStandardExchangeDETF.creationPairPerDetfWad.selector;
        f[8] = IUniswapV4SingleStandardExchangeDETF.lastExpansionTimestamp.selector;
        f[9] = IUniswapV4SingleStandardExchangeDETF.expansionEpochLength.selector;
        f[10] = IUniswapV4SingleStandardExchangeDETF.expansionClosureRatePerYearWad.selector;
        f[11] = IUniswapV4SingleStandardExchangeDETF.expansionMaxCatchUpEpochs.selector;
        f[12] = IUniswapV4SingleStandardExchangeDETF.acceptedBondTokens.selector;
        f[13] = IUniswapV4SingleStandardExchangeDETF.protocolLp.selector;
        f[14] = IUniswapV4SingleStandardExchangeDETF.userBondedLp.selector;
        f[15] = IUniswapV4SingleStandardExchangeDETF.compoundProtocolRewards.selector;
        f[16] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
    }

    function _funcsC() private pure returns (bytes4[] memory f) {
        f = new bytes4[](4);
        f[0] = IUniswapV4SingleStandardExchangeDETF.isReserveHookFinalized.selector;
        f[1] = IUniswapV4SingleStandardExchangeDETF.isReserveWired.selector;
        f[2] = IUniswapV4SingleStandardExchangeDETF.completeReserveBondNft.selector;
        f[3] = IUniswapV4SingleStandardExchangeDETF.completeReserveClaim.selector;
    }
}
