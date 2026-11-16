# F1 evidence size correction

The original validation ledger accidentally used JavaScript UTF-16 string length for a field labeled bytes. The preserved raw logs and original seal were correct. This additive correction replaces only the specs and forks byte counts with 269164 and 218681 respectively. All other validation fields are unchanged.

The original sealed evidence and both needs-fix audits remain unchanged. The replacement validation-results.json is authoritative only for those two byte counts; it does not invent a new execution or supersede any other acceptance requirement. Source, tests, artifacts and runtime witnesses are unchanged. No suite was rerun. Independent F1 closure is required before the formatting commit.
