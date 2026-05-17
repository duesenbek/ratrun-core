import { Package, Shield, Zap, Cpu, Wrench } from "lucide-react";

// Mock data based on GameItems.sol
const INVENTORY_ITEMS = [
  { id: 0, name: "SCRAP", amount: 1542, rarity: "COMMON", icon: Wrench },
  { id: 1, name: "BATTERY", amount: 12, rarity: "COMMON", icon: Zap },
  { id: 2, name: "WIRE", amount: 45, rarity: "COMMON", icon: Package },
  { id: 3, name: "CHIP", amount: 7, rarity: "UNCOMMON", icon: Cpu },
  { id: 4, name: "RELIC", amount: 1, rarity: "RARE", icon: Shield },
  { id: 5, name: "DRILL", amount: 3, rarity: "UNCOMMON", icon: Wrench },
  { id: 6, name: "GPU", amount: 0, rarity: "EPIC", icon: Cpu },
  { id: 7, name: "SERVER", amount: 0, rarity: "LEGENDARY", icon: Shield },
];

const RARITY_COLORS: Record<string, string> = {
  COMMON: "text-gray-400 border-gray-800",
  UNCOMMON: "text-green-400 border-green-900",
  RARE: "text-blue-400 border-blue-900",
  EPIC: "text-purple-400 border-purple-900",
  LEGENDARY: "text-yellow-400 border-yellow-900 glow-primary",
};

export default function Inventory() {
  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-primary tracking-widest">INVENTORY</h1>
        <div className="text-sm text-muted">TOTAL ITEMS: 8</div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {INVENTORY_ITEMS.map((item) => (
          <div key={item.id} className={`term-box flex flex-col items-center justify-center p-6 text-center ${RARITY_COLORS[item.rarity]}`}>
            <item.icon className="w-10 h-10 mb-4 opacity-80" />
            <div className="text-sm font-bold tracking-wider mb-1">{item.name}</div>
            <div className="text-xs opacity-70 mb-3">{item.rarity}</div>
            <div className="text-2xl font-mono">{item.amount}</div>
          </div>
        ))}
      </div>
      
      <div className="mt-8 flex justify-center">
         <a href="/craft" className="pixel-btn">GO TO CRAFTING</a>
      </div>
    </div>
  );
}
