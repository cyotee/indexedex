const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { test } = require('node:test')
const { createRequire } = require('node:module')
const { execFile } = require('node:child_process')
const { promisify } = require('node:util')
const { resolveArtifacts, resolveArtifactsSync } = require('@tevm/compiler')
const { defaultConfig } = require('@tevm/config')
const { createMemoryClient } = require('tevm')
const solc = require('solc')
const run = promisify(execFile)

const source = path.join(__dirname, 'fixtures/TevmCounter.sol')
const fileAccess = {
  readFile: fs.promises.readFile,
  readFileSync: fs.readFileSync,
  existsSync: fs.existsSync,
  exists: async (file) => fs.existsSync(file),
}

test('TEVM compiles with Effect and executes the resulting contract in memory', { timeout: 30_000 }, async () => {
  const compiled = await resolveArtifacts(source, __dirname, console, defaultConfig, true, true, fileAccess, solc)
  const contract = compiled.artifacts.TevmCounter
  const client = createMemoryClient({ miningConfig: { type: 'manual' } })
  await client.tevmReady()

  const deployment = await client.tevmDeploy({
    abi: contract.abi,
    bytecode: `0x${contract.evm.bytecode.object}`,
    args: [17n],
    addToMempool: true,
  })
  assert.ok(deployment.createdAddress)
  await client.tevmMine({ blockCount: 1 })
  const result = await client.tevmContract({
    to: deployment.createdAddress,
    abi: contract.abi,
    functionName: 'value',
  })

  assert.equal(result.data, 17n)
  const synchronous = resolveArtifactsSync(source, __dirname, console, defaultConfig, false, true, fileAccess, solc)
  assert.equal(synchronous.artifacts.TevmCounter.evm.bytecode.object, contract.evm.bytecode.object)
})

test('Solc SMT integration passes the real temporary file to a process and removes it', () => {
  const solcRequire = createRequire(require.resolve('solc'))
  const { smtSolver } = solcRequire('./smtsolver')
  const query = '(set-logic QF_LIA)\n(check-sat)\n'
  // Exercise file transport and cleanup, not an external SMT solver's mathematics.
  const params = `-e 'const fs = require("node:fs"); const file = process.argv[1]; process.stdout.write(JSON.stringify({ file, query: fs.readFileSync(file, "utf8") }))'`

  const result = JSON.parse(smtSolver(query, { command: JSON.stringify(process.execPath), params }))

  assert.equal(result.query, query)
  assert.equal(path.extname(result.file), '.smt2')
  assert.equal(fs.existsSync(result.file), false)
})

test('TEVM ESM entry initializes an offline client on the selected chain', { timeout: 30_000 }, async () => {
  const { createMemoryClient: createEsmClient } = await import('tevm')
  const { createCommon } = await import('tevm/common')
  const { mainnet } = await import('viem/chains')
  const client = createEsmClient({ common: createCommon({ ...mainnet, id: 31337 }) })

  await client.tevmReady()
  const chainId = await client.getChainId()

  assert.equal(chainId, 31337)
})

test('TEVM retains legacy chain identities in both module formats', async () => {
  const esm = await import('tevm/common')
  const cjs = require('tevm/common')

  for (const [name, id] of Object.entries({ ekta: 1994, ektaTestnet: 1004, seiDevnet: 713715, zircuitTestnet: 48899 })) {
    assert.equal(esm[name].id, id)
    assert.equal(cjs[name].id, id)
  }
})

for (const args of [['--help'], ['compile', '--target', 'esnext', '--no-optimize']]) {
  test(`TEVM CLI accepts ${args.join(' ')}`, { timeout: 20_000 }, async () => {
    await run(process.execPath, [require.resolve('@tevm/cli'), ...args], {
      timeout: 15_000,
      env: { ...process.env, CI: '1' },
    })
  })
}

test('TEVM CLI rejects an unsupported compiler target', { timeout: 20_000 }, async () => {
  await assert.rejects(
    run(process.execPath, [require.resolve('@tevm/cli'), 'compile', '--target', 'invalid-target'], {
      timeout: 15_000,
      env: { ...process.env, CI: '1' },
    }),
    { code: 1 },
  )
})
