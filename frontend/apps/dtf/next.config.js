/** @type {import('next').NextConfig} */
const sharedConfig = require('../indexedex/next.config')

module.exports = {
  ...sharedConfig,
  env: { ...sharedConfig.env, NEXT_PUBLIC_SITE_DEPLOYMENT: 'dtf' },
}
