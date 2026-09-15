import { defineConfig, globalIgnores } from 'eslint/config'
import nextVitals from 'eslint-config-next/core-web-vitals'

export default defineConfig([
  ...nextVitals,
  {
    // React Compiler is not enabled in this migration. Surface its newly added
    // diagnostics without forcing unrelated money-path rewrites into the upgrade.
    rules: {
      'react-hooks/set-state-in-effect': 'warn',
      'react-hooks/preserve-manual-memoization': 'warn',
      'react-hooks/refs': 'warn',
      'react-hooks/purity': 'warn',
    },
  },
  globalIgnores(['.next*/**', 'out/**', 'build/**', 'next-env.d.ts']),
])
