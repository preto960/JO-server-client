local customWindow = nil
local contentsPanel = nil
local titleBar = nil
local battlePanelRef = nil
local battlePanelOriginalParent = nil
local originalBattleHandler = nil

isOpen = false

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

    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        if not customWindow:getParent() then
            root:addChild(customWindow)
        end

        contentsPanel = customWindow:getChildById('contentsPanel')
        titleBar = customWindow:getChildById('titleBar')

        -- Default position
        local savedPos = g_settings.getPoint('battleCustomWindow/position')
        if savedPos then
            pcall(function() customWindow:setPosition(savedPos) end)
        else
            pcall(function()
                customWindow:setX(10)
                customWindow:setY(100)
            end)
        end
        customWindow:hide()

        -- Title bar drag
        if titleBar then
            titleBar.onMousePress = function(widget, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    startWindowDrag(customWindow, mousePos)
                end
            end
        end

        -- ESC to close
        customWindow.onKeyPress = function(widget, keyCode, keyboardModifiers)
            if keyboardModifiers == KeyboardNoModifier and keyCode == KeyEscape then
                if isOpen then
                    closeBattle()
                    return true
                end
            end
        end

        -- Hijack the original battleButton in the sidebar (like skills_custom does)
        local battleBtn = root:recursiveGetChildById('battleButton')
        if battleBtn then
            originalBattleHandler = battleBtn.onMouseRelease
            battleBtn.onMouseRelease = function(widget, mousePos, mouseButton)
                if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                    toggleBattle()
                    return true
                end
            end
            g_logger.info("[BattleCustom] Hijacked battleButton")
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

    -- Restore original battle button handler
    if originalBattleHandler then
        local root = g_ui.getRootWidget()
        if root then
            local battleBtn = root:recursiveGetChildById('battleButton')
            if battleBtn then
                battleBtn.onMouseRelease = originalBattleHandler
            end
        end
    end

    -- Restore battle panel if still moved
    if isOpen and battlePanelRef and battlePanelOriginalParent then
        restorePanel()
    end

    if customWindow then
        if customWindow:getParent() then
            local pos = customWindow:getPosition()
            g_settings.set('battleCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))
        end
        customWindow:destroy()
        customWindow = nil
    end
    isOpen = false
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

function moveOriginalPanelToCustom()
    local root = g_ui.getRootWidget()
    if not root then return false end

    local origWindow = root:recursiveGetChildById('battleWindow')
    if not origWindow then return false end

    local battlePanel = origWindow:recursiveGetChildById('battlePanel')
    if not battlePanel then return false end

    battlePanelOriginalParent = battlePanel:getParent()
    battlePanelRef = battlePanel

    contentsPanel:addChild(battlePanel)
    battlePanel:setMarginTop(0)

    return true
end

function restorePanel()
    if not battlePanelRef or not battlePanelOriginalParent then return end
    if battlePanelRef:isDestroyed() then return end

    battlePanelOriginalParent:addChild(battlePanelRef)
    battlePanelRef:setMarginTop(5)

    battlePanelRef = nil
    battlePanelOriginalParent = nil
end

function openBattle()
    if not customWindow then return end
    if not g_game.isOnline() then return end

    -- Hide original battle window
    pcall(function()
        local root = g_ui.getRootWidget()
        local origWindow = root:recursiveGetChildById('battleWindow')
        if origWindow then origWindow:hide() end
    end)

    -- Move original battle panel into our window
    if not battlePanelRef or (battlePanelRef and battlePanelRef:isDestroyed()) then
        moveOriginalPanelToCustom()
    end

    if not customWindow:getParent() then
        local root = g_ui.getRootWidget()
        if root then root:addChild(customWindow) end
    end

    customWindow:show()
    customWindow:raise()
    customWindow:focus()
    isOpen = true

    -- Sync sidebar button state
    pcall(function()
        local root = g_ui.getRootWidget()
        local btn = root:recursiveGetChildById('battleButton')
        if btn then btn:setOn(true) end
    end)

    -- Notify headerbar if loaded
    pcall(function()
        if modules.game_headerbar then
            modules.game_headerbar.setBattleButtonState(true)
        end
    end)
end

function closeBattle()
    if not isOpen then return end
    isOpen = false

    if dragInfo.active then
        stopWindowDrag()
    end

    restorePanel()

    local pos = customWindow:getPosition()
    g_settings.set('battleCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))

    customWindow:hide()

    -- Sync sidebar button state
    pcall(function()
        local root = g_ui.getRootWidget()
        local btn = root:recursiveGetChildById('battleButton')
        if btn then btn:setOn(false) end
    end)

    pcall(function()
        if modules.game_headerbar then
            modules.game_headerbar.setBattleButtonState(false)
        end
    end)
end

function toggleBattle()
    if isOpen then
        closeBattle()
    else
        openBattle()
    end
end

function onGameStart()
    addEvent(function()
        -- Re-hijack button in case it was recreated
        local root = g_ui.getRootWidget()
        if root then
            local battleBtn = root:recursiveGetChildById('battleButton')
            if battleBtn then
                battleBtn.onMouseRelease = function(widget, mousePos, mouseButton)
                    if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                        toggleBattle()
                        return true
                    end
                end
            end

            -- Hide original battle window
            local origWindow = root:recursiveGetChildById('battleWindow')
            if origWindow then
                origWindow:hide()
            end
        end
    end)
end

function onGameEnd()
    if isOpen then
        restorePanel()
        customWindow:hide()
    end
    isOpen = false
end