// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {TestBase_UniswapV4FullSpreadG4DeploymentClosure as Closure} from "contracts/test/bases/TestBase_UniswapV4FullSpreadG4DeploymentClosure.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Bytecode} from "@crane/contracts/utils/Bytecode.sol";
import {IUniswapV4MultiPoolTwapOracleDFPkg} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {IUniswapV4MultiPoolTwapOracle} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg as Package} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService as Factory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.sol";

// tag::UniswapV4FullSpreadHooklessStandardExchangeVaultImportDeploymentClosureTest[]
/// @notice G4 source-only closure additions; parent owns compilation and execution.
contract UniswapV4FullSpreadHooklessStandardExchangeVaultImportDeploymentClosureTest is Acceptance, Closure {
    IPositionManager private g4Positions;

    /// @notice Reuse the fully initialized family acceptance fixture and its real protocol stack.
    function setUp() public override(Acceptance) {
        Acceptance.setUp();
        g4 = G4ImportFixture(vault, poolManager, g4Positions, permit2, poolKey, token0, token1);
        g4Registry = indexedexManager;
        g4Package = IDiamondFactoryPackage(address(uniswapV4StandardExchangeDFPkg));
        g4Oracle = twapOracle;
        g4Factory = address(create3Factory);
        g4Weth = address(weth);
        g4ExpectedFacets = new address[](15);
        g4ExpectedFacets[0] = address(erc20Facet);
        g4ExpectedFacets[1] = address(erc5267Facet);
        g4ExpectedFacets[2] = address(erc2612Facet);
        g4ExpectedFacets[3] = address(multiAssetBasicVaultFacet);
        g4ExpectedFacets[4] = address(multiAssetStandardVaultFacet);
        g4ExpectedFacets[5] = address(uniswapV4StandardExchangeInFacet);
        g4ExpectedFacets[6] = address(uniswapV4StandardExchangeInQueryFacet);
        g4ExpectedFacets[7] = address(uniswapV4StandardExchangePositionImportFacet);
        g4ExpectedFacets[8] = address(uniswapV4StandardExchangeOutFacet);
        g4ExpectedFacets[9] = address(uniswapV4StandardExchangeOutQueryFacet);
        g4ExpectedFacets[10] = address(uniswapV4StandardExchangeLiquidReserveFacet);
        g4ExpectedFacets[11] = address(uniswapV4StandardExchangeInMultiFacet);
        g4ExpectedFacets[12] = address(uniswapV4StandardExchangeInMultiQueryFacet);
        g4ExpectedFacets[13] = address(uniswapV4StandardExchangeOutMultiFacet);
        g4ExpectedFacets[14] = address(uniswapV4StandardExchangeOutMultiQueryFacet);
    }

    function _positionManagerForTests() internal override returns (IPositionManager) {
        g4Positions = IPositionManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PositionManager.sol:PositionManager"),
            abi.encode(poolManager, permit2, uint256(100_000), address(0), weth),
            keccak256(abi.encode("G4.H.PositionManager"))));
        return g4Positions;
    }

    function _g4Init() internal view returns (Package.PkgInit memory init) {
        init = Factory.buildArgsUniswapV4FullSpreadHooklessStandardExchangeVaultPkgInit(_univ4SePkgInitCore());
        init = Factory.attachTwapOracle(init, twapOracle);
        init = Factory.attachUniswapV4FullSpreadHooklessStandardExchangeVaultMultiFacets(init,
            uniswapV4StandardExchangeInMultiFacet, uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet, uniswapV4StandardExchangeOutMultiQueryFacet);
    }

    function _g4UnboundVault() internal override returns (IStandardExchangeProxy) {
        Package.PkgInit memory init = _g4Init();
        assertEq(address(init.positionManager), address(0));
        bytes memory code = ArtifactCreationCode.creationCode(create3Factory,
            "UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg");
        vm.prank(owner);
        Package unbound = Package(indexedexManager.deployPkg(code, abi.encode(init), keccak256(abi.encode("G4.H.Unbound"))));
        return IStandardExchangeProxy(unbound.deployVault(poolKey));
    }

    function _g4Trade() internal override { _externalSwap(true, 100e18); }
    function _g4Prefix() internal pure override returns (string memory) { return "UniswapV4FullSpreadHooklessStandardExchangeVault"; }
    function _g4SecondVault() internal override returns (IStandardExchangeProxy) {
        return IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(poolKey));
    }

    function _g4OraclePackage(IUniswapV4MultiPoolTwapOracle oracle_) internal override returns (address) {
        Package.PkgInit memory init = _g4Init();
        init.twapOracle = oracle_;
        bytes memory code = ArtifactCreationCode.creationCode(create3Factory,
            "UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg");
        vm.prank(owner);
        return indexedexManager.deployPkg(code, abi.encode(init), keccak256(abi.encode("G4.H.OracleCounterparty")));
    }

    function _g4VaultFromPackage(address package_) internal override returns (IStandardExchangeProxy) {
        return IStandardExchangeProxy(Package(package_).deployVault(poolKey));
    }

    function _g4NativeVault(PoolKey memory key_) internal override returns (IStandardExchangeProxy) {
        poolManager.initialize(key_, uint160(1) << 96);
        return IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(key_));
    }

    function _g4DeployBadOracle(bool zero_) internal override {
        Package.PkgInit memory init = _g4Init();
        if (zero_) init.twapOracle = IUniswapV4MultiPoolTwapOracle(address(0));
        else {
            address otherManager = create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
                abi.encode(address(this)), keccak256(abi.encode("G4.H.ForeignManager")));
            init.twapOracle = twapOraclePkg.deployOracle(IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs(otherManager));
            assertTrue(init.twapOracle.poolManager() != address(poolManager));
        }
        bytes memory code = ArtifactCreationCode.creationCode(create3Factory,
            "UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg");
        vm.prank(owner);
        vm.expectRevert(Bytecode.ErrorCreatingContract.selector);
        indexedexManager.deployPkg(code, abi.encode(init), keccak256(abi.encode("G4.H.InvalidOracle", zero_)));
    }
}
// end::UniswapV4FullSpreadHooklessStandardExchangeVaultImportDeploymentClosureTest[]
