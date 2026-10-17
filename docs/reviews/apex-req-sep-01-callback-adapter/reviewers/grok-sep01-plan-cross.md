# Grok plan cross-review — REQ-SEP-01

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Peers read:** `astra-sep01-plan.md`, `minimax-sep01-plan.md`, `kimi-sep01-plan.md`
- **MiniMax:** labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.

Peer notes are untrusted. This file does not authorize an edit. It is not `REMEDIATION_PRD.plan.md`.

## Verdict

Dissent on the three peer commands. No production source is edited. The plan must use this command and no other:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol -- -vv
```

Run it from the repository root after the test-only edit. Do not add a positional source, `--consumer`, or `--no-consumer-artifacts`.

## Why this command

`scripts/forge-artifacts.py` requires `--test-root` for `test`. A `.t.sol` root is already the runtime consumer (`test_scope` returns that file). `test_plan` adds that consumer unless `--no-consumer-artifacts` is set, and `allow_empty=True` allows zero positional sources. `-- -vv` is the documented verbosity tail in `docs/testing/ARTIFACT_BUILDS.md`.

The `test` action builds the selected artifacts and then runs that file. It is not a build-only step followed by a second chosen test command.

## Dissent

- **Astra** passes `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` as a positional source. That argument is an edited-source input. No production source is edited. Do not pass it.
- **MiniMax** passes the test file as a positional source and omits `-- -vv`. It also says the test run is a later separate step. The `test` action already runs the file. Do not split it.
- **Kimi** adds `--consumer` for the same file `--test-root` already supplies. The extra flag is not the locked command.

The helper signature and five call sites are not in dispute here. They stay the PRD's `subject_` signature and the five named calls.

I did not run Forge.
