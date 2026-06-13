local headerBar = nil
local battleBtn = nil
local equipBtn = nil
local gameTopPanel = nil
local savedTopPanelMargin = 0

local HEADER_HEIGHT = 36

local function updateButtonState(btn, isOn)
    if not btn then return end
    btn:setImageColor(isOn and '#00B4D8' or '#FFFFFF60')
end

function init()
    local ok = pcall(function()
        headerBar = g_ui.loadUI('headerbar')
    end)
    if not ok or not headerBar then
        g_logger.warning("[HeaderBar] Failed to load headerbar.otui")
        return
    end

    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        -- Find gameRootPanel and parent the header bar INSIDE it
        local gameRootPanel = root:getChildById('gameRootPanel')
        if not gameRootPanel then
            g_logger.warning("[HeaderBar] gameRootPanel not found")
            return
        end

        -- Add header bar to gameRootPanel (not root!)
        if not headerBar:getParent() then
            gameRootPanel:addChild(headerBar)
        end

        -- Get button references
        battleBtn = headerBar:getChildById('headerBattleBtn')
        equipBtn = headerBar:getChildById('headerEquipBtn')

        -- Push gameTopPanel (stats bar) down so it sits below our header bar
        gameTopPanel = gameRootPanel:getChildById('gameTopPanel')
        if gameTopPanel then
            savedTopPanelMargin = gameTopPanel:getMarginTop()
            gameTopPanel:setMarginTop(savedTopPanelMargin + HEADER_HEIGHT)
        end

        -- Show/hide bar based on game state
        connect(g_game, {
            onGameStart = onGameStart,
            onGameEnd = onGameEnd
        })

        if g_game.isOnline() then
            onGameStart()
        end
    end)
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    -- Restore gameTopPanel margin
    if gameTopPanel then
        pcall(function()
            gameTopPanel:setMarginTop(savedTopPanelMargin)
        end)
        gameTopPanel = nil
    end

    if headerBar then
        headerBar:destroy()
        headerBar = nil
    end
end

function onGameStart()
    addEvent(function()
        if headerBar then
            headerBar:show()
            headerBar:raise()
        end

        -- Hide original battle sidebar button
        pcall(function()
            local root = g_ui.getRootWidget()
            local origBattleBtn = root:recursiveGetChildById('battleButton')
            if origBattleBtn then
                origBattleBtn:hide()
            end
            -- Hide original battle window
            local origWindow = root:recursiveGetChildById('battleWindow')
            if origWindow then
                origWindow:hide()
            end
        end)
    end)

    -- Override original battle button onClick to use our header
    addEvent(function()
        pcall(function()
            local root = g_ui.getRootWidget()
            local origBattleBtn = root:recursiveGetChildById('battleButton')
            if origBattleBtn then
                origBattleBtn.onClick = function()
                    toggleBattle()
                end
            end
        end)
    end)
end

function onGameEnd()
    if headerBar then
        headerBar:hide()
    end
end

function toggleBattle()
    pcall(function()
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
        local isOpen = modules.game_inventory_custom.isOpen
        if isOpen then
            modules.game_inventory_custom.closeEquipment()
        else
            modules.game_inventory_custom.openEquipment()
        end
        updateButtonState(equipBtn, not isOpen)
    end)
end

-- Public API: let other modules sync their button state
function setBattleButtonState(isOn)
    updateButtonState(battleBtn, isOn)
end

function setEquipmentButtonState(isOn)
    updateButtonState(equipBtn, isOn)
end