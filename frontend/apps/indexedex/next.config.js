const path = require('node:path')
const { PHASE_DEVELOPMENT_SERVER } = require('next/constants')

module.exports = (phase) => {
  const deployment = process.env.NEXT_PUBLIC_SITE_DEPLOYMENT ?? 'indexedex'
  if (!['indexedex', 'dtf'].includes(deployment)) {
    throw new Error('NEXT_PUBLIC_SITE_DEPLOYMENT must be indexedex or dtf')
  }

  return {
    // Local variants must not share compiler output. Vercel builds are isolated
    // deployments and retain the standard output directory.
    distDir: phase === PHASE_DEVELOPMENT_SERVER ? `.next-${deployment}` : '.next',
    env: { NEXT_PUBLIC_SITE_DEPLOYMENT: deployment },
    allowedDevOrigins: ['127.0.0.1'],
    // Vercel resolves relativeAppDir from the repository root when packaging functions.
    outputFileTracingRoot: path.resolve(__dirname, '../../..'),
    transpilePackages: ['@indexedex/protocol'],
    webpack: (config) => {
      // Wallet connectors need the SDK's browser entry during SSR as well.
      // Its Node entry imports CDP server payments and optional x402 peers.
      config.resolve.alias = {
        ...config.resolve.alias,
        '@base-org/account$': require.resolve('@base-org/account/browser'),
      }
      return config
    },
  }
}
