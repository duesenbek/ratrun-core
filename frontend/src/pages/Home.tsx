import { useState } from "react";
import { Link } from "react-router-dom";
import { useAccount } from "wagmi";
import { Terminal, Pickaxe, Vault, Users, ShoppingCart, Crosshair, Zap, Shield, ChevronRight, Activity } from "lucide-react";
import gmSticker from "../assets/stickers/gm.png";
import { useRatMaze } from "../hooks/useRatMaze";
import { useInventory } from "../hooks/useInventory";

export default function Home() {
  const { isConnected } = useAccount();
  const [selectedZone, setSelectedZone] = useState<number>(1);
  const [systemLogs, setSystemLogs] = useState<string[]>([
    "> [04:00:11] INITIALIZING RATRUN_OS... OK",
    "> [04:00:12] CONNECTING TO BASE SEPOLIA... OK"
  ]);

  const { isActive, remainingTimeSeconds, isFinished, enterMaze, claimLoot, isPending } = useRatMaze();
  const { scrapBalance } = useInventory();

  // Format time (MM:SS)
  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60).toString().padStart(2, '0');
    const s = (seconds % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  };

  const handleDeploy = () => {
    if (!isConnected) return;
    enterMaze(selectedZone);
    setSystemLogs(prev => [...prev, `> [SYSTEM] DEPLOYING RUNNER TO ZONE ${selectedZone}...`]);
  };

  const handleClaim = () => {
    if (!isConnected) return;
    claimLoot();
    setSystemLogs(prev => [...prev, `> [SYSTEM] CLAIMING LOOT...`]);
  };

  return (
    <div className="max-w-6xl mx-auto space-y-8 animate-in fade-in duration-700 relative z-10 pb-20">
      
      {/* Header Area with Glitch Title */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-end mb-8 border-b border-primary/30 pb-4">
        <div>
          <h1 className="text-4xl md:text-6xl font-black text-transparent bg-clip-text bg-gradient-to-r from-primary to-green-300 uppercase tracking-tighter mb-2">
            RatRun Network
          </h1>
          <p className="text-muted flex items-center gap-2">
            <Activity className="w-4 h-4 text-primary animate-pulse" />
            SECURE CONNECTION ESTABLISHED. WELCOME TO THE UNDERGROUND.
          </p>
        </div>
        <div className="mt-4 md:mt-0 glass-panel px-4 py-2 rounded-sm border-l-4 border-l-primary">
          <span className="text-xs text-muted block">GLOBAL NETWORK STATUS</span>
          <span className="text-primary font-bold tracking-widest">OPTIMAL // SYNCHRONIZED</span>
        </div>
      </div>

      {/* Main Dashboard Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Profile Card (Left Column) */}
        <div className="lg:col-span-4 space-y-6">
          <div className="glass-panel neon-border p-6 relative overflow-hidden group">
            <div className="absolute top-0 right-0 p-2 opacity-20 group-hover:opacity-100 transition-opacity">
              <Crosshair className="w-16 h-16 text-primary" strokeWidth={1} />
            </div>
            
            <div className="flex items-center gap-6 mb-6">
              <div className="relative">
                <div className="w-24 h-24 rounded-full border-2 border-primary/50 overflow-hidden bg-black/50 p-2 shadow-[0_0_15px_rgba(182,255,0,0.2)]">
                  <img src={gmSticker} alt="Ratoshi GM" className="w-full h-full object-contain filter contrast-125" />
                </div>
                {isConnected && (
                  <div className="absolute bottom-0 right-0 w-4 h-4 bg-primary rounded-full border-2 border-black animate-pulse-glow" />
                )}
              </div>
              <div>
                <div className="text-xs text-muted mb-1 font-bold tracking-wider">OPERATIVE ID</div>
                <h2 className="text-xl font-bold text-white uppercase truncate max-w-[150px]">
                  {isConnected ? "Runner_0x9A" : "GUEST_USER"}
                </h2>
                <div className="mt-2 inline-block px-2 py-1 bg-primary/20 text-primary text-xs font-bold rounded-sm border border-primary/30">
                  {isConnected ? "RANK: STREET RAT" : "UNREGISTERED"}
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="bg-black/40 p-3 rounded-sm border border-white/5">
                <div className="flex justify-between items-center mb-1">
                  <span className="text-xs text-muted">SCRAP BALANCE</span>
                  <Zap className="w-4 h-4 text-yellow-500" />
                </div>
                <div className="text-2xl text-primary font-mono font-bold tracking-wider">
                  {isConnected ? scrapBalance.toLocaleString(undefined, {minimumFractionDigits: 2}) : "0.00"}
                </div>
              </div>
              
              <div className="bg-black/40 p-3 rounded-sm border border-white/5">
                <div className="flex justify-between items-center mb-1">
                  <span className="text-xs text-muted">NEXT LOOT DROP</span>
                  <Shield className="w-4 h-4 text-blue-500" />
                </div>
                <div className="text-xl text-white font-mono tracking-wider">
                  {isActive ? formatTime(remainingTimeSeconds) : "00:00"}
                </div>
                <div className="w-full h-1 bg-white/10 mt-2 rounded-full overflow-hidden relative">
                  {isActive && remainingTimeSeconds > 0 && (
                    <div className="h-full bg-blue-500 animate-pulse w-full"></div>
                  )}
                  {isFinished && (
                    <div className="h-full bg-green-500 w-full shadow-[0_0_10px_rgba(34,197,94,0.8)]"></div>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Terminal Log */}
          <div className="glass-panel border-t-2 border-t-primary p-4 h-48 flex flex-col">
            <div className="flex items-center justify-between border-b border-white/10 pb-2 mb-3">
              <div className="flex items-center gap-2">
                <Terminal className="w-4 h-4 text-primary" />
                <span className="text-xs font-bold tracking-widest text-white/70">SYSTEM_LOG</span>
              </div>
              <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
            </div>
            <div className="text-xs text-primary/80 font-mono overflow-y-auto space-y-2 flex-1 scrollbar-hide flex flex-col-reverse">
              <div className="animate-pulse">{'>'} _</div>
              {systemLogs.map((log, index) => (
                <div key={index} className="text-white opacity-90">{log}</div>
              ))}
            </div>
          </div>
        </div>

        {/* Main Action Area (Right Column) */}
        <div className="lg:col-span-8 space-y-6 flex flex-col">
          
          {/* Hero Action Banner - The Maze */}
          <div className="glass-panel border border-primary/40 relative overflow-hidden flex-1 min-h-[300px] flex flex-col justify-center items-center p-8 group">
            <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] opacity-10 group-hover:opacity-20 transition-opacity z-0"></div>
            
            {/* Corner Decorations */}
            <div className="absolute top-0 left-0 w-8 h-8 border-t-2 border-l-2 border-primary m-4 z-10"></div>
            <div className="absolute top-0 right-0 w-8 h-8 border-t-2 border-r-2 border-primary m-4 z-10"></div>
            <div className="absolute bottom-0 left-0 w-8 h-8 border-b-2 border-l-2 border-primary m-4 z-10"></div>
            <div className="absolute bottom-0 right-0 w-8 h-8 border-b-2 border-r-2 border-primary m-4 z-10"></div>

            <div className="z-10 w-full max-w-2xl flex flex-col h-full">
              <div className="text-center mb-6">
                <h2 className="text-3xl font-black text-white tracking-widest uppercase mb-2 glitch-text">
                  <span aria-hidden="true">ENTER THE MAZE</span>
                  ENTER THE MAZE
                  <span aria-hidden="true">ENTER THE MAZE</span>
                </h2>
                <p className="text-muted text-sm">Deploy your rat. Scavenge for scrap. Survive.</p>
              </div>
              
              <div className="grid grid-cols-3 gap-4 mb-8 flex-1">
                {/* Zone 1 */}
                <div 
                  onClick={() => setSelectedZone(1)}
                  className={`border ${selectedZone === 1 ? 'border-primary ring-2 ring-primary bg-primary/10' : 'border-green-500/30 bg-green-900/10'} p-4 flex flex-col items-center text-center cursor-pointer hover:border-green-500 hover:bg-green-500/10 transition-all group/zone relative`}
                >
                  <div className="absolute top-0 right-0 p-1 text-xs text-green-500 font-bold opacity-50">Z-1</div>
                  <h3 className={`font-bold mb-1 ${selectedZone === 1 ? 'text-primary' : 'text-white group-hover/zone:text-green-400'}`}>SEWER GRID</h3>
                  <div className="text-xs text-muted mb-2">Safe • Low Yield</div>
                  <div className="mt-auto w-full">
                    <div className="text-xs flex justify-between mb-1"><span className="text-muted">Survival:</span> <span className="text-green-500">90%</span></div>
                    <div className="text-xs flex justify-between"><span className="text-muted">Time:</span> <span className="text-white">1 Min</span></div>
                  </div>
                </div>

                {/* Zone 2 */}
                <div 
                  onClick={() => setSelectedZone(2)}
                  className={`border ${selectedZone === 2 ? 'border-primary ring-2 ring-primary bg-primary/10' : 'border-yellow-500/50 bg-yellow-900/20'} p-4 flex flex-col items-center text-center cursor-pointer hover:border-yellow-500 hover:bg-yellow-500/10 transition-all group/zone relative shadow-[0_0_15px_rgba(234,179,8,0.15)]`}
                >
                  <div className="absolute top-0 right-0 p-1 text-xs text-yellow-500 font-bold opacity-50">Z-2</div>
                  <h3 className={`font-bold mb-1 ${selectedZone === 2 ? 'text-primary' : 'text-white group-hover/zone:text-yellow-400'}`}>MAINFRAME</h3>
                  <div className="text-xs text-muted mb-2">Risky • Med Yield</div>
                  <div className="mt-auto w-full">
                    <div className="text-xs flex justify-between mb-1"><span className="text-muted">Survival:</span> <span className="text-yellow-500">70%</span></div>
                    <div className="text-xs flex justify-between"><span className="text-muted">Time:</span> <span className="text-white">3 Min</span></div>
                  </div>
                </div>

                {/* Zone 3 */}
                <div 
                  onClick={() => setSelectedZone(3)}
                  className={`border ${selectedZone === 3 ? 'border-primary ring-2 ring-primary bg-primary/10' : 'border-red-500/30 bg-red-900/10'} p-4 flex flex-col items-center text-center cursor-pointer hover:border-red-500 hover:bg-red-500/10 transition-all group/zone relative`}
                >
                  <div className="absolute top-0 right-0 p-1 text-xs text-red-500 font-bold opacity-50">Z-3</div>
                  <h3 className={`font-bold mb-1 ${selectedZone === 3 ? 'text-primary' : 'text-white group-hover/zone:text-red-400'}`}>THE CORE</h3>
                  <div className="text-xs text-muted mb-2">Deadly • High Yield</div>
                  <div className="mt-auto w-full">
                    <div className="text-xs flex justify-between mb-1"><span className="text-muted">Survival:</span> <span className="text-red-500">45%</span></div>
                    <div className="text-xs flex justify-between"><span className="text-muted">Time:</span> <span className="text-white">5 Min</span></div>
                  </div>
                </div>
              </div>

              {!isActive ? (
                <button 
                  onClick={handleDeploy}
                  disabled={!isConnected || isPending}
                  className="pixel-btn w-full text-xl py-4 flex items-center justify-center gap-3 disabled:opacity-50 disabled:cursor-not-allowed group/btn hover:scale-105"
                >
                  {isPending ? (
                    <span className="animate-pulse">DEPLOYING...</span>
                  ) : (
                    <>DEPLOY RAT <ChevronRight className="w-6 h-6 group-hover/btn:translate-x-2 transition-transform" /></>
                  )}
                </button>
              ) : isFinished ? (
                <button 
                  onClick={handleClaim}
                  disabled={isPending}
                  className="w-full text-xl py-4 flex items-center justify-center gap-3 bg-green-500/20 text-green-500 border border-green-500/50 hover:bg-green-500 hover:text-white transition-all uppercase tracking-wider font-bold shadow-[0_0_15px_rgba(34,197,94,0.4)] disabled:opacity-50 disabled:cursor-not-allowed group/btn hover:scale-105"
                >
                  {isPending ? (
                    <span className="animate-pulse">CLAIMING...</span>
                  ) : (
                    <>CLAIM LOOT <Pickaxe className="w-6 h-6" /></>
                  )}
                </button>
              ) : (
                <button 
                  disabled
                  className="w-full text-xl py-4 flex items-center justify-center gap-3 bg-blue-500/10 text-blue-500 border border-blue-500/30 transition-all uppercase tracking-wider font-bold opacity-70 cursor-not-allowed"
                >
                  <span className="animate-pulse">RUNNER DEPLOYED - {formatTime(remainingTimeSeconds)}</span>
                </button>
              )}
            </div>
          </div>

          {/* Navigation Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <Link to="/inventory" className="glass-panel p-4 flex flex-col items-center justify-center hover:border-primary hover:bg-primary/5 transition-all cursor-pointer text-center group h-32 relative overflow-hidden">
              <div className="absolute -inset-1 bg-gradient-to-r from-primary/0 via-primary/20 to-primary/0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000"></div>
              <Pickaxe className="w-8 h-8 mb-3 text-white/50 group-hover:text-primary transition-colors group-hover:scale-110 duration-300" />
              <span className="text-xs font-bold tracking-widest text-white/80 group-hover:text-white">INVENTORY</span>
            </Link>
            
            <Link to="/burrow" className="glass-panel p-4 flex flex-col items-center justify-center hover:border-primary hover:bg-primary/5 transition-all cursor-pointer text-center group h-32 relative overflow-hidden">
              <div className="absolute -inset-1 bg-gradient-to-r from-primary/0 via-primary/20 to-primary/0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000"></div>
              <Vault className="w-8 h-8 mb-3 text-white/50 group-hover:text-primary transition-colors group-hover:scale-110 duration-300" />
              <span className="text-xs font-bold tracking-widest text-white/80 group-hover:text-white">BURROW</span>
            </Link>
            
            <Link to="/market" className="glass-panel p-4 flex flex-col items-center justify-center border-red-500/30 hover:border-red-500 hover:bg-red-500/5 transition-all cursor-pointer text-center group h-32 relative overflow-hidden">
              <div className="absolute -inset-1 bg-gradient-to-r from-red-500/0 via-red-500/20 to-red-500/0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000"></div>
              <ShoppingCart className="w-8 h-8 mb-3 text-red-500/50 group-hover:text-red-500 transition-colors group-hover:scale-110 duration-300" />
              <span className="text-xs font-bold tracking-widest text-red-500/80 group-hover:text-red-500">MARKET</span>
            </Link>

            <Link to="/council" className="glass-panel p-4 flex flex-col items-center justify-center hover:border-primary hover:bg-primary/5 transition-all cursor-pointer text-center group h-32 relative overflow-hidden">
              <div className="absolute -inset-1 bg-gradient-to-r from-primary/0 via-primary/20 to-primary/0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000"></div>
              <Users className="w-8 h-8 mb-3 text-white/50 group-hover:text-primary transition-colors group-hover:scale-110 duration-300" />
              <span className="text-xs font-bold tracking-widest text-white/80 group-hover:text-white">COUNCIL</span>
            </Link>
          </div>
          
        </div>
      </div>
    </div>
  );
}
