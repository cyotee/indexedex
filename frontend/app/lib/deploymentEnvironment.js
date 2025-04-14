"use strict";
'use client';
Object.defineProperty(exports, "__esModule", { value: true });
exports.DeploymentEnvironmentToggle = exports.useDeploymentEnvironment = exports.isDeploymentEnvironment = exports.DeploymentEnvironmentContext = exports.DEFAULT_DEPLOYMENT_ENVIRONMENT = exports.DEPLOYMENT_ENVIRONMENT_STORAGE_KEY = void 0;
const react_1 = require("react");
const addresses_1 = require("../addresses");
exports.DEPLOYMENT_ENVIRONMENT_STORAGE_KEY = 'indexedex:deployment-environment';
exports.DEFAULT_DEPLOYMENT_ENVIRONMENT = process.env.NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT ?? 'supersim_sepolia';
exports.DeploymentEnvironmentContext = (0, react_1.createContext)({
    environment: exports.DEFAULT_DEPLOYMENT_ENVIRONMENT,
    setEnvironment: () => { },
});
function isDeploymentEnvironment(value) {
    return addresses_1.DEPLOYMENT_ENVIRONMENTS.includes(value);
}
exports.isDeploymentEnvironment = isDeploymentEnvironment;
function useDeploymentEnvironment() {
    return (0, react_1.useContext)(exports.DeploymentEnvironmentContext);
}
exports.useDeploymentEnvironment = useDeploymentEnvironment;
function DeploymentEnvironmentToggle() {
    const { environment, setEnvironment } = useDeploymentEnvironment();
    return (<div className="fixed bottom-4 right-4 z-40 rounded-xl border border-slate-700 bg-slate-900/90 px-3 py-2 text-xs text-slate-100 shadow-lg backdrop-blur">
      <label className="mb-1 block font-medium text-slate-300" htmlFor="deployment-environment-toggle">
        Environment
      </label>
      <select id="deployment-environment-toggle" className="rounded-md border border-slate-600 bg-slate-950 px-2 py-1 text-sm text-white" value={environment} onChange={(event) => setEnvironment(event.target.value)}>
        {addresses_1.DEPLOYMENT_ENVIRONMENTS.map((option) => (<option key={option} value={option}>
            {option}
          </option>))}
      </select>
    </div>);
}
exports.DeploymentEnvironmentToggle = DeploymentEnvironmentToggle;
