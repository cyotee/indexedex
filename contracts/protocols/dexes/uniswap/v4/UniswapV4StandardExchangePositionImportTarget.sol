// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";

import {
    IUniswapV4StandardExchangePositionImport,
    UniswapV4StandardExchangeInTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";
import {
    UniswapV4StandardExchangeInBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol";
import {UniswapV4PositionRepo} from "contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol";

contract UniswapV4StandardExchangePositionImportTarget is
    UniswapV4StandardExchangeInBase,
    IUniswapV4StandardExchangePositionImport
{
    function importPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 sharesOut) {
        if (deadline < block.timestamp) revert UniswapV4ExchangeIn_DeadlineExceeded();
        // D15 / T4e: position import hard-reverts while PoolManager is in-session.
        _requireCanOpenPoolManagerUnlock();
        if (IERC20(address(this)).totalSupply() != 0 || UniswapV4PositionRepo._isPositionCreated()) {
            revert UniswapV4ExchangeIn_PositionImportUnavailable();
        }

        (PoolKey memory poolKey, PositionInfo info) = positionManager.getPoolAndPositionInfo(positionTokenId);
        if (keccak256(abi.encode(poolKey)) != keccak256(abi.encode(_poolKey()))) {
            revert UniswapV4ExchangeIn_InvalidImportedPool();
        }

        uint256 liquidity = positionManager.getPositionLiquidity(positionTokenId);
        if (liquidity == 0) {
            revert UniswapV4Exchange_ZeroAmount();
        }

        sharesOut = _quoteImportedPositionShares(info, uint128(liquidity));
        if (sharesOut < minSharesOut) revert UniswapV4ExchangeIn_SlippageExceeded();

        IERC721(address(positionManager)).transferFrom(owner, address(this), positionTokenId);
        UniswapV4PositionRepo._initializeImportedPosition(
            positionManager, positionTokenId, info.tickLower(), info.tickUpper()
        );
        _refreshStoredLiquidity();
        _syncVaultReserves();
        ERC20Repo._mint(recipient, sharesOut);
    }
}
