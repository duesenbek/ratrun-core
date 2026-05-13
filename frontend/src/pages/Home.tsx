import { Link } from "react-router-dom";
import { useAccount } from "wagmi";
import { Terminal, Pickaxe, Vault, Users, ShoppingCart } from "lucide-react";
import gmSticker from "../assets/stickers/gm.png";

export default function Home() {
  const { isConnected } = useAccount();

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      {/* Dashboard Top */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        
        {/* Profile / Mascot */}
        <div className="term-box col-span-1 md:col-span-2 flex items-center gap-6">
          <img src={gmSticker} alt="Ratoshi GM" className="w-32 h-32 object-contain" />
          <div>
            <h1 className="text-2xl font-bold text-primary uppercase mb-2">
              Welcome, {isConnected ? "Runner" : "Guest"}
            </h1>
            <p className="text-sm text-muted">
              {isConnected 
                ? "Your gear is ready. The underground awaits." 
                : "Connect your wallet to access the RatRun network."}
            </p>
            <div className="mt-4 flex gap-4">
              <div className="text-xs">
                <span className="text-muted">STATUS: </span>
                <span className={isConnected ? "text-primary" : "text-red-500"}>
                  {isConnected ? "ONLINE" : "OFFLINE"}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="term-box col-span-1 flex flex-col justify-center">
          <div className="mb-4">
            <div className="text-xs text-muted mb-1">SCRAP BALANCE</div>
            <div className="text-3xl text-primary font-bold">0.00</div>
          </div>
          <div>
            <div className="text-xs text-muted mb-1">NEXT LOOT DROP</div>
            <div className="text-xl">04:20:00</div>
          </div>
        </div>
      </div>

      {/* Main Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="term-box flex flex-col items-center justify-center p-8 text-center min-h-[200px]">
          <h2 className="text-xl font-bold mb-4">ENTER THE MAZE</h2>
          <button 
            disabled={!isConnected}
            className="pixel-btn w-full max-w-xs text-lg disabled:opacity-50 disabled:cursor-not-allowed"
          >
            START RUN
          </button>
        </div>
        
        <div className="grid grid-cols-2 gap-4">
          <Link to="/inventory" className="term-box flex flex-col items-center justify-center hover:border-primary transition-colors cursor-pointer text-center group">
            <Pickaxe className="w-8 h-8 mb-2 text-muted group-hover:text-primary transition-colors" />
            <span className="text-sm font-bold">INVENTORY & CRAFT</span>
          </Link>
          
          <Link to="/burrow" className="term-box flex flex-col items-center justify-center hover:border-primary transition-colors cursor-pointer text-center group">
            <Vault className="w-8 h-8 mb-2 text-muted group-hover:text-primary transition-colors" />
            <span className="text-sm font-bold">BURROW VAULT</span>
          </Link>
          
          <Link to="/market" className="term-box flex flex-col items-center justify-center hover:border-primary transition-colors cursor-pointer text-center group">
            <ShoppingCart className="w-8 h-8 mb-2 text-muted group-hover:text-primary transition-colors" />
            <span className="text-sm font-bold">BLACK MARKET</span>
          </Link>

          <Link to="/council" className="term-box flex flex-col items-center justify-center hover:border-primary transition-colors cursor-pointer text-center group">
            <Users className="w-8 h-8 mb-2 text-muted group-hover:text-primary transition-colors" />
            <span className="text-sm font-bold">THE COUNCIL</span>
          </Link>
        </div>
      </div>

      {/* Terminal Log */}
      <div className="term-box">
        <div className="flex items-center gap-2 border-b border-muted pb-2 mb-2">
          <Terminal className="w-4 h-4 text-primary" />
          <span className="text-xs text-muted">SYSTEM_LOG</span>
        </div>
        <div className="text-xs text-muted font-mono h-24 overflow-y-auto space-y-1">
          <div>{'>'} INITIALIZING RATRUN_OS... OK</div>
          <div>{'>'} CONNECTING TO BASE SEPOLIA... OK</div>
          <div>{'>'} WAITING FOR USER INPUT...</div>
        </div>
      </div>
    </div>
  );
}
