// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {UNISWAPV2_FEE_PERCENT} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {BaseProtocolDETFCommon} from "contracts/vaults/protocol/BaseProtocolDETFCommon.sol";
import {UniswapV2DualEmbeddedDETFCommon} from 'contracts/protocols/dexes/uniswap/v2/vaults/exchange/standard/detf/dual/embedded/UniswapV2DualEmbeddedDETFCommon.sol';

/**
 * @title EthereumProtocolDETFCommon
 * @notice Uniswap V2-specific overrides for the Ethereum Protocol DETF path.
 * @dev Keeps UniV2 assumptions out of the Base/Aerodrome implementation.
 */
abstract contract EthereumProtocolDETFCommon is UniswapV2DualEmbeddedDETFCommon, BaseProtocolDETFCommon {
    function _loadPoolReserves(BaseProtocolDETFRepo.Storage storage layout_, PoolReserves memory reserves_)
        internal
        view
        virtual
        override
    {
        IUniswapV2Pair chirWethPool = IUniswapV2Pair(address(IERC4626(address(layout_.chirWethVault)).asset()));
        reserves_.chirWethLpTotalSupply = IERC20(address(chirWethPool)).totalSupply();
        reserves_.chirWethFeePercent = UNISWAPV2_FEE_PERCENT;

        (uint256 reserve0, uint256 reserve1,) = chirWethPool.getReserves();
        address token0 = chirWethPool.token0();
        if (token0 == address(this)) {
            reserves_.chirInWethPool = reserve0;
            reserves_.wethReserve = reserve1;
        } else {
            reserves_.chirInWethPool = reserve1;
            reserves_.wethReserve = reserve0;
        }

        IUniswapV2Pair richChirPool = IUniswapV2Pair(address(IERC4626(address(layout_.richChirVault)).asset()));
        reserves_.richChirLpTotalSupply = IERC20(address(richChirPool)).totalSupply();
        reserves_.richChirFeePercent = UNISWAPV2_FEE_PERCENT;

        (reserve0, reserve1,) = richChirPool.getReserves();
        token0 = richChirPool.token0();
        if (token0 == address(layout_.richToken)) {
            reserves_.richReserve = reserve0;
            reserves_.chirInRichPool = reserve1;
        } else {
            reserves_.richReserve = reserve1;
            reserves_.chirInRichPool = reserve0;
        }

        reserves_.chirTotalSupply = ERC20Repo._totalSupply();
        reserves_.chirWethVaultWeight = layout_.chirWethVaultWeight;
        reserves_.richChirVaultWeight = layout_.richChirVaultWeight;
    }

    function _buildCompoundSim(IStandardExchange vault_)
        internal
        view
        virtual
        override
        returns (AeroCompoundSim memory sim)
    {
        address poolAddress = address(IERC4626(address(vault_)).asset());
        IUniswapV2Pair pair = IUniswapV2Pair(poolAddress);
        (sim.reserve0, sim.reserve1,) = pair.getReserves();
        sim.lpTotalSupply = IERC20(poolAddress).totalSupply();
        sim.swapFeePercent = UNISWAPV2_FEE_PERCENT;
        sim.token0 = pair.token0();
    }

    function _poolIsStable(address) internal view virtual override returns (bool stable_) {
        stable_ = false;
    }

    function _poolSwapFeePercent(address) internal view virtual override returns (uint256 feePercent_) {
        feePercent_ = UNISWAPV2_FEE_PERCENT;
    }

    function _poolMetadata(address pool_)
        internal
        view
        virtual
        override
        returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1)
    {
        IUniswapV2Pair pair = IUniswapV2Pair(pool_);
        (r0, r1,) = pair.getReserves();
        t0 = pair.token0();
        t1 = pair.token1();
        dec0 = 10 ** IERC20Metadata(t0).decimals();
        dec1 = 10 ** IERC20Metadata(t1).decimals();
        st = false;
    }
}