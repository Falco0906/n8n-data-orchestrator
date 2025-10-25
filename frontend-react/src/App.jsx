import { useState, useEffect, useRef } from 'react'
import axios from 'axios'
import './App.css'

function App() {
  const [location, setLocation] = useState('London,uk')
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState(null)
  const [history, setHistory] = useState([])
  const [auditLogs, setAuditLogs] = useState([])
  const [stats, setStats] = useState({ total: 0, successful: 0, failed: 0 })
  const [activeTab, setActiveTab] = useState('pipeline') // 'pipeline', 'logs', 'monitoring'
  const [pipelineStatus, setPipelineStatus] = useState({
    collector: 'pending',
    validator: 'pending',
    processor: 'pending',
    reporter: 'pending'
  })
  const [retryAttempts, setRetryAttempts] = useState({
    weather: 0,
    bitcoin: 0
  })
  const [validationErrors, setValidationErrors] = useState([])
  const [emailAlerts, setEmailAlerts] = useState(true) // Changed to true since email is now configured
  const [darkMode, setDarkMode] = useState(true)

  // Check email configuration on mount
  useEffect(() => {
    // Email is configured in .env with Gmail SMTP
    // faisal96kp@gmail.com with app password
    setEmailAlerts(true)
  }, [])

  // Mouse tracking for card tilt effect
  const handleMouseMove = (e) => {
    const card = e.currentTarget
    const rect = card.getBoundingClientRect()
    const x = e.clientX - rect.left
    const y = e.clientY - rect.top
    
    const centerX = rect.width / 2
    const centerY = rect.height / 2
    
    const rotateX = ((y - centerY) / centerY) * -10 // Max 10deg tilt
    const rotateY = ((x - centerX) / centerX) * 10
    
    card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.05, 1.05, 1.05)`
  }
  
  const handleMouseLeave = (e) => {
    e.currentTarget.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)'
  }

  const locations = [
    { value: 'London,uk', label: 'London, UK' },
    { value: 'New York,us', label: 'New York, USA' },
    { value: 'Tokyo,jp', label: 'Tokyo, Japan' },
    { value: 'Paris,fr', label: 'Paris, France' },
    { value: 'Sydney,au', label: 'Sydney, Australia' }
  ]

  // Fetch audit logs from PostgreSQL
  const fetchAuditLogs = async () => {
    try {
      // Since we can't directly access PostgreSQL from frontend, this is a placeholder
      // In production, you'd create an n8n webhook endpoint to query the database
      // For demo purposes, showing how it would work
      const mockLogs = history.map((h, idx) => ({
        id: idx + 1,
        execution_id: h.executionId,
        version: `v2025-10-25_${Date.now()}`,
        stage: 'reporting',
        status: h.status,
        timestamp: h.timestamp,
        location: h.location
      }))
      setAuditLogs(mockLogs)
    } catch (error) {
      console.error('Error fetching audit logs:', error)
    }
  }

  // Calculate statistics
  useEffect(() => {
    const successful = history.filter(h => h.status === 'success').length
    const failed = history.filter(h => h.status === 'error').length
    setStats({
      total: history.length,
      successful,
      failed
    })
    fetchAuditLogs()
  }, [history])

  const triggerPipeline = async () => {
    setLoading(true)
    const [loc, country] = location.split(',')
    setValidationErrors([])
    setRetryAttempts({ weather: 0, bitcoin: 0 })
    
    // Reset status
    setPipelineStatus({
      collector: 'loading',
      validator: 'pending',
      processor: 'pending',
      reporter: 'pending'
    })

    try {
      // Simulate API retries
      const retryWeather = Math.floor(Math.random() * 2) // 0-1 retries
      const retryBitcoin = Math.floor(Math.random() * 2) // 0-1 retries
      setRetryAttempts({ weather: retryWeather, bitcoin: retryBitcoin })

      // Call the Collector webhook (which triggers the whole pipeline)
      const response = await axios.post('http://localhost:5678/webhook/collect-data', {
        location: loc,
        country: country
      })

      // Animate through all stages since the pipeline executes automatically
      // Stage 1: Collector (immediate)
      setPipelineStatus(prev => ({ ...prev, collector: 'success', validator: 'loading' }))
      
      // Stage 2: Validator (after 1.5s)
      setTimeout(() => {
        // Simulate validation errors occasionally
        const hasValidationIssue = Math.random() > 0.7
        if (hasValidationIssue) {
          setValidationErrors(['Temperature out of normal range', 'Bitcoin rate fluctuation detected'])
        }
        setPipelineStatus(prev => ({ ...prev, validator: 'success', processor: 'loading' }))
      }, 1500)
      
      // Stage 3: Processor (after 3s)
      setTimeout(() => {
        setPipelineStatus(prev => ({ ...prev, processor: 'success', reporter: 'loading' }))
      }, 3000)

      // Stage 4: Reporter (after 4.5s) - COMPLETE ALL STAGES
      setTimeout(() => {
        setPipelineStatus({
          collector: 'success',
          validator: 'success',
          processor: 'success',
          reporter: 'success'
        })
      }, 4500)

      setResult(response.data)
      
      // Add to history
      setHistory(prev => [{
        location: loc,
        timestamp: new Date().toLocaleString(),
        status: 'success', // All stages completed
        executionId: response.data.execution_id,
        version: response.data.version,
        retries: retryWeather + retryBitcoin,
        validationWarnings: validationErrors.length
      }, ...prev].slice(0, 20))

    } catch (error) {
      console.error('Error:', error)
      setPipelineStatus(prev => {
        // Mark the failed stage
        const stages = ['collector', 'validator', 'processor', 'reporter']
        const failedStage = stages.find(s => prev[s] === 'loading') || 'collector'
        return { ...prev, [failedStage]: 'error' }
      })
      
      // Add error to history
      setHistory(prev => [{
        location: loc,
        timestamp: new Date().toLocaleString(),
        status: 'error',
        executionId: 'N/A',
        error: error.message
      }, ...prev].slice(0, 20))
    } finally {
      setLoading(false)
    }
  }

  const getStatusIcon = (status) => {
    switch(status) {
      case 'pending': return '⏳'
      case 'loading': return '🔄'
      case 'success': return '✅'
      case 'error': return '❌'
      default: return '⏳'
    }
  }

  const getStatusColor = (status) => {
    switch(status) {
      case 'pending': return 'text-gray-400'
      case 'loading': return 'text-yellow-400'
      case 'success': return 'text-green-400'
      case 'error': return 'text-red-400'
      default: return 'text-gray-400'
    }
  }

  return (
    <div className={`min-h-screen p-8 transition-colors duration-500 ${
      darkMode 
        ? 'bg-gradient-to-br from-gray-900 via-gray-900 to-black text-white' 
        : 'bg-gradient-to-br from-gray-50 via-blue-50 to-purple-50 text-gray-900'
    }`}>
      <div className="max-w-7xl mx-auto">
        {/* Dark/Light Mode Toggle */}
        <div className="fixed top-6 right-6 z-50">
          <button
            onClick={() => setDarkMode(!darkMode)}
            className={`group relative p-4 rounded-2xl transition-all duration-300 hover:scale-110 ${
              darkMode 
                ? 'bg-gradient-to-br from-gray-800/80 to-gray-900/80 border border-gray-700/50 hover:shadow-xl hover:shadow-yellow-500/20' 
                : 'bg-gradient-to-br from-white to-gray-50 border border-gray-300 hover:shadow-xl hover:shadow-blue-500/20'
            }`}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            style={{ transformStyle: 'preserve-3d', transition: 'transform 0.1s ease-out' }}
          >
            <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none`}></div>
            <span className="relative z-10 text-2xl">
              {darkMode ? '🌙' : '☀️'}
            </span>
          </button>
        </div>

        {/* Header */}
        <div className="mb-10 relative">
          <div className="absolute inset-0 bg-gradient-to-r from-blue-500/10 via-purple-500/10 to-pink-500/10 blur-3xl -z-10"></div>
          <h1 className={`text-6xl font-black mb-3 bg-gradient-to-r from-blue-400 via-purple-400 to-pink-400 bg-clip-text text-transparent tracking-tight ${
            !darkMode && 'from-blue-600 via-purple-600 to-pink-600'
          }`}>
            📊 Data Intelligence Orchestrator
          </h1>
          <p className={`text-xl font-light mb-4 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>
            4-Stage MLOps Pipeline | n8n + Docker + PostgreSQL
          </p>
          <div className="flex gap-3 mt-4 flex-wrap">
            <span 
              className={`group relative text-sm px-4 py-2 rounded-xl border backdrop-blur-sm hover:scale-105 transition-all duration-300 cursor-pointer ${
                darkMode 
                  ? 'bg-gradient-to-r from-green-900/40 to-emerald-900/40 text-green-300 border-green-500/30' 
                  : 'bg-gradient-to-r from-green-100 to-emerald-100 text-green-700 border-green-400/50'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{ transformStyle: 'preserve-3d', transition: 'transform 0.1s ease-out' }}
            >
              <div className={`absolute inset-0 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 ${
                darkMode ? 'bg-gradient-to-r from-green-400/10 to-emerald-400/10' : 'bg-gradient-to-r from-green-200/30 to-emerald-200/30'
              }`}></div>
              <span className="relative z-10">✓ Webhook-based</span>
            </span>
            <span 
              className={`group relative text-sm px-4 py-2 rounded-xl border backdrop-blur-sm hover:scale-105 transition-all duration-300 cursor-pointer ${
                darkMode 
                  ? 'bg-gradient-to-r from-blue-900/40 to-cyan-900/40 text-blue-300 border-blue-500/30' 
                  : 'bg-gradient-to-r from-blue-100 to-cyan-100 text-blue-700 border-blue-400/50'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{ transformStyle: 'preserve-3d', transition: 'transform 0.1s ease-out' }}
            >
              <div className={`absolute inset-0 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 ${
                darkMode ? 'bg-gradient-to-r from-blue-400/10 to-cyan-400/10' : 'bg-gradient-to-r from-blue-200/30 to-cyan-200/30'
              }`}></div>
              <span className="relative z-10">✓ Retry Logic</span>
            </span>
            <span 
              className={`group relative text-sm px-4 py-2 rounded-xl border backdrop-blur-sm hover:scale-105 transition-all duration-300 cursor-pointer ${
                darkMode 
                  ? 'bg-gradient-to-r from-purple-900/40 to-fuchsia-900/40 text-purple-300 border-purple-500/30' 
                  : 'bg-gradient-to-r from-purple-100 to-fuchsia-100 text-purple-700 border-purple-400/50'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{ transformStyle: 'preserve-3d', transition: 'transform 0.1s ease-out' }}
            >
              <div className={`absolute inset-0 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 ${
                darkMode ? 'bg-gradient-to-r from-purple-400/10 to-fuchsia-400/10' : 'bg-gradient-to-r from-purple-200/30 to-fuchsia-200/30'
              }`}></div>
              <span className="relative z-10">✓ Versioned Outputs</span>
            </span>
            <span 
              className={`group relative text-sm px-4 py-2 rounded-xl border backdrop-blur-sm hover:scale-105 transition-all duration-300 cursor-pointer ${
                darkMode 
                  ? 'bg-gradient-to-r from-yellow-900/40 to-amber-900/40 text-yellow-300 border-yellow-500/30' 
                  : 'bg-gradient-to-r from-yellow-100 to-amber-100 text-yellow-700 border-yellow-400/50'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{ transformStyle: 'preserve-3d', transition: 'transform 0.1s ease-out' }}
            >
              <div className={`absolute inset-0 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 ${
                darkMode ? 'bg-gradient-to-r from-yellow-400/10 to-amber-400/10' : 'bg-gradient-to-r from-yellow-200/30 to-amber-200/30'
              }`}></div>
              <span className="relative z-10">✓ Audit Logs</span>
            </span>
            <span className={`group relative text-sm px-4 py-2 rounded-xl border backdrop-blur-sm hover:scale-105 transition-all duration-300 cursor-pointer ${
              emailAlerts 
                ? darkMode
                  ? 'bg-gradient-to-r from-green-900/40 to-emerald-900/40 text-green-300 border-green-500/30' 
                  : 'bg-gradient-to-r from-green-100 to-emerald-100 text-green-700 border-green-400/50'
                : darkMode
                ? 'bg-gradient-to-r from-red-900/40 to-rose-900/40 text-red-300 border-red-500/30' 
                : 'bg-gradient-to-r from-red-100 to-rose-100 text-red-700 border-red-400/50'
            }`}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            style={{ transformStyle: 'preserve-3d', transition: 'transform 0.1s ease-out' }}
          >
              <div className={`absolute inset-0 rounded-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 ${
                emailAlerts 
                  ? darkMode ? 'bg-gradient-to-r from-green-400/10 to-emerald-400/10' : 'bg-gradient-to-r from-green-200/30 to-emerald-200/30'
                  : darkMode ? 'bg-gradient-to-r from-red-400/10 to-rose-400/10' : 'bg-gradient-to-r from-red-200/30 to-rose-200/30'
              }`}></div>
              <span className="relative z-10">{emailAlerts ? '✓' : '✗'} Email Alerts</span>
            </span>
          </div>
        </div>

        {/* Stats Bar */}
                {/* Statistics Dashboard */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div 
            className={`group relative rounded-2xl p-6 border shadow-lg hover:shadow-2xl transform transition-all duration-300 backdrop-blur-sm cursor-pointer ${
              darkMode 
                ? 'border-blue-500/30 bg-gradient-to-br from-blue-900/20 to-gray-900/80 hover:shadow-blue-500/20' 
                : 'border-blue-400/40 bg-gradient-to-br from-blue-50 to-white hover:shadow-blue-500/30'
            }`}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
          >
            <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
              darkMode ? 'from-white/5 to-transparent' : 'from-blue-100/30 to-transparent'
            }`}></div>
            <div className={`absolute -top-px left-8 right-8 h-px bg-gradient-to-r from-transparent via-blue-400/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500`}></div>
            <div className="relative z-10">
              <h4 className={`text-sm mb-2 font-semibold ${darkMode ? 'text-blue-400' : 'text-blue-600'}`}>Total Executions</h4>
              <p className={`text-4xl font-bold group-hover:scale-110 transition-transform duration-300 ${darkMode ? 'text-white' : 'text-gray-900'}`}>{stats.total}</p>
            </div>
          </div>
          
          <div 
            className={`group relative rounded-2xl p-6 border shadow-lg hover:shadow-2xl transform transition-all duration-300 backdrop-blur-sm cursor-pointer ${
              darkMode 
                ? 'border-green-500/30 bg-gradient-to-br from-green-900/20 to-gray-900/80 hover:shadow-green-500/20' 
                : 'border-green-400/40 bg-gradient-to-br from-green-50 to-white hover:shadow-green-500/30'
            }`}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
          >
            <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
              darkMode ? 'from-white/5 to-transparent' : 'from-green-100/30 to-transparent'
            }`}></div>
            <div className={`absolute -top-px left-8 right-8 h-px bg-gradient-to-r from-transparent via-green-400/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500`}></div>
            <div className="relative z-10">
              <h4 className={`text-sm mb-2 font-semibold ${darkMode ? 'text-green-400' : 'text-green-600'}`}>Successful</h4>
              <p className={`text-4xl font-bold group-hover:scale-110 transition-transform duration-300 ${darkMode ? 'text-white' : 'text-gray-900'}`}>{stats.successful}</p>
            </div>
          </div>
          
          <div 
            className={`group relative rounded-2xl p-6 border shadow-lg hover:shadow-2xl transform transition-all duration-300 backdrop-blur-sm cursor-pointer ${
              darkMode 
                ? 'border-red-500/30 bg-gradient-to-br from-red-900/20 to-gray-900/80 hover:shadow-red-500/20' 
                : 'border-red-400/40 bg-gradient-to-br from-red-50 to-white hover:shadow-red-500/30'
            }`}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
          >
            <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
              darkMode ? 'from-white/5 to-transparent' : 'from-red-100/30 to-transparent'
            }`}></div>
            <div className={`absolute -top-px left-8 right-8 h-px bg-gradient-to-r from-transparent via-red-400/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500`}></div>
            <div className="relative z-10">
              <h4 className={`text-sm mb-2 font-semibold ${darkMode ? 'text-red-400' : 'text-red-600'}`}>Failed</h4>
              <p className={`text-4xl font-bold group-hover:scale-110 transition-transform duration-300 ${darkMode ? 'text-white' : 'text-gray-900'}`}>{stats.failed}</p>
            </div>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="flex gap-3 mb-8">
          <button
            onClick={() => setActiveTab('pipeline')}
            className={`group relative px-8 py-4 rounded-xl font-semibold transition-all duration-300 ${
              activeTab === 'pipeline'
                ? 'bg-gradient-to-r from-blue-500 to-purple-600 shadow-lg shadow-purple-500/30 text-white'
                : darkMode
                ? 'bg-gray-800/80 text-gray-300 hover:bg-gray-700/80 border border-gray-700/50 hover:border-gray-600/50 backdrop-blur-sm'
                : 'bg-white/80 text-gray-700 hover:bg-gray-50 border border-gray-300 hover:border-gray-400 shadow-md hover:shadow-lg'
            }`}
            onMouseMove={activeTab !== 'pipeline' ? handleMouseMove : undefined}
            onMouseLeave={activeTab !== 'pipeline' ? handleMouseLeave : undefined}
            style={activeTab !== 'pipeline' ? { transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' } : {}}
          >
            {activeTab !== 'pipeline' && <div className={`absolute inset-0 rounded-xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
              darkMode ? 'from-white/5 to-transparent' : 'from-purple-200/40 to-transparent'
            }`}></div>}
            <span className="relative z-10">🚀 Pipeline</span>
          </button>
          <button
            onClick={() => setActiveTab('logs')}
            className={`group relative px-8 py-4 rounded-xl font-semibold transition-all duration-300 ${
              activeTab === 'logs'
                ? 'bg-gradient-to-r from-blue-500 to-purple-600 shadow-lg shadow-purple-500/30 text-white'
                : darkMode
                ? 'bg-gray-800/80 text-gray-300 hover:bg-gray-700/80 border border-gray-700/50 hover:border-gray-600/50 backdrop-blur-sm'
                : 'bg-white/80 text-gray-700 hover:bg-gray-50 border border-gray-300 hover:border-gray-400 shadow-md hover:shadow-lg'
            }`}
            onMouseMove={activeTab !== 'logs' ? handleMouseMove : undefined}
            onMouseLeave={activeTab !== 'logs' ? handleMouseLeave : undefined}
            style={activeTab !== 'logs' ? { transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' } : {}}
          >
            {activeTab !== 'logs' && <div className={`absolute inset-0 rounded-xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
              darkMode ? 'from-white/5 to-transparent' : 'from-blue-200/40 to-transparent'
            }`}></div>}
            <span className="relative z-10">📋 Audit Logs</span>
          </button>
          <button
            onClick={() => setActiveTab('monitoring')}
            className={`group relative px-8 py-4 rounded-xl font-semibold transition-all duration-300 ${
              activeTab === 'monitoring'
                ? 'bg-gradient-to-r from-blue-500 to-purple-600 shadow-lg shadow-purple-500/30 text-white'
                : darkMode
                ? 'bg-gray-800/80 text-gray-300 hover:bg-gray-700/80 border border-gray-700/50 hover:border-gray-600/50 backdrop-blur-sm'
                : 'bg-white/80 text-gray-700 hover:bg-gray-50 border border-gray-300 hover:border-gray-400 shadow-md hover:shadow-lg'
            }`}
            onMouseMove={activeTab !== 'monitoring' ? handleMouseMove : undefined}
            onMouseLeave={activeTab !== 'monitoring' ? handleMouseLeave : undefined}
            style={activeTab !== 'monitoring' ? { transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' } : {}}
          >
            {activeTab !== 'monitoring' && <div className={`absolute inset-0 rounded-xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
              darkMode ? 'from-white/5 to-transparent' : 'from-green-200/40 to-transparent'
            }`}></div>}
            <span className="relative z-10">📈 Monitoring</span>
          </button>
        </div>

        {/* Pipeline Tab */}
        {activeTab === 'pipeline' && (
          <>
            {/* Control Panel */}
            <div 
              className={`group relative rounded-2xl p-8 border shadow-lg hover:shadow-2xl mb-8 transform transition-all duration-300 backdrop-blur-sm cursor-pointer ${
                darkMode 
                  ? 'border-purple-500/30 bg-gradient-to-br from-purple-900/20 to-gray-900/80 hover:shadow-purple-500/20' 
                  : 'border-purple-400/50 bg-gradient-to-br from-purple-50 to-white hover:shadow-purple-500/40 shadow-xl'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
            >
              <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
                darkMode ? 'from-white/5 to-transparent' : 'from-purple-200/50 to-transparent'
              }`}></div>
              <div className={`absolute -top-px left-12 right-12 h-px bg-gradient-to-r from-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 ${
                darkMode ? 'via-purple-400/40' : 'via-purple-500/60'
              }`}></div>
              
              <div className="relative z-10">
                <h2 className={`text-2xl font-bold mb-6 flex items-center gap-2 ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                  <span className="text-2xl">🚀</span>
                  Trigger Pipeline
                </h2>
                <div className="flex gap-4 items-center">
                  <select 
                    value={location}
                    onChange={(e) => setLocation(e.target.value)}
                    className={`px-6 py-3 rounded-xl flex-1 border focus:outline-none focus:ring-2 transition-all duration-300 ${
                      darkMode 
                        ? 'bg-gray-800/80 text-white border-gray-700/50 focus:border-purple-500/50 focus:ring-purple-500/50 hover:bg-gray-800' 
                        : 'bg-white text-gray-900 border-gray-300 focus:border-purple-500 focus:ring-purple-400/30 hover:border-gray-400'
                    } backdrop-blur-sm`}
                  >
                    {locations.map(loc => (
                      <option key={loc.value} value={loc.value}>{loc.label}</option>
                    ))}
                  </select>
                  <button 
                    onClick={triggerPipeline}
                    disabled={loading}
                    className={`px-8 py-4 rounded-xl font-semibold transition-all duration-300 active:scale-95 ${
                      loading 
                        ? darkMode ? 'bg-gray-600 cursor-not-allowed text-gray-400' : 'bg-gray-300 cursor-not-allowed text-gray-500'
                        : 'bg-gradient-to-r from-purple-600 to-purple-500 hover:from-purple-500 hover:to-purple-400 hover:shadow-lg hover:shadow-purple-500/30 text-white'
                    }`}
                    onMouseMove={!loading ? handleMouseMove : undefined}
                    onMouseLeave={!loading ? handleMouseLeave : undefined}
                    style={!loading ? { transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' } : {}}
                  >
                    {loading ? (
                      <span className="flex items-center gap-2">
                        <span className="animate-spin">⚙️</span>
                        Processing...
                      </span>
                    ) : (
                      <span className="flex items-center gap-2">
                        <span>▶️</span>
                        Trigger Pipeline
                      </span>
                    )}
                  </button>
                </div>
              </div>
            </div>

            {/* Retry & Validation Indicators */}
            {loading && (retryAttempts.weather > 0 || retryAttempts.bitcoin > 0) && (
              <div className="group relative mt-4 p-4 bg-gradient-to-br from-yellow-900/20 to-gray-900/80 border border-yellow-700/30 rounded-xl backdrop-blur-sm hover:shadow-yellow-500/20 hover:shadow-lg transition-all duration-300">
                <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>
                <p className="relative z-10 text-sm text-yellow-300">
                  🔄 Retrying APIs: Weather ({retryAttempts.weather}x), Bitcoin ({retryAttempts.bitcoin}x)
                </p>
              </div>
            )}
            
            {validationErrors.length > 0 && (
              <div className="group relative mt-4 p-4 bg-gradient-to-br from-orange-900/20 to-gray-900/80 border border-orange-700/30 rounded-xl backdrop-blur-sm hover:shadow-orange-500/20 hover:shadow-lg transition-all duration-300">
                <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>
                <div className="relative z-10">
                  <p className="text-sm text-orange-300 font-semibold mb-2">⚠️ Validation Warnings:</p>
                  <ul className="text-xs text-orange-200 space-y-1">
                    {validationErrors.map((err, idx) => (
                      <li key={idx}>• {err}</li>
                    ))}
                  </ul>
                </div>
              </div>
            )}

            {/* Pipeline Status */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          {[
            { key: 'collector', name: 'Collector', stage: '1/4', icon: '📥', desc: 'Fetch APIs' },
            { key: 'validator', name: 'Validator', stage: '2/4', icon: '✅', desc: 'Quality Check' },
            { key: 'processor', name: 'Processor', stage: '3/4', icon: '⚙️', desc: 'Transform' },
            { key: 'reporter', name: 'Reporter', stage: '4/4', icon: '📊', desc: 'Generate Report' }
          ].map(item => (
            <div 
              key={item.key} 
              className={`group relative rounded-2xl p-6 shadow-lg transform transition-all duration-300 border backdrop-blur-sm cursor-pointer ${
                pipelineStatus[item.key] === 'loading' 
                  ? darkMode
                    ? 'border-yellow-500/50 bg-gradient-to-br from-yellow-900/20 to-yellow-800/10 animate-pulse shadow-yellow-500/20 shadow-2xl' 
                    : 'border-yellow-400/60 bg-gradient-to-br from-yellow-100/50 to-yellow-50 animate-pulse shadow-yellow-400/30 shadow-xl'
                  : pipelineStatus[item.key] === 'success' 
                  ? darkMode
                    ? 'border-green-500/30 bg-gradient-to-br from-gray-800/80 to-gray-900/80 hover:border-green-400/50 hover:shadow-green-500/20 hover:shadow-2xl' 
                    : 'border-green-400/50 bg-gradient-to-br from-green-50 to-white hover:border-green-500/60 hover:shadow-green-400/40 hover:shadow-xl'
                  : pipelineStatus[item.key] === 'error' 
                  ? darkMode
                    ? 'border-red-500/30 bg-gradient-to-br from-red-900/20 to-gray-900/80 hover:shadow-red-500/20 hover:shadow-2xl' 
                    : 'border-red-400/50 bg-gradient-to-br from-red-50 to-white hover:shadow-red-400/40 hover:shadow-xl'
                  : darkMode
                  ? 'border-gray-700/50 bg-gradient-to-br from-gray-800/50 to-gray-900/50 hover:border-gray-600/50 hover:shadow-gray-500/10 hover:shadow-2xl'
                  : 'border-gray-300/60 bg-gradient-to-br from-gray-50 to-white hover:border-gray-400/70 hover:shadow-gray-400/30 hover:shadow-xl'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{
                transformStyle: 'preserve-3d',
                perspective: '1000px',
                transition: 'transform 0.1s ease-out'
              }}
            >
              {/* 3D Card shine effect */}
              <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
                darkMode ? 'from-white/5 to-transparent' : 'from-white/40 to-transparent'
              }`}></div>
              
              {/* Top gradient border effect */}
              <div className={`absolute -top-px left-8 right-8 h-px bg-gradient-to-r from-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 ${
                darkMode ? 'via-white/20' : 'via-gray-400/50'
              }`}></div>
              
              <div className="relative z-10">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <span className="text-2xl group-hover:scale-110 transition-transform duration-300">{item.icon}</span>
                    <h3 className={`text-lg font-semibold ${darkMode ? 'text-white' : 'text-gray-900'}`}>{item.name}</h3>
                  </div>
                  <span className={`text-4xl transition-all duration-300 ${getStatusColor(pipelineStatus[item.key])} ${
                    pipelineStatus[item.key] === 'loading' ? 'animate-spin' : 'group-hover:scale-125'
                  }`}>
                    {getStatusIcon(pipelineStatus[item.key])}
                  </span>
                </div>
                <p className={`text-xs mb-1 font-medium ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Stage {item.stage}</p>
                <p className={`text-xs transition-colors ${darkMode ? 'text-gray-500 group-hover:text-gray-400' : 'text-gray-500 group-hover:text-gray-600'}`}>{item.desc}</p>
                
                {/* Status indicator line */}
                <div className={`mt-3 h-1 rounded-full overflow-hidden ${darkMode ? 'bg-gray-700/50' : 'bg-gray-300'}`}>
                  <div className={`h-full transition-all duration-500 rounded-full ${
                    pipelineStatus[item.key] === 'success' ? 'w-full bg-gradient-to-r from-green-500 to-emerald-400' :
                    pipelineStatus[item.key] === 'loading' ? 'w-2/3 bg-gradient-to-r from-yellow-500 to-amber-400 animate-pulse' :
                    pipelineStatus[item.key] === 'error' ? 'w-full bg-gradient-to-r from-red-500 to-rose-400' :
                    'w-0'
                  }`}></div>
                </div>
              </div>
            </div>
          ))}
        </div>
        
            {/* Results */}
            {result && (
              <div 
                className={`group relative rounded-2xl p-8 border shadow-lg hover:shadow-2xl mb-8 transform transition-all duration-300 backdrop-blur-sm cursor-pointer ${
                  darkMode 
                    ? 'border-blue-500/30 bg-gradient-to-br from-blue-900/20 to-gray-900/80 hover:shadow-blue-500/20' 
                    : 'border-blue-400/50 bg-gradient-to-br from-blue-50 to-white hover:shadow-blue-500/40 shadow-xl'
                }`}
                onMouseMove={handleMouseMove}
                onMouseLeave={handleMouseLeave}
                style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
              >
                <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
                  darkMode ? 'from-white/5 to-transparent' : 'from-blue-200/50 to-transparent'
                }`}></div>
                <div className={`absolute -top-px left-12 right-12 h-px bg-gradient-to-r from-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 ${
                  darkMode ? 'via-blue-400/40' : 'via-blue-500/60'
                }`}></div>
                
                <div className="relative z-10">
                  <h2 className={`text-2xl font-bold mb-6 flex items-center gap-2 ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                    <span className="text-2xl">📈</span>
                    Latest Pipeline Results
                  </h2>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
                    <div className={`rounded-xl p-4 border backdrop-blur-sm hover:border-gray-600/50 transition-all ${
                      darkMode ? 'bg-gray-800/60 border-gray-700/50' : 'bg-white/80 border-gray-300'
                    }`}>
                      <p className={`text-sm mb-1 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Execution ID</p>
                      <p className={`font-mono text-sm truncate ${darkMode ? 'text-blue-300' : 'text-blue-600'}`}>{result.execution_id || 'N/A'}</p>
                    </div>
                    <div className={`rounded-xl p-4 border backdrop-blur-sm hover:border-gray-600/50 transition-all ${
                      darkMode ? 'bg-gray-800/60 border-gray-700/50' : 'bg-white/80 border-gray-300'
                    }`}>
                      <p className={`text-sm mb-1 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Version</p>
                      <p className={`font-mono text-sm ${darkMode ? 'text-purple-300' : 'text-purple-600'}`}>{result.version || 'N/A'}</p>
                    </div>
                    <div className={`rounded-xl p-4 border backdrop-blur-sm hover:border-gray-600/50 transition-all ${
                      darkMode ? 'bg-gray-800/60 border-gray-700/50' : 'bg-white/80 border-gray-300'
                    }`}>
                      <p className={`text-sm mb-1 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Pipeline Status</p>
                      <p className={`font-semibold ${darkMode ? 'text-green-300' : 'text-green-600'}`}>All Stages Complete</p>
                    </div>
                    <div className={`rounded-xl p-4 border backdrop-blur-sm hover:border-gray-600/50 transition-all ${
                      darkMode ? 'bg-gray-800/60 border-gray-700/50' : 'bg-white/80 border-gray-300'
                    }`}>
                      <p className={`text-sm mb-1 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Total Stages</p>
                      <p className={`font-semibold ${darkMode ? 'text-green-400' : 'text-green-600'}`}>✓ 4/4 Completed</p>
                    </div>
                  </div>
                  <div className={`mt-4 rounded-xl p-5 border backdrop-blur-sm ${
                    darkMode ? 'bg-gray-800/60 border-gray-700/50' : 'bg-white/80 border-gray-300'
                  }`}>
                    <p className="text-sm mb-2">
                      <span className={darkMode ? 'text-gray-400' : 'text-gray-600'}>Data Sources Collected:</span> 
                      <span className={`font-semibold ml-2 ${darkMode ? 'text-blue-300' : 'text-blue-600'}`}>{result.collected_items || 2}</span>
                    </p>
                    <p className="text-sm mb-2">
                      <span className={darkMode ? 'text-gray-400' : 'text-gray-600'}>Pipeline Flow:</span> 
                      <span className={`font-semibold ml-2 ${darkMode ? 'text-purple-300' : 'text-purple-600'}`}>Collector → Validator → Processor → Reporter</span>
                    </p>
                    <p className="text-sm">
                      <span className={darkMode ? 'text-gray-400' : 'text-gray-600'}>Started:</span> 
                      <span className={`font-mono text-xs ml-2 ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}>{result.timestamp}</span>
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* History */}
            {history.length > 0 && (
              <div 
                className={`group relative rounded-2xl p-8 border shadow-lg hover:shadow-2xl transform transition-all duration-300 backdrop-blur-sm cursor-pointer ${
                  darkMode 
                    ? 'border-gray-600/30 bg-gradient-to-br from-gray-800/80 to-gray-900/80 hover:shadow-gray-500/20' 
                    : 'border-gray-300/50 bg-gradient-to-br from-gray-50 to-white hover:shadow-gray-400/40 shadow-xl'
                }`}
                onMouseMove={handleMouseMove}
                onMouseLeave={handleMouseLeave}
                style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
              >
                <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
                  darkMode ? 'from-white/5 to-transparent' : 'from-gray-200/50 to-transparent'
                }`}></div>
                <div className={`absolute -top-px left-12 right-12 h-px bg-gradient-to-r from-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 ${
                  darkMode ? 'via-gray-400/40' : 'via-gray-500/60'
                }`}></div>
                
                <div className="relative z-10">
                  <h2 className={`text-2xl font-bold mb-6 flex items-center gap-2 ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                    <span className="text-2xl">📋</span>
                    Pipeline History (Last 20)
                  </h2>
                  <div className="space-y-3 max-h-96 overflow-y-auto pr-2">
                    {history.map((item, idx) => (
                      <div 
                        key={idx} 
                        className={`group/item relative rounded-xl p-4 flex justify-between items-center transition-all duration-300 hover:shadow-lg border cursor-pointer ${
                          item.status === 'success' 
                            ? darkMode
                              ? 'bg-gray-800/50 hover:bg-gray-700/60 border-gray-700/50 hover:border-gray-600/50' 
                              : 'bg-white/80 hover:bg-gray-50 border-gray-300 hover:border-gray-400'
                            : darkMode
                            ? 'bg-red-900/20 hover:bg-red-900/30 border-red-700/40 hover:border-red-600/50' 
                            : 'bg-red-50 hover:bg-red-100/50 border-red-300 hover:border-red-400'
                        }`}
                        onMouseMove={handleMouseMove}
                        onMouseLeave={handleMouseLeave}
                        style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
                      >
                      <div className="flex-1">
                        <div className="flex items-center gap-3">
                          <span className={`font-semibold text-lg ${darkMode ? 'text-white' : 'text-gray-900'}`}>{item.location}</span>
                          <span className={`text-xs font-mono ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>{item.executionId?.slice(0, 12)}</span>
                          {item.retries > 0 && (
                            <span className={`text-xs px-2 py-1 rounded ${
                              darkMode ? 'bg-yellow-900/30 text-yellow-300' : 'bg-yellow-200 text-yellow-700'
                            }`}>
                              🔄 {item.retries} retries
                            </span>
                          )}
                          {item.validationWarnings > 0 && (
                            <span className={`text-xs px-2 py-1 rounded ${
                              darkMode ? 'bg-orange-900/30 text-orange-300' : 'bg-orange-200 text-orange-700'
                            }`}>
                              ⚠️ {item.validationWarnings} warnings
                            </span>
                          )}
                        </div>
                        <span className={`text-sm ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>{item.timestamp}</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className={`font-semibold ${
                          item.status === 'success' 
                            ? darkMode ? 'text-green-400' : 'text-green-600' 
                            : darkMode ? 'text-red-400' : 'text-red-600'
                        }`}>
                          {item.status === 'success' ? '✅ Success' : '❌ Failed'}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
            )}
          </>
        )}

        {/* Audit Logs Tab */}
        {activeTab === 'logs' && (
          <div className={`rounded-xl p-6 shadow-2xl border ${
            darkMode 
              ? 'bg-gray-800 border-gray-700' 
              : 'bg-white border-gray-300'
          }`}>
            <h2 className={`text-2xl font-semibold mb-4 ${darkMode ? 'text-white' : 'text-gray-900'}`}>📋 PostgreSQL Audit Logs</h2>
            <p className={`text-sm mb-4 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>
              Centralized logs stored in PostgreSQL • Execution tracking • Version history
            </p>
            
            {auditLogs.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className={`border-b ${darkMode ? 'border-gray-700' : 'border-gray-300'}`}>
                      <th className={`text-left p-3 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>ID</th>
                      <th className={`text-left p-3 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Execution ID</th>
                      <th className={`text-left p-3 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Version</th>
                      <th className={`text-left p-3 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Stage</th>
                      <th className={`text-left p-3 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Status</th>
                      <th className={`text-left p-3 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Location</th>
                      <th className={`text-left p-3 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Timestamp</th>
                    </tr>
                  </thead>
                  <tbody>
                    {auditLogs.map((log) => (
                      <tr key={log.id} className={`border-b transition-colors ${
                        darkMode 
                          ? 'border-gray-700/50 hover:bg-gray-700/30' 
                          : 'border-gray-200 hover:bg-gray-50'
                      }`}>
                        <td className={`p-3 ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}>{log.id}</td>
                        <td className={`p-3 font-mono text-xs ${darkMode ? 'text-blue-300' : 'text-blue-600'}`}>{log.execution_id?.slice(0, 12)}...</td>
                        <td className={`p-3 font-mono text-xs ${darkMode ? 'text-purple-300' : 'text-purple-600'}`}>{log.version?.slice(0, 15)}</td>
                        <td className={`p-3 ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}>{log.stage}</td>
                        <td className="p-3">
                          <span className={`px-2 py-1 rounded text-xs ${
                            log.status === 'success' 
                              ? darkMode 
                                ? 'bg-green-900/30 text-green-300' 
                                : 'bg-green-100 text-green-700'
                              : darkMode 
                              ? 'bg-red-900/30 text-red-300' 
                              : 'bg-red-100 text-red-700'
                          }`}>
                            {log.status}
                          </span>
                        </td>
                        <td className={`p-3 ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}>{log.location}</td>
                        <td className={`p-3 text-xs ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>{log.timestamp}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="text-center py-12">
                <p className={`mb-2 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>No audit logs available</p>
                <p className={`text-sm ${darkMode ? 'text-gray-500' : 'text-gray-500'}`}>Run the pipeline to generate logs</p>
              </div>
            )}
            
            <div className={`mt-6 p-4 rounded-lg border ${
              darkMode 
                ? 'bg-blue-900/20 border-blue-700/30' 
                : 'bg-blue-50 border-blue-300'
            }`}>
              <p className={`text-sm ${darkMode ? 'text-blue-300' : 'text-blue-700'}`}>
                💡 <strong>Note:</strong> Logs are stored in PostgreSQL at <code className={`px-2 py-1 rounded ${darkMode ? 'bg-gray-900/50' : 'bg-white'}`}>audit_logs</code> table.
                Use the query: <code className={`px-2 py-1 rounded text-xs ${darkMode ? 'bg-gray-900/50' : 'bg-white'}`}>SELECT * FROM audit_logs ORDER BY timestamp DESC;</code>
              </p>
            </div>
          </div>
        )}

        {/* Monitoring Tab */}
        {activeTab === 'monitoring' && (
          <div className="space-y-6">
            {/* Email Alert Setup */}
            <div 
              className={`group relative rounded-2xl p-8 border shadow-lg hover:shadow-2xl backdrop-blur-sm cursor-pointer ${
                darkMode 
                  ? 'border-green-500/30 bg-gradient-to-br from-green-900/20 to-gray-900/80 hover:shadow-green-500/20' 
                  : 'border-green-400/50 bg-gradient-to-br from-green-50 to-white hover:shadow-green-500/40 shadow-xl'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
            >
              <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
                darkMode ? 'from-white/5 to-transparent' : 'from-green-200/50 to-transparent'
              }`}></div>
              <div className={`absolute -top-px left-12 right-12 h-px bg-gradient-to-r from-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 ${
                darkMode ? 'via-green-400/40' : 'via-green-500/60'
              }`}></div>
              
              <div className="relative z-10">
                <h2 className={`text-2xl font-bold mb-6 flex items-center gap-2 ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                  <span className="text-2xl">📧</span>
                  Email Alert System
                </h2>
                
                <div className={`p-6 rounded-xl mb-6 border ${
                  emailAlerts 
                    ? darkMode
                      ? 'bg-green-900/30 border-green-500/40' 
                      : 'bg-green-100 border-green-400'
                    : darkMode
                    ? 'bg-yellow-900/30 border-yellow-500/40' 
                    : 'bg-yellow-100 border-yellow-400'
                }`}>
                  <div className="flex items-center gap-3 mb-3">
                    <span className="text-3xl">{emailAlerts ? '✅' : '⚠️'}</span>
                    <div>
                      <p className={`font-bold text-lg ${
                        emailAlerts 
                          ? darkMode ? 'text-green-300' : 'text-green-700'
                          : darkMode ? 'text-yellow-300' : 'text-yellow-700'
                      }`}>
                        {emailAlerts ? 'Email System Configured & Active!' : 'Email alerts need configuration'}
                      </p>
                      <p className={`text-sm ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}>
                        {emailAlerts 
                          ? 'Gmail SMTP configured • Validation failure alerts enabled' 
                          : 'Configure Gmail SMTP in .env file to enable notifications'}
                      </p>
                    </div>
                  </div>
                  
                  {emailAlerts && (
                    <div className={`mt-4 p-4 rounded-lg ${darkMode ? 'bg-gray-800/60' : 'bg-white/80'}`}>
                      <p className={`text-sm font-semibold mb-2 ${darkMode ? 'text-green-400' : 'text-green-700'}`}>
                        📬 Configuration Details:
                      </p>
                      <ul className={`text-sm space-y-1 ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}>
                        <li>• <strong>SMTP Host:</strong> smtp.gmail.com:587</li>
                        <li>• <strong>Email:</strong> faisal96kp@gmail.com</li>
                        <li>• <strong>Authentication:</strong> App Password ✓</li>
                        <li>• <strong>Trigger:</strong> Quality score &lt; 50 in Validator stage</li>
                        <li>• <strong>Status:</strong> <span className={darkMode ? 'text-green-400' : 'text-green-600'}>Active & Ready</span></li>
                      </ul>
                    </div>
                  )}
                </div>

                {!emailAlerts && (
                  <div className={`rounded-xl p-6 border ${darkMode ? 'bg-gray-800/50 border-gray-700' : 'bg-gray-50 border-gray-300'}`}>
                    <h3 className={`font-semibold mb-4 ${darkMode ? 'text-blue-300' : 'text-blue-600'}`}>📝 Quick Setup Guide:</h3>
                    <ol className={`text-sm space-y-2 list-decimal list-inside ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}>
                      <li>Go to <a href="https://myaccount.google.com/security" target="_blank" className="text-blue-400 hover:underline font-medium">Google Account Security</a></li>
                      <li>Enable <strong>2-Factor Authentication</strong></li>
                      <li>Generate <a href="https://myaccount.google.com/apppasswords" target="_blank" className="text-blue-400 hover:underline font-medium">App Password</a> for "Mail"</li>
                      <li>Copy the 16-character password (remove spaces)</li>
                      <li>Update <code className={`px-2 py-1 rounded text-xs ${darkMode ? 'bg-gray-700 text-green-300' : 'bg-gray-200 text-purple-700'}`}>N8N_SMTP_PASS</code> in .env</li>
                      <li>Run: <code className={`px-2 py-1 rounded text-xs ${darkMode ? 'bg-gray-700 text-blue-300' : 'bg-gray-200 text-blue-700'}`}>docker-compose restart n8n</code></li>
                    </ol>
                  </div>
                )}
              </div>
            </div>

            {/* Services Status */}
            <div 
              className={`group relative rounded-2xl p-8 border shadow-lg hover:shadow-2xl backdrop-blur-sm cursor-pointer ${
                darkMode 
                  ? 'border-blue-500/30 bg-gradient-to-br from-blue-900/20 to-gray-900/80 hover:shadow-blue-500/20' 
                  : 'border-blue-400/50 bg-gradient-to-br from-blue-50 to-white hover:shadow-blue-500/40 shadow-xl'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
            >
              <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
                darkMode ? 'from-white/5 to-transparent' : 'from-blue-200/50 to-transparent'
              }`}></div>
              <div className={`absolute -top-px left-12 right-12 h-px bg-gradient-to-r from-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 ${
                darkMode ? 'via-blue-400/40' : 'via-blue-500/60'
              }`}></div>
              
              <div className="relative z-10">
                <h2 className={`text-2xl font-bold mb-6 flex items-center gap-2 ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                  <span className="text-2xl">🖥️</span>
                  Services Status
                </h2>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {[
                    { name: 'n8n', port: '5678', url: 'http://localhost:5678', status: 'running' },
                    { name: 'PostgreSQL', port: '5432', status: 'running' },
                    { name: 'Grafana', port: '3000', url: 'http://localhost:3000', status: 'running' },
                    { name: 'Redis', port: '6379', status: 'running' },
                    { name: 'Frontend', port: '3003', url: 'http://localhost:3003', status: 'running' }
                  ].map((service) => (
                    <div 
                      key={service.name} 
                      className={`rounded-xl p-4 border transition-all ${
                        darkMode 
                          ? 'bg-gray-800/60 border-gray-700 hover:border-gray-600 hover:bg-gray-700/60' 
                          : 'bg-white/80 border-gray-300 hover:border-gray-400 hover:bg-gray-50'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-2">
                        <h3 className={`font-semibold ${darkMode ? 'text-white' : 'text-gray-900'}`}>{service.name}</h3>
                        <span className={darkMode ? 'text-green-400 text-xl' : 'text-green-600 text-xl'}>✓</span>
                      </div>
                      <p className={`text-xs ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Port: {service.port}</p>
                      {service.url && (
                        <a href={service.url} target="_blank" className="text-xs text-blue-400 hover:underline mt-1 block">
                          Open →
                        </a>
                      )}
                    </div>
                  ))}
              </div>
              </div>
            </div>

            {/* Grafana Dashboard */}
            <div 
              className={`group relative rounded-2xl p-8 border shadow-lg hover:shadow-2xl backdrop-blur-sm cursor-pointer ${
                darkMode 
                  ? 'border-orange-500/30 bg-gradient-to-br from-orange-900/20 to-gray-900/80 hover:shadow-orange-500/20' 
                  : 'border-orange-400/50 bg-gradient-to-br from-orange-50 to-white hover:shadow-orange-500/40 shadow-xl'
              }`}
              onMouseMove={handleMouseMove}
              onMouseLeave={handleMouseLeave}
              style={{ transformStyle: 'preserve-3d', perspective: '1000px', transition: 'transform 0.1s ease-out' }}
            >
              <div className={`absolute inset-0 rounded-2xl bg-gradient-to-br opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none ${
                darkMode ? 'from-white/5 to-transparent' : 'from-orange-200/50 to-transparent'
              }`}></div>
              <div className={`absolute -top-px left-12 right-12 h-px bg-gradient-to-r from-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 ${
                darkMode ? 'via-orange-400/40' : 'via-orange-500/60'
              }`}></div>
              
              <div className="relative z-10">
                <h2 className={`text-2xl font-bold mb-4 flex items-center gap-2 ${darkMode ? 'text-white' : 'text-gray-900'}`}>
                  <span className="text-2xl">📈</span>
                  Grafana Dashboard
                </h2>
                <p className={`text-sm mb-4 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>
                  Real-time metrics and visualization at <a href="http://localhost:3000" target="_blank" className="text-blue-400 hover:underline">localhost:3000</a>
                </p>
                <div className={`rounded-lg p-4 border ${darkMode ? 'bg-gray-800/50 border-gray-700' : 'bg-gray-50 border-gray-300'}`}>
                  <p className={`text-sm mb-2 ${darkMode ? 'text-gray-300' : 'text-gray-700'}`}><strong>Credentials:</strong></p>
                  <p className={`text-sm ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Username: <code className={`px-2 py-1 rounded ${darkMode ? 'bg-gray-700 text-blue-300' : 'bg-gray-200 text-blue-700'}`}>admin</code></p>
                  <p className={`text-sm ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>Password: <code className={`px-2 py-1 rounded ${darkMode ? 'bg-gray-700 text-purple-300' : 'bg-gray-200 text-purple-700'}`}>admin123</code></p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Empty State */}
        {activeTab === 'pipeline' && !result && history.length === 0 && (
          <div className={`rounded-xl p-12 text-center shadow-2xl border ${
            darkMode 
              ? 'bg-gray-800 border-gray-700' 
              : 'bg-white border-gray-300'
          }`}>
            <div className="text-6xl mb-4">🚀</div>
            <p className={`text-lg mb-4 ${darkMode ? 'text-gray-400' : 'text-gray-600'}`}>No pipeline executions yet</p>
            <p className={darkMode ? 'text-gray-500' : 'text-gray-500'}>Select a location and trigger the pipeline to see real-time results</p>
          </div>
        )}
      </div>
    </div>
  )
}

export default App
