import { useState } from "react";
import { Vote, CheckCircle2, XCircle, Clock } from "lucide-react";
import copiumSticker from "../assets/stickers/emotion-copium.png";

const MOCK_PROPOSALS = [
  {
    id: 1,
    title: "Increase GPU crafting requirements",
    status: "Active",
    votesFor: 45200,
    votesAgainst: 12500,
    timeRemaining: "12h 45m"
  },
  {
    id: 2,
    title: "Add new RELIC drop to maze level 4",
    status: "Passed",
    votesFor: 89000,
    votesAgainst: 2000,
    timeRemaining: "Ended"
  },
  {
    id: 3,
    title: "Decrease Burrow Vault yield by 2%",
    status: "Defeated",
    votesFor: 15000,
    votesAgainst: 95000,
    timeRemaining: "Ended"
  }
];

export default function Council() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <div className="flex justify-between items-center mb-8 border-b border-muted pb-4">
        <h1 className="text-3xl font-bold text-primary tracking-widest">THE COUNCIL</h1>
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted">YOUR VOTING POWER:</span>
          <span className="text-primary font-mono text-xl">0 vRAT</span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        <div className="col-span-1 md:col-span-2 space-y-4">
          <div className="text-xs text-muted mb-2 tracking-widest">ACTIVE & RECENT PROPOSALS</div>
          
          {MOCK_PROPOSALS.map((prop) => (
            <div key={prop.id} className="term-box p-5 hover:border-primary/50 transition-colors">
              <div className="flex justify-between items-start mb-3">
                <h3 className="font-bold text-lg">{prop.title}</h3>
                <div className={`px-2 py-1 text-xs border ${
                  prop.status === 'Active' ? 'text-primary border-primary' : 
                  prop.status === 'Passed' ? 'text-green-500 border-green-500' : 
                  'text-red-500 border-red-500'
                }`}>
                  {prop.status}
                </div>
              </div>
              
              <div className="grid grid-cols-3 gap-4 text-sm mb-4">
                <div>
                  <div className="text-xs text-muted mb-1 flex items-center gap-1"><CheckCircle2 className="w-3 h-3 text-green-500"/> FOR</div>
                  <div className="font-mono">{prop.votesFor.toLocaleString()}</div>
                </div>
                <div>
                  <div className="text-xs text-muted mb-1 flex items-center gap-1"><XCircle className="w-3 h-3 text-red-500"/> AGAINST</div>
                  <div className="font-mono">{prop.votesAgainst.toLocaleString()}</div>
                </div>
                <div>
                  <div className="text-xs text-muted mb-1 flex items-center gap-1"><Clock className="w-3 h-3 text-primary"/> REMAINING</div>
                  <div className="font-mono">{prop.timeRemaining}</div>
                </div>
              </div>

              {prop.status === "Active" && (
                <div className="flex gap-2 mt-4 pt-4 border-t border-muted/50">
                  <button className="flex-1 pixel-btn bg-green-500 text-black hover:bg-green-600">VOTE FOR</button>
                  <button className="flex-1 pixel-btn bg-red-500 text-black hover:bg-red-600">VOTE AGAINST</button>
                </div>
              )}
            </div>
          ))}
        </div>

        <div className="term-box flex flex-col items-center p-6 text-center h-fit">
          <img src={copiumSticker} alt="Governance" className="w-32 h-32 object-contain mb-4" />
          <h3 className="font-bold mb-2 text-primary">SHAPE THE ECONOMY</h3>
          <p className="text-xs text-muted mb-6">
            Hold vRAT to participate in the DAO. The council decides on drop rates, new items, and yield parameters.
          </p>
          <button className="pixel-btn w-full text-sm">CREATE PROPOSAL</button>
        </div>
      </div>
    </div>
  );
}
