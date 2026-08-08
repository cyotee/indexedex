'use client'

import { useEffect } from 'react'
import { debugError } from '../lib/debug'

export default function TokenInfoError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    debugError('[token-info] route error:', error)
  }, [error])

  return (
    <div className="container mx-auto px-4 max-w-3xl">
      <div className="text-center pt-10 pb-6">
        <h1 className="text-3xl font-bold text-white">Token Information</h1>
        <p className="text-gray-300 mt-2">
          This page hit a runtime error. The wallet connect UI should still work; try reloading or retrying.
        </p>
      </div>

      <div className="bg-red-900/30 border border-red-700 rounded-lg p-4 text-red-200 text-sm">
        <div className="font-semibold mb-2">Error</div>
        <div className="font-mono break-words">{error?.message ?? 'Unknown error'}</div>
        {error?.digest ? <div className="mt-2 text-xs opacity-80">Digest: {error.digest}</div> : null}
      </div>

      <div className="mt-4 flex gap-2 justify-center">
        <button
          onClick={() => reset()}
          className="px-3 py-1 text-xs rounded-md border border-gray-600 bg-gray-700 text-gray-200 hover:bg-gray-600"
        >
          Retry
        </button>
        <button
          onClick={() => window.location.reload()}
          className="px-3 py-1 text-xs rounded-md border border-gray-600 bg-gray-700 text-gray-200 hover:bg-gray-600"
        >
          Reload
        </button>
      </div>
    </div>
  )
}
