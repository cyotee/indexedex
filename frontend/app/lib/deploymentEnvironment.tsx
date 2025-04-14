'use client'

import { createContext, useContext } from 'react'

import {
  DEPLOYMENT_ENVIRONMENTS,
  type DeploymentEnvironment,
} from '../addresses'

export const DEPLOYMENT_ENVIRONMENT_STORAGE_KEY = 'indexedex:deployment-environment'
export const DEFAULT_DEPLOYMENT_ENVIRONMENT: DeploymentEnvironment =
  (process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT as DeploymentEnvironment | undefined) ?? 'supersim_sepolia'

export type DeploymentEnvironmentContextValue = {
  environment: DeploymentEnvironment
  setEnvironment: (environment: DeploymentEnvironment) => void
}

export const DeploymentEnvironmentContext = createContext<DeploymentEnvironmentContextValue>({
  environment: DEFAULT_DEPLOYMENT_ENVIRONMENT,
  setEnvironment: () => {},
})

export function isDeploymentEnvironment(value: string): value is DeploymentEnvironment {
  return (DEPLOYMENT_ENVIRONMENTS as string[]).includes(value)
}

export function useDeploymentEnvironment(): DeploymentEnvironmentContextValue {
  return useContext(DeploymentEnvironmentContext)
}

export function DeploymentEnvironmentToggle() {
  const { environment, setEnvironment } = useDeploymentEnvironment()

  return (
    <div className="fixed bottom-4 right-4 z-40 rounded-xl border border-slate-700 bg-slate-900/90 px-3 py-2 text-xs text-slate-100 shadow-lg backdrop-blur">
      <label className="mb-1 block font-medium text-slate-300" htmlFor="deployment-environment-toggle">
        Environment
      </label>
      <select
        id="deployment-environment-toggle"
        className="rounded-md border border-slate-600 bg-slate-950 px-2 py-1 text-sm text-white"
        value={environment}
        onChange={(event) => setEnvironment(event.target.value as DeploymentEnvironment)}
      >
        {DEPLOYMENT_ENVIRONMENTS.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    </div>
  )
}
