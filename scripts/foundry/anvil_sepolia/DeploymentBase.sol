// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";
import {ETHEREUM_MAIN} from "@crane/contracts/constants/networks/ETHEREUM_MAIN.sol";
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

abstract contract DeploymentBase is Script {
    string internal constant OUT_DIR = "deployments/anvil_sepolia";

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

        return "ethereum_sepolia";
    }

    function _envOrDefaultAddress(string memory key, address defaultAddress) internal view returns (address resolved) {
        try vm.envAddress(key) returns (address envAddress_) {
            return envAddress_;
        } catch {
            return defaultAddress;
        }
    }

    uint256 internal privateKey;
    address internal deployer;
    address internal owner;

    // Sepolia protocol bindings - using Balancer's WETH for consistency
    IPermit2 internal permit2;
    IWETH internal weth;
    IBalancerV3Vault internal balancerV3Vault;
    IBalancerV3Router internal balancerV3Router;
    
    // Our deployed instances (Uniswap V2, Aerodrome - deployed by us)
    IAerodromeRouter internal aerodromeRouter;
    IAerodromePoolFactory internal aerodromePoolFactory;
    IUniswapV2Router internal uniswapV2Router;
    IUniswapV2Factory internal uniswapV2Factory;

    function _loadConfig() internal {
        try vm.envAddress("SENDER") returns (address sender) {
            if (sender != address(0)) {
                deployer = sender;
            } else {
                deployer = tx.origin;
            }
        } catch {
            deployer = tx.origin;
        }

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

    function _bindSepoliaForkAddrs() internal {
        string memory profile = _networkProfile();

        if (keccak256(bytes(profile)) == keccak256(bytes("ethereum_main"))) {
            permit2 = IPermit2(_envOrDefaultAddress("PERMIT2_ADDRESS", ETHEREUM_MAIN.PERMIT2));
            weth = IWETH(_envOrDefaultAddress("WETH9_ADDRESS", ETHEREUM_MAIN.WETH9));
            balancerV3Vault = IBalancerV3Vault(
                _envOrDefaultAddress("BALANCER_V3_VAULT_ADDRESS", ETHEREUM_MAIN.BALANCER_V3_VAULT)
            );
            balancerV3Router = IBalancerV3Router(
                _envOrDefaultAddress("BALANCER_V3_ROUTER_ADDRESS", ETHEREUM_MAIN.BALANCER_V3_ROUTER)
            );
            return;
        }

        permit2 = IPermit2(_envOrDefaultAddress("PERMIT2_ADDRESS", ETHEREUM_SEPOLIA.PERMIT2));

        // Use Balancer's WETH for consistency across all DEX integrations.
        weth = IWETH(_envOrDefaultAddress("WETH9_ADDRESS", ETHEREUM_SEPOLIA.BALANCER_V3_WETH9));

        // Balancer V3 - use existing Sepolia deployment.
        balancerV3Vault = IBalancerV3Vault(
            _envOrDefaultAddress("BALANCER_V3_VAULT_ADDRESS", ETHEREUM_SEPOLIA.BALANCER_V3_VAULT)
        );
        balancerV3Router = IBalancerV3Router(
            _envOrDefaultAddress("BALANCER_V3_ROUTER_ADDRESS", ETHEREUM_SEPOLIA.BALANCER_V3_ROUTER)
        );

        // Uniswap V2 - will be set by Stage 5 deployment (our own instance with Balancer's WETH)
        // Aerodrome - will be set by Stage 6 deployment (deployed fresh since not on Sepolia)
    }

    function _setOurUniswapV2(address router, address factory) internal {
        uniswapV2Router = IUniswapV2Router(router);
        uniswapV2Factory = IUniswapV2Factory(factory);
    }

    function _setOurAerodrome(address router, address factory) internal {
        aerodromeRouter = IAerodromeRouter(router);
        aerodromePoolFactory = IAerodromePoolFactory(factory);
    }

    function _validateForkIsSepolia() internal view {
        require(address(permit2).code.length > 0, "Permit2 has no code (fork not Sepolia?)");
        require(address(weth).code.length > 0, "WETH9 has no code (fork not Sepolia?)");
        require(address(balancerV3Vault).code.length > 0, "Balancer V3 Vault has no code (fork not Sepolia?)");
    }

    function _setup() internal {
        _loadConfig();
        _bindSepoliaForkAddrs();
        _validateForkIsSepolia();
    }

    function _readAddress(string memory file, string memory key) internal view returns (address) {
        string memory path = string.concat(_outDir(), "/", file);
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", key));
    }

    /// @dev Read address with fallback - tries primary file, then fallback file
    function _readAddressWithFallback(string memory primaryFile, string memory key, string memory fallbackFile)
        internal
        view
        returns (address)
    {
        (address addr,) = _readAddressSafe(primaryFile, key);
        if (addr == address(0)) {
            (addr,) = _readAddressSafe(fallbackFile, key);
        }
        return addr;
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

    function _ensureOutDir() internal {
        vm.createDir(_outDir(), true);
    }

    function _writeJson(string memory json, string memory filename) internal {
        _ensureOutDir();
        vm.writeJson(json, string.concat(_outDir(), "/", filename));
    }

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
