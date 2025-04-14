// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import { VmSafe } from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                  Permit 2                                  */
/* -------------------------------------------------------------------------- */

import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

import { IERC20 as OZIERC20 } from "@crane/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@crane/contracts/interfaces/IERC4626.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

/* ------------------------------- Interfaces ------------------------------- */

import { IWETH } from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import { IRateProvider } from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import { IVault } from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import { IRouter } from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import { IBatchRouter } from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBatchRouter.sol";
import { IBufferRouter } from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBufferRouter.sol";

import {
    // Rounding,
    TokenConfig,
    TokenInfo,
    TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import "contracts/crane/constants/CraneINITCODE.sol";
import {terminal as term} from "contracts/crane/utils/vm/foundry/tools/terminal.sol";
import { betterconsole as console } from "contracts/crane/utils/vm/foundry/tools/betterconsole.sol";
import { WALLET_0_KEY } from "contracts/crane/constants/FoundryConstants.sol";
import { IDiamondPackageCallBackFactory } from "contracts/crane/interfaces/IDiamondPackageCallBackFactory.sol";
import { IERC20MintBurn } from "contracts/crane/interfaces/IERC20MintBurn.sol";
import {
    IERC20MintBurnOperableStorage, 
    ERC20MintBurnOperableStorage
} from "contracts/crane/token/ERC20/utils/ERC20MintBurnOperableStorage.sol";
import {
    IOwnableStorage, 
    OwnableStorage
} from "contracts/crane/access/ownable/utils/OwnableStorage.sol";
import {
    IERC20MintBurnOperableFacetDFPkg,
    ERC20MintBurnOperableFacetDFPkg
} from "contracts/crane/token/ERC20/extensions/ERC20MintBurnOperableFacetDFPkg.sol";
import { BetterIERC20 } from "contracts/crane/interfaces/BetterIERC20.sol";
import { BetterIERC20 as IERC20 } from "contracts/crane/interfaces/BetterIERC20.sol";
import { BetterInputHelpers as InputHelpers } from "contracts/crane/protocols/dexes/balancer/v3/solidity-utils/BetterInputHelpers.sol";
import { IUniswapV2Factory } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import { IUniswapV2Router } from "contracts/crane/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import { ERC4626RateProviderFacetDFPkg } from "contracts/crane/protocols/dexes/balancer/v3/rateProviders/ERC4626RateProviderFacetDFPkg.sol";
import { IERC20MinterFacade } from "contracts/crane/interfaces/IERC20MinterFacade.sol";
import "contracts/crane/constants/Crane_PATHS.sol";
import { IOperable } from "contracts/crane/interfaces/IOperable.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import "contracts/indexedex/constants/Indexedex_CONSTANTS.sol";
import "contracts/indexedex/constants/Indexedex_INITCODE.sol";
import { Script_Indexedex_Balancer_V3 } from "contracts/indexedex/scripts/Script_Indexedex_Balancer_V3.sol";
import { Script_Indexedex_Uniswap_V2 } from "contracts/indexedex/scripts/Script_Indexedex_Uniswap_V2.sol";
import { IUniswapV2StandardStrategyVault } from "contracts/indexedex/interfaces/IUniswapV2StandardStrategyVault.sol";

contract Local_Sepolia_02_Test_Tokens_and_Pools_with_WETH
is
    Script_Indexedex_Balancer_V3,
    Script_Indexedex_Uniswap_V2
{

    using InputHelpers for address[];
    using InputHelpers for IERC20[];

    VmSafe.Wallet dev0Wallet;

    string baseDeploymentJson;

    string tokensJSON;
    string tokensKey = "tokens";
    string tokensPath = string.concat(DEPLOYMENT_PATH_PREFIX, LOCAL_DEPLOYMENTS_PATH, tokensKey, ".json");

    string erc4626JSON;
    string erc4626Key = "erc4626";
    string erc4626Path = string.concat(DEPLOYMENT_PATH_PREFIX, LOCAL_DEPLOYMENTS_PATH, erc4626Key, ".json");

    string uniV2PoolsJSON;
    string uniV2PoolsKey = "uniV2Pool";
    string uniV2PoolsPath = string.concat(DEPLOYMENT_PATH_PREFIX, LOCAL_DEPLOYMENTS_PATH, uniV2PoolsKey, ".json");

    string strategyVaultJSON;
    string strategyVaultKey = "strategyVault";
    string strategyVaultPath = string.concat(DEPLOYMENT_PATH_PREFIX, LOCAL_DEPLOYMENTS_PATH, strategyVaultKey, ".json");

    string rateProvidersJSON;
    string rateProvidersKey = "rateProviders";
    string rateProvidersPath = string.concat(DEPLOYMENT_PATH_PREFIX, LOCAL_DEPLOYMENTS_PATH, rateProvidersKey, ".json");

    string constProdPoolsJSON;
    string constProdPooolsKey = "constProdPools";
    string constProdPooolsPath = string.concat(DEPLOYMENT_PATH_PREFIX, LOCAL_DEPLOYMENTS_PATH, constProdPooolsKey, ".json");

    IERC20MinterFacade erc20MinterFacade_;

    /* ---------------------------------------------------------------------- */
    /*                            Base Test Tokens                            */
    /* ---------------------------------------------------------------------- */

    IERC20MintBurn ttA;
    IERC20MintBurn ttB;
    IERC20MintBurn ttC;

    uint256 tokenAInitAmount = 100_000e18;
    uint256 tokenBInitAmount = 100_000e18;
    uint256 tokenCInitAmount = 100_000e18;
    uint256 wethInitAmount = 100e18;

    /* ---------------------------------------------------------------------- */
    /*                            Uniswap V2 Pools                            */
    /* ---------------------------------------------------------------------- */

    IUniswapV2Pair abUniV2Pool;
    uint256 abUniV2PoolLPAmt;
    IUniswapV2Pair acUniV2Pool;
    uint256 acUniV2PoolLPAmt;
    IUniswapV2Pair bcUniV2Pool;
    uint256 bcUniV2PoolLPAmt;
    IUniswapV2Pair aWethUniV2Pool;
    uint256 aWethUniV2PoolLPAmt;
    IUniswapV2Pair bWethUniV2Pool;
    uint256 bWethUniV2PoolLPAmt;
    IUniswapV2Pair cWethUniV2Pool;
    uint256 cWethUniV2PoolLPAmt;

    /* ---------------------------------------------------------------------- */
    /*                            ERC4626 Wrappers                            */
    /* ---------------------------------------------------------------------- */

    IERC4626 ttA4626;
    uint256 ttA4626LPAmt;
    IERC4626 ttB4626;
    uint256 ttB4626LPAmt;
    IERC4626 ttC4626;
    uint256 ttC4626LPAmt;
    IERC4626 weth4626;
    uint256 weth4626LPAmt;

    /* ---------------------------------------------------------------------- */
    /*                       Uniswap V2 Strategy Vaults                       */
    /* ---------------------------------------------------------------------- */

    IUniswapV2StandardStrategyVault abUniV2PoolStrategyVault;
    uint256 abUniV2PoolStrategyVaultLPAmt;
    IUniswapV2StandardStrategyVault acUniV2PoolStrategyVault;
    uint256 acUniV2PoolStrategyVaultLPAmt;
    IUniswapV2StandardStrategyVault bcUniV2PoolStrategyVault;
    uint256 bcUniV2PoolStrategyVaultLPAmt;
    IUniswapV2StandardStrategyVault aWethUniV2PoolStrategyVault;
    uint256 aWethUniV2PoolStrategyVaultLPAmt;
    IUniswapV2StandardStrategyVault bWethUniV2PoolStrategyVault;
    uint256 bWethUniV2PoolStrategyVaultLPAmt;
    IUniswapV2StandardStrategyVault cWethUniV2PoolStrategyVault;
    uint256 cWethUniV2PoolStrategyVaultLPAmt;

    /* ---------------------------------------------------------------------- */
    /*                             Rate Providers                             */
    /* ---------------------------------------------------------------------- */

    /* ----------------------- ERC4626 Rate Providers ----------------------- */

    IRateProvider ttA4626RateProvider;
    IRateProvider ttB4626RateProvider;
    IRateProvider ttC4626RateProvider;
    IRateProvider weth4626RateProvider;

    /* -------------- Uniswap V2 Strategy Vault Rate Providers -------------- */

    /* ------------------------- A/B Uniswap V2 Pool ------------------------ */

    IRateProvider aRatedABUniV2PoolStrategyVaultRateProvider;
    IRateProvider bRatedABUniV2PoolStrategyVaultRateProvider;

    /* ------------------------- A/C Uniswap V2 Pool ------------------------ */

    IRateProvider aRatedACUniV2PoolStrategyVaultRateProvider;
    IRateProvider cRatedACUniV2PoolStrategyVaultRateProvider;

    /* ------------------------- B/C Uniswap V2 Pool ------------------------ */

    IRateProvider bRatedBCUniV2PoolStrategyVaultRateProvider;
    IRateProvider cRatedBCUniV2PoolStrategyVaultRateProvider;

    /* ------------------------- A/WETH Uniswap V2 Pool -------------------- */

    IRateProvider aRatedAWethUniV2PoolStrategyVaultRateProvider;
    IRateProvider wethRatedAWethUniV2PoolStrategyVaultRateProvider;

    /* ------------------------- B/WETH Uniswap V2 Pool -------------------- */

    IRateProvider bRatedBWethUniV2PoolStrategyVaultRateProvider;
    IRateProvider wethRatedBWethUniV2PoolStrategyVaultRateProvider;

    /* ------------------------- C/WETH Uniswap V2 Pool -------------------- */

    IRateProvider cRatedCWethUniV2PoolStrategyVaultRateProvider;
    IRateProvider wethRatedCWethUniV2PoolStrategyVaultRateProvider;

    /* ---------------------------------------------------------------------- */
    /*                              Token Configs                             */
    /* ---------------------------------------------------------------------- */

    TokenConfig ttATokenConfig;
    TokenConfig ttBTokenConfig;
    TokenConfig ttCTokenConfig;
    TokenConfig wethTokenConfig;

    TokenConfig ttAWrapperTokenConfig;
    TokenConfig ttBWrapperTokenConfig;
    TokenConfig ttCWrapperTokenConfig;
    TokenConfig wethWrapperTokenConfig;

    TokenConfig aRatedABStrategyVaultTokenConfig;
    TokenConfig bRatedABStrategyVaultTokenConfig;

    TokenConfig aRatedACStrategyVaultTokenConfig;
    TokenConfig cRatedACStrategyVaultTokenConfig;

    TokenConfig bRatedBCStrategyVaultTokenConfig;
    TokenConfig cRatedBCStrategyVaultTokenConfig;

    TokenConfig aRatedAWethStrategyVaultTokenConfig;
    TokenConfig wethRatedAWethStrategyVaultTokenConfig;

    TokenConfig bRatedBWethStrategyVaultTokenConfig;
    TokenConfig wethRatedBWethStrategyVaultTokenConfig;

    TokenConfig cRatedCWethStrategyVaultTokenConfig;
    TokenConfig wethRatedCWethStrategyVaultTokenConfig;

    /* ---------------------------------------------------------------------- */
    /*                            Const Prod Pools                            */
    /* ---------------------------------------------------------------------- */

    address abConstProdPool;
    address acConstProdPool;
    address bcConstProdPool;

    address aWETHConstProdPool;
    address bWETHConstProdPool;
    address cWETHConstProdPool;

    address aWrapperConstProdPool;
    address bWrapperConstProdPool;
    address cWrapperConstProdPool;
    address wethWrapperConstProdPool;

    address aRatedABStrategyVaultConstProdPool;
    address bRatedABStrategyVaultConstProdPool;

    address aRatedACStrategyVaultConstProdPool;
    address cRatedACStrategyVaultConstProdPool;

    address bRatedBCStrategyVaultConstProdPool;
    address cRatedBCStrategyVaultConstProdPool;

    address aRatedAWethStrategyVaultConstProdPool;
    address wethRatedAWethStrategyVaultConstProdPool;

    address bRatedBWethStrategyVaultConstProdPool;
    address wethRatedBWethStrategyVaultConstProdPool;

    address cRatedCWethStrategyVaultConstProdPool;
    address wethRatedCWethStrategyVaultConstProdPool;

    function setUp() public virtual {
        dev0Wallet = vm.createWallet(WALLET_0_KEY);
        setDeployer(dev0Wallet.addr);

        feeCollector(deployer());
        uniswapV2FeeTo(deployer());
        setOwner(deployer());
        setDeploymentPath(string.concat(LOCAL_DEPLOYMENTS_PATH, BASE_TOKENS_POOLS_FILE));
        baseDeploymentJson = loadDeployments(string.concat(LOCAL_DEPLOYMENTS_PATH, BASE_DEPLOYMENTS_FILE));


        weth9(IWETH(parseJsonAddress(baseDeploymentJson, "weth9")));
        factory(Create2CallBackFactory(parseJsonAddress(baseDeploymentJson, "craneFactory")));
        diamondFactory(IDiamondPackageCallBackFactory(parseJsonAddress(baseDeploymentJson, "craneDiamondFactory")));
        erc20MintBurnPkg(ERC20MintBurnOperableFacetDFPkg(parseJsonAddress(baseDeploymentJson, "erc20MintBurnPkg")));
        erc4626DFPkg(ERC4626DFPkg(parseJsonAddress(baseDeploymentJson, "erc4626DFPkg")));
        balV3ERC4626RateProviderFacetDFPkg(ERC4626RateProviderFacetDFPkg(parseJsonAddress(baseDeploymentJson, "erc4626RateProviderFacetDFPkg")));
        balancerV3ConstantProductPoolStandardVaultPkg(BalancerV3ConstantProductPoolStandardVaultPkg(parseJsonAddress(baseDeploymentJson, "balancerV3ConstantProductPoolStandardVaultPkg")));
        permit2(IPermit2(parseJsonAddress(baseDeploymentJson, "permit2")));
        balancerV3Vault(IVault(parseJsonAddress(baseDeploymentJson, "balancerV3Vault")));
        balancerV3Router(IRouter(parseJsonAddress(baseDeploymentJson, "balancerV3StandardExchangeRouter")));
        uniswapV2Router(IUniswapV2Router(parseJsonAddress(baseDeploymentJson, "uniswapV2Router")));
        uniswapV2Factory(IUniswapV2Factory(parseJsonAddress(baseDeploymentJson, "uniswapV2Factory")));
        uniswapV2StandardStrategyVaultPkg(UniswapV2StandardStrategyVaultPkg(parseJsonAddress(baseDeploymentJson, "uniswapV2StandardStrategyVaultPkg")));
        standardExchangeRateProviderFacetDFPkg(standardExchangeRateProviderFacetDFPkg(parseJsonAddress(baseDeploymentJson, "StandardExchangeRateProviderFacetDFPkg")));
        erc20MinterFacade_ = IERC20MinterFacade(parseJsonAddress(baseDeploymentJson, "erc20MinterFacade"));
        balancerV3BatchRouter(IBatchRouter(parseJsonAddress(baseDeploymentJson, "balancerV3BatchRouter")));
        balancerV3BufferRouter(IBufferRouter(parseJsonAddress(baseDeploymentJson, "balancerV3BufferRouter")));
    }

    function run() public virtual
    override(
        Script_Indexedex_Balancer_V3,
        Script_Indexedex_Uniswap_V2
    ) {
        vm.startBroadcast();

        /* ------------------------------------------------------------------ */
        /*                          Base Test Tokens                          */
        /* ------------------------------------------------------------------ */

        ttA = erc20MintBurnOperable(owner(), "TestTokenA", "TTA", 18);
        declare(ttA.name(), address(ttA));
        tokensJSON = vm.serializeAddress(
                tokensKey,
                ttA.name(),
                address(ttA)
            );
        IOperable(address(ttA)).setOperatorFor(
            IERC20MintBurn.mint.selector,
            address(erc20MinterFacade_),
            true
        );

        ttB = erc20MintBurnOperable(owner(), "TestTokenB", "TTB", 18);
        declare(ttB.name(), address(ttB));
        tokensJSON = vm.serializeAddress(
                tokensKey,
                ttB.name(),
                address(ttB)
            );
        IOperable(address(ttB)).setOperatorFor(
            IERC20MintBurn.mint.selector,
            address(erc20MinterFacade_),
            true
        );

        ttC = erc20MintBurnOperable(owner(), "TestTokenC", "TTC", 18);
        declare(ttC.name(), address(ttC));
        tokensJSON = vm.serializeAddress(
                tokensKey,
                ttC.name(),
                address(ttC)
            );
        IOperable(address(ttC)).setOperatorFor(
            IERC20MintBurn.mint.selector,
            address(erc20MinterFacade_),
            true
        );

        /* ------------------------------------------------------------------ */
        /*                          Uniswap V2 Pools                          */
        /* ------------------------------------------------------------------ */

        (
            abUniV2Pool,
            abUniV2PoolLPAmt
        ) = createABUniV2Pool();
        declare("abUniV2Pool", address(abUniV2Pool));
        uniV2PoolsJSON = vm.serializeAddress(
                uniV2PoolsKey,
                "abUniV2Pool",
                address(abUniV2Pool)
            );

        (
            acUniV2Pool,
            acUniV2PoolLPAmt
        ) = createACUniV2Pool();
        declare("acUniV2Pool", address(acUniV2Pool));
        uniV2PoolsJSON = vm.serializeAddress(
                uniV2PoolsKey,
                "acUniV2Pool",
                address(acUniV2Pool)
            );

        (
            bcUniV2Pool,
            bcUniV2PoolLPAmt
        ) = createBCUniV2Pool();
        declare("bcUniV2Pool", address(bcUniV2Pool));
        uniV2PoolsJSON = vm.serializeAddress(
                uniV2PoolsKey,
                "bcUniV2Pool",
                address(bcUniV2Pool)
            );

        (
            aWethUniV2Pool,
            aWethUniV2PoolLPAmt
        ) = createAWETHUniV2Pool();
        declare("aWethUniV2Pool", address(aWethUniV2Pool));
        uniV2PoolsJSON = vm.serializeAddress(
                uniV2PoolsKey,
                "aWethUniV2Pool",
                address(aWethUniV2Pool)
            );
        
        (
            bWethUniV2Pool,
            bWethUniV2PoolLPAmt
        ) = createBWETHUniV2Pool();
        declare("bWethUniV2Pool", address(bWethUniV2Pool));
        uniV2PoolsJSON = vm.serializeAddress(
                uniV2PoolsKey,
                "bWethUniV2Pool",
                address(bWethUniV2Pool)
            );
        
        (
            cWethUniV2Pool,
            cWethUniV2PoolLPAmt
        ) = createCWETHUniV2Pool();
        declare("cWethUniV2Pool", address(cWethUniV2Pool));
        uniV2PoolsJSON = vm.serializeAddress(
                uniV2PoolsKey,
                "cWethUniV2Pool",
                address(cWethUniV2Pool)
            );
        
        /* ------------------------------------------------------------------ */
        /*                          ERC4626 Wrappers                          */
        /* ------------------------------------------------------------------ */

        ttA4626 = erc4626(address(ttA));
        declare("ttA4626", address(ttA4626));
        erc4626JSON = vm.serializeAddress(
                uniV2PoolsKey,
                "ttA4626",
                address(ttA4626)
            );
        ttB4626 = erc4626(address(ttB));
        declare("ttB4626", address(ttB4626));
        erc4626JSON = vm.serializeAddress(
                uniV2PoolsKey,
                "ttB4626",
                address(ttB4626)
            );
        ttC4626 = erc4626(address(ttC));
        declare("ttC4626", address(ttC4626));
        erc4626JSON = vm.serializeAddress(
                uniV2PoolsKey,
                "ttC4626",
                address(ttC4626)
            );
        weth4626 = erc4626(address(weth9()));
        declare("weth4626", address(weth4626));
        erc4626JSON = vm.serializeAddress(
                uniV2PoolsKey,
                "weth4626",
                address(weth4626)
            );

        ttA.approve(address(ttA4626), type(uint256).max);
        ttB.approve(address(ttB4626), type(uint256).max);
        ttC.approve(address(ttC4626), type(uint256).max);
        weth9().approve(address(weth4626), type(uint256).max);

        ttA.mint(deployer(), tokenAInitAmount);
        ttB.mint(deployer(), tokenBInitAmount);
        ttC.mint(deployer(), tokenCInitAmount);
        weth9().deposit{value: wethInitAmount}();

        ttA4626.deposit(tokenAInitAmount, deployer());
        ttA4626LPAmt = ttA4626.balanceOf(deployer());

        ttB4626.deposit(tokenBInitAmount, deployer());
        ttB4626LPAmt = ttB4626.balanceOf(deployer());

        ttC4626.deposit(tokenCInitAmount, deployer());
        ttC4626LPAmt = ttC4626.balanceOf(deployer());

        weth4626.deposit(wethInitAmount, deployer());
        weth4626LPAmt = weth4626.balanceOf(deployer());

        /* ------------------------------------------------------------------ */
        /*                     Uniswap V2 Strategy Vaults                     */
        /* ------------------------------------------------------------------ */

        (
            abUniV2PoolStrategyVault,
            abUniV2PoolStrategyVaultLPAmt
        ) = createABUniV2PoolStrategyVault();
        declare("abUniV2PoolStrategyVault", address(abUniV2PoolStrategyVault));
        strategyVaultJSON = vm.serializeAddress(
                strategyVaultKey,
                "abUniV2PoolStrategyVault",
                address(abUniV2PoolStrategyVault)
            );

        (
            acUniV2PoolStrategyVault,
            acUniV2PoolStrategyVaultLPAmt
        ) = createACUniV2PoolStrategyVault();
        declare("acUniV2PoolStrategyVault", address(acUniV2PoolStrategyVault));
        strategyVaultJSON = vm.serializeAddress(
                strategyVaultKey,
                "acUniV2PoolStrategyVault",
                address(acUniV2PoolStrategyVault)
            );
        
        (
            bcUniV2PoolStrategyVault,
            bcUniV2PoolStrategyVaultLPAmt
        ) = createBCUniV2PoolStrategyVault();
        declare("bcUniV2PoolStrategyVault", address(bcUniV2PoolStrategyVault));
        strategyVaultJSON = vm.serializeAddress(
                strategyVaultKey,
                "bcUniV2PoolStrategyVault",
                address(bcUniV2PoolStrategyVault)
            );
        
        (
            aWethUniV2PoolStrategyVault,
            aWethUniV2PoolStrategyVaultLPAmt
        ) = createAWETHUniV2PoolStrategyVault();
        declare("aWethUniV2PoolStrategyVault", address(aWethUniV2PoolStrategyVault));
        strategyVaultJSON = vm.serializeAddress(
                strategyVaultKey,
                "aWethUniV2PoolStrategyVault",
                address(aWethUniV2PoolStrategyVault)
            );
        
        (
            bWethUniV2PoolStrategyVault,
            bWethUniV2PoolStrategyVaultLPAmt
        ) = createBWETHUniV2PoolStrategyVault();
        declare("bWethUniV2PoolStrategyVault", address(bWethUniV2PoolStrategyVault));
        strategyVaultJSON = vm.serializeAddress(
                strategyVaultKey,
                "bWethUniV2PoolStrategyVault",
                address(bWethUniV2PoolStrategyVault)
            );
        
        (
            cWethUniV2PoolStrategyVault,
            cWethUniV2PoolStrategyVaultLPAmt
        ) = createCWETHUniV2PoolStrategyVault();
        declare("cWethUniV2PoolStrategyVault", address(cWethUniV2PoolStrategyVault));
        strategyVaultJSON = vm.serializeAddress(
                strategyVaultKey,
                "cWethUniV2PoolStrategyVault",
                address(cWethUniV2PoolStrategyVault)
            );

        /* ------------------------------------------------------------------ */
        /*                           Rate Providers                           */
        /* ------------------------------------------------------------------ */

        /* ------------------------------------------------------------------ */
        /*                       ERC4626 Rate Providers                       */
        /* ------------------------------------------------------------------ */

        ttA4626RateProvider = balV3ERC4626RateProvider(ttA4626);
        declare("ttA4626RateProvider", address(ttA4626RateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "ttA4626RateProvider",
                address(ttA4626RateProvider)
            );

        ttB4626RateProvider = balV3ERC4626RateProvider(ttB4626);
        declare("ttB4626RateProvider", address(ttB4626RateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "ttB4626RateProvider",
                address(ttB4626RateProvider)
            );
        ttC4626RateProvider = balV3ERC4626RateProvider(ttC4626);
        declare("ttC4626RateProvider", address(ttC4626RateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "ttC4626RateProvider",
                address(ttC4626RateProvider)
            );
        weth4626RateProvider = balV3ERC4626RateProvider(weth4626);
        declare("weth4626RateProvider", address(weth4626RateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "weth4626RateProvider",
                address(weth4626RateProvider)
            );

        /* ------------ Uniswap V2 Strategy Vault Rate Providers ------------ */

        /* ----------------------- A/B Uniswap V2 Pool ---------------------- */

        aRatedABUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            abUniV2PoolStrategyVault,
            ttA
        );
        declare("aRatedABUniV2PoolStrategyVaultRateProvider", address(aRatedABUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "aRatedABUniV2PoolStrategyVaultRateProvider",
                address(aRatedABUniV2PoolStrategyVaultRateProvider)
            );

        bRatedABUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            abUniV2PoolStrategyVault,
            ttB
        );
        declare("bRatedABUniV2PoolStrategyVaultRateProvider", address(bRatedABUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "bRatedABUniV2PoolStrategyVaultRateProvider",
                address(bRatedABUniV2PoolStrategyVaultRateProvider)
            );

        /* ----------------------- A/C Uniswap V2 Pool ---------------------- */

        aRatedACUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            acUniV2PoolStrategyVault,
            ttA
        );
        declare("aRatedACUniV2PoolStrategyVaultRateProvider", address(aRatedACUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "aRatedACUniV2PoolStrategyVaultRateProvider",
                address(aRatedACUniV2PoolStrategyVaultRateProvider)
            );

        cRatedACUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            acUniV2PoolStrategyVault,
            ttC
        );
        declare("cRatedACUniV2PoolStrategyVaultRateProvider", address(cRatedACUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "cRatedACUniV2PoolStrategyVaultRateProvider",
                address(cRatedACUniV2PoolStrategyVaultRateProvider)
            );
        /* ----------------------- B/C Uniswap V2 Pool ---------------------- */

        bRatedBCUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            bcUniV2PoolStrategyVault,
            ttB
        );
        declare("bRatedBCUniV2PoolStrategyVaultRateProvider", address(bRatedBCUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "bRatedBCUniV2PoolStrategyVaultRateProvider",
                address(bRatedBCUniV2PoolStrategyVaultRateProvider)
            );

        cRatedBCUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            bcUniV2PoolStrategyVault,
            ttC
        );
        declare("cRatedBCUniV2PoolStrategyVaultRateProvider", address(cRatedBCUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "cRatedBCUniV2PoolStrategyVaultRateProvider",
                address(cRatedBCUniV2PoolStrategyVaultRateProvider)
            );

        /* --------------------- A/WETH Uniswap V2 Pool --------------------- */

        aRatedAWethUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            aWethUniV2PoolStrategyVault,
            ttA
        );
        declare("aRatedAWethUniV2PoolStrategyVaultRateProvider", address(aRatedAWethUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "aRatedAWethUniV2PoolStrategyVaultRateProvider",
                address(aRatedAWethUniV2PoolStrategyVaultRateProvider)
            );
        
        wethRatedAWethUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            aWethUniV2PoolStrategyVault,
            IERC20(address(weth9()))
        );
        declare("wethRatedAWethUniV2PoolStrategyVaultRateProvider", address(wethRatedAWethUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "wethRatedAWethUniV2PoolStrategyVaultRateProvider",
                address(wethRatedAWethUniV2PoolStrategyVaultRateProvider)
            );

        /* --------------------- B/WETH Uniswap V2 Pool --------------------- */

        bRatedBWethUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            bWethUniV2PoolStrategyVault,
            ttB
        );
        declare("bRatedBWethUniV2PoolStrategyVaultRateProvider", address(bRatedBWethUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "bRatedBWethUniV2PoolStrategyVaultRateProvider",
                address(bRatedBWethUniV2PoolStrategyVaultRateProvider)
            );
        
        wethRatedBWethUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            bWethUniV2PoolStrategyVault,
            IERC20(address(weth9()))
        );
        declare("wethRatedBWethUniV2PoolStrategyVaultRateProvider", address(wethRatedBWethUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "wethRatedBWethUniV2PoolStrategyVaultRateProvider",
                address(wethRatedBWethUniV2PoolStrategyVaultRateProvider)
            );

        /* --------------------- C/WETH Uniswap V2 Pool --------------------- */

        cRatedCWethUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            cWethUniV2PoolStrategyVault,
            ttC
        );
        declare("cRatedCWethUniV2PoolStrategyVaultRateProvider", address(cRatedCWethUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "cRatedCWethUniV2PoolStrategyVaultRateProvider",
                address(cRatedCWethUniV2PoolStrategyVaultRateProvider)
            );
        
        wethRatedCWethUniV2PoolStrategyVaultRateProvider = standardExchangeIRateProvider(
            cWethUniV2PoolStrategyVault,
            IERC20(address(weth9()))
        );
        declare("wethRatedCWethUniV2PoolStrategyVaultRateProvider", address(wethRatedCWethUniV2PoolStrategyVaultRateProvider));
        rateProvidersJSON = vm.serializeAddress(
                rateProvidersKey,
                "wethRatedCWethUniV2PoolStrategyVaultRateProvider",
                address(wethRatedCWethUniV2PoolStrategyVaultRateProvider)
            );

        /* ------------------------------------------------------------------ */
        /*                            Token Configs                           */
        /* ------------------------------------------------------------------ */

        /* ----------------------- Base Token Configs ----------------------- */

        ttATokenConfig = TokenConfig({
            token: OZIERC20(address(ttA)),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        ttBTokenConfig = TokenConfig({
            token: OZIERC20(address(ttB)),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        ttCTokenConfig = TokenConfig({
            token: OZIERC20(address(ttC)),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
        wethTokenConfig = TokenConfig({
            token: OZIERC20(address(weth9())),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        /* ------------------ ERC4626 Wrapper Token Configs ----------------- */

        ttAWrapperTokenConfig = TokenConfig({
            token: OZIERC20(address(ttA4626)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: ttA4626RateProvider,
            paysYieldFees: false
        });
        ttBWrapperTokenConfig = TokenConfig({
            token: OZIERC20(address(ttB4626)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: ttB4626RateProvider,
            paysYieldFees: false
        });
        ttCWrapperTokenConfig = TokenConfig({
            token: OZIERC20(address(ttC4626)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: ttC4626RateProvider,
            paysYieldFees: false
        });
        wethWrapperTokenConfig = TokenConfig({
            token: OZIERC20(address(weth4626)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: weth4626RateProvider,
            paysYieldFees: false
        });

        /* ------------ Uniswap V2 Strategy Vault Rate Providers ------------ */

        /* ----------------------- A/B Uniswap V2 Pool ---------------------- */

        aRatedABStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(abUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: aRatedABUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });
        bRatedABStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(abUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: bRatedABUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });

        /* ----------------------- A/C Uniswap V2 Pool ---------------------- */

        aRatedACStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(acUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: aRatedACUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });
        cRatedACStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(acUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: cRatedACUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });

        /* ----------------------- B/C Uniswap V2 Pool ---------------------- */

        bRatedBCStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(bcUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: bRatedBCUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });
        cRatedBCStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(bcUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: cRatedBCUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });

        /* --------------------- A/WETH Uniswap V2 Pool --------------------- */

        aRatedAWethStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(aWethUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: aRatedAWethUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });
        wethRatedAWethStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(aWethUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: wethRatedAWethUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });

        /* --------------------- B/WETH Uniswap V2 Pool --------------------- */

        bRatedBWethStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(bWethUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: bRatedBWethUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });
        wethRatedBWethStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(bWethUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: wethRatedBWethUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });

        /* --------------------- C/WETH Uniswap V2 Pool --------------------- */

        cRatedCWethStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(cWethUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: cRatedCWethUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });
        wethRatedCWethStrategyVaultTokenConfig = TokenConfig({
            token: OZIERC20(address(cWethUniV2PoolStrategyVault)),
            tokenType: TokenType.WITH_RATE,
            rateProvider: wethRatedCWethUniV2PoolStrategyVaultRateProvider,
            paysYieldFees: false
        });

        /* ------------------------------------------------------------------ */
        /*                          Const Prod Pools                          */
        /* ------------------------------------------------------------------ */

        abConstProdPool = createABConstProdPool();
        declare("abConstProdPool", address(abConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "abConstProdPool",
                address(abConstProdPool)
            );

        acConstProdPool = createACConstProdPool();
        declare("acConstProdPool", address(acConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "acConstProdPool",
                address(acConstProdPool)
            );
        
        bcConstProdPool = createBCConstProdPool();
        declare("bcConstProdPool", address(bcConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "bcConstProdPool",
                address(bcConstProdPool)
            );

        /* ---------------------- WETH Const Prod Pools --------------------- */

        aWETHConstProdPool = createAWETHConstProdPool();
        declare("aWETHConstProdPool", address(aWETHConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "aWETHConstProdPool",
                address(aWETHConstProdPool)
            );
        
        bWETHConstProdPool = createBWETHConstProdPool();
        declare("bWETHConstProdPool", address(bWETHConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "bWETHConstProdPool",
                address(bWETHConstProdPool)
            );
        
        cWETHConstProdPool = createCWETHConstProdPool();
        declare("cWETHConstProdPool", address(cWETHConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "cWETHConstProdPool",
                address(cWETHConstProdPool)
            );

        /* -------------------- Wrapper Const Prod Pools -------------------- */

        aWrapperConstProdPool = createAWrapperConstProdPool();
        declare("aWrapperConstProdPool", address(aWrapperConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "aWrapperConstProdPool",
                address(aWrapperConstProdPool)
            );
        
        bWrapperConstProdPool = createBWrapperConstProdPool();
        declare("bWrapperConstProdPool", address(bWrapperConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "bWrapperConstProdPool",
                address(bWrapperConstProdPool)
            );
        
        cWrapperConstProdPool = createCWrapperConstProdPool();
        declare("cWrapperConstProdPool", address(cWrapperConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "cWrapperConstProdPool",
                address(cWrapperConstProdPool)
            );
        
        wethWrapperConstProdPool = createWETHWrapperConstProdPool();
        declare("wethWrapperConstProdPool", address(wethWrapperConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "wethWrapperConstProdPool",
                address(wethWrapperConstProdPool)
            );

        /* ----------------- Strategy Vault Const Prod Pools ---------------- */

        aRatedABStrategyVaultConstProdPool = createBARatedStratVaultPool();
        declare("aRatedABStrategyVaultConstProdPool", address(aRatedABStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "aRatedABStrategyVaultConstProdPool",
                address(aRatedABStrategyVaultConstProdPool)
            );
        
        bRatedABStrategyVaultConstProdPool = createABRatedStratVaultPool();
        declare("bRatedABStrategyVaultConstProdPool", address(bRatedABStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "bRatedABStrategyVaultConstProdPool",
                address(bRatedABStrategyVaultConstProdPool)
            );

        aRatedACStrategyVaultConstProdPool = createCARatedStratVaultPool();
        declare("aRatedACStrategyVaultConstProdPool", address(aRatedACStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "aRatedACStrategyVaultConstProdPool",
                address(aRatedACStrategyVaultConstProdPool)
            );
        
        cRatedACStrategyVaultConstProdPool = createACRatedStratVaultPool();
        declare("cRatedACStrategyVaultConstProdPool", address(cRatedACStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "cRatedACStrategyVaultConstProdPool",
                address(cRatedACStrategyVaultConstProdPool)
            );

        bRatedBCStrategyVaultConstProdPool = createCBRatedStratVaultPool();
        declare("bRatedBCStrategyVaultConstProdPool", address(bRatedBCStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "bRatedBCStrategyVaultConstProdPool",
                address(bRatedBCStrategyVaultConstProdPool)
            );
        
        cRatedBCStrategyVaultConstProdPool = createBCRatedStratVaultPool();
        declare("cRatedBCStrategyVaultConstProdPool", address(cRatedBCStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "cRatedBCStrategyVaultConstProdPool",
                address(cRatedBCStrategyVaultConstProdPool)
            );

        aRatedAWethStrategyVaultConstProdPool = createARatedAWethStrategyVaultConstProdPool();
        declare("aRatedAWethStrategyVaultConstProdPool", address(aRatedAWethStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "aRatedAWethStrategyVaultConstProdPool",
                address(aRatedAWethStrategyVaultConstProdPool)
            );
        
        wethRatedAWethStrategyVaultConstProdPool = createWETHRatedAWethStrategyVaultConstProdPool();
        declare("wethRatedAWethStrategyVaultConstProdPool", address(wethRatedAWethStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "wethRatedAWethStrategyVaultConstProdPool",
                address(wethRatedAWethStrategyVaultConstProdPool)
            );

        bRatedBWethStrategyVaultConstProdPool = createBRatedBWethStrategyVaultConstProdPool();
        declare("bRatedBWethStrategyVaultConstProdPool", address(bRatedBWethStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "bRatedBWethStrategyVaultConstProdPool",
                address(bRatedBWethStrategyVaultConstProdPool)
            );
        
        wethRatedBWethStrategyVaultConstProdPool = createWETHRatedBWethStrategyVaultConstProdPool();
        declare("wethRatedBWethStrategyVaultConstProdPool", address(wethRatedBWethStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "wethRatedBWethStrategyVaultConstProdPool",
                address(wethRatedBWethStrategyVaultConstProdPool)
            );

        cRatedCWethStrategyVaultConstProdPool = createCRatedCWethStrategyVaultConstProdPool();
        declare("cRatedCWethStrategyVaultConstProdPool", address(cRatedCWethStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "cRatedCWethStrategyVaultConstProdPool",
                address(cRatedCWethStrategyVaultConstProdPool)
            );
        
        wethRatedCWethStrategyVaultConstProdPool = createWETHRatedCWethStrategyVaultConstProdPool();
        declare("wethRatedCWethStrategyVaultConstProdPool", address(wethRatedCWethStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "wethRatedCWethStrategyVaultConstProdPool",
                address(wethRatedCWethStrategyVaultConstProdPool)
            );

        address abacStrategyVaultConstProdPool = createABACStratVaultPool();
        declare("abacStrategyVaultConstProdPool", address(abacStrategyVaultConstProdPool));
        constProdPoolsJSON = vm.serializeAddress(
                constProdPooolsKey,
                "abacStrategyVaultConstProdPool",
                address(abacStrategyVaultConstProdPool)
            );

        ttA.mint(deployer(), tokenAInitAmount / 10);
        ttA.approve(address(abUniV2PoolStrategyVault), type(uint256).max);
        abUniV2PoolStrategyVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(ttA)),
            // uint256 amountIn,
            tokenAInitAmount / 10,
            // IERC20 tokenOut,
            IERC20(address(abUniV2PoolStrategyVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );

        ttC.mint(deployer(), tokenCInitAmount / 10);
        ttC.approve(address(acUniV2PoolStrategyVault), type(uint256).max);
        acUniV2PoolStrategyVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(ttC)),
            // uint256 amountIn,
            tokenCInitAmount / 10,
            // IERC20 tokenOut,
            IERC20(address(acUniV2PoolStrategyVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );

        ttC.mint(deployer(), tokenCInitAmount / 10);
        ttC.approve(address(bcUniV2PoolStrategyVault), type(uint256).max);
        bcUniV2PoolStrategyVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(ttC)),
            // uint256 amountIn,
            tokenCInitAmount / 10,
            // IERC20 tokenOut,
            IERC20(address(bcUniV2PoolStrategyVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );

        ttA.mint(deployer(), tokenAInitAmount / 10);
        ttA.approve(address(aWethUniV2PoolStrategyVault), type(uint256).max);
        aWethUniV2PoolStrategyVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(ttA)),
            // uint256 amountIn,
            tokenAInitAmount / 10,
            // IERC20 tokenOut,
            IERC20(address(aWethUniV2PoolStrategyVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );

        ttB.mint(deployer(), tokenBInitAmount / 10);
        ttB.approve(address(bWethUniV2PoolStrategyVault), type(uint256).max);
        bWethUniV2PoolStrategyVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(ttB)),
            // uint256 amountIn,
            tokenBInitAmount / 10,
            // IERC20 tokenOut,
            IERC20(address(bWethUniV2PoolStrategyVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );

        ttC.mint(deployer(), tokenCInitAmount / 10);
        ttC.approve(address(cWethUniV2PoolStrategyVault), type(uint256).max);
        cWethUniV2PoolStrategyVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(ttC)),
            // uint256 amountIn,
            tokenCInitAmount / 10,
            // IERC20 tokenOut,
            IERC20(address(cWethUniV2PoolStrategyVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );

        ttA.mint(deployer(), tokenAInitAmount);
        ttB.mint(deployer(), tokenBInitAmount);
        ttC.mint(deployer(), tokenCInitAmount);
        weth9().deposit{value: wethInitAmount}();

        ttA.approve(address(ttA4626), type(uint256).max);
        ttB.approve(address(ttB4626), type(uint256).max);
        ttC.approve(address(ttC4626), type(uint256).max);
        weth9().approve(address(weth4626), type(uint256).max);

        ttA4626.deposit(tokenAInitAmount, deployer());
        ttB4626.deposit(tokenBInitAmount, deployer());
        ttC4626.deposit(tokenCInitAmount, deployer());
        weth4626.deposit(wethInitAmount, deployer());

        ttA.mint(deployer(), tokenAInitAmount);
        ttB.mint(deployer(), tokenBInitAmount);
        ttC.mint(deployer(), tokenCInitAmount);
        weth9().deposit{value: wethInitAmount * 10}();

        vm.stopBroadcast();
        // writeDeploymentJSON();
        term.mkDir(term.dirName(tokensPath));
        term.touch(tokensPath);
        vm.writeJson(
            tokensJSON,
            tokensPath
        );
        term.mkDir(term.dirName(erc4626Path));
        term.touch(erc4626Path);
        vm.writeJson(
            erc4626JSON,
            erc4626Path
        );
        term.mkDir(term.dirName(uniV2PoolsPath));
        term.touch(uniV2PoolsPath);
        vm.writeJson(
            uniV2PoolsJSON,
            uniV2PoolsPath
        );
        term.mkDir(term.dirName(strategyVaultPath));
        term.touch(strategyVaultPath);
        vm.writeJson(
            strategyVaultJSON,
            strategyVaultPath
        );
        term.mkDir(term.dirName(rateProvidersPath));
        term.touch(rateProvidersPath);
        vm.writeJson(
            rateProvidersJSON,
            rateProvidersPath
        );
        term.mkDir(term.dirName(constProdPooolsPath));
        term.touch(constProdPooolsPath);
        vm.writeJson(
            constProdPoolsJSON,
            constProdPooolsPath
        );
    }

    function createABUniV2Pool() public
    returns(
        IUniswapV2Pair newPool,
        uint256 lpAmt
    ) {
        newPool = uniswapV2Pair(
            BetterIERC20(address(ttA)),
            BetterIERC20(address(ttB))
        );

        ttA.mint(deployer(), tokenAInitAmount);
        ttB.mint(deployer(), tokenBInitAmount);
        ttA.approve(address(uniswapV2Router()), type(uint256).max);
        ttB.approve(address(uniswapV2Router()), type(uint256).max);

        (
            // uint256 amount0,
            ,
            // uint256 amount1,
            ,
            // uint256 liquidity
            lpAmt
        ) = uniswapV2Router().addLiquidity(
            // address tokenA,
            address(ttA),
            // address tokenB,
            address(ttB),
            // uint amountADesired,
            tokenAInitAmount,
            // uint amountBDesired,
            tokenBInitAmount,
            // uint amountAMin,
            tokenAInitAmount * 95 / 100,
            // uint amountBMin,
            tokenBInitAmount * 95 / 100,
            // address to,
            address(deployer()),
            // uint deadline
            block.timestamp + 999
        );
    }

    function createACUniV2Pool() public
    returns(
        IUniswapV2Pair newPool,
        uint256 lpAmt
    ) {
        newPool = uniswapV2Pair(
            BetterIERC20(address(ttA)),
            BetterIERC20(address(ttC))
        );

        ttA.mint(deployer(), tokenAInitAmount);
        ttC.mint(deployer(), tokenCInitAmount);
        ttA.approve(address(uniswapV2Router()), type(uint256).max);
        ttC.approve(address(uniswapV2Router()), type(uint256).max);

        (
            // uint256 amount0,
            ,
            // uint256 amount1,
            ,
            // uint256 liquidity
            lpAmt
        ) = uniswapV2Router().addLiquidity(
            // address tokenA,
            address(ttA),
            // address tokenB,
            address(ttC),
            // uint amountADesired,
            tokenAInitAmount,
            // uint amountBDesired,
            tokenCInitAmount,
            // uint amountAMin,
            tokenAInitAmount * 95 / 100,
            // uint amountBMin,
            tokenCInitAmount * 95 / 100,
            // address to,
            address(deployer()),
            // uint deadline
            block.timestamp + 999
        );
    }

    function createBCUniV2Pool() public
    returns(
        IUniswapV2Pair newPool,
        uint256 lpAmt
    ) {
        newPool = uniswapV2Pair(
            BetterIERC20(address(ttB)),
            BetterIERC20(address(ttC))
        );
        // declare("bcUniV2Pool", address(newPool));

        ttB.mint(deployer(), tokenBInitAmount);
        ttC.mint(deployer(), tokenCInitAmount);
        ttB.approve(address(uniswapV2Router()), type(uint256).max);
        ttC.approve(address(uniswapV2Router()), type(uint256).max);
        
        (
            // uint256 amount0,
            ,
            // uint256 amount1,
            ,
            // uint256 liquidity
            lpAmt
        ) = uniswapV2Router().addLiquidity(
            // address tokenA,
            address(ttB),
            // address tokenB,
            address(ttC),
            // uint amountADesired,
            tokenBInitAmount,
            // uint amountBDesired,
            tokenCInitAmount,
            // uint amountAMin,
            tokenBInitAmount * 95 / 100,
            // uint amountBMin,
            tokenCInitAmount * 95 / 100,
            // address to,
            address(deployer()),
            // uint deadline
            block.timestamp + 999
        );
    }

    function createAWETHUniV2Pool() public
    returns(
        IUniswapV2Pair newPool,
        uint256 lpAmt
    ) {
        newPool = uniswapV2Pair(
            BetterIERC20(address(ttA)),
            BetterIERC20(address(weth9()))
        );

        ttA.mint(deployer(), tokenAInitAmount);
        weth9().deposit{value: wethInitAmount}();
        ttA.approve(address(uniswapV2Router()), type(uint256).max);
        weth9().approve(address(uniswapV2Router()), type(uint256).max);

        (
            // uint256 amount0,
            ,
            // uint256 amount1,
            ,
            // uint256 liquidity
            lpAmt
        ) = uniswapV2Router().addLiquidity(
            // address tokenA,
            address(ttA),
            // address tokenB,
            address(weth9()),
            // uint amountADesired,
            tokenAInitAmount,
            // uint amountBDesired,
            wethInitAmount,
            // uint amountAMin,
            tokenAInitAmount * 95 / 100,
            // uint amountBMin,
            wethInitAmount * 95 / 100,
            // address to,
            address(deployer()),
            // uint deadline
            block.timestamp + 999
        );
    }

    function createBWETHUniV2Pool() public
    returns(
        IUniswapV2Pair newPool,
        uint256 lpAmt
    ) {
        newPool = uniswapV2Pair(
            BetterIERC20(address(ttB)),
            BetterIERC20(address(weth9()))
        );

        ttB.mint(deployer(), tokenBInitAmount);
        weth9().deposit{value: wethInitAmount}();
        ttB.approve(address(uniswapV2Router()), type(uint256).max);
        weth9().approve(address(uniswapV2Router()), type(uint256).max);

        (
            // uint256 amount0,
            ,
            // uint256 amount1,
            ,
            // uint256 liquidity
            lpAmt
        ) = uniswapV2Router().addLiquidity(
            // address tokenA,
            address(ttB),
            // address tokenB,
            address(weth9()),
            // uint amountADesired,
            tokenBInitAmount,
            // uint amountBDesired,
            wethInitAmount,
            // uint amountAMin,
            tokenBInitAmount * 95 / 100,
            // uint amountBMin,
            wethInitAmount * 95 / 100,
            // address to,
            address(deployer()),
            // uint deadline
            block.timestamp + 999
        );
    }

    function createCWETHUniV2Pool() public
    returns(
        IUniswapV2Pair newPool,
        uint256 lpAmt
    ) {
        newPool = uniswapV2Pair(
            BetterIERC20(address(ttC)),
            BetterIERC20(address(weth9()))
        );

        ttC.mint(deployer(), tokenCInitAmount);
        weth9().deposit{value: wethInitAmount}();
        ttC.approve(address(uniswapV2Router()), type(uint256).max);
        weth9().approve(address(uniswapV2Router()), type(uint256).max);

        (
            // uint256 amount0,
            ,
            // uint256 amount1,
            ,
            // uint256 liquidity
            lpAmt
        ) = uniswapV2Router().addLiquidity(
            // address tokenA,
            address(ttC),
            // address tokenB,
            address(weth9()),
            // uint amountADesired,
            tokenCInitAmount,
            // uint amountBDesired,
            wethInitAmount,
            // uint amountAMin,
            tokenAInitAmount * 95 / 100,
            // uint amountBMin,
            wethInitAmount * 95 / 100,
            // address to,
            address(deployer()),
            // uint deadline
            block.timestamp + 999
        );
    }

    function createABUniV2PoolStrategyVault() public
    returns(
        IUniswapV2StandardStrategyVault newVault,
        uint256 vaultAmt
    ) {
        newVault = uniswapV2StandardStrategyVault(abUniV2Pool);
        abUniV2Pool.approve(address(newVault), type(uint256).max);
        vaultAmt = newVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(abUniV2Pool)),
            // uint256 amountIn,
            abUniV2Pool.balanceOf(address(deployer())),
            // IERC20 tokenOut,
            IERC20(address(newVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );
    }

    function createACUniV2PoolStrategyVault() public
    returns(
        IUniswapV2StandardStrategyVault newVault,
        uint256 vaultAmt
    ) {
        newVault = uniswapV2StandardStrategyVault(acUniV2Pool);
        acUniV2Pool.approve(address(newVault), type(uint256).max);
        vaultAmt = newVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(acUniV2Pool)),
            // uint256 amountIn,
            acUniV2Pool.balanceOf(address(deployer())),
            // IERC20 tokenOut,
            IERC20(address(newVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );
    }

    function createBCUniV2PoolStrategyVault() public
    returns(
        IUniswapV2StandardStrategyVault newVault,
        uint256 vaultAmt
    ) {
        newVault = uniswapV2StandardStrategyVault(bcUniV2Pool);
        bcUniV2Pool.approve(address(newVault), type(uint256).max);
        vaultAmt = newVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(bcUniV2Pool)),
            // uint256 amountIn,
            bcUniV2Pool.balanceOf(address(deployer())),
            // IERC20 tokenOut,
            IERC20(address(newVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );
    }

    function createAWETHUniV2PoolStrategyVault() public
    returns(
        IUniswapV2StandardStrategyVault newVault,
        uint256 vaultAmt
    ) {
        newVault = uniswapV2StandardStrategyVault(aWethUniV2Pool);
        aWethUniV2Pool.approve(address(newVault), type(uint256).max);
        vaultAmt = newVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(aWethUniV2Pool)),
            // uint256 amountIn,
            aWethUniV2Pool.balanceOf(address(deployer())),
            // IERC20 tokenOut,
            IERC20(address(newVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );
    }

    function createBWETHUniV2PoolStrategyVault() public
    returns(
        IUniswapV2StandardStrategyVault newVault,
        uint256 vaultAmt
    ) {
        newVault = uniswapV2StandardStrategyVault(bWethUniV2Pool);
        bWethUniV2Pool.approve(address(newVault), type(uint256).max);
        vaultAmt = newVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(bWethUniV2Pool)),
            // uint256 amountIn,
            bWethUniV2Pool.balanceOf(address(deployer())),
            // IERC20 tokenOut,
            IERC20(address(newVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );
    }

    function createCWETHUniV2PoolStrategyVault() public
    returns(
        IUniswapV2StandardStrategyVault newVault,
        uint256 vaultAmt
    ) {
        newVault = uniswapV2StandardStrategyVault(cWethUniV2Pool);
        cWethUniV2Pool.approve(address(newVault), type(uint256).max);
        vaultAmt = newVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(cWethUniV2Pool)),
            // uint256 amountIn,
            cWethUniV2Pool.balanceOf(address(deployer())),
            // IERC20 tokenOut,
            IERC20(address(newVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                             Const Prod Pools                           */
    /* ---------------------------------------------------------------------- */

    /* --------------------- Base Token Const Prod Pools -------------------- */

    function createABConstProdPool() public returns(address newPool) {

        address[] memory abConstProdPoolsTokens;
        uint256[] memory abConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            abConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            abConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttA),
            // uint256 tokenAInitAmount,
            tokenAInitAmount,
            // TokenConfig memory tokenAConfig,
            ttATokenConfig,
            // address tokenB,
            address(ttB),
            // uint256 tokenBInitAmount,
            tokenBInitAmount,
            // TokenConfig memory tokenBConfig
            ttBTokenConfig
        );
        // declare("abConstProdPool", newPool);

        ttA.mint(deployer(), tokenAInitAmount);
        ttB.mint(deployer(), tokenBInitAmount);
        ttA.approve(address(permit2()), type(uint256).max);
        ttB.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttA), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(ttB), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 abBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            abConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            abConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("abBPTOut", abBPTOut);

    }

    function createACConstProdPool() public returns(address newPool) {

        address[] memory acConstProdPoolsTokens;
        uint256[] memory acConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            acConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            acConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttA),
            // uint256 tokenAInitAmount,
            tokenAInitAmount,
            // TokenConfig memory tokenAConfig,
            ttATokenConfig,
            // address tokenB,
            address(ttC),
            // uint256 tokenBInitAmount,
            tokenCInitAmount,
            // TokenConfig memory tokenBConfig
            ttCTokenConfig
        );
        // declare("acConstProdPool", newPool);

        ttA.mint(deployer(), tokenAInitAmount);
        ttC.mint(deployer(), tokenCInitAmount);
        ttA.approve(address(permit2()), type(uint256).max);
        ttC.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttA), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(ttC), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 acBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            acConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            acConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("acBPTOut", acBPTOut);

    }

    function createBCConstProdPool() public returns(address newPool) {

        address[] memory bcConstProdPoolsTokens;
        uint256[] memory bcConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            bcConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            bcConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttB),
            // uint256 tokenAInitAmount,
            tokenBInitAmount,
            // TokenConfig memory tokenAConfig,
            ttBTokenConfig,
            // address tokenB,
            address(ttC),
            // uint256 tokenBInitAmount,
            tokenCInitAmount,
            // TokenConfig memory tokenBConfig
            ttCTokenConfig
        );
        // declare("bcConstProdPool", newPool);

        ttB.mint(deployer(), tokenBInitAmount);
        ttC.mint(deployer(), tokenCInitAmount);
        ttB.approve(address(permit2()), type(uint256).max);
        ttC.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttB), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(ttC), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 bcBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            bcConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            bcConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("bcBPTOut", bcBPTOut);

    }

    /* ---------------- Base Token and WETH Const Prod Pools ---------------- */

    function createAWETHConstProdPool() public returns(address newPool) {

        address[] memory aWETHConstProdPoolsTokens;
        uint256[] memory aWETHConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            aWETHConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            aWETHConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttA),
            // uint256 tokenAInitAmount,
            tokenAInitAmount,
            // TokenConfig memory tokenAConfig,
            ttATokenConfig,
            // address tokenB,
            address(weth9()),
            // uint256 tokenBInitAmount,
            wethInitAmount,
            // TokenConfig memory tokenBConfig
            wethTokenConfig
        );

        ttA.mint(deployer(), tokenAInitAmount);
        weth9().deposit{value: wethInitAmount}();
        ttA.approve(address(permit2()), type(uint256).max);
        weth9().approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttA), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(weth9()), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 aWETHBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            aWETHConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            aWETHConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("aWETHBPTOut", aWETHBPTOut);

    }

    function createBWETHConstProdPool() public returns(address newPool) {

        address[] memory bWETHConstProdPoolsTokens;
        uint256[] memory bWETHConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            bWETHConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            bWETHConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttB),
            // uint256 tokenAInitAmount,
            tokenBInitAmount,
            // TokenConfig memory tokenAConfig,
            ttBTokenConfig,
            // address tokenB,
            address(weth9()),
            // uint256 tokenBInitAmount,
            wethInitAmount,
            // TokenConfig memory tokenBConfig
            wethTokenConfig
        );

        ttB.mint(deployer(), tokenBInitAmount);
        weth9().deposit{value: wethInitAmount}();
        ttB.approve(address(permit2()), type(uint256).max);
        weth9().approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttB), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(weth9()), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 bWETHBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            bWETHConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            bWETHConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("bWETHBPTOut", bWETHBPTOut);

    }

    function createCWETHConstProdPool() public returns(address newPool) {

        address[] memory cWETHConstProdPoolsTokens;
        uint256[] memory cWETHConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            cWETHConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            cWETHConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttC),
            // uint256 tokenAInitAmount,
            tokenCInitAmount,
            // TokenConfig memory tokenAConfig,
            ttCTokenConfig,
            // address tokenB,
            address(weth9()),
            // uint256 tokenBInitAmount,
            wethInitAmount,
            // TokenConfig memory tokenBConfig
            wethTokenConfig
        );

        ttC.mint(deployer(), tokenCInitAmount);
        weth9().deposit{value: wethInitAmount}();
        ttC.approve(address(permit2()), type(uint256).max);
        weth9().approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttC), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(weth9()), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 cWETHBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            cWETHConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            cWETHConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("cWETHBPTOut", cWETHBPTOut);

    }

    /* ------------------ Base and Wrapper Const Prod Pools ----------------- */

    function createAWrapperConstProdPool() public returns(address newPool) {

        address[] memory aWrapperConstProdPoolsTokens;
        uint256[] memory aWrapperConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            aWrapperConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            aWrapperConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttA),
            // uint256 tokenAInitAmount,
            tokenAInitAmount,
            // TokenConfig memory tokenAConfig,
            ttATokenConfig,
            // address tokenB,
            address(ttA4626),
            // uint256 tokenBInitAmount,
            ttA4626LPAmt,
            // TokenConfig memory tokenBConfig
            ttAWrapperTokenConfig
        );

        ttA.mint(deployer(), tokenAInitAmount);
        ttA.approve(address(permit2()), type(uint256).max);
        ttA4626.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttA), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(ttA4626), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 aWrapperBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            aWrapperConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            aWrapperConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("aWrapperBPTOut", aWrapperBPTOut);

    }

    function createBWrapperConstProdPool() public returns(address newPool) {

        address[] memory bWrapperConstProdPoolsTokens;
        uint256[] memory bWrapperConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            bWrapperConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            bWrapperConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttB),
            // uint256 tokenAInitAmount,
            tokenBInitAmount,
            // TokenConfig memory tokenAConfig,
            ttBTokenConfig,
            // address tokenB,
            address(ttB4626),
            // uint256 tokenBInitAmount,
            ttB4626LPAmt,
            // TokenConfig memory tokenBConfig
            ttBWrapperTokenConfig
        );

        ttB.mint(deployer(), tokenBInitAmount);
        ttB.approve(address(permit2()), type(uint256).max);
        ttB4626.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttB), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(ttB4626), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 bWrapperBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            bWrapperConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            bWrapperConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("bWrapperBPTOut", bWrapperBPTOut);

    }

    function createCWrapperConstProdPool() public returns(address newPool) {

        address[] memory cWrapperConstProdPoolsTokens;
        uint256[] memory cWrapperConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            cWrapperConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            cWrapperConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttC),
            // uint256 tokenAInitAmount,
            tokenCInitAmount,
            // TokenConfig memory tokenAConfig,
            ttCTokenConfig,
            // address tokenB,
            address(ttC4626),
            // uint256 tokenBInitAmount,
            ttC4626LPAmt,
            // TokenConfig memory tokenBConfig
            ttCWrapperTokenConfig
        );

        ttC.mint(deployer(), tokenCInitAmount);
        ttC.approve(address(permit2()), type(uint256).max);
        ttC4626.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttC), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(ttC4626), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 cWrapperBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            cWrapperConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            cWrapperConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("cWrapperBPTOut", cWrapperBPTOut);

    }

    function createWETHWrapperConstProdPool() public returns(address newPool) {

        address[] memory wethWrapperConstProdPoolsTokens;
        uint256[] memory wethWrapperConstProdInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            wethWrapperConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            wethWrapperConstProdInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(weth9()),
            // uint256 tokenAInitAmount,
            wethInitAmount,
            // TokenConfig memory tokenAConfig,
            wethTokenConfig,
            // address tokenB,
            address(weth4626),
            // uint256 tokenBInitAmount,
            weth4626LPAmt,
            // TokenConfig memory tokenBConfig
            wethWrapperTokenConfig
        );
        weth9().deposit{value: wethInitAmount}();
        weth9().approve(address(permit2()), type(uint256).max);
        weth4626.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(weth9()), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(weth4626), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 wethWrapperBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            wethWrapperConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            wethWrapperConstProdInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("wethWrapperBPTOut", wethWrapperBPTOut);

    }

    /* -------------------- Base and Strategy Vault Pools ------------------- */

    /* ----------------- A/B Strategy Vault Const Prod Pools ---------------- */

        // Mapped in menu correctly
    function createABRatedStratVaultPool() public returns(address newPool) {

        address[] memory abRatedStratVaultPoolsTokens;
        uint256[] memory abRatedStratVaultInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            abRatedStratVaultPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            abRatedStratVaultInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttA),
            // uint256 tokenAInitAmount,
            tokenAInitAmount,
            // TokenConfig memory tokenAConfig,
            ttATokenConfig,
            // address tokenB,
            address(abUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            abUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            bRatedABStrategyVaultTokenConfig
        );
        declare("abRatedStratVaultPool", newPool);

        ttA.mint(deployer(), tokenAInitAmount);
        ttA.approve(address(permit2()), type(uint256).max);
        abUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttA), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(abUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 abRatedStratVaultBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            abRatedStratVaultPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            abRatedStratVaultInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("abRatedStratVaultBPTOut", abRatedStratVaultBPTOut);

    }

        // Mapped in menu correctly
    function createBARatedStratVaultPool() public returns(address newPool) {

        address[] memory baRatedStratVaultPoolsTokens;
        uint256[] memory baRatedStratVaultInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            baRatedStratVaultPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            baRatedStratVaultInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttB),
            // uint256 tokenAInitAmount,
            tokenBInitAmount,
            // TokenConfig memory tokenAConfig,
            ttBTokenConfig,
            // address tokenB,
            address(abUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            abUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            aRatedABStrategyVaultTokenConfig
        );

        ttB.mint(deployer(), tokenBInitAmount);
        ttB.approve(address(permit2()), type(uint256).max);
        abUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttB), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(abUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 baRatedStratVaultBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            baRatedStratVaultPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            baRatedStratVaultInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("baRatedStratVaultBPTOut", baRatedStratVaultBPTOut);

    }

    /* ---------------------- A/C Strategy Vault Poolsd --------------------- */

        // Mapped in menu correctly
    function createACRatedStratVaultPool() public returns(address newPool) {

        address[] memory acRatedStratVaultPoolsTokens;
        uint256[] memory acRatedStratVaultInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            acRatedStratVaultPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            acRatedStratVaultInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttA),
            // uint256 tokenAInitAmount,
            tokenAInitAmount,
            // TokenConfig memory tokenAConfig,
            ttATokenConfig,
            // address tokenB,
            address(acUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            acUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            cRatedACStrategyVaultTokenConfig
        );

        ttA.mint(deployer(), tokenAInitAmount);
        ttA.approve(address(permit2()), type(uint256).max);
        acUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttA), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(acUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 acRatedStratVaultBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            acRatedStratVaultPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            acRatedStratVaultInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("acRatedStratVaultBPTOut", acRatedStratVaultBPTOut);

    }

        // Mapped in menu correctly
    function createCARatedStratVaultPool() public returns(address newPool) {

        address[] memory caRatedStratVaultPoolsTokens;
        uint256[] memory caRatedStratVaultInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            caRatedStratVaultPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            caRatedStratVaultInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttC),
            // uint256 tokenAInitAmount,
            tokenCInitAmount,
            // TokenConfig memory tokenAConfig,
            ttCTokenConfig,
            // address tokenB,
            address(acUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            acUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            aRatedACStrategyVaultTokenConfig
        );

        ttC.mint(deployer(), tokenCInitAmount);
        ttC.approve(address(permit2()), type(uint256).max);
        acUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttC), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(acUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 caRatedStratVaultBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            caRatedStratVaultPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            caRatedStratVaultInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("caRatedStratVaultBPTOut", caRatedStratVaultBPTOut);

    }

    function createABACStratVaultPool() public returns(address newPool) {

        ttB.mint(deployer(), tokenBInitAmount);
        ttB.approve(address(abUniV2PoolStrategyVault), type(uint256).max);
        uint256 abAmount = abUniV2PoolStrategyVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(ttB)),
            // uint256 amountIn,
            tokenBInitAmount,
            // IERC20 tokenOut,
            IERC20(address(abUniV2PoolStrategyVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );

        TokenConfig memory aBNoRateTokenConfig = TokenConfig({
            token: OZIERC20(address(abUniV2PoolStrategyVault)),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        ttC.mint(deployer(), tokenCInitAmount / 10);
        ttC.approve(address(acUniV2PoolStrategyVault), type(uint256).max);
        uint256 acAmount = acUniV2PoolStrategyVault.exchangeIn(
            // IERC20 tokenIn,
            IERC20(address(ttC)),
            // uint256 amountIn,
            tokenCInitAmount / 10,
            // IERC20 tokenOut,
            IERC20(address(acUniV2PoolStrategyVault)),
            // uint256 minAmountOut,
            0,
            // address recipient,
            address(deployer()),
            // bool pretransferred
            false
        );

        TokenConfig memory acNoRateTokenConfig = TokenConfig({
            token: OZIERC20(address(acUniV2PoolStrategyVault)),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });

        address[] memory abacStratVaultPoolsTokens;
        uint256[] memory abacStratVaultInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            abacStratVaultPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            abacStratVaultInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(abUniV2PoolStrategyVault),
            // uint256 tokenAInitAmount,
            abAmount,
            // TokenConfig memory tokenAConfig,
            aBNoRateTokenConfig,
            // address tokenB,
            address(acUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            acAmount,
            // TokenConfig memory tokenBConfig
            acNoRateTokenConfig
        );
        declare("abRatedStratVaultPool", newPool);

        abUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(abUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        acUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(acUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            abacStratVaultPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            abacStratVaultInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );

    }

    /* ---------------------- B/C Strategy Vault Pools ---------------------- */

    function createBCRatedStratVaultPool() public returns(address newPool) {

        address[] memory bcRatedStratVaultPoolsTokens;
        uint256[] memory bcRatedStratVaultInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            bcRatedStratVaultPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            bcRatedStratVaultInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttB),
            // uint256 tokenAInitAmount,
            tokenBInitAmount,
            // TokenConfig memory tokenAConfig,
            ttBTokenConfig,
            // address tokenB,
            address(bcUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            bcUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            cRatedBCStrategyVaultTokenConfig
        );

        ttB.mint(deployer(), tokenBInitAmount);
        ttB.approve(address(permit2()), type(uint256).max);
        bcUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttB), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(bcUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 bcRatedStratVaultBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            bcRatedStratVaultPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            bcRatedStratVaultInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("bcRatedStratVaultBPTOut", bcRatedStratVaultBPTOut);

    }

    function createCBRatedStratVaultPool() public returns(address newPool) {

        address[] memory cbRatedStratVaultPoolsTokens;
        uint256[] memory cbRatedStratVaultInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            cbRatedStratVaultPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            cbRatedStratVaultInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttC),
            // uint256 tokenAInitAmount,
            tokenCInitAmount,
            // TokenConfig memory tokenAConfig,
            ttCTokenConfig,
            // address tokenB,
            address(bcUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            bcUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            bRatedBCStrategyVaultTokenConfig
        );

        ttC.mint(deployer(), tokenCInitAmount);
        ttC.approve(address(permit2()), type(uint256).max);
        bcUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttC), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(bcUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 cbRatedStratVaultBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            cbRatedStratVaultPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            cbRatedStratVaultInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("cbRatedStratVaultBPTOut", cbRatedStratVaultBPTOut);

    }

    /* ---------------- WETH Strategy Vault Const Prod Pools ---------------- */

    /* --------------- A/WETH Strategy Vault Const Prod Pools --------------- */

    function createARatedAWethStrategyVaultConstProdPool() public returns(address newPool) {

        address[] memory aRatedAWethStrategyVaultConstProdPoolsTokens;
        uint256[] memory aRatedAWethStrategyVaultConstProdPoolsInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            aRatedAWethStrategyVaultConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            aRatedAWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(weth9()),
            // uint256 tokenAInitAmount,
            wethInitAmount,
            // TokenConfig memory tokenAConfig,
            wethTokenConfig,
            // address tokenB,
            address(aWethUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            aWethUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            aRatedAWethStrategyVaultTokenConfig
        );
        weth9().deposit{value: wethInitAmount}();
        weth9().approve(address(permit2()), type(uint256).max);
        aWethUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttA), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(aWethUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 aRatedAWethStrategyVaultConstProdPoolBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            aRatedAWethStrategyVaultConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            aRatedAWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("aRatedAWethStrategyVaultConstProdPoolBPTOut", aRatedAWethStrategyVaultConstProdPoolBPTOut);

    }

    function createWETHRatedAWethStrategyVaultConstProdPool() public returns(address newPool) {

        address[] memory wethRatedAWethStrategyVaultConstProdPoolsTokens;
        uint256[] memory wethRatedAWethStrategyVaultConstProdPoolsInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            wethRatedAWethStrategyVaultConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            wethRatedAWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttA),
            // uint256 tokenAInitAmount,
            tokenAInitAmount,
            // TokenConfig memory tokenAConfig,
            ttATokenConfig,
            // address tokenB,
            address(aWethUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            aWethUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            wethRatedAWethStrategyVaultTokenConfig
        );
        ttA.mint(deployer(), tokenAInitAmount);
        ttA.approve(address(permit2()), type(uint256).max);

        aWethUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttA), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(aWethUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 wethRatedAWethStrategyVaultConstProdPoolBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            wethRatedAWethStrategyVaultConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            wethRatedAWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("wethRatedAWethStrategyVaultConstProdPoolBPTOut = ", wethRatedAWethStrategyVaultConstProdPoolBPTOut);

    }

    /* --------------- B/WETH Strategy Vault Const Prod Pools --------------- */

    function createBRatedBWethStrategyVaultConstProdPool() public returns(address newPool) {

        address[] memory bRatedBWethStrategyVaultConstProdPoolsTokens;
        uint256[] memory bRatedBWethStrategyVaultConstProdPoolsInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            bRatedBWethStrategyVaultConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            bRatedBWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(weth9()),
            // uint256 tokenAInitAmount,
            wethInitAmount,
            // TokenConfig memory tokenAConfig,
            wethTokenConfig,
            // address tokenB,
            address(bWethUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            bWethUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            bRatedBWethStrategyVaultTokenConfig
        );
        weth9().deposit{value: wethInitAmount}();
        weth9().approve(address(permit2()), type(uint256).max);

        bWethUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttB), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(bWethUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 bRatedBWethStrategyVaultConstProdPoolBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            bRatedBWethStrategyVaultConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            bRatedBWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("bRatedBWethStrategyVaultConstProdPoolBPTOut", bRatedBWethStrategyVaultConstProdPoolBPTOut);

    }

    function createWETHRatedBWethStrategyVaultConstProdPool() public returns(address newPool) {

        address[] memory wethRatedBWethStrategyVaultConstProdPoolsTokens;
        uint256[] memory wethRatedBWethStrategyVaultConstProdPoolsInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            wethRatedBWethStrategyVaultConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            wethRatedBWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttB),
            // uint256 tokenAInitAmount,
            tokenBInitAmount,
            // TokenConfig memory tokenAConfig,
            ttBTokenConfig,
            // address tokenB,
            address(bWethUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            bWethUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            wethRatedBWethStrategyVaultTokenConfig
        );
        ttB.mint(deployer(), tokenBInitAmount);
        ttB.approve(address(permit2()), type(uint256).max);

        bWethUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttB), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(bWethUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 wethRatedBWethStrategyVaultConstProdPoolBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            wethRatedBWethStrategyVaultConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            wethRatedBWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("wethRatedBWethStrategyVaultConstProdPoolBPTOut = ", wethRatedBWethStrategyVaultConstProdPoolBPTOut);

    }

    /* --------------- C/WETH Strategy Vault Const Prod Pools --------------- */

    function createCRatedCWethStrategyVaultConstProdPool() public returns(address newPool) {

        address[] memory cRatedCWethStrategyVaultConstProdPoolsTokens;
        uint256[] memory cRatedCWethStrategyVaultConstProdPoolsInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            cRatedCWethStrategyVaultConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            cRatedCWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(weth9()),
            // uint256 tokenAInitAmount,
            wethInitAmount,
            // TokenConfig memory tokenAConfig,
            wethTokenConfig,
            // address tokenB,
            address(cWethUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            cWethUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            cRatedCWethStrategyVaultTokenConfig
        );
        weth9().deposit{value: wethInitAmount}();
        weth9().approve(address(permit2()), type(uint256).max);
        
        cWethUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttC), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(cWethUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 cRatedCWethStrategyVaultConstProdPoolBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            cRatedCWethStrategyVaultConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            cRatedCWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("cRatedCWethStrategyVaultConstProdPoolBPTOut", cRatedCWethStrategyVaultConstProdPoolBPTOut);

    }

    function createWETHRatedCWethStrategyVaultConstProdPool() public returns(address newPool) {

        address[] memory wethRatedCWethStrategyVaultConstProdPoolsTokens;
        uint256[] memory wethRatedCWethStrategyVaultConstProdPoolsInitAmounts;

        (
            // address newPool,
            newPool,
            // TokenConfig[] memory tokenConfigs,
            ,
            // address[] memory poolsTokens,
            wethRatedCWethStrategyVaultConstProdPoolsTokens,
            // uint256[] memory tokenInitAmounts,
            wethRatedCWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 tokenAPoolIndex,
            ,
            // uint256 tokenBPoolIndex
            
        ) = balancerV3ConstantProductPool(
            // address hooks,
            address(0),
            // address tokenA,
            address(ttC),
            // uint256 tokenAInitAmount,
            tokenCInitAmount,
            // TokenConfig memory tokenAConfig,
            ttCTokenConfig,
            // address tokenB,
            address(cWethUniV2PoolStrategyVault),
            // uint256 tokenBInitAmount,
            cWethUniV2PoolStrategyVaultLPAmt / 2,
            // TokenConfig memory tokenBConfig
            wethRatedCWethStrategyVaultTokenConfig
        );
        ttC.mint(deployer(), tokenCInitAmount);
        ttC.approve(address(permit2()), type(uint256).max);
        
        cWethUniV2PoolStrategyVault.approve(address(permit2()), type(uint256).max);
        permit2().approve(address(ttC), address(balancerV3Router()), type(uint160).max, type(uint48).max);
        permit2().approve(address(cWethUniV2PoolStrategyVault), address(balancerV3Router()), type(uint160).max, type(uint48).max);

        uint256 wethRatedCWethStrategyVaultConstProdPoolBPTOut =  balancerV3Router().initialize(
            // address pool,
            newPool,
            // IERC20[] memory tokens,
            wethRatedCWethStrategyVaultConstProdPoolsTokens.castToOZIERC20(),
            // uint256[] memory exactAmountsIn,
            wethRatedCWethStrategyVaultConstProdPoolsInitAmounts,
            // uint256 minBptAmountOut,
            0,
            // bool wethIsEth,
            false,
            // bytes memory userData
            bytes("")
        );
        console.log("wethRatedCWethStrategyVaultConstProdPoolBPTOut = ", wethRatedCWethStrategyVaultConstProdPoolBPTOut);

    }

}
