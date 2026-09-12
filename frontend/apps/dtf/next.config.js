/** @type {import('next').NextConfig} */
const nextConfig = {
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
