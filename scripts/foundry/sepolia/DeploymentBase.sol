// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";

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
    string internal constant OUT_DIR = "deployments/sepolia";

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
        try vm.envUint("PRIVATE_KEY") returns (uint256 envKey) {
            privateKey = envKey;
            deployer = vm.addr(envKey);
        } catch {
            privateKey = 0;
            try vm.envAddress("DEPLOYER") returns (address envDeployer) {
                deployer = envDeployer;
            } catch {
                try vm.envAddress("SENDER") returns (address envSender) {
                    deployer = envSender;
                } catch {
                    deployer = msg.sender;
                }
            }
        }

        try vm.envAddress("OWNER") returns (address envOwner) {
            owner = envOwner;
        } catch {
            owner = deployer;
        }
    }

    function _bindSepoliaAddrs() internal {
        permit2 = IPermit2(ETHEREUM_SEPOLIA.PERMIT2);
        
        // Use Balancer's WETH for consistency across all DEX integrations
        weth = IWETH(ETHEREUM_SEPOLIA.BALANCER_V3_WETH9);
        
        // Balancer V3 - use existing Sepolia deployment
        balancerV3Vault = IBalancerV3Vault(ETHEREUM_SEPOLIA.BALANCER_V3_VAULT);
        balancerV3Router = IBalancerV3Router(ETHEREUM_SEPOLIA.BALANCER_V3_ROUTER);

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

    function _validateSepolia() internal view {
        require(block.chainid == 11155111, "Not Ethereum Sepolia");
        require(address(permit2).code.length > 0, "Permit2 has no code on Sepolia");
        require(address(weth).code.length > 0, "WETH9 has no code on Sepolia");
        require(address(balancerV3Vault).code.length > 0, "Balancer V3 Vault has no code on Sepolia");
    }

    function _setup() internal {
        _loadConfig();
        _bindSepoliaAddrs();
        _validateSepolia();
    }

    function _readAddress(string memory file, string memory key) internal view returns (address) {
        string memory path = string.concat(OUT_DIR, "/", file);
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
        string memory path = string.concat(OUT_DIR, "/", file);
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
        vm.createDir(OUT_DIR, true);
    }

    function _writeJson(string memory json, string memory filename) internal {
        _ensureOutDir();
        vm.writeJson(json, string.concat(OUT_DIR, "/", filename));
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
