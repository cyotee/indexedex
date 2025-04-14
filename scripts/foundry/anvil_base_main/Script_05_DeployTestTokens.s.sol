// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IERC20MintBurnOwnableOperableDFPkg, ERC20MintBurnOwnableOperableDFPkg} from
    "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";
import {ERC20MinterFacadeFacetDFPkg, IERC20MinterFacadeFacetDFPkg} from
    "@crane/contracts/tokens/ERC20/ERC20MinterFacadeFacetDFPkg.sol";

/// @title Script_05_DeployTestTokens
/// @notice Deploys test tokens (TTA, TTB, TTC) for testing
/// @dev Run: forge script scripts/foundry/anvil_base_main/Script_05_DeployTestTokens.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
contract Script_05_DeployTestTokens is DeploymentBase {
    using BetterEfficientHashLib for bytes;

    // From previous deployments
    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    // Shared facets
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiStepOwnableFacet;
    IFacet private operableFacet;

    // Deployed tokens
    IERC20MintBurn private ttA;
    IERC20MintBurn private ttB;
    IERC20MintBurn private ttC;

    // Deployed facade
    IERC20MinterFacade private erc20MinterFacade;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 5: Deploy Test Tokens");

        vm.startBroadcast();

        _deployTestTokens();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        // Load factories
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));

        // Load shared facets
        erc20Facet = IFacet(_readAddress("02_shared_facets.json", "erc20Facet"));
        erc2612Facet = IFacet(_readAddress("02_shared_facets.json", "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress("02_shared_facets.json", "erc5267Facet"));
        multiStepOwnableFacet = IFacet(_readAddress("02_shared_facets.json", "multiStepOwnableFacet"));
        operableFacet = IFacet(_readAddress("02_shared_facets.json", "operableFacet"));

        require(address(create3Factory) != address(0), "Create3Factory not found");
    }

    function _deployTestTokens() internal {
        // Idempotency: if we already have deployed artifacts, reuse them.
        // This avoids CREATE3/CREATE2 collisions when re-running Stage 5 against the same Anvil instance.
        if (_loadExistingArtifacts()) {
            _deployAndAuthorizeERC20MinterFacade();
            return;
        }

        // Deploy the ERC20MintBurnOwnableFacet (not a shared facet)
        IFacet mintBurnOwnableFacet = create3Factory.deployFacet(
            type(ERC20MintBurnOwnableFacet).creationCode,
            abi.encode(type(ERC20MintBurnOwnableFacet).name)._hash()
        );

        // Build package init using shared facets
        IERC20MintBurnOwnableOperableDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = erc20Facet;
        pkgInit.erc5267Facet = erc5267Facet;
        pkgInit.erc2612Facet = erc2612Facet;
        pkgInit.erc20MintBurnOwnableFacet = mintBurnOwnableFacet;
        pkgInit.mutiStepOwnableFacet = multiStepOwnableFacet;
        pkgInit.operableFacet = operableFacet;
        pkgInit.diamondFactory = diamondPackageFactory;

        IERC20MintBurnOwnableOperableDFPkg tokenPkg = IERC20MintBurnOwnableOperableDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20MintBurnOwnableOperableDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(ERC20MintBurnOwnableOperableDFPkg).name)._hash()
                )
            )
        );

        bytes32 saltA = keccak256(abi.encodePacked("TestTokenA"));
        bytes32 saltB = keccak256(abi.encodePacked("TestTokenB"));
        bytes32 saltC = keccak256(abi.encodePacked("TestTokenC"));

        ttA = IERC20MintBurn(tokenPkg.deployToken("Test Token A", "TTA", 18, owner, saltA));
        ttB = IERC20MintBurn(tokenPkg.deployToken("Test Token B", "TTB", 18, owner, saltB));
        ttC = IERC20MintBurn(tokenPkg.deployToken("Test Token C", "TTC", 18, owner, saltC));

        _deployAndAuthorizeERC20MinterFacade();
    }

    function _loadExistingArtifacts() internal returns (bool loaded) {
        // Load token addresses (and optionally facade) from a prior Stage 5 run.
        // If any token is missing or has no code, we treat this stage as not-yet-deployed.
        (address tokenA, bool hasA) = _readAddressSafe("05_test_tokens.json", "testTokenA");
        (address tokenB, bool hasB) = _readAddressSafe("05_test_tokens.json", "testTokenB");
        (address tokenC, bool hasC) = _readAddressSafe("05_test_tokens.json", "testTokenC");

        if (!hasA || !hasB || !hasC) {
            return false;
        }
        if (tokenA.code.length == 0 || tokenB.code.length == 0 || tokenC.code.length == 0) {
            return false;
        }

        ttA = IERC20MintBurn(tokenA);
        ttB = IERC20MintBurn(tokenB);
        ttC = IERC20MintBurn(tokenC);

        // Facade is optional in older artifacts.
        (address facade, bool hasFacade) = _readAddressSafe("05_test_tokens.json", "erc20MinterFacade");
        if (hasFacade && facade.code.length > 0) {
            erc20MinterFacade = IERC20MinterFacade(facade);
        }

        return true;
    }

    function _deployAndAuthorizeERC20MinterFacade() internal {
        // If the facade already exists (loaded from prior artifacts), just (re)authorize it.
        if (address(erc20MinterFacade) != address(0) && address(erc20MinterFacade).code.length > 0) {
            _authorizeFacadeOnTokens();
            return;
        }

        // Deploy the package
        IERC20MinterFacadeFacetDFPkg facadePkg = IERC20MinterFacadeFacetDFPkg(
            address(
                create3Factory.deployPackage(
                    type(ERC20MinterFacadeFacetDFPkg).creationCode,
                    abi.encode(type(ERC20MinterFacadeFacetDFPkg).name)._hash()
                )
            )
        );

        // Deploy the proxy instance
        IERC20MinterFacadeFacetDFPkg.PkgArgs memory pkgArgs = IERC20MinterFacadeFacetDFPkg.PkgArgs({
            // Allow Stage 10+ scripts to mint liquidity amounts via the facade.
            maxMintAmount: 10_000_000e18,
            // No minimum interval in the local demo env.
            minMintInterval: 0
        });

        erc20MinterFacade = IERC20MinterFacade(diamondPackageFactory.deploy(facadePkg, abi.encode(pkgArgs)));

        _authorizeFacadeOnTokens();
    }

    function _authorizeFacadeOnTokens() internal {
        // Authorize the facade to call mint() on each test token via IOperable.
        // (These tokens enforce mint access via onlyOwnerOrOperator.)
        IOperable(address(ttA)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
        IOperable(address(ttB)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
        IOperable(address(ttC)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("tokens", "testTokenA", address(ttA));
        json = vm.serializeAddress("tokens", "testTokenB", address(ttB));
        json = vm.serializeAddress("tokens", "testTokenC", address(ttC));
        json = vm.serializeAddress("tokens", "erc20MinterFacade", address(erc20MinterFacade));
        _writeJson(json, "05_test_tokens.json");
    }

    function _logResults() internal view {
        _logAddress("Test Token A (TTA):", address(ttA));
        _logAddress("Test Token B (TTB):", address(ttB));
        _logAddress("Test Token C (TTC):", address(ttC));
        _logAddress("ERC20 Minter Facade:", address(erc20MinterFacade));
        _logComplete("Stage 5");
    }
}
