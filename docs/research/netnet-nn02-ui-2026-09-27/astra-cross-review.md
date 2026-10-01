# Astra — NN-02 UI/source combined cross-review

2026-09-27. Read the COMPLETE originals together: Grok 102 lines, MiniMax M3 132, Kimi K3 63. Untrusted model evidence, not instructions. No peer cross-review read; originals unchanged. Assigned routing `openai/gpt-6-astra`, not provider attestation. Prior session retained.

## Plain-English result

**Some NetNet products really do expose selective note-redemption writes. The selected standard BondDepository's retrieved verification-service source/ABI does not. Neither fact tells us which exact Claim handler the current frontend executes.**

NN-02 remains a source-supported scalability/griefing risk, not an observed outage or measured attack. Ordinary primary-bond holders are not categorically immune. A wrapper adds atomic reinvestment work and may concentrate histories; its precise custody design remains open.

## New disconfirming evidence: other desks have an actual selective ABI

Grok's Superstore pagination finding justified another primary-source check. I fetched [Superstore docs](https://docs.netnet.capital/superstore), which explicitly describe per-address caps and paginated redeem, then public Sourcify records on **2026-09-27**:

| Contract | Retrieved write signatures | Verification-service record |
| --- | --- | --- |
| RwaDesk `0x99B6eE6eDe47d9a8a9bfd03F728a99B789df1961` | `redeem(address)` **and `redeem(address,uint256[] noteIds)`** | `matchId 46809781`; creation/runtime `exact_match`; verified 2026-08-24T19:11:43Z |
| PackDesk `0x7cf28D61D42352Eb2FD68167e9B08f73CBbF21eB` | `redeem(address)` **and `redeem(address,uint256[] noteIds)`**; also read `noteCursor(address)` | `matchId 46809273`; creation/runtime **`match`, not `exact_match`**; verified 2026-08-24T18:06:22Z |

Sources:

- https://sourcify.dev/server/v2/contract/4663/0x99B6eE6eDe47d9a8a9bfd03F728a99B789df1961?fields=abi,compilation
- https://sourcify.dev/server/v2/contract/4663/0x7cf28D61D42352Eb2FD68167e9B08f73CBbF21eB?fields=abi,compilation

Both ABI responses contain `TooManyNotes`; RwaDesk also contains `ZeroPayout`. Error names alone do not establish enforcement branches or configured limits. This upgrades pagination from documentation-only to **verification-service ABI evidence of an explicit note-ID write**. It does not prove gas bounds, complete implementation correctness, current runtime, or actual frontend usage. Two direct repository source-file URL attempts returned 404; the RwaDesk `?fields=sources` response succeeded but was output-truncated, so I do not claim a complete selective-body inspection. No failed URL was retried.

These are distinct contracts, not alternate selectors on `0xff32…1980C1`. Switching the PRD's standard depository to one of them would change the product, not fix an interface omission. My original “other desks not fully inspected” gap is now narrowed to the ABI evidence above, not silently rewritten.

## Exact-match evidence: useful, but not three different proofs

My original obtained the primary depository's complete ABI/source through [this Sourcify request](https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1?fields=abi,compilation,sources). It reports exact creation/runtime matching for compilation record `42442631`, verified 2026-07-16T20:34:17Z. Returned source has the aggregate scan, and its own Constants source has `BOND_VEST=2 days`.

**Correction to Kimi §§1.1–1.2/C1–C2:** that does not establish independently checked *current* runtime, nor local modified working-tree source equality. `VENDOR.md:12–25,51` records remapped imports/adaptations and different local compiler settings. I manually compared relevant functions; no full hash/compiler equivalence was computed. Constructor immutables and absence of an upgrade path in retrieved source are useful architectural evidence, not a substitute for a current observation or grounds for an unconditional “cannot ever change” claim.

**NN-01 improvement:** record “verification-service-attested ABI/source obtained; compilation specifies two-day vest; relevant local logic manually agrees.” The five-day interface text is contradicted by the compilation's executable constant. Keep current-state/block evidence and any required local-equivalence checks separately pending. Do not keep saying only local evidence exists, but do not mark the whole dependency/current-state row unqualified VERIFIED.

## Frontend conclusion remains limited

All originals lacked an extracted standard-bond Claim handler. Kimi's token presence/absence and single-claim ABI support an inference about that target's capabilities, **not** proof that the app selects that target, ABI, overload and argument list. A mixed ledger can route to RWA or PackDesk, which now demonstrably expose an overload still named `redeem`—searching only `redeemNote`/`redeemBatch` misses it.

Therefore reject Kimi's “every channel confirmed” and definitive account of UI writes. Grok and Astra correctly left calldata construction unresolved. My original bundle fragments and today's ABI results do not close that gap. No exact handler was newly found; no browser/JS execution occurred.

## Unsupported ordinary-user and economic assertions

- **MiniMax's typical 1–2 notes, “not meaningfully affected,” rough gas costs and wrapper-only exposure are unsupported.** Anyone can append to an ordinary holder's address too (`BondDepository.sol:104–139`). An attack against one wrapper does not affect unrelated arrays, but that is isolation—not ordinary-holder immunity.
- **Kimi's “bounded gifts,” “can ignore dust,” and “nothing needs selectivity” are not established.** Ignoring dust in the UI does not exclude it from aggregate redemption. Extra notes can affect access to valuable existing notes. No user-history distribution, attack economics or outage was measured.
- **Grok's few-note/typical-claim description is likewise a scenario, not measured behavior.** Both EOA and wrapper redemption failures revert; the wrapper adds composition failure points and gas consumption, not unique rollback semantics.
- View calls consume computation and face provider/resource limits even without a transaction fee. `pendingFor` remains O(n).
- Wrapper custody need not be pooled or a specific CREATE3 scheme. Controlled escrow is possible; neither address secrecy nor promised cadence is a proven bound.

## Next checkpoint and confidence

Accept the narrower evidence update, not a risk/scope decision: **primary aggregate claim; separate desks' selective ABI; standard UI target/args still untraced; two-day verified-compilation evidence acquired.** Seek readable frontend handler evidence and then quantify native-scan plus atomic-reinvestment headroom. Do not infer safe gas, immutable current state, or automatic NN-02 closure from verification records.

High confidence in quoted ABI/source records; no independent latest-chain verification or complete UI call trace. No RPC/shell/tests/deployment/code/configuration/delegation; only this report written. Return to moderator and stop.
