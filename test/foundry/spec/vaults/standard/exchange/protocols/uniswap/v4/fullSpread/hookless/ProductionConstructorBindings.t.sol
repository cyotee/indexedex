// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Acceptance.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg as Package} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService as Factory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault_Component_FactoryService.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
import {Bytecode} from "@crane/contracts/utils/Bytecode.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

contract UniswapV4FullSpreadHooklessStandardExchangeVaultProductionConstructorBindingsTest is Acceptance {
    function test_chain4663WrongManagerConstructorFailsBeforeRegistration() public {
        Package.PkgInit memory init = Factory.buildArgsUniswapV4FullSpreadHooklessStandardExchangeVaultPkgInit(_univ4SePkgInitCore());
        init = Factory.attachTwapOracle(init, twapOracle);
        init = Factory.attachUniswapV4FullSpreadHooklessStandardExchangeVaultMultiFacets(init,
            uniswapV4StandardExchangeInMultiFacet, uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet, uniswapV4StandardExchangeOutMultiQueryFacet);
        bytes memory code = ArtifactCreationCode.creationCode(create3Factory,
            "UniswapV4FullSpreadHooklessStandardExchangeVaultProductionBindingProbe.sol:UniswapV4FullSpreadHooklessStandardExchangeVaultProductionBindingProbe");
        bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadHooklessStandardExchangeVaultProductionBindingProbe"));
        uint256 count = indexedexManager.vaultPackages().length;
        uint256 originalChain = block.chainid;
        assertGt(address(poolManager).code.length, 0);
        assertTrue(address(poolManager) != ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER);
        vm.chainId(ROBINHOOD_MAIN.CHAIN_ID);
        vm.prank(owner);
        // CREATE3 masks constructor revert data; this is not an occupied-salt bindingHash failure.
        vm.expectRevert(Bytecode.ErrorCreatingContract.selector);
        indexedexManager.deployPkg(code, abi.encode(init), salt);
        assertEq(indexedexManager.vaultPackages().length, count);
        vm.chainId(originalChain);
        vm.prank(owner);
        address deployed = indexedexManager.deployPkg(code, abi.encode(init), salt);
        assertGt(deployed.code.length, 0);
        assertTrue(indexedexManager.isPackage(deployed));
        assertEq(indexedexManager.vaultPackages().length, count + 1);
        assertEq(Package(deployed).bindingHash(), keccak256(abi.encode(init)));
    }
}
