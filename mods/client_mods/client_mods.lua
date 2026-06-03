-- client_mods.lua v8 - Sequenced Packets Fix
-- ROOT CAUSE: Protocol::onConnect() called enabledSequencedPackets() unconditionally
-- for client version >= 1200, without checking the GameSequencedPackets feature flag.
-- This caused the login packet to use sequence numbers (0x00000000) instead of
-- checksums (adler32), producing an incorrect packet format for OTServBR-Global 13.16.
-- FIX: protocol.cpp now checks g_game.getFeature(GameSequencedPackets) before
-- calling enabledSequencedPackets(). This Lua mod keeps GameSequencedPackets disabled.

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

        -- Disable GameSequencedPackets for protocol 1316
        -- OTServBR-Global uses checksums, not sequence numbers
        local origSetClientVersion = g_game.setClientVersion
        local versionSet = false
        g_game.setClientVersion = function(v)
            origSetClientVersion(v)
            if not versionSet and v >= 1290 then
                versionSet = true
                g_game.disableFeature(GameSequencedPackets)
                debugLog("GameSequencedPackets disabled (protocol " .. v .. ")")
            end
        end

        local origSetProtocolVersion = g_game.setProtocolVersion
        g_game.setProtocolVersion = function(v)
            origSetProtocolVersion(v)
            if v >= 1290 then
                g_game.disableFeature(GameSequencedPackets)
            end
        end

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
                originalLoginWorld(self, account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
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
