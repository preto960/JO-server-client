-- client_mods.lua - Fix for OTServBR-Global connection crash
-- Problem: STATUS_HEAP_CORRUPTION (0xc0000374) when entering game world
-- Fix: Disable GameSequencedPackets + RSA overflow safety

local DEBUG_FILE = "crash_debug.log"

local function debugLog(msg)
    local f = io.open(DEBUG_FILE, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
    print("[MOD] " .. msg)
end

local ORIGINAL_RSA_SIZE = 128

function init()
    local ok, err = pcall(function()
        debugLog("=== client_mods init (FIX v3) ===")

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

        -- Hook loginWorld for debug + RSA safety
        local originalLoginWorld = g_game.loginWorld

        g_game.loginWorld = function(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey, recordTo)
            debugLog("========== loginWorld CALLED ==========")
            debugLog("  worldHost: " .. tostring(worldHost))
            debugLog("  worldPort: " .. tostring(worldPort))
            debugLog("  characterName: " .. tostring(characterName))
            debugLog("  sessionKey: " .. tostring(sessionKey))
            debugLog("  clientVersion: " .. g_game.getClientVersion())
            debugLog("  protocolVersion: " .. g_game.getProtocolVersion())
            debugLog("  GameSequencedPackets: " .. tostring(g_game.getFeature(GameSequencedPackets)))

            -- RSA overflow safety
            local sk = tostring(sessionKey)
            local cn = tostring(characterName)
            local rsaContent = 27 + #sk + #cn
            if rsaContent > ORIGINAL_RSA_SIZE - 20 then
                debugLog("  WARNING: RSA content too large, truncating sessionKey")
                sk = sk:sub(1, ORIGINAL_RSA_SIZE - 27 - #cn)
                sessionKey = sk
            end

            debugLog("  Calling original loginWorld...")
            originalLoginWorld(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey, recordTo)
            debugLog("loginWorld returned OK")
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
