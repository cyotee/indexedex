import type { AggregatorConfig } from '../src/types.js'

export const config: AggregatorConfig = {
  inputRoot: 'scripts/node/fixtures/sample-deploys',
  outputRoot: 'scripts/node/fixtures/sample-output',
  environments: [
    { environment: 'sepolia', chains: [{ chainId: 11155111, chainDir: '11155111' }] },
  ],
  buckets: [
    {
      id: 'base-tokens',
      name: 'Fixture Tokens',
      keywords: ['fixture'],
      includeTypeDirs: ['tokens'],
      defaultTags: [],
      tagDefinitions: {
        token: { name: 'Token', description: 'ERC20 token' },
        testToken: { name: 'Test Token', description: 'Test ERC20' },
      },
    },
    {
      id: 'balancer-v3-pools',
      name: 'Fixture Balancer V3 Pools',
      keywords: ['fixture'],
      includeTypeDirs: ['pools/balancerV3'],
      defaultTags: [],
      tagDefinitions: {
        pool: { name: 'Pool', description: 'AMM pool' },
        balancer: { name: 'Balancer', description: 'Balancer pool' },
        balV3: { name: 'Balancer V3', description: 'Balancer V3 pool' },
      },
    },
  ],
}
