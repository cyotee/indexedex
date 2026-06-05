#!/bin/bash

# anvil --steps-tracing --code-size-limit 9999999999 --fork-url sepolia_alchemy
# anvil --code-size-limit 9999999999 --fork-url sepolia_alchemy --block-time 2
# anvil --code-size-limit 9999999999 --fork-url sepolia_alchemy
# anvil --fork-url sepolia_alchemy
# anvil --fork-url sepolia_alchemy --fork-block-number 8983089
forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_Sepolia_01_Deploy.s.sol -vvv
forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_Sepolia_02_Test_Tokens_and_Pools_with_WETH.s.sol -vvv

# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_00_Init.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_01_WETH9.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_02_Permit2.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_03_Balancer_V3.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_04_Uniswap_V2.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_05_Crane_Factories.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_06_Crane_Access.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_07_Crane_Components.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_08_Indexedex_Components.s.sol
# forge script --rpc-url local --broadcast --private-key ${DEV_0_PRIVATE_KEY} --batch-size 4 scripts/foundry/local/Local_09_Indexedex_Platform.s.sol

# forge script --rpc-url local --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --batch-size 4 scripts/foundry/local/Local_01_Wallet_Funding.s.sol
# forge script --rpc-url local --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --batch-size 4 scripts/foundry/local/Local_02_WETH9.s.sol
# forge script --rpc-url local --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --batch-size 4 scripts/foundry/local/Local_03_UniswapV2.s.sol
# forge script --rpc-url local --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --batch-size 4 scripts/foundry/local/Local_04_Permit2.s.sol