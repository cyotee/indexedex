---
description: Ask the Astra/Grok/MiniMax M3/Kimi K3 research council; research only, no code changes
agent: council
subtask: false
---

Research this human question using the council protocol:

$ARGUMENTS

If empty, ask for the topic. Preserve existing researcher sessions on follow-up.
For a full council round, obtain four independent first passes with the same question/context from Astra,
Grok, MiniMax M3 and Kimi K3. Collect all originals before sharing any peer responses.
Resume each original session once with the other three original answers together,
never earlier cross-review answers: four initial calls plus four combined
cross-review calls, eight total. Return evidence, dissent and a decision checkpoint
to the human. A missing or unresolvable ordinary read is not a participant
failure: record the path, do not retry that exact path, and continue the roster.
Stop without substitutes only when a researcher session fails or the guard
reports RC_ATTRIBUTION, RC_IDENTITY, RC_HISTORY, RC_COMPACTION, RC_EVIDENCE,
or a genuine SDK RC_UNAVAILABLE.
For an explicit targeted question or probe, invoke only the named members for
the requested turns and label the response as targeted, not council consensus.
All five agents author requested/assigned research reports, PRDs and implementation plans.
Create/update Markdown .md only under docs/research/, docs/plans/, docs/strategies/,
research/ or plans/. The moderator owns final consolidation; researchers write
distinct assigned outputs only. No peer artifact reading during independent passes;
preserve originals and never share earlier cross-review artifacts.
Writing a plan never authorizes executing it. No code implementation,
shell/tests/deployments, config/instruction edits, file deletion or moving.
Do not target secrets, instruction filenames, hidden agent/config directories,
symlinks or hardlinks. Report saved paths and stop at the human checkpoint.
