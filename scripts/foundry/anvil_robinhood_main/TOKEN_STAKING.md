# TokenStaking ($DTF) on Robinhood 4663

Same as `forge script`: no `--broadcast` simulates; `--broadcast` sends.

Sender / owner: `$DEPLOYER_ADDRESS` (`0x72BeA6Fa3E68EF18c87D045Aac7C4Aa5249d933B`)

Staking token: `$DTF` `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01`

Rewards duration: 7 days

`--broadcast` still simulates each Stage first, then sends. Never `--skip-simulation`.

## 1. Deploy package + instance

Does not notify rewards. Does not need a DTF balance.

```bash
# Simulate
bash scripts/shell/robinhood_main.sh token-staking

# Execute
bash scripts/shell/robinhood_main.sh token-staking --broadcast
```

## 2. Deposit reward reserve

Pulls the sender's full `$DTF` balance into the staking diamond via Permit2, then `notifyRewardAmount`. Put DTF on `$DEPLOYER_ADDRESS` first. Reverts if that balance is 0.

```bash
# Simulate
bash scripts/shell/robinhood_main.sh token-staking-fund

# Execute
bash scripts/shell/robinhood_main.sh token-staking-fund --broadcast
```

JSON:

- `deployments/anvil_robinhood_main/phase06_stage08_token_staking_pkg.json`
- `deployments/anvil_robinhood_main/phase08_stage01_token_staking_dtf.json`
- `deployments/anvil_robinhood_main/phase08_stage02_token_staking_notify.json`

## Per-Stage `forge script`

Default RPC is Foundry alias `robinhood_mainnet`. First compile in this tree often takes 20–40+ minutes.

```bash
export SENDER="$DEPLOYER_ADDRESS"
export OWNER="$DEPLOYER_ADDRESS"
export OUT_DIR_OVERRIDE=deployments/anvil_robinhood_main
export NETWORK_PROFILE=anvil_robinhood_main
export CHAIN_ID=4663
export RPC_URL=https://rpc.mainnet.chain.robinhood.com

# Simulate deploy
forge script scripts/foundry/anvil_robinhood_main/Phase_06_Stage_08_TokenStakingPkg.s.sol --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS"
forge script scripts/foundry/anvil_robinhood_main/Phase_08_Stage_01_TokenStakingDtf.s.sol --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS"

# Execute deploy
forge script scripts/foundry/anvil_robinhood_main/Phase_06_Stage_08_TokenStakingPkg.s.sol --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS" --broadcast --slow --gas-estimate-multiplier 300
forge script scripts/foundry/anvil_robinhood_main/Phase_08_Stage_01_TokenStakingDtf.s.sol --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS" --broadcast --slow --gas-estimate-multiplier 300

# Simulate reward deposit (sender DTF balance)
forge script scripts/foundry/anvil_robinhood_main/Phase_08_Stage_02_TokenStakingNotifyRewards.s.sol --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS"

# Execute reward deposit
forge script scripts/foundry/anvil_robinhood_main/Phase_08_Stage_02_TokenStakingNotifyRewards.s.sol --rpc-url "$RPC_URL" --sender "$DEPLOYER_ADDRESS" --broadcast --slow --gas-estimate-multiplier 300
```
