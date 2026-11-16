# Preparation interface v1

Date: 2026-11-11. Source base:
`421072a7630a0d3d47a6f36e1062d9eae98c93e2`.

This is the exact post-capture interface consumed by the dependent execution
lane. Authoritative executable schemas are
`scripts/recovery/dtf-migration/schema.ts`; the returned TypeScript contract
is `PreparedDomain` in `preparation.ts`. Import paths use `.js` for the
repository's NodeNext resolution; Bun resolves the TypeScript source.

## Commands and acceptance

```text
bun scripts/recovery/dtf-migration/cli.ts prepare --input <file> --output <directory>
bun scripts/recovery/dtf-migration/cli.ts validate --manifest <file>
```

Both commands are read-only onchain. No signer, key, transaction submission,
approval, deployment, automatic retry, or RPC endpoint is persisted. The
domain's `rpcEnv` names a caller-supplied HTTP(S) RPC environment variable.
Each RPC request has a 15-second bound. Providers are destroyed on success
and failure. Synthetic inputs require a literal loopback hostname and remain
ineligible for any later nonlocal broadcast.

Success writes `independent.json`, `nfts.json`, then `manifest.json`.
The first two are review mirrors containing only full configuration inputs;
execution consumes only the validated manifest. All writes use exclusive
creation; reuse a new output directory rather than overwriting an accepted
dataset. A failed write can leave incomplete review mirrors, but without a
successfully returned manifest there is no accepted preparation result.

An unsupported, otherwise evidenced category writes `blocked.json` with
every category disposition and exits nonzero. It writes no executable
manifest or replacement dataset. Missing evidence fails before acceptance.
No category omission or zero-record count means zero economic exposure.

`validateManifest(path)` reparses the input and reconstructs the entire
manifest from current raw file bytes and pinned RPC reads, then requires
exact canonical equality. Its return value is the typed execution input.
Do not consume `JSON.parse(...).payloads`, review mirrors, or a hash alone.

## Input

All quantities, token IDs, sizes, chain/block numbers, and deadlines are
unsigned decimal strings smaller than `2**256`. Leading zeros normalize.
Numbers, blanks, fractions, negative values, exponents and null reject.
Addresses normalize lowercase; unknown object keys reject. A known zero is
explicit `"0"`; `contributionsKnown` must be `true`.

```typescript
type Category = "independent" | "weighted-nft" | "earlier-nft" |
  "weighted-liquid" | "earlier-liquid" | "weighted-receipt" | "earlier-receipt" |
  "weighted-sy" | "token-staking" | "claim-vault" | "underlying-se" |
  "fungible-lp" | "earlier-liquidation";
type PreparationInput = {
  version: "dtf-operator-preparation-v1";
  purpose: "synthetic-local" | "operational-review";
  domain: {
    chainId: string;
    proxy: string;
    snapshotId: string;        // actual captured bytes32, nonzero
    blockNumber: string;       // RPC/L2 block, not EVM BLOCKNUMBER
    blockHash: string;         // canonical RPC header at blockNumber
    rpcEnv: string;            // environment variable NAME, not endpoint
    snapshotArtifact: string; // fingerprinted artifact with migrationSnapshot ABI
    bindings: readonly {
      role: "proxy" | "registry" | "package" | "facet";
      address: string;
      codeHash: string;        // expected keccak256 runtime
    }[];
  };
  sources: readonly {
    id: string;
    path: string;
    sha256: string;            // lowercase, no 0x
    bytes: string;
    provenance:
      | { kind: "file"; authority: string }
      | { kind: "chain"; chainId: string; blockNumber: string;
          blockHash: string; contract: string;
          method: "eth_getLogs" | "eth_getTransactionReceipt" | "eth_call" | "eth_getCode";
          locator: string };
  }[];
  exposures: readonly {
    originId: string;          // bytes32; canonical nftOrigin for either NFT
    category: Category;
    originalUnits: string;    // positive; SOURCE-SPECIFIC unit
    descendants: readonly { id: string; units: string }[];
    recoveredUnits: string;
    excludedUnits: string;
    proof: Proof;
  }[];
  independent: readonly {
    recipient: string;
    evidenceId: string;
    entitlements: readonly { original: Original; proof: Proof }[];
  }[];
  nfts: readonly { original: NftOriginal; proof: Proof }[];
  issueRecipients: readonly string[];
  harvest: { steps: readonly RecoveryStep[]; deadline: string };
};
type Proof = { sourceId: string; pointer: string }; // RFC6901 JSON pointer
type Original = {
  entitlementId: string; originalEth: string; originalDtf: string; evidenceId: string;
};
type NftOriginal = {
  collection: string; tokenId: string; originalUnits: string;
  originalEth: string; originalDtf: string; evidenceId: string;
  contributionsKnown: true;
};
```

Paths resolve relative to the original input file and become absolute.
The snapshot artifact itself must be in `sources`. Each proof resolves into
the fingerprinted JSON file and must equal the complete original object.
Exposure proofs equal the full exposure object excluding its `proof`.
Raw reviewed-record objects must already use normalized field values.
An archive containing CSV or another source format can be retained as an
additional fingerprinted source, but is not silently interpreted as approved
JSON originals.

For each origin, `sum(descendant.units) + recoveredUnits + excludedUnits`
must equal `originalUnits` exactly. Descendant IDs cannot overlap across
origins. Each origin must have exactly one configuration use, of its
matching category; duplicate recipients and original identities reject.
NFT original units must equal the evidenced original basis. The independent
path requires reviewed, disjoint independent origins, never an unresolved
fungible remainder relabeled as independent. These file-integrity,
partition and identity checks do not prove the truth or completeness of a
reviewer's historical ancestry assertions. E2 remains open.

## Typed stage payloads

```typescript
type PreparedDomain = {
  version: "dtf-operator-manifest-v1";
  input: PreparationInput;
  normalizedHash: string;
  payloads: {
    configure: {
      independent: readonly {
        input: { recipient: string; evidenceId: string; entitlements: readonly Original[] };
        configurationId: string;
        quotedCredit: string; // EXPECTATION ONLY; never a setter argument
      }[];
      nfts: readonly {
        input: NftOriginal;
        configurationId: string;
        originalId: string;
        quotedCredit: string; // full original quote, NOT remaining delivery
      }[];
    };
    independentIssue: {
      requests: readonly { recipient: string; configurationId: string }[];
    };
    harvest: { steps: readonly RecoveryStep[]; deadline: string };
  };
  payloadHash: string;
  quoteEvidence: {
    snapshot: string;          // COMPLETE ABI-encoded actual snapshot result
    snapshotId: string;
    blockHash: string;
    quotes: readonly {
      originalEth: string; originalDtf: string;
      ethCredit: string; dtfCredit: string; credit: string;
    }[];
  };
  dispositions: readonly {
    category: Category; disposition: string; gate: string; records: string;
  }[];
  fullTask9: "open";
};
type RecoveryStep = {
  stage: "WeightedClaim" | "WeightedPrincipal" | "WeightedRewards" |
    "WeightedUnstake" | "WeightedConvert" | "EarlierClaim" | "EarlierSale" | "Donate";
  tokenId: string; amount: string; minimum: string;
};
```

`configureIndependentAllocations` receives only
`payloads.configure.independent.map(row => row.input)`.
`configureNftEntitlements` receives only the corresponding NFT `.input`
array. These are distinct transactions/setters and whole replacements.
Configuration does not issue. `issueIndependentAllocations` receives only
`payloads.independentIssue.requests`; unselected configurations stay unissued.
Actual emitted bond IDs and once-only consumption belong in the execution
journal, never predicted here.

The canonical independent tuple is
`(address recipient,bytes32 evidenceId,(bytes32 entitlementId,uint256 originalEth,uint256 originalDtf,bytes32 evidenceId)[] entitlements)`.
The NFT tuple is
`(address collection,uint256 tokenId,uint256 originalUnits,uint256 originalEth,uint256 originalDtf,bytes32 evidenceId,bool contributionsKnown)`.
For both, `configurationId = keccak256(abi.encode(chainId,proxy,snapshotId,input))`.
For NFTs, `originalId = keccak256(abi.encode("migration.nft",chainId,proxy,snapshotId,collection,tokenId))`.
Array order is canonicalized before these identities are calculated:
recipient, entitlement ID, then collection and numerical NFT ID. Recovery
steps retain their caller-selected execution order. These IDs match the
accepted `AllocationTarget` and `MigrationLegacyNftLib` contracts.

For `recoverMigrationNfts`, enum ordinals are exactly 0 through 7 in the
`RecoveryStep.stage` order shown above. Encode each as the genuine
`(uint8 stage,uint256 tokenId,uint256 amount,uint256 minimum)` tuple and pass
the common deadline. NFT stages use `tokenId >= 3`, `amount == 0`;
only EarlierSale permits a nonzero minimum. Conversion/donation stages use
`tokenId == 0`, positive amount; WeightedUnstake requires minimum zero.
The bounded selection is at most eight weighted claim steps, or one other
stage. This does not imply any arbitrary eight-stage transaction is safe.

Weighted conversion selection must use tracked attributed gons and the
source's synchronized divisor, plus bounded simulation. The stored native
inventory view is not a live preview and zero does not exclude accrued
recovery value. This payload selects an amount, not authority to spend the
proxy's whole balance. Execution must reconcile actual revaluation,
conversion and donation events separately from NFT claims.

## Pricing and fingerprints

At the pinned RPC header, preparation checks chain, every requested code
identity, the unique proxy binding and required registry/package/facet roles.
It reads the full actual `migrationSnapshot()`, decodes it through the
fingerprinted ABI, checks version 1, consumer, subject and chain, then
recomputes the snapshot's native seal with its ID cleared. No caller-provided
rate or credit is accepted.

For every distinct original ETH/DTF pair it separately calls
`previewOriginalCredit(E,0)`, `previewOriginalCredit(0,D)`, and
`previewOriginalCredit(E,D)` on that same frozen snapshot. The sum must match;
recipient totals use native integers and checked uint256 bounds. All calls
use the same explicit historical block tag and a final canonical-header
check rejects a changed block. No linear price surrogate or aggregate-before-
quote calculation is used.

Canonical JSON sorts object keys and normalized set-like arrays; it preserves
recovery order. `normalizedHash` is SHA-256 of canonical normalized input.
`payloadHash` is SHA-256 of canonical
`{independent,nfts,requests,harvest}`, with those exact keys. Individual
configuration IDs and snapshot IDs remain Keccak-256 ABI identities, not
JSON hashes. Paths and RPC environment-variable names are part of the
operational domain; relocating sources changes the normalized fingerprint.

## Boundaries for the execution lane

Deployment, funding and capture precede this post-capture manifest.
Their typed package arguments, genuine registry deployment, donation/genesis
transaction plans and source identities must be established by the execution
lane from actual source and fixed deployment inputs. Do not use a fabricated
snapshot ID to get through preparation. This interface adds no generic
target/calldata escape hatch and no source-category adapter.

The dependent lane owns all onchain stage commands, default simulation,
Anvil instance/fork guards, fresh broadcast confirmations, signer/nonce
intents, canonical receipt/state reconciliation and fresh-process resume.
It must bind checkpoints to both hashes and the domain, recheck exact
registry/package/facet relationships and installed selectors, and never
infer successful execution from preparation or a simulation.

Required blocked categories retained in every successful disposition report:
weighted/earlier liquid, weighted/earlier receipts, weighted SY, TokenStaking,
claim-vault rights, underlying SE shares, fungible LP, and earlier liquidation.
The first nine retain E1/E2 source/ancestry/composition limits. Earlier
liquidation retains SB-E1/E2/E3 disabled SE exits and SB-E4 unproved conversion.
Earlier NFT claim-and-hold/sale-and-hold are not earlier liquidation.
Operational funding, reviewed allocations, all-category task9, rehearsal,
resume, independent acceptance and release remain separate open gates.
