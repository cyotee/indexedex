// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "../../anvil_base_main/DeploymentBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IPool as IAerodromePool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

contract Script_17_WethTtcPoolsAndVaults is DeploymentBase {
    uint256 internal constant MINT_TTC = 1_000_000e18;
    uint256 internal constant INITIAL_WETH = 10e18;
    uint256 internal constant INITIAL_TTC = 10_000e18;

    IAerodromeStandardExchangeDFPkg private aerodromePkg;
    address private ttC;

    IAerodromePool private aeroWethcPool;
    address private aeroWethcVault;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Base Stage 17: Aerodrome WETH/TTC Pools and Vaults");

        vm.startBroadcast();
        _deployPool();
        _deployVault();
        _mintAndWrap();
        _approveRouter();
        _seedAerodrome();
        vm.stopBroadcast();

        _exportPoolsJson();
        _exportVaultsJson();
        _exportLiquidityJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        aerodromePkg = IAerodromeStandardExchangeDFPkg(_readAddress("04_dex_packages.json", "aerodromePkg"));
        ttC = _readAddress("05_test_tokens.json", "testTokenC");

        require(address(aerodromePkg) != address(0), "AerodromePkg not found");
        require(ttC != address(0), "Test Token C not found");
    }

    function _deployPool() internal {
        address aeroPool = aerodromePoolFactory.getPool(address(weth), ttC, false);
        if (aeroPool == address(0)) {
            aeroPool = aerodromePoolFactory.createPool(address(weth), ttC, false);
        }
        aeroWethcPool = IAerodromePool(aeroPool);
    }

    function _deployVault() internal {
        aeroWethcVault = aerodromePkg.deployVault(aeroWethcPool);
    }

    function _mintAndWrap() internal {
        IERC20MintBurn(ttC).mint(deployer, MINT_TTC);

        uint256 haveWeth = IERC20(address(weth)).balanceOf(deployer);
        if (haveWeth < INITIAL_WETH) {
            weth.deposit{value: INITIAL_WETH - haveWeth}();
        }
    }

    function _approveMax(address token, address spender) internal {
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, type(uint256).max);
    }

    function _approveRouter() internal {
        _approveMax(address(weth), address(aerodromeRouter));
        _approveMax(ttC, address(aerodromeRouter));
    }

    function _seedAerodrome() internal {
        if (aeroWethcPool.reserve0() != 0 || aeroWethcPool.reserve1() != 0) {
            return;
        }

        uint256 deadline = block.timestamp + 1 hours;
        aerodromeRouter.addLiquidity(address(weth), ttC, false, INITIAL_WETH, INITIAL_TTC, 0, 0, deployer, deadline);
    }

    function _exportPoolsJson() internal {
        string memory json;
        json = vm.serializeAddress("", "aeroWethcPool", address(aeroWethcPool));
        _writeJson(json, "17_weth_ttc_pools.json");
    }

    function _exportVaultsJson() internal {
        string memory json;
        json = vm.serializeAddress("", "aeroWethcVault", aeroWethcVault);
        _writeJson(json, "18_weth_ttc_vaults.json");
    }

    function _exportLiquidityJson() internal {
        string memory json;
        json = vm.serializeUint("", "initialWeth", INITIAL_WETH);
        json = vm.serializeUint("", "initialTtc", INITIAL_TTC);
        _writeJson(json, "19_weth_ttc_base_liquidity.json");
    }

    function _logResults() internal view {
        _logAddress("Aerodrome WETH/TTC Pool:", address(aeroWethcPool));
        _logAddress("Aerodrome WETH/TTC Vault:", aeroWethcVault);
        _logComplete("Base Stage 17");
    }
}