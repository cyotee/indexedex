// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol";

/// @notice Liquidity quotes through the shared reserve accounting.
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryTarget is UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore, NativeStandardYieldTarget {
    function previewJoinProportional(uint256[] calldata amounts)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts) {
        return _entryPreviewJoinProportional(amounts);
    }

    function previewJoinUnbalanced(uint256[] calldata amounts) public view returns (uint256 shares) {
        return _entryPreviewJoinUnbalanced(amounts);
    }

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut) public view returns (uint256) {
        return _entryPreviewJoinSingleAssetExactOut(tokenIn, sharesOut);
    }





    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares) {
        return _entryPreviewJoinSingleAssetExactIn(tokenIn, amountIn);
    }

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares) {
        return _entryPreviewDepositSingle(tokenIn, amountIn);
    }







    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata sharesIn)
        external view returns (uint256 shares, uint256[] memory used) {
        return _entryPreviewJoinProportionalFlexible(amounts, sharesIn);
    }



    function previewJoinUnbalanced(address[] calldata tokens_, uint256[] calldata amounts) external view returns (uint256) {
        return _entryPreviewJoinUnbalanced(tokens_, amounts);
    }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }
    /// @notice Existing Stable invariant per active asset, per LP including pending protocol dilution.
    function exchangeRate() external view override returns (uint256) {
        uint256 supply_ = _previewSupplyAfterProtocolMint();
        return supply_ == 0 ? 1e18 : FullMath.mulDiv(_rootKNow(), 1e18, supply_);
    }
    function getTokensIn() public view override returns (address[] memory tokens_) {
        Repo.Layout storage l_ = Repo._layout();
        tokens_ = new address[](uint256(l_.tokens.length) * 2);
        uint256 count_;
        for (uint256 i_; i_ < l_.tokens.length; ++i_) tokens_[count_++] = l_.tokens[i_];
        for (uint256 i_; i_ < l_.tokens.length; ++i_) {
            address se_ = l_.standardExchanges[i_];
            if (se_ == address(0)) continue;
            bool found_;
            for (uint256 j_; j_ < count_; ++j_) if (tokens_[j_] == se_) { found_ = true; break; }
            if (!found_) tokens_[count_++] = se_;
        }
        assembly ("memory-safe") { mstore(tokens_, count_) }
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
}
