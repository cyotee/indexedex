import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

function run(cmd, args, opts = {}) {
  const result = spawnSync(cmd, args, { stdio: 'inherit', ...opts })
  if (result.error) throw result.error
  if (typeof result.status === 'number' && result.status !== 0) process.exit(result.status)
}

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const frontendDir = path.resolve(scriptDir, '..')

// Next.js may auto-edit tsconfig.json to include ".next/types/**/*.ts".
// Ensure the directory exists so plain `tsc --noEmit` always works.
const typesDir = path.join(frontendDir, '.next', 'types')
fs.mkdirSync(typesDir, { recursive: true })

const placeholderFile = path.join(typesDir, 'placeholder.ts')
if (!fs.existsSync(placeholderFile)) {
  fs.writeFileSync(placeholderFile, 'export {}\n', 'utf8')
}

// Resolve hoisted workspace dependencies as well as app-local installs.
const require = createRequire(import.meta.url)
run(process.execPath, [require.resolve('typescript/bin/tsc'), '--noEmit'], { cwd: frontendDir })
