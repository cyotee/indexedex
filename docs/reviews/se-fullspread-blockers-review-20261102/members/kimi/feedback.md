# Kimi advisory feedback

## Disposition

support-with-reservations

## Fidelity to Kimi's initial findings

The draft states all seven of my findings accurately:

- D3 covers the undefined post-sleeve local reserve term.
- D15 covers the contradictory seven-address storage wording.
- D9 covers the externally visible share-unit choice.
- D10 covers the missing `Compounded()` emission predicate.
- D14 covers the optional `PkgInit.wrappedNative` package ABI.
- D6 covers the overbroad matrix exclusion for booked-remainder rows.
- D17 covers the stale APEX-2026-039 waiting status.

No load-bearing finding from my initial response is omitted. The additional issues adopted from other members do not distort the Kimi findings, and the draft preserves my different position on the quote mechanism in D12 and Preserved disagreements.

## Corrections by draft section

### D4. Booking the held balance can take a staged pretransfer

The draft presents leaving a staged unbooked balance untouched as an equally supported reading and asks whether taking it is an explicitly accepted risk. The booking lock already says to book the actual held balance, expressly includes a stray transfer, and says a non-atomic pretransfer can be booked too. B-13 also assigns the non-atomic pretransfer risk to the caller.

The draft should not reopen that booking scope or imply that a second owner acceptance is required. Its separate observation about a declared maximum exceeding the unbooked balance can remain as a distinct clarity question, but it should not be used to make the existing maintenance-booking rule appear undecided.

### D16. The 64-byte consumer list is still required

The requirement to enumerate every old 32-byte preview consumer is valid, but the fix direction changes the locked workflow when it says the PRD pass “starts once the consumer list exists.” The blockers file expressly assigns that enumeration to the single comprehensive PRD pass; it does not make completing the list a precondition for starting the pass.

Keep the warning that the tuple migration is incomplete without the consumer inventory, but preserve the file's stated sequencing: enumeration is work performed in that pass, not an additional gate invented by this draft.

## Scope

These reservations concern draft fidelity and workflow, not new product decisions. This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.
