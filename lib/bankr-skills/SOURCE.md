# Bankr Skills (vendored)

Source: https://github.com/BankrBot/skills
Install / refresh: `./scripts/sync-bankr-skills.sh`

Synced into the **parent** workspace (`projects-defi/.claude|/.opencode|/.grok/skills`),
not into IndexedEx project skill trees (keeps IndexedEx agent discovery lean).

Override destination: `BANKR_SKILLS_DEST_ROOT=/path ./scripts/sync-bankr-skills.sh`

External stubs: `./scripts/sync-bankr-skills.sh --expand-stubs` (also on `--refresh`).
