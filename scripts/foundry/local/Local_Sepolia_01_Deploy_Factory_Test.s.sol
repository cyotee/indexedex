// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import { VmSafe } from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import { IWETH } from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import "contracts/crane/constants/CraneINITCODE.sol";
import { betterconsole as console } from "contracts/crane/utils/vm/foundry/tools/betterconsole.sol";
import {
    WALLET_0_KEY,
    WALLET_1_KEY,
    WALLET_2_KEY,
    WALLET_3_KEY,
    WALLET_4_KEY,
    WALLET_5_KEY,
    WALLET_6_KEY,
    WALLET_7_KEY,
    WALLET_8_KEY,
    WALLET_9_KEY
} from "contracts/crane/constants/FoundryConstants.sol";
import { ETHEREUM_SEPOLIA } from "contracts/crane/constants/networks/ETHEREUM_SEPOLIA.sol";
import { BetterAddress as Address } from "contracts/crane/utils/BetterAddress.sol";
import { ICreate2CallbackFactory } from "contracts/crane/interfaces/ICreate2CallbackFactory.sol";
import { IOperable } from "contracts/crane/interfaces/IOperable.sol";
import { IUniswapV2Factory } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import { IUniswapV2Router } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import { UniV2Factory } from "contracts/crane/protocols/dexes/uniswap/v2/UniV2Factory.sol";
import { UniV2Router02 } from "contracts/crane/protocols/dexes/uniswap/v2/UniV2Router02.sol";
import { IERC20MinterFacade } from "contracts/crane/interfaces/IERC20MinterFacade.sol";

import "contracts/crane/constants/Crane_PATHS.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import "contracts/indexedex/constants/Indexedex_CONSTANTS.sol";
import "contracts/indexedex/constants/Indexedex_INITCODE.sol";
import "contracts/indexedex/constants/Indexedex_PATHS.sol";
import { Script_Indexedex_Balancer_V3 } from "contracts/indexedex/scripts/Script_Indexedex_Balancer_V3.sol";
import { Script_Indexedex_Uniswap_V2 } from "contracts/indexedex/scripts/Script_Indexedex_Uniswap_V2.sol";

contract Local_Sepolia_01_Deploy_Factory_Test
is
    Script_Indexedex_Balancer_V3,
    Script_Indexedex_Uniswap_V2
{

    using Address for address;
    using Address for address payable;

    VmSafe.Wallet dev0Wallet;
    VmSafe.Wallet dev1Wallet;
    VmSafe.Wallet dev2Wallet;
    VmSafe.Wallet dev3Wallet;
    VmSafe.Wallet dev4Wallet;
    VmSafe.Wallet dev5Wallet;
    VmSafe.Wallet dev6Wallet;
    VmSafe.Wallet dev7Wallet;
    VmSafe.Wallet dev8Wallet;
    VmSafe.Wallet dev9Wallet;

    IERC20MinterFacade erc20MinterFacade_;

    function setUp() public virtual {
        dev0Wallet = vm.createWallet(WALLET_0_KEY);
        dev1Wallet = vm.createWallet(WALLET_1_KEY);
        dev2Wallet = vm.createWallet(WALLET_2_KEY);
        dev3Wallet = vm.createWallet(WALLET_3_KEY);
        dev4Wallet = vm.createWallet(WALLET_4_KEY);
        dev5Wallet = vm.createWallet(WALLET_5_KEY);
        dev6Wallet = vm.createWallet(WALLET_6_KEY);
        dev7Wallet = vm.createWallet(WALLET_7_KEY);
        dev8Wallet = vm.createWallet(WALLET_8_KEY);
        dev9Wallet = vm.createWallet(WALLET_9_KEY);

        // setDeployer(address(0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7));
        setDeployer(dev0Wallet.addr);
        setOwner(deployer());
        feeCollector(deployer());
        uniswapV2FeeTo(deployer());
        setDeploymentPath(string.concat(SEPOLIA_DEPLOYMENTS_PATH, BASE_DEPLOYMENTS_FILE));
        // string memory craneFactoriesDeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, CRANE_FACTORIES_FILE));
        // factory(Create2CallBackFactory(parseJsonAddress(craneFactoriesDeploymentJson, "craneFactory")));
        // diamondFactory(IDiamondPackageCallBackFactory(parseJsonAddress(craneFactoriesDeploymentJson, "craneDiamondFactory")));
    }

    function run() public virtual
    override(
        Script_Indexedex_Balancer_V3,
        Script_Indexedex_Uniswap_V2
    ) {
        vm.startBroadcast(WALLET_1_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_2_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_3_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_4_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_5_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_6_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_7_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_8_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(WALLET_9_KEY);
        payable(dev0Wallet.addr).sendValue(9999 ether);
        vm.stopBroadcast();

        vm.startBroadcast(deployer());
        // vm.startBroadcast();

        console.log("deployer balance = ", address(msg.sender).balance);

        weth9(IWETH(ETHEREUM_SEPOLIA.BALANCER_V3_WETH9));
        declare("weth9", address(weth9()));

        // Can reuse existing Sepolia UniswapV2Factory because it is NOT dependent on the WETH9
        declare("uniswapV2Factory", address(uniswapV2Factory()));

        // Must deploy custom UniV2Router02 because it is dependent on the WETH9
        // Deploying with same WETH9 as Sepolia Balancer V3.
        uniswapV2Router(
            IUniswapV2Router(address(new UniV2Router02(address(uniswapV2Factory()), address(weth9()))))
        );
        declare("uniswapV2Router", address(uniswapV2Router()));

        declare("permit2", address(permit2()));

        declare("balancerV3Vault", address(balancerV3Vault()));
        declare("balancerV3Router", address(balancerV3Router()));
        declare("balancerV3BatchRouter", address(balancerV3BatchRouter()));
        declare("balancerV3BufferRouter", address(balancerV3BufferRouter()));

        declare("craneFactory", address(factory()));
        declare("craneDiamondFactory", address(diamondFactory()));

        declare("ownableFacet", address(ownableFacet()));
        declare("operableFacet", address(operableFacet()));

        declare("erc20PermitFacet", address(erc20PermitFacet()));
        declare("erc20MintBurnPkg", address(erc20MintBurnPkg()));

        declare("erc4626Facet", address(erc4626Facet()));
        declare("erc4626DFPkg", address(erc4626DFPkg()));
        declare("erc4626RateProviderFacetDFPkg", address(balV3ERC4626RateProviderFacetDFPkg()));

        declare("wethAwareFacet", address(wethAwareFacet()));
        declare("permit2AwareFacet", address(permit2AwareFacet()));
        declare("uniswapV2AwareFacet", address(uniswapV2AwareFacet()));
        declare("balancerV3VaultAwareFacet", address(balancerV3VaultAwareFacet()));
        declare("versionFacet", address(versionFacet()));
        declare("betterBalancerV3PoolTokenFacet", address(betterBalancerV3PoolTokenFacet()));
        declare("defaultPoolInfoFacet", address(defaultPoolInfoFacet()));
        declare("standardSwapFeePercentageBoundsFacet", address(standardSwapFeePercentageBoundsFacet()));
        declare("standardUnbalancedLiquidityInvariantRatioBoundsFacet", address(standardUnbalancedLiquidityInvariantRatioBoundsFacet()));
        declare("balancerV3AuthenticationFacet", address(balancerV3AuthenticationFacet()));

        declare("standardVaultFacet", address(standardVaultFacet()));
        declare("constantProductStrategyVaultFacet", address(constantProductStrategyVaultFacet()));

        // declare("vaultFeeOracleQueryFacet", address(vaultFeeOracleQueryFacet()));
        // declare("vaultFeeOracleManagerFacet", address(vaultFeeOracleManagerFacet()));
        // declare("vaultFeeOracleDFPkg", address(vaultFeeOracleDFPkg()));
        // declare("vaultFeeOracle", address(vaultFeeOracle()));

        declare("feeCollectorManagerFacet", address(feeCollectorManagerFacet()));
        declare("feeCollectorPushFacet", address(feeCollectorPushFacet()));
        declare("feeCollectorDFPkg", address(feeCollectorDFPkg()));
        declare("feeCollector", address(feeCollector()));

        declare("vaultRegistryDeploymentFacet", address(vaultRegistryDeploymentFacet()));
        declare("vaultRegistryVaultQueryFacet", address(vaultRegistryVaultQueryFacet()));
        declare("vaultRegistryVaultPackageQueryFacet", address(vaultRegistryVaultPackageQueryFacet()));
        declare("vaultRegistryFeeOracleQueryFacet", address(vaultRegistryFeeOracleQueryFacet()));
        declare("vaultRegistryFeeOracleManagerFacet", address(vaultRegistryFeeOracleManagerFacet()));
        declare("vaultRegistryDFPkg", address(vaultRegistryDFPkg()));
        declare("vaultRegistry", address(vaultRegistry()));

        IOperable(address(factory())).setOperatorFor(
            ICreate2CallbackFactory.create3WithInitData.selector,
            address(vaultRegistry()),
            true
        );

        declare("uniswapV2StandardExchangeInFacet", address(uniswapV2StandardExchangeInFacet()));
        declare("uniswapV2StandardExchangeOutFacet", address(uniswapV2StandardExchangeOutFacet()));
        declare("uniswapV2StandardStrategyVaultPkg", address(uniswapV2StandardStrategyVaultPkg()));
        declare("StandardExchangeRateProviderFacetDFPkg", address(standardExchangeRateProviderFacetDFPkg()));

        declare("balancerV3ConstantProductPoolFacet", address(balancerV3ConstantProductPoolFacet()));
        declare("balancerV3ConstantProductPoolStandardVaultPkg", address(balancerV3ConstantProductPoolStandardVaultPkg()));

        declare("balancerV3StandardExchangeRouterDFPkg", address(balancerV3StandardExchangeRouterDFPkg()));
        declare("balancerV3StandardExchangeRouter", address(balancerV3StandardExchangeRouter()));
        declare("balancerV3StandardExchangeExactInBatchRouterFacet", address(balancerV3StandardExchangeExactInBatchRouterFacet()));
        declare("balancerV3StandardExchangeExactOutBatchRouterFacet", address(balancerV3StandardExchangeExactOutBatchRouterFacet()));
        declare("balancerV3StandardExchangeBatchRouterDFPkg", address(balancerV3StandardExchangeBatchRouterDFPkg()));
        declare("balancerV3StandardExchangeBatchRouter", address(balancerV3StandardExchangeBatchRouter()));

        console.log("Deploying minter facade");
        erc20MinterFacade_ = erc20MinterFacade();
        declare("erc20MinterFacade", address(erc20MinterFacade_));

        vm.stopBroadcast();
        writeDeploymentJSON();
    }

}
