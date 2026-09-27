# Lido native rounding correction

READY.patch contains three production sources and one new production-route test source. Apply from the current shared checkout; git apply --check passed. No shared files or artifacts were written by this agent.

The native stETH fixture implements the vendored share-transfer formulas and uses the actual vendored WstETH. A derived external-share fixture implements Lido.sol internal-share conversion semantics. Production vaults/facets are deployed through the existing registry/CREATE3 TestBase.

The patch validates exact native shares and recipient balance deltas; only stETH has native quantization handling. Other tokens retain strict nominal pull deltas. Pull quotes include incoming native transfer rounding, while pretransferred execution starts from measured local credit. Mint credit and stETH-to-WETH payment use the wrapped value retained. Native stETH output, unwrap and submit quotes include the relevant transfer floors; output minimums use actual recipient delivery. Native ETH dust is booked and zero receipt is not replaced with nominal value. Stateful quote models use the native internal ratio where external shares exist. Legacy ports lacking the optional external-share getter use their total ratio; errors/malformed returns from recognized getters bubble.

Final validation: 88 tests passed across seven Lido suites, zero failed/skipped; native fuzz properties each executed 10,001 cases (10,000 configured plus persisted counterexample), and the existing accounting invariant completed 256 runs by depth64. Final source hashes and facet sizes are recorded separately; no viaIR.

Red evidence against exact preserved original production sources: 20 of21 native tests failed and one compatibility control passed. Final tests are preserved under preserved-final-tests and original production under original. Red and green commands/logs/manifests are in /tmp/apex-review-accounting-red-run/lido-native-evidence/. Earlier sandbox panic and incomplete-sync/formatter-error attempts are preserved and excluded from successful validation claims. The root arithmetic check is supplementary, not runtime evidence.
