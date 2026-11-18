// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {INonfungiblePositionManager} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {FixedPoint128} from "@crane/contracts/protocols/dexes/uniswap/libraries/FixedPoint128.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from "./UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";
import {UniswapV3FullSpreadStandardExchangeVaultMath as Math} from "./UniswapV3FullSpreadStandardExchangeVaultMath.sol";
import {UniswapV3FullSpreadStandardExchangeVaultRepo as Repo} from "./UniswapV3FullSpreadStandardExchangeVaultRepo.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";

interface IUniswapV3FullSpreadStandardExchangeVaultPositionImport {
    function previewImportPosition(INonfungiblePositionManager positionManager, uint256 positionTokenId)
        external view returns (uint256 sharesOut, uint256 refund0, uint256 refund1);

    function importPosition(
        INonfungiblePositionManager positionManager, uint256 positionTokenId, uint256 minSharesOut,
        address owner, address recipient, uint256 deadline
    ) external returns (uint256 sharesOut);
}

/// @notice Convert an authorized NFT's principal and fees through the ordinary proportional add.
contract UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget is
    UniswapV3FullSpreadStandardExchangeVaultCommon, ReentrancyLockModifiers,
    IUniswapV3FullSpreadStandardExchangeVaultPositionImport
{
    error UniswapV3ExchangeImport_InvalidImportedPool();
    error UniswapV3ExchangeImport_UnauthorizedOwner();

    struct ImportedPosition {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 lower;
        int24 upper;
        uint128 liquidity;
        uint256 growth0;
        uint256 growth1;
        uint128 owed0;
        uint128 owed1;
    }

    function previewImportPosition(INonfungiblePositionManager manager_, uint256 tokenId_)
        external view returns (uint256 sharesOut_, uint256 refund0_, uint256 refund1_)
    {
        ImportedPosition memory position_ = _position(manager_, tokenId_);
        (uint160 price_,,,,,,) = _pool().slot0();
        (uint256 amount0_, uint256 amount1_) = Math.amountsForLiquidity(
            price_, TickMath.getSqrtRatioAtTick(position_.lower), TickMath.getSqrtRatioAtTick(position_.upper),
            position_.liquidity
        );
        (uint256 growth0_, uint256 growth1_) = Planner.feesInside(position_.lower, position_.upper);
        uint128 accrued0_;
        uint128 accrued1_;
        unchecked {
            accrued0_ = uint128(FullMath.mulDiv(growth0_ - position_.growth0, position_.liquidity, FixedPoint128.Q128));
            accrued1_ = uint128(FullMath.mulDiv(growth1_ - position_.growth1, position_.liquidity, FixedPoint128.Q128));
        }
        amount0_ += position_.owed0 + accrued0_;
        amount1_ += position_.owed1 + accrued1_;
        Planner.Plan memory plan_ = Planner.planImport(
            amount0_, amount1_, position_.lower, position_.upper, position_.liquidity
        );
        return (plan_.failed ? 0 : plan_.amountOut, plan_.refund0, plan_.refund1);
    }

    function importPosition(
        INonfungiblePositionManager manager_, uint256 tokenId_, uint256 minimum_,
        address owner_, address recipient_, uint256 deadline_
    ) external nonReentrant returns (uint256 sharesOut_) {
        _deadline(deadline_);
        _requireNotDisabled();
        _recipient(recipient_);
        IERC721 nft_ = IERC721(address(manager_));
        if (nft_.ownerOf(tokenId_) != owner_ || (msg.sender != owner_ && nft_.getApproved(tokenId_) != msg.sender
            && !nft_.isApprovedForAll(owner_, msg.sender))) {
            revert UniswapV3ExchangeImport_UnauthorizedOwner();
        }
        ImportedPosition memory position_ = _position(manager_, tokenId_);
        _requireCanOpenBoundPoolOps();
        // Incumbent destination fees are booked before measuring the source NFT's incoming assets.
        _collectFees();
        uint256 before0_ = IERC20(position_.token0).balanceOf(address(this));
        uint256 before1_ = IERC20(position_.token1).balanceOf(address(this));
        nft_.transferFrom(owner_, address(this), tokenId_);
        if (position_.liquidity != 0) {
            manager_.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId_, liquidity: position_.liquidity, amount0Min: 0, amount1Min: 0, deadline: deadline_
            }));
        }
        manager_.collect(INonfungiblePositionManager.CollectParams({
            tokenId: tokenId_, recipient: address(this), amount0Max: type(uint128).max, amount1Max: type(uint128).max
        }));
        // The real NPM requires both liquidity and owed balances to be zero.
        // Any later failure rolls back this burn and the owner's original NFT transfer.
        manager_.burn(tokenId_);
        uint256 incoming0_ = IERC20(position_.token0).balanceOf(address(this)) - before0_;
        uint256 incoming1_ = IERC20(position_.token1).balanceOf(address(this)) - before1_;
        Repo._layout().reserved[0] = incoming0_;
        Repo._layout().reserved[1] = incoming1_;
        Planner.Plan memory plan_ = Planner.planBundleIn(incoming0_, incoming1_);
        if (plan_.failed) revert IVault.MinLiquidityNotMet();
        if (plan_.amountOut < minimum_) revert IStandardExchangeErrors.AmountOutNotMet(minimum_, plan_.amountOut);
        _add(plan_);
        _mintShares(plan_, recipient_);
        _pay(position_.token0, 0, recipient_, plan_.refund0);
        _pay(position_.token1, 1, recipient_, plan_.refund1);
        _close();
        return plan_.amountOut;
    }

    function _position(INonfungiblePositionManager manager_, uint256 tokenId_)
        private view returns (ImportedPosition memory position_)
    {
        (bool ok_, bytes memory result_) = address(manager_).staticcall(
            abi.encodeCall(INonfungiblePositionManager.positions, (tokenId_))
        );
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        position_ = abi.decode(result_, (ImportedPosition));
        if (position_.token0 != _token0() || position_.token1 != _token1()
            || position_.fee != _pool().fee() || manager_.factory() != _pool().factory()) {
            revert UniswapV3ExchangeImport_InvalidImportedPool();
        }
    }
}
