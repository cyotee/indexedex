# Preserved development and tooling failures

No genuine production defect was established. No production or existing
non-owned test was patched, weakened, skipped or relabeled.

1. Two attempted parallel implementation delegations were rejected before
   spawning because this session is already at the nesting limit. All work
   was performed in this session; no child remains.
2. Initial multi-read output was truncated. Complete raw reads and bounded
   line ranges supplied the missing briefs, reports and law before relying
   on them. The tool-schema discovery initially assumed an array and failed;
   direct named schema lookup corrected it.
3. `legacy-development-01.log`: the first legacy test compilation rejected
   `Receipt` colliding with inherited `StdCheatsSafe.Receipt`, and an override
   of a nonvirtual existing fixture function. Only the owned test changed:
   the alias became `MigrationReceipt`, and a distinct fresh bounded parent
   is deployed after the unchanged base setup. Production/TestBase remained
   unchanged.
4. `legacy-development-02.log`: setup called legacy NFT `approve(0)` even
   though the real transfer-back had already cleared approval. The actual
   source rejects zero operator. The unsupported redundant clear was removed;
   the test now asserts actual approval is zero and still executes the exact
   missing-approval failure, wrong-wallet/control failures and successful
   custody afterward.
5. `fork-development-03.log`: new unit setup expected a bubbled source
   allowance error on wrapped approved pulls. Those calls use Crane's
   `SafeTransferLib` and return exact `TransferFromFailed()`.
6. `unit-development-04.log` and `unit-trace-05.log`: applying that wrapper
   error to the three held-source direct bool pulls was incorrect. Actual
   `UniswapV4DetfMigrationRecoveryTarget.sol:68-69` calls those sources
   directly, as does the ER adapter; they bubble the exact typed allowance
   error. Expectations now distinguish those four direct pulls from wrapped
   paths. The -vvv setup attempt did not expose a detailed call trace; source
   inspection established the distinction. No broad accepted-error set exists.
7. Native development, corrected legacy development and
   `unit-development-06.log` pass. Later source additions justified
   `unit-development-07.log`: current/issued independent-origin exclusions,
   all-source Stage1 rejection, exact allowance accounting and real ER
   source-rate change. That gate passes too.
8. Final diagnostics caught one address checksum spelling in the new ER
   backing-donation action. It was corrected before the passing final
   compilation. Several fresh Solidity diagnostic requests timed out.
   Biome is absent for JSON; no package/configuration installation was made.
9. The first offline artifact inventory attempted to enumerate standalone
   output directories for abstract TestBases. Those directories do not exist.
   It was corrected to retain that explicit absence and require their source
   hashes in concrete metadata. All deployable selected artifact paths exist.
10. `cleanup-final.log` stopped on the first clean new-file whitespace check:
    `git diff --no-index` implies difference exit status 1 even when `--check`
    emits no diagnostic. `cleanup-final-02.log` accepts only status 0 or 1
    with empty output, rejecting every diagnostic or fatal status. The first
    attempt remains preserved; it did not reach the port check.
11. The corrected whitespace check then correctly rejected an extra blank
    EOF line in generated evidence JSON. The evidence writer had added one
    newline beyond the supplied content. Only owned Markdown/JSON/patch
    container EOFs were corrected through `apply_patch`; all raw log and
    base64-carried source/artifact bytes remain unchanged. The third cleanup
    gate checks the corrected authored files. No Solidity test rerun is
    warranted by this evidence-only correction.

Every failed raw log remains separate from the final complete gates.
No final required gate failed: 171 specifications, 147 pinned forks and
58 focused ordinary regressions passed. No production mutation experiment was
performed because existing-source edits are forbidden.
