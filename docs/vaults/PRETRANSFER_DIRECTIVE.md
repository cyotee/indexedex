# Pretransfer directive

Locked 2026-11-02. This is a project rule for Standard Exchange calls that take `pretransferred`. It is not an implementation, and it does not edit a product PRD by itself.

A pretransfer call does not ask where the tokens came from. `pretransferred == true` declares that the caller is using a held unbooked balance, up to the maximum amount the caller provides. The caller is assumed to know what they are doing.

Locally booked balances are the parking lot. They are not the pretransfer balance. A pretransfer call uses the unbooked held balance. It does not spend a booked remainder.

If the caller's maximum is within the unbooked balance, the refund is that maximum minus the amount actually used. It is paid in the token the caller provided. The vault does not refund the whole remaining unbooked balance in that case. That balance may be staged for another call. The vault has no instruction to process it. If the maximum is larger than the unbooked balance, refund the unbooked balance. Do not refund the maximum minus the amount used, and do not pull the shortfall. The owner locked that case on 2026-11-02.

The swap is shaped so a remainder of the call is in the token the caller provided. That is the token the caller can receive back. A caller that pretransfers outside an atomic operation does so at its own risk.

Addresses without bytecode cannot pretransfer. That is the existing best effort to protect an EOA. It is not a promise that a contract caller is safe.

APEX-2026-039 is not the rule. A balance sitting on the vault is not the caller's credit beyond the declared maximum. The unbooked remainder is not sent to `msg.sender`. A burn uses the caller's shares. Shares parked on the vault, including shares whose recipient was the vault, are not that credit.
