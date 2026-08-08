import { defineConfig } from 'vitest/config'
import path from 'node:path'

export default defineConfig({
  test: {
    include: ['app/**/*.test.ts', 'app/**/*.test.tsx'],
    environment: 'node',
  },
  resolve: {
    alias: [
      {
        find: /^@indexedex\/protocol\/(.*)$/,
        replacement: path.resolve(__dirname, '../../packages/protocol/src/$1'),
      },
      {
        find: '@indexedex/protocol',
        replacement: path.resolve(__dirname, '../../packages/protocol/src/index.ts'),
      },
    ],
  },
})
