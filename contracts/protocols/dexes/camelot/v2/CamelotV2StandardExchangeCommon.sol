// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ICamelotV2Router} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotV2Router.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {CamelotV2FactoryAwareRepo} from "@crane/contracts/protocols/dexes/camelot/v2/CamelotV2FactoryAwareRepo.sol";
import {ConstProdReserveVaultRepo} from "contracts/vaults/ConstProdReserveVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {BasicVaultCommon} from "contracts/vaults/basic/BasicVaultCommon.sol";
import {CamelotV2Service} from "@crane/contracts/protocols/dexes/camelot/v2/services/CamelotV2Service.sol";

// abstract
contract CamelotV2StandardExchangeCommon is BasicVaultCommon {
    struct CamelotV2IndexSourceReserves {
        ICamelotPair pool;
        address token0;
        address token1;
        uint256 knownReserve;
        uint256 opposingReserve;
        uint256 knownfeePercent;
        uint256 opTokenFeePercent;
        uint256 totalSupply;
        uint256 kLast;
    }

    struct CamelotV2StrategyVault {
        uint256 vaultLpReserve;
        uint256 vaultTotalShares;
        uint256 knownTokenLastOwnedSourceReserve;
        uint256 opTokenLastOwnedSourceReserve;
        uint256 feeShares;
    }

    function _loadIndexSourceReserves(CamelotV2IndexSourceReserves memory indexSource, IERC20 knownToken)
        internal
        view
    {
        // indexSource.pool = ICamelotPair(address(ERC4626Repo._reserveAsset()));
        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        indexSource.token0 = ConstProdReserveVaultRepo._token0(constProd);
        indexSource.token1 = ConstProdReserveVaultRepo._token1(constProd);
        indexSource.totalSupply = indexSource.pool.totalSupply();
        indexSource.kLast = indexSource.pool.kLast();
        // (uint112 reserve0, uint112 reserve1, uint16 token0feePercent, uint16 token1FeePercent) = indexSource.pool.getReserves();
        (
            indexSource.knownReserve,
            indexSource.opposingReserve,
            indexSource.knownfeePercent,
            indexSource.opTokenFeePercent
        ) = CamelotV2Service._sortReserves(indexSource.pool, knownToken);
    }

    function _loadStrategyVault(CamelotV2StrategyVault memory vault, IERC20 knownToken) internal view {
        vault.vaultLpReserve = ERC4626Repo._lastTotalAssets();
        vault.vaultTotalShares = ERC20Repo._totalSupply();
        ConstProdReserveVaultRepo.Storage storage constProd = ConstProdReserveVaultRepo._layout();
        vault.knownTokenLastOwnedSourceReserve =
            ConstProdReserveVaultRepo._yieldReserveOfToken(constProd, address(knownToken));
        vault.opTokenLastOwnedSourceReserve = ConstProdReserveVaultRepo._yieldReserveOfToken(
            constProd, ConstProdReserveVaultRepo._opposingToken(constProd, address(knownToken))
        );
    }

    function _calcVaultFee(CamelotV2IndexSourceReserves memory indexSource, CamelotV2StrategyVault memory vault)
        internal
        view
    {
        (uint256 knownTokenFeeYield, uint256 opTokenFeeYield) = ConstProdUtils._calculateFeePortionForPosition(
            // uint256 ownedLP,
            vault.vaultLpReserve,
            // uint256 initialA,
            vault.knownTokenLastOwnedSourceReserve,
            // uint256 initialB,
            vault.opTokenLastOwnedSourceReserve,
            // uint256 reserveA,
            indexSource.knownReserve,
            // uint256 reserveB,
            indexSource.opposingReserve,
            // uint256 totalSupply
            indexSource.totalSupply
        );
        uint256 feeShareLPEquiv = ConstProdUtils._quoteDepositWithFee(
            // uint256 amountADeposit,
            knownTokenFeeYield,
            // uint256 amountBDeposit,
            opTokenFeeYield,
            // uint256 lpTotalSupply,
            indexSource.totalSupply,
            // uint256 lpReserveA,
            vault.knownTokenLastOwnedSourceReserve,
            // uint256 lpReserveB,
            vault.opTokenLastOwnedSourceReserve,
            // uint256 kLast,
            indexSource.kLast,
            // uint256 ownerFeeShare,
            CamelotV2FactoryAwareRepo._camelotV2Factory().ownerFeeShare(),
            // bool feeOn
            CamelotV2FactoryAwareRepo._camelotV2Factory().feeTo() != address(0)
        );
        feeShareLPEquiv = BetterMath._percentageOfWAD(
            // uint256 total,
            feeShareLPEquiv,
            // uint256 percentage,
            VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this))
        );

        vault.feeShares = BetterMath._convertToSharesDown(
            feeShareLPEquiv, vault.vaultLpReserve, vault.vaultTotalShares, ERC4626Repo._decimalOffset()
        );
        vault.vaultTotalShares += vault.feeShares;
    }

    function _calcAndMintVaultFee(CamelotV2IndexSourceReserves memory indexSource, CamelotV2StrategyVault memory vault)
        internal
    {
        _calcVaultFee(
            // UnIV2IndexSourceReserves memory indexSource,
            indexSource,
            // UniV2IndexSupply memory indexSupply,
            // indexSupply,
            // UniV2StrategyVault memory vault
            vault
        );
        ERC20Repo._mint(
            // address account,
            address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo()),
            // uint256 amount,
            vault.feeShares
        );
    }
}
