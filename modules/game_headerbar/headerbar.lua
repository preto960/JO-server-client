local headerBar = nil
local battleBtn = nil
local equipBtn = nil
local gameRootPanel = nil
local topMenu = nil
local bottomLine = nil
local buttonsCreated = false

local HEADER_HEIGHT = 36

local function updateButtonState(btn, isOn)
    if not btn then return end
    btn:setImageColor(isOn and '#00B4D8' or '#FFFFFF60')
end

local function createButtons()
    if buttonsCreated or not headerBar then return end
    buttonsCreated = true

    -- Bottom accent line
    bottomLine = g_ui.createWidget('UIWidget', headerBar)
    bottomLine:setHeight(1)
    bottomLine:setBackgroundColor('#00B4D840')
    bottomLine:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    bottomLine:addAnchor(AnchorRight, 'parent', AnchorRight)
    bottomLine:addAnchor(AnchorBottom, 'parent', AnchorBottom)

    -- Battle button
    battleBtn = g_ui.createWidget('UIButton', headerBar)
    battleBtn:setId('headerBattleBtn')
    battleBtn:setSize(28, 28)
    battleBtn:setImageColor('#FFFFFF60')
    pcall(function() battleBtn:setImageSource('/images/topbuttons/battle') end)
    battleBtn:setCursor('pointer')
    battleBtn:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    battleBtn:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    battleBtn:setMarginLeft(12)
    battleBtn.onClick = function()
        modules.game_headerbar.toggleBattle()
    end

    -- Battle label
    local battleLabel = g_ui.createWidget('Label', headerBar)
    battleLabel:setText(tr('Battle'))
    battleLabel:setFont('verdana-9px-rounded')
    battleLabel:setColor('#FFFFFF60')
    battleLabel:setId('headerBattleLabel')
    battleLabel:addAnchor(AnchorLeft, 'headerBattleBtn', AnchorRight)
    battleLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    battleLabel:setMarginLeft(4)

    -- Separator
    local sep1 = g_ui.createWidget('UIWidget', headerBar)
    sep1:setWidth(1)
    sep1:setHeight(20)
    sep1:setBackgroundColor('#00B4D830')
    sep1:setId('sep1')
    sep1:addAnchor(AnchorLeft, 'prev', AnchorRight)
    sep1:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    sep1:setMarginLeft(10)

    -- Equipment button
    equipBtn = g_ui.createWidget('UIButton', headerBar)
    equipBtn:setId('headerEquipBtn')
    equipBtn:setSize(28, 28)
    equipBtn:setImageColor('#FFFFFF60')
    pcall(function() equipBtn:setImageSource('/images/topbuttons/inventory') end)
    equipBtn:setCursor('pointer')
    equipBtn:addAnchor(AnchorLeft, 'sep1', AnchorRight)
    equipBtn:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    equipBtn:setMarginLeft(10)
    equipBtn.onClick = function()
        modules.game_headerbar.toggleEquipment()
    end

    -- Equipment label
    local equipLabel = g_ui.createWidget('Label', headerBar)
    equipLabel:setText(tr('Equipment'))
    equipLabel:setFont('verdana-9px-rounded')
    equipLabel:setColor('#FFFFFF60')
    equipLabel:setId('headerEquipLabel')
    equipLabel:addAnchor(AnchorLeft, 'headerEquipBtn', AnchorRight)
    equipLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
    equipLabel:setMarginLeft(4)
end

function init()
    -- Load the OTUI widget but don't do anything else yet
    local ok = pcall(function()
        headerBar = g_ui.loadUI('headerbar')
    end)
    if not ok or not headerBar then
        g_logger.error("[HeaderBar] Failed to load headerbar.otui")
        return
    end

    -- Connect game events — everything else happens in onGameStart
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    g_logger.info("[HeaderBar] Module loaded, waiting for game start")
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    -- Restore gameRootPanel margin
    if gameRootPanel and not gameRootPanel:isDestroyed() then
        pcall(function()
            gameRootPanel:setMarginTop(0)
        end)
    end

    gameRootPanel = nil
    topMenu = nil
    buttonsCreated = false

    if headerBar and not headerBar:isDestroyed() then
        headerBar:destroy()
    end
    headerBar = nil
end

function onGameStart()
    -- Use scheduleEvent with delay to let the game fully stabilize first
    scheduleEvent(function()
        if not headerBar or headerBar:isDestroyed() then return end

        local root = g_ui.getRootWidget()
        if not root then return end

        topMenu = root:getChildById('topMenu')
        gameRootPanel = root:getChildById('gameRootPanel')
        if not topMenu or not gameRootPanel then
            g_logger.warning("[HeaderBar] topMenu or gameRootPanel not found on game start")
            return
        end

        -- Parent headerBar to root if needed
        if not headerBar:getParent() then
            root:addChild(headerBar)
        end

        -- Create buttons once
        createButtons()

        -- Position headerBar using absolute positioning (safest approach)
        local menuY = topMenu:getY()
        local menuH = topMenu:getHeight()
        local barY = menuY + menuH
        local rootW = root:getWidth()

        pcall(function()
            headerBar:setX(0)
            headerBar:setY(barY)
            headerBar:setWidth(rootW)
            headerBar:setHeight(HEADER_HEIGHT)
        end)

        -- Shift gameRootPanel down
        pcall(function()
            gameRootPanel:setMarginTop(HEADER_HEIGHT)
        end)

        -- Show and raise
        pcall(function()
            headerBar:show()
            headerBar:raise()
        end)

        -- Hide original battle sidebar button
        pcall(function()
            local origBattleBtn = root:recursiveGetChildById('battleButton')
            if origBattleBtn then origBattleBtn:hide() end
            local origWindow = root:recursiveGetChildById('battleWindow')
            if origWindow then origWindow:hide() end
        end)

        g_logger.info("[HeaderBar] Shown at Y=" .. barY)
    end, 1000)
end

function onGameEnd()
    if headerBar and not headerBar:isDestroyed() then
        headerBar:hide()
    end
end

function toggleBattle()
    pcall(function()
        if not modules.game_battle_custom then return end
        local isOpen = modules.game_battle_custom.isOpen
        if isOpen then
            modules.game_battle_custom.closeBattle()
        else
            modules.game_battle_custom.openBattle()
        end
        updateButtonState(battleBtn, not isOpen)
    end)
end

function toggleEquipment()
    pcall(function()
        if not modules.game_inventory_custom then return end
        local isOpen = modules.game_inventory_custom.isOpen
        if isOpen then
            modules.game_inventory_custom.closeEquipment()
        else
            modules.game_inventory_custom.openEquipment()
        end
        updateButtonState(equipBtn, not isOpen)
    end)
end

function setBattleButtonState(isOn)
    updateButtonState(battleBtn, isOn)
end

function setEquipmentButtonState(isOn)
    updateButtonState(equipBtn, isOn)
end