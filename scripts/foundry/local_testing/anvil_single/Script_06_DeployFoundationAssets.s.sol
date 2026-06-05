// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {LocalTestingDeploymentBase} from "../shared/LocalTestingDeploymentBase.sol";
import {ManifestEntry} from "../shared/ManifestEntry.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IERC20PermitDFPkg, ERC20PermitDFPkg} from "@crane/contracts/tokens/ERC20/ERC20PermitDFPkg.sol";
import {IERC20MintBurnOwnableOperableDFPkg, ERC20MintBurnOwnableOperableDFPkg} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";
import {ERC20MinterFacadeFacetDFPkg, IERC20MinterFacadeFacetDFPkg} from "@crane/contracts/tokens/ERC20/ERC20MinterFacadeFacetDFPkg.sol";

/// @title Script_06_DeployFoundationAssets
/// @notice Deploys reusable local testing assets including test tokens, a minter facade, and the RICH fixture token
contract Script_06_DeployFoundationAssets is LocalTestingDeploymentBase {
    using BetterEfficientHashLib for bytes;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant ARTIFACT_FILE = "06_foundation_assets.json";
    uint256 internal constant RICH_TOTAL_SUPPLY = 1_000_000_000e18;

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
    IERC20MinterFacade private erc20MinterFacade;

    IERC20PermitDFPkg private richTokenPkg;
    address private richToken;

    function run() external {
        _loadConfig();
        _loadCraneFoundation();

        _logHeader("Stage 06: Deploy Foundation Assets");

        if (_loadExistingAssets()) {
            _exportJson();
            _exportFragments();
            _logResults();
            return;
        }

        vm.startBroadcast();

        _deployTestTokens();
        _deployRichToken();

        vm.stopBroadcast();

        _exportJson();
        _exportFragments();
        _logResults();
    }

    function _loadCraneFoundation() internal {
        address create3FactoryAddr = _readAddress(CRANE_FOUNDATION_FILE, "create3Factory");
        address diamondPackageFactoryAddr = _readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory");

        require(create3FactoryAddr != address(0), "Create3Factory not found - run Script_01 first");
        require(diamondPackageFactoryAddr != address(0), "DiamondPackageFactory not found - run Script_01 first");

        create3Factory = ICreate3FactoryProxy(create3FactoryAddr);
        diamondPackageFactory = IDiamondPackageCallBackFactory(diamondPackageFactoryAddr);

        erc20Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc20Facet"));
        erc2612Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc5267Facet"));
        multiStepOwnableFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiStepOwnableFacet"));
        operableFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "operableFacet"));
    }

    function _loadExistingAssets() internal returns (bool) {
        (address tokenA, bool hasA) = _readAddressSafe(ARTIFACT_FILE, "testTokenA");
        (address tokenB, bool hasB) = _readAddressSafe(ARTIFACT_FILE, "testTokenB");
        (address tokenC, bool hasC) = _readAddressSafe(ARTIFACT_FILE, "testTokenC");
        (address facade, bool hasFacade) = _readAddressSafe(ARTIFACT_FILE, "erc20MinterFacade");
        (address richTokenPkgAddr, bool hasRichPkg) = _readAddressSafe(ARTIFACT_FILE, "richTokenPkg");
        (address richTokenAddr, bool hasRichToken) = _readAddressSafe(ARTIFACT_FILE, "richToken");

        bool hasRequired = hasA && hasB && hasC && hasFacade && hasRichPkg && hasRichToken;
        if (!hasRequired) {
            return false;
        }

        if (
            tokenA.code.length == 0 || tokenB.code.length == 0 || tokenC.code.length == 0 || facade.code.length == 0
                || richTokenPkgAddr.code.length == 0 || richTokenAddr.code.length == 0
        ) {
            return false;
        }

        ttA = IERC20MintBurn(tokenA);
        ttB = IERC20MintBurn(tokenB);
        ttC = IERC20MintBurn(tokenC);
        erc20MinterFacade = IERC20MinterFacade(facade);
        richTokenPkg = IERC20PermitDFPkg(richTokenPkgAddr);
        richToken = richTokenAddr;
        return true;
    }

    function _deployTestTokens() internal {
        IFacet mintBurnOwnableFacet = create3Factory.deployFacet(
            type(ERC20MintBurnOwnableFacet).creationCode,
            abi.encode(type(ERC20MintBurnOwnableFacet).name, "LocalTesting")._hash()
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
                    abi.encode(type(ERC20MintBurnOwnableOperableDFPkg).name, "LocalTesting")._hash()
                )
            )
        );

        ttA = IERC20MintBurn(tokenPkg.deployToken("Test Token A", "TTA", 18, owner, keccak256("LocalTestingTokenA")));
        ttB = IERC20MintBurn(tokenPkg.deployToken("Test Token B", "TTB", 18, owner, keccak256("LocalTestingTokenB")));
        ttC = IERC20MintBurn(tokenPkg.deployToken("Test Token C", "TTC", 18, owner, keccak256("LocalTestingTokenC")));

        _deployAndAuthorizeERC20MinterFacade();
    }

    function _deployAndAuthorizeERC20MinterFacade() internal {
        IERC20MinterFacadeFacetDFPkg facadePkg = IERC20MinterFacadeFacetDFPkg(
            address(
                create3Factory.deployPackage(
                    type(ERC20MinterFacadeFacetDFPkg).creationCode,
                    abi.encode(type(ERC20MinterFacadeFacetDFPkg).name, "LocalTesting")._hash()
                )
            )
        );

        IERC20MinterFacadeFacetDFPkg.PkgArgs memory pkgArgs = IERC20MinterFacadeFacetDFPkg.PkgArgs({
            maxMintAmount: 10_000_000e18,
            minMintInterval: 0
        });

        erc20MinterFacade = IERC20MinterFacade(diamondPackageFactory.deploy(facadePkg, abi.encode(pkgArgs)));

        IOperable(address(ttA)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
        IOperable(address(ttB)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
        IOperable(address(ttC)).setOperatorFor(IERC20MintBurn.mint.selector, address(erc20MinterFacade), true);
    }

    function _deployRichToken() internal {
        richTokenPkg = IERC20PermitDFPkg(
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
                    abi.encode(type(ERC20PermitDFPkg).name, "LocalTestingRich")._hash()
                )
            )
        );

        richToken = diamondPackageFactory.deploy(
            IDiamondFactoryPackage(address(richTokenPkg)),
            abi.encode(
                IERC20PermitDFPkg.PkgArgs({
                    name: "Rich Token",
                    symbol: "RICH",
                    decimals: 18,
                    totalSupply: RICH_TOTAL_SUPPLY,
                    recipient: owner,
                    optionalSalt: keccak256("LocalTestingRichToken")
                })
            )
        );
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("foundationAssets", "testTokenA", address(ttA));
        json = vm.serializeAddress("foundationAssets", "testTokenB", address(ttB));
        json = vm.serializeAddress("foundationAssets", "testTokenC", address(ttC));
        json = vm.serializeAddress("foundationAssets", "erc20MinterFacade", address(erc20MinterFacade));
        json = vm.serializeAddress("foundationAssets", "richTokenPkg", address(richTokenPkg));
        json = vm.serializeAddress("foundationAssets", "richToken", richToken);
        json = vm.serializeAddress("foundationAssets", "owner", owner);
        json = vm.serializeAddress("foundationAssets", "deployer", deployer);
        json = vm.serializeUint("foundationAssets", "chainId", block.chainid);
        json = vm.serializeString("foundationAssets", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _exportFragments() internal {
        _writeTokenFragment("tta", address(ttA), "Test Token A", "TTA", "testToken");
        _writeTokenFragment("ttb", address(ttB), "Test Token B", "TTB", "testToken");
        _writeTokenFragment("ttc", address(ttC), "Test Token C", "TTC", "testToken");
        _writeTokenFragment("rich", richToken, "Rich Token", "RICH", "");
    }

    function _writeTokenFragment(
        string memory key,
        address tokenAddr,
        string memory name,
        string memory symbol,
        string memory extraTag
    ) internal {
        if (tokenAddr == address(0)) return;

        uint256 tagCount = bytes(extraTag).length > 0 ? 1 : 0;
        string[] memory tags = new string[](tagCount);
        if (tagCount == 1) tags[0] = extraTag;

        ManifestEntry memory entry = ManifestEntry({
            chainId: block.chainid,
            addr: tokenAddr,
            name: name,
            symbol: symbol,
            decimals: 18,
            tags: tags
        });
        _writeManifestEntry("tokens", key, entry);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("Test Token A:", address(ttA));
        _logAddress("Test Token B:", address(ttB));
        _logAddress("Test Token C:", address(ttC));
        _logAddress("ERC20 Minter Facade:", address(erc20MinterFacade));
        _logAddress("RICH Token Pkg:", address(richTokenPkg));
        _logAddress("RICH Token:", richToken);
        _logUint("ChainId:", block.chainid);
        _logComplete("Stage 06");
    }
}