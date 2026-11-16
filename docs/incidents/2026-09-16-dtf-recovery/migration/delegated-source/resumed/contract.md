# Bounded delegated TokenStaking source-admission contract

This is a source-engineering proposal, not production intake, a configured
entitlement, an operational original, or a Migration award. The parent owns
integration. It does not admit the historical indirect transaction merely
because this controlled wallet works.

## Authorities and fixed source

The current primary plan sections 1.3, 1.4, 1.6 and 1.8 govern. In particular:
the original acquiring wallet must control and surrender the eligible asset;
configuration is not compensation; all eligible raw preparation must be
complete before dependent Stage 1 configuration; actual surrender is Stage 2
only; one canonical original retains its full contribution quote.

Only chain 4663 is examined. The controlled fork is pinned to block 108944663,
hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
This is not the new funded reserve snapshot.

| Role | Address | Source unit |
| --- | --- | --- |
| T, TokenStaking | `0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00` | native18 caller-owned accounting weight, not approved-pull ERC20 |
| V, claim vault | `0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0` | native19 shares; T-owned shares are backing, not another user claim |
| Y, SY | `0xb55604cf4dcdabb362078e106d20f98512391edf` | native9 static SY |

Require phase 2, T.claimVault = V, V.asset = Y, V.decimals = 19 and
Y.decimals = 9. Retain all actual used selector/facet/runtime bindings.
The fixed proxy runtime hash is
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
T withdrawClaim uses facet `0x9c90d4a476f3473b9a0e32b530af3474271a80b1`,
hash `0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742`.
V redeem uses `0x517234f78a4bcafc5f880024a3e45d49cf43b305`,
hash `0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f`.
Y transfer uses `0x4b6e65cfc9a16aae0dfa4257a680f4697275e5fc`,
hash `0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d`.

The current explanatory source is TokenStakingTarget.sol:184-209,289-306
and RebasingAwareERC4626Common.sol:145-159. The actual legacy bytecode is
not asserted to be a recompilation of those current files. Observed calls,
returns, canonical logs and source-native state changes are the bounded
behavioral evidence; no new legacy source-equivalence claim is made.

## Distinct execution domains

Keep the existing direct empty-code EOA domain unchanged.

**D1: direct signed claim from an already delegated EOA.** A recovered original
wallet signature sends an ordinary zero-value transaction directly to T with
exact `withdrawClaim(q)` calldata. There is no authorization list in this claim
transaction. The successful trace root is the source invocation itself.
Pre/post wallet code is the same exact 23-byte `0xef0100 || delegate` designation,
and the delegate runtime identity is captured. The source subtree must contain
only the admitted source/vault/SY operations and must not execute the claimant's
wallet code. Thus the source claim does not rely on a delegate's relayer policy.
This is not permission to call an arbitrary wallet method or assert that it
can receive a new bond.

**D2: one relayed fixed `claim(q)` through the reviewed local delegate.**
The outer signer is the fixture's fixed relayer, the outer destination is the
original wallet, and its exact entry calldata is the reviewed `claim(q)`.
The actual source CALL's `from` is the original wallet, never the relayer.
Require stable pre/post designation and the exact reviewed runtime including
its bound full/split wallets, relayer, fixed source/SY and custody. Verify
the separate signed chain-4663 EIP-7702 authorization and its canonical
inclusion, established designation and authority nonce effect. This proof
does not admit the historical EntryPoint, arbitrary execute/batch methods,
other delegated wallet implementations, ordinary deployed contract wallets,
multiple source calls per member, or same-transaction delegation changes.

The controlled delegate has no arbitrary target, calldata, delegatecall,
Migration executor, withdrawal destination, credit loader or beneficiary
argument. Its additional failure probes are negative-test methods, not
positive certificate entrypoints. Neither `catchClaim`, `doubleClaim` nor
`claimThenRevert` is a positive D2 member.

Delegation authorization signs a chain/address/nonce tuple, not arbitrary
application intent or runtime bytes. The reviewed deployment, runtime and
constructor bindings supply the latter identity. Do not equate a designation
address with authenticated delegate semantics.

## Member authentication

For either domain, fetch evidence anew from the selected authoritative RPC
when integrating. Uploaded self-consistent receipts or hashes alone do not
authenticate it. The retained local HTTP captures support this experiment,
not an independent public-chain attestation.

1. Recover and bind the exact signed outer bytes, chain, hash, nonce, from,
   to, value and calldata. Require canonical transaction, successful receipt,
   exact header membership and canonical parent. Retain the current isolated
   block restriction: exactly this transaction, index zero. Recheck block
   identity after authentication.
2. Fetch the actual call trace. Count **all** CALL attempts to T's
   withdrawClaim selector, including failed attempts; require exactly one.
   Do not count T's internal proxy DELEGATECALL as another source invocation.
   Match exact input q, source caller, actual returned SY and a successful
   ancestor chain. A reverted ancestor makes a successful child uncommitted.
   A successful outer transaction does not prove successful inner execution.
3. Match one committed nested V.redeem(shares, originalWallet, T), return
   equal to source return, and one Y.transfer(originalWallet, SY) from V.
   Reject unmatched/multiple vault or SY actions. A path locator identifies
   a frame but cannot replace counting all candidate frames.
4. Match canonical receipt ClaimWithdrawn, V share burn, V Withdraw and
   Y Transfer by address, topics, exact native quantities, recipient and
   transaction/block/log identity. Reverted trace logs are not receipt logs.
5. At the exact parent and member blocks measure:
   wallet and global T weight debit = q; T-owned V share and V supply debit =
   shares; wallet Y increase and vault Y decrease = returned SY; Y supply
   unchanged. Preserve rewards, unrelated donor/relayer balances, claimant
   V shares and custody accounting. No wallet-wide increase is substituted
   for this source output.
6. Authenticate fixed source routing, code, phase, asset and unit bindings
   before and after. For D2, also authenticate its wallet runtime/permissions
   and constructor identities; unchanged outer code alone does not prove them.
7. Preserve the reviewed unrelated raw-weight and SY floors. A late unrelated
   donation cannot enlarge certified Q0. Historical ownership, original
   contributions, exclusions and zero previous compensation remain separate
   reviewed facts, not consequences of signature, trace or current balance.

The local arithmetic is independently checked as:

```text
shares_i = floor(q_i * sourceVaultShares_before / globalWeight_before)
SY_i = floor(shares_i * (vaultSY_before + 1)
             / (vaultShareSupply_before + 10000000000))
```

Both quotients and remainders are retained in actual evidence. These are
bounded observed source conversions, not contribution prices. The global
whole-supply branch and universal equality of split/full output are not proven.
Positive consumed weight with zero shares/SY is a committed member.

## Original conservation and current phase30 contract

Keep these distinct:

```text
W_original = reviewed complete original native18 weight denominator
W_eligible = reviewed still-eligible native18 remainder
sum(q_i) = W_eligible, including every committed zero-output member
Q0 = sum(actual eligible SY_i), positive native9 measured SY
C_original = frozenPreview(full E0) + frozenPreview(full D0)
C_eligible = floor(C_original * W_eligible / W_original)
```

Complete-original certificates use W_original = W_eligible. Complete-remaining
certificates retain the full denominator and exclude disposed or previously
compensated portions. Existing known-zero prior-delivery admission and reviewed
alias exclusion are not broadened into arbitrary inherited-credit support.
No current price, raw-to-SY ratio, donated SY, old rewards or infrastructure
backing is added to E0/D0. Never quote reduced contributions or create a new
original ID per member.

The current phase30 code already implements the required scale:
UniswapV4DetfMigrationAllocationTarget.sol:162-180 stores original/eligible
weights and scales the complete frozen quote. preparation.ts:74-82,
payloads.ts:137-149 and execution-plan.ts:63-66 preserve the same basis.
Delegation changes source authentication, not this arithmetic or ABI.

After complete preparation and loading, ordinary remaining-Q/remaining-C
SY surrender remains:

```text
c = C if q == Q, otherwise floor(C * q / Q)
Q' = Q - q; C' = C - c
delivered + remainingCredit = C_eligible
```

No numerical new credit or funded snapshot is generated by this source task.

## Exact minimal integration edits recommended

Paths below are relative to
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts`.
These are recommendations, not edits performed here.

**scripts/recovery/dtf-migration/schema.ts:61-103.** Preserve certificate
kind and review fields. Add an optional strict member-level execution
discriminant; absence retains the existing direct empty-code EOA meaning:

```text
execution:
  { kind: "direct-eip7702-v1", delegate, delegateCodeHash }
  OR
  { kind: "relayed-eip7702-fixed-claim-v1",
    delegate, delegateCodeHash, outerCaller, sourceCallPath,
    authorizationSetup: {
      transactionHash, rawSignedTransaction, blockNumber, blockHash,
      authorityNonceBefore, authorityNonceAfter
    } }
```

Use existing address/hash/uint validators and bounded nonnegative integer
path components. In D2 `outerCaller` is checked against reviewed delegate
permissions, not accepted as user-chosen authority. Runtime hashes need a
reviewed supported wallet binding, not an unchecked uploaded hash. The local
fixture's bound runtime is the only D2 implementation demonstrated here.
Do not make an arbitrary runtime hash an allowlist.

**claimed-sy.ts:130-191.** Replace the single direct-only branch with the
three explicit domains while retaining common canonical/isolated, source,
unit, state, log and output checks. D1 keeps originalWallet == signed.from
and signed.to == T; only the empty-code condition changes to authenticated
stable delegation. D2 binds the outer signed body separately from actual
source caller/input/output. Traverse with a path and ancestor commitment bit;
count all source attempts before selecting the unique committed frame.
Authenticate the separate setup under actual EIP-7702 nonce semantics.
Never simply remove the code guard or compare outer.from to the relayer
in place of checking source.from == originalWallet.

**claimed-sy.ts:49-95,193-252.** Retain complete eligible weight coverage,
zero-output membership, positive measured Q0, cross-original transaction
uniqueness, snapshot domain, raw signed evidence commitment, current control,
excluded floors and the complete configured-origin census. The existing
evidenceId function already includes the whole certificate: new execution
fields become committed naturally. Missing execution data must not downgrade
a delegated case into ordinary SY.

**provenance.ts:67-74,103-116; quotes.ts:88.** Retain complete-record reviewed
file authority, no certificate stripping/nested-proof downgrade, and RPC
authentication before quote/configuration. No new production contract,
arbitrary beneficiary, raw-weight approved pull, pricing formula, mutable
postactivation entitlement or Migration executor is needed for this proposal.

Parent integration must exercise both certificate kinds and retain old EOA
tests. Add actual delegated direct and fixed-relayed preparation, all source
negative cases, preconfiguration rejection without owner nonce advancement,
partial/terminal real Migration surrender, exact funded bond beneficiary,
same-wallet receiver rejection and late rollback. This source gate does not
claim those integrated transactions happened.

## NFT receiving and rollback

Current bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:29-43 calls
onERC721Received for every recipient with nonzero code, including a 23-byte
delegated EOA. The invocation comes from the child bond contract with
operator = parent, from = zero, tokenId = newly funded position, data empty.
It must return `0x150b7a02`; failure reverts the enclosing issuance.
Source claim success therefore does not establish Migration compatibility.

The local delegate contains a callback and an authorized reject switch
solely for receiver testing. Its callback tests do not mint a real NFT or
establish that the historical delegate implements receiving. The later real
integration must use the original wallet as recipient and test success and
atomic failure after real custody/funding. Never redirect the bond to the
relayer to evade a receiver failure.

Source preparation is an earlier completed transaction. A later failed
custody transaction restores its SY movement, allowance and custody book,
not previously consumed raw weight. Gas and transaction nonce are not restored.
EIP-7702 setup is a separate boundary: authorization processing changes the
authority nonce and designation even when subsequent EVM execution reverts.
The controlled setup explicitly exercises that distinction.

## Historical limit

The retained ../source/historical/wire/00007.json contains HTTP 400, RPC -32600:
debug_traceTransaction is unavailable on the provider's Free tier. It was
not retried, proxied, reconstructed or replaced.

Historical transaction
`0x6ece614ad85798eef4244cc58262b3edafce211f135a66f68e0354bbf57a12bb`,
block 71862410, records ClaimWithdrawn for
`0x2c0400cf47e5ea01364e44c237aed22d7ae86199`, weight
`20000000000000000000000`, SY `36107853`. Its outer caller/callee differ.
The designation before/after and at the source pin is
`0xef01007702cb554e6bfb442cb743a7df23154544a7176c`.

Those authentic retained observations support a delegated-account lead, not
the actual unique inner invocation, authorization policy, complete execution
scope, current control or operational eligibility. No inspected byte-exact
legacy source invariant replaces the unavailable inner trace here. Therefore
this historical transaction remains outside both proposed admission domains.

Primary protocol/API references read: EIP-7702
(`https://eips.ethereum.org/EIPS/eip-7702`), ethers v6 official Wallet/Authorization
documentation, and the installed ethers authorizeSync/hashAuthorization/
verifyAuthorization implementations. Installed APIs, exact compiler identity,
failures and local observations are recorded in the accompanying report.
