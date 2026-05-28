// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Math} from "@crane/contracts/utils/Math.sol";
import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {DETFPreviewLib} from "contracts/vaults/detf/core/DETFPreviewLib.sol";
import {BaseDualSelfCommonDETFRepo} from "contracts/vaults/protocol/BaseDualSelfCommonDETFRepo.sol";
import {BaseDualSelfCommonDETFCommon} from "contracts/vaults/protocol/BaseDualSelfCommonDETFCommon.sol";
import {BaseDualSelfCommonDETFPreviewHelpers} from "contracts/vaults/protocol/BaseDualSelfCommonDETFPreviewHelpers.sol";
import {
    BalancerV38020WeightedPoolMath
} from "contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";

import {
    PREVIEW_BUFFER_DENOMINATOR,
    PREVIEW_RICHIR_BUFFER_BPS,
    PREVIEW_BPT_BUFFER_DENOMINATOR,
    PREVIEW_BPT_BUFFER_BPS,
    PREVIEW_WETH_CHIR_BUFFER_BPS
} from "contracts/constants/Indexedex_CONSTANTS.sol";

/**
 * @title BaseDualSelfCommonDETFExchangeOutTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of IStandardExchangeOut for Protocol DETF (CHIR).
 * @dev Handles exact-output exchanges:
 *      - WETH → CHIR (mint exact CHIR amount)
 *      - CHIR → RICH (buy exact RICH amount)
 *      - WETH → RICH (buy exact RICH amount via multi-hop)
 *      - RICH → CHIR (buy exact CHIR amount)
 */
contract BaseDualSelfCommonDETFExchangeOutTarget is BaseDualSelfCommonDETFCommon, ReentrancyLockModifiers, IStandardExchangeOut {
    using BetterSafeERC20 for IERC20;
    using FixedPoint for uint256;
    using BaseDualSelfCommonDETFRepo for BaseDualSelfCommonDETFRepo.Storage;

    struct ExchangeOutParams {
        IERC20 tokenIn;
        uint256 maxAmountIn;
        IERC20 tokenOut;
        uint256 amountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
        uint256 syntheticPrice;
    }

    struct ReservePoolBptPreviewOut {
        uint256[] balancesRaw;
        uint256 bptOut;
        uint256 poolSupply;
        uint256 chirIdx;
        uint256 richIdx;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Preview Exchange Out                          */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IStandardExchangeOut
     * @dev Supported routes:
     *      1. WETH → CHIR (mint exact CHIR when above mint threshold)
     *      2. CHIR → RICH (buy exact RICH amount)
     *      3. WETH → RICH (buy exact RICH via multi-hop)
     *      4. RICH → CHIR (buy exact CHIR via multi-hop)
     */
    function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_)
        external
        view
        returns (uint256 amountIn_)
    {
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();

        // Route: WETH → CHIR (mint exact CHIR)
        if (_isWethToken(layoutStruct, tokenIn_) && _isChirToken(tokenOut_)) {
            // Calculate synthetic price
            PoolReserves memory reserves;
            _loadPoolReserves(layoutStruct, reserves);
            uint256 syntheticPrice = _calcSyntheticPrice(reserves);

            // Verify minting is allowed
            if (!_isMintingAllowed(layoutStruct, syntheticPrice)) {
                revert MintingNotAllowed(syntheticPrice, layoutStruct.mintThreshold);
            }

            // Calculate required WETH using oracle incentive + AMM math
            amountIn_ = _calcRequiredWethForExactChir(layoutStruct, amountOut_, reserves);
            return amountIn_;
        }

        // Route: CHIR → RICH (buy exact RICH)
        if (_isChirToken(tokenIn_) && _isRichToken(layoutStruct, tokenOut_)) {
            // Delegate to RICH/CHIR vault
            amountIn_ = layoutStruct.richChirVault.previewExchangeOut(tokenIn_, tokenOut_, amountOut_);
            return amountIn_;
        }

        // Route: RICHIR → WETH - NOT SUPPORTED
        if (_isRichirToken(layoutStruct, tokenIn_) && _isWethToken(layoutStruct, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Route: WETH → RICH (buy exact RICH via multi-hop)
        if (_isWethToken(layoutStruct, tokenIn_) && _isRichToken(layoutStruct, tokenOut_)) {
            return _previewWethToRichExact(layoutStruct, amountOut_);
        }

        // Route: RICH → CHIR (buy exact CHIR via multi-hop)
        if (_isRichToken(layoutStruct, tokenIn_) && _isChirToken(tokenOut_)) {
            return _previewRichToChirExact(layoutStruct, amountOut_);
        }

        // Route: RICH → RICHIR - NOT SUPPORTED
        if (_isRichToken(layoutStruct, tokenIn_) && _isRichirToken(layoutStruct, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Route: WETH → RICHIR - NOT SUPPORTED
        if (_isWethToken(layoutStruct, tokenIn_) && _isRichirToken(layoutStruct, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Unsupported route
        revert ExchangeOutNotAvailable();
    }

    /* ---------------------------------------------------------------------- */
    /*                             Exchange Out                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IStandardExchangeOut
     */
    function exchangeOut(
        IERC20 tokenIn_,
        uint256 maxAmountIn_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) external lock returns (uint256 amountIn_) {
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp > deadline_) {
            revert DeadlineExceeded(deadline_, block.timestamp);
        }

        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();

        // Calculate synthetic price once
        PoolReserves memory reserves;
        _loadPoolReserves(layoutStruct, reserves);
        uint256 syntheticPrice = _calcSyntheticPrice(reserves);

        ExchangeOutParams memory params = ExchangeOutParams({
            tokenIn: tokenIn_,
            maxAmountIn: maxAmountIn_,
            tokenOut: tokenOut_,
            amountOut: amountOut_,
            recipient: recipient_,
            pretransferred: pretransferred_,
            deadline: deadline_,
            syntheticPrice: syntheticPrice
        });

        // Route: WETH → CHIR (mint exact CHIR)
        if (_isWethToken(layoutStruct, tokenIn_) && _isChirToken(tokenOut_)) {
            amountIn_ = _executeMintExactChir(layoutStruct, params);
            return amountIn_;
        }

        // Route: CHIR → RICH (buy exact RICH)
        if (_isChirToken(tokenIn_) && _isRichToken(layoutStruct, tokenOut_)) {
            amountIn_ = _executeChirToRichExact(layoutStruct, params);
            return amountIn_;
        }

        // Route: RICHIR → WETH - NOT SUPPORTED
        if (_isRichirToken(layoutStruct, tokenIn_) && _isWethToken(layoutStruct, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Route: WETH → RICH (buy exact RICH via multi-hop)
        if (_isWethToken(layoutStruct, tokenIn_) && _isRichToken(layoutStruct, tokenOut_)) {
            amountIn_ = _executeWethToRichExact(layoutStruct, params);
            return amountIn_;
        }

        // Route: RICH → CHIR (buy exact CHIR via multi-hop)
        if (_isRichToken(layoutStruct, tokenIn_) && _isChirToken(tokenOut_)) {
            amountIn_ = _executeRichToChirExact(layoutStruct, params);
            return amountIn_;
        }

        // Route: RICH → RICHIR - NOT SUPPORTED
        if (_isRichToken(layoutStruct, tokenIn_) && _isRichirToken(layoutStruct, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Route: WETH → RICHIR - NOT SUPPORTED
        if (_isWethToken(layoutStruct, tokenIn_) && _isRichirToken(layoutStruct, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Unsupported route
        revert ExchangeOutNotAvailable();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Amount Calculations                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Calculates required WETH for exact CHIR output using oracle incentive + AMM math.
     * @dev Matches execution logic: applies seigniorage incentive factors and AMM pricing.
     *      Adds buffer to guarantee previewIn >= executeIn.
     * @param layoutStruct_ Storage layoutStruct reference
     * @param amountOut_ Exact CHIR amount desired
     * @param reserves_ Current pool reserves
     * @return amountIn_ Required WETH (rounded up with buffer to favor vault)
     */
    function _calcRequiredWethForExactChir(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 amountOut_,
        PoolReserves memory reserves_
    ) internal view returns (uint256 amountIn_) {
        uint256 syntheticPrice = _calcSyntheticPrice(reserves_);

        if (syntheticPrice <= ONE_WAD) {
            amountIn_ = amountOut_;
        } else {
            uint256 incentivePercent = layoutStruct_._seigniorageIncentivePercentagePPM();

            uint256 FULL = 1e6;

            // If no incentive set (or very small), fall back to simple synthetic price math
            if (incentivePercent == 0 || incentivePercent >= FULL * 2) {
                amountIn_ = BetterMath._mulDiv(amountOut_, syntheticPrice, ONE_WAD, Math.Rounding.Ceil);
                amountIn_ = DETFPreviewLib._applyMarkupBps(
                    amountIn_, PREVIEW_WETH_CHIR_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR
                );
                return amountIn_;
            }

            uint256 userFactor = FULL - (incentivePercent / 2);
            uint256 boostFactor = FULL + incentivePercent;

            uint256 targetBaseCHIR =
                BetterMath._mulDiv(amountOut_, FULL, userFactor, Math.Rounding.Ceil);

            uint256 requiredBoostedWETH = ConstProdUtils._purchaseQuote(
                targetBaseCHIR,
                reserves_.wethReserve,
                reserves_.chirInWethPool,
                reserves_.chirWethFeePercent,
                10000
            );

            amountIn_ =
                BetterMath._mulDiv(requiredBoostedWETH, FULL, boostFactor, Math.Rounding.Ceil);
        }

        amountIn_ = DETFPreviewLib._applyMarkupBps(amountIn_, PREVIEW_WETH_CHIR_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR);
    }

    /**
     * @notice Calculates required WETH for exact CHIR output (execution version).
     * @param amountOut_ Exact CHIR amount desired
     * @param syntheticPrice_ Current synthetic price
     * @return amountIn_ Required WETH (rounded up to favor vault)
     */
    function _calcRequiredWethForExactChirExec(uint256 amountOut_, uint256 syntheticPrice_)
        internal
        pure
        returns (uint256 amountIn_)
    {
        if (syntheticPrice_ <= ONE_WAD) {
            amountIn_ = amountOut_;
        } else {
            amountIn_ = BetterMath._mulDiv(amountOut_, syntheticPrice_, ONE_WAD, Math.Rounding.Ceil);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                  Original Exchange Out Route Handlers                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Mints exact amount of CHIR with WETH.
     */
    function _executeMintExactChir(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        if (!_isMintingAllowed(layoutStruct_, p_.syntheticPrice)) {
            revert MintingNotAllowed(p_.syntheticPrice, layoutStruct_.mintThreshold);
        }

        // Calculate required WETH for exact CHIR output (rounds UP)
        // Execution uses simple synthetic price math - seigniorage calculated on actual received
        amountIn_ = _calcRequiredWethForExactChirExec(p_.amountOut, p_.syntheticPrice);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        // Secure WETH transfer
        uint256 actualIn = _secureTokenTransfer(p_.tokenIn, amountIn_, p_.pretransferred);

        // Calculate seigniorage based on actual WETH received
        SeigniorageCalc memory calc;
        calc.syntheticPrice = p_.syntheticPrice;
        _calcSeigniorage(layoutStruct_, calc, actualIn);

        // Deposit WETH into CHIR/WETH vault
        p_.tokenIn.safeTransfer(address(layoutStruct_.chirWethVault), actualIn);
        layoutStruct_.chirWethVault
            .exchangeIn(
                p_.tokenIn, actualIn, IERC20(address(layoutStruct_.chirWethVault)), 0, address(this), true, p_.deadline
            );

        // Mint seigniorage to the NFT vault as reward-token accrual
        if (calc.seigniorageTokens > 0) {
            ERC20Repo._mint(address(layoutStruct_.protocolNFTVault), calc.seigniorageTokens);
        }

        // Mint exact CHIR to recipient
        ERC20Repo._mint(p_.recipient, p_.amountOut);

        // Refund excess WETH if pretransferred and we received more than needed
        if (p_.pretransferred && p_.maxAmountIn > amountIn_) {
            p_.tokenIn.safeTransfer(msg.sender, p_.maxAmountIn - amountIn_);
        }
    }

    /**
     * @notice Buys exact amount of RICH with CHIR.
     */
    function _executeChirToRichExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        // Calculate required CHIR for exact RICH output
        amountIn_ = layoutStruct_.richChirVault.previewExchangeOut(p_.tokenIn, p_.tokenOut, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        // Burn CHIR from sender
        _secureChirBurn(msg.sender, amountIn_, p_.pretransferred);

        // Execute exchange via RICH/CHIR vault
        // Mint CHIR to vault and exchange for RICH
        ERC20Repo._mint(address(layoutStruct_.richChirVault), amountIn_);

        layoutStruct_.richChirVault
            .exchangeOut(p_.tokenIn, amountIn_, p_.tokenOut, p_.amountOut, p_.recipient, true, p_.deadline);
    }

    /* ---------------------------------------------------------------------- */
    /*                      CHIR → WETH ExactOut Route                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required CHIR for exact WETH output.
     * @dev Uses binary search to find the minimum CHIR that yields exactWethOut.
     *      Rounds UP to favor the vault.
     * @param layoutStruct_ Storage layoutStruct reference
     * @param exactWethOut_ Exact WETH amount desired
     * @return chirIn_ Required CHIR input (rounded up)
     */
    function _previewChirToWethExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactWethOut_)
        internal
        view
        returns (uint256 chirIn_)
    {
        if (exactWethOut_ == 0) return 0;

        PoolReserves memory reserves;
        _loadPoolReserves(layoutStruct_, reserves);
        uint256 syntheticPrice = _calcSyntheticPrice(reserves);

        // Verify burning is allowed
        if (!_isBurningAllowed(layoutStruct_, syntheticPrice)) {
            revert BurningNotAllowed(syntheticPrice, layoutStruct_.burnThreshold);
        }

        // Binary search for minimum CHIR that yields at least exactWethOut
        uint256 low = exactWethOut_;
        uint256 high = exactWethOut_ * 2;

        // Expand high bound if needed (with iteration limit)
        uint256 MAX_ITERATIONS = 128;
        uint256 iterations = 0;
        uint256 wethFromHigh = layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), high, layoutStruct_.wethToken);
        while (wethFromHigh < exactWethOut_ && high < type(uint128).max && iterations < MAX_ITERATIONS) {
            high = high * 2;
            wethFromHigh = layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), high, layoutStruct_.wethToken);
            ++iterations;
        }

        // Binary search (bounded)
        iterations = 0;
        while (low < high && iterations < MAX_ITERATIONS) {
            uint256 mid = (low + high) / 2;
            uint256 wethOut = layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), mid, layoutStruct_.wethToken);
            if (wethOut < exactWethOut_) {
                low = mid + 1;
            } else {
                high = mid;
            }
            ++iterations;
        }

        // Final verification with round-up
        chirIn_ = low;
        uint256 wethCheck = layoutStruct_.chirWethVault.previewExchangeIn(IERC20(address(this)), chirIn_, layoutStruct_.wethToken);
        if (wethCheck < exactWethOut_) {
            chirIn_ += 1;
        }
    }

    /**
     * @notice Redeems CHIR for exact amount of WETH.
     */
    function _executeChirToWethExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        if (!_isBurningAllowed(layoutStruct_, p_.syntheticPrice)) {
            revert BurningNotAllowed(p_.syntheticPrice, layoutStruct_.burnThreshold);
        }

        // Calculate required CHIR for exact WETH output
        amountIn_ = _previewChirToWethExact(layoutStruct_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        // Burn CHIR from sender
        _secureChirBurn(msg.sender, amountIn_, p_.pretransferred);

        // Mint CHIR to vault and swap for WETH
        ERC20Repo._mint(address(layoutStruct_.chirWethVault), amountIn_);

        uint256 wethOut = layoutStruct_.chirWethVault
            .exchangeIn(
                IERC20(address(this)), amountIn_, layoutStruct_.wethToken, p_.amountOut, p_.recipient, true, p_.deadline
            );

        // Verify exact output
        if (wethOut < p_.amountOut) {
            revert SlippageExceeded(p_.amountOut, wethOut);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                     RICHIR → WETH ExactOut Route                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required RICHIR for exact WETH output.
     * @dev RICHIR uses a linear redemption rate: wethOut = richirIn * rate / 1e18
     * @param layoutStruct_ Storage layoutStruct reference
     * @param exactWethOut_ Exact WETH amount desired
     * @return richirIn_ Required RICHIR input (rounded up)
     */
    function _previewRichirToWethExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactWethOut_)
        internal
        view
        returns (uint256 richirIn_)
    {
        if (exactWethOut_ == 0) return 0;

        uint256 redemptionRate = layoutStruct_.richirToken.redemptionRate();
        if (redemptionRate == 0) {
            revert ZeroAmount();
        }

        // richirIn = exactWethOut * 1e18 / rate (round UP)
        richirIn_ = BetterMath._mulDiv(exactWethOut_, ONE_WAD, redemptionRate, Math.Rounding.Ceil);
    }

    /**
     * @notice Redeems RICHIR for exact amount of WETH.
     */
    function _executeRichirToWethExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        // Calculate required RICHIR
        amountIn_ = _previewRichirToWethExact(layoutStruct_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        // Transfer RICHIR from sender
        if (!p_.pretransferred) {
            p_.tokenIn.safeTransferFrom(msg.sender, address(this), amountIn_);
        }

        // Get actual RICHIR balance
        uint256 richirBalance = p_.tokenIn.balanceOf(address(this));

        // Calculate BPT to exit BEFORE burning (rate reflects current state)
        uint256 richirShares = layoutStruct_.richirToken.convertToShares(richirBalance);
        uint256 totalRichirShares = layoutStruct_.richirToken.totalShares();
        uint256 protocolNftBpt = layoutStruct_.protocolNFTVault.originalSharesOf(layoutStruct_.protocolNFTId);
        uint256 bptIn = (richirShares * protocolNftBpt) / totalRichirShares;

        // Burn RICHIR first
        p_.tokenIn.safeTransfer(address(layoutStruct_.richirToken), richirBalance);
        layoutStruct_.richirToken.burnShares(richirBalance, address(0), true);

        // Exit reserve pool and unwind to WETH
        uint256 wethOut = _exitAndUnwindToWethForExactOut(layoutStruct_, bptIn, p_.deadline);

        // Verify exact output
        if (wethOut < p_.amountOut) {
            revert SlippageExceeded(p_.amountOut, wethOut);
        }

        // Send exact WETH to recipient
        layoutStruct_.wethToken.safeTransfer(p_.recipient, p_.amountOut);

        // Refund excess WETH
        if (wethOut > p_.amountOut) {
            layoutStruct_.wethToken.safeTransfer(msg.sender, wethOut - p_.amountOut);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                      WETH → RICH ExactOut Route                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required WETH for exact RICH output.
     * @dev Multi-hop: WETH → CHIR → RICH. Works backwards.
     */
    function _previewWethToRichExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactRichOut_)
        internal
        view
        returns (uint256 wethIn_)
    {
        if (exactRichOut_ == 0) return 0;

        // Step 1: CHIR needed for exact RICH
        uint256 chirNeeded =
            layoutStruct_.richChirVault.previewExchangeOut(IERC20(address(this)), layoutStruct_.richToken, exactRichOut_);

        // Step 2: WETH needed for that CHIR
        wethIn_ = layoutStruct_.chirWethVault.previewExchangeOut(layoutStruct_.wethToken, IERC20(address(this)), chirNeeded);
    }

    /**
     * @notice Buys exact amount of RICH with WETH via multi-hop.
     */
    function _executeWethToRichExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        amountIn_ = _previewWethToRichExact(layoutStruct_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(layoutStruct_.wethToken, amountIn_, p_.pretransferred);

        // Step 1: WETH → CHIR
        layoutStruct_.wethToken.safeTransfer(address(layoutStruct_.chirWethVault), actualIn);
        uint256 chirOut = layoutStruct_.chirWethVault
            .exchangeIn(layoutStruct_.wethToken, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);

        // Step 2: CHIR → RICH (exact out)
        IERC20(address(this)).safeTransfer(address(layoutStruct_.richChirVault), chirOut);
        layoutStruct_.richChirVault
            .exchangeOut(
                IERC20(address(this)), chirOut, layoutStruct_.richToken, p_.amountOut, p_.recipient, true, p_.deadline
            );
    }

    /* ---------------------------------------------------------------------- */
    /*                      RICH → CHIR ExactOut Route                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required RICH for exact CHIR output.
     * @dev Multi-hop: RICH → CHIR → WETH → mint CHIR. Works backwards.
     */
    function _previewRichToChirExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactChirOut_)
        internal
        view
        returns (uint256 richIn_)
    {
        if (exactChirOut_ == 0) return 0;

        PoolReserves memory reserves;
        _loadPoolReserves(layoutStruct_, reserves);
        uint256 syntheticPrice = _calcSyntheticPrice(reserves);

        if (!_isMintingAllowed(layoutStruct_, syntheticPrice)) {
            revert MintingNotAllowed(syntheticPrice, layoutStruct_.mintThreshold);
        }

        // Work backwards:
        // 1. WETH needed for exact CHIR mint (use oracle-based preview with buffer)
        uint256 wethNeeded = _calcRequiredWethForExactChir(layoutStruct_, exactChirOut_, reserves);

        // 2. CHIR needed to get that WETH
        uint256 chirNeeded =
            layoutStruct_.chirWethVault.previewExchangeOut(IERC20(address(this)), layoutStruct_.wethToken, wethNeeded);

        // 3. RICH needed to get that CHIR
        richIn_ = layoutStruct_.richChirVault.previewExchangeOut(layoutStruct_.richToken, IERC20(address(this)), chirNeeded);
    }

    /**
     * @notice Converts RICH to exact amount of CHIR via multi-hop mint.
     */
    function _executeRichToChirExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        if (!_isMintingAllowed(layoutStruct_, p_.syntheticPrice)) {
            revert MintingNotAllowed(p_.syntheticPrice, layoutStruct_.mintThreshold);
        }

        amountIn_ = _previewRichToChirExact(layoutStruct_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(layoutStruct_.richToken, amountIn_, p_.pretransferred);

        // Step 1: RICH → CHIR
        layoutStruct_.richToken.safeTransfer(address(layoutStruct_.richChirVault), actualIn);
        uint256 chirOut = layoutStruct_.richChirVault
            .exchangeIn(layoutStruct_.richToken, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);

        // Step 2: CHIR → WETH
        IERC20(address(this)).safeTransfer(address(layoutStruct_.chirWethVault), chirOut);
        uint256 wethOut = layoutStruct_.chirWethVault
            .exchangeIn(IERC20(address(this)), chirOut, layoutStruct_.wethToken, 0, address(this), true, p_.deadline);

        // Step 3: Mint exact CHIR with WETH
        ExchangeOutParams memory mintParams = ExchangeOutParams({
            tokenIn: layoutStruct_.wethToken,
            maxAmountIn: wethOut,
            tokenOut: IERC20(address(this)),
            amountOut: p_.amountOut,
            recipient: p_.recipient,
            pretransferred: true,
            deadline: p_.deadline,
            syntheticPrice: p_.syntheticPrice
        });
        _executeMintExactChir(layoutStruct_, mintParams);
    }

    /* ---------------------------------------------------------------------- */
    /*                     RICH → RICHIR ExactOut Route                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required RICH for exact RICHIR output.
     * @dev Uses binary search with forward preview simulation.
     */
    function _previewRichToRichirExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactRichirOut_)
        internal
        view
        returns (uint256 richIn_)
    {
        if (exactRichirOut_ == 0) return 0;

        // Binary search
        uint256 low = 1;
        uint256 high = exactRichirOut_ * 2;

        uint256 richirFromHigh = _previewRichToRichirForward(layoutStruct_, high);
        while (richirFromHigh < exactRichirOut_ && high < type(uint128).max) {
            high = high * 2;
            richirFromHigh = _previewRichToRichirForward(layoutStruct_, high);
        }

        while (low < high) {
            uint256 mid = (low + high) / 2;
            uint256 richirOut = _previewRichToRichirForward(layoutStruct_, mid);
            if (richirOut < exactRichirOut_) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }

        richIn_ = low;

        // Apply precision buffer to ensure preview overestimates input required.
        // previewExchangeOut should overestimate (return ≥ actual input needed).
        richIn_ = DETFPreviewLib._applyMarkupBps(richIn_, PREVIEW_RICHIR_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR);
    }

    /**
     * @notice Forward preview for RICH → RICHIR.
     */
    function _previewRichToRichirForward(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 richIn_)
        internal
        view
        returns (uint256 richirOut_)
    {
        if (richIn_ == 0) return 0;

        // Simulate Aerodrome fee compound to get accurate post-compound vault shares
        uint256 vaultShares = _previewVaultSharesPostCompound(layoutStruct_.richChirVault, layoutStruct_.richToken, richIn_);

        richirOut_ = _previewRichirOutFromVaultShares(layoutStruct_, layoutStruct_.richChirVaultIndex, vaultShares);
    }

    /**
     * @notice Converts RICH to exact amount of RICHIR.
     */
    function _executeRichToRichirExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        amountIn_ = _previewRichToRichirExact(layoutStruct_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(layoutStruct_.richToken, amountIn_, p_.pretransferred);

        layoutStruct_.richToken.safeTransfer(address(layoutStruct_.richChirVault), actualIn);
        uint256 richChirShares = layoutStruct_.richChirVault
            .exchangeIn(
                layoutStruct_.richToken, actualIn, IERC20(address(layoutStruct_.richChirVault)), 0, address(this), true, p_.deadline
            );

        uint256 bptOut = _addToReservePoolForExactOut(layoutStruct_, richChirShares, layoutStruct_.richChirVaultIndex);

        IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
        reservePoolToken.forceApprove(address(layoutStruct_.protocolNFTVault), bptOut);
        layoutStruct_.protocolNFTVault.addToProtocolNFT(layoutStruct_.protocolNFTId, bptOut);

        uint256 richirOut = layoutStruct_.richirToken.mintFromNFTSale(bptOut, p_.recipient);

        if (richirOut < p_.amountOut) {
            revert SlippageExceeded(p_.amountOut, richirOut);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                     WETH → RICHIR ExactOut Route                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required WETH for exact RICHIR output.
     * @dev Uses binary search with forward preview simulation.
     */
    function _previewWethToRichirExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 exactRichirOut_)
        internal
        view
        returns (uint256 wethIn_)
    {
        if (exactRichirOut_ == 0) return 0;

        // Binary search
        uint256 low = 1;
        uint256 high = exactRichirOut_ * 2;

        uint256 richirFromHigh = _previewWethToRichirForward(layoutStruct_, high);
        while (richirFromHigh < exactRichirOut_ && high < type(uint128).max) {
            high = high * 2;
            richirFromHigh = _previewWethToRichirForward(layoutStruct_, high);
        }

        while (low < high) {
            uint256 mid = (low + high) / 2;
            uint256 richirOut = _previewWethToRichirForward(layoutStruct_, mid);
            if (richirOut < exactRichirOut_) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }

        wethIn_ = low;

        // Apply precision buffer to ensure preview overestimates input required.
        // previewExchangeOut should overestimate (return ≥ actual input needed).
        wethIn_ = DETFPreviewLib._applyMarkupBps(wethIn_, PREVIEW_RICHIR_BUFFER_BPS, PREVIEW_BUFFER_DENOMINATOR);
    }

    /**
     * @notice Forward preview for WETH → RICHIR.
     */
    function _previewWethToRichirForward(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 wethIn_)
        internal
        view
        returns (uint256 richirOut_)
    {
        if (wethIn_ == 0) return 0;

        // Simulate Aerodrome fee compound to get accurate post-compound vault shares
        uint256 vaultShares = _previewVaultSharesPostCompound(layoutStruct_.chirWethVault, layoutStruct_.wethToken, wethIn_);

        richirOut_ = _previewRichirOutFromVaultShares(layoutStruct_, layoutStruct_.chirWethVaultIndex, vaultShares);
    }

    function _previewRichirOutFromVaultShares(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 vaultIndex_,
        uint256 vaultShares_
    ) internal view returns (uint256 richirOut_) {
        ReservePoolBptPreviewOut memory preview_ = _previewReservePoolBptOut(vaultIndex_, vaultShares_);
        uint256 bptOut = preview_.bptOut;

        ReservePoolData memory resPoolData;
        _loadReservePoolData(resPoolData, new uint256[](0));

        BaseDualSelfCommonDETFPreviewHelpers.RichirCalc memory calc;
        calc.balV3Vault = address(resPoolData.balV3Vault);
        calc.reservePool = address(resPoolData.reservePool);
        calc.reservePoolSwapFee = resPoolData.reservePoolSwapFee;
        calc.weightsArray = resPoolData.weightsArray;
        calc.chirWethVault = address(layoutStruct_.chirWethVault);
        calc.richChirVault = address(layoutStruct_.richChirVault);
        calc.chirToken = address(this);
        calc.wethToken = address(layoutStruct_.wethToken);
        calc.poolBalsRaw = preview_.balancesRaw;
        calc.chirIdx = preview_.chirIdx;
        calc.richIdx = preview_.richIdx;
        calc.vaultIdx = vaultIndex_;
        calc.sharesAdded = vaultShares_;
        calc.poolSupply = preview_.poolSupply;
        calc.bptAdded = bptOut;
        calc.newPosShares = layoutStruct_.protocolNFTVault.getPosition(layoutStruct_.protocolNFTId).originalShares + bptOut;
        calc.newTotShares = layoutStruct_.richirToken.totalShares() + bptOut;

        richirOut_ = BaseDualSelfCommonDETFPreviewHelpers.computeRichirOutFromDeposit(calc);
    }

    function _previewReservePoolBptOut(uint256 vaultIndex_, uint256 vaultShares_)
        internal
        view
        returns (ReservePoolBptPreviewOut memory preview_)
    {
        ReservePoolData memory resPoolData;
        (TokenInfo[] memory tokenInfo, uint256[] memory balancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);

        uint256[] memory balancesLiveScaled18 = new uint256[](balancesRaw.length);
        for (uint256 i = 0; i < balancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(balancesRaw[i], tokenInfo[i]);
        }

        uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[vaultIndex_]);

        uint256 bptOut = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
            balancesLiveScaled18,
            resPoolData.weightsArray,
            vaultIndex_,
            amountInLiveScaled18,
            resPoolData.resPoolTotalSupply,
            resPoolData.reservePoolSwapFee
        );

        // Apply precision buffer to ensure BPT preview never exceeds actual.
        // Accounts for rounding differences between pure math and Balancer Vault.
        bptOut = DETFPreviewLib._applyDiscountBps(bptOut, PREVIEW_BPT_BUFFER_BPS, PREVIEW_BPT_BUFFER_DENOMINATOR);

        preview_.balancesRaw = balancesRaw;
        preview_.bptOut = bptOut;
        preview_.poolSupply = resPoolData.resPoolTotalSupply;
        preview_.chirIdx = resPoolData.chirWethVaultIndex;
        preview_.richIdx = resPoolData.richChirVaultIndex;
    }

    /**
     * @notice Converts WETH to exact amount of RICHIR.
     */
    function _executeWethToRichirExact(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        amountIn_ = _previewWethToRichirExact(layoutStruct_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(layoutStruct_.wethToken, amountIn_, p_.pretransferred);

        layoutStruct_.wethToken.safeTransfer(address(layoutStruct_.chirWethVault), actualIn);
        uint256 chirWethShares = layoutStruct_.chirWethVault
            .exchangeIn(
                layoutStruct_.wethToken, actualIn, IERC20(address(layoutStruct_.chirWethVault)), 0, address(this), true, p_.deadline
            );

        uint256 bptOut = _addToReservePoolForExactOut(layoutStruct_, chirWethShares, layoutStruct_.chirWethVaultIndex);

        IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
        reservePoolToken.forceApprove(address(layoutStruct_.protocolNFTVault), bptOut);
        layoutStruct_.protocolNFTVault.addToProtocolNFT(layoutStruct_.protocolNFTId, bptOut);

        uint256 richirOut = layoutStruct_.richirToken.mintFromNFTSale(bptOut, p_.recipient);

        if (richirOut < p_.amountOut) {
            revert SlippageExceeded(p_.amountOut, richirOut);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                          Helper Functions                              */
    /* ---------------------------------------------------------------------- */

    function _rateOfLocal(TokenInfo memory t_) private view returns (uint256 rate_) {
        rate_ = FixedPoint.ONE;
        if (address(t_.rateProvider) != address(0)) {
            rate_ = t_.rateProvider.getRate();
        }
    }

    /**
     * @notice Adds vault shares to the reserve pool and returns BPT.
     */
    function _addToReservePoolForExactOut(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 vaultShares_,
        uint256 vaultIndex_
    ) internal returns (uint256 bptOut_) {
        ReservePoolData memory resPoolData;
        (TokenInfo[] memory tokenInfo, uint256[] memory currentBalancesRaw) = _loadReservePoolDataWithTokenInfo(resPoolData);

        uint256[] memory balancesLiveScaled18 = new uint256[](currentBalancesRaw.length);
        for (uint256 i = 0; i < currentBalancesRaw.length; ++i) {
            balancesLiveScaled18[i] = _toLiveScaled18(currentBalancesRaw[i], tokenInfo[i]);
        }

        uint256 amountInLiveScaled18 = _toLiveScaled18(vaultShares_, tokenInfo[vaultIndex_]);

        uint256[] memory amountsIn = new uint256[](2);
        amountsIn[vaultIndex_] = vaultShares_;

        bptOut_ = BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(
            balancesLiveScaled18,
            resPoolData.weightsArray,
            vaultIndex_,
            amountInLiveScaled18,
            resPoolData.resPoolTotalSupply,
            resPoolData.reservePoolSwapFee
        );

        IERC20 vaultToken = vaultIndex_ == layoutStruct_.chirWethVaultIndex
            ? IERC20(address(layoutStruct_.chirWethVault))
            : IERC20(address(layoutStruct_.richChirVault));
        vaultToken.safeTransfer(address(resPoolData.balV3Vault), vaultShares_);

        layoutStruct_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut_, "");

        ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
    }

    /**
     * @notice Exits reserve pool and unwinds to WETH.
     * @dev Split into helper functions to avoid stack-too-deep.
     */
    function _exitAndUnwindToWethForExactOut(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 bptIn_,
        uint256 deadline_
    ) internal returns (uint256 wethOut_) {
        // Exit pool and get vault shares
        uint256[] memory amountsOut = _exitReservePoolProportional(bptIn_);

        // Unwind CHIR/WETH vault to WETH
        uint256 wethFromChirWeth = _unwindChirWethVault(layoutStruct_, amountsOut[layoutStruct_.chirWethVaultIndex], deadline_);

        // Unwind RICH/CHIR vault to CHIR, then swap CHIR → WETH
        uint256 wethFromRichChir =
            _unwindRichChirVaultToWeth(layoutStruct_, amountsOut[layoutStruct_.richChirVaultIndex], deadline_);

        wethOut_ = wethFromChirWeth + wethFromRichChir;
    }

    /**
     * @notice Exits the reserve pool proportionally.
     */
    function _exitReservePoolProportional(uint256 bptIn_) internal returns (uint256[] memory amountsOut_) {
        IWeightedPool pool = _reservePool();
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct = BaseDualSelfCommonDETFRepo._layoutStruct();

        // Balancer V3 prepay remove-liquidity burns BPT from `params.sender` (the caller).
        // Do NOT pre-transfer BPT to the vault; instead, approve the prepay router to pull/burn it.
        IERC20(address(pool)).forceApprove(address(layoutStruct.balancerV3PrepayRouter), bptIn_);
        uint256[] memory minAmountsOut = new uint256[](2);
        amountsOut_ =
            layoutStruct.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(address(pool), bptIn_, minAmountsOut, "");
    }

    /**
     * @notice Unwinds CHIR/WETH vault shares to WETH.
     */
    function _unwindChirWethVault(BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_, uint256 vaultShares_, uint256 deadline_)
        internal
        returns (uint256 wethOut_)
    {
        if (vaultShares_ == 0) return 0;

        IERC20 vaultToken = IERC20(address(layoutStruct_.chirWethVault));
        vaultToken.forceApprove(address(layoutStruct_.chirWethVault), vaultShares_);
        wethOut_ = layoutStruct_.chirWethVault
            .exchangeIn(vaultToken, vaultShares_, layoutStruct_.wethToken, 0, address(this), false, deadline_);
    }

    /**
     * @notice Unwinds RICH/CHIR vault shares to WETH via CHIR intermediate.
     */
    function _unwindRichChirVaultToWeth(
        BaseDualSelfCommonDETFRepo.Storage storage layoutStruct_,
        uint256 vaultShares_,
        uint256 deadline_
    ) internal returns (uint256 wethOut_) {
        if (vaultShares_ == 0) return 0;

        // RICH/CHIR vault → CHIR
        IERC20 vaultToken = IERC20(address(layoutStruct_.richChirVault));
        vaultToken.forceApprove(address(layoutStruct_.richChirVault), vaultShares_);
        uint256 chirOut = layoutStruct_.richChirVault
            .exchangeIn(vaultToken, vaultShares_, IERC20(address(this)), 0, address(this), false, deadline_);

        // CHIR → WETH
        IERC20(address(this)).forceApprove(address(layoutStruct_.chirWethVault), chirOut);
        wethOut_ = layoutStruct_.chirWethVault
            .exchangeIn(IERC20(address(this)), chirOut, layoutStruct_.wethToken, 0, address(this), false, deadline_);
    }
}
