# Other-source custody and harvest evidence

Date: 2026-11-10. Execution lane: `other-sources`, plan task 1 / E1.

**Verdict: evidence delivery complete; migration route closure is NOT complete.**
The final public-provider full probe records **21 PASS, 4 FAIL, 3 UNPROVEN** assertions. Two supplemental native LP exit assertions also FAIL. PASS below means the stated source-level behavior, not authorization to issue migration credit.

## Evidence and execution identity

All paths below are relative to this report unless stated otherwise.

| Run | Result and retained evidence |
| --- | --- |
| Initial non-login Alchemy invocation | Exit 2, UNPROVEN: `ALCHEMY_KEY absent; RPC alias robinhood_mainnet_alchemy cannot be expanded`. The non-login command environment and task kernel lacked the variable; the existing login shell supplies it. `probe.json`, `probe.sources.json`. No child started. |
| First public-provider fallback | Exit 2, UNPROVEN. Requested historical state unavailable; fresh fork started. Receipt reads raced mining. Preserved as `probe-public.{json,sources.json,anvil.log}`. This is a harness failure, not product evidence. |
| Explicit-mining correction | Exit 2. Custody and several harvests succeeded; rollback assertions lacked opcode tracing. `probe-public-r2.{json,sources.json,anvil.log}`. Its rollback FAILs are superseded harness failures. |
| Tracing correction | Exit 2. Tracing enabled; parser mishandled already-prefixed stack hex. Rollback assertions UNPROVEN. `probe-public-r3.{json,sources.json,summary.json,anvil.log}`. |
| Final full run | Exit 2, overall FAIL, 21/4/3 individual verdicts. `probe-public-r4.{json,sources.json,summary.json,anvil.log}`. Explicit mining, step tracing and corrected hex parsing. |
| Supplemental native LP exits | Exit 2, two FAILs. `probe-native.{json,sources.json,summary.json,anvil.log}`. Reuses an authenticated prior fresh pin; does not substitute it for the historical block. |
| Login-shell Alchemy retry | Existing `/bin/zsh -lc` environment passed a presence-only check. Historical code and TokenStaking state were served at the required pin, but identity acquisition stopped with `eth_getCode: HTTP 429`. Exit 2, UNPROVEN, no Anvil child started. `probe-alchemy.{json,sources.json}`. |
| Serialized login-shell Alchemy retry | Metadata reads were changed from a concurrent burst to sequential calls; transport throttles now propagate as harness errors rather than missing source methods. Historical code/state access again passed, but identity acquisition stopped with `eth_call: HTTP 429`. Exit 2, UNPROVEN, no Anvil child started. `probe-alchemy-r2.{json,sources.json}`. |

The historical block `108944663` header was available with hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
The public provider rejected `eth_getCode` with code `-32000`:
`historical state b1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071 is not available`.
Each full fallback preserves that failure under `attempts` before selecting its separately labeled fresh block.

Both login-shell Alchemy attempts separately authenticated chain 4663, the same historical block/hash/state root, the TokenStaking runtime, and `totalSupply()` = **`15338080546808403036783930`** at block **108944663**. Both historical attempts are PASS. Thus historical state is available through Alchemy; the public provider's archive failure remains true and preserved. The initial missing-variable result was an environment-selection error, not evidence that the credential was unavailable. Neither the key nor its expanded RPC URL was printed.

The concrete remaining blocker is **HTTP 429 during authenticated historical source acquisition**, including after serializing metadata calls. First attempt: `2026-11-10T12:10:13.533Z` to `12:10:19.242Z`, Bun PID `54212`, failed `eth_getCode`. Serialized attempt: `12:12:45.184Z` to `12:12:58.510Z`, Bun PID `55971`, failed `eth_call`. Both exited 2 with `overall=UNPROVEN`, `productProof=false`, and `cleanup.noChildStarted=true`. Neither created an Anvil process, owned port, custody transaction or pinned custody PASS. No further credential request is needed; provider throughput is the blocker for the orchestrator.

Final public-provider full-run pin:

- Chain: Robinhood, **4663**, RPC result `0x1237`; configured alias `robinhood_mainnet_public`.
- Block: **110862604**, hash `0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80`.
- State root: `0x1d86ca9f4f0457092dbfc6a8aa7d341e90d94e5a5fa4eba5bfa9500065d6ac77`; timestamp `0x6af306af`.
- Bun **1.4.2**, `/opt/homebrew/Cellar/bun/1.4.2/bin/bun`, Darwin arm64; probe PID `43055`.
- Anvil **1.9.0-Homebrew**, commit `6056c5845d34205a83cf7108042adb137325c9df`; child PID `43834`, loopback port `56769`.

Native LP replay pin: block **110860459**, hash
`0xd5df213bed280397043210c7e927207971def5b71dcedf81e94a4240d4a736a1`,
state root `0xf7b30af1d962fb6a11d2ed19fdaf19963774f409dc5f11fdb0da3366aa05a582`.
Probe PID `46979`, Anvil PID `46983`, port `56959`.

Source manifests retain runtime bytes, Keccak-256 hashes, exact queried selector bindings, facet runtime hashes, metadata, graph edges, registry results and input SHA-256 fingerprints. There are **43 observed identities**, including unrelated registry tokens; observation is not admission. Main runtime comparison checks the fork against the upstream pinned code. Proxy runtime hash alone is insufficient: these diamonds commonly share
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
Facet bindings distinguish the source behaviors.

No claim is made that current repository Solidity exactly reproduces every legacy facet byte-for-byte. No compiler was run. The evidence establishes deployed routing fingerprints and executed behavior, not an independent source-code verification service result.

## Resolved identities, units and source matrix

Registry `0x09682b00D873D913ada0bB69B4D4c9631810d0bc`,
`vaultsOfToken(address)` selector **`0x2b9fc930`**, returned seven DTF-related vaults: both DETFs and the five SE/LP identities below. Earlier DETF `standardExchangeVault()` and `standardExchangeVaultShare()` identify the earlier SE; its `reservePool()` and the earlier NFT's `lpToken()` identify the earlier fungible LP. Weighted deployment exports, registry membership and source metadata identify the weighted legs and LP.

| Source | Exact address | Raw unit | Executed custody / rollback | Harvest from ordinary new custodian |
| --- | --- | --- | --- | --- |
| TokenStaking allocation right | `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00` | DTF-denominated weight, 18-decimal basis; not ERC-20 shares | PASS: holder reassignment; claim rollback PASS | PASS to SY; integrated credit remains UNPROVEN |
| Claim-vault shares | `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0` | **19 decimals**, not 9 | PASS mechanical ERC-20 custody and rollback | PASS ERC-4626 redemption to 9-decimal SY |
| Earlier underlying SE shares | `0xb7D4Bb379D361AD442CddEE53eA71a33957826A7` | 18 decimals | PASS mechanical custody and rollback | FAIL: `VaultDisabled(source)` |
| Earlier fungible LP | `0x923877336b14662cFb5B3A60b14e7d716d54A888` | 18 decimals | PASS mechanical custody and rollback | FAIL exact-in: `UnsupportedRoute()`; FAIL native share exit: `NotOwner(custodian)` |
| Weighted WETH-leg SE shares | `0x999DaE02D22E5FEe1c4508430D5196d31d631009` | 18 decimals | PASS mechanical custody and rollback | FAIL SY and SE exact-in exits: `VaultDisabled(source)` |
| Weighted DTF custody SE shares | `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` | **28 decimals** | PASS mechanical custody and rollback | PASS ERC-4626 redemption to 18-decimal DTF |
| Weighted fungible LP | `0x46E068c2393e189Fbc86632f67210aF253a42Aa8` | 18 decimals | PASS mechanical custody and rollback | FAIL exact-in and native exits: `NotOwner(custodian)` |

The earlier NFT `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` is an **LP-lock NFT**, not the fungible LP at `0x9238…A888`. Neither its token IDs nor its lock amounts are treated as funded DETF principal.

The five SE/LP addresses above are the concrete standalone identities missing from the historical eight-position-kind ledger inventory. Their identities are now resolved; their eligible user balances and contribution ancestry are not. Claim-vault shares are a separate 19-decimal custody layer over SY at
`0xB55604CF4dcdABB362078e106D20F98512391EdF`.

**Fixture limit:** share/LP tests impersonate actual infrastructure holders: TokenStaking, the earlier LP, the earlier NFT escrow, the weighted hook, and fee collector `0x20af9A1e21a59a411cd3b0c40E70AF9084770b2E`. This proves authentic token mechanics, not that an end user can instruct those contracts to approve or surrender their holdings. Direct end-user share/LP migration eligibility remains UNPROVEN. The staking fixture is an actual recorded EOA claim holder.

## Exact selectors and raw state transitions

Observed relevant source selectors:

| Function / return schema | Selector |
| --- | --- |
| `balanceOf(address) -> uint256` | `0x70a08231` |
| `totalSupply() -> uint256` | `0x18160ddd` |
| `approve(address,uint256) -> bool` | `0x095ea7b3` |
| `transfer(address,uint256) -> bool` | `0xa9059cbb` |
| `transferFrom(address,address,uint256) -> bool` | `0x23b872dd` |
| `reassign(address,uint256)`, no return | `0xcc447fba` |
| `withdrawClaim(uint256) -> uint256` | `0xa224dcb7` |
| `claimVault() -> address` | `0xab518e6e` |
| `redeem(uint256,address,address) -> uint256` | `0xba087652` |
| `redeem(address,uint256,address,uint256,bool) -> uint256` | `0x769f8e5d` |
| `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` | `0xd02d3063` |
| `withdrawSeShares(uint256,address,uint256,uint256,uint256)` | `0x84eb9bce` |
| `exitProportional(uint256,address,uint256[],uint256)` | `0x8b72d9e5` |
| `exitProportionalFlexible(uint256,address,bool[],uint256[],uint256)` | `0x94b74d12` |
| Registry `isDisabled(address) -> bool` | `0x4f6c171d` |

Transaction entrypoints are sent as transactions; unused return data is not asserted. Full receipts and native-exit arguments are in the JSON. The older LP has no binding for the two proportional selectors; the weighted LP has no binding for `withdrawSeShares`.

TokenStaking's `reassign` and `withdrawClaim` bind to facet
`0x9C90d4a476f3473b9a0e32B530aF3474271a80B1`, runtime hash
`0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742`.
Its ERC-20 `approve`, `transfer`, and `transferFrom` bindings are zero. Thus the claim is not an ERC-20, but **holder-authorized reassignment exists**.

Claim holder `0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3` reassigned
**`64890781291192882058375`** weight to the local custodian
`0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`.
One successful transaction, `0x1ef021c20f3e08df3ebd722e1f9c44b180c7e913972ac33b1df11f78c9e177ae`,
changed holder weight to **0** and custody weight from **0** to that exact amount.
The former holder therefore retained no independently exercisable surrendered weight.

The custodian then called `withdrawClaim` in a separate, staged harvest transaction
`0x965e7f7265aa42a3837370a5715a33232b6688f186ab1b12052abaf5826f8ce5`.
Custody weight became **0** and SY increased from **0** to **`117153341`** raw units.
A repeat claim reverted and did not change SY. Source phase was **2** (Wrapped).

The proportional vault-share conversion is source-specific: weight consumes claim-vault shares, and those 19-decimal shares redeem to SY. It is not a 1:1 weight/SY conversion. Remaining-unit reads are `balanceOf(holder)` / `balanceOf(custodian)` on TokenStaking, plus claim-vault `balanceOf(TokenStaking)` and `totalSupply()`.

Full-run partial token custody used the following exact quantities:

| Source | Surrendered raw `q` | Holder raw remainder after custody | Custody remainder after attempted harvest |
| --- | ---: | ---: | ---: |
| Claim vault | `2769125838408621163` | `274143458002453495139` | `0`; received `276912584` SY |
| Earlier SE | `2402083350942343165016427703439986226` | `237806251743291973336626342640558636382` | Same `q`; no proceeds |
| Earlier LP | `1075167226680908457977200216751522` | `106441555441409937339742821458400691` | Same `q`; no proceeds |
| Weighted WETH SE | `23634291028048331275075` | `2339794811776784796232463` | Same `q`; no proceeds |
| Weighted DTF SE | `1622646459016401842967981100000000` | `160641999442623782453830128900000000` | `0`; received `162264645901640184296798` DTF |
| Weighted LP | `15166467477246491` | `1501480280247402651` | Same `q`; no proceeds |

For each row, wrong-operator `transferFrom` reverted, holder approval succeeded, then custodian `transferFrom` succeeded with exact holder/custody deltas. Remaining units were read back, not inferred from calldata.

## Failed routes and required-behavior verdicts

Pinned registry reads mark the earlier SE and weighted WETH SE disabled; the other five matrix sources are not effectively disabled.

- **Earlier SE harvest FAIL:** WETH and DTF exact-in exits revert `0x1ba84b43` plus the source address, matching `VaultDisabled(address)` in `contracts/interfaces/IVaultRegistryDisableQuery.sol:13`.
- **Weighted WETH SE harvest FAIL:** both SY redemption and Standard Exchange exact-in routes to both WETH and DTF produce the same source-specific disable error.
- **Earlier LP harvest FAIL:** exact-in exits to earlier DETF and DTF revert `0x5d5fe824`, matching current `UnsupportedRoute()`. The actual bound native `withdrawSeShares` also reverted, with `NotOwner(custodian)` (`0x245aecd3`). Its current owner reads as the earlier DETF, `0xaf0E1967c8F755c747615c5427108Bc549CA1122`.
- **Weighted LP harvest FAIL:** all five declared single outputs through both bound exact-in methods revert `NotOwner(custodian)`. Native `exitProportional` and `exitProportionalFlexible` also revert with the same caller. Its owner is the weighted DETF, `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7`, and `ownerOnlyLiquidity()` reads **true**. No role or source ownership was changed to manufacture a PASS.

Native failed receipts include earlier LP
`0x1fc18e1c68581f11d2eab00d4e6ee1020bd699dd6d4b124f1bd5e92726ab9b36`,
weighted proportional
`0x907c88a4a1c017b13b12a35dabd5e06ec1d5caefcf940499b6f8273ea2576e06`,
and flexible
`0x4ab538ea64295736b32a289811d1f875f967dbae0b0602f9bf6baea54003d24d`.
All measured output-token deltas are zero and custody LP balances remain unchanged.
These are failures of the enumerated routes from the new custodian, not proof that every possible legacy owner-mediated recovery is impossible.

| Required behavior | Verdict / boundary |
| --- | --- |
| Authenticated chain/block/source routing and fork runtime identity | PASS at the separately labeled fresh pins; historical code/state authenticated through Alchemy, with historical custody still UNPROVEN after HTTP 429 |
| Stale runtime identity rejection | PASS for the offchain probe guard; not proof of a future onchain guard |
| Claim surrender without surviving original-holder right | PASS for atomic source `reassign`; original weight zero |
| Claim extinguishment and custody receipt | PASS for staged `withdrawClaim` into SY |
| Zero and claimed positions | PASS: zero reassignment, zero claim and second claim revert |
| Wrong owner/operator redirection | PASS: claimant attacker cannot reassign or withdraw victim weight; all six fungible unauthorized pulls revert |
| Failed outer operation rolls back successful inner source calls | PASS: one claim and six fungible transfer tests |
| Share/LP harvest | Source-specific PASS/FAIL above; no blanket support |
| Atomic custody plus migration credit/fresh bond | UNPROVEN: source `reassign` exposes no operator pull or migration callback; no integrated issuance implementation is tested |
| Immutable postactivation proportional contribution ancestry | UNPROVEN: neither balances nor this offchain history/manifest is an authenticated onchain attribution mechanism |
| Exhaustive eligible exposure / proof of absence | UNPROVEN: no standalone accepted-source holder census and complete acquisition/transfer ancestry are established by the frozen ledger |
| Runtime teardown | PASS; see cleanup receipt |

Rollback tests deploy a small local-only runtime that calls the authentic source and then deliberately reverts. They do not replace or etch the source. Step traces show the outer helper's inner CALL returning `0x1`, followed by failed transaction status and unchanged source balances/allowances. The claim test additionally preserves supply **`15338080546808403036783930`**, claim-vault shares **`276912583840862116302`**, custody weight and SY. Its trace contains **199800** steps; each fungible rollback trace contains **874** steps. Identical transaction hashes can recur across snapshot-isolated cases because nonce, helper address and outer calldata are restored; use case name, block hash, helper runtime and receipt together.

Current-source explanatory anchors are `TokenStakingTarget.sol:184-209` (`reassign`), `:289-306` (`withdrawClaim`), under `contracts/protocols/staking/token/`; and `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Target.sol:97-110`. These explain the tested mechanism without asserting legacy bytecode equivalence.

## Reproduction and limits

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01`.
Executable: `scripts/recovery/dtf-migration/phase01/other-sources/probe.mjs`.
Before commands, create a new owned root using:

```sh
RUN_ROOT=$(mktemp -d '/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/other-sources.XXXXXX')
export TMPDIR="$RUN_ROOT" BUN_INSTALL_CACHE_DIR="$RUN_ROOT/bun-cache"
export npm_config_cache="$RUN_ROOT/node-cache" XDG_CACHE_HOME="$RUN_ROOT/cache"
```

The required command was initially run without a login shell:

```sh
bun scripts/recovery/dtf-migration/phase01/other-sources/probe.mjs --chain-id 4663 --block 108944663 --rpc-alias robinhood_mainnet_alchemy --local-fork --output docs/incidents/2026-09-16-dtf-recovery/migration/evidence/other-sources/probe
```

Each JSON records its literal invocation and binary PASS observable. Reproduce the full fallback using the same arguments with `--rpc-alias robinhood_mainnet_public` and a new output prefix. The native invocation in `probe-native.json` additionally uses `--block 110860459 --native-lp-evidence docs/incidents/2026-09-16-dtf-recovery/migration/evidence/other-sources/probe-public-r3.sources.json`. Replaying that pin still requires its state to be available. `--summarize <result.json>` generates the compact summary and independently reads registry disable state at the result's pin; summary exit 0 does not turn a source FAIL into PASS.

For Alchemy, run the same probe inside **`/bin/zsh -lc`**, with the absolute worktree cwd and owned TMPDIR/cache exports inside that shell. Check only `test -n "$ALCHEMY_KEY"`; do not print the value or expanded URL. Authenticated retries used output prefixes `probe-alchemy` and `probe-alchemy-r2`, preserving every original result. Child logs are redacted after complete lines are assembled so a split stream chunk cannot expose the credential. No Anvil child reached this logging path during the throttled retries.

Exact serialized retry:

```sh
bun scripts/recovery/dtf-migration/phase01/other-sources/probe.mjs --chain-id 4663 --block 108944663 --rpc-alias robinhood_mainnet_alchemy --local-fork --output docs/incidents/2026-09-16-dtf-recovery/migration/evidence/other-sources/probe-alchemy-r2
```

Its full login-shell invocation and both failure receipts are recorded in `alchemy-retry-receipt.json`. The previous public historical-state failure and every earlier fork receipt remain unchanged. Retry cleanup is recorded separately in `cleanup-alchemy.json`.

A full-run PASS requires exit **0** and `overall=PASS`; the observed exit **2** is intentional for unresolved assertions. Public RPC methods are read-only. Sends, impersonation, snapshots, helper deployment, explicit mining and traces use only the owned loopback Anvil. Every case restores its snapshot; Anvil is terminated in `finally`. Summarization may regenerate runtime caches, so final run-root cleanup is still necessary after all commands.

`node --check` and executable-mode checks PASS. Fresh Native LSP diagnostics repeatedly timed out after 3000 ms; final LSP diagnostics are unverified. No Forge build/test was run: no production Solidity changed, and the local rollback helper needs no compilation.

No product contracts, other lanes, PRD, plan, frozen incident inputs, linked libraries or dependencies were edited. No commit, deployment or public transaction occurred. This evidence does not alter original-contribution quoting, remaining-principal awards, fresh 90-day cliff bonds, or irreversible activation configuration rules. It supplies no postactivation trusted root, signature, source-admission update or substitute pricing policy.

## DoneClaim

- **Status:** delivered with concrete source and harness blockers; E1/E2 and implementation readiness are not claimed closed.
- **Changed files:** the executable above; this report; `cleanup-receipt.json`, `alchemy-retry-receipt.json`, `cleanup-alchemy.json`; all result, source, summary and Anvil-log files enumerated in the execution table. All are inside the two owned directories.
- **Exact tests/probes and outcomes:** recorded invocations in each result; final public full run 21 PASS / 4 FAIL / 3 UNPROVEN, native exits 2 FAIL; initial non-login Alchemy environment failure superseded by two login-shell retries that authenticated historical state but exited 2 / UNPROVEN on HTTP 429; syntax/executable checks PASS.
- **Evidence paths:** `probe-public-r4.json`, `probe-public-r4.sources.json`, `probe-public-r4.summary.json`, `probe-native.json`, `probe-native.summary.json`, `probe-alchemy.json`, `probe-alchemy-r2.json`, their source JSON, `alchemy-retry-receipt.json`, and both cleanup receipts.
- **Cleanup:** original five owned Anvil PIDs absent and ports closed; authenticated retries started no Anvil children or ports. Original and retry caches/roots removed with separate read-back receipts. No shared resource removed.
- **Risks:** historical Alchemy custody acquisition hit HTTP 429 despite authenticated state access; disabled SE exits and legacy-owner LP restrictions; infrastructure-fixture versus user-authority distinction; integrated atomic issuance and authenticated contribution ancestry remain unproven; final LSP diagnostics unavailable. Credential availability is no longer an open blocker.
