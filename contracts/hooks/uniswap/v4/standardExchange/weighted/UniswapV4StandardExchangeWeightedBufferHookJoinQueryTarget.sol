// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";

import {UniswapV4StandardExchangeWeightedBufferHookJoinCore} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol";

/// @notice Read-only liquidity quotes. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeWeightedBufferHookJoinQueryTarget is UniswapV4StandardExchangeWeightedBufferHookJoinCore {
    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 index = _tokenIndex(pairToken);
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(l.standardExchanges[index], pairToken, tokenIn, amountIn, address(this));
        uint256[] memory inv = _invWadAll();
        inv[index] = Math.scaleTo(q.heldShares, l.invScales[index]);
        uint256 supply = _previewSupplyAfterProtocolMint(inv);
        uint256 fee = _feeOracle().dexSwapFeeOfVault(address(this));
        if (fee >= Math.WAD) revert InvalidFeeWad();
        return _singleJoinExactInSharesOwnerAware(inv, l.weights, index, Math.scaleTo(q.assets, l.invScales[index]), supply, fee);
    }

    function previewJoinProportional(uint256[] calldata amounts)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _entryPreviewJoinProportional(amounts);
    }

    function previewJoinUnbalanced(uint256[] calldata amounts) public view returns (uint256 shares) {
        return _entryPreviewJoinUnbalanced(amounts);
    }

    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinUnbalanced(tokensIn, amounts);
    }

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinSingleAssetExactIn(tokenIn, amountIn);
    }

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewDepositSingle(tokenIn, amountIn);
    }

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        public
        view
        returns (uint256 amountIn)
    {
        return _entryPreviewJoinSingleAssetExactOut(tokenIn, sharesOut);
    }

    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _entryPreviewJoinProportionalFlexible(amounts, amountIsSeShare);
    }

    function previewJoinSingleAssetExactInFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare);
    }

    function previewDepositSingleFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewDepositSingleFlexible(tokenIn, amountIn, amountIsSeShare);
    }

}
