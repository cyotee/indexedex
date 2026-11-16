# Finite E2 native-surface closure

Continue the same phase06 worktree/run, preserving all four completed nodes
and their artifacts. Read phase06-e2-brief.md and the complete independent
`migration/attribution-feasibility/verification/report.md`, especially
sections1.1 and7.1. Overall E2 remains unproven. The examined completed-parent
plus selected-observation construction is already rejected; do not rerun its
balance witness or propose it again.

## Exact deliverable

Close the finite question named by the verifier: at the observed ArbOS61 and
reported pinned Nitro revision, does any ordinary-contract-callable native
method authenticate an ordered executing-prefix commitment at the caller's
actual execution position?

Start from verification/native-surface-scope.json. Inventory all18 registered
ArbOS families and every version-enabled callable method. Bind address,
selector, implementation, version/context/caller restrictions, fields read,
and data dependencies to source update points. Include relevant Geth opcode
hooks; distinguish RPC interception, debug/owner-only entrypoints, counters,
caller-provided values and completed-block roots from authenticated current
prefixes. Do not count inaccessible or inactive methods as Migration powers.
Use pinned primary sources and existing runtime observations.

Producer writes only
`migration/attribution-feasibility/native-surface/contract.md`,
machine-readable method inventory and supporting evidence under that directory.
No production/test edits or protocol change. State the completeness of the
method inventory and exact source/runtime binding limitations. An RPC build
string is not attestation of every native handler.

If a candidate method exists, identify exact address/selector/update point
before requesting any new execution. A genuine native-prefix probe requires
faithful Nitro execution; ordinary Anvil cannot prove it. No Forge/Nitro build
or new environment is authorized without an indispensable concrete root
decision. A no-candidate result must cover every admitted method and its
relevant dataflow, not infer absence from filenames or a text search.

This is a finite capability audit, not another open-ended cryptographic search.
An absence result rejects the native-prefix-oracle hypothesis within its
source/runtime scope. It does not itself prove arbitrary E2 mechanisms
impossible. If the source/runtime binding cannot be closed, name exactly what
is unbound and the finite next check; do not fill it with a trust assumption.

Independent verifier writes only
`migration/attribution-feasibility/native-surface-verification/report.md`
and supporting evidence there. It checks inventory completeness against the
registration/ABI/version gates, traces any claimed eligible commitment to its
producer, and challenges exclusions. It gives confirmed-no-native-prefix,
confirmed-candidate-requires-runtime-proof, or unproven-binding, with exact
scope and remaining original E2 obligations.

Both nodes retain inputs and commands, use only read-only network/source
inspection unless a concrete new probe is admitted, and capture runtime
cleanup. No commits, delegation, policy relaxation, repeated successful
probes, source omissions, public transactions or installed attribution API.
