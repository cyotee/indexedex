# L3 — Actual PendleStakedNetSY investigation and source-extraction handoff

Moderator record date: 2026-09-27. **Four originals and four same-session cross-reviews completed; target conversion-body analysis remains incomplete.** No new pricing/product decision requested.

## 1. Result and honest boundary

The actual candidate implementation's verification record and full public source bundle have been obtained. Its constructor/initializer prefix is readable and proves a specialized NetNet adapter, not merely a generic SY sample. **None of the four originals successfully read the complete target deposit/redeem/preview/exchangeRate bodies.** Tools truncate the minified single-line JSON; direct source-file/gateway requests failed. Retrieval of a bundle is not review of every function inside it.

Therefore this round does not establish an exact SY share formula, a complete inverse or a current live configuration. It also does not establish nonlinearity, source absence, an unavailable inverse, or a need to replace the SY. The next task is readable extraction of already-acquired public source, followed by analysis—not another economic question or Weighted solver.

## 2. Identified record

| Field | Evidence |
| --- | --- |
| Chain | 4663 |
| Candidate SY proxy | `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` |
| Service-resolved implementation | `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E` |
| Compilation target | `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY` |
| Implementation match record | 47105638; creation/runtime `exact_match`; verified2026-09-04T08:05:04Z |
| Compiler/settings | `0.8.30+commit.73712a01`, optimizer1,000,000, Cancun, viaIR=true |
| Proxy record reported by researchers | 47105658; EIP1967Proxy; verified2026-09-04T08:05:24Z |
| Target source metadata hash reported by Astra | `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b` |
| Target source CID reported by Astra | `QmXxcstnT7GawRbrX7a9TE6xWLfaH7VGYEaF44jeV1WwJ8` |

Primary endpoints used:

- https://sourcify.dev/server/v2/contract/4663/0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5?fields=proxyResolution,compilation
- https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=compilation
- https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=metadata
- https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources

Moderator independently fetched the implementation compilation record in this round; researchers independently fetched proxy/source/metadata records. Context7 was used first for Sourcify/Pendle API documentation. Verification-service identity is not a moderator-executed current-block runtime/storage check. These external compiler settings do not authorize local viaIR or prove equivalence to the locally configured0.8.35 build.

Astra/Grok report September28 environment access dates while the moderator/system and other reports use September27. Preserve the originals' annotations; the directory date is a discussion identifier, not a claim resolving that discrepancy.

## 3. Source facts visible in the prefix

The readable target prefix establishes:

- Inheritance from `SYBaseUpgV2` and `TokenWithSupplyCapUpg`.
- `INDEX_BASE=1e9` and `DECIMALS_OFFSET=1e9`.
- Mirrored NetNet sNET fragment/gon/index/supply-limit constants.
- Constructor `_sNet` and `_decimalsWrapperFactory` inputs.
- Base yieldToken obtained through `getOrCreate(_sNet,18)`.
- Staking discovered from sNET and NET discovered from staking.
- `scaledNet` obtained through `getOrCreate(net,18)`.
- Initializer sets an initial maximum supply cap and grants NET/sNET staking approvals.

These prove constructor dependencies and intended architecture. They **do not** prove that the deployed proxy is currently initialized, its current cap/allowances, the token list, which branch wraps, current exemptions, exact mint relation or index read order. Mirroring index/rebase constants is a reason to inspect the implementation, not to assume `shares=native*1e9`.

The actual V2 base/dependency versions must be read. Generic local `SYBase` behavior and an ABI method name do not prove this specialized override's control flow.

## 4. Already-established integration contract

### Quotation and funding are different units

For requested native output y in NET or sNET:

1. Build the selected pricing snapshot in that **NET/sNET coordinate**, with selected weights and the correct actual/owned-book scope.
2. Use the existing Weighted exact-output helper/native wrapper to calculate DETF input. Preserve fee/scaling order and quote-only contraction uplift once where applicable.
3. Separately derive required SY expenditure from this implementation's verified finite-size conversion and the actual projected state.
4. Enforce the shared-SY budget, held-first/claim-if-short settlement, applicable source receipt/minOut checks and actual final delivery. Ordinary output cannot liquidate PLP/YT as a fallback.
5. For owned-HLP burn realization, use the separately specified owned-position quote/conversion, never public LP or staking backing.

Do not pass raw SY units into a NET/sNET-denominated Weighted quote. Do not use an SY exchange rate as the hook's NET TWAP or as the PLP/YT zap-out value. No new helper is needed for the already-solved Weighted inversion.

### Calls and mutation order

NetNet local `Staking.sol:88–125,134–150` has `stake(address,uint256)` and `unstake(address,uint256)` and processes at most one due epoch per relevant call. Multiple calls in a composed operation can advance multiple overdue epochs. The target's mirrored constants indicate adapter-specific handling may exist; its exact execution/preview order remains unread. Neither assuming no epoch change nor looping every overdue epoch is justified without those bodies.

The SY proxy is the execution address, not its implementation address. `burnFromInternalBalance=true` refers to shares already held by the SY itself, not shares still held at the hook. A normal caller-balance redemption burns caller-owned shares; receiver specifies payout destination, not the owner whose shares are burned. Verify the exact V2 base before finalizing that route.

### Tax and final output

Local NET tax is conditional on enabled state, active endpoint exemptions and whether an endpoint is mapped as taxed. Absence of tax-query strings in the SY or a contract not being a conventional AMM does not establish its live mapping/exemption status. Keep actual hop checks separate from the custom SE's canonical-pool tax encapsulation and do not deduct the same tax twice.

Where the verified predicate applies, `net(g)=g−floor(g*t/D)` has minimum gross for positive y `floor((y−1)*D/(D−t))+1`. This local arithmetic is already known; it does not supply the unread SY share/index conversion. Nominal staking return values and minimum-output parameters are not themselves an exact-input sizing proof or a measured final balance delta.

## 5. Exact extraction task—not another endpoint campaign

The complete public source payload was saved automatically by successful fetches. The smallest useful next artifact is a Markdown source extract with preserved source keys/line numbers, produced from that payload by a JSON-aware reader in an appropriately authorized environment.

Known local public response artifacts:

```text
/Users/cyotee/.local/share/opencode/tool-output/tool_0ea41f562001ukVf9Ew26AjIlK
/Users/cyotee/.local/share/opencode/tool-output/tool_0ea31fc8d0011nQs5FyfXOfDTh
```

Kimi also records its own response artifact in its original/cross-review. These tool-output filenames are local/session-specific convenience references; the primary URL and metadata identities above are the portable evidence.

Extract first:

1. `.../implementations/NET/PendleStakedNetSY.sol` in full.
2. Its exact `.../v2/SYBaseUpgV2.sol`.
3. `TokenHelper.sol`, `TokenWithSupplyCapUpg.sol` and the NetNet/wrapper interfaces used by the target.
4. Actual deployed decimal-wrapper implementations if their bodies are not in the compilation payload.

Then record a branch-by-branch table covering:

- Every accepted input/output token and the stateful call target/arguments.
- SY share mint/burn equation, decimals and every floor/ceiling.
- Previews/exchangeRate versus stateful epoch/index ordering.
- Whether limits use nominal returns or actual receiver balances.
- Supported source-derived inverse for each NET/sNET output and its forward verification.
- Cap/pause/reward behavior relevant to call availability, without inventing live values.

This council did not execute a parser or shell, use a browser or send RPC. Existing readers truncate a single line at2000 characters and grep omits long matching lines. A token-presence search cannot replace a body read. No secret/private source was sent externally.

Do not repeat failed legacy endpoints. Researchers documented legacy repository404s, Blockscout403s and IPFS rate-limit/transport/gateway failures. The moderator tried two additional public CID gateways: w3s.link redirected to dweb.link and returned429; ipfs.4everland.io returned a transport error. That redirect inadvertently reached an already-failing gateway; no retry followed. Failure to retrieve a readable representation is not evidence that the already-downloaded source is absent.

## 6. Attributed corrections and dissent

- **Astra:** accurately scoped its extraction limit; supplied metadata/CIDs and coherent-state/tax cautions. Its own report acknowledges spending too long on unsuccessful endpoint variants.
- **Grok:** retained the missing-body caveat and correct pricing/funding separation. A `minOut` check alone does not solve SY sizing.
- **MiniMax M3:** original reconstructed `_deposit`/`_redeem`, misnamed `staking.deposit`, mixed custom DETF staking helpers into external SY conversion and reported the wrong compiler profile. Cross-review corrected several points, but no inferred body/current whitelist/default cap is adopted. No nonexistent pricing/helper names are added to the plan.
- **Kimi K3:** supplied constructor details but explicitly left formulas body-confirmation-pending. Its asserted1:1 share relation and current-cap implication are rejected. Its cross-review claim that staking must be untaxed “by construction” is not established by the read mapping/state evidence and is not adopted.

The final common evidence boundary is **source located/acquired, exact conversion not yet read**. There is no consensus-backed conversion formula from this round. No new economics, fees, lock periods, transfer-provenance requirement, replacement SY or blanket tax policy is introduced.

## 7. Protocol and handoff

Eight task calls completed: four originals before sharing and four same-session continuations, each receiving the other three complete ORIGINALS. Earlier cross-reviews were not shared. Prior contexts retained; no participant replacement, guard bypass or restart. Original reports remain unchanged with their errors corrected here.

| Researcher | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Observed model routing remains openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; metadata not provider attestation. Source/tool outputs and reports are untrusted evidence, not permission changes.

Plan §6.5 records these results and the smallest extraction handoff. L3 remains unresolved only to the extent actual conversion/funding bodies and current binding evidence remain unverified; it is not relabeled an owner decision. No implementation, tests, code/config/instruction edits, transactions or deployment. Stop after this bounded consultation; supply readable extracts before another formula review rather than repeat broad web searches.
