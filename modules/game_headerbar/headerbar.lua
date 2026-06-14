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

    local topMenu = rootWidget:getChildById('topMenu')
    if not topMenu then
        g_logger.error("[HeaderBar] topMenu not found")
        return
    end

    -- Create headerBar as a child of rootWidget (same level as topMenu and gameRootPanel)
    headerBar = g_ui.createWidget('GameHeaderBar', rootWidget)
    headerBar:setId('gameHeaderBar')

    -- Position it right below topMenu using absolute positioning
    -- DO NOT touch gameRootPanel at all
    local topMenuBottom = topMenu:getY() + topMenu:getHeight()
    local rootW = rootWidget:getWidth()

    headerBar:setX(0)
    headerBar:setY(topMenuBottom)
    headerBar:setWidth(rootW)
    headerBar:setHeight(HEADER_HEIGHT)
    headerBar:show()
    headerBar:raise()

    g_logger.info("[HeaderBar] Positioned at Y=" .. topMenuBottom .. " W=" .. rootW)

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
        battleButton:setColor('#00ffff')
    else
        battleButton:setColor('#cccccc')
    end
end

function setEquipmentButtonState(active)
    if not equipmentButton then return end
    if active then
        equipmentButton:setColor('#ff00ff')
    else
        equipmentButton:setColor('#cccccc')
    end
end