/** @type {import('next').NextConfig} */
const path = require('node:path')
// Next's dev route watcher does not traverse a symlinked app directory. DTF
// development runs from this canonical directory with its own output cache.
const dtfDevelopment = process.env.INDEXEDEX_DTF_DEV === 'true'
const nextConfig = {
  distDir: dtfDevelopment ? '.next-dtf' : '.next',
  env: { NEXT_PUBLIC_SITE_DEPLOYMENT: dtfDevelopment ? 'dtf' : 'indexedex' },
  // Vercel resolves relativeAppDir from the repository root when packaging functions.
  experimental: { outputFileTracingRoot: path.resolve(__dirname, '../../..') },
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

module.exports = nextConfig
