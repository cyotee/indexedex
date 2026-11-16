# Independent runtime evidence

This directory belongs to the independent phase04 verifier. The production
source, existing tests, and implementation evidence remain unchanged.

Owned Anvil endpoint: `http://127.0.0.1:18548`, chain 31337, 100,000,000 block gas,
EIP-170 enforcement enabled, no fork, unlocked standard development accounts.
Initial timestamp: 1794348000.
First, unsuccessful instance:
`0x7c3d3fc7e5ed9d1d423080e80e7785b4180b3d29b8f21b3e21efe759deb4e53f`.
The fixture wraps 10,000 ETH, exceeding the default account's remaining balance
after deployment gas. Its 56-transaction prefix is retained in `broadcast/`.
No Migration proxy was deployed on that instance.

Successful fresh instance:
`0x3c7762a059c4bc219482898a6c93a94a6ccc887be30cafa822e7c45f05b7a5b7`.
It used `--balance 1000000`, supplying native development-account funding at
node genesis, not forged WETH or source-token balances. `stage-a-funded.log`
records a journal conflict before broadcast. `stage-a-isolated.log` is the
successful exact-argv run with a separately seeded runtime cache; Stage B is
`stage-b.log`. Both nodes are stopped; see `../cleanup.json`.

Current source base: `6e27ecaa242c4acca132e3575a160514aad07b11`.
Branch: `work/dtf-migration-phase-04`.

Independent SHA-256 checks matched all 927 unique recorded artifacts and all
2,479 source files. Independent Keccak-256 checks matched all source files.
Every artifact metadata source entry matches that current source graph; no
non-Solar or viaIR artifact was found.

The existing focused log contains 59 passing tests in 10 suites; the combined
log contains 10,078 passing tests in 609 suites, with zero failures or skips.
These are inspected producer executions, not reruns by the verifier.
