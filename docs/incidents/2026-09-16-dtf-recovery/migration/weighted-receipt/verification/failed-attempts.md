# Verifier-owned audit attempts

The initial `receipts.ts` invocation exited 1 before writing `receipts.json`:

```text
AssertionError: duplicate journal operation 0cf5aa4b26badced1ad1da56f6c1a97a590224011e5702ea0d8006ff9389f42b
true !== false
```

This was an auditor keying error, not duplicate execution on resume. The same
idempotent independent-configuration payload is deliberately executed in two
different preparation domains, `journal-configure` and `journal-replacement`.
Their domain hashes are
`8383b66a0eea091815e4125189a7282ea6947be23aab28b6ac98c77ec0665f2d`
and
`83ff72b4e105c12fe77b3ee5714ce7de8402ac1244b00eb10c2b4be078455943`.
They use nonces 2139 and 2147. The actual operator journal separates domains.
The corrected auditor keys by `(domainHash,id)` and still rejects duplicate
execution within one domain. It compares each interrupted intent to its
matching final domain without overwriting another domain's record.

No source, test, producer evidence or runtime witness was changed.

The first `economics.ts` execution exited 1 at the decoded-event equality:
ethers returned checksummed `0x83781Cf2371117aAc856621805FB83c9ca439BAd`
while the prepared input uses lowercase
`0x83781cf2371117aac856621805fb83c9ca439bad`.
The address bytes are identical. The corrected auditor normalizes only the
decoded address argument before comparison; all numeric and raw receipt
comparisons remain exact. The preceding strict probe typecheck passed.
