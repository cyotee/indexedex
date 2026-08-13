// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ICLFactory} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLFactory.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    ISlipstreamStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeDFPkg.sol";
import {
    Slipstream_Component_FactoryService
} from "contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol";
import {
    SlipstreamHermeticClBook
} from "contracts/protocols/dexes/aerodrome/slipstream/test/SlipstreamHermeticClBook.sol";

/// @dev Address-only factory so PkgInit / pool.factory() match without Aero voter wiring.
contract SlipstreamFactoryStub {}

/**
 * @title TestBase_SlipstreamStandardExchange
 * @notice Gold TestBase: CREATE3 facets + manager-registry DFPkg + hermetic CL book.
 */
contract TestBase_SlipstreamStandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using Slipstream_Component_FactoryService for ICreate3FactoryProxy;
    using Slipstream_Component_FactoryService for IIndexedexManagerProxy;

    uint24 internal constant DEFAULT_WIDTH_MULTIPLIER = 10;
    uint24 internal constant FEE_LOW = 500;

    IFacet slipstreamStandardExchangeInFacet;
    IFacet slipstreamStandardExchangeOutFacet;
    ISlipstreamStandardExchangeDFPkg internal slipstreamStandardExchangeDFPkg;

    ERC20PermitMintableStub internal pairToken0;
    ERC20PermitMintableStub internal pairToken1;
    ICLFactory internal slipstreamFactory;
    SlipstreamHermeticClBook internal clBook;
    IStandardExchangeProxy internal vault;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();
        slipstreamStandardExchangeInFacet = create3Factory.deploySlipstreamStandardExchangeInFacet();
        slipstreamStandardExchangeOutFacet = create3Factory.deploySlipstreamStandardExchangeOutFacet();

        pairToken0 = new ERC20PermitMintableStub("Pair0", "P0", 18, address(this), 0);
        pairToken1 = new ERC20PermitMintableStub("Pair1", "P1", 18, address(this), 0);
        if (address(pairToken0) > address(pairToken1)) {
            (pairToken0, pairToken1) = (pairToken1, pairToken0);
        }

        slipstreamFactory = ICLFactory(address(new SlipstreamFactoryStub()));
        clBook = new SlipstreamHermeticClBook(
            address(pairToken0), address(pairToken1), FEE_LOW, int24(1), address(slipstreamFactory)
        );
        clBook.initialize(uint160(uint256(1) << 96));
        clBook.addLiquidity(-10_000, 10_000, 1e24);
        pairToken0.mint(address(clBook), 1e27);
        pairToken1.mint(address(clBook), 1e27);

        ISlipstreamStandardExchangeDFPkg.PkgInit memory pkgInit = ISlipstreamStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            slipstreamStandardExchangeInFacet: slipstreamStandardExchangeInFacet,
            slipstreamStandardExchangeOutFacet: slipstreamStandardExchangeOutFacet,
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            permit2: permit2,
            slipstreamFactory: slipstreamFactory
        });

        vm.startPrank(owner);
        slipstreamStandardExchangeDFPkg = indexedexManager.deploySlipstreamStandardExchangeDFPkg(pkgInit);
        vm.stopPrank();

        vault = IStandardExchangeProxy(
            slipstreamStandardExchangeDFPkg.deployVault(ICLPool(address(clBook)), DEFAULT_WIDTH_MULTIPLIER)
        );
        vm.label(address(vault), "SlipstreamSE");
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }
}
