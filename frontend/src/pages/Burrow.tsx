import { useState } from "react";
import { ArrowDownToLine, ArrowUpFromLine, Activity } from "lucide-react";
import sleepDeprivedSticker from "../assets/stickers/emotion-sleep-deprived.png";

export default function Burrow() {
  const [amount, setAmount] = useState("");

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <div className="flex justify-between items-center mb-8 border-b border-muted pb-4">
        <h1 className="text-3xl font-bold text-primary tracking-widest">BURROW VAULT</h1>
        <div className="flex items-center gap-2 text-sm">
          <Activity className="w-4 h-4 text-primary" />
          <span className="text-primary glow-primary">APY: 14.2%</span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        <div className="col-span-1 md:col-span-2 space-y-6">
          
          <div className="grid grid-cols-2 gap-4">
            <div className="term-box">
              <div className="text-xs text-muted mb-1">YOUR SHARES (bSCRAP)</div>
              <div className="text-2xl font-mono">0.00</div>
            </div>
            <div className="term-box border-primary">
              <div className="text-xs text-muted mb-1">EARNED YIELD</div>
              <div className="text-2xl font-mono text-primary">+0.00</div>
            </div>
          </div>

          <div className="term-box p-6 space-y-6">
            <div>
              <label className="text-xs text-muted block mb-2">AMOUNT (SCRAP)</label>
              <input 
                type="number" 
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="w-full bg-background border border-muted p-3 text-text font-mono focus:border-primary focus:outline-none transition-colors"
                placeholder="0.0"
              />
            </div>
            
            <div className="grid grid-cols-2 gap-4">
              <button className="pixel-btn flex items-center justify-center gap-2 bg-muted hover:bg-muted/80 text-white">
                <ArrowDownToLine className="w-4 h-4" />
                DEPOSIT
              </button>
              <button className="pixel-btn flex items-center justify-center gap-2">
                <ArrowUpFromLine className="w-4 h-4" />
                WITHDRAW
              </button>
            </div>
          </div>
        </div>

        <div className="term-box flex flex-col items-center p-6 text-center">
          <img src={sleepDeprivedSticker} alt="Passive Income" className="w-32 h-32 object-contain mb-4" />
          <h3 className="font-bold mb-2">PASSIVE SCRAP</h3>
          <p className="text-xs text-muted">
            Send your gear into the underground burrow. The deeper it goes, the more yield it generates while you sleep.
          </p>
        </div>
      </div>
    </div>
  );
}
