import { join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { readFragmentsForInput } from './readFragments.js'
import { buildList } from './buildList.js'
import { loadPreviousList, writeList } from './writeList.js'
import { generateRegistryFiles } from './generateRegistry.js'
import type { AggregatorConfig } from './types.js'

async function loadConfig(configPath: string): Promise<AggregatorConfig> {
  const mod = (await import(pathToFileURL(configPath).href)) as { config?: AggregatorConfig }
  if (!mod.config) throw new Error(`Config at ${configPath} must export a named 'config'`)
  return mod.config
}

function parseArgs(argv: string[]): { configPath: string } {
  let configPath = join(process.cwd(), 'tokenlists.config.ts')
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--config' && i + 1 < argv.length) {
      configPath = argv[i + 1]!
      i++
    }
  }
  return { configPath }
}

function formatVersion(v: { major: number; minor: number; patch: number }): string {
  return `v${v.major}.${v.minor}.${v.patch}`
}

async function main() {
  const { configPath } = parseArgs(process.argv.slice(2))
  const config = await loadConfig(configPath)
  const repoRoot = process.env.INDEXEDEX_REPO_ROOT ?? process.cwd()
  const timestamp = new Date().toISOString()

  let totalLists = 0
  let totalTokens = 0
  let failures = 0

  for (const input of config.inputs) {
    // Fragments live in a `fragments/` subdirectory of each input.
    // Outputs are keyed by chain id only: outputRoot/chain/<chainId>/<bucket>.tokenlist.json.
    const fragments = await readFragmentsForInput(
      join(repoRoot, config.inputRoot, input.inputDir, 'fragments')
    )

    for (const bucket of config.buckets) {
      const outDir = join(repoRoot, config.outputRoot, 'chain', String(input.chainId))
      const outPath = join(outDir, `${bucket.id}.tokenlist.json`)
      const previous = await loadPreviousList(outPath)
      const result = buildList({ bucket, fragments, previousList: previous, timestamp })

      if (result.list.tokens.length === 0) continue

      if (!result.validation.valid) {
        failures++
        console.error(`[FAIL] chain/${input.chainId}/${bucket.id} (from ${input.inputDir})`)
        for (const e of result.validation.errors) console.error(`  - ${e}`)
        continue
      }

      if (result.bump.bump === 'none' && previous !== null) {
        console.log(`[SKIP] chain/${input.chainId}/${bucket.id} unchanged (from ${input.inputDir})`)
        continue
      }

      await writeList(outPath, result.list)
      totalLists++
      totalTokens += result.list.tokens.length
      console.log(
        `[OK]   chain/${input.chainId}/${bucket.id} ${formatVersion(result.list.version)} (${result.bump.bump}, ${result.list.tokens.length} tokens) <- ${input.inputDir}`
      )
    }
  }

  console.log(`\nWrote ${totalLists} list(s), ${totalTokens} token(s) total, ${failures} failure(s).`)

  const registry = await generateRegistryFiles(repoRoot)
  console.log(
    `Generated ${registry.registryPath} and ${registry.overridesPath} for ${registry.chainIds.length} chain(s): ${registry.chainIds.join(', ')}`
  )

  if (failures > 0) process.exit(1)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
