// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurnProxy} from "@crane/contracts/interfaces/proxies/IERC20MintBurnProxy.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {ISeigniorageDETFErrors} from "contracts/interfaces/ISeigniorageDETFErrors.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {WeightedMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {
    BalancerV38020WeightedPoolMath
} from "@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {ERC4626Service} from "@crane/contracts/tokens/ERC4626/ERC4626Service.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {SeigniorageVaultRepo} from "contracts/protocols/dexes/balancer/v3/vaults/SeigniorageVaultRepo.sol";
import {
    BalancerV3StandardExchangeRouterAwareRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterAwareRepo.sol";
import {WeightedPoolReserveVaultRepo} from "contracts/vaults/standard/WeightedPoolReserveVaultRepo.sol";
import {
    StandardExchangeSingleVaultSeigniorageDETFCommon
} from "contracts/protocols/dexes/balancer/v3/vaults/StandardExchangeSingleVaultSeigniorageDETFCommon.sol";

contract StandardExchangeSingleVaultSeigniorageDETFExchangeInTarget is
    StandardExchangeSingleVaultSeigniorageDETFCommon,
    IStandardExchangeIn,
    ISeigniorageDETFErrors
{
    using BetterSafeERC20 for IERC20;

    /* ------------------------- IStandardExchangeIn ------------------------ */

    /**
     * @param tokenIn The token provided to the vault for an exchange.
     * @param amountIn The amount of `tokenIn` the users wishes to exchange for `tokenOut`.
     * @param tokenOut The token the caller wishes to receive in exchange for `tokenIn`.
     * @return amountOut The amount of `tokenOut` the caller will receive in exchange for `amountIn` of `tokenIn`.
     * @custom:selector 0x89d61912
     */
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        //
    }

    struct ExchangeInArgs {
        IERC20 tokenIn;
        uint256 amountIn;
        IERC20 tokenOut;
        uint256 minAmountOut;
        address recipient;
        bool pretransferred;
        uint256 deadline;
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external onOrBeforeDeadline(deadline) returns (uint256 amountOut) {
        ExchangeInArgs memory args = ExchangeInArgs({
            tokenIn: tokenIn,
            amountIn: amountIn,
            tokenOut: tokenOut,
            minAmountOut: minAmountOut,
            recipient: recipient,
            pretransferred: pretransferred,
            deadline: deadline
        });
        // IERC20MintBurnProxy seigniorageToken = SeigniorageVaultRepo._seigniorageToken();
        SRBTData memory sRbtData;
        sRbtData.seigniorageToken = SeigniorageVaultRepo._seigniorageToken();

        /* ------------------------ Seigniorage Mint ------------------------ */

        // Check for seigniorage token minting first.
        if (address(args.tokenIn) == address(this) && address(args.tokenOut) == address(sRbtData.seigniorageToken)) {
            // Can always burn RBT to mint seigniorage token.
            // No price check needed, seigniorage always mints at 1:1.
            // Burn first to fail fast and ensure consistency.
            // Reuse amountIn to save memory.
            args.amountIn = _secureSelfBurn(msg.sender, args.amountIn, args.pretransferred);
            // Mint seigniorage token directly to recipient.
            sRbtData.seigniorageToken.mint(args.recipient, args.amountIn);
            // Return to short-circuit remaining logic.
            return args.amountIn;
        }

        ReservePoolData memory resPoolData;
        resPoolData.balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        resPoolData.reservePool = WeightedPoolReserveVaultRepo._reservePool();
        resPoolData.reservePoolSwapFee =
            resPoolData.balV3Vault.getStaticSwapFeePercentage(address(resPoolData.reservePool));
        // These values are rated based on configured rate provider(s).
        uint256[] memory currentRatedBalances =
            resPoolData.balV3Vault.getCurrentLiveBalances(address(resPoolData.reservePool));
        // Safe to use local cached value because pool token array order does not change.
        resPoolData.reserveVaultIndexInReservePool =
            WeightedPoolReserveVaultRepo._indexInReservePool(address(SeigniorageVaultRepo._reserveVault()));
        resPoolData.selfIndexInReservePool = WeightedPoolReserveVaultRepo._indexInReservePool(address(this));
        // Cheaper to make many successive reads from struct member compared to array member.
        resPoolData.reserveVaultRatedBalance = currentRatedBalances[resPoolData.reserveVaultIndexInReservePool];
        resPoolData.selfReservePoolRatedBalance = currentRatedBalances[resPoolData.selfIndexInReservePool];
        // Using cached values is safe because weighting never changes.
        resPoolData.reserveVaultReservePoolWeight =
            WeightedPoolReserveVaultRepo._weightInReservePool(address(SeigniorageVaultRepo._reserveVault()));
        resPoolData.selfReservePoolWeight = WeightedPoolReserveVaultRepo._weightInReservePool(address(this));

        RBTData memory rbtData;

        // Load total supplies.
        // Sum of RBT and seigniorage token supplies for diluted price.
        // Using diluted price as it reflects total claims on reserve vault.
        // This also means that noncirculating tokens are included in price checks.
        // Including noncirculating supply is intentional to prevent drastic crash.
        rbtData.selfTotalSupply = ERC20Repo._totalSupply();

        sRbtData.srbtTotalSupply = sRbtData.seigniorageToken.totalSupply();

        // Calculate the amount of reserve vault token owed or would be purchased for when sRBT is redeemed.
        sRbtData.sRbtReserveVaultDebt = WeightedMath.computeOutGivenExactIn(
            // uint256 balanceIn,
            resPoolData.selfReservePoolRatedBalance,
            // uint256 weightIn,
            resPoolData.selfReservePoolWeight,
            // uint256 balanceOut,
            resPoolData.reserveVaultRatedBalance,
            // uint256 weightOut,
            resPoolData.reserveVaultReservePoolWeight,
            // uint256 amountIn
            FixedPoint.mulDown(sRbtData.srbtTotalSupply, FixedPoint.ONE - resPoolData.reservePoolSwapFee)
        );

        // Calculate diluted price minus the reserve token token debt owed via sRBT.
        rbtData.selfDilutedPrice = BalancerV38020WeightedPoolMath._priceFromReserves(
            // uint256 baseCurrencyReserve,
            resPoolData.reserveVaultRatedBalance - sRbtData.sRbtReserveVaultDebt,
            // uint256 quoteCurrencyReserve,
            rbtData.selfTotalSupply + sRbtData.srbtTotalSupply,
            // uint256 baseCurrencyWeight,
            resPoolData.reserveVaultReservePoolWeight,
            // uint256 quoteCurrencyWeight
            resPoolData.selfReservePoolWeight
        );

        /* ------------------------ Seigniorage Burn ------------------------ */

        // Check if this is a seigniorage token burn for RBT mint.
        if (address(args.tokenIn) == address(sRbtData.seigniorageToken) && address(args.tokenOut) == address(this)) {
            // Check if price is below or equal to peg.
            if (rbtData.selfDilutedPrice <= ONE_WAD) {
                // If below peg, refuse to expand RBT supply.
                revert PriceBelowPeg(rbtData.selfDilutedPrice, ONE_WAD);
            }
            // Check if pretransfer was declares.
            if (args.pretransferred == true) {
                // If pretransferred, burn own balance.
                // RBT holds no sRBT balance, so no need to check reserve.
                // Burn will revert for insufficient balance.
                // No need to confirm receipt.
                sRbtData.seigniorageToken.burn(address(this), args.amountIn);
            } else {
                // If not pretransferred, burn from msg.sender.
                sRbtData.seigniorageToken.burn(msg.sender, args.amountIn);
            }
            // sRBT mints RBT 1:1.
            ERC20Repo._mint(args.recipient, amountOut);
            return amountOut;
        }

        // Create pool weighting array for calculating expected required BPT.
        resPoolData.weightsArray = new uint256[](2);
        resPoolData.weightsArray[resPoolData.reserveVaultIndexInReservePool] = resPoolData.reserveVaultReservePoolWeight;
        resPoolData.weightsArray[resPoolData.selfIndexInReservePool] = resPoolData.selfReservePoolWeight;

        resPoolData.resPoolTotalSupply = resPoolData.balV3Vault.totalSupply(address(resPoolData.reservePool));
        // Load reserve vault address;
        rbtData.reserveVault = SeigniorageVaultRepo._reserveVault();

        /* ------------- DETF Burn for Reserve Vault Withdrawal ------------- */

        // Check if this is is a burn to redeem.
        if (address(args.tokenIn) == address(this) && address(args.tokenOut) == address(rbtData.reserveVault)) {
            // Check is above peg.
            if (rbtData.selfDilutedPrice > ONE_WAD) {
                // Reject redemption if above peg.
                revert PriceAbovePeg(rbtData.selfDilutedPrice, ONE_WAD);
            }

            // Secure RBT burn, allow failure to revert to revert remaining logic.
            args.amountIn = _secureSelfBurn(address(this), args.amountIn, args.pretransferred);
            // Compute effectiveIn with REDUCED fee
            uint256 amountInWithReducedFeeApplied = FixedPoint.mulDown(
                args.amountIn,
                // FixedPoint.ONE - rbtData.rbtSwapFee
                FixedPoint.ONE
                    - BetterMath._percentageOfWAD(
                        resPoolData.reservePoolSwapFee,
                        VaultFeeOracleQueryAwareRepo._feeOracle().seigniorageIncentivePercentageOfVault(address(this))
                    )
            );
            // Compute actual amountOut using reduced-fee effective input
            amountOut = WeightedMath.computeOutGivenExactIn(
                // uint256 balanceIn,
                resPoolData.selfReservePoolRatedBalance,
                // uint256 weightIn,
                resPoolData.selfReservePoolWeight,
                // uint256 balanceOut,
                resPoolData.reserveVaultRatedBalance,
                // uint256 weightOut,
                resPoolData.reserveVaultReservePoolWeight,
                // uint256 amountIn
                amountInWithReducedFeeApplied
            );
            // Check that minimum amount out has been met.
            if (amountOut < args.minAmountOut) {
                revert MinAmountNotMet(args.minAmountOut, amountOut);
            }
            // Calculate expected BPT in for single-asset out removal.
            resPoolData.expectedBpt = BalancerV38020WeightedPoolMath._calcBptInGivenProportionalOut(
                // uint256[] memory balances,
                currentRatedBalances,
                // uint256 totalSupply,
                resPoolData.resPoolTotalSupply,
                // uint256 desiredTokenIndex,
                resPoolData.reserveVaultIndexInReservePool,
                // uint256 desiredAmountOut
                amountOut
            );

            // Call interrupter to remove liquidity single-asset out (Strategy)
            uint256[] memory minAmountsOut = new uint256[](2);
            minAmountsOut[resPoolData.reserveVaultIndexInReservePool] = amountOut;
            IERC20(address(resPoolData.reservePool)).transfer(address(resPoolData.balV3Vault), resPoolData.expectedBpt);
            IBalancerV3StandardExchangeRouterProxy seRouter =
                BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter();
            // uint256[] memory withdrawnAmounts =
            seRouter.prepayRemoveLiquidityProportional(
                // address pool,
                address(resPoolData.reservePool),
                // uint256 exactBptAmountIn,
                resPoolData.expectedBpt,
                // uint256[] memory minAmountsOut,
                minAmountsOut,
                // bool wethIsEth,
                // false,
                // bytes memory userData
                ""
            );
            args.tokenOut.transfer(address(args.recipient), amountOut);
            uint256[] memory unUsedAmountOut = new uint256[](2);
            unUsedAmountOut[resPoolData.reserveVaultIndexInReservePool] =
                IERC20(address(rbtData.reserveVault)).balanceOf(address(this));
            unUsedAmountOut[resPoolData.selfIndexInReservePool] = ERC20Repo._balanceOf(address(this));
            currentRatedBalances = resPoolData.balV3Vault.getCurrentLiveBalances(address(resPoolData.reservePool));
            resPoolData.resPoolTotalSupply = resPoolData.balV3Vault.totalSupply(address(resPoolData.reservePool));
            resPoolData.expectedBpt = BalancerV38020WeightedPoolMath._calcBptOutGivenUnbalancedIn(
                // uint256[] memory balances,
                currentRatedBalances,
                // uint256[] memory normalizedWeights,
                resPoolData.weightsArray,
                // uint256[] memory amountsIn,
                unUsedAmountOut,
                // uint256 totalSupply,
                resPoolData.resPoolTotalSupply,
                // uint256 swapFeePercentage
                resPoolData.reservePoolSwapFee
            );
            seRouter.prepayAddLiquidityUnbalanced(
                // address pool,
                address(resPoolData.reservePool),
                // uint256[] memory exactAmountsIn,
                unUsedAmountOut,
                // uint256 minBptAmountOut,
                resPoolData.expectedBpt,
                // bool wethIsEth,
                // false,
                // bytes memory userData
                ""
            );
            ERC4626Repo._setLastTotalAssets(IERC20(address(resPoolData.reservePool)).balanceOf(address(this)));

            return amountOut;
        }

        /* --------- DETF Burn for Reserve Vault Contents Withdrawal -------- */

        // Check if this is is a burn to redeem.
        if (
            address(args.tokenIn) == address(this)
                && WeightedPoolReserveVaultRepo._isReserveAssetContents(address(args.tokenOut))
        ) {
            // Check is above peg.
            if (rbtData.selfDilutedPrice > ONE_WAD) {
                // Reject redemption if above peg.
                revert PriceAbovePeg(rbtData.selfDilutedPrice, ONE_WAD);
            }

            // Secure RBT burn, allow failure to revert to revert remaining logic.
            args.amountIn = _secureSelfBurn(address(this), args.amountIn, args.pretransferred);
            // Compute effectiveIn with REDUCED fee
            uint256 amountInWithReducedFeeApplied = FixedPoint.mulDown(
                args.amountIn,
                // FixedPoint.ONE - rbtData.rbtSwapFee
                FixedPoint.ONE
                    - BetterMath._percentageOfWAD(
                        resPoolData.reservePoolSwapFee,
                        VaultFeeOracleQueryAwareRepo._feeOracle().seigniorageIncentivePercentageOfVault(address(this))
                    )
            );
            // Compute actual amountOut using reduced-fee effective input
            amountOut = WeightedMath.computeOutGivenExactIn(
                // uint256 balanceIn,
                resPoolData.selfReservePoolRatedBalance,
                // uint256 weightIn,
                resPoolData.selfReservePoolWeight,
                // uint256 balanceOut,
                resPoolData.reserveVaultRatedBalance,
                // uint256 weightOut,
                resPoolData.reserveVaultReservePoolWeight,
                // uint256 amountIn
                amountInWithReducedFeeApplied
            );
            // Check that minimum amount out has been met.
            if (amountOut < args.minAmountOut) {
                revert MinAmountNotMet(args.minAmountOut, amountOut);
            }
            // Calculate expected BPT in for single-asset out removal.
            resPoolData.expectedBpt = BalancerV38020WeightedPoolMath._calcBptInGivenProportionalOut(
                // uint256[] memory balances,
                currentRatedBalances,
                // uint256 totalSupply,
                resPoolData.resPoolTotalSupply,
                // uint256 desiredTokenIndex,
                resPoolData.reserveVaultIndexInReservePool,
                // uint256 desiredAmountOut
                amountOut
            );

            // Call interrupter to remove liquidity single-asset out (Strategy)
            uint256[] memory minAmountsOut = new uint256[](2);
            minAmountsOut[resPoolData.reserveVaultIndexInReservePool] = amountOut;
            IERC20(address(resPoolData.reservePool)).transfer(address(resPoolData.balV3Vault), resPoolData.expectedBpt);
            IBalancerV3StandardExchangeRouterProxy seRouter =
                BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter();
            // uint256[] memory withdrawnAmounts =
            seRouter.prepayRemoveLiquidityProportional(
                // address pool,
                address(resPoolData.reservePool),
                // uint256 exactBptAmountIn,
                resPoolData.expectedBpt,
                // uint256[] memory minAmountsOut,
                minAmountsOut,
                // bool wethIsEth,
                // false,
                // bytes memory userData
                ""
            );
            IERC20(address(rbtData.reserveVault)).transfer(address(rbtData.reserveVault), amountOut);
            amountOut = rbtData.reserveVault
                .exchangeIn(
                    // IERC20 tokenIn,
                    IERC20(address(rbtData.reserveVault)),
                    // uint256 amountIn,
                    amountOut,
                    // IERC20 tokenOut,
                    args.tokenOut,
                    // uint256 minAmountOut,
                    args.minAmountOut,
                    // address recipient,
                    args.recipient,
                    // bool pretransferred
                    true,
                    // uint256 deadline
                    args.deadline
                );
            uint256[] memory unUsedAmountOut = new uint256[](2);
            unUsedAmountOut[resPoolData.reserveVaultIndexInReservePool] =
                IERC20(address(rbtData.reserveVault)).balanceOf(address(this));
            unUsedAmountOut[resPoolData.selfIndexInReservePool] = ERC20Repo._balanceOf(address(this));
            currentRatedBalances = resPoolData.balV3Vault.getCurrentLiveBalances(address(resPoolData.reservePool));
            resPoolData.resPoolTotalSupply = resPoolData.balV3Vault.totalSupply(address(resPoolData.reservePool));
            resPoolData.expectedBpt = BalancerV38020WeightedPoolMath._calcBptOutGivenUnbalancedIn(
                // uint256[] memory balances,
                currentRatedBalances,
                // uint256[] memory normalizedWeights,
                resPoolData.weightsArray,
                // uint256[] memory amountsIn,
                unUsedAmountOut,
                // uint256 totalSupply,
                resPoolData.resPoolTotalSupply,
                // uint256 swapFeePercentage
                resPoolData.reservePoolSwapFee
            );
            seRouter.prepayAddLiquidityUnbalanced(
                // address pool,
                address(resPoolData.reservePool),
                // uint256[] memory exactAmountsIn,
                unUsedAmountOut,
                // uint256 minBptAmountOut,
                resPoolData.expectedBpt,
                // bytes memory userData
                ""
            );
            ERC4626Repo._setLastTotalAssets(IERC20(address(resPoolData.reservePool)).balanceOf(address(this)));

            return amountOut;
        }

        /* --------------- DETF Mint for Reserve Vault Deposit -------------- */

        // Check if this is a reserve vault deposit to mint.
        if (address(args.tokenIn) == address(rbtData.reserveVault) && address(args.tokenOut) == address(this)) {
            // Check if price is below or equal to peg.
            if (rbtData.selfDilutedPrice <= ONE_WAD) {
                // If below peg, refuse to expand the supply
                revert PriceBelowPeg(rbtData.selfDilutedPrice, ONE_WAD);
            }
            // Secure token deposit and check for receipt by comparing balance minus previous reserve.
            uint256 originalAmountIn = ERC4626Service._secureReserveDeposit(args.amountIn);
            // Compute effectiveIn with REDUCED fee
            uint256 amountInWithReducedFeeApplied = FixedPoint.mulDown(
                originalAmountIn,
                // FixedPoint.ONE - rbtData.rbtSwapFee
                FixedPoint.ONE
                    - BetterMath._percentageOfWAD(
                        resPoolData.reservePoolSwapFee,
                        VaultFeeOracleQueryAwareRepo._feeOracle().seigniorageIncentivePercentageOfVault(address(this))
                    )
            );
            // After confirming receipt, transfer reserve vault to Balancer V3 Vault.
            args.tokenIn.transfer(address(resPoolData.balV3Vault), originalAmountIn);
            // Calculate how many BPT to expect from the unbalanced liquidity add.
            resPoolData.expectedBpt = BalancerV38020WeightedPoolMath._calcBptOutGivenSingleIn(
                // uint256[] memory balances,
                currentRatedBalances,
                // uint256[] memory normalizedWeights,
                resPoolData.weightsArray,
                // uint256 tokenIndex,
                resPoolData.reserveVaultIndexInReservePool,
                // uint256 amountIn,
                originalAmountIn,
                // uint256 totalSupply,
                resPoolData.resPoolTotalSupply,
                // uint256 swapFeePercentage
                resPoolData.reservePoolSwapFee
            );
            // Create deposit amount array for interrupter call.
            uint256[] memory paymentAmountsIn = new uint256[](2);
            // Single side deposit only need to set one array member.
            paymentAmountsIn[resPoolData.reserveVaultIndexInReservePool] = originalAmountIn;
            // Call interrupter to add liquidity single-asset in (reserve vault).
            BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter()
                .prepayAddLiquidityUnbalanced(
                    // address pool,
                    address(resPoolData.reservePool),
                    // uint256[] memory exactAmountsIn,
                    paymentAmountsIn,
                    // uint256 minBptAmountOut,
                    resPoolData.expectedBpt,
                    // bytes memory userData
                    ""
                );
            ERC4626Repo._setLastTotalAssets(IERC20(address(resPoolData.reservePool)).balanceOf(address(this)));

            // Deduct swap fee from amount in.
            uint256 effectiveInFull =
                FixedPoint.mulDown(originalAmountIn, FixedPoint.ONE - resPoolData.reservePoolSwapFee);

            // Compute amountOut at FULL fee for profit margin calc
            uint256 amountOutFull = WeightedMath.computeOutGivenExactIn(
                resPoolData.reserveVaultRatedBalance,
                resPoolData.reserveVaultReservePoolWeight,
                currentRatedBalances[WeightedPoolReserveVaultRepo._indexInReservePool(address(this))],
                resPoolData.selfReservePoolWeight,
                effectiveInFull
            );

            // Compute mint amount at REDUCED fee.
            amountOut = WeightedMath.computeOutGivenExactIn(
                // uint256 balanceIn,
                resPoolData.reserveVaultRatedBalance,
                // uint256 weightIn,
                resPoolData.reserveVaultReservePoolWeight,
                // uint256 balanceOut,
                resPoolData.selfReservePoolRatedBalance,
                // uint256 weightOut,
                resPoolData.selfReservePoolWeight,
                // uint256 amountIn
                amountInWithReducedFeeApplied
            );
            if (amountOut < args.minAmountOut) {
                revert MinAmountNotMet(args.minAmountOut, amountOut);
            }

            SRBTAmounts memory srbt;

            // Compute profit margin components
            // Gross seigniorage: Extra value from premium (using full-fee equivalent for "pure" capture)
            // Strategy per RBT at full fee
            srbt.effectiveMintPriceFull = FixedPoint.divDown(amountInWithReducedFeeApplied, amountOutFull);
            // Assumes pegPrice scaled to 1e18
            srbt.premiumPerRBT = srbt.effectiveMintPriceFull - ONE_WAD;
            // In Strategy units
            srbt.grossSeigniorage = FixedPoint.mulDown(amountOutFull, srbt.premiumPerRBT);

            // Discount margin: Extra RBT given due to fee reduction, valued at peg
            srbt.discountRBT = amountOut - amountOutFull;
            // In Strategy-equivalent units
            srbt.discountMargin = FixedPoint.mulDown(srbt.discountRBT, ONE_WAD);

            // Total profit margin: What the protocol "captures" overall (gross + recapturable discount)
            srbt.profitMargin = srbt.grossSeigniorage + srbt.discountMargin;

            // Convert profit margin to sRBT amount (peg-equivalent RBT units)
            // Ensures 1:1 redeemability scale
            srbt.sRBTToMint = FixedPoint.divDown(srbt.profitMargin, ONE_WAD);

            // Step 7: Mint RBT to recipient and sRBT to bond holders
            ERC20Repo._mint(args.recipient, amountOut);
            if (srbt.sRBTToMint > 0) {
                // Distribute proportionally to NFT bond shares
                ISeigniorageNFTVault nftVault = SeigniorageVaultRepo._seigniorageNFTVault();
                sRbtData.seigniorageToken.mint(address(nftVault), srbt.sRBTToMint);
                // nftVault.syncReserves();
            }

            // Return to short-circuit remaining logic.
            return amountOut;
        }

        /* ---------- DETF Mint for Reserve Vault Contents Deposit ---------- */

        // Check if this is a reserve vault deposit to mint.
        if (
            // address(tokenIn) == address(rbtData.reserveVault)
            WeightedPoolReserveVaultRepo._isReserveAssetContents(address(args.tokenIn))
                && address(args.tokenOut) == address(this)
        ) {
            // Check if price is below or equal to peg.
            if (rbtData.selfDilutedPrice <= ONE_WAD) {
                // If below peg, refuse to expand the supply
                revert PriceBelowPeg(rbtData.selfDilutedPrice, ONE_WAD);
            }
            // Secure token deposit and check for receipt by comparing balance minus previous reserve.
            uint256 originalAmountIn;

            if (args.pretransferred) {
                args.tokenIn.transfer(address(rbtData.reserveVault), args.amountIn);
                originalAmountIn = rbtData.reserveVault
                    .exchangeIn(
                        // IERC20 tokenIn,
                        IERC20(address(args.tokenIn)),
                        // uint256 amountIn,
                        args.amountIn,
                        // IERC20 tokenOut,
                        IERC20(address(rbtData.reserveVault)),
                        // uint256 minAmountOut,
                        0,
                        // address recipient,
                        address(resPoolData.balV3Vault),
                        // bool pretransferred
                        true,
                        // uint256 deadline
                        args.deadline
                    );
            } else {
                args.tokenIn.safeTransferFrom(address(msg.sender), address(rbtData.reserveVault), args.amountIn);
                originalAmountIn = rbtData.reserveVault
                    .exchangeIn(
                        // IERC20 tokenIn,
                        IERC20(address(args.tokenIn)),
                        // uint256 amountIn,
                        args.amountIn,
                        // IERC20 tokenOut,
                        IERC20(address(rbtData.reserveVault)),
                        // uint256 minAmountOut,
                        0,
                        // address recipient,
                        address(resPoolData.balV3Vault),
                        // bool pretransferred
                        true,
                        // uint256 deadline
                        args.deadline
                    );
            }
            // Compute effectiveIn with REDUCED fee
            uint256 amountInWithReducedFeeApplied = FixedPoint.mulDown(
                originalAmountIn,
                // FixedPoint.ONE - rbtData.rbtSwapFee
                FixedPoint.ONE
                    - BetterMath._percentageOfWAD(
                        resPoolData.reservePoolSwapFee,
                        VaultFeeOracleQueryAwareRepo._feeOracle().seigniorageIncentivePercentageOfVault(address(this))
                    )
            );
            // After confirming receipt, transfer reserve vault to Balancer V3 Vault.
            args.tokenIn.transfer(address(resPoolData.balV3Vault), originalAmountIn);
            // Calculate how many BPT to expect from the unbalanced liquidity add.
            resPoolData.expectedBpt = BalancerV38020WeightedPoolMath._calcBptOutGivenSingleIn(
                // uint256[] memory balances,
                currentRatedBalances,
                // uint256[] memory normalizedWeights,
                resPoolData.weightsArray,
                // uint256 tokenIndex,
                resPoolData.reserveVaultIndexInReservePool,
                // uint256 amountIn,
                originalAmountIn,
                // uint256 totalSupply,
                resPoolData.resPoolTotalSupply,
                // uint256 swapFeePercentage
                resPoolData.reservePoolSwapFee
            );
            // Create deposit amount array for interrupter call.
            uint256[] memory paymentAmountsIn = new uint256[](2);
            // Single side deposit only need to set one array member.
            paymentAmountsIn[resPoolData.reserveVaultIndexInReservePool] = originalAmountIn;
            // Call interrupter to add liquidity single-asset in (reserve vault).
            BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter()
                .prepayAddLiquidityUnbalanced(
                    // address pool,
                    address(resPoolData.reservePool),
                    // uint256[] memory exactAmountsIn,
                    paymentAmountsIn,
                    // uint256 minBptAmountOut,
                    resPoolData.expectedBpt,
                    // bytes memory userData
                    ""
                );
            ERC4626Repo._setLastTotalAssets(IERC20(address(resPoolData.reservePool)).balanceOf(address(this)));

            // Deduct swap fee from amount in.
            uint256 effectiveInFull =
                FixedPoint.mulDown(originalAmountIn, FixedPoint.ONE - resPoolData.reservePoolSwapFee);

            // Compute amountOut at FULL fee for profit margin calc
            uint256 amountOutFull = WeightedMath.computeOutGivenExactIn(
                resPoolData.reserveVaultRatedBalance,
                resPoolData.reserveVaultReservePoolWeight,
                currentRatedBalances[WeightedPoolReserveVaultRepo._indexInReservePool(address(this))],
                resPoolData.selfReservePoolWeight,
                effectiveInFull
            );

            // Compute mint amount at REDUCED fee.
            amountOut = WeightedMath.computeOutGivenExactIn(
                // uint256 balanceIn,
                resPoolData.reserveVaultRatedBalance,
                // uint256 weightIn,
                resPoolData.reserveVaultReservePoolWeight,
                // uint256 balanceOut,
                resPoolData.selfReservePoolRatedBalance,
                // uint256 weightOut,
                resPoolData.selfReservePoolWeight,
                // uint256 amountIn
                amountInWithReducedFeeApplied
            );
            if (amountOut < args.minAmountOut) {
                revert MinAmountNotMet(args.minAmountOut, amountOut);
            }

            SRBTAmounts memory srbt;

            // Compute profit margin components
            // Gross seigniorage: Extra value from premium (using full-fee equivalent for "pure" capture)
            // Strategy per RBT at full fee
            srbt.effectiveMintPriceFull = FixedPoint.divDown(amountInWithReducedFeeApplied, amountOutFull);
            // Assumes pegPrice scaled to 1e18
            srbt.premiumPerRBT = srbt.effectiveMintPriceFull - ONE_WAD;
            // In Strategy units
            srbt.grossSeigniorage = FixedPoint.mulDown(amountOutFull, srbt.premiumPerRBT);

            // Discount margin: Extra RBT given due to fee reduction, valued at peg
            srbt.discountRBT = amountOut - amountOutFull;
            // In Strategy-equivalent units
            srbt.discountMargin = FixedPoint.mulDown(srbt.discountRBT, ONE_WAD);

            // Total profit margin: What the protocol "captures" overall (gross + recapturable discount)
            srbt.profitMargin = srbt.grossSeigniorage + srbt.discountMargin;

            // Convert profit margin to sRBT amount (peg-equivalent RBT units)
            // Ensures 1:1 redeemability scale
            srbt.sRBTToMint = FixedPoint.divDown(srbt.profitMargin, ONE_WAD);

            // Step 7: Mint RBT to recipient and sRBT to bond holders
            ERC20Repo._mint(args.recipient, amountOut);
            if (srbt.sRBTToMint > 0) {
                // Distribute proportionally to NFT bond shares
                ISeigniorageNFTVault nftVault = SeigniorageVaultRepo._seigniorageNFTVault();
                sRbtData.seigniorageToken.mint(address(nftVault), srbt.sRBTToMint);
                // nftVault.syncReserves();
            }

            // Return to short-circuit remaining logic.
            return amountOut;
        }
    }
}
