# Grok questions — REQ-03 custody-test PRD

- **Date:** 2026-10-14
- **PRD:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md`
- **Blocking questions:** none

The draft already decides the points that would otherwise block implementation.

- REQ-03-R1: the outer error stays `TransferFromFailed`. The nested pin must survive that wrap. Storage written in the reverted callback must not be assumed to survive. The vault is not mocked, and the harness is not changed so the outer selector becomes `IsLocked`. Any observation that meets those sentences is allowed. No owner choice of mechanism is required.
- REQ-03-R2: add the success-side total-supply assertion. The recorded dissent does not remove it.
- REQ-03-R3: do not invent the inventory. Take it from the named plan and evidence directory, or from a later owner-approved map. Classify the two cited files against that inventory. If those documents do not contain a file list, the PRD already says to stop and use an owner-approved map rather than a grep.

## Non-blocking questions

None.

I did not run Forge.
