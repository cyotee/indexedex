// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IMorpho, Id, MarketParams, Market} from
    "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    MorphoBlue_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol";

/**
 * @title TestBase_MorphoBlueStandardExchangeFork
 * @notice Binds live Morpho (no hermetic `new Morpho`). Fork first, then IndexedEx registry deploy.
 */
abstract contract TestBase_MorphoBlueStandardExchangeFork is TestBase_Permit2, TestBase_VaultComponents {
    using MorphoBlue_Component_FactoryService for ICreate3FactoryProxy;
    using MorphoBlue_Component_FactoryService for IIndexedexManagerProxy;
    using MorphoBalancesLib for IMorpho;

    IMorpho internal liveMorpho;
    MarketParams internal liveParams;
    Id internal liveId;

    IFacet morphoBlueErc4626Facet;
    IFacet exchangeInFacet;
    IFacet exchangeOutFacet;
    IFacet markerFacet;
    IMorphoBlueStandardExchangeDFPkg morphoBlueStandardExchangeDFPkg;

    address internal se;
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;
    IMorphoBlueStandardExchange internal mbse;
    IERC4626 internal se4626;
    address internal user;

    function _rpcAlias() internal pure virtual returns (string memory);
    function _forkBlock() internal pure virtual returns (uint256);
    function _liveMorphoAddress() internal pure virtual returns (address);
    function _candidateIds() internal pure virtual returns (bytes32[] memory);

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        string memory rpc_ = vm.rpcUrl(_rpcAlias());
        uint256 pin_ = _forkBlock();
        if (pin_ == 0) {
            vm.createSelectFork(rpc_);
        } else {
            vm.createSelectFork(rpc_, pin_);
        }
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);

        liveMorpho = IMorpho(_liveMorphoAddress());
        _bindLiveMarket();

        morphoBlueErc4626Facet = create3Factory.deployMorphoBlueERC4626Facet();
        exchangeInFacet = create3Factory.deployMorphoBlueStandardExchangeInFacet();
        exchangeOutFacet = create3Factory.deployMorphoBlueStandardExchangeOutFacet();
        markerFacet = create3Factory.deployMorphoBlueStandardExchangeMarkerFacet();

        vm.prank(owner);
        morphoBlueStandardExchangeDFPkg =
            indexedexManager.deployMorphoBlueStandardExchangeDFPkg(_buildPkgInit());

        user = makeAddr("forkUser");
        if (liveParams.loanToken != address(0) && liveParams.loanToken.code.length > 0) {
            se = _deployVault(liveMorpho, liveParams);
            seIn = IStandardExchangeIn(se);
            seOut = IStandardExchangeOut(se);
            mbse = IMorphoBlueStandardExchange(se);
            se4626 = IERC4626(se);
        }
    }

    function _bindLiveMarket() internal {
        bytes32[] memory candidates = _candidateIds();
        for (uint256 i; i < candidates.length; ++i) {
            Id id_ = Id.wrap(candidates[i]);
            MarketParams memory p = liveMorpho.idToMarketParams(id_);
            if (p.loanToken == address(0)) continue;
            Market memory m = liveMorpho.market(id_);
            if (m.lastUpdate == 0) continue;
            uint256 totalS = liveMorpho.expectedTotalSupplyAssets(p);
            uint256 totalB = liveMorpho.expectedTotalBorrowAssets(p);
            if (totalS <= totalB) continue;
            liveId = id_;
            liveParams = p;
            return;
        }
    }

    function _buildPkgInit()
        internal
        view
        returns (IMorphoBlueStandardExchangeDFPkg.PkgInit memory)
    {
        return IMorphoBlueStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            morphoBlueErc4626Facet: morphoBlueErc4626Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: exchangeInFacet,
            exchangeOutFacet: exchangeOutFacet,
            markerFacet: markerFacet,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2
        });
    }

    function _deployVault(IMorpho morpho_, MarketParams memory params_)
        internal
        returns (address vault)
    {
        vm.prank(owner);
        vault = morphoBlueStandardExchangeDFPkg.deployVault(
            IMorphoBlueStandardExchangeDFPkg.PkgArgs({morpho: morpho_, marketParams: params_})
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _freeCash() internal view returns (uint256) {
        uint256 totalS = liveMorpho.expectedTotalSupplyAssets(liveParams);
        uint256 totalB = liveMorpho.expectedTotalBorrowAssets(liveParams);
        return totalS > totalB ? totalS - totalB : 0;
    }
}
