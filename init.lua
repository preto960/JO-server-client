-- this is the first file executed when the application starts
-- we have to load the first modules form here

-- updater
Services = {
    --updater = "http://localhost/api/updater.php", --./updater
    --status = "http://localhost/login.php", --./client_entergame | ./client_topmenu
    --websites = "http://localhost/?subtopic=accountmanagement", --./client_entergame "Forgot password and/or email"
    --createAccount = "http://localhost/clientcreateaccount.php", --./client_entergame -- createAccount.lua
    --getCoinsUrl = "http://localhost/?subtopic=shop&step=terms", --./game_market
    clientAssets = {
        enabled = true,
        repository = "dudantas/tibia-client",
        installSounds = true,
        strictManifestSha256 = true,
        allowRawFallbackHashMismatch = false,
        preferArchive = true,
        installArchiveExtras = true,
        archiveExtraPrefixes = { "bin" },
        installPackagedFiles = true
    }, -- ./client_assets
}

--- Enables or disables the entire server configuration block.
-- Set to `false` to disable all configuration below.
local ENABLE_SERVERS = true

---
-- @module Servers_init
-- Configuration table for all servers used by the system.
--
-- This entire block is conditionally enabled based on ENABLE_SERVERS.
-- When ENABLE_SERVERS == false, everything is ignored/disabled.
--

---
-- Server configuration system for multi-server or multi-world clients.
--
-- This structure allows a single client build to connect to multiple servers
-- without requiring duplicate client folders.
--
-- A server that hosts several worlds, or that provides a separate test environment,
-- can simply define additional entries inside this configuration table.
--
-- Instead of maintaining multiple client installations (one per world/server),
-- the client can switch between servers by selecting the desired configuration entry.
-- This simplifies testing, avoids redundant directories, and centralizes connection settings.
--
-- The ENABLE_SERVERS flag allows the entire configuration block to be enabled or disabled
-- without deleting or commenting out individual entries.
--

Servers_init = {}

if ENABLE_SERVERS then

    ---
    -- List of servers and their configuration parameters.
    -- Each entry defines port, protocol, and authentication options.
    -- @table Servers_init
    --
    Servers_init = {

        -- Local login server
        ---
        -- Configuration for local login server.
        -- @class table
        -- @name local_login
        -- @field port Port used for HTTP connection
        -- @field protocol Protocol identifier used by the application
        -- @field httpLogin Enables HTTP-based login on the server
        -- @field useAuthenticator Enables additional authentication layer
        --
        ["http://127.0.0.1:3000/api/game/login"] = {
            port = 3000,
            protocol = 1316,
            httpLogin = true,
            useAuthenticator = false
        },

        -- Direct login to game server (port 7171 = loginProtocolPort)
        -- This bypasses HTTP login and uses the binary login protocol
        -- Use this if HTTP login causes crashes
        ["127.0.0.1"] = {
            port = 7171,
            protocol = 1316,
            httpLogin = false,
            useAuthenticator = false
        },
    }
end

g_app.setName("OTClient - Redemption");
g_app.setCompactName("otclient");
g_app.setOrganizationName("otcr");

g_app.hasUpdater = function()
    return (Services.updater and Services.updater ~= "" and g_modules.getModule("updater"))
end

-- setup logger
g_logger.setLogFile(g_resources.getWorkDir() .. g_app.getCompactName() .. '.log')
g_logger.info(os.date('== application started at %b %d %Y %X'))
g_logger.info("== operating system: " .. g_platform.getOSName())

-- print first terminal message
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' ..
    g_app.getBuildCommit() .. ') built on ' .. g_app.getBuildDate() .. ' for arch ' ..
    g_app.getBuildArch())

-- setup lua debugger
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
    g_logger.debug("Started LUA debugger.")
else
    g_logger.debug("LUA debugger not started (not launched with VSCode local-lua).")
end

-- add data directory to the search path
if not g_resources.addSearchPath(g_resources.getWorkDir() .. 'data', true) then
    g_logger.fatal('Unable to add data directory to the search path.')
end

-- add modules directory to the search path
if not g_resources.addSearchPath(g_resources.getWorkDir() .. 'modules', true) then
    g_logger.fatal('Unable to add modules directory to the search path.')
end

g_html.addGlobalStyle('/data/styles/html.css')
g_html.addGlobalStyle('/data/styles/custom.css')

-- try to add mods path too
g_resources.addSearchPath(g_resources.getWorkDir() .. 'mods', true)

-- setup directory for saving configurations
g_resources.setupUserWriteDir(('%s/'):format(g_app.getCompactName()))

-- search all packages
g_resources.searchAndAddPackages('/', '.otpkg', true)

-- load settings
g_configs.loadSettings('/config.otml')

g_modules.discoverModules()

-- libraries modules 0-99
g_modules.autoLoadModules(99)
g_modules.ensureModuleLoaded('corelib')
g_modules.ensureModuleLoaded('gamelib')
g_modules.ensureModuleLoaded('modulelib')
g_modules.ensureModuleLoaded("startup")

g_modules.autoLoadModules(999)
g_modules.ensureModuleLoaded('game_shaders') -- pre load

local function loadModules()
    -- client modules 100-499
    g_modules.autoLoadModules(499)
    g_modules.ensureModuleLoaded('client')

    -- game modules 500-999
    g_modules.autoLoadModules(999)
    g_modules.ensureModuleLoaded('game_interface')

    -- mods 1000-9999
    g_modules.autoLoadModules(9999)
    g_modules.ensureModuleLoaded('client_mods')

    local script = '/' .. g_app.getCompactName() .. 'rc.lua'

    if g_resources.fileExists(script) then
        dofile(script)
    end

-- Auto-reload: when files change on disk (e.g. after git pull),
    -- only the modified module is reloaded automatically (~500ms delay)
    g_modules.enableAutoReload()

    -- Safe reload: only reloads custom dev modules, skips core/login/UI modules
    -- that would cause the login screen, footer, or sidebar to reappear
    local SAFE_RELOAD_MODULES = {
        'game_chat_custom',
        'game_inventory_custom',
        'skills_custom',
        'game_healthcircle',
        'game_actionbar',
        'game_notifications',
        'debug_info',
    }
    local SKIP_RELOAD_MODULES = {
        'game_entergame_custom', 'client_bottommenu', 'client_topmenu',
        'game_mainpanel', 'game_interface', 'client', 'corelib', 'gamelib',
        'modulelib', 'startup', 'features', 'things', 'updater',
    }

    local function doSafeReload()
        g_logger.warning("[DevTools] Safe reload: reloading custom modules only...")
        local reloaded = 0
        for _, name in ipairs(SAFE_RELOAD_MODULES) do
            local mod = g_modules.getModule(name)
            if mod and mod:isLoaded() then
                local canReload = false
                pcall(function() canReload = mod:canReload() end)
                if canReload then
                    pcall(function() mod:reload() end)
                    reloaded = reloaded + 1
                    g_logger.warning("[DevTools] Reloaded: " .. name)
                end
            end
        end
        g_logger.warning("[DevTools] Safe reload done. " .. reloaded .. " module(s) reloaded.")
    end

    -- Hotkey: Ctrl+Shift+R
    g_keyboard.bindKeyDown('Ctrl+Shift+R', doSafeReload)

    -- Visible reload button in the game sidebar
    scheduleEvent(function()
        pcall(function()
            modules.client_topmenu.addRightGameToggleButton(
                'devReloadButton',
                'Reload Custom Modules (Ctrl+Shift+R)',
                '/images/options/button_reload',
                doSafeReload,
                true
            )
            g_logger.warning("[DevTools] Reload button added to game sidebar")
        end)
    end, 3000)
end

-- run updater, must use data.zip
if g_app.hasUpdater() then
    g_modules.ensureModuleLoaded("updater")
    return Updater.init(loadModules)
end

loadModules()
