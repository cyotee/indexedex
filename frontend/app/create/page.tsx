'use client'

import { useAccount, useReadContract, useWriteContract } from 'wagmi'
import { useMemo, useState, useCallback } from 'react'
import DebugPanel from '../components/DebugPanel'
import { getFactories, getFactoryFunctions, type ContractListFactory, type ContractListArgument, type ContractListArgUI, buildOptionsFromUI, resolveLabel } from '../lib/contractlists'
import { erc20Abi, parseUnits } from 'viem'
import { explorerAddressUrl } from '../lib/explorer'
import {
    useWriteUniswapV2StandardExchangeDfPkgDeployVault,
    useWriteBalancerV3ConstantProductPoolStandardVaultPkgDeployVault,
    useSimulateUniswapV2StandardExchangeDfPkgDeployVault,
    useWatchVaultRegistryDeploymentFacetNewVaultEvent
} from '../generated'
import { useSelectedNetwork } from '../lib/networkSelection'

function ContractFunctionSelectField({
    arg,
    val,
    enabled,
    argsState,
    chainId,
    onChange,
}: {
    arg: ContractListArgument
    val: any
    enabled: boolean
    argsState: Record<string, any>
    chainId: number
    onChange: (next: any) => void
}) {
    const label = arg.name
    const abiCall = arg.ui?.abiCall
    const baseOptions = useMemo(() => buildOptionsFromUI(arg.ui, chainId), [arg.ui, chainId])

    const contract = useMemo(() => {
        if (!abiCall) return undefined
        return typeof abiCall.contractFrom === 'string' ? argsState[abiCall.contractFrom] : (abiCall.contractFrom as any)?.literal
    }, [abiCall, argsState])

    const args = useMemo(() => {
        if (!abiCall) return []
        return abiCall.argsFrom?.map(a => typeof a === 'string' ? argsState[a] : (a as any).literal) ?? []
    }, [abiCall, argsState])

    const { data: contractData } = useReadContract({
        address: (contract as `0x${string}` | undefined) ?? undefined,
        abi: abiCall?.inlineAbi ?? [],
        functionName: (abiCall?.function ?? '') as any,
        args,
        query: { enabled: !!abiCall && !!contract && args.every(a => a != null) },
    })

    const options = useMemo(() => {
        if (!abiCall || !contractData) return baseOptions
        if (!Array.isArray(contractData)) return baseOptions

        return (contractData as any[]).map((v) => {
            const labelVal = typeof arg.ui?.labelField === 'object' ? resolveLabel(String(v), arg.ui.labelField, chainId) : String(v)
            return { value: v, label: labelVal }
        })
    }, [abiCall, baseOptions, contractData, arg.ui?.labelField, chainId])

    return (
        <div className="mb-3">
            <label className="block text-sm text-gray-300 mb-1">{label}</label>
            <select
                value={val}
                onChange={e => onChange(e.target.value)}
                className="w-full rounded border border-slate-600 bg-slate-700 text-white p-2"
                disabled={!enabled}
            >
                <option value="">Select...</option>
                {options.map((o, i) => (
                    <option key={i} value={String(o.value)}>{o.label}</option>
                ))}
            </select>
        </div>
    )
}

export default function CreatePage() {
    const { isConnected } = useAccount()
    const { selectedChainId } = useSelectedNetwork()
    const { writeContract } = useWriteContract()

    const resolvedChainId = selectedChainId || 11155111
    const factories = useMemo(() => getFactories(resolvedChainId), [resolvedChainId])
    const [selectedFactoryIndex, setSelectedFactoryIndex] = useState<number>(-1)
    const selectedFactory: ContractListFactory | undefined = factories[selectedFactoryIndex]

    const functions = useMemo(() => selectedFactory ? getFactoryFunctions(selectedFactory) : [], [selectedFactory])
    const [selectedFunctionIndex, setSelectedFunctionIndex] = useState<number>(-1)
    const selectedFn = functions[selectedFunctionIndex]

    // Dynamic argument state
    const [argsState, setArgsState] = useState<Record<string, any>>({})

    const setArgValue = useCallback((name: string, value: any) => {
        setArgsState(prev => ({ ...prev, [name]: value }))
    }, [])

    function isFieldEnabled(arg: ContractListArgument): boolean {
        if (!arg.ui?.dependsOn) return true
        return arg.ui.dependsOn.every(dep => argsState[dep] != null && argsState[dep] !== '')
    }

    function renderField(arg: ContractListArgument, idx: number) {
        const enabled = isFieldEnabled(arg)
        if (!enabled) return null

        // tuple[] repeater
        if (arg.type as string === 'tuple[]') {
            const items: any[] = argsState[arg.name] || []
            const canAdd = arg.maxItems ? items.length < arg.maxItems : true
            const canRemove = items.length > (arg.minItems || 0)
            return (
                <div key={idx} className="border border-slate-600 rounded p-3 mb-3">
                    <div className="text-sm text-gray-300 mb-2">{arg.description}</div>
                    {items.map((it, i) => (
                        <div key={i} className="border border-slate-500 rounded p-2 mb-2">
                            {arg.components?.map((c, j) => renderSimpleField(c, `${arg.name}.${i}.${c.name}`, j, `${arg.name}.${i}`))}
                            {canRemove && (
                                <button type="button" className="px-2 py-1 text-xs bg-red-700 rounded" onClick={() => {
                                    const next = [...items]
                                    next.splice(i, 1)
                                    setArgValue(arg.name, next)
                                }}>{arg.ui?.array?.removeLabel || 'Remove'}</button>
                            )}
                        </div>
                    ))}
                    {canAdd && (
                        <button type="button" className="px-2 py-1 text-xs bg-blue-700 rounded" onClick={() => {
                            const defaults = arg.components?.reduce((acc, c) => ({ ...acc, [c.name]: c.default ?? null }), {}) ?? {}
                            const next = [...items, defaults]
                            setArgValue(arg.name, next)
                        }}>{arg.ui?.array?.addLabel || 'Add'}</button>
                    )}
                </div>
            )
        }
        // Fallback to simple field
        return renderSimpleField(arg, arg.name, idx)
    }

    function renderSimpleField(arg: ContractListArgument, key: string, idx: number, parentKey?: string) {
        const val = parentKey ? argsState[parentKey]?.[arg.name] : argsState[key] ?? arg.default ?? ''
        const label = arg.name
        const widget = arg.ui?.widget || (arg.type.endsWith('[]') ? 'multiselect' : arg.type === 'bool' ? 'checkbox' : 'text')
        const enabled = isFieldEnabled(arg)
        const updateVal = (newVal: any) => {
            if (parentKey) {
                setArgsState(prev => {
                    const parent = { ...(prev[parentKey] ?? {}) }
                    parent[arg.name] = newVal
                    return { ...prev, [parentKey]: parent }
                })
            } else {
                setArgValue(key, newVal)
            }
        }

        if (widget === 'address' || widget === 'text') {
            const isValid = !arg.ui?.validation?.regex || new RegExp(arg.ui.validation.regex).test(val)
            return (
                <div key={idx} className="mb-3">
                    <label className="block text-sm text-gray-300 mb-1">{label}</label>
                    <input
                        value={val}
                        onChange={e => updateVal(e.target.value)}
                        className={`w-full rounded border ${isValid ? 'border-slate-600' : 'border-red-600'} bg-slate-700 text-white p-2`}
                        disabled={!enabled}
                    />
                    {!isValid && arg.ui?.validation?.errorMessage && (
                        <p className="text-xs text-red-400 mt-1">{arg.ui.validation.errorMessage}</p>
                    )}
                </div>
            )
        }
        if (widget === 'select') {
            if (arg.ui?.source === 'contractFunction') {
                return (
                    <ContractFunctionSelectField
                        key={idx}
                        arg={arg}
                        val={val}
                        enabled={enabled}
                        argsState={argsState}
                        chainId={resolvedChainId}
                        onChange={updateVal}
                    />
                )
            }

            const options = buildOptionsFromUI(arg.ui, resolvedChainId)
            return (
                <div key={idx} className="mb-3">
                    <label className="block text-sm text-gray-300 mb-1">{label}</label>
                    <select value={val} onChange={e => updateVal(e.target.value)} className="w-full rounded border border-slate-600 bg-slate-700 text-white p-2" disabled={!enabled}>
                        <option value="">Select...</option>
                        {options.map((o, i) => (
                            <option key={i} value={String(o.value)}>{o.label}</option>
                        ))}
                    </select>
                </div>
            )
        }
        if (widget === 'multiselect') {
            const options = buildOptionsFromUI(arg.ui, resolvedChainId)
            const selected: any[] = Array.isArray(val) ? val : []
            return (
                <div key={idx} className="mb-3">
                    <label className="block text-sm text-gray-300 mb-1">{label}</label>
                    <div className="space-y-1">
                        {options.map((o, i) => {
                            const checked = selected.includes(o.value)
                            return (
                                <label key={i} className="flex items-center gap-2 text-sm text-gray-300">
                                    <input type="checkbox" checked={checked} disabled={!enabled} onChange={(e) => {
                                        const next = new Set(selected)
                                        if (e.target.checked) next.add(o.value); else next.delete(o.value)
                                        updateVal(Array.from(next))
                                    }} />
                                    {o.label}
                                </label>
                            )
                        })}
                    </div>
                </div>
            )
        }
        if (widget === 'checkbox') {
            return (
                <div key={idx} className="mb-3 flex items-center gap-2">
                    <input type="checkbox" checked={!!val} disabled={!enabled} onChange={e => updateVal(e.target.checked)} />
                    <label className="text-sm text-gray-300">{label}</label>
                </div>
            )
        }
        if (widget === 'radio') {
            const options = buildOptionsFromUI(arg.ui)
            return (
                <div key={idx} className="mb-3">
                    <label className="block text-sm text-gray-300 mb-1">{label}</label>
                    <div className="space-y-1">
                        {options.map((o, i) => (
                            <label key={i} className="flex items-center gap-2 text-sm text-gray-300">
                                <input type="radio" value={o.value} checked={val === o.value} disabled={!enabled} onChange={() => updateVal(o.value)} />
                                {o.label}
                            </label>
                        ))}
                    </div>
                </div>
            )
        }
        if (widget === 'slider') {
            return (
                <div key={idx} className="mb-3">
                    <label className="block text-sm text-gray-300 mb-1">{label} ({val})</label>
                    <input type="range" value={val} min={0} max={100} disabled={!enabled} onChange={e => updateVal(Number(e.target.value))} className="w-full" />
                </div>
            )
        }
        return null
    }

    const { writeContract: writeUniV2Deploy } = useWriteUniswapV2StandardExchangeDfPkgDeployVault()
    const { writeContract: writeBalDeploy } = useWriteBalancerV3ConstantProductPoolStandardVaultPkgDeployVault()
    const { data: uniSim } = useSimulateUniswapV2StandardExchangeDfPkgDeployVault({
        args: argsState['pool'] ? [argsState['pool'] as `0x${string}`] : undefined,
        query: { enabled: selectedFactory?.hookName === 'UniswapV2StandardStrategyVaultPkg' && selectedFn?.functionName === 'deployVault' && !!argsState['pool'] }
    })

    // Watch NewVault events (display last seen)
    const [lastNewVault, setLastNewVault] = useState<string>('')
    useWatchVaultRegistryDeploymentFacetNewVaultEvent({
        onLogs: (logs) => {
            const last = logs[logs.length - 1]
            const v = (last?.args as any)?.vault as string | undefined
            if (v) setLastNewVault(v)
        }
    })

    const handleSubmit = useCallback(async () => {
        if (!selectedFactory || !selectedFn) return
        try {
            if (selectedFactory.hookName === 'UniswapV2StandardStrategyVaultPkg' && selectedFn.functionName === 'deployVault') {
                const pool = argsState['pool'] as `0x${string}`
                if (!pool) throw new Error('pool is required')
                await writeUniV2Deploy({ args: [pool] as const })
                return
            }
            if (selectedFactory.hookName === 'balancerV3ConstantProductPoolStandardVaultPkg' && selectedFn.functionName === 'deployVault') {
                const tokenConfigs = (argsState['tokenConfigs'] as any[] || []).map((it) => ({
                    token: it['token'] ?? '0x0000000000000000000000000000000000000000',
                    tokenType: Number(it['tokenType'] ?? 0),
                    rateProvider: it['rateProvider'] ?? '0x0000000000000000000000000000000000000000',
                    paysYieldFees: Boolean(it['paysYieldFees'] ?? false)
                }))
                const hooksContract = (argsState['hooksContract'] || '0x0000000000000000000000000000000000000000') as `0x${string}`
                await writeBalDeploy({ args: [tokenConfigs as any, hooksContract] as const })
                return
            }
            if (selectedFactory.hookName === 'StandardExchangeSingleVaultSeigniorageDETFDFPkg' && selectedFn.functionName === 'deployDetf') {
                // Stub: Implement useWrite... for this hook
                console.log('DETF deploy not implemented', argsState)
                return
            }
            console.log('Submitting (no writer wired)', { factory: selectedFactory.name, fn: selectedFn.functionName, argsState })
        } catch (e) {
            console.error('Create failed', e)
        }
    }, [selectedFactory, selectedFn, argsState, writeUniV2Deploy, writeBalDeploy])

    if (!isConnected) {
        return (
            <div className="container mx-auto px-4">
                <div className="text-center pt-10 pb-6">
                    <h1 className="text-3xl font-bold text-white">Create</h1>
                    <p className="text-gray-300 mt-2">Connect your wallet to create contracts</p>
                </div>
            </div>
        )
    }

    return (
        <div className="container mx-auto px-4 max-w-4xl">
            <h1 className="text-3xl font-bold text-white text-center py-8">Create</h1>

            {/* Factory Selector */}
            <div className="mb-6">
                <label className="block text-sm font-medium text-gray-300 mb-2">Factory</label>
                <select
                    value={selectedFactoryIndex}
                    onChange={(e) => { setSelectedFactoryIndex(parseInt(e.target.value, 10)); setSelectedFunctionIndex(-1); setArgsState({}) }}
                    className="w-full rounded border border-slate-600 bg-slate-700 text-white p-3"
                >
                    <option value={-1}>Select a Factory</option>
                    {factories.map((f, i) => (
                        <option key={i} value={i}>{f.name}</option>
                    ))}
                </select>
            </div>

            {/* Function Selector */}
            {selectedFactory && (
                <div className="mb-6">
                    <label className="block text-sm font-medium text-gray-300 mb-2">Function</label>
                    <select
                        value={selectedFunctionIndex}
                        onChange={(e) => { setSelectedFunctionIndex(parseInt(e.target.value, 10)); setArgsState({}) }}
                        className="w-full rounded border border-slate-600 bg-slate-700 text-white p-3"
                    >
                        <option value={-1}>Select a Function</option>
                        {functions.map((fn, i) => (
                            <option key={i} value={i}>{fn.label}</option>
                        ))}
                    </select>
                </div>
            )}

            {/* Arguments Form */}
            {selectedFn && (
                <div className="mb-6">
                    <div className="space-y-2">
                        {selectedFn.args.map((arg, idx) => renderField(arg, idx))}
                    </div>
                </div>
            )}

            {/* Result Strategies Preview */}
            {selectedFactory?.hookName === 'UniswapV2StandardStrategyVaultPkg' && selectedFn?.functionName === 'deployVault' && (
                <div className="mb-6 p-4 bg-slate-700/50 rounded-lg text-sm text-gray-300">
                    {uniSim?.result && (
                        <div className="mb-1">Expected Vault (simulate): {String(uniSim.result)}</div>
                    )}
                    {lastNewVault && (
                        <div className="mb-1">
                            New Vault (event):
                            {(() => {
                                const url = explorerAddressUrl(resolvedChainId, lastNewVault)
                                if (!url) return <span className="ml-1">{lastNewVault}</span>
                                return (
                                    <a className="text-blue-400 underline ml-1" href={url} target="_blank" rel="noreferrer">{lastNewVault}</a>
                                )
                            })()}
                        </div>
                    )}
                </div>
            )}

            {/* Action */}
            {selectedFn && (
                <div className="mb-10">
                    <button
                        onClick={handleSubmit}
                        className="w-full py-3 px-4 bg-blue-600 text-white rounded-md disabled:opacity-50"
                    >
                        Create
                    </button>
                </div>
            )}

            <DebugPanel title="Create Debug">
                <div>Factory Index: {selectedFactoryIndex}</div>
                <div>Function Index: {selectedFunctionIndex}</div>
                <div>Args: {JSON.stringify(argsState)}</div>
            </DebugPanel>
        </div>
    )
}