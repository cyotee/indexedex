// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {FixtureGraph} from "./FixtureGraph.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {
    IERC20MintBurnOwnableOperableDFPkg,
    ERC20MintBurnOwnableOperableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";

/// @title Script_04_DeployTestTokens
/// @notice Deploy TT0…TT7 mintable tokens; mint 1e12 whole units to deployer and UI wallet.
contract Script_04_DeployTestTokens is DeploymentBase {
    using BetterEfficientHashLib for bytes;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant ARTIFACT_FILE = "04_test_tokens.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiStepOwnableFacet;
    IFacet private operableFacet;

    address[8] private tokens;
    IERC20MintBurnOwnableOperableDFPkg private tokenPkg;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        _loadCraneFoundation();
        _logHeader("Stage 04: Deploy Test Tokens TT0-TT7");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        _deployTokens();
        _mintSupplies();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadCraneFoundation() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        diamondPackageFactory =
            IDiamondPackageCallBackFactory(_readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory"));
        erc20Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc20Facet"));
        erc2612Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc5267Facet"));
        multiStepOwnableFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiStepOwnableFacet"));
        operableFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "operableFacet"));
    }

    function _loadExisting() internal returns (bool) {
        for (uint8 i; i < 8; ++i) {
            (address t, bool ok) = _readAddressSafe(ARTIFACT_FILE, FixtureGraph.tokenSymbol(i));
            if (!ok || t.code.length == 0) return false;
            tokens[i] = t;
        }
        return true;
    }

    function _deployTokens() internal {
        IFacet mintBurnOwnableFacet = create3Factory.deployFacet(
            type(ERC20MintBurnOwnableFacet).creationCode,
            abi.encode(type(ERC20MintBurnOwnableFacet).name, "AnvilRobinhood")._hash()
        );

        IERC20MintBurnOwnableOperableDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.erc20MintBurnOwnableFacet = mintBurnOwnableFacet;
        pkgInit.mutiStepOwnableFacet = multiStepOwnableFacet;
        pkgInit.operableFacet = operableFacet;
        pkgInit.diamondFactory = diamondPackageFactory;

        tokenPkg = IERC20MintBurnOwnableOperableDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20MintBurnOwnableOperableDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(ERC20MintBurnOwnableOperableDFPkg).name, "AnvilRobinhood")._hash()
                )
            )
        );

        for (uint8 i; i < 8; ++i) {
            tokens[i] = tokenPkg.deployToken(
                FixtureGraph.tokenName(i), FixtureGraph.tokenSymbol(i), 18, owner, FixtureGraph.tokenSalt(i)
            );
            vm.label(tokens[i], FixtureGraph.tokenSymbol(i));
        }
    }

    function _mintSupplies() internal {
        uint256 amt = FixtureGraph.MINT_AMOUNT;
        for (uint8 i; i < 8; ++i) {
            IERC20MintBurn t = IERC20MintBurn(tokens[i]);
            t.mint(deployer, amt);
            t.mint(uiWallet, amt);
        }
    }

    function _exportJson() internal {
        string memory json;
        for (uint8 i; i < 8; ++i) {
            json = vm.serializeAddress("tokens", FixtureGraph.tokenSymbol(i), tokens[i]);
        }
        json = vm.serializeAddress("tokens", "tt0", tokens[0]);
        json = vm.serializeAddress("tokens", "tt1", tokens[1]);
        json = vm.serializeAddress("tokens", "tt2", tokens[2]);
        json = vm.serializeAddress("tokens", "tt3", tokens[3]);
        json = vm.serializeAddress("tokens", "tt4", tokens[4]);
        json = vm.serializeAddress("tokens", "tt5", tokens[5]);
        json = vm.serializeAddress("tokens", "tt6", tokens[6]);
        json = vm.serializeAddress("tokens", "tt7", tokens[7]);
        json = vm.serializeAddress("tokens", "tokenPkg", address(tokenPkg));
        json = vm.serializeAddress("tokens", "deployer", deployer);
        json = vm.serializeAddress("tokens", "uiWallet", uiWallet);
        json = vm.serializeUint("tokens", "mintAmount", FixtureGraph.MINT_AMOUNT);
        json = vm.serializeUint("tokens", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        for (uint8 i; i < 8; ++i) {
            _logAddress(FixtureGraph.tokenSymbol(i), tokens[i]);
        }
        _logComplete("Stage 04");
    }
}
