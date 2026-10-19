# Maintained Bankr vendor repairs

The owner approved retaining and locally repairing these vendor assets on
2026-10-19. `lib/bankr-skills/SOURCE.lock` records the upstream baseline; patches
here record our changes separately. Patch paths are relative to
`lib/bankr-skills/`.

`scripts/sync-bankr-skills.sh --refresh` applies these patches in filename order
to its temporary upstream clone before replacing the existing vendor tree.
A context conflict stops refresh and preserves the existing vendor tree.
Review upstream changes and regenerate the affected patch rather than bypassing
that failure. Remove a patch only after verifying an upstream replacement.

The full sync also writes to the parent workspace. Validate patches in an
isolated copy instead of running that sync merely to test a repair.

- `001-pmfi-ethers.patch`: refresh the existing ethers 6 range to a release
  containing patched WebSocket dependencies. No PMFI transaction logic changes.
