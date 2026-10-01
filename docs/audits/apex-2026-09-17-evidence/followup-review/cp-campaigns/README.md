# Canonical constant-product R11 campaigns

All three deterministic lifecycles and all three 256×64 campaigns pass in the independent APFS clone. Each campaign completed 16,384 coordinator calls with zero outer reverts; counters begin at zero and required actions have exact attempted/success/rejection coverage. There are three funded honest actors plus EOA and contract attack probes.

Production pools, registry packages, proxy vaults and mapped facets are real. Only external ERC20s expose callback hooks. LP principal is minted by real proportional pool liquidity, never balance-injected. The shared campaign performs deposits, partial exact-output redemptions, atomic prepay/refund minting, donations, partial resting-credit claims, transfers and repeat-credit attacks. Family supplements perform real pool trades and SE exact-in/out swaps with exact guard checks; Aerodrome additionally proves positive accrued-fee compounding into additional actual LP backing.

Apply `review.patch`; `manifest.json` pins before/after identities. These five files depend on the final generic handler from the staking combined overlay (hash included in `validation-source-manifest.json`). Tiny concrete subclasses declared in each test file preserve Foundry target artifact discovery under both focused and full builds.

Evidence: `/tmp/apex-review-cp-validation/campaigns.log`, `campaigns-result.json`, `campaigns-command.json`, and `artifact-seed.json`. The release environment counts and exact concrete-artifact build/test command are recorded in these files. `validation-summary.json` pins test totals and hashes. No shared checkout sources or artifacts were changed.
