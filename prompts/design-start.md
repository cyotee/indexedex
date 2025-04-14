In this project, we use Cursor IDE with a Memory Bank for persistent context, stored in memory-bank/ as Markdown files (e.g., project-brief.md, architecture.md, active-context.md, patterns.md, progress.md, testing.md, integrations.md, file-index.md). Cursor rules in .cursor/rules ensure the AI references these files for context-aware responses. For task management, we use task-master-ai, integrated via Model Context Protocol (MCP), to manage tasks and interact with Claude.
Your Role: Assist me in writing prompts for Claude, leveraging task-master-ai to manage tasks and the Memory Bank for project context.
Using task-master-ai:

MCP is enabled in Cursor, and task-master-ai is initialized.
Use commands like:
"Can you parse my PRD at scripts/prd.txt?" to generate tasks from the PRD.
"What’s the next task I should work on?" to list pending tasks.
"Can you help me implement task 3?" to get assistance with a specific task.


The AI uses Claude to implement tasks, referencing memory-bank/ files for context (e.g., integrations.md for Balancer V3 details).

Writing Prompts for Claude:

For task-related prompts, use task-master-ai commands (e.g., "Can you help me implement task 3?"), and the AI will craft Claude prompts incorporating task details and Memory Bank context.
For general prompts, reference Memory Bank files directly (e.g., "Using architecture.md, suggest improvements to FacadePool.sol").
The AI automatically uses memory-bank/file-index.md to locate files, prioritizing relevant sections (e.g., Solidity files for contract tasks).

PRD Updates:

When I update scripts/prd.txt, prompt: "Can you parse my updated PRD at scripts/prd.txt?" to generate new tasks.
I’ll update memory-bank/active-context.md with new tasks to keep context current.

Documentation:

For detailed task-master-ai commands and usage, refer to Task Master AI on npm.
For source code and additional docs, see Claude Task Master on GitHub.

Workflow:

Use Memory Bank for project context (e.g., patterns.md for coding standards).
Manage complex tasks (e.g., refactoring FacadePool.sol) with task-master-ai commands.
Update memory-bank/progress.md after tasks, using AI-generated summaries if requested.
For testing, reference testing.md and run Foundry tests, logging results.

This setup enables efficient, context-aware assistance for writing Claude prompts, task management, and project documentation.
