'use client'

import { debugLog } from '../lib/debug'

export default function TestPage() {
  const handleClick = () => {
    debugLog('Test button clicked')
    alert('Button works!')
  }

  return (
    <div>
      <h1>Test Page</h1>
      <button onClick={handleClick} className="bg-blue-500 text-white px-4 py-2 rounded">
        Test Button
      </button>
    </div>
  )
}
