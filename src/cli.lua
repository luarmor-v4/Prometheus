-- ============================================================
-- Prometheus Lua Obfuscator - CLI
-- OPTIMIZED VERSION with Roblox Support
-- 
-- Original by Levno_710
-- Modified for better error handling and Roblox presets
-- ============================================================

-- ============================================================
-- PACKAGE PATH SETUP
-- ============================================================
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*[/%\\])")
end
package.path = script_path() .. "?.lua;" .. package.path;

---@diagnostic disable-next-line: different-requires
local Prometheus = require("prometheus");
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Info;

-- ============================================================
-- VERSION
-- ============================================================
local CLI_VERSION = "1.1.0-optimized"

-- ============================================================
-- ROBLOX OPTIMIZED PRESETS
-- ============================================================
Prometheus.Presets.RobloxMinify = {
    LuaVersion = "LuaU";
    VarNamePrefix = "";
    NameGenerator = "MangledShuffled";
    PrettyPrint = false;
    Seed = 0;
    Steps = {};
};

Prometheus.Presets.RobloxWeak = {
    LuaVersion = "LuaU";
    VarNamePrefix = "";
    NameGenerator = "MangledShuffled";
    PrettyPrint = false;
    Seed = 0;
    Steps = {
        {
            Name = "ConstantArray";
            Settings = {
                Treshold = 0.5;
                StringsOnly = true;
                Shuffle = true;
                Rotate = false;
            };
        };
    };
};

Prometheus.Presets.RobloxMedium = {
    LuaVersion = "LuaU";
    VarNamePrefix = "";
    NameGenerator = "MangledShuffled";
    PrettyPrint = false;
    Seed = 0;
    Steps = {
        {
            Name = "ConstantArray";
            Settings = {
                Treshold = 0.8;
                StringsOnly = false;
                Shuffle = true;
                Rotate = true;
                LocalWrapperTreshold = 0.5;
            };
        };
        {
            Name = "EncryptStrings";
            Settings = {
                Treshold = 0.8;
            };
        };
        {
            Name = "WrapInFunction";
            Settings = {};
        };
    };
};

Prometheus.Presets.RobloxStrong = {
    LuaVersion = "LuaU";
    VarNamePrefix = "";
    NameGenerator = "MangledShuffled";
    PrettyPrint = false;
    Seed = 0;
    Steps = {
        {
            Name = "ConstantArray";
            Settings = {
                Treshold = 0.9;
                StringsOnly = false;
                Shuffle = true;
                Rotate = true;
                LocalWrapperTreshold = 0.7;
            };
        };
        {
            Name = "EncryptStrings";
            Settings = {
                Treshold = 0.9;
            };
        };
        {
            Name = "SplitStrings";
            Settings = {
                Treshold = 0.5;  -- Lower for stability
            };
        };
        {
            Name = "ProxifyLocals";
            Settings = {
                Treshold = 0.7;  -- Lower for stability
            };
        };
        {
            Name = "WrapInFunction";
            Settings = {};
        };
        -- NOTE: No Vmify - causes Roblox issues
        -- NOTE: Only 1x WrapInFunction - prevents stack overflow
    };
};

Prometheus.Presets.RobloxSafeStrong = {
    LuaVersion = "LuaU";
    VarNamePrefix = "";
    NameGenerator = "MangledShuffled";
    PrettyPrint = false;
    Seed = 0;
    Steps = {
        {
            Name = "ConstantArray";
            Settings = {
                Treshold = 0.8;
                StringsOnly = false;
                Shuffle = true;
                Rotate = true;
                LocalWrapperTreshold = 0.6;
            };
        };
        {
            Name = "EncryptStrings";
            Settings = {
                Treshold = 0.8;
            };
        };
        {
            Name = "ProxifyLocals";
            Settings = {
                Treshold = 0.5;
            };
        };
        {
            Name = "WrapInFunction";
            Settings = {};
        };
    };
};

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

-- Check if file exists
local function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

-- Get file size
local function file_size(file)
    local f = io.open(file, "rb")
    if not f then return 0 end
    local size = f:seek("end")
    f:close()
    return size
end

-- String split
string.split = function(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

-- Read file content
local function read_file(file)
    local f = io.open(file, "rb")
    if not f then return nil, "Cannot open file" end
    local content = f:read("*all")
    f:close()
    return content
end

-- Write file content
local function write_file(file, content)
    local f, err = io.open(file, "w")
    if not f then return false, err end
    local success, write_err = pcall(function()
        f:write(content)
    end)
    f:close()
    return success, write_err
end

-- ============================================================
-- HELP FUNCTION
-- ============================================================
local function print_help()
    print([[

🔥 Prometheus Lua Obfuscator - CLI v]] .. CLI_VERSION .. [[


USAGE:
    lua cli.lua [OPTIONS] <input_file>

OPTIONS:
    --preset, --p <name>     Use a preset configuration
    --config, --c <file>     Use a custom configuration file
    --out, --o <file>        Output file path (default: <input>.obfuscated.lua)
    --Lua51                  Force Lua 5.1 output
    --LuaU                   Force LuaU (Roblox) output
    --pretty                 Pretty print output
    --nocolors               Disable colored output
    --saveerrors             Save errors to .error.txt file
    --help, -h               Show this help message
    --version, -v            Show version info
    --list-presets           List all available presets

STANDARD PRESETS:
    Minify                   Only minification, no obfuscation
    Weak                     Basic obfuscation (fast, low protection)
    Medium                   Balanced obfuscation (recommended)
    Strong                   Maximum obfuscation (may cause errors)

ROBLOX PRESETS:
    RobloxMinify             Minify for Roblox
    RobloxWeak               Basic obfuscation for Roblox
    RobloxMedium             Balanced obfuscation for Roblox (recommended)
    RobloxStrong             Strong obfuscation for Roblox
    RobloxSafeStrong         Safe strong obfuscation for Roblox

EXAMPLES:
    lua cli.lua --preset Medium script.lua
    lua cli.lua --preset RobloxMedium --out secure.lua game.lua
    lua cli.lua --config myconfig.lua --LuaU script.lua
    lua cli.lua --preset Strong --pretty debug.lua
    lua cli.lua --list-presets

NOTES:
    - LuaU support is not fully finished yet!
    - Always test obfuscated code before deploying
    - For Roblox, use RobloxMedium preset (recommended)

For more info: https://github.com/prometheus-lua/Prometheus

]])
end

-- ============================================================
-- VERSION FUNCTION
-- ============================================================
local function print_version()
    print("Prometheus CLI v" .. CLI_VERSION)
    print("Prometheus Core v" .. (Prometheus.Version or "unknown"))
end

-- ============================================================
-- LIST PRESETS FUNCTION
-- ============================================================
local function list_presets()
    print("\n🔥 Available Presets:\n")
    
    print("STANDARD PRESETS:")
    print("  Minify           - Only minification, no obfuscation")
    print("  Weak             - Basic obfuscation")
    print("  Medium           - Balanced obfuscation (recommended)")
    print("  Strong           - Maximum obfuscation")
    
    print("\nROBLOX PRESETS (LuaU):")
    print("  RobloxMinify     - Minify for Roblox")
    print("  RobloxWeak       - Basic obfuscation for Roblox")
    print("  RobloxMedium     - Balanced for Roblox (recommended)")
    print("  RobloxStrong     - Strong obfuscation for Roblox")
    print("  RobloxSafeStrong - Safe strong for Roblox")
    
    print("\nAll available presets:")
    local presets = {}
    for name, _ in pairs(Prometheus.Presets) do
        table.insert(presets, name)
    end
    table.sort(presets)
    for _, name in ipairs(presets) do
        print("  - " .. name)
    end
    print("")
end

-- ============================================================
-- CONFIG VALIDATION
-- ============================================================
local function validate_config(config)
    if type(config) ~= "table" then
        Prometheus.Logger:error("Config must be a table")
        return false
    end
    
    -- Validate LuaVersion
    local valid_versions = { Lua51 = true, LuaU = true }
    if config.LuaVersion and not valid_versions[config.LuaVersion] then
        Prometheus.Logger:warn("Invalid LuaVersion: " .. tostring(config.LuaVersion) .. " (using default)")
    end
    
    -- Validate Steps
    if config.Steps and type(config.Steps) == "table" then
        local wrap_count = 0
        local has_vmify = false
        
        for i, step in ipairs(config.Steps) do
            if type(step) ~= "table" then
                Prometheus.Logger:warn("Step " .. i .. " is not a table")
            elseif not step.Name then
                Prometheus.Logger:warn("Step " .. i .. " is missing 'Name' property")
            else
                -- Count WrapInFunction
                if step.Name == "WrapInFunction" then
                    wrap_count = wrap_count + 1
                end
                
                -- Check Vmify
                if step.Name == "Vmify" then
                    has_vmify = true
                end
                
                -- Validate thresholds
                if step.Settings then
                    local t = step.Settings.Treshold
                    if t ~= nil then
                        if type(t) ~= "number" or t < 0 or t > 1 then
                            Prometheus.Logger:warn("Step " .. i .. " (" .. step.Name .. "): Treshold should be between 0 and 1")
                        end
                        
                        -- Specific warnings
                        if step.Name == "SplitStrings" and t > 0.8 then
                            Prometheus.Logger:warn("SplitStrings Treshold > 0.8 may cause errors!")
                        end
                        
                        if step.Name == "ProxifyLocals" and t > 0.9 then
                            Prometheus.Logger:warn("ProxifyLocals Treshold > 0.9 may cause 'attempt to index nil' errors!")
                        end
                    end
                end
            end
        end
        
        -- Warn about multiple WrapInFunction
        if wrap_count > 1 then
            Prometheus.Logger:warn("Multiple WrapInFunction steps (" .. wrap_count .. ") may cause stack overflow!")
        end
        
        if wrap_count > 2 then
            Prometheus.Logger:error("Too many WrapInFunction steps! Maximum recommended: 2")
            return false
        end
        
        -- Warn about Vmify
        if has_vmify then
            Prometheus.Logger:warn("Vmify step significantly increases output size")
        end
        
        -- Warn about Vmify + LuaU
        if has_vmify and config.LuaVersion == "LuaU" then
            Prometheus.Logger:warn("Vmify with LuaU may cause Roblox compatibility issues!")
        end
    end
    
    return true
end

-- ============================================================
-- CLI VARIABLES
-- ============================================================
local config;
local sourceFile;
local outFile;
local luaVersion;
local prettyPrint;

Prometheus.colors.enabled = true;

-- ============================================================
-- ARGUMENT PARSING
-- ============================================================
local i = 1;
while i <= #arg do
    local curr = arg[i];
    
    -- Help flags
    if curr == "--help" or curr == "-h" then
        print_help()
        os.exit(0)
    end
    
    -- Version flags
    if curr == "--version" or curr == "-v" then
        print_version()
        os.exit(0)
    end
    
    -- List presets
    if curr == "--list-presets" then
        list_presets()
        os.exit(0)
    end
    
    if curr:sub(1, 2) == "--" then
        if curr == "--preset" or curr == "--p" then
            if config then
                Prometheus.Logger:warn("The config was set multiple times");
            end

            i = i + 1;
            if not arg[i] then
                Prometheus.Logger:error("--preset requires a preset name. Use --list-presets to see available presets.");
            end
            
            local preset = Prometheus.Presets[arg[i]];
            if not preset then
                -- List available presets
                local available = {}
                for name, _ in pairs(Prometheus.Presets) do
                    table.insert(available, name)
                end
                table.sort(available)
                Prometheus.Logger:error(string.format(
                    "Preset \"%s\" not found!\nAvailable presets: %s\n\nUse --list-presets for details.",
                    tostring(arg[i]),
                    table.concat(available, ", ")
                ));
            end

            config = preset;
            
        elseif curr == "--config" or curr == "--c" then
            if config then
                Prometheus.Logger:warn("The config was set multiple times");
            end
            
            i = i + 1;
            if not arg[i] then
                Prometheus.Logger:error("--config requires a filename");
            end
            
            local filename = tostring(arg[i]);
            if not file_exists(filename) then
                Prometheus.Logger:error(string.format("Config file \"%s\" not found!", filename));
            end

            local content, read_err = read_file(filename);
            if not content then
                Prometheus.Logger:error(string.format("Cannot read config file: %s", read_err or "unknown error"));
            end
            
            -- Load config with error handling
            local func, load_err = loadstring(content);
            if not func then
                Prometheus.Logger:error(string.format("Config syntax error: %s", load_err));
            end
            
            -- Sandboxing
            setfenv(func, {});
            
            local success, result = pcall(func);
            if not success then
                Prometheus.Logger:error(string.format("Config execution error: %s", result));
            end
            
            config = result;
            
        elseif curr == "--out" or curr == "--o" then
            i = i + 1;
            if not arg[i] then
                Prometheus.Logger:error("--out requires a filename");
            end
            if outFile then
                Prometheus.Logger:warn("Output file specified multiple times!");
            end
            outFile = arg[i];
            
        elseif curr == "--nocolors" then
            Prometheus.colors.enabled = false;
            
        elseif curr == "--Lua51" then
            luaVersion = "Lua51";
            
        elseif curr == "--LuaU" then
            luaVersion = "LuaU";
            
        elseif curr == "--pretty" then
            prettyPrint = true;
            
        elseif curr == "--saveerrors" then
            Prometheus.Logger.errorCallback = function(...)
                print(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. ..., "red"))
                
                local args = {...};
                local message = table.concat(args, " ");
                
                local fileName = sourceFile and 
                    (sourceFile:sub(-4) == ".lua" and sourceFile:sub(0, -5) .. ".error.txt" or sourceFile .. ".error.txt")
                    or "prometheus.error.txt";
                
                write_file(fileName, message);
                os.exit(1);
            end;
        else
            Prometheus.Logger:warn(string.format("Unknown option \"%s\" - ignored", curr));
        end
    else
        if sourceFile then
            Prometheus.Logger:error(string.format("Unexpected argument \"%s\" (source file already set to \"%s\")", arg[i], sourceFile));
        end
        sourceFile = tostring(arg[i]);
    end
    i = i + 1;
end

-- ============================================================
-- VALIDATION
-- ============================================================

-- Check source file
if not sourceFile then
    if #arg == 0 then
        print_help()
        os.exit(0)
    end
    Prometheus.Logger:error("No input file specified! Use --help for usage info.")
end

-- Check if source file exists
if not file_exists(sourceFile) then
    Prometheus.Logger:error(string.format("Input file \"%s\" not found!", sourceFile));
end

-- Check file size (max 10MB)
local size = file_size(sourceFile)
local MAX_SIZE = 10 * 1024 * 1024
if size > MAX_SIZE then
    Prometheus.Logger:error(string.format("Input file too large! (%d bytes, max %d bytes)", size, MAX_SIZE))
end

-- Default config
if not config then
    Prometheus.Logger:warn("No config specified, using Minify preset");
    config = Prometheus.Presets.Minify;
end

-- Override config options
config.LuaVersion = luaVersion or config.LuaVersion;
config.PrettyPrint = prettyPrint ~= nil and prettyPrint or config.PrettyPrint;

-- Validate config
if not validate_config(config) then
    os.exit(1)
end

-- Set output file
if not outFile then
    if sourceFile:sub(-4) == ".lua" then
        outFile = sourceFile:sub(0, -5) .. ".obfuscated.lua";
    else
        outFile = sourceFile .. ".obfuscated.lua";
    end
end

-- ============================================================
-- EXECUTE OBFUSCATION
-- ============================================================

-- Read source file
local source, read_err = read_file(sourceFile);
if not source then
    Prometheus.Logger:error(string.format("Cannot read source file: %s", read_err or "unknown error"));
end

Prometheus.Logger:info(string.format("Input: %s (%d bytes)", sourceFile, #source));
Prometheus.Logger:info(string.format("LuaVersion: %s", config.LuaVersion or "Lua51"));
Prometheus.Logger:info(string.format("Steps: %d", config.Steps and #config.Steps or 0));

-- Create pipeline with error handling
local pipeline_ok, pipeline = pcall(function()
    return Prometheus.Pipeline:fromConfig(config)
end)

if not pipeline_ok then
    Prometheus.Logger:error(string.format("Failed to create pipeline: %s", tostring(pipeline)))
end

-- Apply obfuscation with error handling
Prometheus.Logger:info("Starting obfuscation...");

local start_time = os.clock()

local apply_ok, out = pcall(function()
    return pipeline:apply(source, sourceFile)
end)

local elapsed = os.clock() - start_time

if not apply_ok then
    Prometheus.Logger:error(string.format("Obfuscation failed: %s", tostring(out)))
end

-- ============================================================
-- WRITE OUTPUT
-- ============================================================
Prometheus.Logger:info(string.format("Writing output to \"%s\"", outFile));

local write_ok, write_err = write_file(outFile, out);
if not write_ok then
    Prometheus.Logger:error(string.format("Cannot write output file: %s", write_err or "unknown error"));
end

-- ============================================================
-- SUMMARY
-- ============================================================
local ratio = #out / #source

Prometheus.Logger:info(string.format(
    "✅ Done! (%.2fs, %d → %d bytes, %.2fx)",
    elapsed,
    #source,
    #out,
    ratio
));

-- Warnings
if ratio > 10 then
    Prometheus.Logger:warn("Output is >10x larger than input! Consider using lighter obfuscation.");
end

if ratio > 20 then
    Prometheus.Logger:warn("Output is extremely large! This may cause performance issues.");
end
