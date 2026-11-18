# Baseline commands

cwd: /Users/cyotee/Projects/indexedex
profile: not selected; no forge build or test was run
start: 2026-11-16T19:01:11.121Z

## forge --version

```
forge Version: 1.9.0
Commit SHA: 6056c5845d34205a83cf7108042adb137325c9df
Build Timestamp: 2026-11-02T20:16:54.701302000Z
```

## solar --version

```
solar 0.3.0-dev+commit.a2b44354
Solidity Version: 0.8.38
Commit SHA: a2b4435466bff1b91459a1bc64b04e5e8144ed9f
```

## foundry.toml

out = 'out'
cache_path = 'cache_forge'
solc = "0.8.35"
via_ir = false
profiles: default (test/foundry/spec), fork (test/foundry/fork)

## --use

forge build --help documents `--use <SOLC_VERSION>` as a solc version, path, or executable name on PATH. `which solar` returned /Users/cyotee/.foundry/bin/solar. No compilation was run, so this is not a build receipt.

## git

GIT_MASTER=1 git status --short
GIT_MASTER=1 git rev-parse --short HEAD -> 42d2efc0d
GIT_MASTER=1 git rev-parse --short 'HEAD^{tree}' -> 15c55f7df

Historical verification.md bodies were not rewritten. Counts 236, 183, and 28641 are cited from the gap-closure plan as unrepaired historical observations, not as outputs of these commands.
