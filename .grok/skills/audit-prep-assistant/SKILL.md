---
name: audit-prep-assistant
description: "Prepare a smart contract codebase for audit: scope, goals, analysis triage, coverage gaps, accessibility, and documentation."
---

# Audit Prep Assistant


## IndexedEx integration

Read the target repository's `CLAUDE.md` and `docs/agent/SKILL_CATALOG.md`; current product law and canonical `crane-*` / `indexedex-*` guidance override generic examples here. Tests are production-first, never SUT mocks; use Crane TestBases, CREATE3/FactoryService for facets and the IndexedEx manager registry for vault/DETF DFPkgs, never direct `new`. For testing within the current authorized task: `forge build` before tests, default hermetic or `FOUNDRY_PROFILE=fork`; no `via_ir` or package profiles.

Analysis produces findings and recommendations, not silent production fixes. Commands, installation, scans, network/RPC, tests, deployments, Git writes and broadcasts require scope in the current request; examples grant none. Reading or installing this skill executes none. Current task authorization may already cover routine local analysis and validation; do not demand a second approval for those actions. Assessment-only requests do not authorize production fixes. Use Native's actual `read`, `grep`, `glob`, LSP and `apply_patch` tools as available; `allowed-tools` metadata is not enforcement. No Claude aliases or plugin agent registration is assumed. Report missing tools and unverified results rather than claiming success. Reports go only to the user-scoped output path. Historical examples and sample scores are illustrative, not IndexedEx findings or proof of tool correctness. Retained upstream interface metadata is inert in `references/upstream-openai.yaml`. Upstream pointers to `audit-context-building` or `issue-writer` are optional, not installed commands; use scoped code reading and the included report templates when they are absent.

## Purpose

Helps prepare for a security review using Trail of Bits' checklist. A well-prepared codebase makes the review process smoother and more effective.

**Use this**: 1-2 weeks before your security audit

---

## The Preparation Process

### Step 1: Set Review Goals

Helps define what you want from the review:

**Key Questions**:
- What's the overall security level you're aiming for?
- What areas concern you most?
  - Previous audit issues?
  - Complex components?
  - Fragile parts?
- What's the worst-case scenario for your project?

Documents goals to share with the assessment team.

---

### Step 2: Resolve Easy Issues

Reviews existing static-analysis evidence and proposes low-hanging fixes. Run fresh analysis only when the current request authorizes it; implementation is a separate requested task:

**Static Analysis Plan (commands for separately authorized use)**:

For Solidity:
```bash
slither . --exclude-dependencies
```

For Rust:
```bash
dylint --all
```

For Go:
```bash
golangci-lint run
```

For Go/Rust/C++:
```bash
# CodeQL and Semgrep checks
```

Then I'll:
- Triage all findings
- Recommend specific fixes; do not apply production changes during assessment
- Document accepted risks

**Increase Test Coverage**:
- Analyze current coverage
- Identify untested code
- Suggest new tests
- Review existing test results; record missing evidence and a scoped test plan

**Remove Dead Code**:
- Find unused functions/variables
- Identify unused libraries
- Locate stale features
- Suggest cleanup

**Goal**: Clean static analysis report, high test coverage, minimal dead code

---

### Step 3: Ensure Code Accessibility

Helps make code clear and accessible:

**Provide Detailed File List**:
- List all files in scope
- Mark out-of-scope files
- Explain folder structure
- Document dependencies

**Create Build Instructions**:
- Write step-by-step setup guide
- Test on fresh environment
- Document dependencies and versions
- Verify build succeeds

**Freeze Stable Version**:
- Identify commit hash for review
- Recommend a dedicated review branch and release tag
- Record dependency versions; do not mutate lockfiles or Git state

**Identify Boilerplate**:
- Mark copied/forked code
- Highlight your modifications
- Document third-party code
- Focus review on your code

---

### Step 4: Generate Documentation

Helps create documentation:

**Flowcharts and Sequence Diagrams**:
- Map primary workflows
- Show component relationships
- Visualize data flow
- Identify critical paths

**User Stories**:
- Define user roles
- Document use cases
- Explain interactions
- Clarify expectations

**On-chain/Off-chain Assumptions**:
- Data validation procedures
- Oracle information
- Bridge assumptions
- Trust boundaries

**Actors and Privileges**:
- List all actors
- Document roles
- Define privileges
- Map access controls

**External Developer Docs**:
- Link docs to code
- Keep synchronized
- Explain architecture
- Document APIs

**Function Documentation**:
- System and function invariants
- Parameter ranges (min/max values)
- Arithmetic formulas and precision loss
- Complex logic explanations
- NatSpec for Solidity

**Glossary**:
- Define domain terms
- Explain acronyms
- Consistent terminology
- Business logic concepts

**Video Walkthroughs** (optional):
- Complex workflows
- Areas of concern
- Architecture overview

---

## How I Work

When invoked, I will:

1. **Help set review goals** - Ask about concerns and document them
2. **Review static analysis** - Triage existing evidence; list unavailable tools and propose authorized reruns
3. **Analyze test coverage** - Identify gaps and suggest improvements
4. **Find dead code** - Search for unused code and libraries
5. **Review accessibility** - Check build instructions and scope clarity
6. **Generate documentation** - Create flowcharts, user stories, glossaries
7. **Create prep checklist** - Track what's done and what's remaining

Adapts based on:
- Your platform (Solidity, Rust, Go, etc.)
- Available tools
- Existing documentation
- Review timeline

---

## Rationalizations (Do Not Skip)

| Rationalization | Why It's Wrong | Required Action |
|-----------------|----------------|-----------------|
| "README covers setup, no need for detailed build instructions" | READMEs assume context auditors don't have | Document dependency versions and fresh-build procedure; execute only in a separately authorized task |
| "Static analysis already ran, no need to run again" | Codebase changed since last run | If execution is authorized, generate a fresh report; otherwise record the evidence gap |
| "Test coverage looks decent" | "Looks decent" isn't measured coverage | Review coverage evidence and identify untested paths; mark unmeasured coverage explicitly |
| "Not much dead code to worry about" | Dead code hides during manual review | Inspect references and propose dead-code candidates; run detection tools only when authorized |
| "Architecture is straightforward, no diagrams needed" | Text descriptions miss visual patterns | Generate actual flowcharts and sequence diagrams |
| "Can freeze version right before audit" | Last-minute freezing creates rushed handoff | Identify and document commit hash now; propose a review branch without creating it |
| "Terms are self-explanatory" | Domain knowledge isn't universal | Create comprehensive glossary with all domain-specific terms |
| "I'll do this step later" | Steps build on each other - skipping creates gaps | Complete all 4 steps sequentially, track progress with checklist |

---

## Example Output

When I finish helping you prepare, you'll have concrete deliverables like:

```
=== AUDIT PREP PACKAGE ===

Project: DeFi DEX Protocol
Audit Date: March 15, 2024
Preparation Status: Complete

---

## REVIEW GOALS DOCUMENT

Security Objectives:
- Verify economic security of liquidity pool swaps
- Validate oracle manipulation resistance
- Assess flash loan attack vectors

Areas of Concern:
1. Complex AMM pricing calculation (src/SwapRouter.sol:89-156)
2. Multi-hop swap routing logic (src/Router.sol)
3. Oracle price aggregation (src/PriceOracle.sol:45-78)

Worst-Case Scenario:
- Flash loan attack drains liquidity pools via oracle manipulation

Questions for Auditors:
- Can the AMM pricing model produce negative slippage under edge cases?
- Is the slippage protection sufficient to prevent sandwich attacks?
- How resilient is the system to temporary oracle failures?

---

## STATIC ANALYSIS REPORT

Slither Scan Results:
✓ High: 0 issues
✓ Medium: 0 issues
⚠ Low: 2 issues (triaged - documented in TRIAGE.md)
ℹ Info: 5 issues (code style, acceptable)

Tool: slither . --exclude-dependencies
Date: March 1, 2024
Status: CLEAN (all critical issues resolved)

---

## TEST COVERAGE REPORT

Overall Coverage: 94%
- Statements: 1,245 / 1,321 (94%)
- Branches: 456 / 498 (92%)
- Functions: 89 / 92 (97%)

Uncovered Areas:
- Emergency pause admin functions (tested manually)
- Governance migration path (one-time use)

Command: forge coverage
Status: EXCELLENT

---

## CODE SCOPE

In-Scope Files (8):
✓ src/SwapRouter.sol (456 lines)
✓ src/LiquidityPool.sol (234 lines)
✓ src/PairFactory.sol (389 lines)
✓ src/PriceOracle.sol (167 lines)
✓ src/LiquidityManager.sol (298 lines)
✓ src/Governance.sol (201 lines)
✓ src/FlashLoan.sol (145 lines)
✓ src/RewardsDistributor.sol (178 lines)

Out-of-Scope:
- lib/ (OpenZeppelin, external dependencies)
- test/ (test contracts)
- scripts/ (deployment scripts)

Total In-Scope: 2,068 lines of Solidity

---

## BUILD INSTRUCTIONS

Prerequisites:
- Foundry 0.2.0+
- Node.js 18+
- Git

Setup:
```bash
git clone https://github.com/project/repo.git
cd repo
git checkout audit-march-2024  # Frozen branch
forge install
forge build
forge test
```

Verification:
✓ Build succeeds without errors
✓ All 127 tests pass
✓ No warnings from compiler

---

## DOCUMENTATION

Generated Artifacts:
✓ ARCHITECTURE.md - System overview with diagrams
✓ USER_STORIES.md - 12 user interaction flows
✓ GLOSSARY.md - 34 domain terms defined
✓ docs/diagrams/contract-interactions.png
✓ docs/diagrams/swap-flow.png
✓ docs/diagrams/state-machine.png

NatSpec Coverage: 100% of public functions

---

## DEPLOYMENT INFO

Network: Ethereum Mainnet
Commit: abc123def456 (audit-march-2024 branch)
Deployed Contracts:
- SwapRouter: 0x1234...
- PriceOracle: 0x5678...
[... etc]

---

PACKAGE READY FOR AUDIT ✓
Next Step: Share with Trail of Bits assessment team
```

---

## What You'll Get

**Review Goals Document**:
- Security objectives
- Areas of concern
- Worst-case scenarios
- Questions for auditors

**Clean Codebase**:
- Triaged static analysis (or clean report)
- High test coverage
- No dead code
- Clear scope

**Accessibility Package**:
- File list with scope
- Build instructions
- Frozen commit/branch
- Boilerplate identified

**Documentation Suite**:
- Flowcharts and diagrams
- User stories
- Architecture docs
- Actor/privilege map
- Inline code comments
- Glossary
- Video walkthroughs (if created)

**Audit Prep Checklist**:
- [ ] Review goals documented
- [ ] Static analysis clean/triaged
- [ ] Test coverage >80%
- [ ] Dead code removed
- [ ] Build instructions verified
- [ ] Stable version frozen
- [ ] Flowcharts created
- [ ] User stories documented
- [ ] Assumptions documented
- [ ] Actors/privileges listed
- [ ] Function docs complete
- [ ] Glossary created

---

## Timeline

**2 weeks before audit**:
- Set review goals
- Run static analysis
- Start fixing issues

**1 week before audit**:
- Increase test coverage
- Remove dead code
- Freeze stable version
- Start documentation

**Few days before audit**:
- Complete documentation
- Verify build instructions
- Create final checklist
- Deliver the package to the user; external sharing requires explicit authorization

---

## Ready to Prep

Let me know when you're ready and I'll help you prepare for your security review!
