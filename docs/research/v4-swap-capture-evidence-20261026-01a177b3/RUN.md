# Council run record

## Run

- Run ID: v4-swap-capture-evidence-20261026-01a177b3
- Profile: research
- Council kind: full
- Question: Do actual deposit and exit swaps eliminate APEX-2026-012 when the only venue and reference are the underlying pool and its TWAP?
- Owner session: 01a177b3-f4ed-7770-9633-b5735573eb05
- Phase: published. All four originals and all four advisory feedback files settled. Draft ID draft-v4-swap-capture-evidence-20261026-01a177b3-r1. sha256 1813119f975b657c0214503b252bd9760f6d815f5305747c473f6baeaa078efe. Draft bytes were not edited after the advisory send.
- Publication state: published at REPORT.md. Resolution at coordinator/resolution.md.

## Authorization

- Source: explicit council directive in the current user message
- Implementation authority: none
- Prior artifacts preserved: yes. This run does not edit docs/research/v4-same-pool-swap-evidence-20261026-01a171a0 or docs/research/v4-swaps-independent-redo-20261026-01a17791.

## Coordinator

- Requested mode: invoking-agent
- Requested role: invoking session, not a vote
- Exposed model label in the eval kernel: PI_MODEL=gpt-6.1-sol
- Session persona text also names Grok 4.7. Those two labels are recorded as exposed text, not as two votes, and not as Native task metadata.
- Actual Native task identity of this coordinator: not a child task. Unavailable as a task ID.

## Preflight

- council-member exists in live ~/.omo/omo.jsonc with max_depth 2.
- This session is the root. Direct members need depth 1. Depth is sufficient. Live depth was not changed.
- MiniMax model override forceAdaptiveThinking true was read in ~/.omo/agent/models.json. The effective request payload is not yet observed.
- Isolation requested: false. No apply and no merge.
- Another session, 01a17791, has an in-flight redo of the same question. At preflight its Astra, Grok, and MiniMax tasks were completed, its Kimi task was still running, and its last coordinator turn had ended with a provider error. This run does not continue those tasks and does not write that root.

## Assignments

| Label | Logical assignment | Attempt | Requested model | Task ID | Status |
| --- | --- | --- | --- | --- | --- |
| astra | initial original | 1 | chatgpt-subscription/gpt-6-astra:high | st_01a177b9 | completed 2026-10-26T10:40:27Z; admitted chatgpt-subscription/gpt-6-astra:high, reasoning high; response.md present |
| grok | initial original | 1 | xai/grok-4.7:xhigh | st_01a177ba | completed; admitted xai/grok-4.7:xhigh, reasoning xhigh; response.md and model.py present |
| minimax | initial original | 1 | minimax/MiniMax-M3 | st_01a177bb | completed; admitted minimax/MiniMax-M3. Member reports PI_REASONING_LEVEL=high. Adaptive payload not observed. response.md and model.py present |
| kimi | initial original | 1 | kimi-coding/k3:high | st_01a177bc | completed; admitted kimi-coding/k3:high, reasoning high; response.md and model.py present |
| astra | advisory feedback | 1 | same conversation, epoch 1 | st_01a177b9 | completed; requested-changes; ASTRA-A1 through ASTRA-A7 resolved in coordinator/resolution.md |
| grok | advisory feedback | 1 | same conversation, epoch 1 | st_01a177ba | completed; requested-changes; G1-G5 recorded for the final, draft bytes unchanged |
| minimax | advisory feedback | 1 | same conversation, epoch 1 | st_01a177bb | completed; support-with-reservations; C1-C8 recorded; draft bytes unchanged |
| kimi | advisory feedback | 1 | same conversation, epoch 1 | st_01a177bc | completed; support-with-reservations; KF-1 through KF-3 resolved in coordinator/resolution.md |

No substitution is authorized if a provider refuses. A policy refusal is not a retry reason.
