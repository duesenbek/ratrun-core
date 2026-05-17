import { useState } from "react";
import { ArrowDownToLine, ArrowUpFromLine, Activity } from "lucide-react";
import sleepDeprivedSticker from "../assets/stickers/sleep-deprived.png";
import { useBurrow } from "../hooks/useBurrow";
import { useAccount } from "wagmi";

export default function Burrow() {
  const [amount, setAmount] = useState("");
  const { shares, assets, allowance, deposit, withdraw, approve, isPending } = useBurrow();
  const { isConnected } = useAccount();

  const amountBI = amount && !isNaN(Number(amount)) ? BigInt(amount) : 0n;
  const needsApproval = amountBI > 0n && allowance < amountBI;

  const handleDeposit = () => {
    if (!amount || isNaN(Number(amount))) return;
    if (needsApproval) {
      approve();
    } else {
      deposit(BigInt(amount));
    }
  };

  const handleWithdraw = () => {
    if (!amount || isNaN(Number(amount))) return;
    withdraw(BigInt(amount));
  };

  const earnedYield = Math.max(0, assets - shares);

  return (
    <div className="max-w-4xl mx-auto space-y-8 animate-in fade-in duration-700">
      <div className="flex justify-between items-center mb-8 border-b border-primary/30 pb-4">
        <h1 className="text-3xl font-bold text-primary tracking-widest uppercase glitch-text">
          <span aria-hidden="true">BURROW VAULT</span>
          BURROW VAULT
          <span aria-hidden="true">BURROW VAULT</span>
        </h1>
        <div className="flex items-center gap-2 text-sm bg-primary/10 px-3 py-1 rounded border border-primary/30">
          <Activity className="w-4 h-4 text-primary animate-pulse" />
          <span className="text-primary font-bold tracking-widest">APY: 14.2%</span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        <div className="col-span-1 md:col-span-2 space-y-6">
          
          <div className="grid grid-cols-2 gap-4">
            <div className="glass-panel p-4 border-l-2 border-l-primary/50 relative overflow-hidden group">
              <div className="absolute inset-0 bg-primary/5 group-hover:bg-primary/10 transition-colors"></div>
              <div className="text-xs text-muted mb-1 font-bold tracking-wider relative z-10">YOUR SHARES (bSCRAP)</div>
              <div className="text-3xl font-mono text-white relative z-10">
                {isConnected ? shares.toLocaleString() : "0.00"}
              </div>
            </div>
            <div className="glass-panel p-4 border-l-2 border-l-primary relative overflow-hidden group">
              <div className="absolute inset-0 bg-primary/10 group-hover:bg-primary/20 transition-colors"></div>
              <div className="text-xs text-primary mb-1 font-bold tracking-wider relative z-10">EARNED YIELD</div>
              <div className="text-3xl font-mono text-primary font-bold relative z-10">
                +{isConnected ? earnedYield.toLocaleString(undefined, {minimumFractionDigits: 2}) : "0.00"}
              </div>
            </div>
          </div>

          <div className="glass-panel p-6 space-y-6 border border-primary/30">
            <div>
              <label className="text-xs text-muted font-bold tracking-wider block mb-2">AMOUNT (SCRAP)</label>
              <div className="relative">
                <input 
                  type="number" 
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="w-full bg-black/50 border border-primary/30 p-4 text-white font-mono focus:border-primary focus:ring-1 focus:ring-primary focus:outline-none transition-all"
                  placeholder="0.0"
                />
                <div className="absolute right-4 top-1/2 -translate-y-1/2 text-primary/50 font-bold">SCRAP</div>
              </div>
            </div>
            
            <div className="grid grid-cols-2 gap-4">
              <button 
                onClick={handleDeposit}
                disabled={!isConnected || isPending || !amount}
                className="pixel-btn flex items-center justify-center gap-2 disabled:opacity-50 group hover:scale-[1.02]"
              >
                <ArrowDownToLine className="w-5 h-5 group-hover:animate-bounce" />
                {isPending ? (
                  <span className="animate-pulse">{needsApproval ? "APPROVING..." : "DEPOSITING..."}</span>
                ) : (
                  needsApproval ? "APPROVE SCRAP" : "DEPOSIT"
                )}
              </button>
              <button 
                onClick={handleWithdraw}
                disabled={!isConnected || isPending || !amount}
                className="flex items-center justify-center gap-2 bg-transparent border border-primary text-primary hover:bg-primary hover:text-black transition-all font-bold uppercase tracking-wider py-3 disabled:opacity-50 group hover:scale-[1.02]"
              >
                <ArrowUpFromLine className="w-5 h-5 group-hover:-translate-y-1 transition-transform" />
                WITHDRAW
              </button>
            </div>
          </div>
        </div>

        <div className="glass-panel flex flex-col items-center p-6 text-center border border-primary/20 relative overflow-hidden group">
          <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/carbon-fibre.png')] opacity-20"></div>
          <div className="relative z-10">
            <div className="w-32 h-32 mb-6 rounded-full bg-primary/10 border border-primary/30 flex items-center justify-center p-4 shadow-[0_0_20px_rgba(182,255,0,0.15)] group-hover:scale-110 transition-transform duration-500">
              <img src={sleepDeprivedSticker} alt="Passive Income" className="w-full h-full object-contain filter contrast-125" />
            </div>
            <h3 className="font-bold mb-3 text-primary tracking-widest text-lg">PASSIVE SCRAP</h3>
            <p className="text-sm text-muted leading-relaxed">
              Send your gear into the underground burrow. The deeper it goes, the more yield it generates while you sleep.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
