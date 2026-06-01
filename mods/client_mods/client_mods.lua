-- Debug mod to diagnose crash on character login
-- This hooks into the login flow and logs everything to otclient.log

local DEBUG_FILE = "crash_debug.log"

local function debugLog(msg)
    local f = io.open(DEBUG_FILE, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
    print("[DEBUG] " .. msg)
    g_logger.debug("[CRASH_DEBUG] " .. msg)
end

function init()
    debugLog("=== client_mods init ===")
    debugLog("Client version: " .. g_game.getClientVersion())
    debugLog("Protocol version: " .. g_game.getProtocolVersion())
    debugLog("OS: " .. g_platform.getOSName())

    -- Log all active features for protocol 1316
    local features = {
        { name = "GameLoginPacketEncryption", id = 63 },
        { name = "GameProtocolChecksum", id = 1 },
        { name = "GameAccountNames", id = 2 },
        { name = "GameChallengeOnLogin", id = 3 },
        { name = "GameClientVersion", id = 64 },
        { name = "GameContentRevision", id = 65 },
        { name = "GameSessionKey", id = 69 },
        { name = "GameMessageSizeCheck", id = 61 },
        { name = "GameLoginPending", id = 35 },
        { name = "GameSequencedPackets", id = 90 },
        { name = "GamePreviewState", id = 62 },
    }
    for _, feat in ipairs(features) do
        local enabled = g_game.getFeature(feat.id)
        debugLog(string.format("  Feature %s (%d): %s", feat.name, feat.id, tostring(enabled)))
    end

    -- Hook into loginWorld to trace exactly what happens
    local originalLoginWorld = g_game.loginWorld

    g_game.loginWorld = function(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey, recordTo)
        debugLog("========== loginWorld CALLED ==========")
        debugLog("  account: " .. tostring(account))
        debugLog("  password length: " .. #tostring(password))
        debugLog("  worldName: " .. tostring(worldName))
        debugLog("  worldHost: " .. tostring(worldHost))
        debugLog("  worldPort: " .. tostring(worldPort))
        debugLog("  characterName: " .. tostring(characterName))
        debugLog("  authenticatorToken: " .. tostring(authenticatorToken))
        debugLog("  sessionKey: " .. tostring(sessionKey))
        debugLog("  sessionKey length: " .. #tostring(sessionKey))
        debugLog("  clientVersion: " .. g_game.getClientVersion())
        debugLog("  protocolVersion: " .. g_game.getProtocolVersion())
        debugLog("  protocolVersion == 0: " .. tostring(g_game.getProtocolVersion() == 0))
        debugLog("  isOnline: " .. tostring(g_game.isOnline()))
        debugLog("  GameLoginPacketEncryption: " .. tostring(g_game.getFeature(GameLoginPacketEncryption)))
        debugLog("  GameSessionKey: " .. tostring(g_game.getFeature(GameSessionKey)))
        debugLog("  GameChallengeOnLogin: " .. tostring(g_game.getFeature(GameChallengeOnLogin)))
        debugLog("  GameProtocolChecksum: " .. tostring(g_game.getFeature(GameProtocolChecksum)))
        debugLog("  GameSequencedPackets: " .. tostring(g_game.getFeature(GameSequencedPackets)))
        debugLog("  GameMessageSizeCheck: " .. tostring(g_game.getFeature(GameMessageSizeCheck)))
        debugLog("  GameContentRevision: " .. tostring(g_game.getFeature(GameContentRevision)))
        debugLog("  GameClientVersion: " .. tostring(g_game.getFeature(GameClientVersion)))
        debugLog("  GameLoginPending: " .. tostring(g_game.getFeature(GameLoginPending)))

        -- Flush log before calling the original function
        debugLog("  About to call original loginWorld...")

        local ok, err = pcall(function()
            originalLoginWorld(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey, recordTo)
        end)

        if not ok then
            debugLog("!!! loginWorld THREW ERROR: " .. tostring(err))
        else
            debugLog("loginWorld returned successfully (packet sent)")
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
end

function terminate()
    debugLog("=== client_mods terminate ===")
end
