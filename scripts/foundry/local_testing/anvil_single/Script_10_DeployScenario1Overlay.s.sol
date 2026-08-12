// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LocalTestingDeploymentBase} from "../shared/LocalTestingDeploymentBase.sol";
import {ManifestEntry} from "../shared/ManifestEntry.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {WETH9} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETH9.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";

import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";

/// @title Script_10_DeployScenario1Overlay
/// @notice Deploys the minimal Scenario 1 graph: UniV2 TTA/TTB and TTB/WETH pools plus their vaults
contract Script_10_DeployScenario1Overlay is LocalTestingDeploymentBase {
    string internal constant PROTOCOLS_BASE_FILE = "03_protocols_base.json";
    string internal constant FOUNDATION_PACKAGES_FILE = "05_foundation_packages.json";
    string internal constant FOUNDATION_ASSETS_FILE = "06_foundation_assets.json";
    string internal constant ARTIFACT_FILE = "10_scenario_1.json";

    uint256 internal constant AB_TTA_LIQUIDITY = 1_000 ether;
    uint256 internal constant AB_TTB_LIQUIDITY = 1_000 ether;
    uint256 internal constant BWETH_TTB_LIQUIDITY = 1_000 ether;
    uint256 internal constant BWETH_WETH_LIQUIDITY = 1_000 ether;

    IUniswapV2Factory private uniswapV2Factory;
    IUniswapV2StandardExchangeDFPkg private uniswapV2Pkg;
    IERC20MintBurn private ttA;
    IERC20MintBurn private ttB;
    IERC20MinterFacade private erc20MinterFacade;
    address private localWeth;

    IUniswapV2Pair private abPool;
    IUniswapV2Pair private bWethPool;
    address private abVault;
    address private bWethVault;

    function run() external {
        _loadConfig();
        _loadDependencies();

        _logHeader("Stage 10: Deploy Scenario 1 Overlay");

        if (_loadExistingScenario()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();

        _mintSeedAssets();
        _wrapWeth();
        _approvePkgInputs();
        _deployVaults();

        vm.stopBroadcast();

        _exportJson();
        _exportFragments();
        _logResults();
    }

    function _loadDependencies() internal {
        uniswapV2Factory = IUniswapV2Factory(_readAddress(PROTOCOLS_BASE_FILE, "uniswapV2Factory"));
        localWeth = _readAddress(PROTOCOLS_BASE_FILE, "weth");
        uniswapV2Pkg = IUniswapV2StandardExchangeDFPkg(_readAddress(FOUNDATION_PACKAGES_FILE, "uniswapV2StandardExchangePkg"));
        ttA = IERC20MintBurn(_readAddress(FOUNDATION_ASSETS_FILE, "testTokenA"));
        ttB = IERC20MintBurn(_readAddress(FOUNDATION_ASSETS_FILE, "testTokenB"));
        erc20MinterFacade = IERC20MinterFacade(_readAddress(FOUNDATION_ASSETS_FILE, "erc20MinterFacade"));

        require(address(uniswapV2Factory) != address(0), "UniswapV2Factory not found - run Script_03 first");
        require(localWeth != address(0), "WETH not found - run Script_03 first");
        require(address(uniswapV2Pkg) != address(0), "UniswapV2 pkg not found - run Script_05 first");
        require(address(ttA) != address(0) && address(ttB) != address(0), "Test tokens not found - run Script_06 first");
        require(address(erc20MinterFacade) != address(0), "ERC20 minter facade not found - run Script_06 first");
    }

    function _loadExistingScenario() internal returns (bool) {
        (address abPoolAddr, bool hasAbPool) = _readAddressSafe(ARTIFACT_FILE, "uniV2AbPool");
        (address bWethPoolAddr, bool hasBWethPool) = _readAddressSafe(ARTIFACT_FILE, "uniV2BWethPool");
        (address abVaultAddr, bool hasAbVault) = _readAddressSafe(ARTIFACT_FILE, "uniV2AbVault");
        (address bWethVaultAddr, bool hasBWethVault) = _readAddressSafe(ARTIFACT_FILE, "uniV2BWethVault");

        bool hasRequired = hasAbPool && hasBWethPool && hasAbVault && hasBWethVault;
        if (!hasRequired) {
            return false;
        }

        if (abPoolAddr.code.length == 0 || bWethPoolAddr.code.length == 0 || abVaultAddr.code.length == 0 || bWethVaultAddr.code.length == 0) {
            return false;
        }

        abPool = IUniswapV2Pair(abPoolAddr);
        bWethPool = IUniswapV2Pair(bWethPoolAddr);
        abVault = abVaultAddr;
        bWethVault = bWethVaultAddr;
        return true;
    }

    function _mintSeedAssets() internal {
        erc20MinterFacade.mintToken(ttA, AB_TTA_LIQUIDITY, deployer);
        erc20MinterFacade.mintToken(ttB, AB_TTB_LIQUIDITY + BWETH_TTB_LIQUIDITY, deployer);
    }

    function _wrapWeth() internal {
        WETH9(payable(localWeth)).deposit{value: BWETH_WETH_LIQUIDITY}();
    }

    function _approvePkgInputs() internal {
        IERC20(address(ttA)).approve(address(uniswapV2Pkg), type(uint256).max);
        IERC20(address(ttB)).approve(address(uniswapV2Pkg), type(uint256).max);
        IERC20(localWeth).approve(address(uniswapV2Pkg), type(uint256).max);
    }

    function _deployVaults() internal {
        abVault = uniswapV2Pkg.deployVault(
            IERC20(address(ttA)),
            AB_TTA_LIQUIDITY,
            IERC20(address(ttB)),
            AB_TTB_LIQUIDITY,
            owner
        );

        bWethVault = uniswapV2Pkg.deployVault(
            IERC20(address(ttB)),
            BWETH_TTB_LIQUIDITY,
            IERC20(localWeth),
            BWETH_WETH_LIQUIDITY,
            owner
        );

        abPool = IUniswapV2Pair(uniswapV2Factory.getPair(address(ttA), address(ttB)));
        bWethPool = IUniswapV2Pair(uniswapV2Factory.getPair(address(ttB), localWeth));

        require(address(abPool) != address(0), "Scenario1 AB pool deployment failed");
        require(address(bWethPool) != address(0), "Scenario1 B/WETH pool deployment failed");
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("scenario1", "testTokenA", address(ttA));
        json = vm.serializeAddress("scenario1", "testTokenB", address(ttB));
        json = vm.serializeAddress("scenario1", "weth", localWeth);
        json = vm.serializeAddress("scenario1", "uniV2AbPool", address(abPool));
        json = vm.serializeAddress("scenario1", "uniV2BWethPool", address(bWethPool));
        json = vm.serializeAddress("scenario1", "uniV2AbVault", abVault);
        json = vm.serializeAddress("scenario1", "uniV2BWethVault", bWethVault);
        json = vm.serializeAddress("scenario1", "owner", owner);
        json = vm.serializeAddress("scenario1", "deployer", deployer);
        json = vm.serializeUint("scenario1", "chainId", block.chainid);
        json = vm.serializeString("scenario1", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _exportFragments() internal {
        _writePoolFragment("uniV2AbPool", address(abPool), "Uniswap V2 TTA/TTB Pool", "UNI-V2-AB");
        _writePoolFragment("uniV2BWethPool", address(bWethPool), "Uniswap V2 TTB/WETH Pool", "UNI-V2-BW");
        _writeVaultFragment("uniV2AbVault", abVault, "Pachira Vault of (TTA / TTB)", "abUniV2Vault");
        _writeVaultFragment("uniV2BWethVault", bWethVault, "Pachira Vault of (TTB / WETH)", "bwUniV2Vault");
    }

    function _writePoolFragment(string memory key, address poolAddr, string memory name, string memory symbol) internal {
        if (poolAddr == address(0)) return;
        string[] memory tags = new string[](0);
        ManifestEntry memory entry = ManifestEntry({
            chainId: block.chainid,
            addr: poolAddr,
            name: name,
            symbol: symbol,
            decimals: 18,
            tags: tags
        });
        _writeManifestEntry("pools/uniV2", key, entry);
    }

    function _writeVaultFragment(string memory key, address vaultAddr, string memory name, string memory symbol) internal {
        if (vaultAddr == address(0)) return;
        string[] memory tags = new string[](0);
        ManifestEntry memory entry = ManifestEntry({
            chainId: block.chainid,
            addr: vaultAddr,
            name: name,
            symbol: symbol,
            decimals: 18,
            tags: tags
        });
        _writeManifestEntry("vaults/strategy", key, entry);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("UniV2 TTA/TTB Pool:", address(abPool));
        _logAddress("UniV2 TTB/WETH Pool:", address(bWethPool));
        _logAddress("UniV2 TTA/TTB Vault:", abVault);
        _logAddress("UniV2 TTB/WETH Vault:", bWethVault);
        _logComplete("Stage 10");
    }
}