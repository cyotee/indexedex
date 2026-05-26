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

import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/core/DETFBondLifecycleLib.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/core/DETFMintSplitLib.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {BaseProtocolDETFCommon} from "contracts/vaults/protocol/BaseProtocolDETFCommon.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/**
 * @title BaseProtocolDETFExchangeInTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of IStandardExchangeIn for Protocol DETF (CHIR).
 * @dev Handles:
 *      - WETH → CHIR (mint when synthetic price is below the lower deadband threshold)
 *      - RICH → CHIR (convert RICH to CHIR using RICH/CHIR pool)
 *      - CHIR → WETH (redeem when synthetic price is above the upper deadband threshold)
 *      - RICHIR → WETH (redeem RICHIR for WETH)
 *      - RICH → RICHIR (bond route via exchangeIn)
 *      - WETH → RICHIR (direct WETH deposit into the CHIR/WETH vault; no CHIR mint)
 *      - WETH → RICH (buy RICH with WETH, multi-hop through CHIR)
 *      - RICH → WETH (sell RICH for WETH, multi-hop through CHIR)
 */
contract BaseProtocolDETFExchangeInTarget is BaseProtocolDETFCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;
    using AddressSetRepo for AddressSet;

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

    struct ExchangeInParams {
        IERC20 tokenIn;
        uint256 amountIn;
        IERC20 tokenOut;
        uint256 minAmountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
        uint256 syntheticPrice;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Exchange In                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Executes an exchange-in operation.
     */
    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external lock returns (uint256 amountOut) {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        if (amountIn == 0) {
            revert ZeroAmount();
        }

        BaseProtocolDETFRepo.Storage storage layoutStruct = BaseProtocolDETFRepo._layoutStruct();

        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        PoolReserves memory reserves;
        _loadPoolReserves(layoutStruct, reserves);

        ExchangeInParams memory params = ExchangeInParams({
            tokenIn: tokenIn,
            amountIn: amountIn,
            tokenOut: tokenOut,
            minAmountOut: minAmountOut,
            recipient: recipient, // == address(0) ? msg.sender : recipient,
            pretransferred: pretransferred,
            deadline: deadline,
            syntheticPrice: _calcSyntheticPrice(reserves)
        });

        /* ------------------------------------------------------------------ */
        /*                         WETH → CHIR (Mint)                         */
        /* ------------------------------------------------------------------ */

        if (_isWethToken(layoutStruct, tokenIn) && _isChirToken(tokenOut)) {
            return _executeMintWithWeth(layoutStruct, params);
        }

        /* ------------------------------------------------------------------ */
        /*                    CHIR → WETH (Below-Peg Redeem)                  */
        /* ------------------------------------------------------------------ */

        if (_isChirToken(tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            return _executeChirRedemption(layoutStruct, params);
        }

        /* ------------------------------------------------------------------ */
        /*                      RICH → CHIR (Sell RICH)                       */
        /* ------------------------------------------------------------------ */

        if (_isRichToken(layoutStruct, tokenIn) && _isChirToken(tokenOut)) {
            return _executeRichToChir(layoutStruct, params);
        }

        /* ------------------------------------------------------------------ */
        /*                     RICHIR → WETH (Redemption)                     */
        /* ------------------------------------------------------------------ */

        if (_isRichirToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            return _executeRichirRedemption(layoutStruct, params);
        }

        /* ------------------------------------------------------------------ */
        /*                      RICH → RICHIR (Single-Call)                   */
        /* ------------------------------------------------------------------ */

        if (_isRichToken(layoutStruct, tokenIn) && _isRichirToken(layoutStruct, tokenOut)) {
            return _executeRichToRichir(layoutStruct, params);
        }

        /* ------------------------------------------------------------------ */
        /*                      WETH → RICHIR (Single-Call)                   */
        /* ------------------------------------------------------------------ */

        if (_isWethToken(layoutStruct, tokenIn) && _isRichirToken(layoutStruct, tokenOut)) {
            return _executeWethToRichir(layoutStruct, params);
        }

        /* ------------------------------------------------------------------ */
        /*                        WETH → RICH (Buy RICH)                      */
        /* ------------------------------------------------------------------ */

        if (_isWethToken(layoutStruct, tokenIn) && _isRichToken(layoutStruct, tokenOut)) {
            return _executeWethToRich(layoutStruct, params);
        }

        /* ------------------------------------------------------------------ */
        /*                       RICH → WETH (Sell RICH)                      */
        /* ------------------------------------------------------------------ */

        if (_isRichToken(layoutStruct, tokenIn) && _isWethToken(layoutStruct, tokenOut)) {
            return _executeRichToWeth(layoutStruct, params);
        }

        /* ------------------------------------------------------------------ */
        /*                      RICHIR → RICH (Local Redeem)                   */
        /* ------------------------------------------------------------------ */

        if (_isRichirToken(layoutStruct, tokenIn) && _isRichToken(layoutStruct, tokenOut)) {
            return _executeRichirToRich(layoutStruct, params);
        }

        revert InvalidToken(tokenIn);
    }

    /* ---------------------------------------------------------------------- */
    /*                       Exchange In Route Handlers                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mints CHIR tokens with WETH deposit.
     * @dev Spec-compliant flow (PROMPT.md lines 713-729):
     *      1. Validate deadline/amount
     *      2. Pull/accept WETH from user
     *      3. Get current live balances from Aerodrome pool
     *      4. Apply seigniorage incentive: add seigniorageIncentivePercentageOfVault to WETH amount
     *      5. Use ConstProdUtils._saleQuote with increased WETH to calculate base CHIR
     *      6. Split seigniorage: user gets base*(1-pct/2), protocol NFT gets base*(pct/2)
     *      7. Deposit WETH -> CHIR/WETH vault -> get shares
     *      8. Deposit vault shares -> Balancer reserve pool -> get BPT
     *      9. Add BPT to Protocol NFT position (reserve backing)
     *      10. Mint CHIR reward to Protocol NFT (seigniorage)
     *      11. Mint CHIR to user
     *      12. Return total CHIR to user
     */
    function _executeMintWithWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        if (!_isMintingAllowed(layoutStruct_, p_.syntheticPrice)) {
            revert MintingNotAllowed(p_.syntheticPrice, layoutStruct_.mintThreshold);
        }

        // Secure WETH transfer
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);

        // Step 3-6: Get pool data and calculate CHIR amounts
        MintCalc memory calc = _calcMintFromWeth(layoutStruct_, actualIn);

        // Step 7: Deposit WETH into CHIR/WETH vault (capture shares)
        p_.tokenIn.safeTransfer(address(layoutStruct_.chirWethVault), actualIn);
        uint256 chirWethShares = layoutStruct_.chirWethVault.exchangeIn(
            p_.tokenIn, actualIn, IERC20(address(layoutStruct_.chirWethVault)), 0, address(this), true, p_.deadline
        );

        // Step 8-9: Deposit vault shares to Balancer reserve pool -> BPT -> add to protocol NFT
        if (chirWethShares > 0) {
            _unbalancedDepositChirWethAndAddToProtocolNFT(layoutStruct_, chirWethShares);
        }

        // Step 10: Check minAmountOut against final user amount (AFTER adding discount)
        if (calc.userChir < p_.minAmountOut) {
            revert SlippageExceeded(p_.minAmountOut, calc.userChir);
        }

        // Step 11: Mint CHIR to the NFT vault as reward-token accrual
        if (calc.protocolChir > 0) {
            ERC20Repo._mint(address(layoutStruct_.protocolNFTVault), calc.protocolChir);
        }

        // Step 12: Mint CHIR to user
        ERC20Repo._mint(p_.recipient, calc.userChir);

        amountOut_ = calc.userChir;
    }

    struct MintCalc {
        uint256 userChir;
        uint256 protocolChir;
    }

    function _calcMintFromWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 actualIn_)
        internal
        view
        returns (MintCalc memory calc_)
    {
        // Get CHIR/WETH pool reserves
        IUniswapV2Pair chirWethPool = IUniswapV2Pair(address(IERC4626(address(layoutStruct_.chirWethVault)).asset()));
        (uint256 reserve0, uint256 reserve1,) = chirWethPool.getReserves();
        address token0 = chirWethPool.token0();

        uint256 wethReserve;
        uint256 chirReserve;
        if (token0 == address(layoutStruct_.wethToken)) {
            wethReserve = reserve0;
            chirReserve = reserve1;
        } else {
            wethReserve = reserve1;
            chirReserve = reserve0;
        }

        // Get swap fee from pool
        uint256 swapFeePercent = _poolSwapFeePercent(address(chirWethPool));

        // Apply seigniorage incentive - increase WETH amount
        uint256 seignioragePct = layoutStruct_._feeOracle().seigniorageIncentivePercentageOfVault(address(this));
        uint256 wethWithIncentive = actualIn_ + (actualIn_ * seignioragePct / FixedPoint.ONE);

        // Use ConstProdUtils._saleQuote to calculate base CHIR
        uint256 baseChir =
            ConstProdUtils._saleQuote(wethWithIncentive, wethReserve, chirReserve, swapFeePercent);

        // Split seigniorage 50/50 between the user-facing mint amount and protocol inventory.
        (calc_.userChir, calc_.protocolChir) = DETFMintSplitLib._splitHalfSeigniorage(baseChir, seignioragePct);
    }

    /**
     * @notice Converts RICH to CHIR via Aerodrome swaps, then mints CHIR from WETH.
     * @dev Flow: RICH -> CHIR (RICH/CHIR pool) -> WETH (CHIR/WETH pool) -> CHIR mint.
     */
    function _executeRichToChir(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        if (!_isMintingAllowed(layoutStruct_, p_.syntheticPrice)) {
            revert MintingNotAllowed(p_.syntheticPrice, layoutStruct_.mintThreshold);
        }

        // Secure RICH transfer
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);

        // Swap RICH -> CHIR using the RICH/CHIR Standard Exchange vault (Aerodrome router).
        p_.tokenIn.safeTransfer(address(layoutStruct_.richChirVault), actualIn);

        uint256 chirOut = layoutStruct_.richChirVault
            .exchangeIn(p_.tokenIn, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);

        // Swap CHIR -> WETH using the CHIR/WETH Standard Exchange vault (Aerodrome router).
        IERC20(address(this)).safeTransfer(address(layoutStruct_.chirWethVault), chirOut);
        uint256 wethOut = layoutStruct_.chirWethVault
            .exchangeIn(IERC20(address(this)), chirOut, layoutStruct_.wethToken, 0, address(this), true, p_.deadline);

        // Mint CHIR from WETH using the canonical route.
        ExchangeInParams memory mintParams = ExchangeInParams({
            tokenIn: layoutStruct_.wethToken,
            amountIn: wethOut,
            tokenOut: IERC20(address(this)),
            minAmountOut: p_.minAmountOut,
            recipient: p_.recipient,
            pretransferred: true,
            deadline: p_.deadline,
            syntheticPrice: p_.syntheticPrice
        });

        amountOut_ = _executeMintWithWeth(layoutStruct_, mintParams);
    }

    /**
     * @notice Redeems RICHIR for WETH.
     * @dev Always redeemable - no price gate. Flow:
     *      1. Burn RICHIR (done first to maintain secure state)
     *      2. Calculate BPT claim (RICHIR shares → BPT amount)
     *      3. Proportional exit from reserve pool (BPT → vault shares)
     *      4. Redeem RICH/CHIR vault shares for LP tokens
     *      5. Burn LP → RICH + CHIR
     *      6. Deposit RICH → RICH/CHIR vault shares
     *      7. Unbalanced deposit to reserve pool → BPT
     *      8. Add BPT to Protocol NFT
     *      9. Swap CHIR → WETH (max liquidity present for best price)
     *      10. Redeem CHIR/WETH vault shares → WETH
     *      11. Send WETH to user
     *
     *      IMPORTANT: RICH recycling (steps 4-8) ensures RICHIR never runs short of BPT.
     *      CHIR swap (step 9) happens while maximum liquidity is present for optimal pricing.
     *
     *      IMPORTANT: RICHIR must be burned BEFORE exiting the reserve pool,
     *      because the exit changes the protocol NFT's BPT, which changes the
     *      RICHIR rate, which changes balances.
     */
    function _executeRichirRedemption(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        if (!p_.pretransferred) {
            p_.tokenIn.safeTransferFrom(msg.sender, address(this), p_.amountIn);
        }

        // Get actual RICHIR balance (may differ from p_.amountIn due to rebasing)
        uint256 richirBalance = p_.tokenIn.balanceOf(address(this));

        // Step 2: Calculate BPT to exit BEFORE burning (rate still reflects current state)
        uint256 bptIn = _calcRichirRedemptionBptIn(layoutStruct_, richirBalance);

        // Step 1: Burn RICHIR FIRST, before exiting the reserve pool
        // This is critical because the exit changes protocolNftBpt, which changes rate
        p_.tokenIn.safeTransfer(address(layoutStruct_.richirToken), richirBalance);
        layoutStruct_.richirToken.burnShares(richirBalance, address(0), true);

        // Steps 3-10: Exit reserve pool, recycle RICH, swap CHIR → WETH
        amountOut_ = _exitRecycleAndUnwindToWeth(layoutStruct_, bptIn, p_.deadline);

        // Slippage check against user's minAmountOut
        if (amountOut_ < p_.minAmountOut) {
            revert SlippageExceeded(p_.minAmountOut, amountOut_);
        }

        // Step 11: Send WETH to recipient
        layoutStruct_.wethToken.safeTransfer(p_.recipient, amountOut_);
    }

    /**
     * @notice Calculates BPT amount to exit for RICHIR redemption.
     * @dev bptIn = (richirShares / totalRichirShares) * protocolNftBpt
     */
    function _calcRichirRedemptionBptIn(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 richirAmount_)
        internal
        view
        returns (uint256 bptIn_)
    {
        uint256 richirShares = layoutStruct_.richirToken.convertToShares(richirAmount_);
        uint256 totalRichirShares = layoutStruct_.richirToken.totalShares();
        uint256 protocolNftBpt = layoutStruct_.protocolNFTVault.originalSharesOf(layoutStruct_.protocolNFTId);
        bptIn_ = (richirShares * protocolNftBpt) / totalRichirShares;
    }

    /**
     * @notice Exits reserve pool, recycles RICH back into the reserve, then unwinds to WETH.
     * @dev Implements steps 3-10 of the RICHIR redemption flow:
     *      3. Proportional exit from reserve pool → CHIR/WETH vault shares + RICH/CHIR vault shares
     *      4. Redeem RICH/CHIR vault shares → LP tokens
     *      5. Burn LP → RICH + CHIR
     *      6. Deposit RICH → RICH/CHIR vault shares
     *      7. Unbalanced deposit to reserve pool → BPT
     *      8. Add BPT to Protocol NFT
     *      9. Swap CHIR → WETH (while max liquidity present)
     *      10. Redeem CHIR/WETH vault shares → WETH
     */
    function _exitRecycleAndUnwindToWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 bptIn_, uint256 deadline_)
        internal
        returns (uint256 wethOut_)
    {
        // Step 3: Proportional exit from reserve pool
        (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _exitReservePoolProportional(layoutStruct_, bptIn_);

        // Steps 4-8: Recycle RICH back into reserve pool
        uint256 chirFromRecycle = _recycleRichToReservePool(layoutStruct_, richChirVaultSharesOut, deadline_);

        // Step 9: Swap CHIR → WETH (max liquidity present for best price)
        uint256 wethFromChirSwap = _swapChirToWethViaChirWethVault(layoutStruct_, chirFromRecycle, deadline_);

        // Step 10: Redeem CHIR/WETH vault shares → WETH
        uint256 wethFromChirWeth = _unwindChirWethVaultToWeth(layoutStruct_, chirWethVaultSharesOut, deadline_);

        wethOut_ = wethFromChirWeth + wethFromChirSwap;
    }

    /**
     * @notice Recycles RICH from LP burn back into the reserve pool.
     * @dev Steps 4-8:
     *      4. Redeem RICH/CHIR vault shares → LP tokens
     *      5. Burn LP → RICH + CHIR
     *      6. Deposit RICH → RICH/CHIR vault shares
     *      7. Unbalanced deposit to reserve pool → BPT
     *      8. Add BPT to Protocol NFT
     * @return chirOut_ CHIR received from the LP burn (not recycled)
     */
    function _recycleRichToReservePool(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 richChirVaultSharesIn_,
        uint256 deadline_
    ) internal returns (uint256 chirOut_) {
        // Step 4: Redeem RICH/CHIR vault shares → LP tokens
        uint256 lpTokens = _redeemRichChirVaultToLP(layoutStruct_, richChirVaultSharesIn_, deadline_);

        // Step 5: Burn LP → RICH + CHIR
        (uint256 richOut, uint256 chirFromBurn) = _burnRichChirLP(layoutStruct_, lpTokens);

        // Step 6: Deposit RICH → RICH/CHIR vault shares
        uint256 newVaultShares = _depositRichToRichChirVault(layoutStruct_, richOut, deadline_);

        // Steps 7-8: Unbalanced deposit to reserve pool → BPT → add to Protocol NFT
        _unbalancedDepositAndAddToProtocolNFT(layoutStruct_, newVaultShares);

        // Return CHIR for later swap
        chirOut_ = chirFromBurn;
    }

    /**
     * @notice Redeems RICH/CHIR vault shares for the underlying LP tokens.
     * @dev Step 4: vault shares → LP tokens via exchangeIn(vaultToken, amount, lpToken, ...)
     */
    function _redeemRichChirVaultToLP(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 vaultSharesIn_,
        uint256 deadline_
    ) internal returns (uint256 lpOut_) {
        IERC20 vaultToken = IERC20(address(layoutStruct_.richChirVault));
        // Get the LP token (underlying asset) from the vault
        IERC20 lpToken = IERC20(IERC4626(address(layoutStruct_.richChirVault)).asset());

        vaultToken.forceApprove(address(layoutStruct_.richChirVault), vaultSharesIn_);
        lpOut_ =
            layoutStruct_.richChirVault.exchangeIn(vaultToken, vaultSharesIn_, lpToken, 0, address(this), false, deadline_);
    }

    /**
     * @notice Burns RICH/CHIR LP tokens to receive RICH and CHIR proportionally.
     * @dev Step 5: Transfer LP to pool, call burn(address) to get both tokens.
     *      V2-style pairs return (amount0, amount1) sorted by address.
     */
    function _burnRichChirLP(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 lpAmount_)
        internal
        returns (uint256 richOut_, uint256 chirOut_)
    {
        // Get the LP token (pool) address
        IUniswapV2Pair pool = IUniswapV2Pair(address(IERC4626(address(layoutStruct_.richChirVault)).asset()));

        // Transfer LP tokens to the pool
        IERC20(address(pool)).safeTransfer(address(pool), lpAmount_);

        // Call burn - V2 pairs burn LP when it's sent to the pair, then return tokens to `to`
        (uint256 amount0, uint256 amount1) = pool.burn(address(this));

        // Sort amounts by token order (token0 has lower address)
        address token0 = pool.token0();
        if (token0 == address(layoutStruct_.richToken)) {
            richOut_ = amount0;
            chirOut_ = amount1;
        } else {
            richOut_ = amount1;
            chirOut_ = amount0;
        }
    }

    /**
     * @notice Deposits RICH into the RICH/CHIR vault to get vault shares.
     * @dev Step 6: RICH → vault shares via exchangeIn(RICH, amount, vaultToken, ...)
     */
    function _depositRichToRichChirVault(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 richIn_, uint256 deadline_)
        internal
        returns (uint256 vaultSharesOut_)
    {
        IERC20 richToken = layoutStruct_.richToken;
        IERC20 vaultToken = IERC20(address(layoutStruct_.richChirVault));

        richToken.forceApprove(address(layoutStruct_.richChirVault), richIn_);
        vaultSharesOut_ =
            layoutStruct_.richChirVault.exchangeIn(richToken, richIn_, vaultToken, 0, address(this), false, deadline_);
    }

    /**
     * @notice Performs unbalanced deposit to reserve pool and adds BPT to Protocol NFT.
     * @dev Steps 7-8:
     *      7. Unbalanced deposit of RICH/CHIR vault shares → BPT
     *      8. Add BPT to Protocol NFT
     */
    function _unbalancedDepositAndAddToProtocolNFT(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 richChirVaultShares_
    ) internal {
        IWeightedPool pool = _reservePool();
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();

        // Build amounts array (only RICH/CHIR vault index has value)
        uint256[] memory exactAmountsIn = new uint256[](2);
        exactAmountsIn[layoutStruct_.richChirVaultIndex] = richChirVaultShares_;
        exactAmountsIn[layoutStruct_.chirWethVaultIndex] = 0;

        // Approve vault shares to Balancer vault
        IERC20(address(layoutStruct_.richChirVault)).safeTransfer(address(balV3Vault), richChirVaultShares_);

        // Step 7: Unbalanced deposit to reserve pool
        uint256 bptOut = layoutStruct_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(
                address(pool),
                exactAmountsIn,
                0, // minBptOut - we accept any amount since we're recycling
                ""
            );

        // Step 8: Add BPT to Protocol NFT
        if (bptOut > 0) {
            DETFBondLifecycleLib._addReservePoolBptToProtocolNft(
                IERC20(address(pool)), layoutStruct_.protocolNFTVault, layoutStruct_.protocolNFTId, bptOut
            );
        }
    }

    /**
     * @notice Performs unbalanced deposit of CHIR/WETH vault shares to reserve pool and adds BPT to Protocol NFT.
     * @dev Similar to _unbalancedDepositAndAddToProtocolNFT but for CHIR/WETH vault shares.
     */
    function _unbalancedDepositChirWethAndAddToProtocolNFT(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 chirWethVaultShares_
    ) internal {
        IWeightedPool pool = _reservePool();
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();

        // Build amounts array (only CHIR/WETH vault index has value)
        uint256[] memory exactAmountsIn = new uint256[](2);
        exactAmountsIn[layoutStruct_.chirWethVaultIndex] = chirWethVaultShares_;
        exactAmountsIn[layoutStruct_.richChirVaultIndex] = 0;

        // Approve vault shares to Balancer vault
        IERC20(address(layoutStruct_.chirWethVault)).safeTransfer(address(balV3Vault), chirWethVaultShares_);

        // Unbalanced deposit to reserve pool
        uint256 bptOut = layoutStruct_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(
                address(pool),
                exactAmountsIn,
                0, // minBptOut - we accept any amount since we're recycling
                ""
            );

        // Add BPT to Protocol NFT
        if (bptOut > 0) {
            DETFBondLifecycleLib._addReservePoolBptToProtocolNft(
                IERC20(address(pool)), layoutStruct_.protocolNFTVault, layoutStruct_.protocolNFTId, bptOut
            );
        }
    }

    /**
     * @notice Legacy function for CHIR redemption - exits and unwinds both vaults to WETH.
     * @dev Used by _executeChirRedemption which doesn't need RICH recycling.
     */
    function _exitAndUnwindToWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 bptIn_, uint256 deadline_)
        internal
        returns (uint256 wethOut_)
    {
        (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _exitReservePoolProportional(layoutStruct_, bptIn_);

        uint256 wethFromChirWeth = _unwindChirWethVaultToWeth(layoutStruct_, chirWethVaultSharesOut, deadline_);
        uint256 chirFromRichChir = _unwindRichChirVaultToChir(layoutStruct_, richChirVaultSharesOut, deadline_);
        uint256 wethFromChirSwap = _swapChirToWethViaChirWethVault(layoutStruct_, chirFromRichChir, deadline_);

        wethOut_ = wethFromChirWeth + wethFromChirSwap;
    }

    /**
     * @notice Redeems CHIR for WETH when below peg.
     * @dev Burns CHIR, exits the reserve pool proportionally against protocol-held BPT,
     *      then unwinds both reserve vault tokens into WETH.
     */
    function _executeChirRedemption(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        if (!_isBurningAllowed(layoutStruct_, p_.syntheticPrice)) {
            revert BurningNotAllowed(p_.syntheticPrice, layoutStruct_.burnThreshold);
        }

        uint256 bptIn = _previewChirRedemptionBptIn(p_.amountIn);

        // Burn CHIR first (reduces supply) after using totalSupply for pricing.
        _secureChirBurn(msg.sender, p_.amountIn, p_.pretransferred);

        (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) = _exitReservePoolProportional(layoutStruct_, bptIn);

        uint256 wethFromChirWeth = _unwindChirWethVaultToWeth(layoutStruct_, chirWethVaultSharesOut, p_.deadline);
        uint256 chirFromRichChir = _unwindRichChirVaultToChir(layoutStruct_, richChirVaultSharesOut, p_.deadline);
        uint256 wethFromChirSwap = _swapChirToWethViaChirWethVault(layoutStruct_, chirFromRichChir, p_.deadline);

        amountOut_ = wethFromChirWeth + wethFromChirSwap;

        if (amountOut_ < p_.minAmountOut) {
            revert SlippageExceeded(p_.minAmountOut, amountOut_);
        }

        layoutStruct_.wethToken.safeTransfer(p_.recipient, amountOut_);
    }

    function _exitReservePoolProportional(BaseProtocolDETFRepo.Storage storage layoutStruct_, uint256 bptIn_)
        internal
        returns (uint256 chirWethVaultSharesOut_, uint256 richChirVaultSharesOut_)
    {
        IWeightedPool pool = _reservePool();
        // Balancer V3 prepay remove-liquidity burns BPT from `params.sender` (the caller).
        // Do NOT pre-transfer BPT to the vault; instead, approve the prepay router to pull/burn it.
        IERC20(address(pool)).forceApprove(address(layoutStruct_.balancerV3PrepayRouter), bptIn_);
        uint256[] memory minAmountsOut = new uint256[](2);
        uint256[] memory amountsOut =
            layoutStruct_.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(address(pool), bptIn_, minAmountsOut, "");

        chirWethVaultSharesOut_ = amountsOut[layoutStruct_.chirWethVaultIndex];
        richChirVaultSharesOut_ = amountsOut[layoutStruct_.richChirVaultIndex];
    }

    function _unwindChirWethVaultToWeth(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 chirWethVaultSharesIn_,
        uint256 deadline_
    ) internal returns (uint256 wethOut_) {
        IERC20 chirWethVaultToken = IERC20(address(layoutStruct_.chirWethVault));
        chirWethVaultToken.forceApprove(address(layoutStruct_.chirWethVault), chirWethVaultSharesIn_);
        wethOut_ = layoutStruct_.chirWethVault
            .exchangeIn(
                chirWethVaultToken, chirWethVaultSharesIn_, layoutStruct_.wethToken, 0, address(this), false, deadline_
            );
    }

    function _unwindRichChirVaultToChir(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 richChirVaultSharesIn_,
        uint256 deadline_
    ) internal returns (uint256 chirOut_) {
        IERC20 richChirVaultToken = IERC20(address(layoutStruct_.richChirVault));
        richChirVaultToken.forceApprove(address(layoutStruct_.richChirVault), richChirVaultSharesIn_);
        chirOut_ = layoutStruct_.richChirVault
            .exchangeIn(
                richChirVaultToken, richChirVaultSharesIn_, IERC20(address(this)), 0, address(this), false, deadline_
            );
    }

    function _swapChirToWethViaChirWethVault(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 chirIn_,
        uint256 deadline_
    ) internal returns (uint256 wethOut_) {
        IERC20(address(this)).forceApprove(address(layoutStruct_.chirWethVault), chirIn_);
        wethOut_ = layoutStruct_.chirWethVault
            .exchangeIn(IERC20(address(this)), chirIn_, layoutStruct_.wethToken, 0, address(this), false, deadline_);
    }

    function _previewChirRedemptionBptIn(uint256 amountIn_) internal view virtual returns (uint256 bptIn_) {
        uint256 chirTotalSupply = ERC20Repo._totalSupply();
        if (chirTotalSupply == 0) {
            revert ZeroAmount();
        }

        uint256 bptHeld = IERC20(address(_reservePool())).balanceOf(address(this));
        if (bptHeld == 0) {
            revert ZeroAmount();
        }

        bptIn_ = (amountIn_ * bptHeld) / chirTotalSupply;
        if (bptIn_ == 0) {
            revert ZeroAmount();
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                      RICH → RICHIR Route Handlers                     */
    /* ---------------------------------------------------------------------- */

    /**
      * @notice Executes RICH → RICHIR conversion via exchangeIn route.
      * @dev Atomically: RICH → vault shares → BPT → protocol NFT → mint RICHIR.
    *      This is equivalent to bonding with RICH via the unified bond route (min lock duration) followed by
      *      immediate `sellNFT`, but accessible via the IStandardExchangeIn interface.
      * @param layoutStruct_ Storage layoutStruct reference
      * @param p_ Exchange parameters
      * @return amountOut_ Amount of RICHIR minted
      */
    function _executeRichToRichir(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Secure RICH transfer
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);

        // Deposit RICH into RICH/CHIR vault to get LP shares
        p_.tokenIn.safeTransfer(address(layoutStruct_.richChirVault), actualIn);
        uint256 richChirShares = layoutStruct_.richChirVault
            .exchangeIn(
                p_.tokenIn, actualIn, IERC20(address(layoutStruct_.richChirVault)), 0, address(this), true, p_.deadline
            );

        // Add LP shares to 80/20 reserve pool (get BPT)
        uint256 bptOut = _addToReservePoolForRichir(layoutStruct_, richChirShares, p_.deadline);

        // Add BPT directly to protocol-owned NFT (no user NFT created)
        IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
        DETFBondLifecycleLib._addReservePoolBptToProtocolNft(
            reservePoolToken, layoutStruct_.protocolNFTVault, layoutStruct_.protocolNFTId, bptOut
        );

        // Mint RICHIR to recipient (1:1 with BPT added to protocol NFT)
        amountOut_ = layoutStruct_.richirToken.mintFromNFTSale(bptOut, p_.recipient);

        if (amountOut_ < p_.minAmountOut) {
            revert SlippageExceeded(p_.minAmountOut, amountOut_);
        }
    }

    /**
     * @notice Adds RICH/CHIR vault shares to the reserve pool for RICHIR minting.
     * @dev Uses the same logic as _addToReservePool in BondingTarget but localized here
     *      to avoid cross-facet calls.
     * @param layoutStruct_ Storage layoutStruct reference
     * @param vaultShares_ Amount of vault shares to add
     * @param deadline_ Transaction deadline (unused but kept for consistency)
     * @return bptOut_ Amount of BPT received
     */
    function _addToReservePoolForRichir(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 vaultShares_,
        uint256 deadline_
    ) internal returns (uint256 bptOut_) {
        deadline_; // Silence unused variable warning
        ReservePoolData memory resPoolData;
        (TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);

        uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
        for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
        }

        uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[layoutStruct_.richChirVaultIndex]);

        // Create deposit amounts array (single-sided deposit)
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[layoutStruct_.richChirVaultIndex] = vaultShares_;

        // Calculate expected BPT
        bptOut_ = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
            balancesLiveScaled18,
            resPoolData.weightsArray,
            layoutStruct_.richChirVaultIndex,
            amountInLiveScaled18,
            resPoolData.resPoolTotalSupply,
            resPoolData.reservePoolSwapFee
        );

        // Transfer vault shares to Balancer vault
        IERC20(address(layoutStruct_.richChirVault)).safeTransfer(address(resPoolData.balV3Vault), vaultShares_);

        // Add liquidity
        layoutStruct_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut_, "");

        // Keep BasicVault reserve views in-sync with actual BPT balance
        ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
    }

    /* ---------------------------------------------------------------------- */
    /*                      WETH → RICHIR Route Handlers                      */
    /* ---------------------------------------------------------------------- */

    function _depositWethToChirWethVaultViaBalancedLp(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 wethAmount_,
        address wethRefundRecipient_,
        uint256 deadline_
    ) internal returns (uint256 vaultShares_) {
        BalancedVaultDepositResult memory result_ = _mintAndAddBalancedChirWethLiquidity(layoutStruct_, wethAmount_, deadline_);

        if (result_.chirAmount > result_.chirUsed) {
            ERC20Repo._burn(address(this), result_.chirAmount - result_.chirUsed);
        }

        if (wethAmount_ > result_.wethUsed) {
            layoutStruct_.wethToken.safeTransfer(wethRefundRecipient_, wethAmount_ - result_.wethUsed);
        }

        IERC20(result_.pool).safeTransfer(address(layoutStruct_.chirWethVault), result_.lpMinted);
        vaultShares_ = layoutStruct_.chirWethVault.exchangeIn(
            IERC20(result_.pool),
            result_.lpMinted,
            IERC20(address(layoutStruct_.chirWethVault)),
            0,
            address(this),
            true,
            deadline_
        );
    }

    function _mintAndAddBalancedChirWethLiquidity(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 wethAmount_,
        uint256 deadline_
    ) internal returns (BalancedVaultDepositResult memory result_) {
        deadline_;

        (ChirWethLiquidityQuote memory quote, uint256 chirAmount, uint256 wethUsed) =
            _quoteBalancedChirWethDepositAmounts(layoutStruct_, wethAmount_);
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
        if (quote_.token0 == address(BaseProtocolDETFRepo._layoutStruct().wethToken)) {
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

    /**
     * @notice Executes WETH → RICHIR conversion via the direct deposit route.
     * @dev Atomically: WETH → CHIR/WETH vault shares → BPT → protocol NFT → mint RICHIR.
    *      Unlike bonding through the unified WETH route, this path does not mint CHIR or create balanced LP.
     *      It deposits WETH directly into the CHIR/WETH vault, then routes the resulting
     *      vault shares into the reserve pool and mints RICHIR against the protocol NFT.
     * @param layoutStruct_ Storage layoutStruct reference
     * @param p_ Exchange parameters
     * @return amountOut_ Amount of RICHIR minted
     */
    function _executeWethToRichir(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Secure WETH transfer
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);

        // Direct route: deposit WETH to the CHIR/WETH vault without minting CHIR.
        p_.tokenIn.safeTransfer(address(layoutStruct_.chirWethVault), actualIn);
        uint256 chirWethShares = layoutStruct_.chirWethVault.exchangeIn(
            p_.tokenIn,
            actualIn,
            IERC20(address(layoutStruct_.chirWethVault)),
            0,
            address(this),
            true,
            p_.deadline
        );

        // Add LP shares to 80/20 reserve pool (get BPT)
        uint256 bptOut = _addToReservePoolForWethToRichir(layoutStruct_, chirWethShares, p_.deadline);

        // Add BPT directly to protocol-owned NFT (no user NFT created)
        IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
        DETFBondLifecycleLib._addReservePoolBptToProtocolNft(
            reservePoolToken, layoutStruct_.protocolNFTVault, layoutStruct_.protocolNFTId, bptOut
        );

        // Mint RICHIR to recipient (1:1 with BPT added to protocol NFT)
        amountOut_ = layoutStruct_.richirToken.mintFromNFTSale(bptOut, p_.recipient);

        if (amountOut_ < p_.minAmountOut) {
            revert SlippageExceeded(p_.minAmountOut, amountOut_);
        }
    }

    /**
     * @notice Adds CHIR/WETH vault shares to the reserve pool for RICHIR minting.
     * @dev Uses the same logic as _addToReservePool in BondingTarget but localized here
     *      to avoid cross-facet calls.
     * @param layoutStruct_ Storage layoutStruct reference
     * @param vaultShares_ Amount of vault shares to add
     * @param deadline_ Transaction deadline (unused but kept for consistency)
     * @return bptOut_ Amount of BPT received
     */
    function _addToReservePoolForWethToRichir(
        BaseProtocolDETFRepo.Storage storage layoutStruct_,
        uint256 vaultShares_,
        uint256 deadline_
    ) internal returns (uint256 bptOut_) {
        deadline_; // Silence unused variable warning
        ReservePoolData memory resPoolData;
        (TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);

        uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
        for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
        }

        uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[layoutStruct_.chirWethVaultIndex]);

        // Create deposit amounts array (single-sided deposit)
        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[layoutStruct_.chirWethVaultIndex] = vaultShares_;

        // Calculate expected BPT
        bptOut_ = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
            balancesLiveScaled18,
            resPoolData.weightsArray,
            layoutStruct_.chirWethVaultIndex,
            amountInLiveScaled18,
            resPoolData.resPoolTotalSupply,
            resPoolData.reservePoolSwapFee
        );

        // Transfer vault shares to Balancer vault
        IERC20(address(layoutStruct_.chirWethVault)).safeTransfer(address(resPoolData.balV3Vault), vaultShares_);

        // Add liquidity
        layoutStruct_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut_, "");

        // Keep BasicVault reserve views in-sync with actual BPT balance
        ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
    }

    /* ---------------------------------------------------------------------- */
    /*                      WETH → RICH Route Handlers                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Executes WETH → RICH conversion.
     * @dev Flow:
     *      1. Transfer WETH from user
     *      2. Deposit WETH into CHIR/WETH vault → get CHIR
     *      3. Swap CHIR for RICH via RICH/CHIR vault
     *      4. Transfer RICH to recipient
     * @param layoutStruct_ Storage layoutStruct reference
     * @param p_ Exchange parameters
     * @return amountOut_ Amount of RICH received
     */
    function _executeWethToRich(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Secure WETH transfer
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);

        // Step 1: WETH → CHIR via chirWethVault
        p_.tokenIn.safeTransfer(address(layoutStruct_.chirWethVault), actualIn);
        uint256 chirOut = layoutStruct_.chirWethVault
            .exchangeIn(
                p_.tokenIn,
                actualIn,
                IERC20(address(this)), // CHIR
                0, // No min on intermediate step
                address(this),
                true, // pretransferred
                p_.deadline
            );

        // Step 2: CHIR → RICH via richChirVault
        IERC20(address(this)).safeTransfer(address(layoutStruct_.richChirVault), chirOut);
        amountOut_ = layoutStruct_.richChirVault
            .exchangeIn(
                IERC20(address(this)), // CHIR
                chirOut,
                layoutStruct_.richToken,
                p_.minAmountOut, // Apply slippage protection on final output
                p_.recipient,
                true, // pretransferred
                p_.deadline
            );

        if (amountOut_ < p_.minAmountOut) {
            revert SlippageExceeded(p_.minAmountOut, amountOut_);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                      RICH → WETH Route Handlers                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Executes RICH → WETH conversion.
     * @dev Flow:
     *      1. Transfer RICH from user
     *      2. Swap RICH for CHIR via RICH/CHIR vault
     *      3. Swap CHIR for WETH via CHIR/WETH vault
     *      4. Transfer WETH to recipient
     * @param layoutStruct_ Storage layoutStruct reference
     * @param p_ Exchange parameters
     * @return amountOut_ Amount of WETH received
     */
    function _executeRichToWeth(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Secure RICH transfer
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, p_.amountIn, p_.pretransferred);

        // Step 1: RICH → CHIR via richChirVault
        p_.tokenIn.safeTransfer(address(layoutStruct_.richChirVault), actualIn);
        uint256 chirOut = layoutStruct_.richChirVault
            .exchangeIn(
                p_.tokenIn,
                actualIn,
                IERC20(address(this)), // CHIR
                0, // No min on intermediate step
                address(this),
                true, // pretransferred
                p_.deadline
            );

        // Step 2: CHIR → WETH via chirWethVault
        IERC20(address(this)).safeTransfer(address(layoutStruct_.chirWethVault), chirOut);
        amountOut_ = layoutStruct_.chirWethVault
            .exchangeIn(
                IERC20(address(this)), // CHIR
                chirOut,
                layoutStruct_.wethToken,
                p_.minAmountOut, // Apply slippage protection on final output
                p_.recipient,
                true, // pretransferred
                p_.deadline
            );

        if (amountOut_ < p_.minAmountOut) {
            revert SlippageExceeded(p_.minAmountOut, amountOut_);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                      RICHIR → RICH Route Handler                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Redeems RICHIR for local RICH (no bridging).
     * @dev Flow (same as bridgeRichir except final step):
     *      1. Pull RICHIR from sender (via _secureTokenTransfer)
     *      2. Calculate BPT to exit
        *      3. Move redeemed RICHIR into the RICHIR token contract and burn shares
     *      4. Exit reserve pool proportionally → [chirWethShares, richChirVaultSharesOut]
     *      5. CHIR/WETH portion → re-add to reserve pool, mint local RICHIR to sender
     *      6. RICH/CHIR portion → exchange for RICH
     *      7. Send RICH to local recipient (NO bridging)
     *
     *      Access control: sender must be in allowedRichirRedeemAddresses AddressSet.
     */
    function _executeRichirToRich(BaseProtocolDETFRepo.Storage storage layoutStruct_, ExchangeInParams memory p_)
        internal
        returns (uint256 amountOut_)
    {
        // Access control: check if sender is allowed to use this route
        if (!layoutStruct_.allowedRichirRedeemAddresses._contains(msg.sender)) {
            revert BaseProtocolDETFRepo.NotAllowedRichirRedeem(msg.sender);
        }

        // Step 1: Pull RICHIR from sender
        uint256 actualIn;
        if (p_.pretransferred) {
            // Tokens already at this contract - use balance check
            require(
                p_.tokenIn.balanceOf(address(this)) >= p_.amountIn,
                "BaseProtocolDETFCommon: insufficient pretransferred balance"
            );
            actualIn = p_.amountIn;
        } else {
            // Pull tokens via transfer - this properly moves shares for share-based tokens
            uint256 balBefore = p_.tokenIn.balanceOf(address(this));
            p_.tokenIn.transferFrom(msg.sender, address(this), p_.amountIn);
            uint256 balAfter = p_.tokenIn.balanceOf(address(this));
            actualIn = balAfter - balBefore;
        }

        // Step 2: Calculate BPT to exit BEFORE burning (rate still reflects current state)
        uint256 bptIn = _calcRichirRedemptionBptIn(layoutStruct_, actualIn);

        // Step 3: Mirror bridgeRichir: move redeemed RICHIR into the token contract,
        // then burn from the token contract with pretransferred=true.
        p_.tokenIn.safeTransfer(address(layoutStruct_.richirToken), actualIn);
        layoutStruct_.richirToken.burnShares(actualIn, address(0), true);

        // Step 4: Exit reserve pool proportionally
        (uint256 chirWethVaultSharesOut, uint256 richChirVaultSharesOut) =
            _exitReservePoolProportional(layoutStruct_, bptIn);

        // Step 5: Re-invest CHIR/WETH portion back into reserve pool, mint local RICHIR
        if (chirWethVaultSharesOut > 0) {
            uint256 localBptOut =
                _addToReservePoolForWethToRichir(layoutStruct_, chirWethVaultSharesOut, p_.deadline);
            if (localBptOut > 0) {
                IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
                reservePoolToken.forceApprove(address(layoutStruct_.protocolNFTVault), localBptOut);
                layoutStruct_.protocolNFTVault.addToProtocolNFT(layoutStruct_.protocolNFTId, localBptOut);
                // Mint local RICHIR to sender (not recipient - this is the reinvest portion)
                layoutStruct_.richirToken.mintFromNFTSale(localBptOut, msg.sender);
            }
        }

        // Step 6: Exchange RICH/CHIR portion for RICH
        if (richChirVaultSharesOut > 0) {
            IERC20 richChirVaultToken = IERC20(address(layoutStruct_.richChirVault));
            richChirVaultToken.forceApprove(address(layoutStruct_.richChirVault), richChirVaultSharesOut);
            amountOut_ = layoutStruct_.richChirVault.exchangeIn(
                richChirVaultToken,
                richChirVaultSharesOut,
                layoutStruct_.richToken,
                0, // minAmountOut on intermediate step - final slippage check below
                address(this),
                false,
                p_.deadline
            );
        }

        // Step 7: Apply slippage check and send RICH to recipient (NO bridging)
        if (amountOut_ < p_.minAmountOut) {
            revert SlippageExceeded(p_.minAmountOut, amountOut_);
        }

        layoutStruct_.richToken.safeTransfer(p_.recipient, amountOut_);
    }
}
