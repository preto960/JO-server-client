-- client_mods.lua v9 - Debug logging only
-- Sequenced packets are now handled correctly by protocol.cpp
-- (checks g_game.getFeature(GameSequencedPackets) before enabling).

local DEBUG_FILE = "crash_debug.log"

local function debugLog(msg)
    local f = io.open(DEBUG_FILE, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:flush()
        f:close()
    end
end

function init()
    local ok, err = pcall(function()
        debugLog("=== client_mods init (v8 - sequenced packets fix) ===")

        -- Hook loginWorld for logging
        local originalLoginWorld = g_game.loginWorld
        local loginAttemptInProgress = false

        g_game.loginWorld = function(self, account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
            if loginAttemptInProgress then
                debugLog("!!! Recursive loginWorld call, ignoring")
                return
            end
            loginAttemptInProgress = true

            debugLog("========== loginWorld v8 ==========")
            debugLog("  host=" .. tostring(worldHost) .. " port=" .. tostring(worldPort) .. " char=" .. tostring(characterName))
            debugLog("  sessionKey=" .. tostring(sessionKey))
            debugLog("  GameSequencedPackets=" .. tostring(g_game.getFeature(GameSequencedPackets)))
            debugLog("  GameChallengeOnLogin=" .. tostring(g_game.getFeature(GameChallengeOnLogin)))
            debugLog("  GameLoginPacketEncryption=" .. tostring(g_game.getFeature(GameLoginPacketEncryption)))
            debugLog("  GameSessionKey=" .. tostring(g_game.getFeature(GameSessionKey)))
            debugLog("  GameProtocolChecksum=" .. tostring(g_game.getFeature(GameProtocolChecksum)))
            debugLog("  Calling C++ loginWorld...")

            local ok2, err2 = pcall(function()
                originalLoginWorld(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
            end)

            debugLog("  pcall returned: ok=" .. tostring(ok2))
            if not ok2 then
                debugLog("  C++ loginWorld ERROR: " .. tostring(err2))
            end

            loginAttemptInProgress = false
            debugLog("========== loginWorld v8 END ==========")
        end

        -- Hook connection events for logging
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
                scheduleEvent(1000, function()
                    if g_game.isOnline() and modules.game_welcome then
                        modules.game_welcome.showWelcome("Hola!")
                    end
                end)
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
