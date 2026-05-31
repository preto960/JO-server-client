-- this file is loaded after all modules are loaded and initialized
-- you can place any custom user code here

print 'Startup done :]'

-- ========== DEBUG: Track game server connection ==========
local originalLoginWorld = g_game.loginWorld
g_game.loginWorld = function(account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
    g_logger.info("== DEBUG loginWorld called ==")
    g_logger.info("  worldHost: " .. tostring(worldHost))
    g_logger.info("  worldPort: " .. tostring(worldPort))
    g_logger.info("  characterName: " .. tostring(characterName))
    g_logger.info("  sessionKey: " .. tostring(sessionKey and string.sub(sessionKey, 1, 30) .. "..." or "nil"))
    g_logger.info("  clientVersion: " .. tostring(g_game.getClientVersion()))
    g_logger.info("  protocolVersion: " .. tostring(g_game.getProtocolVersion()))
    g_logger.info("  currentRsa is OTSERV_RSA: " .. tostring(G.currentRsa == OTSERV_RSA))
    g_logger.info(" ================================")
    return originalLoginWorld(g_game, account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
end

local originalTryLogin = nil
if modules.client_entergame then
    local charList = modules.client_entergame.characterlist
    if charList and charList.tryLogin then
        originalTryLogin = charList.tryLogin
        charList.tryLogin = function(charInfo, tries)
            g_logger.info("== DEBUG tryLogin called ==")
            g_logger.info("  charInfo.worldHost: " .. tostring(charInfo.worldHost))
            g_logger.info("  charInfo.worldPort: " .. tostring(charInfo.worldPort))
            g_logger.info("  charInfo.characterName: " .. tostring(charInfo.characterName))
            g_logger.info("  G.sessionKey: " .. tostring(G.sessionKey and string.sub(G.sessionKey, 1, 30) .. "..." or "nil"))
            g_logger.info("  G.account: " .. tostring(G.account))
            g_logger.info("  G.password set: " .. tostring(G.password and #G.password > 0))
            g_logger.info(" ================================")
            return originalTryLogin(charInfo, tries)
        end
    end
end

g_logger.info("== DEBUG: Connection tracker loaded ==");
print("== DEBUG: Connection tracker loaded ==")
