---
name: evm-development
description: "EVM integration development with Viem, Chainlink/VRF, DeFi Saver callback storage and Fluid liquidation math; follow IndexedEx product law."
---

# evm-development

Read only the topic needed for the current task. Resolve the discovery symlink
to this canonical source before following relative links; then resolve each
topic's references from its own source directory. `CLAUDE.md`, current product
PRDs and Crane/IndexedEx testing/deployment rules take precedence.

Availability is not approval to add a protocol to a release, deploy contracts,
install tools, run a live wallet or restore retired Balancer/Slipstream/legacy
Uniswap families. Use local fixtures only within the task's authorized scope.

Generic Chainlink simulator/mocks are external integration fixtures, not a
replacement for IndexedEx SUTs or production-first TestBases. Generic VRF owner
configuration does not override immutable DETF product law. Check installed
versions and the current registry/ABI before applying archived examples.

| Topic | Guidance |
| --- | --- |
| chainlink-local-testing | [chainlink-local-testing](../../../lib/crane/.claude/skills/chainlink-local-testing/SKILL.md) |
| chainlink-vrf-architecture | [chainlink-vrf-architecture](../../../lib/crane/.claude/skills/chainlink-vrf-architecture/SKILL.md) |
| crane-chainlink-local-testing | [crane-chainlink-local-testing](../../../lib/crane/.claude/skills/crane-chainlink-local-testing/SKILL.md) |
| crane-chainlink-vrf | [crane-chainlink-vrf](../../../lib/crane/.claude/skills/crane-chainlink-vrf/SKILL.md) |
| viem | [viem](../viem/SKILL.md) |
| defisaver-public-transient-store | [defisaver-public-transient-store](../defisaver-public-transient-store/SKILL.md) |
| fluid-liquidate-muldiv-clamp | [fluid-liquidate-muldiv-clamp](../fluid-liquidate-muldiv-clamp/SKILL.md) |
