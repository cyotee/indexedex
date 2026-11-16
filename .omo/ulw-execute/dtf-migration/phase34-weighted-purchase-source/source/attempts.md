# Retained preparation diagnostics

No owned proof/syntax/reproduction command failed. Their exact command/stream receipts are retained.

- A tool-rendered JSON read was truncated with an ellipsis, so parsing that rendered text failed before evidence interpretation. Complete bodies were read through the file-read helper instead. No input changed.
- A report-table preparation cell referenced an undefined WETH kernel name. It wrote nothing. The explicit admitted public WETH address corrected that preparation step.
- The unpersisted report draft had NUL markers in a code fence. They were detected and replaced before report publication; no NUL-containing report was written.
- Biome LSP is not installed, and another fresh-diagnostics request timed out. No installation or configuration workaround was attempted. Actual Node syntax and offline semantic proofs pass; no clean LSP or strict checked-JavaScript pass is claimed.
- Prior phase32 observe-01 lost the first 243 response entities/outcomes after a local TypeError. Those bodies remain unavailable, not reconstructed or replaced. Prior sealed failure artifacts are authenticated without edits.
- No new network request, source refetch, provider retry, trace, range scan, phase29 experiment, signing or compiler/gate run occurred.
