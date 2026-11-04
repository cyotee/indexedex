# WeirVaults source-import PRD — publication receipt

## Result

Published the owner-requested standalone PRD at:

`contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md`

Revision: `weir-import-prd-final`.

The PRD specifies a faithful import of WeirVaults, WeirBase and its GPL LiquidityAmounts into the requested directory, with 37 normative requirements and 69 acceptance rows. It covers exact source/ABI fidelity, 22 direct-import rewrites and five free-struct constructions, versioned V5 dependency selection, source and resolved-graph licensing, real-manager lifecycle/accounting/fee/idle/native/recipient/guard behavior, precise errors and rollback boundaries, deterministic campaigns, and separately pinned local fork parity.

The later ERC20, Rate Provider, Diamond/SE and already-unlocked-hook adaptation is excluded. Characterization tests preserve actual source limitations rather than silently repair them.

## Council evidence

The four exact routes completed independent originals and one same-task advisory:

- Astra: `chatgpt-subscription/gpt-6-astra:high`.
- Grok: `xai/grok-4.7:xhigh`.
- MiniMax: `minimax/MiniMax-M3`; adaptive setting not exposed.
- Kimi: `kimi-coding/k3.1-pro:high`.

All advisories were SUPPORT WITH CORRECTIONS. Final wording is coordinator synthesis after resolving every material concern, not a second approved council draft. Original disagreements and incorrect proposals remain preserved and explicitly disposed of in `coordinator/resolution.md`. Actual Native task/ancestry/delivery metadata and process deviations are recorded in RUN.md.

All originals and advisories are preserved under `members/`. Grok needed one original delivery-format repair; its advisory required no additional turn. MiniMax's original used harness write despite the apply_patch-or-inline boundary; that deviation is recorded rather than claimed compliant. Its advisory returned inline correctly.

## Verification

- All 39 saved source-reference files matched retrieved SHA-256 bytes.
- Frozen r1 remains unchanged: `633e430bd6b551c9cabc3147ad9d3275f07534ac50364b30503392f161829b51`.
- Saved final PRD was read completely and matched the prepared final: 608 lines, 89,394 characters, SHA-256 `790ed337b2ec2b2067c13fa7460f94d2a5916c6b27878fa6e18437615681b845`.
- Unique IDs: 37 WI requirements, 69 AC rows. ABI inventory matches the fetched metadata: 27 functions, 11 events, 18 errors, plus constructor and payable receive.
- Source-derived integer anchors were independently calculated, not executed as tests.
- Requested destination contains only the PRD, not production Solidity.

No Forge build/test, runtime transaction, fork, deployment, configuration change or Git commit occurred. The document does not establish economic safety, actual compiler/runtime parity, deployment readiness or legal clearance. Those remain explicit future import/release gates, not missing work from this documentation assignment.
