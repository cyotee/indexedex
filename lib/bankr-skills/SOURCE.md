# Bankr Skills (vendored)

Source: https://github.com/BankrBot/skills
Install / refresh: `./scripts/sync-bankr-skills.sh`

These skill packages are synced into:
- `.claude/skills/` (Claude Code; Grok Build also scans this)
- `.opencode/skills/` (OpenCode)
- `.grok/skills/` (Grok Build project skills)

Do not edit skill content here for long-lived customizations; re-sync will overwrite.
For project-specific agent skills, put them directly under `.claude/skills/` (and mirror to OpenCode/Grok as needed).
