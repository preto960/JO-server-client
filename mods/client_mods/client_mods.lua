-- client_mods.lua v7 - Diagnostic with C++ logging companion
-- C++ side now has detailed logging in protocolgame.cpp, protocolgamesend.cpp, game.cpp, protocol.cpp
-- This Lua mod provides the Lua-side logging and feature management

local DEBUG_FILE = "crash_debug.log"

local function debugLog(msg)
    local f = io.open(DEBUG_FILE, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:flush() -- force flush to OS
        f:close()
    end
end

function init()
    local ok, err = pcall(function()
        debugLog("=== client_mods init (v7) ===")

        -- Disable GameSequencedPackets for protocol 1316+
        local origSetClientVersion = g_game.setClientVersion
        local versionSet = false
        g_game.setClientVersion = function(v)
            origSetClientVersion(v)
            if not versionSet and v >= 1290 then
                versionSet = true
                g_game.disableFeature(GameSequencedPackets)
                debugLog("GameSequencedPackets disabled")
            end
        end

        local origSetProtocolVersion = g_game.setProtocolVersion
        g_game.setProtocolVersion = function(v)
            origSetProtocolVersion(v)
            if v >= 1290 then
                g_game.disableFeature(GameSequencedPackets)
            end
        end

        -- Hook loginWorld with detailed logging
        local originalLoginWorld = g_game.loginWorld
        local loginAttemptInProgress = false

        g_game.loginWorld = function(self, account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
            if loginAttemptInProgress then
                debugLog("!!! Recursive loginWorld call, ignoring")
                return
            end
            loginAttemptInProgress = true

            debugLog("========== loginWorld v7 ==========")
            debugLog("  [LUA] host=" .. tostring(worldHost) .. " port=" .. tostring(worldPort) .. " char=" .. tostring(characterName))
            debugLog("  [LUA] worldName=" .. tostring(worldName))
            debugLog("  [LUA] sessionKey=" .. tostring(sessionKey))
            debugLog("  [LUA] authenticatorToken=" .. tostring(authenticatorToken))
            debugLog("  [LUA] GameSequencedPackets=" .. tostring(g_game.getFeature(GameSequencedPackets)))
            debugLog("  [LUA] GameChallengeOnLogin=" .. tostring(g_game.getFeature(GameChallengeOnLogin)))
            debugLog("  [LUA] GameLoginPacketEncryption=" .. tostring(g_game.getFeature(GameLoginPacketEncryption)))
            debugLog("  [LUA] GameSessionKey=" .. tostring(g_game.getFeature(GameSessionKey)))
            debugLog("  [LUA] GameProtocolChecksum=" .. tostring(g_game.getFeature(GameProtocolChecksum)))

            local portNum = tonumber(worldPort)
            if not portNum or portNum < 1 or portNum > 65535 then
                debugLog("!!! Invalid port: " .. tostring(worldPort))
                loginAttemptInProgress = false
                return
            end

            debugLog("  [LUA] Calling original C++ loginWorld...")
            debugLog("  [LUA] Flushing log before C++ call...")
            io.flush()

            local ok2, err2 = pcall(function()
                originalLoginWorld(self, account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
            end)

            debugLog("  [LUA] pcall returned: ok=" .. tostring(ok2))
            if ok2 then
                debugLog("  [LUA] C++ loginWorld returned successfully!")
                local pg = g_game.getProtocolGame()
                if pg then
                    debugLog("  [LUA] ProtocolGame obtained: " .. tostring(pg))
                else
                    debugLog("  [LUA] WARNING: ProtocolGame is nil after loginWorld")
                end
            else
                debugLog("  [LUA] C++ loginWorld ERROR: " .. tostring(err2))
            end

            loginAttemptInProgress = false
            debugLog("========== loginWorld v7 END ==========")
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
            f:flush()
            f:close()
        end
    end
end

function terminate()
end
