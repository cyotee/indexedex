import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="container mx-auto px-4">
      {/* Hero */}
      <div className="max-w-5xl mx-auto pt-10 pb-8 text-center">
        <h1 className="text-4xl md:text-5xl font-bold tracking-tight text-white">
          Welcome to Pachira
        </h1>
        <p className="mt-3 text-lg md:text-xl text-gray-300">
          Composed Indexed Liquidity - The next generation of DeFi
        </p>
      </div>

      {/* Cards */}
      <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-6">
        <Link
          href="/swap"
          className="p-6 bg-gray-800 rounded-lg shadow-lg hover:shadow-xl transition-colors transition-shadow duration-200 hover:bg-gray-700 border border-gray-700"
        >
          <h3 className="text-xl font-semibold text-white mb-2">Swap Tokens</h3>
          <p className="text-gray-300">Exchange tokens with the best rates using our advanced routing</p>
        </Link>

        <Link
          href="/vaults"
          className="p-6 bg-gray-800 rounded-lg shadow-lg hover:shadow-xl transition-colors transition-shadow duration-200 hover:bg-gray-700 border border-gray-700"
        >
          <h3 className="text-xl font-semibold text-white mb-2">Strategy Vaults</h3>
          <p className="text-gray-300">Deposit into strategy vaults for enhanced yield opportunities</p>
        </Link>

        <Link
          href="/pools"
          className="p-6 bg-gray-800 rounded-lg shadow-lg hover:shadow-xl transition-colors transition-shadow duration-200 hover:bg-gray-700 border border-gray-700"
        >
          <h3 className="text-xl font-semibold text-white mb-2">Manage Pools</h3>
          <p className="text-gray-300">Create and manage liquidity pools for the community</p>
        </Link>

        <Link
          href="/batch-swap"
          className="p-6 bg-gray-800 rounded-lg shadow-lg hover:shadow-xl transition-colors transition-shadow duration-200 hover:bg-gray-700 border border-gray-700"
        >
          <h3 className="text-xl font-semibold text-white mb-2">Batch Swap</h3>
          <p className="text-gray-300">Build multi-step swaps using the Batch Router</p>
        </Link>

        <Link
          href="/insights/vault"
          className="p-6 bg-gray-800 rounded-lg shadow-lg hover:shadow-xl transition-colors transition-shadow duration-200 hover:bg-gray-700 border border-gray-700"
        >
          <h3 className="text-xl font-semibold text-white mb-2">Vault Insights</h3>
          <p className="text-gray-300">Explore index source and pools for a selected strategy vault</p>
        </Link>
      </div>
    </div>
  )
}
