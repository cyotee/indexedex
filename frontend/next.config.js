/** @type {import('next').NextConfig} */
const nextConfig = {
	webpack: (config) => {
		config.resolve = config.resolve || {}
		config.resolve.alias = {
			...(config.resolve.alias || {}),
			'@base-org/account': false,
			'@coinbase/wallet-sdk': false,
			'@gemini-wallet/core': false,
			'@metamask/sdk': false,
			'@safe-global/safe-apps-provider': false,
			'@safe-global/safe-apps-sdk': false,
			'@walletconnect/ethereum-provider': false,
		}
		return config
	},
}

module.exports = nextConfig
