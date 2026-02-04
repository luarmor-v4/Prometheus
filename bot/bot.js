/**
 * Prometheus Discord Bot
 * With Roblox/LuaU Support
 * CORRECTED VERSION - Uses src/cli.lua path
 * 
 * @version 1.1.0
 */

const { Client, GatewayIntentBits, AttachmentBuilder, EmbedBuilder } = require('discord.js');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// ============================================================
// CONFIGURATION
// ============================================================
const PROMETHEUS_PATH = process.env.PROMETHEUS_PATH || './prometheus';
const LUA_PATH = process.env.LUA_PATH || 'lua5.1';
const PROMETHEUS_CLI = path.join(PROMETHEUS_PATH, 'src', 'cli.lua'); // ← CORRECTED PATH
const MAX_CODE_LENGTH = 500000; // 500KB max
const TIMEOUT_MS = 60000; // 60 seconds

// Valid presets
const VALID_PRESETS = [
  'Minify', 'Weak', 'Medium', 'Strong',
  'RobloxMinify', 'RobloxWeak', 'RobloxMedium', 'RobloxStrong', 'RobloxSafeStrong'
];

// ============================================================
// DISCORD CLIENT
// ============================================================
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent
  ]
});

// ============================================================
// HELPER: Download File
// ============================================================
function downloadFile(url) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    
    const request = protocol.get(url, (response) => {
      // Handle redirects
      if (response.statusCode === 301 || response.statusCode === 302) {
        downloadFile(response.headers.location).then(resolve).catch(reject);
        return;
      }
      
      if (response.statusCode !== 200) {
        reject(new Error(`HTTP ${response.statusCode}`));
        return;
      }
      
      let data = '';
      response.setEncoding('utf8');
      response.on('data', chunk => data += chunk);
      response.on('end', () => resolve(data));
      response.on('error', reject);
    });
    
    request.on('error', reject);
    request.setTimeout(30000, () => {
      request.destroy();
      reject(new Error('Download timeout'));
    });
  });
}

// ============================================================
// HELPER: Write File Safely
// ============================================================
function writeFileSafe(filepath, content) {
  return new Promise((resolve, reject) => {
    fs.writeFile(filepath, content, 'utf-8', (err) => {
      if (err) reject(err);
      else resolve();
    });
  });
}

// ============================================================
// HELPER: Read File Safely
// ============================================================
function readFileSafe(filepath) {
  return new Promise((resolve, reject) => {
    fs.readFile(filepath, 'utf-8', (err, data) => {
      if (err) reject(err);
      else resolve(data);
    });
  });
}

// ============================================================
// HELPER: Delete File Safely
// ============================================================
function deleteFileSafe(filepath) {
  return new Promise((resolve) => {
    fs.unlink(filepath, () => resolve()); // Ignore errors
  });
}

// ============================================================
// OBFUSCATE FUNCTION - CORRECTED PATH
// ============================================================
async function obfuscate(luaCode, preset = 'Medium') {
  return new Promise(async (resolve, reject) => {
    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(2, 10);
    const inputFile = `/tmp/input_${timestamp}_${randomId}.lua`;
    const outputFile = `/tmp/output_${timestamp}_${randomId}.lua`;

    try {
      // Write input file
      await writeFileSafe(inputFile, luaCode);

      // ✅ CORRECTED: Build command with src/cli.lua path
      const command = `cd "${PROMETHEUS_PATH}" && "${LUA_PATH}" "src/cli.lua" --preset ${preset} "${inputFile}" --out "${outputFile}"`;
      
      console.log(`[DEBUG] Executing: ${command}`);

      // Execute
      exec(command, { 
        maxBuffer: 1024 * 1024 * 50,
        timeout: TIMEOUT_MS,
        cwd: PROMETHEUS_PATH // Set working directory
      }, async (error, stdout, stderr) => {
        // Cleanup input
        await deleteFileSafe(inputFile);

        if (error) {
          console.error('[ERROR] Obfuscation failed:', stderr || error.message);
          reject(new Error(stderr || error.message));
          return;
        }

        // Check output file
        if (!fs.existsSync(outputFile)) {
          console.error('[ERROR] Output file not created');
          console.error('[STDOUT]', stdout);
          console.error('[STDERR]', stderr);
          reject(new Error('Output file not created'));
          return;
        }

        try {
          const obfuscatedCode = await readFileSafe(outputFile);
          await deleteFileSafe(outputFile);
          console.log(`[SUCCESS] Obfuscated ${luaCode.length} -> ${obfuscatedCode.length} bytes`);
          resolve(obfuscatedCode);
        } catch (e) {
          console.error('[ERROR] Reading output:', e);
          reject(e);
        }
      });
    } catch (e) {
      console.error('[ERROR] Setup failed:', e);
      await deleteFileSafe(inputFile);
      reject(e);
    }
  });
}

// ============================================================
// BOT: Ready Event
// ============================================================
client.on('ready', () => {
  console.log('');
  console.log('🤖 ═══════════════════════════════════════════════════════');
  console.log(`🤖  Bot: ${client.user.tag}`);
  console.log('🤖 ═══════════════════════════════════════════════════════');
  console.log(`📂  Prometheus Path: ${PROMETHEUS_PATH}`);
  console.log(`📜  CLI Path: ${PROMETHEUS_CLI}`);
  console.log(`🔧  Lua Runtime: ${LUA_PATH}`);
  console.log(`✅  CLI Exists: ${fs.existsSync(PROMETHEUS_CLI) ? 'YES' : 'NO'}`);
  console.log('🎮  Roblox/LuaU: Supported');
  console.log('');
  console.log('📋  Commands:');
  console.log('    !help           - Show help');
  console.log('    !presets        - List presets');
  console.log('    !obfuscate      - Obfuscate code');
  console.log('');
  console.log('🤖 ═══════════════════════════════════════════════════════');
  console.log('');
  
  // Check if CLI exists
  if (!fs.existsSync(PROMETHEUS_CLI)) {
    console.error('❌ ERROR: Prometheus CLI not found at:', PROMETHEUS_CLI);
    console.error('❌ Please check PROMETHEUS_PATH environment variable');
  }
  
  client.user.setActivity('!help | Lua Obfuscator', { type: 'WATCHING' });
});

// ============================================================
// BOT: Message Event
// ============================================================
client.on('messageCreate', async (message) => {
  if (message.author.bot) return;
  
  const content = message.content.trim();
  const lowerContent = content.toLowerCase();

  // ============================================================
  // COMMAND: !help
  // ============================================================
  if (lowerContent === '!help' || lowerContent === '!h') {
    const embed = new EmbedBuilder()
      .setTitle('🔥 Prometheus Lua Obfuscator Bot')
      .setColor('#FF6B35')
      .setDescription('Obfuscate your Lua/Roblox scripts!')
      .addFields(
        { 
          name: '📝 !obfuscate [preset]', 
          value: 'Obfuscate code in a code block\n```!obfuscate RobloxMedium\n\\`\\`\\`lua\nprint("Hello")\n\\`\\`\\````', 
          inline: false 
        },
        { 
          name: '📎 !obfuscate [preset] + file', 
          value: 'Upload a .lua file with the command', 
          inline: false 
        },
        { 
          name: '📋 !presets', 
          value: 'Show all available presets', 
          inline: false 
        },
        { 
          name: '❓ !help', 
          value: 'Show this message', 
          inline: false 
        },
        {
          name: '🔍 !status',
          value: 'Check bot status',
          inline: false
        }
      )
      .addFields({
        name: '⚡ Quick Presets',
        value: '`Minify` `Weak` `Medium` `Strong`\n`RobloxMinify` `RobloxWeak` `RobloxMedium` `RobloxStrong`',
        inline: false
      })
      .addFields({
        name: '⚠️ Note',
        value: 'LuaU support is not fully finished. If errors occur, try a lighter preset.',
        inline: false
      })
      .setFooter({ text: 'Powered by Prometheus' })
      .setTimestamp();

    return message.reply({ embeds: [embed] });
  }

  // ============================================================
  // COMMAND: !status (untuk debug)
  // ============================================================
  if (lowerContent === '!status') {
    const cliExists = fs.existsSync(PROMETHEUS_CLI);
    const prometheusPathExists = fs.existsSync(PROMETHEUS_PATH);
    
    const embed = new EmbedBuilder()
      .setTitle('🔍 Bot Status')
      .setColor(cliExists ? '#00FF00' : '#FF0000')
      .addFields(
        { name: 'Prometheus Path', value: `\`${PROMETHEUS_PATH}\``, inline: false },
        { name: 'Path Exists', value: prometheusPathExists ? '✅ Yes' : '❌ No', inline: true },
        { name: 'CLI Path', value: `\`${PROMETHEUS_CLI}\``, inline: false },
        { name: 'CLI Exists', value: cliExists ? '✅ Yes' : '❌ No', inline: true },
        { name: 'Lua Runtime', value: `\`${LUA_PATH}\``, inline: true },
        { name: 'Status', value: cliExists ? '🟢 Operational' : '🔴 CLI Not Found', inline: false }
      );
    
    if (!cliExists) {
      embed.addFields({
        name: '⚠️ Troubleshooting',
        value: [
          '1. Check if Prometheus is cloned',
          '2. CLI should be at `prometheus/src/cli.lua`',
          '3. Set PROMETHEUS_PATH env variable correctly',
          '4. Restart the bot'
        ].join('\n'),
        inline: false
      });
    }
    
    return message.reply({ embeds: [embed] });
  }

  // ============================================================
  // COMMAND: !presets
  // ============================================================
  if (lowerContent === '!presets' || lowerContent === '!preset') {
    const embed = new EmbedBuilder()
      .setTitle('🔥 Available Presets')
      .setColor('#FF6B35')
      .addFields(
        { 
          name: '📦 STANDARD PRESETS (Lua 5.1)', 
          value: [
            '`Minify` - Only minification',
            '`Weak` - Basic obfuscation',
            '`Medium` - Balanced ⭐ Recommended',
            '`Strong` - Maximum (may cause errors)'
          ].join('\n'),
          inline: false 
        },
        { 
          name: '🎮 ROBLOX PRESETS (LuaU)', 
          value: [
            '`RobloxMinify` - Minify for Roblox',
            '`RobloxWeak` - Basic for Roblox',
            '`RobloxMedium` - Balanced ⭐ Recommended',
            '`RobloxStrong` - Strong for Roblox',
            '`RobloxSafeStrong` - Safe strong for Roblox'
          ].join('\n'),
          inline: false 
        }
      )
      .addFields({
        name: '💡 Tips',
        value: [
          '• For Roblox, use `RobloxMedium` (recommended)',
          '• Start with lighter presets and test',
          '• Strong presets may cause errors on complex scripts',
          '• LuaU support is not fully finished yet'
        ].join('\n'),
        inline: false
      })
      .setFooter({ text: 'Usage: !obfuscate <preset>' });

    return message.reply({ embeds: [embed] });
  }

  // ============================================================
  // COMMAND: !obfuscate / !obf
  // ============================================================
  if (lowerContent.startsWith('!obfuscate') || lowerContent.startsWith('!obf')) {
    
    // Check if CLI exists before processing
    if (!fs.existsSync(PROMETHEUS_CLI)) {
      return message.reply({
        content: [
          '❌ **Error: Prometheus CLI not found!**',
          '',
          `Expected location: \`${PROMETHEUS_CLI}\``,
          '',
          '**Troubleshooting:**',
          '1. Ensure Prometheus is cloned in the correct location',
          '2. CLI should be at `prometheus/src/cli.lua`',
          '3. Check PROMETHEUS_PATH environment variable',
          '4. Contact bot administrator',
          '',
          'Use `!status` to check bot configuration.'
        ].join('\n')
      });
    }
    
    const args = content.split(/\s+/);
    
    // Find preset in args
    let preset = 'Medium'; // Default
    for (const arg of args) {
      // Case-insensitive preset matching
      const matchedPreset = VALID_PRESETS.find(p => p.toLowerCase() === arg.toLowerCase());
      if (matchedPreset) {
        preset = matchedPreset;
        break;
      }
    }

    // ========== Handle File Attachment ==========
    if (message.attachments.size > 0) {
      const attachment = message.attachments.first();
      
      if (!attachment.name.endsWith('.lua')) {
        return message.reply('❌ Please upload a `.lua` file!');
      }
      
      if (attachment.size > MAX_CODE_LENGTH) {
        return message.reply(`❌ File too large! Maximum size: ${MAX_CODE_LENGTH / 1024}KB`);
      }

      const loadingMsg = await message.reply(`⏳ Processing **${attachment.name}** with preset **${preset}**...`);

      try {
        const luaCode = await downloadFile(attachment.url);
        const startTime = Date.now();
        const obfuscatedCode = await obfuscate(luaCode, preset);
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);

        const buffer = Buffer.from(obfuscatedCode, 'utf-8');
        const file = new AttachmentBuilder(buffer, { 
          name: `obfuscated_${attachment.name}` 
        });

        const ratio = (obfuscatedCode.length / luaCode.length).toFixed(2);

        await loadingMsg.edit({
          content: [
            `✅ **${attachment.name}** obfuscated!`,
            `📊 Preset: **${preset}**`,
            `📏 Size: ${luaCode.length} → ${obfuscatedCode.length} bytes (${ratio}x)`,
            `⏱️ Time: ${elapsed}s`
          ].join('\n'),
          files: [file]
        });
      } catch (error) {
        console.error('[ERROR] File obfuscation:', error);
        await loadingMsg.edit([
          `❌ Error: ${error.message}`,
          '',
          '💡 **Tips:**',
          '• Try a lighter preset (Minify, Weak, RobloxWeak)',
          '• Check your code for syntax errors',
          '• For Roblox, remove type annotations if present',
          '• Use `!status` to check bot configuration'
        ].join('\n'));
      }
      return;
    }

    // ========== Handle Code Block ==========
    const codeMatch = content.match(/```(?:lua)?\n?([\s\S]+?)```/);
    
    if (!codeMatch) {
      return message.reply([
        '❌ Please provide code in a code block or attach a `.lua` file!',
        '',
        '**Example:**',
        '```',
        '!obfuscate RobloxMedium',
        '\\`\\`\\`lua',
        'print("Hello World")',
        '\\`\\`\\`',
        '```'
      ].join('\n'));
    }

    const luaCode = codeMatch[1].trim();
    
    if (luaCode.length < 5) {
      return message.reply('❌ Code is too short!');
    }
    
    if (luaCode.length > MAX_CODE_LENGTH) {
      return message.reply(`❌ Code too large! Maximum: ${MAX_CODE_LENGTH / 1024}KB. Please upload as file.`);
    }

    const loadingMsg = await message.reply(`⏳ Obfuscating with preset **${preset}**...`);

    try {
      const startTime = Date.now();
      const obfuscatedCode = await obfuscate(luaCode, preset);
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
      const ratio = (obfuscatedCode.length / luaCode.length).toFixed(2);

      // If result is small enough, send in message
      if (obfuscatedCode.length <= 1900) {
        await loadingMsg.edit([
          `✅ Obfuscation complete!`,
          `📊 Preset: **${preset}** | Size: ${ratio}x | Time: ${elapsed}s`,
          '```lua',
          obfuscatedCode,
          '```'
        ].join('\n'));
      } else {
        // Send as file
        const buffer = Buffer.from(obfuscatedCode, 'utf-8');
        const attachment = new AttachmentBuilder(buffer, { 
          name: `obfuscated_${preset.toLowerCase()}.lua` 
        });

        await loadingMsg.edit({
          content: [
            `✅ Obfuscation complete!`,
            `📊 Preset: **${preset}**`,
            `📏 Size: ${luaCode.length} → ${obfuscatedCode.length} bytes (${ratio}x)`,
            `⏱️ Time: ${elapsed}s`,
            `📦 Output too large, sent as file.`
          ].join('\n'),
          files: [attachment]
        });
      }
    } catch (error) {
      console.error('[ERROR] Code obfuscation:', error);
      await loadingMsg.edit([
        `❌ Error: ${error.message}`,
        '',
        '💡 **Tips:**',
        '• Try a lighter preset (Minify, Weak, RobloxWeak)',
        '• Check your code for syntax errors',
        '• For Roblox, remove type annotations if present',
        '• Use `!status` to check bot configuration'
      ].join('\n'));
    }
  }
});

// ============================================================
// ERROR HANDLING
// ============================================================
client.on('error', (error) => {
  console.error('Discord client error:', error);
});

process.on('unhandledRejection', (error) => {
  console.error('Unhandled rejection:', error);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error);
});

// ============================================================
// LOGIN
// ============================================================
const token = process.env.DISCORD_TOKEN;

if (!token) {
  console.error('');
  console.error('❌ ═══════════════════════════════════════════════════════');
  console.error('❌  ERROR: DISCORD_TOKEN environment variable is required!');
  console.error('❌ ═══════════════════════════════════════════════════════');
  console.error('');
  console.error('Set DISCORD_TOKEN in your environment:');
  console.error('  export DISCORD_TOKEN="your_bot_token_here"');
  console.error('');
  process.exit(1);
}

console.log('🔄 Connecting to Discord...');
client.login(token).catch(err => {
  console.error('❌ Failed to login:', err.message);
  process.exit(1);
});
