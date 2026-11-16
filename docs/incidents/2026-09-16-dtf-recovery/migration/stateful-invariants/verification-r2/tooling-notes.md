# Verification tooling notes

No independent build or test failed. Raw compiler warnings and complete test output are retained without filtering in the three gate logs.

The initial verifier-kernel helper declaration did not persist as a top-level function, producing exactly `identity is not defined`. It was replaced by a persistent `const` helper before any admission evidence was written. An initial unawaited schema inspection printed `Promise { <pending> }`; schemas were then awaited. Neither affected candidate sources or test execution.

The first selector-table parser expected Unicode separators; the actual table uses ASCII pipes. It was corrected and independently required each final table to sum to 512 before saving execution-results.json. An initial native-argument association looked for a previous subject; source and raw logs show that arguments precede their corresponding subject by two lines. The final binding uses the immediately following subject and all four exact hooks match. No erroneous intermediate binding was sealed.

The host reported the optional JSON Biome LSP was unavailable when creating evidence. JSON syntax is validated by independent parsing before sealing; no dependency/configuration change was made. All fourteen actual Solidity candidate files had clean native LSP results before the independent builds.

