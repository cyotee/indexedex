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
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {BaseProtocolDETFCommon} from "contracts/vaults/protocol/BaseProtocolDETFCommon.sol";
import {BaseProtocolDETFPreviewHelpers} from "contracts/vaults/protocol/BaseProtocolDETFPreviewHelpers.sol";
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
 * @title BaseProtocolDETFExchangeOutTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of IStandardExchangeOut for Protocol DETF (CHIR).
 * @dev Handles exact-output exchanges:
 *      - WETH → CHIR (mint exact CHIR amount)
 *      - CHIR → RICH (buy exact RICH amount)
 *      - WETH → RICH (buy exact RICH amount via multi-hop)
 *      - RICH → CHIR (buy exact CHIR amount)
 */
contract BaseProtocolDETFExchangeOutTarget is BaseProtocolDETFCommon, ReentrancyLockModifiers, IStandardExchangeOut {
    using BetterSafeERC20 for IERC20;
    using FixedPoint for uint256;
    using BaseProtocolDETFRepo for BaseProtocolDETFRepo.Storage;

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
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        // Route: WETH → CHIR (mint exact CHIR)
        if (_isWethToken(layout, tokenIn_) && _isChirToken(tokenOut_)) {
            // Calculate synthetic price
            PoolReserves memory reserves;
            _loadPoolReserves(layout, reserves);
            uint256 syntheticPrice = _calcSyntheticPrice(reserves);

            // Verify minting is allowed
            if (!_isMintingAllowed(layout, syntheticPrice)) {
                revert MintingNotAllowed(syntheticPrice, layout.mintThreshold);
            }

            // Calculate required WETH using oracle incentive + AMM math
            amountIn_ = _calcRequiredWethForExactChir(layout, amountOut_, reserves);
            return amountIn_;
        }

        // Route: CHIR → RICH (buy exact RICH)
        if (_isChirToken(tokenIn_) && _isRichToken(layout, tokenOut_)) {
            // Delegate to RICH/CHIR vault
            amountIn_ = layout.richChirVault.previewExchangeOut(tokenIn_, tokenOut_, amountOut_);
            return amountIn_;
        }

        // Route: RICHIR → WETH - NOT SUPPORTED
        if (_isRichirToken(layout, tokenIn_) && _isWethToken(layout, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Route: WETH → RICH (buy exact RICH via multi-hop)
        if (_isWethToken(layout, tokenIn_) && _isRichToken(layout, tokenOut_)) {
            return _previewWethToRichExact(layout, amountOut_);
        }

        // Route: RICH → CHIR (buy exact CHIR via multi-hop)
        if (_isRichToken(layout, tokenIn_) && _isChirToken(tokenOut_)) {
            return _previewRichToChirExact(layout, amountOut_);
        }

        // Route: RICH → RICHIR - NOT SUPPORTED
        if (_isRichToken(layout, tokenIn_) && _isRichirToken(layout, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Route: WETH → RICHIR - NOT SUPPORTED
        if (_isWethToken(layout, tokenIn_) && _isRichirToken(layout, tokenOut_)) {
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

        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        // Calculate synthetic price once
        PoolReserves memory reserves;
        _loadPoolReserves(layout, reserves);
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
        if (_isWethToken(layout, tokenIn_) && _isChirToken(tokenOut_)) {
            amountIn_ = _executeMintExactChir(layout, params);
            return amountIn_;
        }

        // Route: CHIR → RICH (buy exact RICH)
        if (_isChirToken(tokenIn_) && _isRichToken(layout, tokenOut_)) {
            amountIn_ = _executeChirToRichExact(layout, params);
            return amountIn_;
        }

        // Route: RICHIR → WETH - NOT SUPPORTED
        if (_isRichirToken(layout, tokenIn_) && _isWethToken(layout, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Route: WETH → RICH (buy exact RICH via multi-hop)
        if (_isWethToken(layout, tokenIn_) && _isRichToken(layout, tokenOut_)) {
            amountIn_ = _executeWethToRichExact(layout, params);
            return amountIn_;
        }

        // Route: RICH → CHIR (buy exact CHIR via multi-hop)
        if (_isRichToken(layout, tokenIn_) && _isChirToken(tokenOut_)) {
            amountIn_ = _executeRichToChirExact(layout, params);
            return amountIn_;
        }

        // Route: RICH → RICHIR - NOT SUPPORTED
        if (_isRichToken(layout, tokenIn_) && _isRichirToken(layout, tokenOut_)) {
            revert IStandardExchangeErrors.RouteNotSupported(address(tokenIn_), address(tokenOut_), msg.sig);
        }

        // Route: WETH → RICHIR - NOT SUPPORTED
        if (_isWethToken(layout, tokenIn_) && _isRichirToken(layout, tokenOut_)) {
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
     * @param layout_ Storage layout reference
     * @param amountOut_ Exact CHIR amount desired
     * @param reserves_ Current pool reserves
     * @return amountIn_ Required WETH (rounded up with buffer to favor vault)
     */
    function _calcRequiredWethForExactChir(
        BaseProtocolDETFRepo.Storage storage layout_,
        uint256 amountOut_,
        PoolReserves memory reserves_
    ) internal view returns (uint256 amountIn_) {
        uint256 syntheticPrice = _calcSyntheticPrice(reserves_);

        if (syntheticPrice <= ONE_WAD) {
            amountIn_ = amountOut_;
        } else {
            uint256 incentivePercent = layout_._seigniorageIncentivePercentagePPM();

            uint256 FULL = 1e6;

            // If no incentive set (or very small), fall back to simple synthetic price math
            if (incentivePercent == 0 || incentivePercent >= FULL * 2) {
                amountIn_ = BetterMath._mulDiv(amountOut_, syntheticPrice, ONE_WAD, Math.Rounding.Ceil);
                amountIn_ = amountIn_ + ((amountIn_ * PREVIEW_WETH_CHIR_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);
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

        amountIn_ = amountIn_ + ((amountIn_ * PREVIEW_WETH_CHIR_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);
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
    function _executeMintExactChir(BaseProtocolDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        if (!_isMintingAllowed(layout_, p_.syntheticPrice)) {
            revert MintingNotAllowed(p_.syntheticPrice, layout_.mintThreshold);
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
        _calcSeigniorage(layout_, calc, actualIn);

        // Deposit WETH into CHIR/WETH vault
        p_.tokenIn.safeTransfer(address(layout_.chirWethVault), actualIn);
        layout_.chirWethVault
            .exchangeIn(
                p_.tokenIn, actualIn, IERC20(address(layout_.chirWethVault)), 0, address(this), true, p_.deadline
            );

        // Mint seigniorage to the NFT vault as reward-token accrual
        if (calc.seigniorageTokens > 0) {
            ERC20Repo._mint(address(layout_.protocolNFTVault), calc.seigniorageTokens);
        }

        // Mint exact CHIR to recipient
        ERC20Repo._mint(p_.recipient, p_.amountOut);

        // Refund excess WETH if pretransferred and we received more than needed
        if (p_.pretransferred && actualIn > amountIn_) {
            p_.tokenIn.safeTransfer(msg.sender, actualIn - amountIn_);
        }
    }

    /**
     * @notice Buys exact amount of RICH with CHIR.
     */
    function _executeChirToRichExact(BaseProtocolDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        // Calculate required CHIR for exact RICH output
        amountIn_ = layout_.richChirVault.previewExchangeOut(p_.tokenIn, p_.tokenOut, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        // Burn CHIR from sender
        _secureChirBurn(msg.sender, amountIn_, p_.pretransferred);

        // Execute exchange via RICH/CHIR vault
        // Mint CHIR to vault and exchange for RICH
        ERC20Repo._mint(address(layout_.richChirVault), amountIn_);

        layout_.richChirVault
            .exchangeOut(p_.tokenIn, amountIn_, p_.tokenOut, p_.amountOut, p_.recipient, true, p_.deadline);
    }

    /* ---------------------------------------------------------------------- */
    /*                      CHIR → WETH ExactOut Route                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required CHIR for exact WETH output.
     * @dev Uses binary search to find the minimum CHIR that yields exactWethOut.
     *      Rounds UP to favor the vault.
     * @param layout_ Storage layout reference
     * @param exactWethOut_ Exact WETH amount desired
     * @return chirIn_ Required CHIR input (rounded up)
     */
    function _previewChirToWethExact(BaseProtocolDETFRepo.Storage storage layout_, uint256 exactWethOut_)
        internal
        view
        returns (uint256 chirIn_)
    {
        if (exactWethOut_ == 0) return 0;

        PoolReserves memory reserves;
        _loadPoolReserves(layout_, reserves);
        uint256 syntheticPrice = _calcSyntheticPrice(reserves);

        // Verify burning is allowed
        if (!_isBurningAllowed(layout_, syntheticPrice)) {
            revert BurningNotAllowed(syntheticPrice, layout_.burnThreshold);
        }

        // Binary search for minimum CHIR that yields at least exactWethOut
        uint256 low = exactWethOut_;
        uint256 high = exactWethOut_ * 2;

        // Expand high bound if needed (with iteration limit)
        uint256 MAX_ITERATIONS = 128;
        uint256 iterations = 0;
        uint256 wethFromHigh = layout_.chirWethVault.previewExchangeIn(IERC20(address(this)), high, layout_.wethToken);
        while (wethFromHigh < exactWethOut_ && high < type(uint128).max && iterations < MAX_ITERATIONS) {
            high = high * 2;
            wethFromHigh = layout_.chirWethVault.previewExchangeIn(IERC20(address(this)), high, layout_.wethToken);
            ++iterations;
        }

        // Binary search (bounded)
        iterations = 0;
        while (low < high && iterations < MAX_ITERATIONS) {
            uint256 mid = (low + high) / 2;
            uint256 wethOut = layout_.chirWethVault.previewExchangeIn(IERC20(address(this)), mid, layout_.wethToken);
            if (wethOut < exactWethOut_) {
                low = mid + 1;
            } else {
                high = mid;
            }
            ++iterations;
        }

        // Final verification with round-up
        chirIn_ = low;
        uint256 wethCheck = layout_.chirWethVault.previewExchangeIn(IERC20(address(this)), chirIn_, layout_.wethToken);
        if (wethCheck < exactWethOut_) {
            chirIn_ += 1;
        }
    }

    /**
     * @notice Redeems CHIR for exact amount of WETH.
     */
    function _executeChirToWethExact(BaseProtocolDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        if (!_isBurningAllowed(layout_, p_.syntheticPrice)) {
            revert BurningNotAllowed(p_.syntheticPrice, layout_.burnThreshold);
        }

        // Calculate required CHIR for exact WETH output
        amountIn_ = _previewChirToWethExact(layout_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        // Burn CHIR from sender
        _secureChirBurn(msg.sender, amountIn_, p_.pretransferred);

        // Mint CHIR to vault and swap for WETH
        ERC20Repo._mint(address(layout_.chirWethVault), amountIn_);

        uint256 wethOut = layout_.chirWethVault
            .exchangeIn(
                IERC20(address(this)), amountIn_, layout_.wethToken, p_.amountOut, p_.recipient, true, p_.deadline
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
     * @param layout_ Storage layout reference
     * @param exactWethOut_ Exact WETH amount desired
     * @return richirIn_ Required RICHIR input (rounded up)
     */
    function _previewRichirToWethExact(BaseProtocolDETFRepo.Storage storage layout_, uint256 exactWethOut_)
        internal
        view
        returns (uint256 richirIn_)
    {
        if (exactWethOut_ == 0) return 0;

        uint256 redemptionRate = layout_.richirToken.redemptionRate();
        if (redemptionRate == 0) {
            revert ZeroAmount();
        }

        // richirIn = exactWethOut * 1e18 / rate (round UP)
        richirIn_ = BetterMath._mulDiv(exactWethOut_, ONE_WAD, redemptionRate, Math.Rounding.Ceil);
    }

    /**
     * @notice Redeems RICHIR for exact amount of WETH.
     */
    function _executeRichirToWethExact(BaseProtocolDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        // Calculate required RICHIR
        amountIn_ = _previewRichirToWethExact(layout_, p_.amountOut);

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
        uint256 richirShares = layout_.richirToken.convertToShares(richirBalance);
        uint256 totalRichirShares = layout_.richirToken.totalShares();
        uint256 protocolNftBpt = layout_.protocolNFTVault.originalSharesOf(layout_.protocolNFTId);
        uint256 bptIn = (richirShares * protocolNftBpt) / totalRichirShares;

        // Burn RICHIR first
        p_.tokenIn.safeTransfer(address(layout_.richirToken), richirBalance);
        layout_.richirToken.burnShares(richirBalance, address(0), true);

        // Exit reserve pool and unwind to WETH
        uint256 wethOut = _exitAndUnwindToWethForExactOut(layout_, bptIn, p_.deadline);

        // Verify exact output
        if (wethOut < p_.amountOut) {
            revert SlippageExceeded(p_.amountOut, wethOut);
        }

        // Send exact WETH to recipient
        layout_.wethToken.safeTransfer(p_.recipient, p_.amountOut);

        // Refund excess WETH
        if (wethOut > p_.amountOut) {
            layout_.wethToken.safeTransfer(msg.sender, wethOut - p_.amountOut);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                      WETH → RICH ExactOut Route                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required WETH for exact RICH output.
     * @dev Multi-hop: WETH → CHIR → RICH. Works backwards.
     */
    function _previewWethToRichExact(BaseProtocolDETFRepo.Storage storage layout_, uint256 exactRichOut_)
        internal
        view
        returns (uint256 wethIn_)
    {
        if (exactRichOut_ == 0) return 0;

        // Step 1: CHIR needed for exact RICH
        uint256 chirNeeded =
            layout_.richChirVault.previewExchangeOut(IERC20(address(this)), layout_.richToken, exactRichOut_);

        // Step 2: WETH needed for that CHIR
        wethIn_ = layout_.chirWethVault.previewExchangeOut(layout_.wethToken, IERC20(address(this)), chirNeeded);
    }

    /**
     * @notice Buys exact amount of RICH with WETH via multi-hop.
     */
    function _executeWethToRichExact(BaseProtocolDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        amountIn_ = _previewWethToRichExact(layout_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(layout_.wethToken, amountIn_, p_.pretransferred);

        // Step 1: WETH → CHIR
        layout_.wethToken.safeTransfer(address(layout_.chirWethVault), actualIn);
        uint256 chirOut = layout_.chirWethVault
            .exchangeIn(layout_.wethToken, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);

        // Step 2: CHIR → RICH (exact out)
        IERC20(address(this)).safeTransfer(address(layout_.richChirVault), chirOut);
        layout_.richChirVault
            .exchangeOut(
                IERC20(address(this)), chirOut, layout_.richToken, p_.amountOut, p_.recipient, true, p_.deadline
            );
    }

    /* ---------------------------------------------------------------------- */
    /*                      RICH → CHIR ExactOut Route                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required RICH for exact CHIR output.
     * @dev Multi-hop: RICH → CHIR → WETH → mint CHIR. Works backwards.
     */
    function _previewRichToChirExact(BaseProtocolDETFRepo.Storage storage layout_, uint256 exactChirOut_)
        internal
        view
        returns (uint256 richIn_)
    {
        if (exactChirOut_ == 0) return 0;

        PoolReserves memory reserves;
        _loadPoolReserves(layout_, reserves);
        uint256 syntheticPrice = _calcSyntheticPrice(reserves);

        if (!_isMintingAllowed(layout_, syntheticPrice)) {
            revert MintingNotAllowed(syntheticPrice, layout_.mintThreshold);
        }

        // Work backwards:
        // 1. WETH needed for exact CHIR mint (use oracle-based preview with buffer)
        uint256 wethNeeded = _calcRequiredWethForExactChir(layout_, exactChirOut_, reserves);

        // 2. CHIR needed to get that WETH
        uint256 chirNeeded =
            layout_.chirWethVault.previewExchangeOut(IERC20(address(this)), layout_.wethToken, wethNeeded);

        // 3. RICH needed to get that CHIR
        richIn_ = layout_.richChirVault.previewExchangeOut(layout_.richToken, IERC20(address(this)), chirNeeded);
    }

    /**
     * @notice Converts RICH to exact amount of CHIR via multi-hop mint.
     */
    function _executeRichToChirExact(BaseProtocolDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        if (!_isMintingAllowed(layout_, p_.syntheticPrice)) {
            revert MintingNotAllowed(p_.syntheticPrice, layout_.mintThreshold);
        }

        amountIn_ = _previewRichToChirExact(layout_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(layout_.richToken, amountIn_, p_.pretransferred);

        // Step 1: RICH → CHIR
        layout_.richToken.safeTransfer(address(layout_.richChirVault), actualIn);
        uint256 chirOut = layout_.richChirVault
            .exchangeIn(layout_.richToken, actualIn, IERC20(address(this)), 0, address(this), true, p_.deadline);

        // Step 2: CHIR → WETH
        IERC20(address(this)).safeTransfer(address(layout_.chirWethVault), chirOut);
        uint256 wethOut = layout_.chirWethVault
            .exchangeIn(IERC20(address(this)), chirOut, layout_.wethToken, 0, address(this), true, p_.deadline);

        // Step 3: Mint exact CHIR with WETH
        ExchangeOutParams memory mintParams = ExchangeOutParams({
            tokenIn: layout_.wethToken,
            maxAmountIn: wethOut,
            tokenOut: IERC20(address(this)),
            amountOut: p_.amountOut,
            recipient: p_.recipient,
            pretransferred: true,
            deadline: p_.deadline,
            syntheticPrice: p_.syntheticPrice
        });
        _executeMintExactChir(layout_, mintParams);
    }

    /* ---------------------------------------------------------------------- */
    /*                     RICH → RICHIR ExactOut Route                       */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Previews required RICH for exact RICHIR output.
     * @dev Uses binary search with forward preview simulation.
     */
    function _previewRichToRichirExact(BaseProtocolDETFRepo.Storage storage layout_, uint256 exactRichirOut_)
        internal
        view
        returns (uint256 richIn_)
    {
        if (exactRichirOut_ == 0) return 0;

        // Binary search
        uint256 low = 1;
        uint256 high = exactRichirOut_ * 2;

        uint256 richirFromHigh = _previewRichToRichirForward(layout_, high);
        while (richirFromHigh < exactRichirOut_ && high < type(uint128).max) {
            high = high * 2;
            richirFromHigh = _previewRichToRichirForward(layout_, high);
        }

        while (low < high) {
            uint256 mid = (low + high) / 2;
            uint256 richirOut = _previewRichToRichirForward(layout_, mid);
            if (richirOut < exactRichirOut_) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }

        richIn_ = low;

        // Apply precision buffer to ensure preview overestimates input required.
        // previewExchangeOut should overestimate (return ≥ actual input needed).
        richIn_ = richIn_ + ((richIn_ * PREVIEW_RICHIR_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);
    }

    /**
     * @notice Forward preview for RICH → RICHIR.
     */
    function _previewRichToRichirForward(BaseProtocolDETFRepo.Storage storage layout_, uint256 richIn_)
        internal
        view
        returns (uint256 richirOut_)
    {
        if (richIn_ == 0) return 0;

        // Simulate Aerodrome fee compound to get accurate post-compound vault shares
        uint256 vaultShares = _previewVaultSharesPostCompound(layout_.richChirVault, layout_.richToken, richIn_);

        richirOut_ = _previewRichirOutFromVaultShares(layout_, layout_.richChirVaultIndex, vaultShares);
    }

    /**
     * @notice Converts RICH to exact amount of RICHIR.
     */
    function _executeRichToRichirExact(BaseProtocolDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        amountIn_ = _previewRichToRichirExact(layout_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(layout_.richToken, amountIn_, p_.pretransferred);

        layout_.richToken.safeTransfer(address(layout_.richChirVault), actualIn);
        uint256 richChirShares = layout_.richChirVault
            .exchangeIn(
                layout_.richToken, actualIn, IERC20(address(layout_.richChirVault)), 0, address(this), true, p_.deadline
            );

        uint256 bptOut = _addToReservePoolForExactOut(layout_, richChirShares, layout_.richChirVaultIndex);

        IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
        reservePoolToken.forceApprove(address(layout_.protocolNFTVault), bptOut);
        layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, bptOut);

        uint256 richirOut = layout_.richirToken.mintFromNFTSale(bptOut, p_.recipient);

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
    function _previewWethToRichirExact(BaseProtocolDETFRepo.Storage storage layout_, uint256 exactRichirOut_)
        internal
        view
        returns (uint256 wethIn_)
    {
        if (exactRichirOut_ == 0) return 0;

        // Binary search
        uint256 low = 1;
        uint256 high = exactRichirOut_ * 2;

        uint256 richirFromHigh = _previewWethToRichirForward(layout_, high);
        while (richirFromHigh < exactRichirOut_ && high < type(uint128).max) {
            high = high * 2;
            richirFromHigh = _previewWethToRichirForward(layout_, high);
        }

        while (low < high) {
            uint256 mid = (low + high) / 2;
            uint256 richirOut = _previewWethToRichirForward(layout_, mid);
            if (richirOut < exactRichirOut_) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }

        wethIn_ = low;

        // Apply precision buffer to ensure preview overestimates input required.
        // previewExchangeOut should overestimate (return ≥ actual input needed).
        wethIn_ = wethIn_ + ((wethIn_ * PREVIEW_RICHIR_BUFFER_BPS) / PREVIEW_BUFFER_DENOMINATOR);
    }

    /**
     * @notice Forward preview for WETH → RICHIR.
     */
    function _previewWethToRichirForward(BaseProtocolDETFRepo.Storage storage layout_, uint256 wethIn_)
        internal
        view
        returns (uint256 richirOut_)
    {
        if (wethIn_ == 0) return 0;

        // Simulate Aerodrome fee compound to get accurate post-compound vault shares
        uint256 vaultShares = _previewVaultSharesPostCompound(layout_.chirWethVault, layout_.wethToken, wethIn_);

        richirOut_ = _previewRichirOutFromVaultShares(layout_, layout_.chirWethVaultIndex, vaultShares);
    }

    function _previewRichirOutFromVaultShares(
        BaseProtocolDETFRepo.Storage storage layout_,
        uint256 vaultIndex_,
        uint256 vaultShares_
    ) internal view returns (uint256 richirOut_) {
        ReservePoolBptPreviewOut memory preview_ = _previewReservePoolBptOut(vaultIndex_, vaultShares_);
        uint256 bptOut = preview_.bptOut;

        ReservePoolData memory resPoolData;
        _loadReservePoolData(resPoolData, new uint256[](0));

        BaseProtocolDETFPreviewHelpers.RichirCalc memory calc;
        calc.balV3Vault = address(resPoolData.balV3Vault);
        calc.reservePool = address(resPoolData.reservePool);
        calc.reservePoolSwapFee = resPoolData.reservePoolSwapFee;
        calc.weightsArray = resPoolData.weightsArray;
        calc.chirWethVault = address(layout_.chirWethVault);
        calc.richChirVault = address(layout_.richChirVault);
        calc.chirToken = address(this);
        calc.wethToken = address(layout_.wethToken);
        calc.poolBalsRaw = preview_.balancesRaw;
        calc.chirIdx = preview_.chirIdx;
        calc.richIdx = preview_.richIdx;
        calc.vaultIdx = vaultIndex_;
        calc.sharesAdded = vaultShares_;
        calc.poolSupply = preview_.poolSupply;
        calc.bptAdded = bptOut;
        calc.newPosShares = layout_.protocolNFTVault.getPosition(layout_.protocolNFTId).originalShares + bptOut;
        calc.newTotShares = layout_.richirToken.totalShares() + bptOut;

        richirOut_ = BaseProtocolDETFPreviewHelpers.computeRichirOutFromDeposit(calc);
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
        bptOut = bptOut - ((bptOut * PREVIEW_BPT_BUFFER_BPS) / PREVIEW_BPT_BUFFER_DENOMINATOR);

        preview_.balancesRaw = balancesRaw;
        preview_.bptOut = bptOut;
        preview_.poolSupply = resPoolData.resPoolTotalSupply;
        preview_.chirIdx = resPoolData.chirWethVaultIndex;
        preview_.richIdx = resPoolData.richChirVaultIndex;
    }

    /**
     * @notice Converts WETH to exact amount of RICHIR.
     */
    function _executeWethToRichirExact(BaseProtocolDETFRepo.Storage storage layout_, ExchangeOutParams memory p_)
        internal
        returns (uint256 amountIn_)
    {
        amountIn_ = _previewWethToRichirExact(layout_, p_.amountOut);

        if (amountIn_ > p_.maxAmountIn) {
            revert SlippageExceeded(p_.maxAmountIn, amountIn_);
        }

        uint256 actualIn = _secureTokenTransfer(layout_.wethToken, amountIn_, p_.pretransferred);

        layout_.wethToken.safeTransfer(address(layout_.chirWethVault), actualIn);
        uint256 chirWethShares = layout_.chirWethVault
            .exchangeIn(
                layout_.wethToken, actualIn, IERC20(address(layout_.chirWethVault)), 0, address(this), true, p_.deadline
            );

        uint256 bptOut = _addToReservePoolForExactOut(layout_, chirWethShares, layout_.chirWethVaultIndex);

        IERC20 reservePoolToken = IERC20(address(ERC4626Repo._reserveAsset()));
        reservePoolToken.forceApprove(address(layout_.protocolNFTVault), bptOut);
        layout_.protocolNFTVault.addToProtocolNFT(layout_.protocolNFTId, bptOut);

        uint256 richirOut = layout_.richirToken.mintFromNFTSale(bptOut, p_.recipient);

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
        BaseProtocolDETFRepo.Storage storage layout_,
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

        IERC20 vaultToken = vaultIndex_ == layout_.chirWethVaultIndex
            ? IERC20(address(layout_.chirWethVault))
            : IERC20(address(layout_.richChirVault));
        vaultToken.safeTransfer(address(resPoolData.balV3Vault), vaultShares_);

        layout_.balancerV3PrepayRouter
            .prepayAddLiquidityUnbalanced(address(resPoolData.reservePool), amountsIn, bptOut_, "");

        ERC4626Repo._setLastTotalAssets(IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this)));
    }

    /**
     * @notice Exits reserve pool and unwinds to WETH.
     * @dev Split into helper functions to avoid stack-too-deep.
     */
    function _exitAndUnwindToWethForExactOut(
        BaseProtocolDETFRepo.Storage storage layout_,
        uint256 bptIn_,
        uint256 deadline_
    ) internal returns (uint256 wethOut_) {
        // Exit pool and get vault shares
        uint256[] memory amountsOut = _exitReservePoolProportional(bptIn_);

        // Unwind CHIR/WETH vault to WETH
        uint256 wethFromChirWeth = _unwindChirWethVault(layout_, amountsOut[layout_.chirWethVaultIndex], deadline_);

        // Unwind RICH/CHIR vault to CHIR, then swap CHIR → WETH
        uint256 wethFromRichChir =
            _unwindRichChirVaultToWeth(layout_, amountsOut[layout_.richChirVaultIndex], deadline_);

        wethOut_ = wethFromChirWeth + wethFromRichChir;
    }

    /**
     * @notice Exits the reserve pool proportionally.
     */
    function _exitReservePoolProportional(uint256 bptIn_) internal returns (uint256[] memory amountsOut_) {
        IWeightedPool pool = _reservePool();
        BaseProtocolDETFRepo.Storage storage layout = BaseProtocolDETFRepo._layout();

        // Balancer V3 prepay remove-liquidity burns BPT from `params.sender` (the caller).
        // Do NOT pre-transfer BPT to the vault; instead, approve the prepay router to pull/burn it.
        IERC20(address(pool)).forceApprove(address(layout.balancerV3PrepayRouter), bptIn_);
        uint256[] memory minAmountsOut = new uint256[](2);
        amountsOut_ =
            layout.balancerV3PrepayRouter.prepayRemoveLiquidityProportional(address(pool), bptIn_, minAmountsOut, "");
    }

    /**
     * @notice Unwinds CHIR/WETH vault shares to WETH.
     */
    function _unwindChirWethVault(BaseProtocolDETFRepo.Storage storage layout_, uint256 vaultShares_, uint256 deadline_)
        internal
        returns (uint256 wethOut_)
    {
        if (vaultShares_ == 0) return 0;

        IERC20 vaultToken = IERC20(address(layout_.chirWethVault));
        vaultToken.forceApprove(address(layout_.chirWethVault), vaultShares_);
        wethOut_ = layout_.chirWethVault
            .exchangeIn(vaultToken, vaultShares_, layout_.wethToken, 0, address(this), false, deadline_);
    }

    /**
     * @notice Unwinds RICH/CHIR vault shares to WETH via CHIR intermediate.
     */
    function _unwindRichChirVaultToWeth(
        BaseProtocolDETFRepo.Storage storage layout_,
        uint256 vaultShares_,
        uint256 deadline_
    ) internal returns (uint256 wethOut_) {
        if (vaultShares_ == 0) return 0;

        // RICH/CHIR vault → CHIR
        IERC20 vaultToken = IERC20(address(layout_.richChirVault));
        vaultToken.forceApprove(address(layout_.richChirVault), vaultShares_);
        uint256 chirOut = layout_.richChirVault
            .exchangeIn(vaultToken, vaultShares_, IERC20(address(this)), 0, address(this), false, deadline_);

        // CHIR → WETH
        IERC20(address(this)).forceApprove(address(layout_.chirWethVault), chirOut);
        wethOut_ = layout_.chirWethVault
            .exchangeIn(IERC20(address(this)), chirOut, layout_.wethToken, 0, address(this), false, deadline_);
    }
}
