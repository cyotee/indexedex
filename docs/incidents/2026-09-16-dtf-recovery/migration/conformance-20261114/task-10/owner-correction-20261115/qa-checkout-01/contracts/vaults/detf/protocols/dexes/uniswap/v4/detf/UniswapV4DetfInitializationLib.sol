// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {DETFThresholdPolicy} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFEpochNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo as Repo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfProcessArgsLib as ArgsLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProcessArgsLib.sol";

/// @title UniswapV4DetfInitializationLib
/// @notice Compatible parent initialization with package-selected declarations and children.
library UniswapV4DetfInitializationLib {
    using BetterEfficientHashLib for bytes;

    function _initialize(
        IUniswapV4Detf.PkgArgs memory args,
        IVaultFeeOracleQuery feeOracle_,
        bytes32 vaultFeeTypeIds_,
        bytes4[] memory vaultTypes_,
        address bondNftVaultPkg_,
        address rebasingClaimTokenPkg_
    ) internal {
        ArgsLib.requireHookShape(args.hook);
        ArgsLib.requireLiquidityPolicy(args.hook, args.ownerOnlyLiquidity);
        ArgsLib.requireDetfSelfLegAndOwner(args.hook, address(this));

        address[] memory hookTokens_ = IUniswapV4SeBufferHook(args.hook).tokens();
        uint256 pairCount_ = hookTokens_.length - 1;
        ArgsLib.requireCreationRates(args, pairCount_);
        uint256[] memory opening_ = ArgsLib.resolveOpening(args.creationPairPerDetfWad, args.openingPairPerDetfWad);

        ERC20Repo._initialize(args.name, args.symbol, 9);
        EIP712Repo._initialize(args.name, "1");

        address[] memory contents_ = new address[](hookTokens_.length + 1);
        for (uint256 i; i < hookTokens_.length; ++i) {
            contents_[i] = hookTokens_[i];
        }
        contents_[hookTokens_.length] = args.hook;
        StandardVaultRepo._initialize(
            feeOracle_, vaultFeeTypeIds_, vaultTypes_, abi.encode(contents_)._hash()
        );

        (uint256 mint_, uint256 burn_) =
            DETFThresholdPolicy.resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold);
        uint256 rate_ = DETFEpochNaturalExpansionLib.resolveClosureRate(args.expansionClosureRatePerYearWad);

        Repo._initializeCore(
            Repo.CoreInit({
                hook: args.hook,
                feeOracle: feeOracle_,
                creationPairPerDetfWad: args.creationPairPerDetfWad,
                openingPairPerDetfWad: opening_,
                bondNftVaultPkg: bondNftVaultPkg_,
                rebasingClaimTokenPkg: rebasingClaimTokenPkg_,
                creator: args.creator
            })
        );
        Repo._initializePolicy(
            Repo.PolicyInit({
                mintThreshold: mint_,
                burnThreshold: burn_,
                expansionClosureRatePerYearWad: rate_
            })
        );
        Repo._setChildTokenMetadata(args.claimName, args.claimSymbol, args.bondName, args.bondSymbol);
        Repo._setRouteModes(
            args.mintRouteMode,
            args.burnRouteMode,
            args.bondRouteMode,
            args.donateRouteMode
        );
        ArgsLib.storeHookSetsAndRates(args.hook, address(this), args.creationPairPerDetfWad, opening_);
        _storeTables(args);
        MultiAssetBasicVaultRepo._initialize(contents_);
        emit IUniswapV4Detf.ThresholdsConfigured(mint_, burn_);
    }

    function _storeTables(IUniswapV4Detf.PkgArgs memory args) private {
        Repo.Storage storage s = Repo._layoutStruct();
        if (args.mintRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(address(this), args.mintRoutes, s.mintTable);
        } else {
            ArgsLib.storeDefaultInbound(args.hook, address(this), s.mintTable);
        }
        if (args.burnRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(address(this), args.burnRoutes, s.burnTable);
        } else {
            ArgsLib.storeDefaultInbound(args.hook, address(this), s.burnTable);
        }
        if (args.bondRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(address(this), args.bondRoutes, s.bondTable);
        } else {
            ArgsLib.storeDefaultInbound(args.hook, address(this), s.bondTable);
        }
        if (args.donateRouteMode == IUniswapV4Detf.RouteTableMode.Custom) {
            ArgsLib.storeCustomTable(address(this), args.donateRoutes, s.donateTable);
            ArgsLib.requireDonateSubset();
        } else {
            ArgsLib.storeDonateUnion();
        }
    }
}
