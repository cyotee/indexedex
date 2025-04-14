// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {ETHEREUM_MAIN} from "@crane/contracts/constants/networks/ETHEREUM_MAIN.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ERC20Facet} from "@crane/contracts/tokens/ERC20/ERC20Facet.sol";
import {ERC2612Facet} from "@crane/contracts/tokens/ERC2612/ERC2612Facet.sol";
import {ERC5267Facet} from "@crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

contract Script_DeployRichToken is Script {
    using BetterEfficientHashLib for bytes;

    string internal constant OUT_DIR = "deployments/ethereum_main";
    string internal constant TOKEN_NAME = "RICH";
    string internal constant TOKEN_SYMBOL = "RICH";
    uint8 internal constant TOKEN_DECIMALS = 19;
    uint256 internal constant TOKEN_TOTAL_SUPPLY = 1_000_000_000e18;

    uint256 private privateKey;
    address private deployer;
    address private owner;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IERC20PermitDFPkg private erc20PermitPkg;
    IERC20 private richToken;

    function run() external {
        _loadConfig();
        _validateConfig();

        _startBroadcast();

        (create3Factory, diamondPackageFactory) = InitDevService.initEnv(owner);
        vm.label(address(create3Factory), "Create3Factory");
        vm.label(address(diamondPackageFactory), "DiamondPackageCallBackFactory");

        _deployFacets();
        _deployPackage();
        _deployToken();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

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

    function _validateConfig() internal view {
        require(block.chainid == ETHEREUM_MAIN.CHAIN_ID, "Not Ethereum mainnet (chainid 1)");
        require(deployer != address(0), "Deployer not configured");
        require(owner != address(0), "Owner not configured");
    }

    function _startBroadcast() internal {
        if (privateKey != 0) {
            vm.startBroadcast(privateKey);
        } else {
            vm.startBroadcast(deployer);
        }
    }

    function _deployFacets() internal {
        erc20Facet = IFacet(
            create3Factory.deployFacet(type(ERC20Facet).creationCode, abi.encode(type(ERC20Facet).name)._hash())
        );
        erc2612Facet = IFacet(
            create3Factory.deployFacet(type(ERC2612Facet).creationCode, abi.encode(type(ERC2612Facet).name)._hash())
        );
        erc5267Facet = IFacet(
            create3Factory.deployFacet(type(ERC5267Facet).creationCode, abi.encode(type(ERC5267Facet).name)._hash())
        );

        vm.label(address(erc20Facet), type(ERC20Facet).name);
        vm.label(address(erc2612Facet), type(ERC2612Facet).name);
        vm.label(address(erc5267Facet), type(ERC5267Facet).name);
    }

    function _deployPackage() internal {
        erc20PermitPkg = IERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(
                        IERC20PermitDFPkg.PkgInit({
                            erc20Facet: erc20Facet,
                            erc5267Facet: erc5267Facet,
                            erc2612Facet: erc2612Facet
                        })
                    ),
                    abi.encode(type(ERC20PermitDFPkg).name)._hash()
                )
            )
        );

        vm.label(address(erc20PermitPkg), type(ERC20PermitDFPkg).name);
    }

    function _deployToken() internal {
        richToken = IERC20(
            diamondPackageFactory.deploy(
                IDiamondFactoryPackage(address(erc20PermitPkg)),
                abi.encode(
                    IERC20PermitDFPkg.PkgArgs({
                        name: TOKEN_NAME,
                        symbol: TOKEN_SYMBOL,
                        decimals: TOKEN_DECIMALS,
                        totalSupply: TOKEN_TOTAL_SUPPLY,
                        recipient: deployer,
                        optionalSalt: bytes32(0)
                    })
                )
            )
        );

        vm.label(address(richToken), TOKEN_SYMBOL);
    }

    function _exportJson() internal {
        vm.createDir(OUT_DIR, true);

        string memory json;
        json = vm.serializeUint("", "chainId", block.chainid);
        json = vm.serializeAddress("", "deployer", deployer);
        json = vm.serializeAddress("", "owner", owner);
        json = vm.serializeAddress("", "create3Factory", address(create3Factory));
        json = vm.serializeAddress("", "diamondPackageFactory", address(diamondPackageFactory));
        json = vm.serializeAddress("", "erc20Facet", address(erc20Facet));
        json = vm.serializeAddress("", "erc2612Facet", address(erc2612Facet));
        json = vm.serializeAddress("", "erc5267Facet", address(erc5267Facet));
        json = vm.serializeAddress("", "erc20PermitPkg", address(erc20PermitPkg));
        json = vm.serializeAddress("", "richToken", address(richToken));
        json = vm.serializeString("", "name", TOKEN_NAME);
        json = vm.serializeString("", "symbol", TOKEN_SYMBOL);
        json = vm.serializeUint("", "decimals", TOKEN_DECIMALS);
        json = vm.serializeUint("", "totalSupply", TOKEN_TOTAL_SUPPLY);

        vm.writeJson(json, string.concat(OUT_DIR, "/rich_token.json"));
    }

    function _logResults() internal view {
        console2.log("Ethereum mainnet RICH deploy complete");
        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("Create3Factory:", address(create3Factory));
        console2.log("DiamondPackageFactory:", address(diamondPackageFactory));
        console2.log("ERC20Facet:", address(erc20Facet));
        console2.log("ERC2612Facet:", address(erc2612Facet));
        console2.log("ERC5267Facet:", address(erc5267Facet));
        console2.log("ERC20PermitDFPkg:", address(erc20PermitPkg));
        console2.log("RICH token:", address(richToken));
    }
}