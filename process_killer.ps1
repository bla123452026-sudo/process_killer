import React, { useState, useEffect } from 'react';
import { 
  Shield, 
  Layout, 
  Cpu, 
  Plus, 
  Trash2, 
  Clock, 
  Settings2, 
  AlertCircle,
  X
} from 'lucide-react';

const App = () => {
  const [activeTab, setActiveTab] = useState('apps');
  const [showAddModal, setShowAddModal] = useState(false);
  const [monitorData, setMonitorData] = useState([
    { name: 'chrome.exe', limit: 90, current: 3665, unit: 'min', type: 'app' },
    { name: 'roblox.exe', limit: 30, current: 1740, unit: 'min', type: 'app' },
    { name: 'svchost.exe', limit: 4, current: 7205, unit: 'uur', type: 'proces' }
  ]);

  const [newName, setNewName] = useState('');
  const [newTime, setNewTime] = useState('');
  const [newUnit, setNewUnit] = useState('min');

  // Helper functie om seconden om te zetten naar u m s (voor zowel verbruik als limieten)
  const formatTime = (totalSeconds) => {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = Math.floor(totalSeconds % 60);

    let result = '';
    if (hours > 0) result += `${hours}u `;
    if (minutes > 0 || hours > 0) result += `${minutes}m `;
    if (seconds > 0 || (!hours && !minutes)) result += `${seconds}s`;
    return result.trim();
  };

  // Functie specifiek voor de limiettekst (zonder de seconden als die er niet zijn)
  const formatLimit = (value, unit) => {
    const seconds = unit === 'uur' ? value * 3600 : value * 60;
    return formatTime(seconds);
  };

  useEffect(() => {
    const interval = setInterval(() => {
      setMonitorData(prev => prev.map(item => {
        const limitInSeconds = item.unit === 'uur' ? item.limit * 3600 : item.limit * 60;
        if (item.current < limitInSeconds) {
          return { ...item, current: item.current + 1 };
        }
        return item;
      }));
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  const addItem = () => {
    if (newName && newTime) {
      setMonitorData([...monitorData, {
        name: newName.toLowerCase().includes('.') ? newName.toLowerCase() : `${newName.toLowerCase()}.exe`,
        limit: parseInt(newTime),
        current: 0,
        unit: newUnit,
        type: activeTab === 'apps' ? 'app' : 'proces'
      }]);
      setNewName('');
      setNewTime('');
      setShowAddModal(false);
    }
  };

  const removeItem = (name) => {
    setMonitorData(monitorData.filter(i => i.name !== name));
  };

  const filteredData = monitorData.filter(item => 
    activeTab === 'apps' ? item.type === 'app' : item.type === 'proces'
  );

  return (
    <div className="min-h-screen bg-slate-100 p-4 md:p-8 font-sans text-slate-900">
      <div className="max-w-2xl mx-auto bg-white rounded-3xl shadow-2xl overflow-hidden border border-slate-200">
        
        {/* Header */}
        <div className="bg-slate-900 p-6 text-white flex justify-between items-center">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-indigo-500 rounded-lg">
              <Shield size={24} className="text-white" />
            </div>
            <div>
              <h1 className="text-xl font-bold tracking-tight">Process Killer Pro</h1>
              <p className="text-xs text-slate-400 font-medium uppercase tracking-widest">v2.5 Live Tracker</p>
            </div>
          </div>
          <button 
            onClick={() => setShowAddModal(true)}
            className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 transition-colors px-4 py-2 rounded-xl text-sm font-bold"
          >
            <Plus size={18} /> Nieuwe Limiet
          </button>
        </div>

        {/* Tab Selector */}
        <div className="flex p-2 bg-slate-50 border-b border-slate-200">
          <button 
            onClick={() => setActiveTab('apps')}
            className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl transition-all ${activeTab === 'apps' ? 'bg-white shadow-sm text-indigo-600 font-bold' : 'text-slate-500 hover:text-slate-700'}`}
          >
            <Layout size={18} /> Applicaties
          </button>
          <button 
            onClick={() => setActiveTab('processen')}
            className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl transition-all ${activeTab === 'processen' ? 'bg-white shadow-sm text-orange-600 font-bold' : 'text-slate-500 hover:text-slate-700'}`}
          >
            <Cpu size={18} /> Achtergrond
          </button>
        </div>

        {/* List Content */}
        <div className="p-6 min-h-[400px]">
          {filteredData.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 text-slate-400">
              <Settings2 size={48} strokeWidth={1} className="mb-4 opacity-20" />
              <p>Geen actieve limieten in deze categorie</p>
            </div>
          ) : (
            <div className="space-y-8">
              {filteredData.map((item) => {
                const limitInSeconds = item.unit === 'uur' ? item.limit * 3600 : item.limit * 60;
                const percentage = (item.current / limitInSeconds) * 100;
                const isWarning = percentage > 85;
                const isCritical = percentage >= 100;

                return (
                  <div key={item.name} className="relative">
                    <div className="flex justify-between items-start mb-2">
                      <div>
                        <h3 className="font-bold text-slate-800 text-lg flex items-center gap-2">
                          {item.name}
                          {isCritical && <AlertCircle size={16} className="text-red-500 animate-pulse" />}
                        </h3>
                        <div className="flex items-center gap-3 text-slate-500 text-xs mt-1">
                          <span className="flex items-center gap-1 font-medium bg-slate-100 px-2 py-0.5 rounded-full">
                            <Clock size={12} /> Limiet: {formatLimit(item.limit, item.unit)}
                          </span>
                        </div>
                      </div>
                      <div className="flex flex-col items-end">
                        <div className={`text-sm font-mono font-bold px-3 py-1 rounded-lg ${isCritical ? 'bg-red-100 text-red-600' : isWarning ? 'bg-orange-100 text-orange-600' : 'bg-indigo-50 text-indigo-600'}`}>
                          {formatTime(item.current)}
                        </div>
                        <button 
                          onClick={() => removeItem(item.name)}
                          className="text-slate-300 hover:text-red-500 transition-colors mt-2 p-1"
                          title="Verwijder limiet"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </div>

                    {/* Progress Bar Container */}
                    <div className="relative pt-1">
                      <div className="overflow-hidden h-3 text-xs flex rounded-full bg-slate-100 border border-slate-200">
                        <div 
                          style={{ width: `${Math.min(percentage, 100)}%` }}
                          className={`shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center transition-all duration-1000 ${isCritical ? 'bg-red-500' : isWarning ? 'bg-orange-500' : 'bg-indigo-500'}`}
                        ></div>
                      </div>
                      <div className="flex justify-between text-[10px] mt-1 font-bold uppercase tracking-wider text-slate-400">
                        <span>0s</span>
                        <span>{formatLimit(item.limit, item.unit)} bereikt</span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        <div className="bg-slate-50 p-4 border-t border-slate-200 flex justify-center items-center gap-6 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
            {monitorData.length} PROCESSEN IN GEHEUGEN
        </div>
      </div>

      {showAddModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white w-full max-w-sm rounded-3xl shadow-2xl overflow-hidden border border-slate-200">
            <div className="p-6 border-b border-slate-100 flex justify-between items-center bg-slate-50">
              <h2 className="font-bold text-slate-800">Limiet Instellen</h2>
              <button onClick={() => setShowAddModal(false)} className="text-slate-400 hover:text-slate-600 p-1">
                <X size={20} />
              </button>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2 block">Proces Naam</label>
                <input 
                  type="text" 
                  placeholder="bijv. chrome.exe"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 p-4 rounded-2xl outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-medium"
                />
              </div>
              <div className="flex gap-4">
                <div className="flex-1">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2 block">Tijd</label>
                  <input 
                    type="number" 
                    placeholder="0"
                    value={newTime}
                    onChange={(e) => setNewTime(e.target.value)}
                    className="w-full bg-slate-50 border border-slate-200 p-4 rounded-2xl outline-none focus:ring-2 focus:ring-indigo-500 font-mono font-bold text-lg"
                  />
                </div>
                <div className="w-28">
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2 block">Eenheid</label>
                  <select 
                    value={newUnit}
                    onChange={(e) => setNewUnit(e.target.value)}
                    className="w-full bg-slate-50 border border-slate-200 p-4 rounded-2xl outline-none focus:ring-2 focus:ring-indigo-500 appearance-none font-bold"
                  >
                    <option value="min">min</option>
                    <option value="uur">uur</option>
                  </select>
                </div>
              </div>
              <button 
                onClick={addItem}
                className={`w-full py-5 rounded-2xl font-bold text-white transition-all shadow-xl ${activeTab === 'apps' ? 'bg-indigo-600 hover:bg-indigo-700' : 'bg-orange-600 hover:bg-orange-700'}`}
              >
                Monitor Starten
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;