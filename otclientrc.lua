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
    g_logger.info("  account: " .. tostring(account))
    g_logger.info("  clientVersion: " .. tostring(g_game.getClientVersion()))
    g_logger.info("  protocolVersion: " .. tostring(g_game.getProtocolVersion()))
    g_logger.info("  currentRsa is OTSERV_RSA: " .. tostring(G.currentRsa == OTSERV_RSA))
    g_logger.info("  GameChallengeOnLogin: " .. tostring(g_game.getFeature(GameChallengeOnLogin)))
    g_logger.info("  GameSessionKey: " .. tostring(g_game.getFeature(GameSessionKey)))
    g_logger.info("  GameLoginPacketEncryption: " .. tostring(g_game.getFeature(GameLoginPacketEncryption)))
    g_logger.info("  GameProtocolChecksum: " .. tostring(g_game.getFeature(GameProtocolChecksum)))
    g_logger.info(" ================================")
    return originalLoginWorld(g_game, account, password, worldName, worldHost, worldPort, characterName, authenticatorToken, sessionKey)
end

-- Hook into onGameConnectionError to log errors
local originalOnGameConnectionError = onGameConnectionError
function onGameConnectionError(message, code)
    g_logger.info("== DEBUG onGameConnectionError ==")
    g_logger.info("  message: " .. tostring(message))
    g_logger.info("  code: " .. tostring(code))
    g_logger.info(" ===================================")
    return originalOnGameConnectionError(message, code)
end

g_logger.info("== DEBUG: Connection tracker v2 loaded ==");
print("== DEBUG: Connection tracker v2 loaded ==")
