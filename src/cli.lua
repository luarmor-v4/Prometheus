-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- cli.lua (OPTIMIZED VERSION)
-- This script contains the Code for the Prometheus CLI
-- Modified with better error handling, validation, and Roblox support

-- ============================================================
-- BAGIAN 1: PACKAGE PATH SETUP
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
-- BAGIAN 2: VERSION & CONSTANTS
-- ============================================================
local CLI_VERSION = "1.1.0-optimized"
local MAX_FILE_SIZE = 10 * 1024 * 1024  -- 10MB max input file
local VALID_LUA_VERSIONS = { Lua51 = true, LuaU = true }

-- ============================================================
-- BAGIAN 3: UTILITY FUNCTIONS (IMPROVED)
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

-- String split function
string.split = function(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

-- Read file content safely
local function read_file(file)
    local f = io.open(file, "rb")
    if not f then return nil, "Cannot open file" end
    local content = f:read("*all")
    f:close()
    return content
end

-- Write file content safely
local function write_file(file, content)
    local f, err = io.open(file, "w")
    if not f then return false, err end
    local success, write_err = pcall(function()
        f:write(content)
    end)
    f:close()
    if not success then return false, write_err end
    return true
end

-- Safe table print for debugging
local function table_to_string(t, indent)
    indent = indent or 0
    local result = "{\n"
    for k, v in pairs(t) do
        local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
        local value
        if type(v) == "table" then
            value = table_to_string(v, indent + 2)
        elseif type(v) == "string" then
            value = '"' .. v .. '"'
        else
            value = tostring(v)
        end
        result = result .. string.rep(" ", indent + 2) .. key .. " = " .. value .. ",\n"
    end
    return result .. string.rep(" ", indent) .. "}"
end

-- ============================================================
-- BAGIAN 4: HELP & USAGE
-- ============================================================
local function print_help()
    local help = [[
🔥 Prometheus Lua Obfuscator - CLI v]] .. CLI_VERSION .. [[


USAGE:
    lua cli.lua [OPTIONS] <input_file>

OPTIONS:
    --preset, --p <name>     Use a preset configuration
                             Available: Minify, Weak, Medium, Strong
                             Roblox: RobloxWeak, RobloxMedium, RobloxStrong
    
    --config, --c <file>     Use a custom configuration file
    
    --out, --o <file>        Output file path
                             Default: <input>.obfuscated.lua
    
    --Lua51                  Force Lua 5.1 output
    --LuaU                   Force LuaU (Roblox) output
    
    --pretty                 Pretty print output (readable)
    --nocolors               Disable colored output
    --saveerrors             Save errors to .error.txt file
    --validate               Validate config without processing
    --verbose                Show detailed processing info
    --quiet                  Suppress all output except errors
    
    --help, -h               Show this help message
    --version, -v            Show version info

EXAMPLES:
    lua cli.lua --preset Medium script.lua
    lua cli.lua --preset RobloxMedium --out secure.lua game.lua
    lua cli.lua --config myconfig.lua --LuaU script.lua
    lua cli.lua --preset Strong --pretty debug.lua

ROBLOX USERS:
    Use --LuaU flag or RobloxWeak/RobloxMedium/RobloxStrong presets
    Note: LuaU support is not fully finished yet!

For more info: https://github.com/levno-710/Prometheus
]]
    print(help)
end

local function print_version()
    print("Prometheus CLI v" .. CLI_VERSION)
    print("Prometheus Core v" .. (Prometheus.Version or "unknown"))
end

-- ============================================================
-- BAGIAN 5: ROBLOX OPTIMIZED PRESETS (NEW!)
-- ============================================================
local RobloxPresets = {
    -- Roblox Weak - Safest option
    RobloxWeak = {
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
    
    -- Roblox Medium - Balanced (Recommended)
    RobloxMedium = {
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
    
    -- Roblox Strong - Maximum protection (test thoroughly!)
    RobloxStrong = {
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
                    Treshold = 0.5;  -- Lower than original Strong!
                };
            };
            {
                Name = "ProxifyLocals";
                Settings = {
                    Treshold = 0.7;  -- Lower than original Strong!
                };
            };
            {
                Name = "WrapInFunction";
                Settings = {};
            };
            -- NOTE: Only 1 WrapInFunction, not 3!
            -- NOTE: No Vmify - causes issues with Roblox
        };
    };
    
    -- Roblox Safe Strong - Extra safe version
    RobloxSafeStrong = {
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
}

-- Register Roblox presets
for name, preset in pairs(RobloxPresets) do
    Prometheus.Presets[name] = preset
end

-- ============================================================
-- BAGIAN 6: CONFIG VALIDATION (NEW!)
-- ============================================================
local function validate_config(config)
    local warnings = {}
    local errors = {}
    
    -- Check if config is a table
    if type(config) ~= "table" then
        table.insert(errors, "Config must be a table")
        return false, errors, warnings
    end
    
    -- Validate LuaVersion
    if config.LuaVersion and not VALID_LUA_VERSIONS[config.LuaVersion] then
        table.insert(errors, string.format("Invalid LuaVersion: %s (use Lua51 or LuaU)", tostring(config.LuaVersion)))
    end
    
    -- Validate Steps
    if config.Steps then
        if type(config.Steps) ~= "table" then
            table.insert(errors, "Steps must be a table/array")
        else
            local wrapCount = 0
            local hasVmify = false
            
            for i, step in ipairs(config.Steps) do
                -- Check step structure
                if type(step) ~= "table" then
                    table.insert(errors, string.format("Step %d must be a table", i))
                elseif not step.Name then
                    table.insert(errors, string.format("Step %d missing 'Name' field", i))
                else
                    -- Count WrapInFunction
                    if step.Name == "WrapInFunction" then
                        wrapCount = wrapCount + 1
                    end
                    
                    -- Check Vmify
                    if step.Name == "Vmify" then
                        hasVmify = true
                    end
                    
                    -- Validate thresholds
                    if step.Settings then
                        if step.Settings.Treshold then
                            local t = step.Settings.Treshold
                            if type(t) ~= "number" or t < 0 or t > 1 then
                                table.insert(warnings, string.format("Step %d (%s): Treshold should be between 0 and 1", i, step.Name))
                            end
                            
                            -- Specific warnings
                            if step.Name == "SplitStrings" and t > 0.8 then
                                table.insert(warnings, string.format("Step %d (SplitStrings): Treshold > 0.8 may cause errors!", i))
                            end
                            
                            if step.Name == "ProxifyLocals" and t > 0.9 then
                                table.insert(warnings, string.format("Step %d (ProxifyLocals): Treshold > 0.9 may cause 'attempt to index nil' errors!", i))
                            end
                        end
                        
                        if step.Settings.LocalWrapperTreshold then
                            local t = step.Settings.LocalWrapperTreshold
                            if type(t) ~= "number" or t < 0 or t > 1 then
                                table.insert(warnings, string.format("Step %d (%s): LocalWrapperTreshold should be between 0 and 1", i, step.Name))
                            end
                        end
                    end
                end
            end
            
            -- Warn about multiple WrapInFunction
            if wrapCount > 1 then
                table.insert(warnings, string.format("Multiple WrapInFunction steps (%d) detected! This may cause stack overflow.", wrapCount))
            end
            
            if wrapCount > 2 then
                table.insert(errors, "Too many WrapInFunction steps (max 2 recommended)")
            end
            
            -- Warn about Vmify
            if hasVmify then
                table.insert(warnings, "Vmify step detected: This significantly increases output size and may cause issues with some scripts")
            end
            
            -- Warn about Vmify + LuaU
            if hasVmify and config.LuaVersion == "LuaU" then
                table.insert(warnings, "Vmify with LuaU: May cause compatibility issues with Roblox!")
            end
        end
    end
    
    return #errors == 0, errors, warnings
end

-- ============================================================
-- BAGIAN 7: CLI VARIABLES
-- ============================================================
local config;
local sourceFile;
local outFile;
local luaVersion;
local prettyPrint;
local validateOnly = false;
local verbose = false;
local quiet = false;

Prometheus.colors.enabled = true;

-- ============================================================
-- BAGIAN 8: ARGUMENT PARSING (IMPROVED)
-- ============================================================
local function parse_arguments()
    local i = 1
    while i <= #arg do
        local curr = arg[i]
        
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
        
        if curr:sub(1, 2) == "--" then
            -- Preset
            if curr == "--preset" or curr == "--p" then
                if config then
                    Prometheus.Logger:warn("The config was set multiple times")
                end

                i = i + 1
                if not arg[i] then
                    Prometheus.Logger:error("--preset requires a preset name")
                end
                
                local preset = Prometheus.Presets[arg[i]]
                if not preset then
                    -- Show available presets
                    local available = {}
                    for name, _ in pairs(Prometheus.Presets) do
                        table.insert(available, name)
                    end
                    table.sort(available)
                    Prometheus.Logger:error(string.format(
                        "Preset \"%s\" not found!\nAvailable presets: %s", 
                        tostring(arg[i]),
                        table.concat(available, ", ")
                    ))
                end

                config = preset
                
            -- Config file
            elseif curr == "--config" or curr == "--c" then
                if config then
                    Prometheus.Logger:warn("The config was set multiple times")
                end
                
                i = i + 1
                if not arg[i] then
                    Prometheus.Logger:error("--config requires a filename")
                end
                
                local filename = tostring(arg[i])
                if not file_exists(filename) then
                    Prometheus.Logger:error(string.format("Config file \"%s\" not found!", filename))
                end

                local content, read_err = read_file(filename)
                if not content then
                    Prometheus.Logger:error(string.format("Cannot read config file: %s", read_err))
                end
                
                -- Load and sandbox
                local func, load_err = loadstring(content)
                if not func then
                    Prometheus.Logger:error(string.format("Config syntax error: %s", load_err))
                end
                
                setfenv(func, {})
                
                local success, result = pcall(func)
                if not success then
                    Prometheus.Logger:error(string.format("Config execution error: %s", result))
                end
                
                config = result
                
            -- Output file
            elseif curr == "--out" or curr == "--o" then
                i = i + 1
                if not arg[i] then
                    Prometheus.Logger:error("--out requires a filename")
                end
                if outFile then
                    Prometheus.Logger:warn("Output file specified multiple times!")
                end
                outFile = arg[i]
                
            -- Other flags
            elseif curr == "--nocolors" then
                Prometheus.colors.enabled = false
                
            elseif curr == "--Lua51" then
                luaVersion = "Lua51"
                
            elseif curr == "--LuaU" then
                luaVersion = "LuaU"
                
            elseif curr == "--pretty" then
                prettyPrint = true
                
            elseif curr == "--validate" then
                validateOnly = true
                
            elseif curr == "--verbose" then
                verbose = true
                Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Debug
                
            elseif curr == "--quiet" then
                quiet = true
                Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
                
            elseif curr == "--saveerrors" then
                Prometheus.Logger.errorCallback = function(...)
                    if not quiet then
                        print(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. ..., "red"))
                    end
                    
                    local args = {...}
                    local message = table.concat(args, " ")
                    
                    local fileName = sourceFile and 
                        (sourceFile:sub(-4) == ".lua" and sourceFile:sub(0, -5) .. ".error.txt" or sourceFile .. ".error.txt")
                        or "prometheus.error.txt"
                    
                    write_file(fileName, message)
                    os.exit(1)
                end
                
            else
                Prometheus.Logger:warn(string.format("Unknown option \"%s\" - ignored", curr))
            end
        else
            -- Source file (positional argument)
            if sourceFile then
                Prometheus.Logger:error(string.format("Unexpected argument \"%s\" (source file already set to \"%s\")", arg[i], sourceFile))
            end
            sourceFile = tostring(arg[i])
        end
        
        i = i + 1
    end
end

-- ============================================================
-- BAGIAN 9: MAIN EXECUTION
-- ============================================================
local function main()
    -- Parse arguments
    parse_arguments()
    
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
        Prometheus.Logger:error(string.format("Input file \"%s\" not found!", sourceFile))
    end
    
    -- Check file size
    local size = file_size(sourceFile)
    if size > MAX_FILE_SIZE then
        Prometheus.Logger:error(string.format(
            "Input file too large! (%d bytes, max %d bytes)", 
            size, MAX_FILE_SIZE
        ))
    end
    
    if verbose then
        Prometheus.Logger:info(string.format("Input file: %s (%d bytes)", sourceFile, size))
    end
    
    -- Default config
    if not config then
        if not quiet then
            Prometheus.Logger:warn("No config specified, using Minify preset")
        end
        config = Prometheus.Presets.Minify
    end
    
    -- Override config options
    if luaVersion then
        config.LuaVersion = luaVersion
    end
    
    if prettyPrint ~= nil then
        config.PrettyPrint = prettyPrint
    end
    
    -- Validate config
    local valid, errors, warnings = validate_config(config)
    
    -- Show warnings
    for _, warning in ipairs(warnings) do
        Prometheus.Logger:warn(warning)
    end
    
    -- Show errors
    if not valid then
        for _, err in ipairs(errors) do
            Prometheus.Logger:error(err)
        end
        os.exit(1)
    end
    
    -- Validate only mode
    if validateOnly then
        if not quiet then
            Prometheus.Logger:info("Config validation passed!")
            if verbose then
                Prometheus.Logger:info("Config: " .. table_to_string(config))
            end
        end
        os.exit(0)
    end
    
    -- Set output file
    if not outFile then
        if sourceFile:sub(-4) == ".lua" then
            outFile = sourceFile:sub(0, -5) .. ".obfuscated.lua"
        else
            outFile = sourceFile .. ".obfuscated.lua"
        end
    end
    
    -- Read source file
    local source, read_err = read_file(sourceFile)
    if not source then
        Prometheus.Logger:error(string.format("Cannot read source file: %s", read_err))
    end
    
    if verbose then
        Prometheus.Logger:info(string.format("Source size: %d bytes", #source))
        Prometheus.Logger:info(string.format("LuaVersion: %s", config.LuaVersion or "Lua51"))
        Prometheus.Logger:info(string.format("Steps: %d", config.Steps and #config.Steps or 0))
    end
    
    -- Create pipeline
    local pipeline_success, pipeline = pcall(function()
        return Prometheus.Pipeline:fromConfig(config)
    end)
    
    if not pipeline_success then
        Prometheus.Logger:error(string.format("Failed to create pipeline: %s", tostring(pipeline)))
    end
    
    -- Apply obfuscation
    if not quiet then
        Prometheus.Logger:info("Starting obfuscation...")
    end
    
    local start_time = os.clock()
    
    local apply_success, out = pcall(function()
        return pipeline:apply(source, sourceFile)
    end)
    
    local elapsed = os.clock() - start_time
    
    if not apply_success then
        Prometheus.Logger:error(string.format("Obfuscation failed: %s", tostring(out)))
    end
    
    -- Write output
    if not quiet then
        Prometheus.Logger:info(string.format("Writing output to \"%s\"", outFile))
    end
    
    local write_success, write_err = write_file(outFile, out)
    if not write_success then
        Prometheus.Logger:error(string.format("Cannot write output file: %s", write_err))
    end
    
    -- Summary
    if not quiet then
        Prometheus.Logger:info(string.format(
            "✅ Done! (%.2fs, %d → %d bytes, %.1fx)", 
            elapsed,
            #source, 
            #out,
            #out / #source
        ))
        
        -- Warnings for large output
        if #out / #source > 10 then
            Prometheus.Logger:warn("Output is >10x larger than input! Consider using lighter obfuscation.")
        end
    end
end

-- ============================================================
-- BAGIAN 10: RUN WITH ERROR HANDLING
-- ============================================================
local success, err = pcall(main)
if not success then
    Prometheus.Logger:error(string.format("Unexpected error: %s", tostring(err)))
    os.exit(1)
end
