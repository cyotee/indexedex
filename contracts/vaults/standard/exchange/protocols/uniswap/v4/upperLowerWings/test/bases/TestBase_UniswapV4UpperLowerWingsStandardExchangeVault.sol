// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {DeployPermit2} from "@crane/contracts/protocols/utils/permit2/test/utils/DeployPermit2.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg} from "../../interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "../../interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultComponent_FactoryService as Components} from "../../UniswapV4UpperLowerWingsStandardExchangeVaultComponent_FactoryService.sol";

// tag::TestBase_UniswapV4UpperLowerWingsStandardExchangeVault[]
/// @notice Real registry/manager/fee-oracle/PoolManager fixture, shared by all family lifecycle tests.
abstract contract TestBase_UniswapV4UpperLowerWingsStandardExchangeVault is IndexedexTest, DeployPermit2 {
    IPoolManager internal pool;
    PoolKey internal key;
    ERC20PermitMintableStub internal token0;
    ERC20PermitMintableStub internal token1;
    IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg internal wingsPackage;
    IUniswapV4UpperLowerWingsStandardExchangeVault internal wings0;
    IUniswapV4UpperLowerWingsStandardExchangeVault internal wings1;
    IFacet internal queryFacet;

    function setUp() public virtual override {
        super.setUp();
        pool = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)), keccak256("Wings.PoolManager")
        ));
        token0 = new ERC20PermitMintableStub("Wings token A", "A", 6, address(this), 0);
        token1 = new ERC20PermitMintableStub("Wings token B", "B", 18, address(this), 0);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(0)));
        pool.initialize(key, uint160(1) << 96);
        IFacet[] memory facets = _facets();
        IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgInit memory init = IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgInit(
            facets, pool, indexedexManager, indexedexManager, IPermit2(deployPermit2())
        );
        bytes memory creationCode = ArtifactCreationCode.creationCode(
            create3Factory, "UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol:UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg"
        );
        vm.prank(owner);
        wingsPackage = IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg(indexedexManager.deployPkg(creationCode, abi.encode(init), keccak256("Wings.Package")));
        wings0 = IUniswapV4UpperLowerWingsStandardExchangeVault(wingsPackage.deployVault(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(key, address(token0))));
        wings1 = IUniswapV4UpperLowerWingsStandardExchangeVault(wingsPackage.deployVault(IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.PkgArgs(key, address(token1))));
    }
    function _facets() internal virtual returns (IFacet[] memory facets_) {
        facets_ = new IFacet[](13);
        facets_[0] = IFacet(create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(
            create3Factory, "ERC20Facet.sol:ERC20Facet"), "", keccak256("Wings.ERC20")));
        facets_[1] = IFacet(create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(
            create3Factory, "ERC5267Facet.sol:ERC5267Facet"), "", keccak256("Wings.ERC5267")));
        facets_[2] = IFacet(create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(
            create3Factory, "ERC2612Facet.sol:ERC2612Facet"), "", keccak256("Wings.ERC2612")));
        facets_[3] = IFacet(create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(
            create3Factory, "MultiAssetBasicVaultFacet.sol:MultiAssetBasicVaultFacet"), "", keccak256("Wings.Basic")));
        facets_[4] = IFacet(create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(
            create3Factory, "MultiAssetStandardVaultFacet.sol:MultiAssetStandardVaultFacet"), "", keccak256("Wings.Standard")));
        queryFacet = Components.deployQueryFacet(create3Factory);
        facets_[5] = queryFacet;
        facets_[6] = Components.deployExecutionDelegate(create3Factory);
        facets_[7] = Components.deployInFacet(create3Factory);
        facets_[8] = Components.deployOutFacet(create3Factory);
        facets_[9] = Components.deploySYFacet(create3Factory);
        facets_[10] = Components.deployRebalanceFacet(create3Factory);
        facets_[11] = Components.deployTransitionFacet(create3Factory);
        facets_[12] = Components.deployEconomicFacet(create3Factory);
    }
}
// end::TestBase_UniswapV4UpperLowerWingsStandardExchangeVault[]
