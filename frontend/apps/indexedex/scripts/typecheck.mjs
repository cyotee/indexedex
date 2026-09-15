import { spawnSync } from 'node:child_process'
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

// Resolve hoisted workspace dependencies as well as app-local installs.
const require = createRequire(import.meta.url)
// Generate current route contracts before checking async params/searchParams.
run(process.execPath, [require.resolve('next/dist/bin/next'), 'typegen'], { cwd: frontendDir })
run(process.execPath, [require.resolve('typescript/bin/tsc'), '--noEmit'], { cwd: frontendDir })
