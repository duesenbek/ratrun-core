import { useState } from "react";
import { AlertTriangle, ArrowDownUp } from "lucide-react";
import ngmiSticker from "../assets/stickers/ngmi.png";
import { useMarket } from "../hooks/useMarket";
import { useAccount } from "wagmi";

export default function Market() {
  const { allowance0, allowance1, approve, swap, isPending } = useMarket();
  const { isConnected } = useAccount();

  const [amountIn, setAmountIn] = useState("");
  const [zeroForOne, setZeroForOne] = useState(true);

  const amountBI = amountIn && !isNaN(Number(amountIn)) ? BigInt(amountIn) : 0n;
  const currentAllowance = zeroForOne ? allowance0 : allowance1;
  const needsApproval = amountBI > 0n && currentAllowance < amountBI;

  const handleAction = () => {
    if (!amountIn || isNaN(Number(amountIn))) return;
    if (needsApproval) {
      approve(zeroForOne);
    } else {
      swap(BigInt(amountIn), zeroForOne);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8 animate-in fade-in duration-700 relative z-10 pb-20">
      
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-end mb-8 border-b border-red-500/30 pb-4">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <AlertTriangle className="w-8 h-8 text-red-500 animate-pulse" />
            <h1 className="text-4xl md:text-5xl font-black text-transparent bg-clip-text bg-gradient-to-r from-red-500 to-orange-500 uppercase tracking-tighter glitch-text">
              <span aria-hidden="true">NIGHT MARKET</span>
              NIGHT MARKET
              <span aria-hidden="true">NIGHT MARKET</span>
            </h1>
          </div>
          <p className="text-muted flex items-center gap-2 text-sm">
            RESOURCE AMM // UNREGULATED EXCHANGE.
          </p>
        </div>
        <div className="mt-4 md:mt-0 glass-panel px-4 py-2 rounded-sm border-l-4 border-l-red-500 bg-red-950/20">
          <span className="text-xs text-red-400 block">MARKET STATUS</span>
          <span className="text-red-500 font-bold tracking-widest animate-pulse">OPEN // UNDETECTED</span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        
        {/* Swap Panel */}
        <div className="col-span-1 md:col-span-2 glass-panel border border-red-500/30 p-8 relative overflow-hidden group">
          <div className="absolute inset-0 bg-gradient-to-br from-red-500/5 to-transparent z-0"></div>
          
          <div className="relative z-10 space-y-6">
            <div>
              <label className="text-xs text-muted font-bold tracking-wider block mb-2">PAY</label>
              <div className="relative">
                <input 
                  type="number" 
                  value={amountIn}
                  onChange={(e) => setAmountIn(e.target.value)}
                  className="w-full bg-black/50 border border-red-500/30 p-4 text-white font-mono focus:border-red-500 focus:ring-1 focus:ring-red-500 focus:outline-none transition-all"
                  placeholder="0.0"
                />
                <div className="absolute right-4 top-1/2 -translate-y-1/2 text-red-500 font-bold">
                  {zeroForOne ? "SCRAP" : "BATTERY"}
                </div>
              </div>
            </div>

            <div className="flex justify-center my-4">
              <button 
                onClick={() => setZeroForOne(!zeroForOne)}
                className="p-3 bg-red-900/20 border border-red-500/30 rounded-full hover:bg-red-500/20 transition-colors group/swap"
              >
                <ArrowDownUp className="w-5 h-5 text-red-500 group-hover/swap:rotate-180 transition-transform duration-500" />
              </button>
            </div>

            <div>
              <label className="text-xs text-muted font-bold tracking-wider block mb-2">RECEIVE (ESTIMATED)</label>
              <div className="relative opacity-70">
                <input 
                  type="text" 
                  disabled
                  value="MARKET RATE"
                  className="w-full bg-black/30 border border-red-500/10 p-4 text-white font-mono cursor-not-allowed"
                />
                <div className="absolute right-4 top-1/2 -translate-y-1/2 text-red-500/50 font-bold">
                  {zeroForOne ? "BATTERY" : "SCRAP"}
                </div>
              </div>
            </div>

            <button 
              onClick={handleAction}
              disabled={!isConnected || isPending || !amountIn}
              className="w-full text-xl py-4 mt-6 flex items-center justify-center gap-3 bg-red-500/20 text-red-500 border border-red-500/50 hover:bg-red-500 hover:text-white transition-all uppercase tracking-wider font-bold shadow-[0_0_15px_rgba(239,68,68,0.2)] disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isPending ? (
                <span className="animate-pulse">{needsApproval ? "APPROVING..." : "SWAPPING..."}</span>
              ) : (
                needsApproval ? `APPROVE ${zeroForOne ? "SCRAP" : "BATTERY"}` : "EXECUTE TRADE"
              )}
            </button>
          </div>
        </div>

        {/* Vendor Info */}
        <div className="glass-panel border border-red-500/30 bg-red-950/10 p-6 flex flex-col items-center text-center relative overflow-hidden h-fit">
          <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/carbon-fibre.png')] opacity-20 z-0"></div>
          <div className="relative z-10 w-32 h-32 flex-shrink-0 bg-black/50 rounded-full border-2 border-red-500/50 flex items-center justify-center p-4 mb-6 shadow-[0_0_20px_rgba(239,68,68,0.2)]">
            <img src={ngmiSticker} alt="Vendor" className="w-full h-full object-contain filter grayscale contrast-150" />
          </div>
          <div className="relative z-10 space-y-3">
            <div className="inline-block px-2 py-1 bg-red-500/20 text-red-400 text-xs font-bold rounded-sm border border-red-500/30 mb-2">
              VENDOR_TRANSMISSION
            </div>
            <p className="text-muted text-sm leading-relaxed">
              "The Exterminators are sweeping sector 4. Trade your tokens now. Liquidity is drying up."
            </p>
          </div>
        </div>

      </div>
    </div>
  );
}
