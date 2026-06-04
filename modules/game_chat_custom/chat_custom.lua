-- chat_custom.lua - Custom chat popup for JO Server
-- Opens a floating chat window on Enter with restyled tabs and messages
-- Loaded via interface.otmod load-later (after game_console)

local chatPopup = nil
local isOpen = false
local savedWidgets = {}
local originalOnTabChange = nil

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

    savedWidgets = {
        tabBar = tabBar,
        contentPanel = contentPanel,
        consolePanel = consolePanel,
    }

    -- Hide the entire original console panel (frame, empty space, etc.)
    consolePanel:hide()
    -- Keep textEdit reference for restore
    if textEdit then savedWidgets.textEdit = textEdit end
    local toggleChat = consolePanel:getChildById('toggleChat')
    if toggleChat then savedWidgets.toggleChat = toggleChat end

    -- No need to individually hide buttons since we hide the whole consolePanel

    -- Reparent and restyle tab bar
    if tabBar then
        tabBar:breakAnchors()
        local slot = chatPopup:recursiveGetChildById('chatTabBarSlot')
        if slot then
            slot:addChild(tabBar)
        end
        tabBar:setMarginTop(0)
        tabBar:setMarginLeft(4)
        tabBar:setMarginRight(4)
        tabBar:setMarginBottom(0)

        pcall(function()
            tabBar:setBackgroundColor('#181830')
        end)

        -- Restyle every tab button (including preTabs and postTabs)
        local allTabs = {}
        if tabBar.tabs then
            for _, t in ipairs(tabBar.tabs) do table.insert(allTabs, t) end
        end
        if tabBar.preTabs then
            for _, t in ipairs(tabBar.preTabs) do table.insert(allTabs, t) end
        end
        if tabBar.postTabs then
            for _, t in ipairs(tabBar.postTabs) do table.insert(allTabs, t) end
        end

        for _, tab in ipairs(allTabs) do
            pcall(function()
                tab:setImageSource('')
                tab:setBackgroundColor('#252540')
                tab:setBorderWidth(1)
                tab:setBorderColor('#2E2E48')
                tab:setBorderRadius(4)
                tab:setColor('#8888A0')
                tab:setFont('verdana-11px-rounded')
                tab:setMarginTop(3)
                tab:setMarginBottom(3)
                tab:setMarginLeft(2)
                tab:setMarginRight(2)
            end)
        end
    end

    -- Reparent and restyle content panel
    if contentPanel then
        contentPanel:breakAnchors()
        local slot = chatPopup:recursiveGetChildById('chatContentSlot')
        if slot then
            slot:addChild(contentPanel)
        end
        contentPanel:setMargin(0)
        contentPanel:setPadding(0)
        contentPanel:setMarginTop(0)
        contentPanel:setMarginBottom(0)
        contentPanel:setMarginLeft(0)
        contentPanel:setMarginRight(0)

        pcall(function()
            contentPanel:setBackgroundColor('#14142A')
            contentPanel:setBorderWidth(0)
            contentPanel:setBorderColor('transparent')
        end)
    end

    -- Restyle ALL tab panels (each tab has a tabPanel with consoleBuffer)
    restyleAllTabPanels(tabBar)

    -- Hook tab change to restyle new tab panels automatically
    if tabBar then
        originalOnTabChange = tabBar.onTabChange
        tabBar.onTabChange = function(self, tab)
            if tab.tabPanel then
                restyleTabPanelBuffer(tab.tabPanel)
            end
            -- Restyle the new tab button itself
            pcall(function()
                tab:setImageSource('')
                tab:setBackgroundColor('#252540')
                tab:setBorderWidth(1)
                tab:setBorderColor('#2E2E48')
                tab:setBorderRadius(4)
                tab:setColor('#8888A0')
                tab:setFont('verdana-11px-rounded')
                tab:setMarginTop(3)
                tab:setMarginBottom(3)
                tab:setMarginLeft(2)
                tab:setMarginRight(2)
            end)
            -- Call original handler if exists
            if originalOnTabChange then
                originalOnTabChange(self, tab)
            end
        end
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

function restyleAllTabPanels(tabBar)
    if not tabBar then return end

    local allTabs = {}
    if tabBar.tabs then
        for _, t in ipairs(tabBar.tabs) do table.insert(allTabs, t) end
    end
    if tabBar.preTabs then
        for _, t in ipairs(tabBar.preTabs) do table.insert(allTabs, t) end
    end
    if tabBar.postTabs then
        for _, t in ipairs(tabBar.postTabs) do table.insert(allTabs, t) end
    end

    for _, tab in ipairs(allTabs) do
        if tab.tabPanel then
            restyleTabPanelBuffer(tab.tabPanel)
        end
    end
end

function restyleTabPanelBuffer(panel)
    pcall(function()
        -- Restyle the panel background
        panel:setBackgroundColor('#14142A')
        panel:setBorderWidth(0)
        panel:setBorderColor('transparent')
        panel:setPadding(0)
    end)

    -- Restyle the ScrollablePanel (consoleBuffer) inside this tab panel
    local buffer = panel:getChildById('consoleBuffer')
    if buffer then
        pcall(function()
            buffer:setImageSource('')
            buffer:setBackgroundColor('#14142A')
            buffer:setBorderWidth(0)
            buffer:setBorderColor('transparent')
            buffer:setPadding(6)
            buffer:setPaddingRight(14)
            buffer:setPaddingLeft(6)
            buffer:setPaddingTop(6)
            buffer:setPaddingBottom(6)
        end)

        -- Restyle existing console labels (message lines)
        local labels = buffer:getChildren()
        for _, label in ipairs(labels) do
            pcall(function()
                -- Keep original message colors, just ensure background is transparent
                label:setBackgroundColor('transparent')
                label:setBorderWidth(0)
            end)
        end
    end

    -- Restyle the scrollbar
    local scrollBar = panel:getChildById('consoleScrollBar')
    if scrollBar then
        pcall(function()
            scrollBar:setMarginRight(2)
            scrollBar:setMarginTop(2)
            scrollBar:setMarginBottom(2)
        end)
    end
end

function closeChatPopup()
    -- Restore original onTabChange handler
    local tabBar = savedWidgets.tabBar
    if tabBar then
        tabBar.onTabChange = originalOnTabChange
        originalOnTabChange = nil
    end
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

    -- Restore tabBar
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
        tabBar:setBackgroundColor('transparent')
    end

    -- Restore tab button styles
    local allTabs = {}
    if tabBar and tabBar.tabs then
        for _, t in ipairs(tabBar.tabs) do table.insert(allTabs, t) end
    end
    if tabBar and tabBar.preTabs then
        for _, t in ipairs(tabBar.preTabs) do table.insert(allTabs, t) end
    end
    if tabBar and tabBar.postTabs then
        for _, t in ipairs(tabBar.postTabs) do table.insert(allTabs, t) end
    end

    for _, tab in ipairs(allTabs) do
        pcall(function()
            tab:setImageSource('/images/ui/console_button')
            tab:setBackgroundColor('transparent')
            tab:setBorderWidth(0)
            tab:setBorderColor('transparent')
            tab:setBorderRadius(0)
            tab:setColor('#7f7f7fff')
            tab:setFont('verdana-11px-rounded')
            tab:setMarginTop(0)
            tab:setMarginBottom(0)
            tab:setMarginLeft(0)
            tab:setMarginRight(0)
        end)

        -- Restore tab panel buffer styles
        if tab.tabPanel then
            restoreTabPanelBuffer(tab.tabPanel)
        end
    end

    -- Restore contentPanel
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
        contentPanel:setBackgroundColor('transparent')
    end

    -- Show the entire console panel back (restores all children visibility)
    consolePanel:show()

    savedWidgets = {}
end

function restoreTabPanelBuffer(panel)
    pcall(function()
        panel:setBackgroundColor('transparent')
        panel:setPadding(0)
    end)

    local buffer = panel:getChildById('consoleBuffer')
    if buffer then
        pcall(function()
            buffer:setImageSource('/images/ui/3pixel_frame_borderimage')
            buffer:setBackgroundColor('transparent')
            buffer:setPadding(1)
            buffer:setPaddingRight(12)
            buffer:setPaddingLeft(4)
            buffer:setPaddingTop(4)
            buffer:setPaddingBottom(4)
        end)
    end

    local scrollBar = panel:getChildById('consoleScrollBar')
    if scrollBar then
        pcall(function()
            scrollBar:setMarginTop(4)
            scrollBar:setMarginBottom(4)
            scrollBar:setMarginRight(4)
        end)
    end
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
