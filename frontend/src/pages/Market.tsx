import { AlertTriangle, Shield, Battery, Cpu, Lock, ChevronRight } from "lucide-react";
import ngmiSticker from "../assets/stickers/ngmi.png";

const MOCK_ITEMS = [
  { id: 1, name: "CORRUPTED KEYCARD", type: "ACCESS", price: 500, rarity: "rare", icon: Lock, desc: "Grants access to high-security burrow sectors. Single use." },
  { id: 2, name: "OVERCLOCKED CPU", type: "HARDWARE", price: 1200, rarity: "epic", icon: Cpu, desc: "Increases scrap mining efficiency by 15% for 24 hours." },
  { id: 3, name: "EMP GRENADE", type: "WEAPON", price: 300, rarity: "uncommon", icon: Battery, desc: "Disables exterminator drones for 30 seconds." },
  { id: 4, name: "STEALTH CLOAK v2", type: "GEAR", price: 2500, rarity: "legendary", icon: Shield, desc: "Renders the user invisible to thermal scans." },
];

export default function Market() {
  return (
    <div className="max-w-6xl mx-auto space-y-8 animate-in fade-in duration-700 relative z-10 pb-20">
      
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-end mb-8 border-b border-red-500/30 pb-4">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <AlertTriangle className="w-8 h-8 text-red-500 animate-pulse" />
            <h1 className="text-4xl md:text-5xl font-black text-transparent bg-clip-text bg-gradient-to-r from-red-500 to-orange-500 uppercase tracking-tighter glitch-text">
              <span aria-hidden="true">BLACK MARKET</span>
              BLACK MARKET
              <span aria-hidden="true">BLACK MARKET</span>
            </h1>
          </div>
          <p className="text-muted flex items-center gap-2 text-sm">
            SECURE ENCRYPTED CHANNEL. UNREGULATED GOODS. NO REFUNDS.
          </p>
        </div>
        <div className="mt-4 md:mt-0 glass-panel px-4 py-2 rounded-sm border-l-4 border-l-red-500 bg-red-950/20">
          <span className="text-xs text-red-400 block">MARKET STATUS</span>
          <span className="text-red-500 font-bold tracking-widest animate-pulse">OPEN // UNDETECTED</span>
        </div>
      </div>

      {/* Featured Item / Alert */}
      <div className="glass-panel border border-red-500/30 bg-red-950/10 p-6 flex flex-col md:flex-row gap-8 items-center relative overflow-hidden group">
        <div className="absolute inset-0 bg-gradient-to-r from-red-500/5 to-transparent z-0"></div>
        <div className="relative z-10 w-32 h-32 flex-shrink-0 bg-black/50 rounded-full border-2 border-red-500/50 flex items-center justify-center p-4 shadow-[0_0_20px_rgba(239,68,68,0.2)]">
          <img src={ngmiSticker} alt="Vendor" className="w-full h-full object-contain filter grayscale contrast-150" />
        </div>
        <div className="relative z-10 flex-1 space-y-3">
          <div className="inline-block px-2 py-1 bg-red-500/20 text-red-400 text-xs font-bold rounded-sm border border-red-500/30">
            VENDOR_TRANSMISSION
          </div>
          <h3 className="text-xl font-bold text-white uppercase">"The Exterminators are sweeping sector 4."</h3>
          <p className="text-muted text-sm max-w-xl">
            Stock up while you can. We're moving operations in 12 hours. Everything must go. Payment in SCRAP only.
          </p>
        </div>
      </div>

      {/* Market Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {MOCK_ITEMS.map((item) => (
          <div key={item.id} className="glass-panel border border-white/10 hover:border-red-500/50 transition-all group relative overflow-hidden flex flex-col h-full">
            {/* Scanline hover effect */}
            <div className="absolute inset-0 bg-red-500/5 translate-y-[100%] group-hover:translate-y-0 transition-transform duration-500 ease-in-out z-0"></div>
            
            <div className="p-4 border-b border-white/5 relative z-10 flex justify-between items-start">
              <div className={`p-3 rounded-sm bg-black/50 border ${
                item.rarity === 'legendary' ? 'border-yellow-500 text-yellow-500' :
                item.rarity === 'epic' ? 'border-purple-500 text-purple-500' :
                item.rarity === 'rare' ? 'border-blue-500 text-blue-500' :
                'border-green-500 text-green-500'
              }`}>
                <item.icon className="w-6 h-6" />
              </div>
              <div className="text-right">
                <div className="text-xs text-muted mb-1">{item.type}</div>
                <div className="text-xs uppercase font-bold tracking-widest opacity-70" style={{
                  color: item.rarity === 'legendary' ? '#eab308' : item.rarity === 'epic' ? '#a855f7' : item.rarity === 'rare' ? '#3b82f6' : '#22c55e'
                }}>{item.rarity}</div>
              </div>
            </div>
            
            <div className="p-4 relative z-10 flex-1 flex flex-col">
              <h4 className="font-bold text-white uppercase mb-2 group-hover:text-red-400 transition-colors">{item.name}</h4>
              <p className="text-xs text-muted flex-1">{item.desc}</p>
              
              <div className="mt-6 pt-4 border-t border-white/5 flex items-center justify-between">
                <div className="font-mono text-lg font-bold text-primary flex items-center gap-1">
                  <span className="text-xs text-muted">§</span> {item.price}
                </div>
                <button className="px-3 py-1.5 bg-red-500/10 hover:bg-red-500 hover:text-white text-red-500 text-xs font-bold uppercase tracking-wider border border-red-500/50 transition-colors flex items-center gap-1">
                  BUY <ChevronRight className="w-3 h-3" />
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
      
    </div>
  );
}
