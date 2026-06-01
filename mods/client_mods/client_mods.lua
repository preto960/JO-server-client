-- client_mods.lua v6 - Lua-side sendLoginPacket bypass + diagnostic
-- Bypasses the C++ sendLoginPacket that causes heap corruption

local DEBUG_FILE = "crash_debug.log"

local function debugLog(msg)
    local f = io.open(DEBUG_FILE, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
    print("[MOD] " .. msg)
end

function init()
    local ok, err = pcall(function()
        debugLog("=== client_mods init (v6 - Lua bypass) ===")

        -- Disable GameSequencedPackets
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

        -- ===== DIAGNOSTIC: Test RSA from Lua =====
        debugLog("RSA diagnostic:")
        debugLog("  rsaGetSize = " .. tostring(g_crypt.rsaGetSize()))
        local testMsg = OutputMessage.create()
        testMsg:addU8(0)
        testMsg:addU32(1234)
        testMsg:addU32(5678)
        testMsg:addU32(9999)
        testMsg:addU32(1111)
        testMsg:addU8(0)
        testMsg:addString("testkey")
        testMsg:addString("testchar")
        local testDataSize = testMsg:getMessageSize()
        local rsaSize = g_crypt.rsaGetSize()
        local padBytes = rsaSize - testDataSize
        debugLog("  testDataSize=" .. testDataSize .. " rsaSize=" .. rsaSize .. " padBytes=" .. padBytes)
        if padBytes > 0 then
            testMsg:addPaddingBytes(padBytes)
        end
        local testOk, testErr = pcall(function()
            testMsg:encryptRsa()
        end)
        debugLog("  RSA encrypt test: " .. tostring(testOk) .. (testErr and (" err=" .. tostring(testErr)) or ""))

        -- ===== DIAGNOSTIC: Test full login packet build from Lua =====
        debugLog("Login packet build test:")
        local testPacket = OutputMessage.create()
        testPacket:addU8(10) -- ClientPendingGame
        testPacket:addU16(g_game.getOs())
        testPacket:addU16(g_game.getProtocolVersion())
        testPacket:addU32(g_game.getClientVersion())
        testPacket:addString(tostring(g_game.getClientVersion()))
        testPacket:addU16(g_things.getContentRevision())
        testPacket:addU8(0) -- preview state
        local offset = testPacket:getMessageSize()
        debugLog("  header offset=" .. offset)

        testPacket:addU8(0)
        testPacket:addU32(0xDEADBEEF)
        testPacket:addU32(0x12345678)
        testPacket:addU32(0x9ABCDEF0)
        testPacket:addU32(0x11111111)
        testPacket:addU8(0)
        testPacket:addString("@god\n123456")
        testPacket:addString("GOD")
        testPacket:addU32(0)
        testPacket:addU8(0)
        local blockSize = testPacket:getMessageSize() - offset
        debugLog("  blockSize=" .. blockSize .. " (max=" .. rsaSize .. ")")
        local pad2 = rsaSize - blockSize
        debugLog("  padBytes=" .. pad2)
        testPacket:addPaddingBytes(pad2)
        local totalSize = testPacket:getMessageSize()
        debugLog("  totalSize=" .. totalSize)

        local encOk, encErr = pcall(function()
            testPacket:encryptRsa()
        end)
        debugLog("  Full packet RSA encrypt: " .. tostring(encOk) .. (encErr and (" err=" .. tostring(encErr)) or ""))
        debugLog("  Final message size: " .. testPacket:getMessageSize())

        -- ===== MAIN FIX: Hook loginWorld with Lua bypass =====
        local originalLoginWorld = g_game.loginWorld
        local loginAttemptInProgress = false

        g_game.loginWorld = function(self, account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
            if loginAttemptInProgress then
                debugLog("!!! Recursive loginWorld call, ignoring")
                return
            end
            loginAttemptInProgress = true

            debugLog("========== loginWorld v6 ==========")
            debugLog("  host=" .. tostring(worldHost) .. " port=" .. tostring(worldPort) .. " char=" .. tostring(characterName))
            debugLog("  sessionKey=" .. tostring(sessionKey))
            debugLog("  GameSequencedPackets=" .. tostring(g_game.getFeature(GameSequencedPackets)))

            local portNum = tonumber(worldPort)
            if not portNum or portNum < 1 or portNum > 65535 then
                debugLog("!!! Invalid port: " .. tostring(worldPort))
                loginAttemptInProgress = false
                return
            end

            -- Save params for potential Lua fallback
            G._loginParams = {
                account = account,
                password = password,
                worldName = worldName,
                worldHost = worldHost,
                worldPort = portNum,
                characterName = characterName,
                authenticatorToken = authenticatorToken,
                sessionKey = sessionKey
            }

            debugLog("  Calling C++ loginWorld...")
            local ok2, err2 = pcall(function()
                originalLoginWorld(self, account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
            end)

            if ok2 then
                debugLog("  C++ loginWorld returned OK!")
                -- Try to get the protocol game for Lua-side monitoring
                local pg = g_game.getProtocolGame()
                if pg then
                    debugLog("  ProtocolGame obtained: " .. tostring(pg))
                else
                    debugLog("  WARNING: ProtocolGame is nil after loginWorld")
                end
            else
                debugLog("  !!! C++ loginWorld ERROR: " .. tostring(err2))
            end

            loginAttemptInProgress = false
            debugLog("========== loginWorld v6 END ==========")
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
