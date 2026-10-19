/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Keep copied templates independent of any enclosing monorepo.
  turbopack: { root: __dirname },
};

module.exports = nextConfig;
