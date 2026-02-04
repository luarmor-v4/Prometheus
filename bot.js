// bot.js - Roblox/LuaU Version
const { Client, GatewayIntentBits, AttachmentBuilder, EmbedBuilder } = require('discord.js');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent
  ]
});

const PROMETHEUS_PATH = process.env.PROMETHEUS_PATH || './prometheus';
const LUA_PATH = process.env.LUA_PATH || 'lua5.1';
const VALID_PRESETS = ['Minify', 'Weak', 'Medium', 'Strong'];

// Roblox-specific presets dengan LuaU
const ROBLOX_CONFIGS = {
  'Minify': `return { LuaVersion = "LuaU"; VarNamePrefix = ""; NameGenerator = "MangledShuffled"; PrettyPrint = false; Seed = 0; Steps = {} }`,
  
  'Weak': `return { LuaVersion = "LuaU"; VarNamePrefix = ""; NameGenerator = "MangledShuffled"; PrettyPrint = false; Seed = 0; Steps = { { Name = "ConstantArray"; Settings = { Treshold = 0.5; StringsOnly = true; } } } }`,
  
  'Medium': `return { LuaVersion = "LuaU"; VarNamePrefix = ""; NameGenerator = "MangledShuffled"; PrettyPrint = false; Seed = 0; Steps = { { Name = "ConstantArray"; Settings = { Treshold = 0.8; StringsOnly = false; Shuffle = true; Rotate = true; } }; { Name = "EncryptStrings"; Settings = { Treshold = 0.8; } }; { Name = "WrapInFunction"; Settings = {}; } } }`,
  
  'Strong': `return { LuaVersion = "LuaU"; VarNamePrefix = ""; NameGenerator = "MangledShuffled"; PrettyPrint = false; Seed = 0; Steps = { { Name = "ConstantArray"; Settings = { Treshold = 0.9; StringsOnly = false; Shuffle = true; Rotate = true; LocalWrapperTreshold = 0.7; } }; { Name = "EncryptStrings"; Settings = { Treshold = 0.9; } }; { Name = "SplitStrings"; Settings = { Treshold = 0.5; } }; { Name = "ProxifyLocals"; Settings = { Treshold = 0.7; } }; { Name = "WrapInFunction"; Settings = {}; } } }`
};

// Download file helper
function downloadFile(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      if (response.statusCode === 301 || response.statusCode === 302) {
        downloadFile(response.headers.location).then(resolve).catch(reject);
        return;
      }
      let data = '';
      response.on('data', chunk => data += chunk);
      response.on('end', () => resolve(data));
      response.on('error', reject);
    }).on('error', reject);
  });
}

// Obfuscate function untuk Roblox
async function obfuscateForRoblox(luaCode, preset = 'Medium') {
  return new Promise((resolve, reject) => {
    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(7);
    const inputFile = `/tmp/input_${timestamp}_${randomId}.lua`;
    const outputFile = `/tmp/output_${timestamp}_${randomId}.lua`;
    const configFile = `/tmp/config_${timestamp}_${randomId}.lua`;

    // Write input
    fs.writeFileSync(inputFile, luaCode, 'utf-8');
    
    // Write config dengan LuaU
    const configContent = ROBLOX_CONFIGS[preset] || ROBLOX_CONFIGS['Medium'];
    fs.writeFileSync(configFile, configContent, 'utf-8');

    const command = `cd ${PROMETHEUS_PATH} && ${LUA_PATH} cli.lua --config ${configFile} ${inputFile} --out ${outputFile}`;

    exec(command, { 
      maxBuffer: 1024 * 1024 * 50,
      timeout: 60000 
    }, (error, stdout, stderr) => {
      // Cleanup
      try { fs.unlinkSync(inputFile); } catch (e) {}
      try { fs.unlinkSync(configFile); } catch (e) {}

      if (error) {
        reject(new Error(stderr || error.message));
        return;
      }

      if (fs.existsSync(outputFile)) {
        const obfuscatedCode = fs.readFileSync(outputFile, 'utf-8');
        try { fs.unlinkSync(outputFile); } catch (e) {}
        resolve(obfuscatedCode);
      } else {
        reject(new Error('Output file not created'));
      }
    });
  });
}

client.on('ready', () => {
  console.log(`🤖 Bot logged in as ${client.user.tag}`);
  console.log(`🎮 Mode: Roblox/LuaU`);
  client.user.setActivity('!help | Roblox Obfuscator', { type: 'WATCHING' });
});

client.on('messageCreate', async (message) => {
  if (message.author.bot) return;

  const content = message.content.trim();

  // Command: !obfuscate atau !obf
  if (content.startsWith('!obfuscate') || content.startsWith('!obf')) {
    const args = content.split(/\s+/);
    let preset = 'Medium';
    
    for (const arg of args) {
      if (VALID_PRESETS.includes(arg)) {
        preset = arg;
        break;
      }
    }

    // Handle file attachment
    if (message.attachments.size > 0) {
      const attachment = message.attachments.first();
      
      if (!attachment.name.endsWith('.lua')) {
        return message.reply('❌ Please upload a `.lua` file!');
      }

      const loadingMsg = await message.reply(`⏳ Processing **${attachment.name}** for Roblox with preset **${preset}**...`);

      try {
        const luaCode = await downloadFile(attachment.url);
        const obfuscatedCode = await obfuscateForRoblox(luaCode, preset);

        const buffer = Buffer.from(obfuscatedCode, 'utf-8');
        const file = new AttachmentBuilder(buffer, { 
          name: `roblox_obfuscated_${attachment.name}` 
        });

        await loadingMsg.edit({
          content: `✅ **${attachment.name}** obfuscated for Roblox! (Preset: **${preset}**, LuaVersion: **LuaU**)`,
          files: [file]
        });
      } catch (error) {
        await loadingMsg.edit(`❌ Error: ${error.message}\n\n💡 **Tip:** If using LuaU-specific syntax (type annotations, etc.), try removing them first as LuaU support is not fully finished.`);
      }
      return;
    }

    // Handle code block
    const codeMatch = content.match(/```(?:lua)?\n?([\s\S]+?)```/);
    
    if (!codeMatch) {
      return message.reply(
        '❌ Please provide code in a code block or attach a `.lua` file:\n' +
        '```\n!obfuscate Medium\n\\`\\`\\`lua\nprint("Hello Roblox!")\n\\`\\`\\`\n```'
      );
    }

    const luaCode = codeMatch[1].trim();
    const loadingMsg = await message.reply(`⏳ Obfuscating for Roblox with preset **${preset}**...`);

    try {
      const obfuscatedCode = await obfuscateForRoblox(luaCode, preset);

      if (obfuscatedCode.length > 1900) {
        const buffer = Buffer.from(obfuscatedCode, 'utf-8');
        const attachment = new AttachmentBuilder(buffer, { 
          name: `roblox_obfuscated_${preset.toLowerCase()}.lua` 
        });

        await loadingMsg.edit({
          content: `✅ Obfuscation complete for Roblox! (Preset: **${preset}**, LuaVersion: **LuaU**)`,
          files: [attachment]
        });
      } else {
        await loadingMsg.edit(
          `✅ Obfuscation complete for Roblox! (Preset: **${preset}**, LuaVersion: **LuaU**)\n\`\`\`lua\n${obfuscatedCode}\n\`\`\``
        );
      }
    } catch (error) {
      await loadingMsg.edit(`❌ Error: ${error.message}\n\n💡 **Tip:** LuaU support is not fully finished. Try simpler presets like Minify or Weak.`);
    }
  }

  // Command: !presets
  if (content === '!presets') {
    const embed = new EmbedBuilder()
      .setTitle('🎮 Prometheus Presets for Roblox')
      .setColor('#00A2FF')
      .setDescription('⚠️ **Note:** LuaU support is not fully finished yet!')
      .addFields(
        { name: '📋 Minify', value: 'Only minification, safest option', inline: false },
        { name: '🔓 Weak', value: 'Basic obfuscation - safe for most Roblox scripts', inline: false },
        { name: '⚖️ Medium', value: 'Balanced obfuscation - **recommended**', inline: false },
        { name: '🔒 Strong', value: 'Maximum obfuscation - test thoroughly!', inline: false }
      )
      .setFooter({ text: 'All presets use LuaVersion = "LuaU"' });

    await message.reply({ embeds: [embed] });
  }

  // Command: !help
  if (content === '!help') {
    const embed = new EmbedBuilder()
      .setTitle('🎮 Prometheus Roblox Obfuscator')
      .setColor('#00A2FF')
      .setDescription('Obfuscate your Roblox Lua scripts!')
      .addFields(
        { 
          name: '📝 !obfuscate [preset]', 
          value: 'Obfuscate code in a code block\n`!obfuscate Medium ```lua print("Hi") ``` `', 
          inline: false 
        },
        { 
          name: '📎 !obfuscate [preset] + file', 
          value: 'Upload a .lua file with the command', 
          inline: false 
        },
        { 
          name: '📋 !presets', 
          value: 'Show available presets', 
          inline: false 
        }
      )
      .addFields({
        name: '⚠️ Important Note',
        value: 'LuaU support is **not fully finished** yet. If you encounter errors:\n• Try simpler presets (Minify, Weak)\n• Remove LuaU-specific syntax (type annotations)\n• Test the obfuscated code in Roblox Studio',
        inline: false
      })
      .setTimestamp();

    await message.reply({ embeds: [embed] });
  }
});

client.on('error', console.error);
process.on('unhandledRejection', console.error);

client.login(process.env.DISCORD_TOKEN);
