// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// @dev Shared mainnet addresses for Ethereum staking fork tests.
library EthereumStakingAddresses {
    address internal constant DEPOSIT = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address internal constant FRX_ETH = 0x5E8422345238F34275888049021821E8E08CAa1f;
    address internal constant FRX_ETH_MINTER = 0xbAFA44EFE7901E04E39Dad13167D089C559c1138;
    address internal constant SFRX_ETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address internal constant ST_ETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal constant WST_ETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant R_ETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address internal constant ROCKET_STORAGE = 0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46;
    address internal constant E_ETH = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
    address internal constant WE_ETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant ETHERFI_LIQUIDITY_POOL = 0x308861A430be4cce5502d0A12724771Fc6DaF216;
    address internal constant OS_ETH = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;
    address internal constant OS_TOKEN_VAULT_CONTROLLER = 0x2A261e60FB14586B474C208b1B7AC6D0f5000306;
    // StakeWise Genesis vault (public) - verified at execute time in TestBase
    address internal constant STAKEWISE_GENESIS_VAULT = 0xAC0F906E433d58FA868F936E8A43230473652885;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant ETH_WHALE = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
}

abstract contract TestBase_EthereumStakingFork is Test {
    function _forkEthereum() internal returns (bool) {
        return _forkEthereumAtBlock(0);
    }

    function _forkEthereumAtBlock(uint256 blockNumber) internal returns (bool) {
        string[3] memory rpcNames;
        rpcNames[0] = "ethereum_mainnet_alchemy";
        rpcNames[1] = "ethereum_mainnet_infura";
        rpcNames[2] = "ethereum_mainnet_public";

        for (uint256 i = 0; i < rpcNames.length; i++) {
            try vm.rpcUrl(rpcNames[i]) returns (string memory rpc) {
                if (bytes(rpc).length == 0) continue;
                if (blockNumber == 0) {
                    try this._createFork(rpc) {
                        return true;
                    } catch {}
                } else {
                    try this._createForkAt(rpc, blockNumber) {
                        return true;
                    } catch {}
                }
            } catch {}
        }

        // Fallback: ETH_RPC_URL env
        try vm.envString("ETH_RPC_URL") returns (string memory envRpc) {
            if (bytes(envRpc).length > 0) {
                try this._createFork(envRpc) {
                    return true;
                } catch {}
            }
        } catch {}

        vm.skip(true);
        return false;
    }

    function _createFork(string memory rpc) external {
        vm.createSelectFork(rpc);
    }

    function _createForkAt(string memory rpc, uint256 blockNumber) external {
        vm.createSelectFork(rpc, blockNumber);
    }

    function _dealETH(address to, uint256 amount) internal {
        vm.deal(to, amount);
    }
}
