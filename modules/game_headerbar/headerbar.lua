local headerBar = nil
local battleBtn = nil
local equipBtn = nil
local gameRootPanel = nil
local savedRootMargin = 0

local HEADER_HEIGHT = 36
local MAX_RETRIES = 10
local retryCount = 0

local function updateButtonState(btn, isOn)
    if not btn then return end
    btn:setImageColor(isOn and '#00B4D8' or '#FFFFFF60')
end

local function setupHeaderBar()
    local root = g_ui.getRootWidget()
    if not root then
        retryCount = retryCount + 1
        if retryCount < MAX_RETRIES then
            scheduleEvent(setupHeaderBar, 500)
        end
        return
    end

    -- Add header bar to root (topMenu is a sibling, so anchors.top: topMenu.bottom works)
    if not headerBar:getParent() then
        root:addChild(headerBar)
    end
    headerBar:raise()

    -- Get button references
    battleBtn = headerBar:getChildById('headerBattleBtn')
    equipBtn = headerBar:getChildById('headerEquipBtn')

    -- Push gameRootPanel down so it starts below our header bar
    gameRootPanel = root:getChildById('gameRootPanel')
    if gameRootPanel then
        savedRootMargin = gameRootPanel:getMarginTop()
        gameRootPanel:setMarginTop(savedRootMargin + HEADER_HEIGHT)
        g_logger.info("[HeaderBar] Pushed gameRootPanel down by " .. HEADER_HEIGHT .. "px")
    else
        g_logger.warning("[HeaderBar] gameRootPanel not found")
    end

    -- Connect game events
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if g_game.isOnline() then
        onGameStart()
    end

    g_logger.info("[HeaderBar] Setup complete, parented to root")
end

function init()
    local ok = pcall(function()
        headerBar = g_ui.loadUI('headerbar')
    end)
    if not ok or not headerBar then
        g_logger.error("[HeaderBar] Failed to load headerbar.otui")
        return
    end

    g_logger.info("[HeaderBar] Module loaded, setting up...")
    retryCount = 0
    addEvent(setupHeaderBar)
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    -- Restore gameRootPanel margin
    if gameRootPanel and not gameRootPanel:isDestroyed() then
        pcall(function()
            gameRootPanel:setMarginTop(savedRootMargin)
        end)
    end
    gameRootPanel = nil

    if headerBar then
        headerBar:destroy()
        headerBar = nil
    end
end

function onGameStart()
    addEvent(function()
        if not headerBar or headerBar:isDestroyed() then return end

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

        g_logger.info("[HeaderBar] Game started, header bar shown")
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

-- Public API
function setBattleButtonState(isOn)
    updateButtonState(battleBtn, isOn)
end

function setEquipmentButtonState(isOn)
    updateButtonState(equipBtn, isOn)
end