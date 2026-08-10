# Runtime proof commands — TCA-COMMON-001 (PAT-I-ABS)

## Primary (hermetic)

```bash
forge test --match-path 'test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol' -vv
```

Key test: `test_secureTokenTransfer_pretransferred_returnsAmount`

## Supporting (product free-mint already hardened elsewhere)

```bash
forge test --match-path 'test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol' --match-test 'test_FreeMint' -vv
forge test --match-path 'test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol' --match-test 'test_A0_pretransferred' -vv
```

## Env

- Profile: default hermetic (`forge test`)
- ALCHEMY_KEY: not required for this proof
- `via_ir`: not used
