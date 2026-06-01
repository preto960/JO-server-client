-- client_mods.lua - Fix for OTServBR-Global connection crash (v4 - full trace)
-- Problem: STATUS_HEAP_CORRUPTION (0xc0000374) when entering game world
-- Fix: Disable GameSequencedPackets + RSA overflow safety + parameter tracing

local DEBUG_FILE = "crash_debug.log"

local function debugLog(msg)
    local f = io.open(DEBUG_FILE, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
    print("[MOD] " .. msg)
end

local function debugDumpTable(t, prefix)
    prefix = prefix or ""
    if type(t) ~= "table" then
        debugLog(prefix .. tostring(t))
        return
    end
    for k, v in pairs(t) do
        if type(v) == "table" then
            debugLog(prefix .. tostring(k) .. " = {")
            debugDumpTable(v, prefix .. "  ")
            debugLog(prefix .. "}")
        else
            debugLog(prefix .. tostring(k) .. " = " .. tostring(v) .. " (" .. type(v) .. ")")
        end
    end
end

local ORIGINAL_RSA_SIZE = 128

function init()
    local ok, err = pcall(function()
        debugLog("=== client_mods init (FIX v4 - FULL TRACE) ===")

        -- CRITICAL FIX: Disable GameSequencedPackets for OTServBR compat
        local originalSetClientVersion = g_game.setClientVersion
        local versionSet = false

        g_game.setClientVersion = function(version)
            originalSetClientVersion(version)
            if not versionSet and version >= 1290 then
                versionSet = true
                debugLog("Disabling GameSequencedPackets for version " .. version)
                g_game.disableFeature(GameSequencedPackets)
            end
        end

        local originalSetProtocolVersion = g_game.setProtocolVersion
        g_game.setProtocolVersion = function(version)
            originalSetProtocolVersion(version)
            if version >= 1290 then
                debugLog("Disabling GameSequencedPackets on protocol " .. version)
                g_game.disableFeature(GameSequencedPackets)
            end
        end

        -- ===== TRACE: Hook EnterGame.loginSuccess to see raw API data =====
        if EnterGame and EnterGame.loginSuccess then
            local origLoginSuccess = EnterGame.loginSuccess
            EnterGame.loginSuccess = function(requestId, jsonSession, jsonWorlds, jsonCharacters)
                debugLog("===== loginSuccess CALLED =====")
                debugLog("  jsonWorlds raw: " .. tostring(jsonWorlds):sub(1, 500))
                debugLog("  jsonCharacters raw: " .. tostring(jsonCharacters):sub(1, 500))
                debugLog("  jsonSession raw: " .. tostring(jsonSession):sub(1, 500))
                origLoginSuccess(requestId, jsonSession, jsonWorlds, jsonCharacters)
                -- Log the character data AFTER loginSuccess builds it
                if G.characters then
                    debugLog("  G.characters after loginSuccess:")
                    for i, c in ipairs(G.characters) do
                        debugLog("  Character " .. i .. ":")
                        debugLog("    name=" .. tostring(c.name))
                        debugLog("    characterName=" .. tostring(c.characterName))
                        debugLog("    worldName=" .. tostring(c.worldName))
                        debugLog("    worldIp=" .. tostring(c.worldIp))
                        debugLog("    worldHost=" .. tostring(c.worldHost))
                        debugLog("    worldPort=" .. tostring(c.worldPort))
                    end
                end
                debugLog("  G.sessionKey after loginSuccess: " .. tostring(G.sessionKey))
                debugLog("===== loginSuccess DONE =====")
            end
        else
            debugLog("WARNING: EnterGame.loginSuccess not found (" .. tostring(EnterGame) .. ")")
        end

        -- ===== TRACE: Hook onCharacterList to see character data from ProtocolLogin =====
        -- This catches the direct login path (ProtocolLogin)
        if EnterGame and EnterGame.loginWorld then
            -- Check for the local onCharacterList callback
            debugLog("EnterGame module loaded: " .. tostring(EnterGame ~= nil))
        end

        -- ===== TRACE: Hook CharacterList.create to see character data (works for both HTTP and direct login) =====
        if CharacterList and CharacterList.create then
            local origCreate = CharacterList.create
            CharacterList.create = function(characters, account, otui)
                debugLog("===== CharacterList.create CALLED =====")
                debugLog("  Number of characters: " .. #characters)
                for i, c in ipairs(characters) do
                    debugLog("  Character " .. i .. ":")
                    debugLog("    name = " .. tostring(c.name))
                    debugLog("    characterName = " .. tostring(c.characterName))
                    debugLog("    worldName = " .. tostring(c.worldName))
                    debugLog("    worldIp = " .. tostring(c.worldIp))
                    debugLog("    worldHost = " .. tostring(c.worldHost))
                    debugLog("    worldPort = " .. tostring(c.worldPort))
                end
                debugLog("  G.sessionKey = " .. tostring(G.sessionKey))
                debugLog("  G.account = " .. tostring(G.account))
                origCreate(characters, account, otui)
                debugLog("===== CharacterList.create DONE =====")
            end
        else
            debugLog("WARNING: CharacterList.create not found")
        end

        -- ===== TRACE: Hook CharacterList.doLogin =====
        if CharacterList and CharacterList.doLogin then
            local origDoLogin = CharacterList.doLogin
            CharacterList.doLogin = function()
                debugLog("===== CharacterList.doLogin CALLED =====")
                debugLog("  G.sessionKey = " .. tostring(G.sessionKey))
                debugLog("  G.account = " .. tostring(G.account))
                debugLog("  G.authenticatorToken = " .. tostring(G.authenticatorToken))
                if G.characters then
                    for i, c in ipairs(G.characters) do
                        debugLog("  G.characters[" .. i .. "]: name=" .. tostring(c.name) .. " characterName=" .. tostring(c.characterName))
                        debugLog("    worldName=" .. tostring(c.worldName) .. " worldIp=" .. tostring(c.worldIp) .. " worldHost=" .. tostring(c.worldHost) .. " worldPort=" .. tostring(c.worldPort))
                    end
                end
                debugLog("===== CharacterList.doLogin CALLING ORIGINAL =====")
                origDoLogin()
            end
        else
            debugLog("WARNING: CharacterList.doLogin not found")
        end

        -- ===== TRACE: Hook tryLogin (via CharacterList) =====
        -- We can't hook the local tryLogin directly, but we hook loginWorld

        -- Hook loginWorld for debug + RSA safety
        local originalLoginWorld = g_game.loginWorld

        g_game.loginWorld = function(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey, recordTo)
            debugLog("========== loginWorld CALLED ==========")
            debugLog("  [arg1] account: " .. tostring(account))
            debugLog("  [arg2] password: " .. tostring(password))
            debugLog("  [arg3] worldName: " .. tostring(worldName))
            debugLog("  [arg4] worldHost: " .. tostring(worldHost))
            debugLog("  [arg5] worldPort: " .. tostring(worldPort))
            debugLog("  [arg6] characterName: " .. tostring(characterName))
            debugLog("  [arg7] authenticatorToken: " .. tostring(authenticatorToken))
            debugLog("  [arg8] sessionKey: " .. tostring(sessionKey))
            debugLog("  [arg9] recordTo: " .. tostring(recordTo))
            debugLog("  clientVersion: " .. g_game.getClientVersion())
            debugLog("  protocolVersion: " .. g_game.getProtocolVersion())
            debugLog("  GameSequencedPackets: " .. tostring(g_game.getFeature(GameSequencedPackets)))

            -- RSA overflow safety
            local sk = tostring(sessionKey or "")
            local cn = tostring(characterName or "")
            local rsaContent = 27 + #sk + #cn
            if rsaContent > ORIGINAL_RSA_SIZE - 20 then
                debugLog("  WARNING: RSA content too large (" .. rsaContent .. "), truncating sessionKey")
                sk = sk:sub(1, ORIGINAL_RSA_SIZE - 27 - #cn)
                sessionKey = sk
            end

            -- Validate parameters before calling C++
            local portNum = tonumber(worldPort)
            if not portNum or portNum < 1 or portNum > 65535 then
                debugLog("  !!! ERROR: worldPort is not a valid number: " .. tostring(worldPort))
                debugLog("  !!! ABORTING loginWorld call to prevent crash")
                return
            end

            -- Check if worldHost looks like an IP
            if type(worldHost) == "string" and not worldHost:match("^%d+%.%d+%.%d+%.%d+$") and not worldHost:match("^[a-zA-Z") then
                debugLog("  !!! WARNING: worldHost doesn't look like IP or hostname: " .. tostring(worldHost))
            end

            debugLog("  Calling original loginWorld...")
            local ok2, err2 = pcall(function()
                originalLoginWorld(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey, recordTo)
            end)
            if not ok2 then
                debugLog("  !!! loginWorld CRASHED: " .. tostring(err2))
            else
                debugLog("loginWorld returned OK")
            end
            debugLog("========== loginWorld COMPLETE ==========")
        end

        -- Hook connection events
        connect(g_game, {
            onConnectionError = function(self, message, code)
                debugLog("!!! CONNECTION ERROR: " .. tostring(message) .. " (code: " .. tostring(code) .. ")")
            end,
            onLoginError = function(self, message)
                debugLog("!!! LOGIN ERROR: " .. tostring(message))
            end,
            onSessionEnd = function(self, reason)
                debugLog("Session ended: " .. tostring(reason))
            end,
            onGameStart = function(self)
                debugLog("=== GAME STARTED SUCCESSFULLY ===")
            end,
        })

        debugLog("=== client_mods init complete ===")
    end)

    if not ok then
        print("[MOD ERROR] " .. tostring(err))
        local f = io.open(DEBUG_FILE, "a")
        if f then
            f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. "!!! INIT ERROR: " .. tostring(err) .. "\n")
            f:close()
        end
    end
end

function terminate()
end
