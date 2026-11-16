# Preparation diagnostics receipts

All paths are relative to `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
These are literal Native tool results, not a claim that Forge emits no warnings.

## Native Solidity diagnostics

Calls used `tool.lsp_diagnostics({filePath: <absolute path>, severity: "all"})`.

| Path | Result |
| --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol` | `No diagnostics found` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol` | `No diagnostics found` |
| `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol` | `No diagnostics found` |
| `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol` | `No diagnostics found` |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol` | Initially timed out waiting for fresh diagnostics within 3000ms; after completed builds returned `warning[solar] (2018) at 49:4: function state mutability can be restricted to view` |

The last warning is on the unchanged `test_deploy_inert_until_first_bond`.
Its complete existing body remains intact in `source.patch`; only its line number
moved from 33 to 49. No suppression or unrelated mutability change was made.

A pre-edit reference request used
`tool.lsp_find_references({filePath: <absolute DETFFundedBondTarget.sol>, line: 94, character: 17, includeDeclaration: true})`.
Result: `LSP request timeout (method: textDocument/references)`.
Direct source inspection traced the ordinary parent `_openBondNft` call to
`createFundedPosition`; the real-proxy suites then executed that path.

## Evidence tooling

`tool.lsp_diagnostics` on `inspect-artifacts.mjs` returned `No diagnostics found`.
The patch-time Bash diagnostic reported:

```text
LSP server 'bash' for .sh, .bash, .zsh, .ksh is NOT INSTALLED.
Command not found: bash-language-server
```

No server was installed, consistent with the explicit dependency/config boundary.
The manifest's patch-time JSON diagnostic also reported that `biome` is not
installed (`Command not found: biome`). No install or configuration change was
attempted for that server either.
`bash -n docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/preparation/run.sh`
exited 0 (`bash_4`). `git diff --check` also exited 0.

## Compiler and lint output

`focused.log` and `broad.log` retain every compiler/lint warning without filtering.
Both builds/tests exited 0 with no failed or skipped test. Warnings include the
existing nightly/config-key notices, unreachable code, mutability suggestions,
and Forge lints for synchronization-before-lock, emitted events after calls,
unused returns, timestamp comparisons, casts, and loops.

Warnings at the edited targets refer to retained statements (including their
existing modifier order), not a new failure. The initializer's event lint moved
with the existing `ThresholdsConfigured` emission. The original package statement
and unchanged event order are visible in `source.patch`; the new library is in
the five-path source manifest. No warning was suppressed.
