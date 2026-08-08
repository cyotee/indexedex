import { execFileSync, spawn } from 'node:child_process'
import { rm } from 'node:fs/promises'
import path from 'node:path'
import { setTimeout as sleep } from 'node:timers/promises'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Ensure Next runs with frontend/ as cwd even if npm was invoked from repo root.
const frontendDir = path.resolve(__dirname, '..')
process.chdir(frontendDir)

const [cmd, ...rest] = process.argv.slice(2)
if (!cmd) {
  console.error('Usage: node scripts/next.mjs <dev|build|start> [--clean] [--kill-port <port>] [-- ...nextArgs]')
  process.exit(1)
}

// npm/yarn may forward args with a leading "--" separator; Next doesn't need it.
if (rest[0] === '--') rest.shift()

const cleanIndex = rest.indexOf('--clean')
const shouldClean = cleanIndex !== -1
if (shouldClean) rest.splice(cleanIndex, 1)

// Optional guardrail: kill any existing process listening on a port before starting Next.
let killPort
for (let i = 0; i < rest.length; i++) {
  const arg = rest[i]

  if (arg === '--kill-port') {
    const value = rest[i + 1]
    if (!value) {
      console.error('Missing value for --kill-port')
      process.exit(1)
    }
    killPort = Number(value)
    if (!Number.isFinite(killPort) || killPort <= 0) {
      console.error(`Invalid --kill-port value: ${value}`)
      process.exit(1)
    }
    rest.splice(i, 2)
    i -= 1
    continue
  }

  if (typeof arg === 'string' && arg.startsWith('--kill-port=')) {
    const value = arg.slice('--kill-port='.length)
    killPort = Number(value)
    if (!Number.isFinite(killPort) || killPort <= 0) {
      console.error(`Invalid --kill-port value: ${value}`)
      process.exit(1)
    }
    rest.splice(i, 1)
    i -= 1
  }
}

// If the separator appears later (e.g. scripts/next.mjs dev --clean -- --port 3000)
// strip it as well.
for (let i = rest.indexOf('--'); i !== -1; i = rest.indexOf('--')) {
  rest.splice(i, 1)
}

if (shouldClean) {
  await rm(path.join(frontendDir, '.next'), { recursive: true, force: true })
}

async function killPortListeners(port) {
  // macOS/Linux: lsof prints one PID per line with -t.
  // If lsof is unavailable, we skip (this is a local-dev guardrail).
  let stdout
  try {
    stdout = execFileSync('lsof', ['-nP', `-iTCP:${port}`, '-sTCP:LISTEN', '-t'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    })
  } catch {
    return { killed: 0 }
  }

  const pids = stdout
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s) => Number(s))
    .filter((n) => Number.isFinite(n) && n > 0 && n !== process.pid)

  if (pids.length === 0) return { killed: 0 }

  for (const pid of pids) {
    try {
      process.kill(pid, 'SIGTERM')
    } catch {
      // Ignore races / already-exited processes.
    }
  }

  await sleep(350)

  // Force kill anything still alive.
  for (const pid of pids) {
    try {
      process.kill(pid, 0)
      process.kill(pid, 'SIGKILL')
    } catch {
      // Not running or no perms.
    }
  }

  return { killed: pids.length }
}

if (typeof killPort === 'number') {
  const { killed } = await killPortListeners(killPort)
  if (killed > 0) {
    console.log(`Killed ${killed} process(es) listening on :${killPort}`)
  }
}

const nextBin = path.join(frontendDir, 'node_modules', '.bin', process.platform === 'win32' ? 'next.cmd' : 'next')

const child = spawn(nextBin, [cmd, ...rest], {
  stdio: 'inherit',
  env: process.env,
})

child.on('exit', (code) => {
  process.exit(code ?? 1)
})
