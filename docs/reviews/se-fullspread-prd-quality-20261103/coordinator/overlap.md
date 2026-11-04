# Overlap so far

Not the report. Astra and MiniMax have filed. Grok and Kimi have not.

| Topic | Astra | MiniMax |
| --- | --- | --- |
| Overstated pretransfer, other legs | ASTRA-01, high | Finding 8, low |
| Operator control path | ASTRA-02, high | not in the title list |
| WETH face / routing | ASTRA-03, medium | not in the title list |
| Donation shape | ASTRA-04, medium | Finding 2 covers donate and compound signatures |
| Removed wrappedNative validation | ASTRA-05, low | not in the title list |
| ERC-165 id | not in the title list | Finding 1, high |
| Maintenance fee source | not in the title list | Finding 3 |
| Unnamed rejection errors | not in the title list | Finding 4 |
| Precedence vs principal-only recap | not in the title list | Finding 5 |
| bindingHash scope | not in the title list | Finding 6 |
| poolKey getter | not in the title list | Finding 7 |

Kimi has filed:

1. FS-OWN-13 broadens borrowed-unlock execution beyond `exchangeIn`.
2. The invalid-route error paragraph conflicts with the no-view-revert lock.
3. The overstated-pretransfer rule changes the object of "do not spend".
4. Bundle pretransfer behavior is expressly left indeterminate.
5. FS-OWN-31 states an exhaustive failure rule that contradicts other required failures.
6. The package inputs do not unambiguously realize the required two-facet reserve cut.

Grok has not filed.
