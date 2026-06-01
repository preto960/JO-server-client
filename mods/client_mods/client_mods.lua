-- client_mods.lua - Fix for OTServBR-Global connection crash
-- Problem: STATUS_HEAP_CORRUPTION (0xc0000374) when entering game world
--
-- Root cause analysis:
-- 1. GameSequencedPackets enabled immediately in C++ (no delay like Lua version)
--    causes packet sequence mismatch with OTServBR-Global
-- 2. Session key may overflow RSA block (128 bytes) if too long
--
-- Fix: Disable problematic features and add safety checks

local DEBUG_FILE = "crash_debug.log"

local function debugLog(msg)
    local f = io.open(DEBUG_FILE, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
    print("[MOD] " .. msg)
    g_logger.debug("[CLIENT_MODS] " .. msg)
end

local ORIGINAL_RSA_SIZE = 128 -- RSA-1024 block size in bytes
local MAX_RSA_CONTENT = ORIGINAL_RSA_SIZE - 20 -- safe margin

function init()
    debugLog("=== client_mods init (FIX v2) ===")
    debugLog("OS: " .. g_platform.getOS())

    -- ================================================
    -- CRITICAL FIX: Disable GameSequencedPackets
    -- The C++ code enables it immediately (no delay),
    -- but OTServBR-Global may not support it,
    -- causing packet parsing errors -> heap corruption
    -- ================================================
    local originalSetClientVersion = g_game.setClientVersion
    local versionSet = false

    g_game.setClientVersion = function(version)
        originalSetClientVersion(version)
        if not versionSet and version >= 1290 then
            versionSet = true
            debugLog("Disabling GameSequencedPackets for version " .. version .. " (OTServBR compat)")
            g_game.disableFeature(Otc.GameSequencedPackets)
        end
    end

    -- Also disable it on protocol version change
    local originalSetProtocolVersion = g_game.setProtocolVersion
    g_game.setProtocolVersion = function(version)
        originalSetProtocolVersion(version)
        if version >= 1290 then
            debugLog("Disabling GameSequencedPackets on protocol " .. version)
            g_game.disableFeature(Otc.GameSequencedPackets)
        end
    end

    -- Hook loginWorld to apply fixes BEFORE connection
    local originalLoginWorld = g_game.loginWorld

    g_game.loginWorld = function(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey, recordTo)
        debugLog("========== loginWorld CALLED ==========")
        debugLog("  worldHost: " .. tostring(worldHost))
        debugLog("  worldPort: " .. tostring(worldPort))
        debugLog("  characterName: " .. tostring(characterName))
        debugLog("  sessionKey: " .. tostring(sessionKey))
        debugLog("  sessionKey length: " .. #tostring(sessionKey))
        debugLog("  authenticatorToken: " .. tostring(authenticatorToken))
        debugLog("  clientVersion: " .. g_game.getClientVersion())
        debugLog("  protocolVersion: " .. g_game.getProtocolVersion())

        -- SAFETY: Truncate session key if it would overflow RSA block
        -- RSA block contains: 1(lead) + 16(xtea) + 1(gm) + len(sessionKey) + 2 + len(charName) + 2 + 5(challenge) = 27 + len(sessionKey) + len(charName)
        -- Must fit in 128 bytes, so sessionKey + charName must be < 101 chars
        local sk = tostring(sessionKey)
        local cn = tostring(characterName)
        local rsaContent = 27 + #sk + #cn
        debugLog("  RSA content estimate: " .. rsaContent .. " / " .. ORIGINAL_RSA_SIZE .. " bytes")

        if rsaContent > MAX_RSA_CONTENT then
            debugLog("  WARNING: RSA content too large, truncating sessionKey")
            local maxSk = MAX_RSA_CONTENT - 27 - #cn
            if maxSk < 1 then maxSk = 1 end
            sk = sk:sub(1, maxSk)
            sessionKey = sk
            debugLog("  Truncated sessionKey length: " .. #sk)
        end

        -- Log features
        debugLog("  GameLoginPacketEncryption: " .. tostring(g_game.getFeature(Otc.GameLoginPacketEncryption)))
        debugLog("  GameSessionKey: " .. tostring(g_game.getFeature(Otc.GameSessionKey)))
        debugLog("  GameChallengeOnLogin: " .. tostring(g_game.getFeature(Otc.GameChallengeOnLogin)))
        debugLog("  GameSequencedPackets: " .. tostring(g_game.getFeature(Otc.GameSequencedPackets)))
        debugLog("  GameProtocolChecksum: " .. tostring(g_game.getFeature(Otc.GameProtocolChecksum)))

        debugLog("  Calling original loginWorld...")

        local ok, err = pcall(function()
            originalLoginWorld(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey, recordTo)
        end)

        if not ok then
            debugLog("!!! loginWorld THREW ERROR: " .. tostring(err))
        else
            debugLog("loginWorld returned OK")
        end

        debugLog("========== loginWorld COMPLETE ==========")
    end

    -- Hook ProtocolLogin (direct login on port 7171) for debug
    -- ProtocolLogin may not be loaded yet, so use pcall
    pcall(function()
        local originalProtocolLoginSend = ProtocolLogin.sendLoginPacket
        if originalProtocolLoginSend then
            ProtocolLogin.sendLoginPacket = function(self)
                debugLog(">>> ProtocolLogin.sendLoginPacket called")
                debugLog("  host: " .. tostring(self.accountName))
                debugLog("  protocol: " .. g_game.getProtocolVersion())
                debugLog("  GameLoginPacketEncryption: " .. tostring(g_game.getFeature(Otc.GameLoginPacketEncryption)))

                local ok, err = pcall(function()
                    originalProtocolLoginSend(self)
                end)

                if not ok then
                    debugLog("!!! ProtocolLogin.sendLoginPacket ERROR: " .. tostring(err))
                else
                    debugLog("<<< ProtocolLogin.sendLoginPacket OK")
                end
            end
        end
    end)

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
end

function terminate()
    debugLog("=== client_mods terminate ===")
end
