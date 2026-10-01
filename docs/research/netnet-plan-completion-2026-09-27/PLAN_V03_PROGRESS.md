# Plan v0.3 authoring progress and limits

Date: 2026-09-27. Documentation-only continuation of the user's request to finish the existing plan.

## Added in place

The plan now fixes custom holder/NFT/hook operational signatures and typed limits/snapshots, enumerates standard V2 interface/cut reuse, specifies caller/component phases and reciprocal initialization states, and distinguishes supported funding token pairs from internal subshares. No arbitrary target/calldata forwarding, second native purchase, caller-selected subshare mint or proxy-owner transfer is introduced.

The remaining creator-address source is not guessed: the reference Universal package reads `args.creator` (`UniswapV4DetfDFPkg.sol:258`), whereas this custom PRD selects a three-address instance PkgArgs. A plan cannot silently pick the deployer, feeTo or a new configuration field without reconciling that source. This is a specific configuration-source omission, not an invented administrative power.

## Additional mathematical investigation

Astra was asked for a targeted check of a live-computed conservative divisor as a possible L1 resolution. Same session `ses_f1c499b6bffe6RiNjZZUSMsP8S`, original identity preserved, no code/execution/delegation. The [result](../netnet-balance-rebase-2026-09-27/astra-live-divisor-targeted.md) proves positive-domain native deposit/transfer/withdrawal and zero-dust recipient identities, but also records differences from literal PRD B/U, allocation-dust behavior, full-exit ordering and empty-state/saturation consequences. It is not adopted or represented as full-council consensus.

This makes the L1 limitation more concrete; it does not justify declaring the existing formula solved or changing it silently. The earlier statement that the plan could simply be finished without any further semantic disposition was too confident. Remaining safe derivations are author work; a real model-semantic change still needs explicit authority.

## New external-source evidence for L3

After Context7 lookup of Sourcify's read-only contract-record API, the moderator fetched on 2026-09-27:

1. https://sourcify.dev/server/v2/contract/4663/0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5?fields=abi,compilation,sources
2. https://sourcify.dev/server/v2/contract/4663/0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5?fields=proxyResolution
3. https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=abi,compilation,sources
4. https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=compilation

The service identifies the candidate SY as an EIP1967 transparent proxy and reports implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, named `PendleStakedNetSY`. The implementation compilation identifier is `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`, compiler0.8.30, optimizer1,000,000, Cancun, viaIR enabled in that external build. These are external compilation settings, not permission to enable viaIR locally.

Proxy record47105658 reports exact creation/runtime match verified2026-09-04T08:05:24Z; implementation record47105638 reports exact matches verified2026-09-04T08:05:04Z. This is verification-service/proxy-resolution evidence, not an independently block-pinned current runtime or permanent implementation binding.

The implementation's full JSON source response was retrieved but the tool output was truncated (~121KB); the target conversion function bodies were not extracted and inspected in this continuation. A grep of the saved public tool response returned an omitted long line, not readable source evidence. Attempts at two Sourcify individual-file paths and the corresponding public raw GitHub main path returned404; exact failed URLs were not retried. **Do not claim the actual inverse is verified from the compilation name or from retrieving unread source.** The new evidence identifies the precise next source target rather than inventing an SY implementation.

## Delivery state

Only plan v0.3 and documentation pointers/status were edited. No code, shell/tests, direct RPC, browser/JavaScript execution, transactions, deployment or instruction/config changes. Public verification-service data contains no credentials; none were sent externally. No obsolete report or accidental sibling was deleted.

The plan is more concrete, but not fully finished/executable. It still exposes exact L1–L4 and binding/source requirements instead of assigning unsafe choices to the implementer. The next human checkpoint must be honest about that limit; no new claim of completion is supported by these reads.
