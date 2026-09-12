# Product package migration for the Robinhood release

**Not a release approval.** Resolve the open gates in [RELEASE_REVIEW.md](RELEASE_REVIEW.md) before any broadcast. The salt/stage correction is currently prepared in `release-salts.patch`, not applied. This document describes that candidate change.

## Hook package interfaces

This release review does not require a new Orbital package initializer or deposit split. Those experimental changes are being restored to their pre-review working versions after verifying Robinhood's actual 98,304-byte runtime and 196,608-byte initcode limits. The same applies to the experimental Weighted/Curve size refactors. The previous agent's existing universal/CP package changes remain part of the candidate and must be included when compiling deployment arguments. Existing immutable packages and instances are not upgraded by recompilation.

## CREATE3 component identity

For the four reviewed hook families, universal DETF product facets/packages, V4 bond NFT facet/package, and rebasing claim facet/package, the candidate factory services derive:

```text
releaseSalt = keccak256(abi.encode(
    existing type-name namespace,
    keccak256(creation bytecode),
    keccak256(ABI-encoded constructor arguments)
))
```

Facet constructor arguments are empty. Caller-supplied hook package salts become namespaces for the release salt. Identical artifacts, links, and constructor arguments remain idempotent; changing any of those inputs selects a new address. Compiler settings, metadata, and linked library addresses therefore belong in the release manifest. Changing compiler output requires a new rehearsal and address record.

The hook services currently use compiler-linked public libraries. If Forge chooses fresh library addresses on another script run, the linked creation bytecode changes even when the Solidity source is unchanged. Preserve and explicitly supply the release's library links for repeatable addresses; do not describe source-only reruns with fresh automatic links as idempotent. A full staged rehearsal must verify this linking configuration.

This changes product-component addresses. It does not change the already deployed manager or factories, or the hook-instance `processArgs`/`calcSalt`/CREATE2 flag-mining rules. It does not migrate assets or alter existing pools. Existing immutable instances keep their original facets. A new package cannot overwrite an occupied hook-instance address; select and rehearse the intended new instance parameters through the existing package flow.

## Product stage behavior

The candidate mainnet wrappers for 06-01, 06-02, 06-03, 06-04, 06-06, and 06-07 always resolve their implementation-sensitive components. A JSON address with code can no longer cause those stages to skip new bytecode. Other stage behavior remains governed by the existing runner.

06-07 additionally checks the bond NFT and claim package names and compares the required product facet runtime against the compiled local artifact. The current recorded common `DETFNFTVaultDFPkg` is rejected. This check requires fresh artifacts; it is not a substitute for the source-hash gate.

The mainnet catalog currently provides CP, Weighted, and Curve Quad hook stages. A production Orbital stage and concrete launch configuration are separate work if Orbital is selected for the first mainnet release; the stage catalog must be amended through the repository's documented workflow.

## Release sequence

1. Freeze the candidate source, compiler configuration, library linking, concrete SE bindings, token addresses/decimals, fees, thresholds, and routing arguments. Record all hashes and package arguments. Use fresh `forge build` output followed by required hermetic tests.
2. Reconcile the existing foundation and authorities against Robinhood chain 4663. Preserve its addresses. The read-only findings here are dated observations and must be refreshed immediately before the rehearsal/release.
3. Rehearse 06-01 and 06-02, the selected hook package stages, then 06-07 against that existing foundation. Use the current staged runner's simulation workflow. Do not rely on the old runbook's same-salt collision claim: the actual CREATE3 factory can return old code successfully.
4. Check actual linked creation/runtime sizes, dependency facet bytecode, manager registry entries, package constructors and selectors, predicted instance addresses/flags, final removal of initialization/ownership selectors, and complete bond/mint/burn/close/claim behavior for each launch binding. Confirm the intentional economic policy for initially unclaimed backing.
5. Review the exact transaction plan and gas estimate before requesting live broadcast approval. This review has not requested or obtained that approval.
6. Export new product addresses and ABIs only after successful receipts and runtime identity checks. Retain the old deployment records as history. Do not replace foundation records to make a product migration appear complete.

New regression coverage checks legacy salt isolation, repeated deployment idempotence, constructor-sensitive package identity, preservation of the previous package's bindings, custom-close inventory isolation, and actual component size limits. The final report must record whether these tests executed and passed; their presence alone does not satisfy the gate.
