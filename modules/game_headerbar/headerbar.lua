local HEADER_HEIGHT = 36
local headerBar = nil
local battleButton = nil
local equipmentButton = nil
local isSetup = false

function init()
    g_ui.importStyle('/game_headerbar/headerbar.otui')
    g_logger.info("[HeaderBar] Module loaded")
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
    if headerBar then
        headerBar:destroy()
        headerBar = nil
    end
    isSetup = false
end

function onGameStart()
    g_logger.info("[HeaderBar] onGameStart fired")
    if isSetup then return end
    isSetup = true
    setupHeaderBar()
end

function onGameEnd()
    g_logger.info("[HeaderBar] onGameEnd fired")
    if headerBar then
        headerBar:hide()
    end
    isSetup = false
end

function setupHeaderBar()
    local rootWidget = g_ui.getRootWidget()
    if not rootWidget then
        g_logger.error("[HeaderBar] rootWidget not found")
        return
    end

    local gameRootPanel = rootWidget:getChildById('gameRootPanel')
    if not gameRootPanel then
        g_logger.error("[HeaderBar] gameRootPanel not found")
        return
    end

    -- Create headerBar as a child of rootWidget (same level as topMenu and gameRootPanel)
    headerBar = g_ui.createWidget('GameHeaderBar', rootWidget)
    headerBar:setId('gameHeaderBar')

    -- Position in the gap: gameRootPanel has margin-top 36 in OTUI,
    -- so place headerbar 36px above gameRootPanel's top edge.
    -- Only READ gameRootPanel position, never modify it.
    local gameRootY = gameRootPanel:getY()
    local rootW = rootWidget:getWidth()
    local barY = gameRootY - HEADER_HEIGHT

    headerBar:setX(0)
    headerBar:setY(barY)
    headerBar:setWidth(rootW)
    headerBar:setHeight(HEADER_HEIGHT)
    headerBar:show()
    headerBar:raise()

    g_logger.info("[HeaderBar] gameRootY=" .. gameRootY .. " barY=" .. barY .. " W=" .. rootW)

    -- Create Battle button
    battleButton = g_ui.createWidget('HeaderBarButton', headerBar)
    battleButton:setId('headerBattleButton')
    battleButton:setText('Battle')
    battleButton:setWidth(100)
    battleButton:setHeight(HEADER_HEIGHT - 8)
    battleButton:setX(10)
    battleButton:setY(4)
    battleButton.onClick = function()
        toggleBattle()
    end

    -- Create Equipment button
    equipmentButton = g_ui.createWidget('HeaderBarButton', headerBar)
    equipmentButton:setId('headerEquipmentButton')
    equipmentButton:setText('Equipment')
    equipmentButton:setWidth(100)
    equipmentButton:setHeight(HEADER_HEIGHT - 8)
    equipmentButton:setX(120)
    equipmentButton:setY(4)
    equipmentButton.onClick = function()
        toggleEquipment()
    end

    g_logger.info("[HeaderBar] Setup complete (floating mode)")
end

function toggleBattle()
    if not battleButton then return end
    local battleWindow = modules.game_battlelist and modules.game_battlelist.battleWindow
    if battleWindow then
        if battleWindow:isVisible() then
            battleWindow:hide()
            setBattleButtonState(false)
        else
            battleWindow:show()
            battleWindow:raise()
            setBattleButtonState(true)
        end
    end
end

function toggleEquipment()
    if not equipmentButton then return end
    local equipmentWindow = g_ui.getRootWidget():recursiveGetChildById('equipmentWindow')
    if not equipmentWindow then
        equipmentWindow = g_ui.getRootWidget():recursiveGetChildById('equipmentBox')
    end
    if equipmentWindow then
        if equipmentWindow:isVisible() then
            equipmentWindow:hide()
            setEquipmentButtonState(false)
        else
            equipmentWindow:show()
            equipmentWindow:raise()
            setEquipmentButtonState(true)
        end
    end
end

function setBattleButtonState(active)
    if not battleButton then return end
    if active then
        battleButton:setColor('#00e5ff')
        battleButton:setBorderWidthBottom(2)
        battleButton:setBorderColorBottom('#00e5ff')
    else
        battleButton:setColor('#6e7681')
        battleButton:setBorderWidthBottom(1)
        battleButton:setBorderColorBottom('#00e5ff18')
    end
end

function setEquipmentButtonState(active)
    if not equipmentButton then return end
    if active then
        equipmentButton:setColor('#00e5ff')
        equipmentButton:setBorderWidthBottom(2)
        equipmentButton:setBorderColorBottom('#00e5ff')
    else
        equipmentButton:setColor('#6e7681')
        equipmentButton:setBorderWidthBottom(1)
        equipmentButton:setBorderColorBottom('#00e5ff18')
    end
end