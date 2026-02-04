const express = require('express');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const app = express();

app.use(express.json({ limit: '10mb' }));

const PORT = process.env.PORT || 3000;
const LUA_PATH = process.env.LUA_PATH || 'lua5.1'; // atau 'luajit'
const PROMETHEUS_PATH = path.join(__dirname, 'prometheus');

// Helper: Convert JS Object to Lua Table
function jsToLua(obj, indent = 0) {
  const spaces = '  '.repeat(indent);
  
  if (obj === null || obj === undefined) return 'nil';
  if (typeof obj === 'string') return `"${obj.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  if (typeof obj === 'number') return String(obj);
  if (typeof obj === 'boolean') return obj ? 'true' : 'false';
  
  if (Array.isArray(obj)) {
    if (obj.length === 0) return '{}';
    const items = obj.map(item => `${spaces}  ${jsToLua(item, indent + 1)}`);
    return `{\n${items.join(',\n')}\n${spaces}}`;
  }
  
  if (typeof obj === 'object') {
    const entries = Object.entries(obj);
    if (entries.length === 0) return '{}';
    const pairs = entries.map(([k, v]) => {
      const key = /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(k) ? k : `["${k}"]`;
      return `${spaces}  ${key} = ${jsToLua(v, indent + 1)}`;
    });
    return `{\n${pairs.join(';\n')};\n${spaces}}`;
  }
  
  return 'nil';
}

// Default configs untuk Roblox
const ROBLOX_PRESETS = {
  'Minify': {
    LuaVersion: "LuaU",
    VarNamePrefix: "",
    NameGenerator: "MangledShuffled",
    PrettyPrint: false,
    Seed: 0,
    Steps: []
  },
  'Weak': {
    LuaVersion: "LuaU",
    VarNamePrefix: "",
    NameGenerator: "MangledShuffled",
    PrettyPrint: false,
    Seed: 0,
    Steps: [
      { Name: "ConstantArray", Settings: { Treshold: 0.5, StringsOnly: true } }
    ]
  },
  'Medium': {
    LuaVersion: "LuaU",
    VarNamePrefix: "",
    NameGenerator: "MangledShuffled",
    PrettyPrint: false,
    Seed: 0,
    Steps: [
      { Name: "ConstantArray", Settings: { Treshold: 0.8, StringsOnly: false, Shuffle: true, Rotate: true } },
      { Name: "EncryptStrings", Settings: { Treshold: 0.8 } },
      { Name: "WrapInFunction", Settings: {} }
    ]
  },
  'Strong': {
    LuaVersion: "LuaU",
    VarNamePrefix: "",
    NameGenerator: "MangledShuffled",
    PrettyPrint: false,
    Seed: 0,
    Steps: [
      { Name: "ConstantArray", Settings: { Treshold: 0.9, StringsOnly: false, Shuffle: true, Rotate: true, LocalWrapperTreshold: 0.7 } },
      { Name: "EncryptStrings", Settings: { Treshold: 0.9 } },
      { Name: "SplitStrings", Settings: { Treshold: 0.5 } },
      { Name: "ProxifyLocals", Settings: { Treshold: 0.7 } },
      { Name: "WrapInFunction", Settings: {} }
    ]
  }
};

// Endpoint: Obfuscate untuk Roblox
app.post('/obfuscate', async (req, res) => {
  try {
    const { code, preset = 'Medium', config, luaVersion = 'LuaU' } = req.body;
    
    if (!code) {
      return res.status(400).json({ error: 'Code is required' });
    }

    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(7);
    const inputFile = path.join('/tmp', `input_${timestamp}_${randomId}.lua`);
    const outputFile = path.join('/tmp', `output_${timestamp}_${randomId}.lua`);
    const configFile = path.join('/tmp', `config_${timestamp}_${randomId}.lua`);

    fs.writeFileSync(inputFile, code, 'utf-8');

    // Build config - prioritaskan custom config, lalu preset Roblox
    let finalConfig;
    if (config && typeof config === 'object') {
      finalConfig = { ...config, LuaVersion: config.LuaVersion || luaVersion };
    } else if (ROBLOX_PRESETS[preset]) {
      finalConfig = { ...ROBLOX_PRESETS[preset], LuaVersion: luaVersion };
    } else {
      finalConfig = { ...ROBLOX_PRESETS['Medium'], LuaVersion: luaVersion };
    }

    // Write config sebagai Lua
    const luaConfig = `return ${jsToLua(finalConfig)}`;
    fs.writeFileSync(configFile, luaConfig, 'utf-8');

    const command = `cd ${PROMETHEUS_PATH} && ${LUA_PATH} cli.lua --config ${configFile} ${inputFile} --out ${outputFile}`;

    exec(command, { 
      maxBuffer: 1024 * 1024 * 50,
      timeout: 120000
    }, (error, stdout, stderr) => {
      // Cleanup
      try {
        if (fs.existsSync(inputFile)) fs.unlinkSync(inputFile);
        if (fs.existsSync(configFile)) fs.unlinkSync(configFile);
      } catch (e) {}

      if (error) {
        console.error('Obfuscation error:', stderr || error.message);
        return res.status(500).json({ 
          error: 'Obfuscation failed', 
          details: stderr || error.message,
          hint: 'If using LuaU features, some may not be supported yet'
        });
      }

      if (fs.existsSync(outputFile)) {
        const obfuscatedCode = fs.readFileSync(outputFile, 'utf-8');
        try { fs.unlinkSync(outputFile); } catch (e) {}
        
        res.json({
          success: true,
          code: obfuscatedCode,
          preset: preset,
          luaVersion: finalConfig.LuaVersion,
          originalSize: code.length,
          obfuscatedSize: obfuscatedCode.length
        });
      } else {
        res.status(500).json({ 
          error: 'Output file not generated',
          stdout: stdout,
          stderr: stderr
        });
      }
    });

  } catch (error) {
    console.error('Server error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint: Health
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok',
    service: 'Prometheus Obfuscator (Roblox/LuaU)',
    luaRuntime: LUA_PATH,
    note: 'LuaU support is not fully finished yet'
  });
});

// Endpoint: Presets untuk Roblox
app.get('/presets', (req, res) => {
  res.json({
    presets: Object.keys(ROBLOX_PRESETS),
    default: 'Medium',
    luaVersion: 'LuaU',
    warning: 'LuaU support is not fully finished yet. Test thoroughly!',
    description: {
      'Minify': 'Only minification, no obfuscation',
      'Weak': 'Basic obfuscation - fast, safe for most Roblox scripts',
      'Medium': 'Balanced obfuscation - recommended for Roblox',
      'Strong': 'Maximum obfuscation - may cause issues with complex scripts'
    }
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🔥 Prometheus Obfuscator Service (Roblox/LuaU)`);
  console.log(`📍 Running on port ${PORT}`);
  console.log(`🎮 Default LuaVersion: LuaU`);
  console.log(`⚠️  Note: LuaU support is not fully finished yet`);
});
