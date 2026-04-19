// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {BaseProtocolDETFCommon} from "contracts/vaults/protocol/BaseProtocolDETFCommon.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/**
 * @title IBaseProtocolDETFBonding
 * @notice Interface for Protocol DETF bonding operations.
 */
interface IBaseProtocolDETFBonding {
    /**
     * @notice Returns the accepted bond-token set for the unified bond route.
     * @return tokens The accepted bond tokens.
     */
    function acceptedBondTokens() external view returns (address[] memory tokens);

    /**
     * @notice Returns whether a token is accepted by the unified bond route.
     * @param token The candidate bond token.
     * @return isAccepted True if the token is supported.
     */
    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted);

    /**
     * @notice Creates a bonded position with an accepted bond token.
     * @param tokenIn Accepted bond token
     * @param amountIn Token amount to bond
     * @param lockDuration Lock duration in seconds
     * @param recipient Address to receive the NFT
     * @param wethAsEth Whether to wrap native ETH into WETH before bonding
     * @param deadline Transaction deadline
     * @return tokenId The minted NFT token ID
     * @return shares The underlying share amount
     */
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool wethAsEth, uint256 deadline)
        external
        payable
        returns (uint256 tokenId, uint256 shares);

    /**
     * @notice Captures accumulated seigniorage into the reserve pool.
        * @dev Called periodically to compound only the protocol NFT's accrued CHIR share into LP tokens.
     * @return bptReceived Amount of BPT received
     */
    function captureSeigniorage() external returns (uint256 bptReceived);

    /**
     * @notice Sells a user bond NFT position to the protocol for RICHIR.
     * @dev Canonical Bond NFT → RICHIR route.
    *      - Harvests pending CHIR rewards for `tokenId` and pays them to `recipient`.
     *      - Transfers principal-only shares into the protocol-owned position.
     *      - Burns the sold bond NFT.
     *      - Mints RICHIR against the contributed principal shares.
     * @param tokenId The bond NFT tokenId to sell.
    * @param recipient Address to receive both rewards (CHIR) and minted RICHIR.
     * @return richirMinted Amount of RICHIR minted.
     */
    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 richirMinted);

    /**
     * @notice Converts RICH directly to RICHIR in a single transaction.
     * @dev Deprecated: this route is now exposed via IStandardExchangeIn.exchangeIn.
     */
    /**
     * @notice Donates WETH or CHIR to the protocol-owned NFT.
     * @param token Token to donate (WETH or CHIR)
     * @param amount Amount to donate
     * @param pretransferred Whether tokens were already transferred to the contract
     */
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;

    /**
     * @notice Returns the current synthetic spot price.
     */
    function syntheticPrice() external view returns (uint256);

    /**
     * @notice Returns whether minting is currently allowed.
     */
    function isMintingAllowed() external view returns (bool);

    /**
     * @notice Returns whether burning/redemption is currently allowed.
     */
    function isBurningAllowed() external view returns (bool);
}

/**
 * @title BaseProtocolDETFBondingTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of bonding operations for Protocol DETF.
 * @dev Handles:
 *      - Creating bonded positions with WETH or RICH
 *      - Capturing seigniorage into the reserve pool
 *      - Selling protocol NFT positions for RICHIR
 *      - Donating to protocol-owned NFT
 */
contract BaseProtocolDETFBondingTarget is BaseProtocolDETFCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;

    error EthRefundFailed(address recipient, uint256 amount);

    struct BalancedLiquidityResult {
        uint256 wethUsed;
        uint256 chirUsed;
        uint256 lpMinted;
    }

    struct BalancedVaultDepositResult {
        address pool;
        uint256 chirAmount;
        uint256 chirUsed;
        uint256 wethUsed;
        uint256 lpMinted;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Liquidity Operations                          */
    /* ---------------------------------------------------------------------- */

    /// @notice Claim liquidity from the reserve pool and return WETH.
    function claimLiquidity(uint256 lpAmount, address recipient) external lock returns (uint256 extractedWeth) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        if (msg.sender != address(layout.protocolNFTVault)) {
            revert NotNFTVault(msg.sender);
        }

        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        if (lpAmount == 0) {
            return 0;
        }

        ReservePoolData memory resPoolData;
        (TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);

        uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
        for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
        }

        uint256 minChirWethVaultOut = _calcMinChirWethVaultOutRaw(resPoolData, tokenInfo, balancesLiveScaled18, lpAmount);
        (IERC20 bpt, uint256 chirWethVaultOut) =
            _exitReservePoolToChirWethVault(layout, resPoolData, lpAmount, minChirWethVaultOut);
        (address poolAddr, uint256 lpOut) = _redeemChirWethVaultToAerodromeLp(layout.chirWethVault, chirWethVaultOut);
        (uint256 chirAmount, uint256 wethAmount) = _burnAerodromeLpToChirWeth(layout, poolAddr, lpOut);

        // Send WETH to user.
        if (wethAmount > 0) {
            layout.wethToken.safeTransfer(recipient, wethAmount);
        }
        extractedWeth = wethAmount;

        // Reinvest CHIR back into backing:
        // - deposit CHIR into CHIR/WETH StandardExchange vault
        // - deposit resulting vault tokens into the Balancer reserve pool
        if (chirAmount > 0) {
            _reinvestChir(layout, chirAmount);
        }

        // Keep BasicVault reserve views in-sync with actual BPT balance.
        ERC4626Repo._setLastTotalAssets(bpt.balanceOf(address(this)));
    }

    function _calcMinChirWethVaultOutRaw(
        ReservePoolData memory resPoolData,
        TokenInfo[] memory tokenInfo,
        uint256[] memory balancesLiveScaled18,
        uint256 lpAmount
    ) internal view returns (uint256 minChirWethVaultOut) {
        uint256 minChirWethVaultOutScaled18 =
            BalancerV38020WeightedPoolMath.calcSingleOutGivenBptIn(
                balancesLiveScaled18,
                resPoolData.weightsArray,
                resPoolData.chirWethVaultIndex,
                lpAmount,
                resPoolData.resPoolTotalSupply,
                resPoolData.reservePoolSwapFee
            );

        // Convert liveScaled18 -> raw token units using the token's Balancer rate.
        uint256 chirWethRate = FixedPoint.ONE;
        if (address(tokenInfo[resPoolData.chirWethVaultIndex].rateProvider) != address(0)) {
            chirWethRate = tokenInfo[resPoolData.chirWethVaultIndex].rateProvider.getRate();
        }

        minChirWethVaultOut = FixedPoint.divDown(minChirWethVaultOutScaled18, chirWethRate);
        if (minChirWethVaultOut > 0) {
            // Leave 1 wei slack for rounding differences.
            unchecked {
                minChirWethVaultOut = minChirWethVaultOut - 1;
            }
        }
    }

    function _exitReservePoolToChirWethVault(
        BaseProtocolDETFRepo.Storage storage layout,
        ReservePoolData memory resPoolData,
        uint256 lpAmount,
        uint256 minChirWethVaultOut
    ) internal returns (IERC20 bpt, uint256 chirWethVaultOut) {
        // Approve BPT for Balancer operations (exact allowance; no accumulation).
        bpt = IERC20(address(ERC4626Repo._reserveAsset()));
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        bpt.forceApprove(address(balV3Vault), lpAmount);
        bpt.forceApprove(address(layout.balancerV3PrepayRouter), lpAmount);

        // Single-token exit: receive CHIR/WETH StandardExchange vault tokens only.
        chirWethVaultOut = layout.balancerV3PrepayRouter
            .prepayRemoveLiquiditySingleTokenExactIn(
                address(resPoolData.reservePool),
                lpAmount,
                IERC20(address(layout.chirWethVault)),
                minChirWethVaultOut,
                ""
            );
    }

    function _redeemChirWethVaultToAerodromeLp(IStandardExchange chirWethVault_, uint256 chirWethVaultOut)
        internal
        returns (address poolAddr, uint256 lpOut)
    {
        poolAddr = IERC4626(address(chirWethVault_)).asset();
        lpOut = IERC4626(address(chirWethVault_)).redeem(chirWethVaultOut, address(this), address(this));
    }

    function _burnAerodromeLpToChirWeth(BaseProtocolDETFRepo.Storage storage layout, address poolAddr, uint256 lpOut)
        internal
        returns (uint256 chirAmount, uint256 wethAmount)
    {
        IPool pool = IPool(poolAddr);
        IERC20(poolAddr).safeTransfer(address(pool), lpOut);
        (uint256 amount0, uint256 amount1) = pool.burn(address(this));

        if (pool.token0() == address(layout.wethToken)) {
            wethAmount = amount0;
            chirAmount = amount1;
        } else {
            wethAmount = amount1;
            chirAmount = amount0;
        }
    }

    function _reinvestChir(BaseProtocolDETFRepo.Storage storage layout, uint256 chirAmount) internal {
        IERC20(address(this)).safeTransfer(address(layout.chirWethVault), chirAmount);
        uint256 chirWethShares = layout.chirWethVault
            .exchangeIn(
                IERC20(address(this)),
                chirAmount,
                IERC20(address(layout.chirWethVault)),
                0,
                address(this),
                true,
                block.timestamp
            );

        _addToReservePool(layout, layout.chirWethVaultIndex, chirWethShares, block.timestamp);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Bonding Operations                           */
    /* ---------------------------------------------------------------------- */

    function _depositWethToChirWethVaultViaBalancedLp(
        BaseProtocolDETFRepo.Storage storage layout_,
        uint256 wethAmount_,
        address wethRefundRecipient_,
        bool wethRefundAsEth_,
        uint256 deadline_
    ) internal returns (uint256 vaultShares_) {
        BalancedVaultDepositResult memory result_ = _mintAndAddBalancedChirWethLiquidity(layout_, wethAmount_, deadline_);

        if (result_.chirAmount > result_.chirUsed) {
            ERC20Repo._burn(address(this), result_.chirAmount - result_.chirUsed);
        }

        if (wethAmount_ > result_.wethUsed) {
            _refundUnusedWeth(layout_, wethAmount_ - result_.wethUsed, wethRefundRecipient_, wethRefundAsEth_);
        }

        IERC20(result_.pool).safeTransfer(address(layout_.chirWethVault), result_.lpMinted);
        vaultShares_ = layout_.chirWethVault.exchangeIn(
            IERC20(result_.pool),
            result_.lpMinted,
            IERC20(address(layout_.chirWethVault)),
            0,
            address(this),
            true,
            deadline_
        );
    }

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        return BaseProtocolDETFRepo._acceptedBondTokens();
    }

    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted_) {
        return BaseProtocolDETFRepo._isAcceptedBondToken(address(token));
    }

    function _refundUnusedWeth(
        BaseProtocolDETFRepo.Storage storage layout_,
        uint256 refundAmount_,
        address recipient_,
        bool refundAsEth_
    ) internal {
        if (refundAmount_ == 0) {
            return;
        }

        if (!refundAsEth_) {
            layout_.wethToken.safeTransfer(recipient_, refundAmount_);
            return;
        }

        IWETH(address(layout_.wethToken)).withdraw(refundAmount_);
        (bool success,) = recipient_.call{value: refundAmount_}("");
        if (!success) {
            revert EthRefundFailed(recipient_, refundAmount_);
        }
    }

    function _collectBondInput(
        BaseProtocolDETFRepo.Storage storage layout_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        bool wethAsEth_
    ) internal {
        if (!layout_._isAcceptedBondToken(address(tokenIn_))) {
            revert BondTokenNotSupported(tokenIn_);
        }

        if (wethAsEth_) {
            if (!_isWethToken(layout_, tokenIn_)) {
                revert InvalidEthBondRoute(tokenIn_);
            }
            if (msg.value != amountIn_) {
                revert IncorrectEthValue(amountIn_, msg.value);
            }
            IWETH(address(layout_.wethToken)).deposit{value: amountIn_}();
            return;
        }

        if (msg.value != 0) {
            revert IncorrectEthValue(0, msg.value);
        }

        tokenIn_.safeTransferFrom(msg.sender, address(this), amountIn_);
    }

    function _mintAndAddBalancedChirWethLiquidity(
        BaseProtocolDETFRepo.Storage storage layout_,
        uint256 wethAmount_,
        uint256 deadline_
    ) internal returns (BalancedVaultDepositResult memory result_) {
        deadline_;

        (ChirWethLiquidityQuote memory quote, uint256 chirAmount, uint256 wethUsed) =
            _quoteBalancedChirWethDepositAmounts(layout_, wethAmount_);
        if (chirAmount == 0 || wethUsed == 0) {
            revert ZeroAmount();
        }

        ERC20Repo._mint(address(this), chirAmount);
        BalancedLiquidityResult memory liquidity = _addBalancedChirWethLiquidity(quote, wethUsed, chirAmount);

        result_.pool = quote.pool;
        result_.chirAmount = chirAmount;
        result_.chirUsed = liquidity.chirUsed;
        result_.wethUsed = liquidity.wethUsed;
        result_.lpMinted = liquidity.lpMinted;
    }

    function _addBalancedChirWethLiquidity(
        ChirWethLiquidityQuote memory quote_,
        uint256 wethUsed_,
        uint256 chirAmount_
    )
        internal
        returns (BalancedLiquidityResult memory result_)
    {
        if (quote_.token0 == address(BaseProtocolDETFRepo._layout().wethToken)) {
            IERC20(quote_.token0).safeTransfer(quote_.pool, wethUsed_);
            IERC20(quote_.token1).safeTransfer(quote_.pool, chirAmount_);
        } else {
            IERC20(quote_.token0).safeTransfer(quote_.pool, chirAmount_);
            IERC20(quote_.token1).safeTransfer(quote_.pool, wethUsed_);
        }

        result_.wethUsed = wethUsed_;
        result_.chirUsed = chirAmount_;
        result_.lpMinted = IUniswapV2Pair(quote_.pool).mint(address(this));
    }

    /// @notice Creates a bonded position with an accepted bond token.
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool wethAsEth, uint256 deadline)
        external
        payable
        lock
        returns (uint256 tokenId, uint256 shares)
    {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        if (amountIn == 0) {
            revert ZeroAmount();
        }

        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        _collectBondInput(layout, tokenIn, amountIn, wethAsEth);

        if (_isWethToken(layout, tokenIn)) {
            uint256 chirWethShares = _depositWethToChirWethVaultViaBalancedLp(
                layout,
                amountIn,
                msg.sender,
                wethAsEth,
                deadline
            );
            shares = _addToReservePool(layout, layout.chirWethVaultIndex, chirWethShares, deadline);
        } else if (_isRichToken(layout, tokenIn)) {
            layout.richToken.safeTransfer(address(layout.richChirVault), amountIn);
            uint256 richChirShares = layout.richChirVault.exchangeIn(
                layout.richToken,
                amountIn,
                IERC20(address(layout.richChirVault)),
                0,
                address(this),
                true,
                deadline
            );
            shares = _addToReservePool(layout, layout.richChirVaultIndex, richChirShares, deadline);
        } else {
            revert BondTokenNotSupported(tokenIn);
        }

        tokenId = layout.protocolNFTVault.createPosition(shares, lockDuration, recipient);
    }

    /* ---------------------------------------------------------------------- */
    /*                        Seigniorage Capture                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Captures the protocol NFT's accrued CHIR share into the reserve pool.
    function captureSeigniorage() external lock returns (uint256 bptReceived) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        // Collect only the protocol NFT's accrued reward-token share.
        uint256 chirBalance = layout.protocolNFTVault.reallocateProtocolRewards(address(this));
        if (chirBalance == 0) {
            revert NoSeigniorageToCapture();
        }

        // Add CHIR to CHIR/WETH pool to get vault shares
        IERC20(address(this)).safeTransfer(address(layout.chirWethVault), chirBalance);
        uint256 chirWethShares = layout.chirWethVault
            .exchangeIn(
                IERC20(address(this)),
                chirBalance,
                IERC20(address(layout.chirWethVault)),
                0,
                address(this),
                true,
                block.timestamp
            );

        // Add to reserve pool
        bptReceived = _addToReservePool(layout, layout.chirWethVaultIndex, chirWethShares, block.timestamp);

        // Add BPT to protocol-owned NFT
        layout.protocolNFTVault.addToProtocolNFT(layout.protocolNFTId, bptReceived);
    }

    /// @notice Sells a user bond NFT position to the protocol for RICHIR.
    function sellNFT(uint256 tokenId, address recipient) external lock returns (uint256 richirMinted) {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        (uint256 principalShares,) = layout.protocolNFTVault.sellPositionToProtocol(tokenId, msg.sender, recipient);
        if (principalShares == 0) {
            revert ZeroAmount();
        }

        // Mint RICHIR to recipient - mintFromNFTSale handles share calculation
        richirMinted = layout.richirToken.mintFromNFTSale(principalShares, recipient);
    }

    /// @notice Donates WETH or CHIR to the protocol-owned NFT.
    function donate(IERC20 token, uint256 amount, bool pretransferred) external lock {
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        if (amount == 0) {
            revert ZeroAmount();
        }

        // Only WETH or CHIR can be donated
        if (!_isWethToken(layout, token) && !_isChirToken(token)) {
            revert InvalidDonationToken(token);
        }

        // Transfer tokens from donor if not pretransferred
        if (!pretransferred) {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }

        // If WETH, deposit to vault then add to reserve pool
        if (_isWethToken(layout, token)) {
            // 1. Deposit WETH into CHIR/WETH vault to get vault shares
            token.safeTransfer(address(layout.chirWethVault), amount);
            uint256 vaultShares = layout.chirWethVault
                .exchangeIn(
                    token,
                    amount,
                    IERC20(address(layout.chirWethVault)),
                    0,
                    address(this), // Shares come to this contract
                    true,
                    block.timestamp
                );

            // 2. Add vault shares to reserve pool (get BPT)
            uint256 bptOut = _addToReservePool(layout, layout.chirWethVaultIndex, vaultShares, block.timestamp);

            // 3. Add BPT to protocol NFT position
            IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
            reservePoolToken.forceApprove(address(layout.protocolNFTVault), bptOut);
            layout.protocolNFTVault.addToProtocolNFT(layout.protocolNFTId, bptOut);
        } else {
            // CHIR: burn to reduce supply
            ERC20Repo._burn(address(this), amount);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                          Internal Helpers                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Adds vault shares to the 80/20 reserve pool.
     * @param layout_ Storage layout
     * @param vaultShares Amount of vault shares to add
     * @param deadline_ Transaction deadline
     * @return bptOut Amount of BPT received
     */
    function _addToReservePool(
        BaseProtocolDETFRepo.Storage storage layout_,
        uint256 tokenIndexIn_,
        uint256 vaultShares,
        uint256 deadline_
    ) internal returns (uint256 bptOut) {
        deadline_;
        ReservePoolData memory resPoolData;
        (TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);

        uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
        for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
        }

        uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares, tokenInfo[tokenIndexIn_]);

        // Create deposit amounts array (single-sided deposit)
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[tokenIndexIn_] = vaultShares;

        // Calculate expected BPT
        bptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
            balancesLiveScaled18,
            resPoolData.weightsArray,
            tokenIndexIn_,
            amountInLiveScaled18,
            resPoolData.resPoolTotalSupply,
            resPoolData.reservePoolSwapFee
        );

        // Transfer vault shares to Balancer vault
        IERC20 reserveVaultToken;
        if (tokenIndexIn_ == layout_.chirWethVaultIndex) {
            reserveVaultToken = IERC20(address(layout_.chirWethVault));
        } else if (tokenIndexIn_ == layout_.richChirVaultIndex) {
            reserveVaultToken = IERC20(address(layout_.richChirVault));
        } else {
            revert BaseProtocolDETFRepo.TokenNotSupported();
        }

        reserveVaultToken.safeTransfer(address(resPoolData.balV3Vault), vaultShares);

        // Add liquidity
        layout_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut, "");

        // Keep BasicVault reserve views in-sync with actual BPT balance.
        ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
    }
}
