# Independent bounded verification method

This is the completed source-only witness, not an operator implementation.
The exact node command is in report.md section2 and raw/cleanup.json.
Start only after confirming no18572 listener; arm the readiness/exit monitor
with that command, and require its Listening line before RPC.

## Fixed control and transaction sequence

Use the existing installed ethers6 package and persistent Bun eval kernel.
All HTTP requests are POST to http://127.0.0.1:18572 with JSON-RPC2.0.
Capture the exact original request and response body strings and HTTP status,
including null results; parse only after retaining those strings. The sole
upstream access is Anvil's existing admitted alias bootstrap.

Require chain4663, the exact historical108944663 hash/state root, phase2,
claimVault=V, V asset=Y, V decimals19 and Y decimals9. Bind proxy/facet bytes
and actual facetAddress responses to the stopped producer and retained phase01
identities. Empty donor code and positive actual weight are separate checks.

Derive public development account0 and fresh controlled paths321/322 from
the public Anvil mnemonic `test test test test test test test test test test
test junk`. Capture all initial source/SY/share/reward balances and supplies.
Require both controlled wallets initially have zero weights and SY.

For each genuine signature:

```text
type0; chain4663; gasPrice2000000000; gasLimit5000000
nonce = actual eth_getTransactionCount(signer, latest)
sign first; retain original raw bytes; eth_sendRawTransaction
evm_mine once; read complete receipt, canonical transaction, callTracer
```

No automatic wallet population, estimate retry, polling or sleep is used.
Receipt status is explicit; a failed repeat is expected status0.

1. Account0 signs three actual gas transfers of1000000000000000000 wei to
   donor/full/split. No setBalance.
2. Impersonate only donor0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3.
   Its ordinary reassign sends10023000000000000000017 weights to each
   controlled wallet. Mine each and retain canonical receipt/trace/state.
   Always stop donor impersonation in finally before controlled claims.
3. Each controlled wallet genuinely signs withdrawClaim3000000000000000000;
   its measured5416 SY is excluded preexisting unrelated output.
4. Full signs withdrawClaim10013000000000000000017.
5. Split signs withdrawClaim3337000000000000000005. Record eligible remaining
   6676000000000000000012 and reject completeness despite positive output.
6. Split signs withdrawClaim6676000000000000000012. Now aggregate exact
   coverage is W0 and measured output is complete Q0.
7. Full signs another W0 claim; require status0, no logs and actual
   InsufficientStake(full,W0,U), with economic state unchanged.
8. Read-only call withdrawClaim1 from split; require exact zero return and
   unchanged state, without mining any dust claim.
9. Recheck actual proxy/facet bytes and nonzero selector bindings. Stop the
   owned node monitor; retain its completion and independently check no listener.

W0=10013000000000000000017, U=7000000000000000000 and excluded seed
3000000000000000000 are synthetic fixture inputs. They are not historical
allocation data, ETH/DTF contributions or frozen credit.

## State capture and independent raw checks

Each capture includes exact block number; donor/full/split T weights and stored
rewards; their Y balances plus T/V Y; their V balances plus T V; source weight
supply, vault supply, vault totalAssets and SY supply.

Before each successful claim read source previewClaim(wallet,q), actual
vault previewRedeem on computed shares and read-only withdrawClaim(q).
Capture before/after state, actual mined return/event and nested vault calldata.
Recompute q*Vn divmod Tn and shares*(A+1) divmod(S+10000000000), recording
numerator/denominator/quotient/remainder for both divisions.

Independently require:

- Wallet/source-supply debit=q, T-held-share/vault-supply debit=calculated
  shares, vault-SY debit=caller-SY delta=actual return=both previews.
- Decoded nested redeem receiver=source caller, owner=T, shares=actual burn;
  decoded ClaimWithdrawn wallet/q/output match canonical transaction and deltas.
- Unrelated wallet balances, direct user vault shares, stored rewards and SY
  supply remain unchanged during claims.
- Full eligible output excludes the seed; split aggregates actual outputs
  only after sum(q_i)=W0. Preserve both U and seed SY, not zero-total-wallet
  requirements. Equality of full/split output is an observation only.
- Complete transaction, receipt and callTracer objects equal their original
  wire responses, including every nested receipt log's transaction/block
  identity. Match by method/params/hash, not array position or global RPC ID.
- Every original raw signature decodes/recoverAddress to actual signer/hash,
  chain4663, nonce, to, calldata, value, gas and gas price. Original raw bytes
  must appear in an actual sendRawTransaction request. Donor fixtures are
  checked for real state movement but not represented as donor signatures.
- All 323 fields across17 snapshot references in each run match original
  eth_call responses at that exact block. Associate calls with the initial pin,
  each manual evm_mine increment, and explicit eth_blockNumber observations.
  No transaction is mined concurrently with a capture.
- Failed repeat economic states match excluding block advancement and native
  gas/nonce; exact error caller/requested/available match. Dust is read-only.

`probe/eval-method.md` records the actual core function bodies used in the eval
kernel. The audit covers both the stopped producer and this fresh run, without
trusting their serialized PASS flags. Missing zero-facet code reads are not
required: their actual loupe response is still required and empty-code Keccak
is checked. Source match/archive limits remain explicit.

## Preservation, stopped-file checks and seal

The17 producer-declared input byte bindings are independently verified before
the source run. Five additional references (complete phase11 contract and
producer seal/contract/report/method) are separately bound after the run;
the producer contract/report/method are already in the pre-run member seal.
The22 input references and11 producer members are compared unchanged again
at cleanup. These are declared-input checks, not a full host inventory.

All owned creations use apply_patch. Raw JSON is serialized once after the
node stops, retaining the original HTTP strings and signatures. Independently
parse the saved files and rerun both-run audit/state calculations on complete
raw text; no normalized digest substitutes for original byte hashing.

Enumerate every regular file recursively under verification, sort relative
POSIX paths, and exclude only seal.json. Seal each complete UTF-8 file's raw
byte length and SHA-256, including trailing newline. The seal's files array
must equal actual membership exactly. The seal does not self-hash.

Final read-only Git recipe uses GIT_MASTER=1/GIT_OPTIONAL_LOCKS=0 and
submodule-ignoring status/diff. Require unchanged exact HEAD, empty tracked
and cached diffs, no listener18572 and no owned pending operation. No build,
suite, Migration configuration or funding rollback is part of this method.
