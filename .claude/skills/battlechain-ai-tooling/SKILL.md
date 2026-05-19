---
name: battlechain-ai-tooling
description: Use this skill when configuring AI agents (Claude Code, Copilot, Cursor, Codex, MCP clients) to enforce BattleChain-first development and docs-aware behavior.
---

# BattleChain AI Tooling Integration

Use this skill to make agents reliably follow BattleChain workflow before mainnet deployment.

## Core Context Source

Use BattleChain docs exports:

- TOC index: `https://docs.battlechain.com/llms.txt`
- Full corpus: `https://docs.battlechain.com/llms-full.txt`

Preferred instruction to AI:

```text
Read https://docs.battlechain.com/llms-full.txt and use it for BattleChain guidance.
```

## Enforced Prompt Block

Add this to project-level AI instructions:

```markdown
## BattleChain

This project deploys to BattleChain for security battle-testing before mainnet.
BattleChain is a pre-mainnet L2 where whitehats legally attack contracts under
Safe Harbor protection.

Full documentation: https://docs.battlechain.com/llms-full.txt

### Deployment workflow
1. Install battlechain-lib (forge install cyfrin/battlechain-lib)
2. Deploy via bcDeployCreate* helpers
3. Create Safe Harbor agreement via createAndAdoptAgreement
4. Request attack mode (BattleChain only)
5. Promote after battle-testing
6. Deploy to mainnet

### Requirements
- Use battlechain-lib for deploy/agreement scripts
- Never deploy directly to mainnet first
- Use --skip-simulation for forge script on BattleChain
```

## File Placement by Tool

- Claude Code: `CLAUDE.md`
- GitHub Copilot: `.github/copilot-instructions.md`
- Cursor: `.cursor/rules/*.mdc`
- OpenAI Codex CLI: `AGENTS.md`
- Windsurf: `.windsurfrules`

## MCP Integration

BattleChain docs MCP endpoint:

- `https://docs.battlechain.com/api/mcp`

Claude Code setup:

```bash
claude mcp add --transport http battlechain-docs https://docs.battlechain.com/api/mcp
```

Tools exposed by server:

- `search_docs(query)`
- `read_page(path)`
- `list_pages()`

## Recommended Agent Behavior

- Always check contract state before attack logic.
- Always resolve Binding Agreement before bounty logic.
- Default to BattleChain testnet params:
  - chain id `627`
  - rpc `https://testnet.battlechain.com`
- Never request private keys in chat; use local keystore flow.

## Safety Guardrails for Agent Output

- Flag if script omits `--skip-simulation` on BattleChain forge broadcasts.
- Flag if deployment targets mainnet before BattleChain stage.
- Flag if bounty calculations ignore cap or retainable mode.
- Flag if agreement terms are read from non-binding registry mapping.

## References

- `https://docs.battlechain.com/battlechain/using-battlechain-with-ai`
- `https://docs.battlechain.com/battlechain/how-to/configure-ai-tools`
- `https://docs.battlechain.com/llms-full.txt`
