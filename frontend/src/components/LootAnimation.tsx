import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { PackageOpen, Lock, Pickaxe, Cpu, Zap, Shield, Wrench } from "lucide-react";
import wagmiSticker from "../assets/stickers/wagmi.png";

type LootState = "idle" | "opening" | "revealed";

// Mock loot items using lucide icons instead of emojis
const LOOT_POOL = [
  { name: "LEGENDARY SERVER", color: "text-yellow-400", bg: "bg-yellow-400/10", border: "border-yellow-400", icon: Shield },
  { name: "EPIC GPU", color: "text-purple-400", bg: "bg-purple-400/10", border: "border-purple-400", icon: Cpu },
  { name: "RARE RELIC", color: "text-blue-400", bg: "bg-blue-400/10", border: "border-blue-400", icon: Shield },
  { name: "UNCOMMON CHIP", color: "text-green-400", bg: "bg-green-400/10", border: "border-green-400", icon: Cpu },
  { name: "COMMON SCRAP", color: "text-gray-400", bg: "bg-gray-400/10", border: "border-gray-600", icon: Wrench },
  { name: "COMMON BATTERY", color: "text-gray-400", bg: "bg-gray-400/10", border: "border-gray-600", icon: Zap },
];

export default function LootAnimation() {
  const [state, setState] = useState<LootState>("idle");
  const [result, setResult] = useState<typeof LOOT_POOL[0] | null>(null);
  const [shufflingItem, setShufflingItem] = useState(LOOT_POOL[0]);

  const handleOpen = () => {
    setState("opening");
    
    // Simulate VRF delay & shuffle animation
    let count = 0;
    const interval = setInterval(() => {
      setShufflingItem(LOOT_POOL[Math.floor(Math.random() * LOOT_POOL.length)]);
      count++;
      if (count > 20) {
        clearInterval(interval);
        // "VRF" resolved
        setResult(LOOT_POOL[Math.floor(Math.random() * LOOT_POOL.length)]);
        setState("revealed");
      }
    }, 150);
  };

  const reset = () => {
    setState("idle");
    setResult(null);
  };

  return (
    <div className="term-box w-full max-w-md mx-auto p-8 flex flex-col items-center justify-center min-h-[400px]">
      <h2 className="text-xl font-bold tracking-widest text-primary mb-8">
        MAZE LOOT CRATE
      </h2>

      <div className="flex-1 w-full flex items-center justify-center relative">
        <AnimatePresence mode="wait">
          
          {state === "idle" && (
            <motion.div
              key="idle"
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.8, opacity: 0 }}
              className="flex flex-col items-center cursor-pointer group"
              onClick={handleOpen}
            >
              <div className="w-32 h-32 border-2 border-primary border-dashed rounded-lg flex items-center justify-center bg-primary/5 group-hover:bg-primary/10 transition-colors shadow-glow relative">
                <Lock className="w-12 h-12 text-primary" />
                <div className="absolute -bottom-3 px-2 bg-background text-primary text-xs tracking-widest">
                  CLICK TO OPEN
                </div>
              </div>
            </motion.div>
          )}

          {state === "opening" && (
            <motion.div
              key="opening"
              className="flex flex-col items-center"
            >
              <div className="w-32 h-32 border-2 border-muted flex items-center justify-center relative overflow-hidden">
                <motion.div
                  animate={{ y: [0, -10, 0] }}
                  transition={{ repeat: Infinity, duration: 0.2 }}
                >
                  <PackageOpen className="w-12 h-12 text-muted" />
                </motion.div>
                <div className="absolute inset-0 bg-primary/20 animate-pulse"></div>
              </div>
              <div className="mt-6 text-sm text-primary tracking-widest animate-pulse">
                AWAITING VRF...
              </div>
              <div className="mt-4 flex items-center gap-2 border border-muted px-4 py-2 opacity-50">
                <shufflingItem.icon className={`w-4 h-4 ${shufflingItem.color}`} />
                <span className={`text-xs ${shufflingItem.color} font-mono`}>{shufflingItem.name}</span>
              </div>
            </motion.div>
          )}

          {state === "revealed" && result && (
            <motion.div
              key="revealed"
              initial={{ scale: 0.5, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              className="flex flex-col items-center w-full"
            >
              <div className={`w-full max-w-xs border-2 ${result.border} ${result.bg} p-6 flex flex-col items-center text-center shadow-[0_0_30px_rgba(0,0,0,0.5)]`} style={{ boxShadow: `0 0 30px var(--${result.color.split('-')[1]})` }}>
                <result.icon className={`w-16 h-16 ${result.color} mb-4 drop-shadow-[0_0_10px_currentColor]`} />
                <div className={`text-xs mb-1 opacity-80 tracking-widest ${result.color}`}>LOOT ACQUIRED</div>
                <div className={`text-xl font-bold tracking-widest ${result.color}`}>{result.name}</div>
              </div>
              
              <img src={wagmiSticker} alt="WAGMI" className="w-24 h-24 object-contain mt-6" />

              <button 
                onClick={reset}
                className="mt-6 text-xs border border-primary text-primary px-4 py-2 hover:bg-primary hover:text-background transition-colors"
              >
                COLLECT & RETURN
              </button>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
