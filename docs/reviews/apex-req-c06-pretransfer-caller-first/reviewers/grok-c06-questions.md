# Grok — REQ-C06 questions

Read `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` only. No other reviewer notes.

No blocking question.

The 21 measurement lines, the true-flag check, the `prepaid` versus `pretransferred` guard, the V3 move, the ten caller-first sites, EtherFi, Slipstream, and the deleted legacy V4 tree are named. The three assertions are named: code-less true-flag short credit reverts `EOAPretransferNotAllowed` and moves no tokens; an allowed contract caller with short credit still reverts the existing credit error and moves no tokens; a false flag does not revert `EOAPretransferNotAllowed` only because it has no bytecode. The plan names the existing production-proxy test for each of the seven files and does not invent a file. That is a plan task, not an owner decision.

I did not run Forge.
