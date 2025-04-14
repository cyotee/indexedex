// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";

/// @notice Sweep sender ETH + ERC20 balances to DEPLOYER_ADDRESS.
/// @dev Intended for Anvil's default unlocked accounts. Uses tokenlist files in deployments/anvil_base_main.
///
/// Run example:
/// `DEPLOYER_ADDRESS=0xYourDeployer forge script scripts/foundry/anvil_base_main/Script_99_SweepBalancesToDeployer.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender <DEV0..DEV9>`
contract Script_99_SweepBalancesToDeployer is Script {
    string internal constant OUT_DIR = "deployments/anvil_base_main";
    uint256 internal constant ETH_RESERVE_WEI = 0.01 ether;

    mapping(address => bool) internal seen;

    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast();
        (, address from,) = vm.readCallers();
        vm.stopBroadcast();

        if (from == deployer) return;

        _sweepTokenlists(from, deployer);
        _sweepDeploymentOutputs(from, deployer);
        _sweepEth(from, deployer);
    }

    function _sweepTokenlists(address from, address deployer) internal {
        string[] memory files = new string[](7);
        files[0] = "anvil_base_main-tokens.tokenlist.json";
        files[1] = "anvil_base_main-uniV2pool.tokenlist.json";
        files[2] = "anvil_base_main-aerodrome-pools.tokenlist.json";
        files[3] = "anvil_base_main-strategy-vaults.tokenlist.json";
        files[4] = "anvil_base_main-aerodrome-strategy-vaults.tokenlist.json";
        files[5] = "anvil_base_main-balancerv3-constprod-pools.tokenlist.json";
        files[6] = "anvil_base_main-balancerv3-vault-token-pools.tokenlist.json";

        for (uint256 f = 0; f < files.length; f++) {
            _sweepTokenlist(from, deployer, files[f]);
        }
    }

    function _sweepDeploymentOutputs(address from, address deployer) internal {
        string[] memory files = new string[](23);
        files[0] = "deployment_summary.json";
        files[1] = "01_factories.json";
        files[2] = "02_shared_facets.json";
        files[3] = "03_core_proxies.json";
        files[4] = "04_dex_packages.json";
        files[5] = "05_test_tokens.json";
        files[6] = "06_pools.json";
        files[7] = "07_strategy_vaults.json";
        files[8] = "08_aerodrome_strategy_vaults.json";
        files[9] = "09_balancer_const_prod_pools.json";
        files[10] = "10_base_liquidity.json";
        files[11] = "11_standard_exchange_rate_providers.json";
        files[12] = "12_balancer_const_prod_vault_token_pools.json";
        files[13] = "13_balancer_vault_token_pool_liquidity.json";
        files[14] = "14_erc4626_permit_vaults.json";
        files[15] = "15_seigniorage_detfs.json";
        files[16] = "16_protocol_detf.json";
        files[17] = "17_weth_ttc_pools.json";
        files[18] = "18_weth_ttc_vaults.json";
        files[19] = "19_weth_ttc_base_liquidity.json";
        files[20] = "20_weth_ttc_balancer_vault_token_pools.json";
        files[21] = "21_weth_ttc_balancer_vault_token_pool_liquidity.json";
        files[22] = "anvil_base_main.json";

        for (uint256 f = 0; f < files.length; f++) {
            _sweepDeploymentJson(from, deployer, files[f]);
        }
    }

    function _sweepTokenlist(address from, address deployer, string memory filename) internal {
        string memory path = string.concat(OUT_DIR, "/", filename);
        string memory json;
        try vm.readFile(path) returns (string memory file) {
            json = file;
        } catch {
            return;
        }

        uint256 count = 0;
        address[] memory tokens = new address[](512);
        for (uint256 i = 0; i < 512; i++) {
            string memory pointer = string.concat(".", vm.toString(i), ".address");
            try vm.parseJsonAddress(json, pointer) returns (address token) {
                if (token != address(0) && !seen[token]) {
                    seen[token] = true;
                    tokens[count++] = token;
                }
            } catch {
                break;
            }
        }

        for (uint256 i = 0; i < count; i++) {
            _sweepToken(from, deployer, tokens[i]);
        }
    }

    function _sweepDeploymentJson(address from, address deployer, string memory filename) internal {
        string memory path = string.concat(OUT_DIR, "/", filename);
        string memory json;
        try vm.readFile(path) returns (string memory file) {
            json = file;
        } catch {
            return;
        }

        string[] memory keys = vm.parseJsonKeys(json, "");
        for (uint256 i = 0; i < keys.length; i++) {
            string memory pointer = string.concat(".", keys[i]);
            try vm.parseJsonAddress(json, pointer) returns (address token) {
                if (token != address(0) && !seen[token]) {
                    seen[token] = true;
                    _sweepToken(from, deployer, token);
                }
            } catch {
                // ignore non-address values
            }
        }
    }

    function _sweepToken(address from, address deployer, address token) internal {
        (bool ok, uint256 bal) = _balanceOf(token, from);
        if (!ok || bal == 0) return;

        vm.startBroadcast();
        _transfer(token, deployer, bal);
        vm.stopBroadcast();
    }

    function _sweepEth(address from, address deployer) internal {
        uint256 bal = from.balance;
        if (bal <= ETH_RESERVE_WEI) return;

        uint256 amount = bal - ETH_RESERVE_WEI;
        vm.startBroadcast();
        (bool ok,) = payable(deployer).call{ value: amount }("");
        vm.stopBroadcast();
        if (!ok) return;
    }

    function _balanceOf(address token, address account) internal returns (bool ok, uint256 bal) {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("balanceOf(address)", account));
        if (!success || data.length < 32) return (false, 0);
        return (true, abi.decode(data, (uint256)));
    }

    function _transfer(address token, address to, uint256 amount) internal returns (bool ok) {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        if (!success) return false;
        if (data.length == 0) return true;
        if (data.length == 32) return abi.decode(data, (bool));
        return false;
    }
}
