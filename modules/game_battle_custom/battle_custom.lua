local customWindow = nil
local customPanel = nil
local isOpen = false
local sidebarButton = nil

local dragInfo = {
    active = false,
    widget = nil,
    overlay = nil,
    startPos = {x=0, y=0},
    startMouse = {x=0, y=0}
}

function init()
    local ok = pcall(function()
        customWindow = g_ui.loadUI('battle_custom')
    end)
    if not ok or not customWindow then
        g_logger.warning("[BattleCustom] Failed to load battle_custom.otui")
        return
    end

    g_logger.warning("[BattleCustom] Module loaded")

    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        if not customWindow:getParent() then
            root:addChild(customWindow)
        end

        pcall(function()
            local rw = root:getWidth()
            local rh = root:getHeight()
            customWindow:setX(rw - customWindow:getWidth() - 20)
            customWindow:setY(math.floor((rh - customWindow:getHeight()) / 2))
        end)

        customWindow:hide()
        customPanel = customWindow:recursiveGetChildById('battlePanel')

        local titleBar = customWindow:getChildById('titleBar')
        if titleBar then
            titleBar.onMousePress = function(widget, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    startWindowDrag(customWindow, mousePos)
                end
            end
        end

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

    if isOpen then
        moveButtonsBack()
    end

    if customWindow then
        customWindow:destroy()
        customWindow = nil
    end

    if sidebarButton then
        pcall(function() sidebarButton:destroy() end)
        sidebarButton = nil
    end

    isOpen = false
end

function onGameStart()
    addEvent(function()
        pcall(function()
            sidebarButton = modules.client_topmenu.addRightGameToggleButton(
                'battleCustomButton',
                'Battle (Ctrl+B)',
                '/images/options/button_battlelist',
                toggleBattle,
                false
            )
        end)
    end)

    g_keyboard.bindKeyDown('Ctrl+B', function()
        if g_game.isOnline() then
            toggleBattle()
        end
    end)
end

function onGameEnd()
    closeBattle()
    if sidebarButton then
        pcall(function() sidebarButton:destroy() end)
        sidebarButton = nil
    end
end

function toggleBattle()
    if isOpen then
        closeBattle()
    else
        openBattle()
    end
end

function openBattle()
    if not customWindow or not g_game.isOnline() then return end

    if not customWindow:getParent() then
        local root = g_ui.getRootWidget()
        if root then root:addChild(customWindow) end
    end

    pcall(function()
        local savedPos = g_settings.getPoint('battleCustomWindow/position')
        if savedPos and savedPos.x > 0 and savedPos.y > 0 then
            customWindow:setX(savedPos.x)
            customWindow:setY(savedPos.y)
        end
    end)

    hideOriginalBattleWindow()
    moveButtonsToCustom()

    customWindow:show()
    customWindow:raise()
    customWindow:focus()
    isOpen = true

    if sidebarButton then sidebarButton:setOn(true) end
end

function closeBattle()
    if not isOpen then return end

    if dragInfo.active then stopWindowDrag() end

    local pos = customWindow:getPosition()
    g_settings.set('battleCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))

    moveButtonsBack()
    showOriginalBattleWindow()

    customWindow:hide()
    isOpen = false

    if sidebarButton then sidebarButton:setOn(false) end
end

function hideOriginalBattleWindow()
    pcall(function()
        local root = g_ui.getRootWidget()
        local origWindow = root:recursiveGetChildById('battleWindow')
        if origWindow and origWindow:isVisible() then
            origWindow:close()
        end
        local origBtn = root:recursiveGetChildById('battleButton')
        if origBtn then origBtn:setOn(false) end
    end)
end

function showOriginalBattleWindow()
    pcall(function()
        local root = g_ui.getRootWidget()
        local origBtn = root:recursiveGetChildById('battleButton')
        if origBtn then origBtn:setOn(false) end
    end)
end

function moveButtonsToCustom()
    if not customPanel then return end

    pcall(function()
        local battle = modules.game_battle
        if not battle or not battle.BattleListManager then return end

        local mainInstance = battle.BattleListManager:getMainInstance()
        if not mainInstance or not mainInstance.panel then return end

        local origPanel = mainInstance.panel
        local children = origPanel:getChildren()
        for i = #children, 1, -1 do
            local child = children[i]
            if child:getId():find('CreatureButton') then
                origPanel:removeChild(child)
                customPanel:addChild(child)
            end
        end
    end)
end

function moveButtonsBack()
    if not customPanel then return end

    pcall(function()
        local battle = modules.game_battle
        if not battle or not battle.BattleListManager then return end

        local mainInstance = battle.BattleListManager:getMainInstance()
        if not mainInstance or not mainInstance.panel then return end

        local origPanel = mainInstance.panel
        local children = customPanel:getChildren()
        for i = #children, 1, -1 do
            local child = children[i]
            if child:getId():find('CreatureButton') then
                customPanel:removeChild(child)
                origPanel:addChild(child)
            end
        end
    end)
end

function onFilterButtonClick(button)
    button:setChecked(not button:isChecked())

    pcall(function()
        local battle = modules.game_battle
        if battle and battle.BattleListManager then
            local mainInstance = battle.BattleListManager:getMainInstance()
            if mainInstance then
                local origHideButtons = mainInstance.hideButtons
                if origHideButtons then
                    for id, widget in pairs(origHideButtons) do
                        local customWidget = customWindow:recursiveGetChildById(id)
                        if customWidget and widget then
                            customWidget:setChecked(widget:isChecked())
                        end
                    end
                end
                mainInstance:checkCreatures()
            end
        end
    end)
end

function startWindowDrag(window, mousePos)
    if dragInfo.active then return end
    local root = g_ui.getRootWidget()
    if not root then return end

    local overlay = g_ui.createWidget('UIWidget', root)
    overlay:setSize(root:getSize())
    overlay:setBackgroundColor('#00000000')
    overlay:focus()

    local winPos = window:getPosition()
    local mouseScreen = g_window.getMousePosition()

    dragInfo.active = true
    dragInfo.widget = window
    dragInfo.overlay = overlay
    dragInfo.startPos = {x = winPos.x, y = winPos.y}
    dragInfo.startMouse = {x = mouseScreen.x, y = mouseScreen.y}

    window:breakAnchors()

    overlay.onMouseMove = function(self, pos, moved)
        if dragInfo.active then
            local dx = pos.x - dragInfo.startMouse.x
            local dy = pos.y - dragInfo.startMouse.y
            pcall(function()
                dragInfo.widget:setX(dragInfo.startPos.x + dx)
                dragInfo.widget:setY(dragInfo.startPos.y + dy)
            end)
        end
    end

    overlay.onMouseRelease = function(self, pos, mouseButton)
        if mouseButton == MouseLeftButton then
            stopWindowDrag()
        end
    end
end

function stopWindowDrag()
    if not dragInfo.active then return end
    dragInfo.active = false

    if dragInfo.widget then
        local pos = dragInfo.widget:getPosition()
        g_settings.set('battleCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))
    end

    if dragInfo.overlay then
        dragInfo.overlay:destroy()
        dragInfo.overlay = nil
    end
    dragInfo.widget = nil

    if customWindow and customWindow:isVisible() then
        customWindow:focus()
    end
end