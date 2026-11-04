# Implementor gaps

Revision **se-fullspread-implementor-gaps-20261031-01a18660-final**. Coordinator revision after advisory on draft `se-fullspread-implementor-gaps-20261031-01a18660-r1`. The advisory session notices were empty. The feedback files were written, and each recorded a matching raw SHA-256. This is not member-approved text, not a PRD edit, and not an implementation.

## Question

Which sentences in the updated full-spread PRD still force an implementor to choose a product behavior?

## Participation

| Member | Original | Advisory file |
| --- | --- | --- |
| Astra | st_01a19393 | members/astra/feedback.md |
| Grok | st_01a19394 | members/grok/feedback.md |
| MiniMax | st_01a19395 | members/minimax/feedback.md |
| Kimi | st_01a19396 | members/kimi/feedback.md |

## Not a gap

A later rate policy is not an open choice. FS-OWN-03 already forbids installing one. The stale sentence that other Basic Vault semantics are unspecified is not a gap. The lock already assigns the three `IBasicVault` members.

## Owner questions

The draft's 29 questions stand, with these corrections. None is answered here.

Add:

- May borrowed-unlock `exchangeIn`, received while the PoolManager is already unlocked, spend local sleeve balances, or must it leave the sleeve untouched? This is not the locked-call question.
- Do `localReserves()` and the sleeve calculation include unbooked transfers, pretransfer surplus, and in-flight reserved input, or only accounted backing?
- What existing state disables inbound issuance, and what existing writer is authorized to set it? Do not invent a setter.
- While the vault is busy, do `reserves()` and `reserveOfToken()` return the live local-plus-deployed sum or the last committed snapshot? Busy is not the same condition as the operation guard being held.
- Which views are the busy-vault economic views that revert?
- If a locked-path call with `pretransferred == true` does not revert, does the accepted pull and refund rule apply?
- Does native-pool support require raw-ETH entry on an accepted locked route? Borrowed `exchangeIn` being nonpayable does not settle that route.

Correct:

- The 1,000-share question includes the denominator. If the floor is outside ERC-20 `totalSupply()`, the existing-supply denominator has to be named. The PRD still forbids a second ledger and a holder address.
- The one-token exit is not unanimously open. Astra says the accepted route already pays the selected token or reverts. Grok and MiniMax still ask what happens to unselected pro-rata idle. That remainder is the open part, not a new exit selector.
- Stored idle counters versus actual balances is still a question. It is not a close. The custody question above is separate.
- Paying an other-currency entry credit to the payer, outside `amountRefunded`, is a recommendation from Weir and the accepted refund rule. Kimi still asks whether that credit is paid or the operation reverts. It is not decided.
- The named `queryFacet` omissions are closed. The open part is the installed selector list and the Protocol Aware component bindings.

## Limits

No PRD edit. No contract implementation. No cap, fee, holder, return field, or selector was added.
