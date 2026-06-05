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
import { IDiamondPackageCallBackFactory } from "contracts/crane/interfaces/IDiamondPackageCallBackFactory.sol";

import "contracts/crane/constants/Crane_PATHS.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import "contracts/indexedex/constants/Indexedex_CONSTANTS.sol";
import "contracts/indexedex/constants/Indexedex_INITCODE.sol";
import "contracts/indexedex/constants/Indexedex_PATHS.sol";
import { Script_Indexedex_Balancer_V3 } from "contracts/indexedex/scripts/Script_Indexedex_Balancer_V3.sol";
import { Script_Indexedex_Uniswap_V2 } from "contracts/indexedex/scripts/Script_Indexedex_Uniswap_V2.sol";

contract Local_10_Indexedex_Components_2
is
    Script_Indexedex_Balancer_V3,
    Script_Indexedex_Uniswap_V2
{

    using Address for address;
    using Address for address payable;

    VmSafe.Wallet dev0Wallet;

    function setUp() public virtual {
        dev0Wallet = vm.createWallet(WALLET_0_KEY);

        setDeployer(dev0Wallet.addr);
        feeCollector(deployer());
        uniswapV2FeeTo(deployer());
        setOwner(deployer());
        setDeploymentPath(string.concat(LOCAL_DEPLOYMENTS_PATH, INDEXEDEX_COMPONENTS_2_FILE));

        /* ------------------------------ WETH9 ----------------------------- */
        string memory weth9DeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, WETH9_FILE));
        weth9(IWETH(parseJsonAddress(weth9DeploymentJson, "weth9")));

        /* ---------------------------- Permit 2 ---------------------------- */
        string memory permit2DeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, PERMIT2_FILE));
        permit2(IPermit2(parseJsonAddress(permit2DeploymentJson, "permit2")));

        /* --------------------------- Balancer V3 -------------------------- */
        string memory balancerV3DeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, BALANCER_V3_FILE));
        balancerV3Vault(IVault(parseJsonAddress(balancerV3DeploymentJson, "balancerV3Vault")));

        /* --------------------------- Uniswap V2 --------------------------- */
        string memory uniswapV2DeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, UNISWAP_V2_FILE));
        uniswapV2Factory(UniV2Factory(parseJsonAddress(uniswapV2DeploymentJson, "uniswapV2Factory")));
        uniswapV2Router(UniV2Router02(parseJsonAddress(uniswapV2DeploymentJson, "uniswapV2Router")));

        /* ------------------------- Crane Factories ------------------------ */
        string memory craneFactoriesDeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, CRANE_FACTORIES_FILE));
        factory(Create2CallBackFactory(parseJsonAddress(craneFactoriesDeploymentJson, "craneFactory")));
        diamondFactory(IDiamondPackageCallBackFactory(parseJsonAddress(craneFactoriesDeploymentJson, "craneDiamondFactory")));

        /* ------------------------ Crane Components ------------------------ */
        string memory craneComponentsDeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, CRANE_COMPONENTS_FILE));
        erc20MetadataFacet(ERC20MetadataFacet(parseJsonAddress(craneComponentsDeploymentJson, "erc20MetadataFacet")));
        erc20PermitFacet(ERC20PermitFacet(parseJsonAddress(craneComponentsDeploymentJson, "erc20PermitFacet")));
        uniswapV2AwareFacet(UniswapV2AwareFacet(parseJsonAddress(craneComponentsDeploymentJson, "uniswapV2AwareFacet")));
        balancerV3VaultAwareFacet(BalancerV3VaultAwareFacet(parseJsonAddress(craneComponentsDeploymentJson, "balancerV3VaultAwareFacet")));
        betterBalancerV3PoolTokenFacet(BetterBalancerV3PoolTokenFacet(parseJsonAddress(craneComponentsDeploymentJson, "betterBalancerV3PoolTokenFacet")));
        defaultPoolInfoFacet(DefaultPoolInfoFacet(parseJsonAddress(craneComponentsDeploymentJson, "defaultPoolInfoFacet")));
        permit2AwareFacet(Permit2AwareFacet(parseJsonAddress(craneComponentsDeploymentJson, "permit2AwareFacet")));
        wethAwareFacet(WethAwareFacet(parseJsonAddress(craneComponentsDeploymentJson, "wethAwareFacet")));
        versionFacet(VersionFacet(parseJsonAddress(craneComponentsDeploymentJson, "versionFacet")));
        standardSwapFeePercentageBoundsFacet(StandardSwapFeePercentageBoundsFacet(parseJsonAddress(craneComponentsDeploymentJson, "standardSwapFeePercentageBoundsFacet")));
        standardUnbalancedLiquidityInvariantRatioBoundsFacet(StandardUnbalancedLiquidityInvariantRatioBoundsFacet(parseJsonAddress(craneComponentsDeploymentJson, "standardUnbalancedLiquidityInvariantRatioBoundsFacet")));
        balancerV3AuthenticationFacet(BalancerV3AuthenticationFacet(parseJsonAddress(craneComponentsDeploymentJson, "balancerV3AuthenticationFacet")));
  
        /* ---------------------- Indexedex Components ---------------------- */
        string memory indexedexComponentsDeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, INDEXEDEX_COMPONENTS_FILE));
        standardVaultFacet(StandardVaultFacet(parseJsonAddress(indexedexComponentsDeploymentJson, "standardVaultFacet")));
        constantProductStrategyVaultFacet(ConstantProductStrategyVaultFacet(parseJsonAddress(indexedexComponentsDeploymentJson, "constantProductStrategyVaultFacet")));

        /* ------------------------- Indexedex Core ------------------------- */
        string memory indexedexCoreDeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, INDEXEDEX_CORE_FILE));
        vaultFeeOracle(VaultFeeOracle(parseJsonAddress(indexedexCoreDeploymentJson, "vaultFeeOracle")));
        vaultRegistry(VaultRegistry(parseJsonAddress(indexedexCoreDeploymentJson, "vaultRegistry")));
    }

    function run() public virtual
    override(
        Script_Indexedex_Balancer_V3,
        Script_Indexedex_Uniswap_V2
    ) {
        vm.startBroadcast();

        declare("uniswapV2StandardExchangeInFacet", address(uniswapV2StandardExchangeInFacet()));
        declare("uniswapV2StandardExchangeOutFacet", address(uniswapV2StandardExchangeOutFacet()));
        declare("uniswapV2StandardStrategyVaultPkg", address(uniswapV2StandardStrategyVaultPkg()));

        declare("StandardExchangeRateProviderFacetDFPkg", address(standardExchangeRateProviderFacetDFPkg()));

        declare("balancerV3ConstantProductPoolFacet", address(balancerV3ConstantProductPoolFacet()));
        declare("balancerV3ConstantProductPoolStandardVaultPkg", address(balancerV3ConstantProductPoolStandardVaultPkg()));

        declare("balancerV3StandardExchangeExactInFacet", address(balancerV3StandardExchangeExactInFacet()));
        declare("balancerV3StandardExchangeExactInQueryFacet", address(balancerV3StandardExchangeExactInQueryFacet()));
        declare("balancerV3StandardExchangeExactOutFacet", address(balancerV3StandardExchangeExactOutFacet()));
        declare("balancerV3StandardExchangeExactOutQueryFacet", address(balancerV3StandardExchangeExactOutQueryFacet()));

        declare("balancerV3StandardExchangeRouterDFPkg", address(balancerV3StandardExchangeRouterDFPkg()));

        declare("balancerV3StandardExchangeExactInBatchRouterFacet", address(balancerV3StandardExchangeExactInBatchRouterFacet()));
        declare("balancerV3StandardExchangeExactOutBatchRouterFacet", address(balancerV3StandardExchangeExactOutBatchRouterFacet()));
        declare("balancerV3StandardExchangeBatchRouterDFPkg", address(balancerV3StandardExchangeBatchRouterDFPkg()));

        vm.stopBroadcast();
        writeDeploymentJSON();
    }

}
