import { useEffect, useMemo, useState } from 'react'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import type { Address } from 'viem'
import { erc20Abi, maxUint256 } from 'viem'
import { useAccount, useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'

const TOKEN: Address = (import.meta.env.VITE_TOKEN_ADDRESS as Address) ?? ('0x0000000000000000000000000000000000000000' as Address)
const MARKET: Address = (import.meta.env.VITE_MARKET_ADDRESS as Address) ?? ('0x0000000000000000000000000000000000000000' as Address) // PredictionMarketAMM

const predictionMarketAbi = [
  {
    inputs: [],
    name: 'numMarkets',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'uint256', name: 'marketId', type: 'uint256' },
      { internalType: 'uint8', name: 'outcome', type: 'uint8' },
      { internalType: 'uint256', name: 'amountIn', type: 'uint256' },
    ],
    name: 'buy',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'uint256', name: 'marketId', type: 'uint256' },
      { internalType: 'address', name: 'user', type: 'address' },
    ],
    name: 'getBalances',
    outputs: [
      { internalType: 'uint256', name: 'yesShares', type: 'uint256' },
      { internalType: 'uint256', name: 'noShares', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: 'marketId', type: 'uint256' }],
    name: 'getMarket',
    outputs: [
      { internalType: 'string', name: 'question', type: 'string' },
      { internalType: 'uint64', name: 'endTime', type: 'uint64' },
      { internalType: 'bool', name: 'resolved', type: 'bool' },
      { internalType: 'bool', name: 'invalid', type: 'bool' },
      { internalType: 'uint8', name: 'winningOutcome', type: 'uint8' },
      { internalType: 'uint16', name: 'feeBps', type: 'uint16' },
      { internalType: 'uint256', name: 'protocolFeesAccrued', type: 'uint256' },
      { internalType: 'uint256', name: 'yesLiquidity', type: 'uint256' },
      { internalType: 'uint256', name: 'noLiquidity', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: 'marketId', type: 'uint256' }],
    name: 'claim',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'uint256', name: 'marketId', type: 'uint256' },
      { internalType: 'uint8', name: 'outcome', type: 'uint8' },
    ],
    name: 'getCurrentPrice',
    outputs: [
      { internalType: 'uint256', name: 'price', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
] as const

export default function App() {
  const { address } = useAccount()
  const [amount, setAmount] = useState('1000000') // 1 USDT with 6 decimals
  const [outcome, setOutcome] = useState<'YES' | 'NO'>('YES')
  const [lastTxHash, setLastTxHash] = useState<`0x${string}` | undefined>(undefined)
  const [txError, setTxError] = useState<string | undefined>(undefined)
  const [selectedMarketId, setSelectedMarketId] = useState<bigint>(0n)
  const [nowTs, setNowTs] = useState<number>(Math.floor(Date.now() / 1000))

  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as Address

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: TOKEN,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [(address as Address) ?? ZERO_ADDRESS, MARKET],
  })

  // Markets listing
  const { data: numMarkets } = useReadContract({
    address: MARKET,
    abi: predictionMarketAbi,
    functionName: 'numMarkets',
  })
  const marketCount = (numMarkets as bigint) ?? 0n
  const ids: bigint[] = Array.from({ length: Number(marketCount) }, (_, i) => BigInt(i))
  const { data: marketSummaries } = useReadContracts({
    contracts: ids.map((id) => ({
      address: MARKET,
      abi: predictionMarketAbi,
      functionName: 'getMarket',
      args: [id],
    })),
  })

  const { data: balances } = useReadContract({
    address: MARKET,
    abi: predictionMarketAbi,
    functionName: 'getBalances',
    args: [selectedMarketId, (address as Address) ?? ZERO_ADDRESS],
  })

  const { data: marketInfo } = useReadContract({
    address: MARKET,
    abi: predictionMarketAbi,
    functionName: 'getMarket',
    args: [selectedMarketId],
  })

  // AMM prices (1e18 scaled)
  const { data: yesPrice } = useReadContract({
    address: MARKET,
    abi: predictionMarketAbi,
    functionName: 'getCurrentPrice',
    args: [selectedMarketId, 1],
  })
  const { data: noPrice } = useReadContract({
    address: MARKET,
    abi: predictionMarketAbi,
    functionName: 'getCurrentPrice',
    args: [selectedMarketId, 2],
  })

  const { writeContractAsync, data: hash, isPending } = useWriteContract()
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash: lastTxHash ?? hash })

  const needsApproval = (allowance ?? 0n) < BigInt(amount || '0')
  const mi = marketInfo as
    | readonly [string, bigint, boolean, boolean, number, bigint, bigint, bigint, bigint]
    | undefined
  const isResolved = mi ? mi[2] : false
  const winningOutcome = mi ? mi[4] : 0
  const isInvalid = mi ? mi[3] : false
  const endTime = mi ? Number(mi[1]) : undefined
  const yesLiq = mi ? (mi[7] as bigint) : 0n
  const noLiq = mi ? (mi[8] as bigint) : 0n

  // Ticking clock for end-time guard and countdown
  useEffect(() => {
    const id = setInterval(() => setNowTs(Math.floor(Date.now() / 1000)), 1000)
    return () => clearInterval(id)
  }, [])

  const isTradingOpen = useMemo(() => {
    if (!endTime) return false
    return !isResolved && nowTs < endTime
  }, [endTime, isResolved, nowTs])

  const countdown = useMemo(() => {
    if (!endTime) return '—'
    const s = Math.max(0, endTime - nowTs)
    const hh = Math.floor(s / 3600)
    const mm = Math.floor((s % 3600) / 60)
    const ss = s % 60
    return `${hh.toString().padStart(2, '0')}:${mm
      .toString()
      .padStart(2, '0')}:${ss.toString().padStart(2, '0')}`
  }, [endTime, nowTs])

  const formatPrice = (p?: bigint) => {
    if (!p) return '—'
    // 1e18 scale; show 4 decimals
    const integer = Number(p / 1000000000000000n) / 1000
    return integer.toFixed(4)
  }

  const bals = balances as readonly [bigint, bigint] | undefined
  const canClaim =
    isResolved &&
    ((winningOutcome === 1 && (bals?.[0] ?? 0n) > 0n) ||
      (winningOutcome === 2 && (bals?.[1] ?? 0n) > 0n) ||
      isInvalid)

  // Refetch allowance after any tx confirms so UI can switch from Approve -> Buy
  useEffect(() => {
    if (!isConfirming && hash) {
      // best-effort refetch; ignore result
      refetchAllowance?.()
    }
  }, [isConfirming, hash, refetchAllowance])

  return (
    <div style={{ maxWidth: 640, margin: '40px auto', fontFamily: 'sans-serif' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 24 }}>
        <h2>Prediction Market</h2>
        <ConnectButton />
      </div>

      <div style={{ padding: 16, border: '1px solid #333', borderRadius: 8 }}>
        {/* Market list */}
        <div style={{ marginBottom: 16 }}>
          <div style={{ fontWeight: 600, marginBottom: 8 }}>Markets</div>
          {ids.length === 0 && <div style={{ fontSize: 14 }}>No markets yet.</div>}
          {ids.length > 0 && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {ids.map((id, idx) => {
                const ms = marketSummaries?.[idx]?.result as
                  | readonly [string, bigint, boolean, boolean, number, bigint, bigint, bigint, bigint]
                  | undefined
                const question = ms ? ms[0] : `Market #${id.toString()}`
                const resolved = ms ? ms[2] : false
                const isSel = id === selectedMarketId
                return (
                  <button
                    key={id.toString()}
                    onClick={() => setSelectedMarketId(id)}
                    style={{
                      textAlign: 'left',
                      padding: '8px 10px',
                      borderRadius: 6,
                      border: '1px solid #444',
                      background: isSel ? '#2a2a2a' : 'transparent',
                      color: resolved ? '#aaa' : '#fff',
                      cursor: 'pointer',
                    }}
                  >
                    #{id.toString()}: {question} {resolved ? '(resolved)' : ''}
                  </button>
                )
              })}
            </div>
          )}
        </div>

        <div style={{ marginBottom: 12 }}>
          Market #{selectedMarketId.toString()}: {mi ? mi[0] : 'Loading...'}
          {isResolved && (
            <div style={{ fontSize: 14, marginTop: 8, padding: 8, background: '#333', borderRadius: 4 }}>
              {isInvalid ? 'Invalid - refunds available' : 
               winningOutcome === 1 ? 'Resolved: YES wins' : 
               winningOutcome === 2 ? 'Resolved: NO wins' : 'Resolved'}
            </div>
          )}
          {!isResolved && (
            <div style={{ fontSize: 13, marginTop: 8, padding: 8, background: '#2a2a2a', borderRadius: 4 }}>
              {isTradingOpen ? `Trading open — ends in ${countdown}` : 'Trading closed'}
            </div>
          )}
        </div>

        {/* AMM widgets */}
        <div style={{ display: 'flex', gap: 16, marginBottom: 16, fontSize: 14 }}>
          <div style={{ padding: 8, border: '1px solid #333', borderRadius: 6 }}>
            <div>YES price: {formatPrice(yesPrice as bigint | undefined)}</div>
            <div>YES liquidity: {yesLiq.toString()}</div>
          </div>
          <div style={{ padding: 8, border: '1px solid #333', borderRadius: 6 }}>
            <div>NO price: {formatPrice(noPrice as bigint | undefined)}</div>
            <div>NO liquidity: {noLiq.toString()}</div>
          </div>
        </div>

        {!isResolved && isTradingOpen && (
          <>
            <label>
              Amount (USDT, 6dp):
              <input
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                style={{ marginLeft: 8 }}
              />
            </label>

            <div style={{ marginTop: 12 }}>
              <label>
                Outcome:
                <select
                  value={outcome}
                  onChange={(e) => setOutcome((e.target.value as 'YES' | 'NO'))}
                  style={{ marginLeft: 8 }}
                >
                  <option>YES</option>
                  <option>NO</option>
                </select>
              </label>
            </div>

            <div style={{ marginTop: 16, display: 'flex', gap: 12 }}>
              {needsApproval && (
                <button
                  onClick={async () => {
                    setTxError(undefined)
                    try {
                      const h = await writeContractAsync({
                        address: TOKEN,
                        abi: erc20Abi,
                        functionName: 'approve',
                        // Approve max to avoid repeated approvals
                        args: [MARKET, maxUint256],
                      })
                      setLastTxHash(h as `0x${string}`)
                    } catch (e) {
                      const err = e as { shortMessage?: string; message?: string }
                      setTxError(err?.shortMessage || err?.message || 'Approval failed')
                    }
                  }}
                  disabled={!address || isPending || isConfirming}
                >
                  {isPending || isConfirming ? 'Approving...' : 'Approve'}
                </button>
              )}

              {!needsApproval && (
                <button
                  onClick={async () => {
                    setTxError(undefined)
                    try {
                      const h = await writeContractAsync({
                        address: MARKET,
                        abi: predictionMarketAbi as never,
                        functionName: 'buy',
                        args: [selectedMarketId, outcome === 'YES' ? 1 : 2, BigInt(amount || '0')],
                      })
                      setLastTxHash(h as `0x${string}`)
                    } catch (e) {
                      const err = e as { shortMessage?: string; message?: string }
                      setTxError(err?.shortMessage || err?.message || 'Buy failed')
                    }
                  }}
                  disabled={!address || isPending || isConfirming}
                >
                  {isPending || isConfirming ? 'Buying...' : `Buy ${outcome}`}
                </button>
              )}
            </div>
          </>
        )}

        {isResolved && canClaim && (
          <div style={{ marginTop: 16 }}>
            <button
              onClick={async () => {
                setTxError(undefined)
                try {
                  const h = await writeContractAsync({
                    address: MARKET,
                    abi: predictionMarketAbi as never,
                    functionName: 'claim',
                    args: [selectedMarketId],
                  })
                  setLastTxHash(h as `0x${string}`)
                } catch (e) {
                  const err = e as { shortMessage?: string; message?: string }
                  setTxError(err?.shortMessage || err?.message || 'Claim failed')
                }
              }}
              disabled={!address || isPending || isConfirming}
              style={{ background: '#4CAF50', color: 'white', padding: '8px 16px', border: 'none', borderRadius: 4 }}
            >
              {isPending || isConfirming ? 'Claiming...' : 'Claim Winnings'}
            </button>
          </div>
        )}

        <div style={{ marginTop: 16, fontSize: 14 }}>
          Your balances: YES {(bals?.[0] ?? 0n).toString()} | NO {(bals?.[1] ?? 0n).toString()}
        </div>

        {(lastTxHash || txError) && (
          <div style={{ marginTop: 12, fontSize: 12 }}>
            {lastTxHash && (
              <a href={`https://sepolia.basescan.org/tx/${lastTxHash}`} target="_blank" rel="noreferrer">
                View transaction on BaseScan
              </a>
            )}
            {txError && (
              <div style={{ color: '#f66', marginTop: 8 }}>Error: {txError}</div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
