# Bounded reproduction and evidence verification

This is the source-only witness at unchanged
`4eaa7decab80d24cf37cb3781eff5ffaf9362942`, not an operator run.
Do not execute a cumulative rehearsal, deploy a helper, restore a snapshot
from another task, or replay old suites/direct-pull negatives.

## Fixed bootstrap and authority

The exact login-shell Anvil command is in `report.md` section 1. Its only
endpoint is loopback18572; alias, chain4663 and historical block108944663
are fixed. First require no existing listener. Subscribe to the node's
`Listening on 127.0.0.1:18572` event before making source calls. Require
the recorded header hash and state root from `raw/source-identities.json`.
Use the existing installed ethers package; no install is necessary.

Read deployed proxy/facet code and `facetAddress(bytes4)` bindings, T phase,
T claimVault, V asset, V/SY decimals, and the donor's empty code/positive
weight before acquisition. Fixed addresses are listed in `contract.md`.
Current explanatory Solidity must not be substituted at any deployed
address.

Derive development account0 and controlled derivations221/222 from the
public Anvil mnemonic. A fresh independent verifier can use fresh
controlled derivations and must retain its own actual raw signatures;
matching producer hashes is not required and is not proof of a fresh run.
Never impersonate those controlled claimants.

Manually mined signed transactions in this witness use:

```text
chainId = 4663
type = 0
gasPrice = 2000000000
gasLimit = 5000000
nonce = actual eth_getTransactionCount(signer, latest)
```

Sign first, capture the exact original raw bytes, submit with
`eth_sendRawTransaction`, call `evm_mine`, then obtain the complete receipt,
canonical transaction and `debug_traceTransaction` callTracer result.
No receipt polling, retry loop, timing sleep or reconstructed signature is
needed. Check receipt status explicitly.

Account0 signs three transfers, each 1000000000000000000 wei: donor, full
claimant, split claimant. This pays gas through real transactions; no
setBalance call is allowed.

## Exact acquisition and claim sequence

1. Capture all initial balances and supplies below. Both controlled
   wallets must start with zero source weight and SY.
2. Start impersonating **only** the existing EOA donor. Its two ordinary
   `reassign` transactions send 10023000000000000000017 weights to each
   controlled wallet. Each is mined with gas5000000/gasPrice2000000000.
   Capture canonical transaction, full receipt, trace and state deltas.
   Always stop donor impersonation in `finally`. Label these as local
   impersonated donations, never donor-key consent.
3. Each controlled wallet signs `withdrawClaim(3000000000000000000)`.
   The 5416 SY output observed for each is the excluded positive
   preexisting SY floor, not part of its eligible original.
4. Full wallet signs `withdrawClaim(10013000000000000000017)`.
5. Split wallet signs `withdrawClaim(3337000000000000000005)`.
   Record explicitly that 6676000000000000000012 eligible weights remain.
6. Split wallet signs `withdrawClaim(6676000000000000000012)`.
   Only now is its eligible original complete.
7. Full wallet signs another `withdrawClaim(10013000000000000000017)`.
   Require its actual status0/InsufficientStake and unchanged source
   economic state, except advancing block/nonce and spent gas.
8. Read-only simulate `withdrawClaim(1)` from the split wallet. Record its
   zero return without mining that dust claim or touching protected U.
9. Compare actual deployed proxy/facet bytes again with initial bytes.
   Stop the owned node and readiness/exit monitor. No snapshot,
   checkpoint, helper contract, subscription or runtime directory is
   needed.

The synthetic original W0 is 10013000000000000000017; excluded surviving
weight U is 7000000000000000000. The donor's reassigned quantity also
contains the excluded seed. These are fixture partition inputs, not
historical allocation records.

## State and claim arithmetic

Capture for donor/full/split:

- T balanceOf and stored rewards.
- SY balanceOf; also SY balances of T and V.
- V balanceOf; also V shares held by T.
- T totalSupply, V totalSupply, V totalAssets and SY totalSupply.
- Exact block number.

Before each positive claim, obtain source `previewClaim(caller,q)`,
V `previewRedeem(floor(q*V/T))`, and a read-only
`eth_call` of the actual `withdrawClaim(q)` from the signer. Do not use a
preview as a substitute for the actual receipt or output.

For every mined successful claim, assert:

```text
caller weight debit = source supply debit = q
T vault-share debit = V supply debit = floor(q*V/T)
V SY debit = caller SY increase = actual uint256 return
source preview = vault preview = simulated return = actual return
SY total supply unchanged
other recorded wallets' weights and SY unchanged
```

Decode the actual nested `redeem(uint256,address,address)` call and
`ClaimWithdrawn` log. Require receiver = source caller, vault owner = T,
shares = measured burned shares, and exact q/output in the event. Do not
infer the recipient just from output size.

For weight-division arithmetic retain numerator `q*V`, denominator T,
quotient and remainder. The explanatory vault arithmetic is
`shares*(A+1) divmod (S+10000000000)`; retain that full numerator,
denominator, quotient and remainder separately and compare its quotient
with actual preview/return. This is an observed five-point fit, not
byte-identical legacy source verification.

Full eligible Q0 is its measured SY delta. Split Q0 is the sum of the two
measured eligible deltas. Exclude each seed's 5416 SY and U. Equal totals
in this run do not authorize extrapolating to another original or state.
Keep one original quote C0, not a new quote per source transaction.

## Offline checks on the stopped handoff

All evidence files are UTF-8. Parse `raw/wire.json`; each row contains the
exact `request` and `response` body strings plus HTTP status. Require
status200, JSON-RPC2.0 and matching IDs **within each HTTP exchange**.
Some independent concurrent reads reuse an ID across different HTTP
requests; no batch or global-unique-ID claim is made. Match results by
request method/parameters and transaction hash, not response array index
or ID alone.

For every entry in `raw/transactions.json`, require complete canonical
transaction/receipt/callTracer equality with the corresponding original
wire response. Compare all receipt fields, not just status/hash. Require
all nested log transaction/block identities to agree with their receipt.
For all nine `raw` entries:

```text
ethers.Transaction.from(raw).hash = keccak256(raw) = recorded hash
recoverAddress(unsignedHash, signature) = actual signer = receipt.from
chainId = 4663
decoded nonce/to/data/value/gasLimit/gasPrice = canonical transaction
canonical block hash/number/index = receipt block hash/number/index
```

The other two entries are labeled impersonated donor operations. Verify
their actual source/caller/quantity and state movement, not a fictional
donor raw signature.

Recompute every observation's actual state differences and both divmod
records. Sum consumed weights, burned shares and received SY from the
observations, not producer PASS flags. Recheck protected floors, the
incomplete first split, actual failed-repeat state, and exact same-caller
vault/event decoding against raw transactions.

Rehash every path in `raw/input-preservation.json` against its complete
original bytes and lengths. `raw/cleanup.json` records the later
unchanged comparison. The input manifest is scoped to its 17 declared
files, not a claim of an inventory audit of every ignored file on this
host.

`seal.json` uses sorted relative POSIX paths. Its `files` array must equal
all files recursively under this owned `source/` directory except
`seal.json` itself. For every member check raw byte length and SHA-256,
including trailing newline. A hash of a parsed/normalized JSON object is
not a substitute for a raw-file digest.

Actual cleanup uses lsof18572 (no listener), unchanged exact HEAD,
tracked diff exit0 and cached diff exit0 with submodules ignored.
The monitor's kill/completion and donor stop RPC are distinct evidence.
Do not remove or stop another task's resources.
