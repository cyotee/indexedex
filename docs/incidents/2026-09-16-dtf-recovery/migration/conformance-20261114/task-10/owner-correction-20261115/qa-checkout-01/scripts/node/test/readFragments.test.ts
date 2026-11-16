import { describe, it, expect } from 'vitest'
import { join, dirname } from 'node:path'
import { mkdir, mkdtemp, rm, symlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { fileURLToPath } from 'node:url'
import { readFragmentsForInput } from '../src/readFragments.js'
import type { ManifestFragment } from '../src/types.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const FIXTURE_ROOT = join(__dirname, '..', 'fixtures', 'sample-deploys', 'sepolia', '11155111')
const FRAGMENT: ManifestFragment = {
  chainId: 11155111,
  address: '0x1111111111111111111111111111111111111111',
  name: 'Discovery fixture',
  symbol: 'FIX',
  decimals: 18,
}

describe('readFragmentsForInput', () => {
  it('returns all fragments under the input with sourceTypeDir attached', async () => {
    const fragments = await readFragmentsForInput(FIXTURE_ROOT)
    expect(fragments).toHaveLength(2)

    const token = fragments.find((f) => f.symbol === 'TTA')!
    expect(token.sourceTypeDir).toBe('tokens')

    const pool = fragments.find((f) => f.symbol === 'abBalancerV3ConstProdPool')!
    expect(pool.sourceTypeDir).toBe('pools/balancerV3')
    expect(pool.extensions?.composingAssets).toEqual([
      '0x1111111111111111111111111111111111111111',
      '0x3333333333333333333333333333333333333333',
    ])
  })

  it('returns empty array when the input directory does not exist', async () => {
    const fragments = await readFragmentsForInput(join(FIXTURE_ROOT, 'doesnotexist'))
    expect(fragments).toEqual([])
  })

  it('reads nested JSON files once in taxonomy order without hidden or unknown paths', async ({ onTestFinished }) => {
    const root = await mkdtemp(join(tmpdir(), 'indexedex-fragments-'))
    onTestFinished(() => rm(root, { recursive: true, force: true }))
    const expectedPaths = [
      'tokens/root.json',
      'tokens/deep/leaf.json',
      'tokens/directory.json/nested.json',
      'pools/uniV2/pair.json',
    ]
    const ignoredPaths = [
      'tokens/.hidden.json',
      'tokens/.hidden/invalid.json',
      'tokens/upper.JSON',
      'unknown/invalid.json',
    ]
    for (const path of [...expectedPaths, ...ignoredPaths]) {
      const file = join(root, path)
      await mkdir(dirname(file), { recursive: true })
      await writeFile(file, expectedPaths.includes(path) ? JSON.stringify(FRAGMENT) : 'not JSON')
    }

    const fragments = await readFragmentsForInput(root)

    expect(fragments.map((fragment) => fragment.sourcePath).sort())
      .toEqual(expectedPaths.map((path) => join(root, path)).sort())
    expect(fragments.map((fragment) => fragment.sourceTypeDir))
      .toEqual(['tokens', 'tokens', 'tokens', 'pools/uniV2'])
    expect(new Set(fragments.map((fragment) => fragment.sourcePath)).size).toBe(fragments.length)
  })

  it('follows file and directory symlinks without resolving away their source paths', async ({ onTestFinished }) => {
    const root = await mkdtemp(join(tmpdir(), 'indexedex-fragment-links-'))
    onTestFinished(() => rm(root, { recursive: true, force: true }))
    const input = join(root, 'fragments')
    const external = join(root, 'external')
    await mkdir(join(input, 'tokens'), { recursive: true })
    await mkdir(join(input, 'pools'), { recursive: true })
    await mkdir(external)
    await writeFile(join(external, 'linked.json'), JSON.stringify(FRAGMENT))
    await symlink(join(external, 'linked.json'), join(input, 'tokens', 'alias.json'), 'file')
    await symlink(external, join(input, 'pools', 'uniV2'), 'dir')
    await symlink(join(root, 'missing.json'), join(input, 'tokens', 'dangling.json'), 'file')

    const fragments = await readFragmentsForInput(input)

    expect(fragments.map((fragment) => fragment.sourcePath)).toEqual([
      join(input, 'tokens', 'alias.json'),
      join(input, 'pools', 'uniV2', 'linked.json'),
    ])
    expect(fragments.map((fragment) => fragment.sourceTypeDir)).toEqual(['tokens', 'pools/uniV2'])
  })

  it('propagates traversal errors other than missing directories', async ({ onTestFinished }) => {
    const root = await mkdtemp(join(tmpdir(), 'indexedex-fragment-errors-'))
    onTestFinished(() => rm(root, { recursive: true, force: true }))
    await writeFile(join(root, 'tokens'), 'not a directory')

    await expect(readFragmentsForInput(root)).rejects.toMatchObject({ code: 'ENOTDIR' })
  })

  it('rejects malformed JSON in a matching file', async ({ onTestFinished }) => {
    const root = await mkdtemp(join(tmpdir(), 'indexedex-fragment-json-'))
    onTestFinished(() => rm(root, { recursive: true, force: true }))
    await mkdir(join(root, 'tokens'))
    await writeFile(join(root, 'tokens', 'invalid.json'), 'not JSON')

    await expect(readFragmentsForInput(root)).rejects.toBeInstanceOf(SyntaxError)
  })
})
