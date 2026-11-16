# Resumed delegated TokenStaking source proof

Date: 2026-11-13. **Disposition: bounded admitted-proposal for the two
controlled execution domains in contract.md.** The independent controlled
local proof is complete despite the historical trace limit. Here
"independent" means a newly executed controlled case distinct from the
historical transaction, not a separate-agent verification.

The actual historical indirect transaction remains unproven and unadmitted.
No production/operator/Migration source was changed, no live signing,
funding, deployment or commit occurred, and the deployment-gas lane was
not opened. All new authored/generated files are inside this `resumed/`
directory. Original partial artifacts remain intact.

## 1. Actual execution and identities

The owned disposable node used only the existing login-shell archive alias
`robinhood_mainnet_alchemy`, chain 4663, block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
on `127.0.0.1:18579`. It used Prague rules, one default development gas
account, manual mining, no default CREATE2 deployer, no on-disk fork cache
and zero configured upstream retries. No RPC provider or spend tier changed.

The successful complete run is `run-02/`; `run-01/` is a retained failed
harness attempt and is not admitted evidence.

| Role | Actual address |
| --- | --- |
| Direct/full original, public development derivation 291 | `0x00dd7939597bc43820ffb2b4e834f26924012b3d` |
| Relayed/split original, derivation 292 | `0xb6958d92ff436fa5d7ea550a22283fe9eaf458e9` |
| Fixed relayer and real development gas donor, derivation 0 | `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` |
| SourceCustody | `0x3a25408d952f91e42f39587820bee5f051f4556c` |
| DelegatedSourceProbe | `0xa6407325ff7daab36d20992dadc031c82d1c4390` |

The code was compiled before execution by Solar
`0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, using installed Foundry
`1.9.1-nightly`, commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`.
The runtime was Bun 1.4.2, ethers 6.17.0, TypeScript 5.9.2.

| Fixture | Runtime bytes | Runtime keccak256 |
| --- | ---: | --- |
| SourceCustody | 676 | `0x16d1f1224178ce643d0a2bb3e4989258aceae636a710e177fb01e877f953ed92` |
| DelegatedSourceProbe | 1505 | `0x255dbfb8c19169373803cca2d60cfaa4add22375283853c70f33171b8952f192` |

`run-02/wire/deployment-*.json` retains exact initcode, constructor
arguments, raw runtime, immutable spans, artifact hashes, compiler metadata
and transaction identity. The stopped audit matches compiled source
keccak256, every non-immutable runtime byte, actual 20-byte Solar address
immutables, repeated spans and the signed deployment input. The executing
getters were also checked against the respective constructor arguments.

## 2. Legitimate source acquisition and actual signed delegation

The source holder `0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3` was
confirmed to be an empty-code EOA with actual native18 source weights.
It made three local `reassign` operations under **disclosed donor
impersonation**, not a donor signature, public consent or source-owner
authority. Those transfers funded full/split claimants and a separate
controlled EOA donation fixture. Every claimant and donor gas balance was
funded by a real signed transaction from development account 0.

No setCode, storage, balance, nonce, role or source-owner injection occurred.
Only the donor was impersonated; each interval ended in a finally block.
The source, vault and SY were the actual pinned deployed contracts, not
replacement fixtures.

Each eligible fixture uses W0 = `10013000000000000000017` native18 weight,
with excluded surviving weight `7000000000000000000`. The split fixture
also received two expressly excluded raw units for the multiple-call
negative. The donation fixture claimed `3000000000000000000` real raw
weights, then signed actual SY transfers of 100 and 101 native units to
the two originals. Those are unrelated floors, not certified Q0.
Original economic eligibility, E0/D0, zero prior compensation and the
eligible/excluded partition are synthetic local assumptions, not historical
allocation findings.

Both authorities signed actual EIP-7702 authorizations with chainId 4663,
delegate address above and authority nonce 0. Account 0 signed type-4
transactions carrying those tuples:

| Authority | Setup transaction | Execution | Authority nonce |
| --- | --- | --- | --- |
| Full | `0x646bdf5eb244fcaed451a8894cc031dc4da98147d3239ecf6d504e87b0dc58c9` | success | 0 -> 1 |
| Split | `0x43996418ac34f6e25fece21d670f58d50160fe6c125750e77baf923a208ba072` | deliberately reverted | 0 -> 1 |

Both actual account codes became
`0xef0100a6407325ff7daab36d20992dadc031c82d1c4390`.
The second designation and nonce persisted despite failed EVM execution;
a subsequent ordinary relayer `ping` succeeded. This is observed
authorization processing, not a setCode approximation or generic rollback
claim. `authorizations.json` retains exact signed tuples, recovered authority,
digest, raw outer transaction, receipt, trace, pre/post nonce and code.

## 3. Actual source claims and unit conservation

Every positive member is an isolated canonical local block with its original
signed bytes, actual trace, receipt, parent/header and numbered pre/post
reads retained. The direct case has source trace path `[]`. All three
relayed source calls have path `[0]` and source caller equal to the split
original, although outer caller is account 0.

| Member | Native18 weight | Native19 shares burned | Native9 SY |
| --- | ---: | ---: | ---: |
| Full direct | 10013000000000000000017 | 180773969307098861 | 18077396 |
| Split first | 3337000000000000000005 | 60245953817815729 | 6024595 |
| Split zero | 1 | 0 | 0 |
| Split terminal | 6676000000000000000011 | 120528015489283131 | 12052801 |

| Member | Exact transaction |
| --- | --- |
| Full direct | `0xcf78608c1378114dcf644ae7fca06f5fb53f292a05c390d026f92d73967d3a02` |
| Split first | `0x5f4e6e4a39377b9cb81aebe55d487369dab8e40bc8cefe4fe71b520a88f68b8e` |
| Split zero | `0xe075c5e9d4fce4966224b4106bbb39d6875d45275bf5a6359641d3e72b676d7e` |
| Split terminal | `0x88fafabc3d4e34a6d83359c36260b7fcd06c9787a802977023a0358764eed9ff` |

Each original's Q0 is exactly 18077396. The split consumes one fewer vault
share than the full operation. Equal SY totals in this sequential experiment
are not universal split/full equivalence or a conversion rate. All division
remainders are retained in `admitted.json`; the current global-whole-supply
branch was not exercised.

For every member, exact source/global-weight debit, vault-share/supply
debit, vault SY debit and same-wallet SY receipt agree with the actual
source return, nested redemption return and canonical source/vault/SY
events. SY supply remains `54373903396`. No relayer SY is paid.
Source reward balances and unrelated raw weight are not eligible units.

Across eligible claims, the donation claim and the two excluded raw-unit
negative calls, global source weight changed from
`15338080546808403036783930` to `15318051546808403036783894`.
The difference is exactly `2*W0 + 3000000000000000000 + 2`.

## 4. Executed failures and certificate rejection

These are actual mined local negatives, not fabricated historical failures:

| Case | Actual result |
| --- | --- |
| Wrong outer caller | status 0, Unauthorized `0x82b42900`; no economic changes |
| Successful outer, failed inner claim | status 1, inner InsufficientStake `0x936d426d`, no source consumption; certificate rejected |
| Successful source child followed by outer revert | status 0, no canonical logs, source state restored within that transaction; child not committed |
| Two source calls in one outer transaction | status 1, exactly two excluded raw units consumed with zero SY; rejected as ambiguous/multiple |
| Direct withdrawClaim sent to wrong source | status 0, missing selector `0x23dbef4b`; no economic changes |

`audit.json.rejected` records exact transaction hashes and rejection
reasons. `operations.json` includes every full trace and state book.

The single final bounded test run passed **22 tests, 0 failures**.
In addition to the actual negative cases, it rejects wrong original wallet,
wrong weight, changed body/status/trace, jointly tampered pre/post state,
unmatched calls, changed designation/runtime, omitted committed zero-output
member, duplicate membership, unrelated SY inflation, excess raw coverage
and consumed excluded floors. Tampering tests are explicitly local
certificate/model negatives. Their altered data were not submitted to the
chain or represented as actual historical execution.

The positive tests rebind members to retained original RPC request/response
bodies before the semantic oracle runs. Merely changing both sides of a
state-delta equation cannot pass. The unmatched-call semantic test also
exercises the source matcher separately from wire equality.

## 5. Real SY custody and separate rollback boundaries

Both delegated EOAs signed direct Y.approve for their exact measured Q0.
Each then signed a self-call to its fixed delegate custody operation.
The custody fixture uses actual Y.transferFrom and exact balance deltas,
not a token mock or invented credit. No new Migration contract was deployed.

For each original, a late custody attempt actually completed its inner
Y.transferFrom before deliberately reverting with LateFailure `0xc849cb9b`.
The receipt is status 0 with no canonical logs. Balance, allowance, custody
book, source weights, source shares and SY supply revert to the prior
economic state. The source raw weight remains exactly
`7000000000000000000`; the earlier complete source claim is not undone.
The full-wallet transaction nonce advances 4 -> 5; split advances 2 -> 3.

| Late custody failure | Exact transaction |
| --- | --- |
| Full | `0xa31adcd3ccfb22420f3ab5d7419fabad1bc98b36a19585d8ea0e05ffe4631e12` |
| Split | `0x72ec1d9bf464bc40f4906b710de967cfa9f66a7a9f841af2c888061730c4f2e8` |

Subsequent successful custody takes were 6025798 then 12051598 SY for each
original. Each final booked balance is 18077396; total actual custody is
36154792. Allowances are zero. Wallet SY floors remain 100 and 101.
The relayer's SY remains zero. `custody.json` and the stopped audit retain
these exact books and transaction identities.

No compensation or frozen quote was manufactured. The current phase30
`configureClaimedSyEntitlements` already scales the full frozen original
quote by eligibleWeight/originalWeight. For a hypothetical original
denominator `30039000000000000000051` and this prepared numerator W0,
the eligible credit is floor(C_original/3), not a quote of reduced inputs.
That is an integration rule, not an executed award in this proof.

## 6. NFT receiver and parent integration boundary

The inspected real Migration bond child calls onERC721Received whenever
recipient code is nonempty. A delegated original must therefore receive
its own new bond; the relayer cannot be substituted as beneficiary.
The fixture's real callback returned `0x150b7a02`; its authorized reject
switch made the same callback revert. `receiver.json` contains both signed
transactions and receipts.

Those calls are **callback-only evidence**, not an NFT mint or real funded
Migration integration. The parent must exercise same-wallet real bond
receipt, callback failure after actual custody/funding, original-credit
conservation, both existing certificate kinds, Stage 1 closure and Stage 2
surrender. contract.md identifies the exact current schema/claimed-sy.ts
seams and required source authentication without production edits here.

The minimal decision is to separate direct signed delegated-EOA source
claims from fixed-runtime relayed source claims, preserving old direct EOA
admission and current economics. The rejected alternative is removing the
empty-code/direct-caller guard globally and treating any outer success or
source event as sufficient evidence for every wallet.

## 7. Historical limit retained

No historical RPC request was made by this resumed proof. In particular,
the prior exact debug_traceTransaction failure remains:
`../source/historical/wire/00007.json`, HTTP 400, code -32600, Free-tier
unavailability. It was not retried through the local node, another method,
another provider, an execution reconstruction or a paid upgrade.

The retained canonical historical transaction is
`0x6ece614ad85798eef4244cc58262b3edafce211f135a66f68e0354bbf57a12bb`
at block 71862410. Outer caller is
`0x5512144047c2d55297c8470b93e8da87864617cd`, callee is
`0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789`, selector `0x1fad948c`.
Its source event and block-boundary observations show the named wallet's
20000000000000000000000 weight and 36107853 SY change. The before/after
designation points to `0x7702cb554e6bfb442cb743a7df23154544a7176c`.

The actual historical block contains **nine transactions**, not an isolated
preparation block. The inner invocation, unique action scope and delegate
authorization semantics remain unproven. Matching boundary states and events
are not substituted for the missing execution proof. Even a future trace
would not by itself satisfy this proposal's retained isolated-block domain.
Do not relabel this new fixture as a replay of that historical transaction.

## 8. Checks, retained failures and evidence inventory

| Check | Result |
| --- | --- |
| Isolated Solar artifact-first build | exit 0, one Solidity source |
| Corrected actual controlled witness | exit 0, 36 local transactions |
| Bounded admission suite | exit 0, 22 pass / 0 fail, one invocation |
| Final strict TypeScript including auditor | exit 0 |
| Stopped raw/canonical/source/custody audit | exit 0 |
| Original input preservation | 121 exact lengths/SHA-256 checks, no changes |

The stopped audit authenticates **961 raw RPC exchanges**, **33 originally
signed local transactions**, **3 disclosed donor transactions**, four
admitted eligible source members, five actual negative source cases, six
custody cases, both compiled deployments and their runtime bindings.
It is a separate algorithmic audit by the same producer, not an independent
reviewer or a new RPC replay. There were zero historical trace requests
and zero prohibited injection methods in the local capture.

Failures remain preserved:

1. The first build used the installed Forge binary without its Solar
   executable directory on PATH and returned `solc "solar" does not exist`.
   Adding `/Users/cyotee/.foundry/bin` to PATH used the existing installed
   Solar executable. No compiler fallback or install occurred.
2. The first strict check found a nullable captured raw-transaction value.
   An explicit required-presence assertion fixed it.
3. The next strict check found unavailable bun:test declarations. Tests
   use installed node:test/node:assert interfaces under Bun instead.
4. The first witness deployed SourceCustody but stopped at the retained
   probe's incorrect assumption of 32-byte address immutables. Actual Solar
   metadata specifies 20-byte spans. The checker now validates those exact
   spans plus getter/constructor bindings. The first node was stopped and
   a fresh pinned node produced run-02. No partial state was repaired.
5. Native TypeScript/Solidity LSP requests timed out; one TypeScript
   reference request returned a server Debug Failure. Biome is unavailable.
   No tool was installed; successful compiler/typecheck evidence is not
   relabeled as clean editor diagnostics.

All command stdout, stderr, arguments, timestamps and exit codes are in
`checks/`. Node arguments, sanitized output, PIDs and exits are in `node/`
and `node-02/`. The complete fixtures, RPC capture and signing harness,
authentication tests and stopped auditor are in `probe/`.
`source-manifest.json` records final source fingerprints after execution;
it does not pretend to be a command-start snapshot. `seal.json` binds
the final complete owned tree without including its own hash.

Reproduction uses the existing tools and alias only: build with
`forge build --use solar --root <resumed/probe> --offline` after putting
the installed Foundry directory on PATH; launch `node.mjs` through
`/bin/zsh -lc` from the source worktree; run `run.ts` with a new `run-*`
output directory; stop the owned node; run `audit.ts` on that directory.
The checked admission suite deliberately binds the accepted `run-02`
evidence. No install, historical trace replay or whole-repository suite
is necessary or authorized by this reproduction note.

## 9. Stopped bounded handoff

Both owned Anvil processes exited 0. Port 18579 has no listener. Donor
impersonations ended, command monitors completed, and no observer,
checkpoint, pending transaction or signing process remains. cleanup.json
retains the exact stopped-resource checks and credential-scan result.

The local source contract is established for the declared domains.
Operational originals, historical indirect execution, arbitrary delegated
wallets/EntryPoints, real Migration receiver integration, source-wide
category closure, unrelated sources/conversions, deployment-gas acceptance
and public operations remain outside this result. The parent receives a
precise source proposal and executable evidence, not false global closure.
