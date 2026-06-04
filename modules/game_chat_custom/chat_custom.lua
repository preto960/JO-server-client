-- chat_custom.lua - Custom chat popup for JO Server
-- Opens a floating chat window on Enter with real tabs and messages
-- Loaded via interface.otmod load-later (after game_console)

local chatPopup = nil
local isOpen = false
local savedWidgets = {}

function init()
    local ok = pcall(function()
        chatPopup = g_ui.loadUI('chat_custom')
    end)
    if not ok or not chatPopup then
        return
    end

    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        if not chatPopup:getParent() then
            root:addChild(chatPopup)
        end
        chatPopup:hide()

        local consolePanel = root:recursiveGetChildById('consolePanel')
        if not consolePanel then return end

        g_keyboard.unbindKeyDown('Enter', consolePanel)
        g_keyboard.unbindKeyDown('Escape', consolePanel)
        g_keyboard.bindKeyDown('Enter', onEnterPressed, consolePanel)
        g_keyboard.bindKeyDown('Escape', onEscapePressed, consolePanel)
    end)
end

function terminate()
    local root = g_ui.getRootWidget()
    if root then
        local consolePanel = root:recursiveGetChildById('consolePanel')
        if consolePanel then
            g_keyboard.unbindKeyDown('Enter', consolePanel)
            g_keyboard.unbindKeyDown('Escape', consolePanel)
            pcall(function()
                g_keyboard.bindKeyDown('Enter', modules.game_console.switchChatOnCall, consolePanel)
                g_keyboard.bindKeyDown('Escape', modules.game_console.disableChatOnCall, consolePanel)
            end)
        end
    end

    if isOpen then
        restoreWidgets()
    end

    if chatPopup then
        chatPopup:destroy()
        chatPopup = nil
    end
end

function onEnterPressed()
    if not g_game.isOnline() then return end

    if isOpen then
        local input = chatPopup:recursiveGetChildById('chatInput')
        if input then
            local text = input:getText()
            if text and #text > 0 then
                sendChatMessage()
            else
                input:focus()
            end
        end
    else
        openChatPopup()
    end
end

function onEscapePressed()
    if not g_game.isOnline() then return end
    if isOpen then
        closeChatPopup()
    end
end

function openChatPopup()
    local root = g_ui.getRootWidget()
    if not root then return end

    local consolePanel = root:recursiveGetChildById('consolePanel')
    if not consolePanel then return end

    local tabBar = consolePanel:getChildById('consoleTabBar')
    local contentPanel = consolePanel:getChildById('consoleContentPanel')
    local textEdit = consolePanel:getChildById('consoleTextEdit')

    -- Save original parent for later restore
    savedWidgets = {
        tabBar = tabBar,
        contentPanel = contentPanel,
        consolePanel = consolePanel,
    }

    -- Hide original console elements we don't want visible
    if textEdit then textEdit:hide() end
    local toggleChat = consolePanel:getChildById('toggleChat')
    if toggleChat then toggleChat:hide() end

    -- Hide original console buttons
    local hideIds = {
        'prevChannelButton', 'nextChannelButton', 'closeChannelButton',
        'channelsButton', 'ignoreButton', 'exivaOption',
        'readOnlyButton', 'sayModeButton', 'extendedViewDraggable',
        'extendedViewHide'
    }
    for _, id in ipairs(hideIds) do
        local w = consolePanel:getChildById(id)
        if w then w:hide() end
    end

    -- Reparent consoleTabBar into our popup's slot
    if tabBar then
        tabBar:breakAnchors()
        local slot = chatPopup:recursiveGetChildById('chatTabBarSlot')
        if slot then
            slot:addChild(tabBar)
        end
        tabBar:setMarginTop(2)
        tabBar:setMarginLeft(18)
        tabBar:setMarginRight(20)
    end

    -- Reparent consoleContentPanel into our popup's content slot
    if contentPanel then
        contentPanel:breakAnchors()
        local slot = chatPopup:recursiveGetChildById('chatContentSlot')
        if slot then
            slot:addChild(contentPanel)
        end
        contentPanel:setMargin(0)
        contentPanel:setPadding(4)
    end

    -- Show popup
    if not chatPopup:getParent() then
        root:addChild(chatPopup)
    end
    chatPopup:show()
    chatPopup:raise()

    local input = chatPopup:recursiveGetChildById('chatInput')
    if input then
        input:focus()
    end

    centerWindow()
    isOpen = true
end

function closeChatPopup()
    restoreWidgets()
    chatPopup:hide()
    isOpen = false
end

function restoreWidgets()
    local root = g_ui.getRootWidget()
    if not root then return end

    local tabBar = savedWidgets.tabBar
    local contentPanel = savedWidgets.contentPanel
    local consolePanel = savedWidgets.consolePanel
    if not consolePanel then return end

    -- Restore tabBar to consolePanel
    if tabBar and tabBar:getParent() ~= consolePanel then
        tabBar:breakAnchors()
        consolePanel:addChild(tabBar)
        tabBar:setMarginTop(0)
        tabBar:setMarginBottom(-7)
        tabBar:setMarginLeft(18)
        tabBar:setMarginRight(20)
        tabBar:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        tabBar:addAnchor(AnchorBottom, 'consoleContentPanel', AnchorTop)
        tabBar:addAnchor(AnchorRight, 'closeChannelButton', AnchorLeft)
    end

    -- Restore contentPanel to consolePanel
    if contentPanel and contentPanel:getParent() ~= consolePanel then
        contentPanel:breakAnchors()
        consolePanel:addChild(contentPanel)
        contentPanel:setMarginLeft(3)
        contentPanel:setMarginRight(2)
        contentPanel:setMarginBottom(4)
        contentPanel:setMarginTop(20)
        contentPanel:setPadding(1)
        contentPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
        contentPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        contentPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
        contentPanel:addAnchor(AnchorBottom, 'consoleTextEdit', AnchorTop)
    end

    -- Restore original elements visibility
    local textEdit = consolePanel:getChildById('consoleTextEdit')
    if textEdit then textEdit:show() end
    local toggleChat = consolePanel:getChildById('toggleChat')
    if toggleChat then toggleChat:show() end

    local showIds = {
        'prevChannelButton', 'nextChannelButton', 'closeChannelButton',
        'channelsButton', 'ignoreButton', 'exivaOption',
        'readOnlyButton', 'sayModeButton', 'extendedViewDraggable',
        'extendedViewHide'
    }
    for _, id in ipairs(showIds) do
        local w = consolePanel:getChildById(id)
        if w then w:show() end
    end

    savedWidgets = {}
end

function centerWindow()
    local gw = g_window
    if gw then
        local x = (gw.getWidth() - chatPopup:getWidth()) / 2
        local y = (gw.getHeight() - chatPopup:getHeight()) / 2
        chatPopup:setPosition({ x = x, y = y })
    end
end

function sendChatMessage()
    local input = chatPopup:recursiveGetChildById('chatInput')
    if not input then return end

    local message = input:getText()
    if not message or #message == 0 then return end

    pcall(function()
        modules.game_console.sendMessage(message)
    end)

    input:clearText()
end
