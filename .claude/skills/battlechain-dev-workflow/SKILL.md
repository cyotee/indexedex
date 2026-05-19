---
name: battlechain-dev-workflow
description: Use this skill when deploying or testing Solidity protocols on BattleChain, including setup, deployment, Safe Harbor agreement creation, requesting attack mode, and promotion to production.
---

# BattleChain Dev Workflow

BattleChain is a pre-mainnet, post-testnet security stage:

Audit -> Deploy on BattleChain -> Stress test under Safe Harbor -> Promote -> Mainnet

Use this workflow for protocol-side development and validation.

## Core Network Settings (Testnet)

- Chain ID: `627`
- CAIP-2: `eip155:627`
- RPC: `https://testnet.battlechain.com`
- Explorer: `https://explorer.testnet.battlechain.com`

## Required Tooling

- Foundry
- just
- cast keystore account for signing (`cast wallet import battlechain --interactive`)

Never pass private keys to AI tools. Import keys manually into Foundry keystore.

## Golden Rules

- Always deploy to BattleChain before mainnet.
- Use `battlechain-lib` deployment helpers (`bcDeployCreate*`).
- On BattleChain, all `forge script` broadcasts should include `--skip-simulation`.
- Prefer identical bytecode to mainnet (only constructor/config differences by chain).

## Recommended Setup

```bash
forge install cyfrin/battlechain-lib
```

Add remapping:

```toml
remappings = [
  "battlechain-lib/=lib/battlechain-lib/src/",
]
```

## Script Base Pattern

Use `BCScript` for deploy + agreement + attack mode orchestration.

```solidity
import {BCScript} from "battlechain-lib/BCScript.sol";

contract Deploy is BCScript {
    function run() external {
        vm.startBroadcast();

        bytes32 salt = keccak256("my-vault-v1");
        address deployed = bcDeployCreate2(salt, type(MyVault).creationCode);

        address agreement = createAndAdoptAgreement(
            defaultAgreementDetails(
                "My Protocol",
                _contacts(),
                getDeployedContracts(),
                _recoveryAddress()
            ),
            msg.sender,
            keccak256("agreement-v1")
        );

        if (_isBattleChain()) {
            requestAttackMode(agreement);
        }

        vm.stopBroadcast();
    }
}
```

## Lifecycle States You Must Respect

- `0` NOT_DEPLOYED
- `1` NEW_DEPLOYMENT
- `2` ATTACK_REQUESTED
- `3` UNDER_ATTACK (attackable)
- `4` PROMOTION_REQUESTED (still attackable)
- `5` PRODUCTION (terminal)
- `6` CORRUPTED (terminal)

## Typical CLI Flow (Starter Style)

```bash
just setup
just create-agreement
just request-attack-mode
just check-state
```

Expect `3` for attackable state.

Testnet fast approval path:

```bash
cast send 0x1bC64E6F187a47D136106784f4E9182801535BD3 \
  "approveAttack(address)" $AGREEMENT_ADDRESS \
  --account battlechain \
  --rpc-url https://testnet.battlechain.com
```

## Request Attack Mode Directly

AttackRegistry testnet proxy:

- `0xdD029a6374095EEb4c47a2364Ce1D0f47f007350`

```bash
cast send 0xdD029a6374095EEb4c47a2364Ce1D0f47f007350 \
  "requestUnderAttack(address)" $AGREEMENT_ADDRESS \
  --account battlechain \
  --rpc-url https://testnet.battlechain.com
```

For non-BattleChainDeployer contracts:

```bash
cast send 0xdD029a6374095EEb4c47a2364Ce1D0f47f007350 \
  "requestUnderAttackByNonAuthorized(address)" $AGREEMENT_ADDRESS \
  --account battlechain \
  --rpc-url https://testnet.battlechain.com
```

## Promote to Production

- Attack moderator calls `promote(agreement)`.
- 3-day delay in `PROMOTION_REQUESTED`.
- Can `cancelPromotion` during delay.
- DAO can `instantPromote` for emergencies.

## Verification

Use BattleChain verifier endpoint:

```bash
forge verify-contract <ADDR> <PATH:NAME> \
  --chain-id 627 \
  --verifier-url https://block-explorer-api.testnet.battlechain.com/api \
  --verifier custom \
  --etherscan-api-key 1234 \
  --rpc-url https://testnet.battlechain.com
```

For factory deployments, prefer battlechain-lib verify helpers (for example, `bc-verify-broadcast`) after deployment.

## Common Failure Fixes

- Forge script fails unexpectedly: add `--skip-simulation`.
- Out-of-gas: try `-g 300`; if block limit exceeded, lower to `-g 200` or `-g 150`.
- Stuck nonce: send no-op replacement at same nonce with higher max fee.

```bash
cast gas-price --rpc-url https://testnet.battlechain.com
cast send \
  --account battlechain \
  --rpc-url https://testnet.battlechain.com \
  --nonce <stuck-nonce> \
  --max-fee-per-gas <higher-fee> \
  --value 0 \
  0x0000000000000000000000000000000000000000
```

## References

- `https://docs.battlechain.com/llms-full.txt`
- `https://docs.battlechain.com/battlechain/tutorials/going-attackable`
- `https://docs.battlechain.com/battlechain/how-to/request-attack-mode`
- `https://docs.battlechain.com/battlechain/how-to/promote-to-production`
- `https://docs.battlechain.com/battlechain/tutorials/deploying-contracts`
