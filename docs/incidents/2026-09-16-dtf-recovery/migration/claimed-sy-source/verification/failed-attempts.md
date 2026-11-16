# Verifier-only failed attempts

No source transaction was retried to repair any item below, and no retained
producer input or evidence was changed.

1. The first offline evidence audit raised `false == true` after its transaction
   and arithmetic checks. Its identity check required an eth_getCode exchange
   even for a zero facet address. The producer correctly records the unbound
   route as zero and its empty runtime without that unnecessary code request.
   The audit was changed to require original code responses only for nonzero
   facets, while still checking every selector's actual loupe response and
   every recorded runtime hash. The completed audit passes.
2. Attempting to call the function from that failed eval cell returned
   `ReferenceError: auditEvidence is not defined`. The function was defined in
   its own successful cell as a persistent variable, then called separately.
3. Final audit aggregation referred to `producerAudit`, previously declared
   inside a try block that was not exposed as a persistent kernel binding.
   It returned `producerAudit is not defined`. Only that offline binding was
   recomputed. The raw records and already completed source witness were not
   rerun or altered.

JSON patch diagnostics report that Biome is not installed. That is unavailable
editor tooling, not a successful diagnostic check; no installation was attempted.
