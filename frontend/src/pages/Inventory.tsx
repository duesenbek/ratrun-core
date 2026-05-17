import { Wrench, Battery, Cpu, Box, Fingerprint, Zap } from "lucide-react";
import sleepSticker from "../assets/stickers/sleep-deprived.png";
import { useInventory } from "../hooks/useInventory";

const ITEM_ICONS: Record<string, any> = {
  SCRAP: Wrench,
  BATTERY: Battery,
  WIRE: Zap,
  CHIP: Cpu,
  RELIC: Fingerprint,
  GPU: Cpu,
  SERVER: Zap,
  DRILL: Wrench,
};

const RARITY_COLORS: Record<string, string> = {
  COMMON: "text-gray-400 border-gray-400/30",
  UNCOMMON: "text-blue-400 border-blue-400/30",
  RARE: "text-primary border-primary/30",
  EPIC: "text-purple-400 border-purple-400/30",
};

export default function Inventory() {
  const { items } = useInventory();

  return (
    <div className="max-w-6xl mx-auto space-y-8 animate-in fade-in duration-700">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-end mb-8 border-b border-primary/30 pb-4">
        <div>
          <h1 className="text-4xl md:text-5xl font-black text-transparent bg-clip-text bg-gradient-to-r from-primary to-green-300 uppercase tracking-tighter mb-2">
            Cache
          </h1>
          <p className="text-muted flex items-center gap-2 text-sm font-mono">
            <Box className="w-4 h-4 text-primary" />
            SECURE STORAGE. LOCAL MANIFEST.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {items.map((item: {id: number, name: string, balance: number}) => {
          const Icon = ITEM_ICONS[item.name] || Box;
          const rarity = item.id === 0 ? "COMMON" : item.id < 3 ? "UNCOMMON" : item.id < 5 ? "RARE" : "EPIC";
          const rarityColor = RARITY_COLORS[rarity];

          return (
            <div key={item.id} className="glass-panel p-6 relative group overflow-hidden border border-white/5 hover:border-primary/50 transition-colors">
              <div className="absolute top-0 right-0 p-2 opacity-10 group-hover:opacity-20 transition-opacity">
                <Icon className="w-16 h-16" />
              </div>
              
              <div className="flex justify-between items-start mb-4 relative z-10">
                <div className={`p-2 rounded-sm border bg-black/40 ${rarityColor}`}>
                  <Icon className="w-6 h-6" />
                </div>
                <div className="text-right">
                  <div className={`text-[10px] font-black tracking-widest ${rarityColor}`}>
                    {rarity}
                  </div>
                  <div className="text-xs text-muted font-mono mt-1">ID: {String(item.id).padStart(3, '0')}</div>
                </div>
              </div>

              <div className="relative z-10">
                <h3 className="font-bold text-lg tracking-wider text-white mb-1">{item.name}</h3>
                <div className="flex items-end gap-2 mt-4">
                  <span className="text-3xl font-black font-mono text-primary">{item.balance}</span>
                  <span className="text-xs text-muted mb-1 tracking-widest">UNITS</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="mt-12 term-box flex items-center gap-6 p-6 border-primary/30">
        <img src={sleepSticker} alt="Sleep Deprived" className="w-24 h-24 object-contain animate-pulse" />
        <div>
          <h3 className="text-primary font-bold tracking-widest mb-2">SYSTEM WARNING</h3>
          <p className="text-sm text-muted">INVENTORY SPACE IS THEORETICALLY INFINITE. HOWEVER, HOARDING SCRAP DOES NOT YIELD INTEREST UNLESS DEPOSITED IN THE VAULT.</p>
        </div>
      </div>
    </div>
  );
}
