local headerBar = nil
local battleBtn = nil
local equipBtn = nil
local gameRootPanel = nil
local topMenu = nil
local bottomLine = nil

local HEADER_HEIGHT = 36

local function updateButtonState(btn, isOn)
    if not btn then return end
    btn:setImageColor(isOn and '#00B4D8' or '#FFFFFF60')
end

local function anchorGameRootToHeaderBar()
    if not gameRootPanel or not headerBar then return end

    -- Break the existing top anchor (topMenu.bottom or parent.top)
    gameRootPanel:breakAnchors()

    -- Re-anchor: fill parent horizontally and vertically, but top follows headerBar bottom
    gameRootPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    gameRootPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
    gameRootPanel:addAnchor(AnchorTop, 'gameHeaderBar', AnchorBottom)
    gameRootPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)

    -- Clear any leftover margin
    gameRootPanel:setMarginTop(0)

    g_logger.info("[HeaderBar] gameRootPanel anchored to headerBar.bottom")
end

local function restoreGameRootAnchors()
    if not gameRootPanel or gameRootPanel:isDestroyed() then return end

    gameRootPanel:breakAnchors()
    gameRootPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    gameRootPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
    gameRootPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
    gameRootPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)

    g_logger.info("[HeaderBar] gameRootPanel anchors restored to parent")
end

local function positionHeaderBar()
    if not headerBar or not topMenu then return end

    local rootW = g_ui.getRootWidget():getWidth()

    -- Anchor headerBar below topMenu
    headerBar:breakAnchors()
    headerBar:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    headerBar:addAnchor(AnchorRight, 'parent', AnchorRight)
    headerBar:addAnchor(AnchorTop, 'topMenu', AnchorBottom)
    headerBar:setHeight(HEADER_HEIGHT)
    headerBar:setMarginTop(0)

    g_logger.info("[HeaderBar] Positioned below topMenu, width=" .. rootW)
end

local function createButtons()
    if not headerBar then return end

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

local function setupHeaderBar()
    local root = g_ui.getRootWidget()
    if not root then
        g_logger.warning("[HeaderBar] Root not found, retrying...")
        scheduleEvent(setupHeaderBar, 500)
        return
    end

    topMenu = root:getChildById('topMenu')
    gameRootPanel = root:getChildById('gameRootPanel')

    if not topMenu then
        g_logger.error("[HeaderBar] topMenu not found!")
        return
    end
    if not gameRootPanel then
        g_logger.warning("[HeaderBar] gameRootPanel not found, retrying...")
        scheduleEvent(setupHeaderBar, 500)
        return
    end

    -- Add headerBar to root (sibling of topMenu and gameRootPanel)
    if not headerBar:getParent() then
        root:addChild(headerBar)
    end

    -- Create all buttons programmatically
    createButtons()

    -- Anchor headerBar below topMenu using anchors (not absolute positioning)
    positionHeaderBar()

    -- Anchor gameRootPanel below headerBar instead of below topMenu
    anchorGameRootToHeaderBar()

    -- Raise to top of root's children
    headerBar:raise()

    -- Connect game events
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if g_game.isOnline() then
        onGameStart()
    end

    g_logger.info("[HeaderBar] Setup complete!")
end

function init()
    local ok = pcall(function()
        headerBar = g_ui.loadUI('headerbar')
    end)
    if not ok or not headerBar then
        g_logger.error("[HeaderBar] Failed to load headerbar.otui")
        return
    end

    g_logger.info("[HeaderBar] Module init, scheduling setup...")
    addEvent(setupHeaderBar)
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    -- Restore gameRootPanel anchors to fill parent
    restoreGameRootAnchors()

    gameRootPanel = nil
    topMenu = nil

    if headerBar then
        headerBar:destroy()
        headerBar = nil
    end
end

function onGameStart()
    addEvent(function()
        if not headerBar or headerBar:isDestroyed() then return end

        -- Re-find widgets in case they changed
        local root = g_ui.getRootWidget()
        if root then
            topMenu = root:getChildById('topMenu') or topMenu
            gameRootPanel = root:getChildById('gameRootPanel') or gameRootPanel
        end

        -- Re-apply anchor chain: topMenu -> headerBar -> gameRootPanel
        positionHeaderBar()
        anchorGameRootToHeaderBar()

        headerBar:show()
        headerBar:raise()

        -- Hide original battle sidebar button
        pcall(function()
            local root = g_ui.getRootWidget()
            local origBattleBtn = root:recursiveGetChildById('battleButton')
            if origBattleBtn then
                origBattleBtn:hide()
            end
            local origWindow = root:recursiveGetChildById('battleWindow')
            if origWindow then
                origWindow:hide()
            end
        end)

        g_logger.info("[HeaderBar] onGameStart - bar shown")
    end)
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