import { describe, it, expect } from 'vitest'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { readFragmentsForInput } from '../src/readFragments.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const FIXTURE_ROOT = join(__dirname, '..', 'fixtures', 'sample-deploys', 'sepolia', '11155111')

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
})
