// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {ERC20PermitDFPkg, IERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {IERC20MintBurnOwnableOperableDFPkg, ERC20MintBurnOwnableOperableDFPkg} from
    "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";
import {ERC20MinterFacadeFacetDFPkg, IERC20MinterFacadeFacetDFPkg} from
    "@crane/contracts/tokens/ERC20/ERC20MinterFacadeFacetDFPkg.sol";

contract Script_07_DeployTestTokens is DeploymentBase {
    using BetterEfficientHashLib for bytes;

    uint256 private constant RICH_TOTAL_SUPPLY = 1_000_000_000e18;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private multiStepOwnableFacet;
    IFacet private operableFacet;

    IERC20MintBurn private ttA;
    IERC20MintBurn private ttB;
    IERC20MintBurn private ttC;
    IERC20MintBurn private demoWeth;
    IERC20 private richToken;
    IERC20MinterFacade private erc20MinterFacade;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 7: Deploy Test Tokens");

        vm.startBroadcast();

        _deployTestTokens();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));

        erc20Facet = IFacet(_readAddress("02_shared_facets.json", "erc20Facet"));
        erc2612Facet = IFacet(_readAddress("02_shared_facets.json", "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress("02_shared_facets.json", "erc5267Facet"));
        multiStepOwnableFacet = IFacet(_readAddress("02_shared_facets.json", "multiStepOwnableFacet"));
        operableFacet = IFacet(_readAddress("02_shared_facets.json", "operableFacet"));

        require(address(create3Factory) != address(0), "Create3Factory not found");
    }

    function _deployTestTokens() internal {
        if (_loadExistingArtifacts()) {
            _deployAndAuthorizeERC20MinterFacade();
            return;
        }

        IFacet mintBurnOwnableFacet = create3Factory.deployFacet(
            type(ERC20MintBurnOwnableFacet).creationCode,
            abi.encode(type(ERC20MintBurnOwnableFacet).name)._hash()
        );

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
        bytes32 saltDemoWeth = keccak256(abi.encodePacked("DemoWETH"));

        ttA = IERC20MintBurn(tokenPkg.deployToken("Test Token A", "TTA", 18, owner, saltA));
        ttB = IERC20MintBurn(tokenPkg.deployToken("Test Token B", "TTB", 18, owner, saltB));
        ttC = IERC20MintBurn(tokenPkg.deployToken("Test Token C", "TTC", 18, owner, saltC));
        demoWeth = IERC20MintBurn(tokenPkg.deployToken("DemoWETH", "DemoWETH", 18, owner, saltDemoWeth));

        IERC20PermitDFPkg.PkgInit memory richPkgInit =
            IERC20PermitDFPkg.PkgInit({erc20Facet: erc20Facet, erc5267Facet: erc5267Facet, erc2612Facet: erc2612Facet});

        IERC20PermitDFPkg richTokenPkg = IERC20PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20PermitDFPkg).creationCode,
                    abi.encode(richPkgInit),
                    abi.encode(type(ERC20PermitDFPkg).name, "DemoRichToken")._hash()
                )
            )
        );

        IERC20PermitDFPkg.PkgArgs memory richArgs = IERC20PermitDFPkg.PkgArgs({
            name: "Rich Token",
            symbol: "RICH",
            decimals: 18,
            totalSupply: RICH_TOTAL_SUPPLY,
            recipient: owner,
            optionalSalt: keccak256(abi.encodePacked("DemoRichToken"))
        });

        richToken = IERC20(diamondPackageFactory.deploy(IDiamondFactoryPackage(address(richTokenPkg)), abi.encode(richArgs)));

        _deployAndAuthorizeERC20MinterFacade();
    }

    function _loadExistingArtifacts() internal returns (bool loaded) {
        (address tokenA, bool hasA) = _readAddressSafe("07_test_tokens.json", "testTokenA");
        (address tokenB, bool hasB) = _readAddressSafe("07_test_tokens.json", "testTokenB");
        (address tokenC, bool hasC) = _readAddressSafe("07_test_tokens.json", "testTokenC");
        (address demoWethAddr, bool hasDemoWeth) = _readAddressSafe("07_test_tokens.json", "demoWeth");
        (address richTokenAddr, bool hasRich) = _readAddressSafe("07_test_tokens.json", "richToken");

        if (!hasA || !hasB || !hasC || !hasDemoWeth || !hasRich) {
            return false;
        }
        if (
            tokenA.code.length == 0 || tokenB.code.length == 0 || tokenC.code.length == 0
                || demoWethAddr.code.length == 0 || richTokenAddr.code.length == 0
        ) {
            return false;
        }

        ttA = IERC20MintBurn(tokenA);
        ttB = IERC20MintBurn(tokenB);
        ttC = IERC20MintBurn(tokenC);
        demoWeth = IERC20MintBurn(demoWethAddr);
        richToken = IERC20(richTokenAddr);

        (address facade, bool hasFacade) = _readAddressSafe("07_test_tokens.json", "erc20MinterFacade");
        if (hasFacade && facade.code.length > 0) {
            erc20MinterFacade = IERC20MinterFacade(facade);
        }

        return true;
    }

    function _deployAndAuthorizeERC20MinterFacade() internal {
        if (address(erc20MinterFacade) != address(0) && address(erc20MinterFacade).code.length > 0) {
            _authorizeFacadeOnTokens();
            return;
        }

        IERC20MinterFacadeFacetDFPkg facadePkg = IERC20MinterFacadeFacetDFPkg(
            address(
                create3Factory.deployPackage(
                    type(ERC20MinterFacadeFacetDFPkg).creationCode,
                    abi.encode(type(ERC20MinterFacadeFacetDFPkg).name)._hash()
                )
            )
        );

        IERC20MinterFacadeFacetDFPkg.PkgArgs memory pkgArgs = IERC20MinterFacadeFacetDFPkg.PkgArgs({
            maxMintAmount: 10_000_000e18,
            minMintInterval: 0
        });

        erc20MinterFacade = IERC20MinterFacade(diamondPackageFactory.deploy(facadePkg, abi.encode(pkgArgs)));

        _authorizeFacadeOnTokens();
    }

    function _authorizeFacadeOnTokens() internal {
        IOperable(address(ttA)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
        IOperable(address(ttB)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
        IOperable(address(ttC)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
        IOperable(address(demoWeth)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("tokens", "testTokenA", address(ttA));
        json = vm.serializeAddress("tokens", "testTokenB", address(ttB));
        json = vm.serializeAddress("tokens", "testTokenC", address(ttC));
        json = vm.serializeAddress("tokens", "demoWeth", address(demoWeth));
        json = vm.serializeAddress("tokens", "richToken", address(richToken));
        json = vm.serializeAddress("tokens", "erc20MinterFacade", address(erc20MinterFacade));
        _writeJson(json, "07_test_tokens.json");
    }

    function _logResults() internal view {
        _logAddress("Test Token A (TTA):", address(ttA));
        _logAddress("Test Token B (TTB):", address(ttB));
        _logAddress("Test Token C (TTC):", address(ttC));
        _logAddress("DemoWETH:", address(demoWeth));
        _logAddress("RICH:", address(richToken));
        _logAddress("ERC20 Minter Facade:", address(erc20MinterFacade));
        _logComplete("Stage 7");
    }
}
