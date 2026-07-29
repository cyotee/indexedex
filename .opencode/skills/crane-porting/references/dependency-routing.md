# Dependency routing quick reference

## Expand → remap → delete

1. Inventory imports from upstream.
2. Ensure each shared symbol exists under `contracts/external/...` (add missing files there first).
3. Rewrite imports to `@crane/contracts/external/...`.
4. Delete protocol-local duplicates only after greps show zero consumers (absolute + relative).

## OZ major selection

| Need | Path |
|------|------|
| Classic non-upgradeable OZ used by most modern ports | `contracts/external/openzeppelin-contracts/` |
| Explicit v4 behavior | `contracts/external/openzeppelin-contracts-v4/` |
| Explicit v5 behavior | `contracts/external/openzeppelin-contracts-v5/` |
| Upgradeable bases | matching `openzeppelin-upgradeable*` tree |

Do not "upgrade" majors mid-port without a decision record and full test pass.

## Crane-native vs OZ-vendored

| Symbol family | Crane-native path | When allowed for a **protocol port** |
|---------------|-------------------|--------------------------------------|
| Ownable / operators | `contracts/access/...` | Only for **new Crane wrappers**, not for replacing OZ inside domain logic |
| Context / `_msgSender` | Crane utils vs OZ Context | Domain code with meta-tx must keep OZ Context |
| SafeCast / SafeERC20 (OZ) | external OZ | Prefer external OZ for domain fidelity |
| ConstProdUtils / Sets | `contracts/utils/...` | Fine for Crane Services and tests |

## Grep checklist before delete

```bash
# Basename and path fragment
rg -n "SafeCast\.sol" contracts/
rg -n "dependencies/openzeppelin" contracts/protocols/
rg -n "@crane/contracts/external/openzeppelin" contracts/protocols/lending/aave/ | head

# Relative survivors
rg -n 'import \{.*\} from "\.\./' contracts/protocols/<protocol>/
rg -n 'import \{.*\} from "\./' contracts/external/<protocol>/ | head
```

## Post-move build hygiene

```bash
rm -rf cache out
forge build
forge test --match-path 'test/foundry/spec/protocols/<...>' -vv
```
