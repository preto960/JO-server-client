function init()
    g_logger.info("[HeaderBar] Module loaded (diagnostic mode)")
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
end

function onGameStart()
    g_logger.info("[HeaderBar] onGameStart fired (no-op)")
end

function onGameEnd()
    g_logger.info("[HeaderBar] onGameEnd fired (no-op)")
end

function toggleBattle() end
function toggleEquipment() end
function setBattleButtonState() end
function setEquipmentButtonState() end