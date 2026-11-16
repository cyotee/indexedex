---
name: defi-ui-testing
description: "IndexedEx DeFi UI tests: Playwright, real injected wallets and Anvil; MetaMask/Synpress reference only under current repo policy."
---

# defi-ui-testing

Read only the topic needed for the current task. Resolve the discovery symlink
to this canonical source before following relative links; then resolve each
topic's references from its own source directory. `CLAUDE.md`, current product
PRDs and Crane/IndexedEx testing/deployment rules take precedence.

Availability is not approval to add a protocol to a release, deploy contracts,
install tools, run a live wallet or restore retired Balancer/Slipstream/legacy
Uniswap families. Use local fixtures only within the task's authorized scope.

Use `indexedex-ui-tx-testing` for required money paths. Its explicit rule is
no MetaMask automation: MetaMask/Synpress topics below are reference-only, not
a second test framework to install or run. Connector stubs are
limited to isolated UI tests; do not claim they prove real wallet, signing or
on-chain behavior. Reuse `frontend/apps/indexedex` and the repository's pinned
Playwright/test setup rather than creating a second frontend or tool installation.

| Topic | Guidance |
| --- | --- |
| defi-ui-anvil-fixtures | [defi-ui-anvil-fixtures](../defi-ui-anvil-fixtures/SKILL.md) |
| defi-ui-mock-connector | [defi-ui-mock-connector](../defi-ui-mock-connector/SKILL.md) |
| defi-ui-synpress-metamask | [defi-ui-synpress-metamask](../defi-ui-synpress-metamask/SKILL.md) |
| defi-ui-test-patterns | [defi-ui-test-patterns](../defi-ui-test-patterns/SKILL.md) |
| defi-ui-testing-overview | [defi-ui-testing-overview](../defi-ui-testing-overview/SKILL.md) |
| metamask-extension-testing | [metamask-extension-testing](../metamask-extension-testing/SKILL.md) |
| metamask-networks-accounts | [metamask-networks-accounts](../metamask-networks-accounts/SKILL.md) |
| metamask-overview | [metamask-overview](../metamask-overview/SKILL.md) |
| metamask-transactions-approvals | [metamask-transactions-approvals](../metamask-transactions-approvals/SKILL.md) |
| synpress-metamask-api | [synpress-metamask-api](../synpress-metamask-api/SKILL.md) |
| synpress-overview | [synpress-overview](../synpress-overview/SKILL.md) |
| synpress-playwright | [synpress-playwright](../synpress-playwright/SKILL.md) |
| synpress-wallet-setup | [synpress-wallet-setup](../synpress-wallet-setup/SKILL.md) |
