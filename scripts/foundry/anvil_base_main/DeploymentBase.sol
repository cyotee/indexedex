// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";
import {WALLET_0_KEY} from "@crane/contracts/constants/FoundryConstants.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import {IRouter as IAerodromeRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory as IAerodromePoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {IVault as IBalancerV3Vault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter as IBalancerV3Router} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {ICamelotFactory} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotFactory.sol";
import {ICamelotV2Router} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotV2Router.sol";

/// @title DeploymentBase
/// @notice Shared base contract for all deployment scripts
/// @dev Provides JSON read/write utilities and common configuration
abstract contract DeploymentBase is Script {
    /* ---------------------------------------------------------------------- */
    /*                                Constants                               */
    /* ---------------------------------------------------------------------- */

    string internal constant OUT_DIR = "deployments/anvil_base_main";
    string internal constant UNISWAP_V2_CORE_FILE = "03a_uniswap_v2_core.json";
    string internal constant BALANCER_CORE_FILE = "03b_balancer_v3_core.json";
    string internal constant AERODROME_CORE_FILE = "03c_aerodrome_core.json";

    function _outDir() internal view returns (string memory outDir) {
        try vm.envString("OUT_DIR_OVERRIDE") returns (string memory overrideDir) {
            if (bytes(overrideDir).length > 0) {
                return overrideDir;
            }
        } catch {}

        return OUT_DIR;
    }

    function _networkProfile() internal view returns (string memory profile) {
        try vm.envString("NETWORK_PROFILE") returns (string memory envProfile) {
            if (bytes(envProfile).length > 0) {
                return envProfile;
            }
        } catch {}

        return "base_main";
    }

    function _envOrDefaultAddress(string memory key, address defaultAddress) internal view returns (address resolved) {
        try vm.envAddress(key) returns (address envAddress_) {
            return envAddress_;
        } catch {
            return defaultAddress;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              State Variables                           */
    /* ---------------------------------------------------------------------- */

    uint256 internal privateKey;
    address internal deployer;
    address internal owner;

    // Base mainnet protocol bindings
    IPermit2 internal permit2;
    IWETH internal weth;
    IBalancerV3Vault internal balancerV3Vault;
    IBalancerV3Router internal balancerV3Router;
    IAerodromeRouter internal aerodromeRouter;
    IAerodromePoolFactory internal aerodromePoolFactory;
    IUniswapV2Router internal uniswapV2Router;
    IUniswapV2Factory internal uniswapV2Factory;
    ICamelotV2Router internal camelotRouter;
    ICamelotFactory internal camelotFactory;

    /* ---------------------------------------------------------------------- */
    /*                              Setup Functions                           */
    /* ---------------------------------------------------------------------- */

    function _loadConfig() internal {
        // Use SENDER env var if set (from shell script orchestration with --sender).
        // Fall back to tx.origin so these scripts remain composable from a top-level
        // script orchestrator while still matching the CLI-selected sender in direct `forge script` runs.
        try vm.envAddress("SENDER") returns (address sender) {
            if (sender != address(0)) {
                deployer = sender;
            } else {
                deployer = tx.origin;
            }
        } catch {
            deployer = tx.origin;
        }

        // Keep the private key optional: it's only needed when running with `--private-key`.
        // When running with `--unlocked`, there may be no PRIVATE_KEY env var.
        try vm.envUint("PRIVATE_KEY") returns (uint256 envKey) {
            privateKey = envKey;
        } catch {
            privateKey = 0;
        }

        try vm.envAddress("OWNER") returns (address envOwner) {
            owner = envOwner;
        } catch {
            owner = deployer;
        }
    }

    function _bindBaseForkAddrs() internal {
        string memory profile = _networkProfile();

        if (keccak256(bytes(profile)) == keccak256(bytes("base_sepolia"))) {
            permit2 = IPermit2(_envOrDefaultAddress("PERMIT2_ADDRESS", BASE_SEPOLIA.PERMIT2));
            weth = IWETH(_envOrDefaultAddress("WETH9_ADDRESS", BASE_SEPOLIA.WETH9));
            balancerV3Vault = IBalancerV3Vault(_envOrDefaultAddress("BALANCER_V3_VAULT_ADDRESS", _boundBalancerVault()));
            balancerV3Router = IBalancerV3Router(_envOrDefaultAddress("BALANCER_V3_ROUTER_ADDRESS", _boundBalancerRouter()));
            aerodromeRouter = IAerodromeRouter(_envOrDefaultAddress("AERODROME_ROUTER_ADDRESS", _boundAerodromeRouter()));
            aerodromePoolFactory =
                IAerodromePoolFactory(_envOrDefaultAddress("AERODROME_POOL_FACTORY_ADDRESS", _boundAerodromeFactory()));
            uniswapV2Router = IUniswapV2Router(_envOrDefaultAddress("UNISWAP_V2_ROUTER_ADDRESS", _boundUniswapV2Router()));
            uniswapV2Factory =
                IUniswapV2Factory(_envOrDefaultAddress("UNISWAP_V2_FACTORY_ADDRESS", _boundUniswapV2Factory()));
        } else {
            permit2 = IPermit2(BASE_MAIN.PERMIT2);
            weth = IWETH(BASE_MAIN.WETH9);
            balancerV3Vault = IBalancerV3Vault(_boundBalancerVault());
            balancerV3Router = IBalancerV3Router(_boundBalancerRouter());

            aerodromeRouter = IAerodromeRouter(BASE_MAIN.AERODROME_ROUTER);
            aerodromePoolFactory = IAerodromePoolFactory(BASE_MAIN.AERODROME_POOL_FACTORY);

            uniswapV2Router = IUniswapV2Router(BASE_MAIN.UNISWAP_V2_ROUTER);
            uniswapV2Factory = IUniswapV2Factory(BASE_MAIN.UNISWAP_V2_FACTORY);
        }

        // Camelot optional (not on Base)
        try vm.envAddress("CAMELOT_V2_ROUTER") returns (address router) {
            camelotRouter = ICamelotV2Router(router);
        } catch {
            camelotRouter = ICamelotV2Router(address(0));
        }
        try vm.envAddress("CAMELOT_V2_FACTORY") returns (address factory) {
            camelotFactory = ICamelotFactory(factory);
        } catch {
            camelotFactory = ICamelotFactory(address(0));
        }
    }

    function _boundBalancerVault() internal view returns (address balancerVaultAddr) {
        (address overrideAddr, bool exists) = _readAddressSafe(BALANCER_CORE_FILE, "balancerV3Vault");
        if (exists && overrideAddr != address(0)) {
            return overrideAddr;
        }
        return BASE_MAIN.BALANCER_V3_VAULT;
    }

    function _boundUniswapV2Router() internal view returns (address uniswapRouterAddr) {
        (address overrideAddr, bool exists) = _readAddressSafe(UNISWAP_V2_CORE_FILE, "uniswapV2Router");
        if (exists && overrideAddr != address(0)) {
            return overrideAddr;
        }
        return BASE_MAIN.UNISWAP_V2_ROUTER;
    }

    function _boundUniswapV2Factory() internal view returns (address uniswapFactoryAddr) {
        (address overrideAddr, bool exists) = _readAddressSafe(UNISWAP_V2_CORE_FILE, "uniswapV2Factory");
        if (exists && overrideAddr != address(0)) {
            return overrideAddr;
        }
        return BASE_MAIN.UNISWAP_V2_FACTORY;
    }

    function _boundBalancerRouter() internal view returns (address balancerRouterAddr) {
        (address overrideAddr, bool exists) = _readAddressSafe(BALANCER_CORE_FILE, "balancerV3Router");
        if (exists && overrideAddr != address(0)) {
            return overrideAddr;
        }
        return BASE_MAIN.BALANCER_V3_ROUTER;
    }

    function _boundAerodromeRouter() internal view returns (address aerodromeRouterAddr) {
        (address overrideAddr, bool exists) = _readAddressSafe(AERODROME_CORE_FILE, "aerodromeRouter");
        if (exists && overrideAddr != address(0)) {
            return overrideAddr;
        }
        return BASE_MAIN.AERODROME_ROUTER;
    }

    function _boundAerodromeFactory() internal view returns (address aerodromeFactoryAddr) {
        (address overrideAddr, bool exists) = _readAddressSafe(AERODROME_CORE_FILE, "aerodromeFactory");
        if (exists && overrideAddr != address(0)) {
            return overrideAddr;
        }
        return BASE_MAIN.AERODROME_POOL_FACTORY;
    }

    function _validateForkIsBaseMainnet() internal view {
        require(address(permit2).code.length > 0, "Permit2 has no code (fork not Base?)");
        require(address(weth).code.length > 0, "WETH9 has no code (fork not Base?)");
        require(address(balancerV3Vault).code.length > 0, "Balancer V3 Vault has no code");
        require(address(aerodromeRouter).code.length > 0, "Aerodrome router has no code (fork not Base?)");
        require(address(aerodromePoolFactory).code.length > 0, "Aerodrome pool factory has no code (fork not Base?)");
        require(address(uniswapV2Router).code.length > 0, "UniswapV2 router has no code (fork not Base?)");
        require(address(uniswapV2Factory).code.length > 0, "UniswapV2 factory has no code (fork not Base?)");
    }

    function _setup() internal {
        _loadConfig();
        _bindBaseForkAddrs();
        _validateForkIsBaseMainnet();
    }

    /* ---------------------------------------------------------------------- */
    /*                            JSON Read Functions                         */
    /* ---------------------------------------------------------------------- */

    function _readAddress(string memory file, string memory key) internal view returns (address) {
        string memory path = string.concat(_outDir(), "/", file);
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", key));
    }

    function _readAddressSafe(string memory file, string memory key) internal view returns (address addr, bool exists) {
        string memory path = string.concat(_outDir(), "/", file);
        try vm.readFile(path) returns (string memory json) {
            try vm.parseJsonAddress(json, string.concat(".", key)) returns (address parsed) {
                return (parsed, true);
            } catch {
                return (address(0), false);
            }
        } catch {
            return (address(0), false);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           JSON Write Functions                         */
    /* ---------------------------------------------------------------------- */

    function _ensureOutDir() internal {
        vm.createDir(_outDir(), true);
    }

    function _writeJson(string memory json, string memory filename) internal {
        _ensureOutDir();
        vm.writeJson(json, string.concat(_outDir(), "/", filename));
    }

    /* ---------------------------------------------------------------------- */
    /*                              Logging                                   */
    /* ---------------------------------------------------------------------- */

    function _logHeader(string memory stageName) internal pure {
        console2.log("========================================");
        console2.log(stageName);
        console2.log("========================================");
    }

    function _logAddress(string memory name, address addr) internal pure {
        console2.log(name, addr);
    }

    function _logComplete(string memory stageName) internal pure {
        console2.log("");
        console2.log(stageName, "complete!");
        console2.log("========================================");
    }
}
