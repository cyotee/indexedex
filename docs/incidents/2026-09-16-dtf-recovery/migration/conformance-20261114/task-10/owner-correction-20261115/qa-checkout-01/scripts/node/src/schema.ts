import Ajv from 'ajv'
import addFormats from 'ajv-formats'
import tokenListSchema from '@uniswap/token-lists/src/tokenlist.schema.json' with { type: 'json' }
import type { TokenList } from './types.js'

const ajv = new Ajv({ allErrors: true, strict: false })
addFormats(ajv)
const validate = ajv.compile(tokenListSchema)

export interface ValidationResult {
  valid: boolean
  errors: string[]
}

export function validateTokenList(list: TokenList): ValidationResult {
  const valid = validate(list) as boolean
  const errors = valid
    ? []
    : (validate.errors ?? []).map((e) => `${e.instancePath || '<root>'} ${e.message ?? 'invalid'}`)
  return { valid, errors }
}
