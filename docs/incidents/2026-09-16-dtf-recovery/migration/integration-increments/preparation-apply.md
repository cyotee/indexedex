# Preparation increment application receipt

Date: 2026-11-10.

## Integration state

- Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-integration`
- Branch: `work/dtf-migration`
- Base before application: `215c2bba6aa75e3e79bf68b7980b730927a85817`
- Pricing parent: `90ff0307a7a8e084aa073e02eff125e9c7973933`
- Applied preparation commit: `6d82859ee0b20804a4ced6e7a5ae395a49f5cdfd`
- Preparation parent: `90ff0307a7a8e084aa073e02eff125e9c7973933`
- Operation: `GIT_MASTER=1 git cherry-pick --no-commit 6d82859ee0b20804a4ced6e7a5ae395a49f5cdfd`
- No commit was created.

The target branch was at the required pricing commit with an empty index and
no tracked worktree diff before application. The pre-existing untracked
`pricing-land.md` receipt was preserved.

## Verified preparation scope

The preparation commit changes exactly these five paths:

```text
contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol
contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol
test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol
```

For every path, the original committed blob, staged index bytes, current
worktree bytes, and accepted `migration/package/evidence/preparation/source-manifest.json`
SHA-256 agree:

| Path | SHA-256 |
| --- | --- |
| `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol` | `ff3c95b45adec74973aabcb874be2a8d86aa79a9af8770949b0b7e635fbcc360` |
| `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol` | `fed9bd4bf324c8e1c3d71e1809c3ae516320d05beb580085b2deedb83bb24f82` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol` | `14112eb68aac3f67bcbae5d41d1a5e76fe3b526033f6dab782df5c1d396b899d` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol` | `6e3a8c25dad4c01ca1e0b517ebe365b8340520237ca8bc269a9ac3eceb94af7c` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol` | `d1a4a227847c32bb5b5f3a4b97d9fed8114d2fca47c4c4ff0106b8332248b41e` |

The independent preparation report confirms this bounded increment; its
accepted evidence records 24 focused tests and 9,932 broad tests, with zero
failures or skips. These tests were not rerun in this application step.

## Pricing preservation and checks

The pricing commit remains the exact `HEAD` and its 19 committed paths were
checked against `HEAD`; every blob matches the pricing commit.

- Staged path inventory: exactly the five paths listed above.
- `git diff --cached --check --ignore-submodules=all`: passed.
- Tracked unstaged diff: none.
- Existing untracked `pricing-land.md`: preserved and not staged.
- No test or build was run; the following integration step owns combined
  verification.
- No source content was edited, and no conflict occurred.

This receipt records application only. It does not claim combined verification
or authorize a commit.
