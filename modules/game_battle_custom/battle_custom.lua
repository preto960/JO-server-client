local customWindow = nil
local contentsPanel = nil
local origBattlePanelParent = nil
local origToggleButton = nil
local isOpen = false

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
        contentsPanel = customWindow:recursiveGetChildById('contentsPanel')

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
        restorePanel()
    end

    if origToggleButton then
        origToggleButton.onClick = nil
        origToggleButton = nil
    end

    if customWindow then
        customWindow:destroy()
        customWindow = nil
    end

    isOpen = false
end

function onGameStart()
    addEvent(function()
        pcall(function()
            local root = g_ui.getRootWidget()
            origToggleButton = root:recursiveGetChildById('battleButton')
            if origToggleButton then
                origToggleButton.onClick = function()
                    toggleBattle()
                end
            end
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
    if origToggleButton then
        origToggleButton.onClick = nil
        origToggleButton = nil
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
    if not contentsPanel then return end

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
    moveOriginalPanelToCustom()

    customWindow:show()
    customWindow:raise()
    customWindow:focus()
    isOpen = true

    if origToggleButton then origToggleButton:setOn(true) end
end

function closeBattle()
    if not isOpen then return end

    if dragInfo.active then stopWindowDrag() end

    local pos = customWindow:getPosition()
    g_settings.set('battleCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))

    restorePanel()
    showOriginalBattleWindow()

    customWindow:hide()
    isOpen = false

    if origToggleButton then origToggleButton:setOn(false) end
end

function moveOriginalPanelToCustom()
    local root = g_ui.getRootWidget()
    local origBattlePanel = root:recursiveGetChildById('battlePanel')
    if not origBattlePanel then
        g_logger.warning("[BattleCustom] orig battlePanel widget not found")
        return
    end

    local parent = origBattlePanel:getParent()
    if not parent then return end

    if parent == contentsPanel then return end

    origBattlePanelParent = parent
    parent:removeChild(origBattlePanel)
    contentsPanel:addChild(origBattlePanel)

    g_logger.warning("[BattleCustom] moved battlePanel to custom window, children: " .. #origBattlePanel:getChildren())
end

function restorePanel()
    if not origBattlePanelParent then return end

    pcall(function()
        local root = g_ui.getRootWidget()
        local origBattlePanel = root:recursiveGetChildById('battlePanel')
        if not origBattlePanel then return end

        local currentParent = origBattlePanel:getParent()
        if currentParent and currentParent ~= origBattlePanelParent then
            currentParent:removeChild(origBattlePanel)
            origBattlePanelParent:addChild(origBattlePanel)
        end
    end)

    origBattlePanelParent = nil
end

function hideOriginalBattleWindow()
    pcall(function()
        local root = g_ui.getRootWidget()
        local origWindow = root:recursiveGetChildById('battleWindow')
        if origWindow then
            origWindow:hide()
        end
    end)
end

function showOriginalBattleWindow()
    pcall(function()
        local root = g_ui.getRootWidget()
        local origWindow = root:recursiveGetChildById('battleWindow')
        if origWindow then
            origWindow:show()
        end
    end)
end

function onFilterButtonClick(button)
    button:setChecked(not button:isChecked())

    pcall(function()
        local root = g_ui.getRootWidget()
        local btnId = button:getId()
        local origButton = root:recursiveGetChildById(btnId)
        if origButton and origButton ~= button then
            origButton:setChecked(button:isChecked())
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