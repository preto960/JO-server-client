local headerBar = nil
local battleBtn = nil
local equipBtn = nil
local skillsBtn = nil

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

        if not headerBar:getParent() then
            root:addChild(headerBar)
        end

        battleBtn = headerBar:getChildById('headerBattleBtn')
        equipBtn = headerBar:getChildById('headerEquipBtn')
        skillsBtn = headerBar:getChildById('headerSkillsBtn')

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

function toggleSkills()
    pcall(function()
        -- Check if custom skills module exists
        if modules.game_skills_custom then
            modules.game_skills_custom.toggleSkills()
        end
    end)
end

-- Public API: let other modules sync their button state
function setBattleButtonState(isOn)
    updateButtonState(battleBtn, isOn)
end

function setEquipmentButtonState(isOn)
    updateButtonState(equipBtn, isOn)
end