-- chat_custom.lua - Custom chat popup for JO Server
-- Uses separate popup (open worked fine), close only hides popup
-- contentPanel stays inside popup between open/close cycles
-- No reparenting on close = no crash

local chatPopup = nil
local isOpen = false
local savedWidgets = {}
local originalOnTabChange = nil
local sidebarButtons = {}

local THEME = {
    tabBg = '#1C1C38',
    tabSelectedBg = '#282848',
    tabSelectedBorder = '#3A3A60',
    tabText = '#686880',
    tabSelectedText = '#C0C0D0',
    contentBg = '#101024',
    bufferBg = '#0E0E20',
    scrollThumb = '#3A3A5888',
}

function init()
    local ok = pcall(function()
        chatPopup = g_ui.loadUI('chat_custom')
    end)
    if not ok or not chatPopup then return end

    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end
        if not chatPopup:getParent() then
            root:addChild(chatPopup)
        end
        chatPopup:hide()

        -- Close button via Lua (not @onClick in OTUI)
        local closeBtn = chatPopup:recursiveGetChildById('chatCloseButton')
        if closeBtn then
            closeBtn.onMouseRelease = function(self, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    closeChatPopup()
                end
            end
        end

        local consolePanel = root:recursiveGetChildById('consolePanel')
        if not consolePanel then return end

        g_keyboard.unbindKeyDown('Enter', consolePanel)
        g_keyboard.unbindKeyDown('Escape', consolePanel)
        g_keyboard.bindKeyDown('Enter', onEnterPressed, consolePanel)
        g_keyboard.bindKeyDown('Escape', onEscapePressed, consolePanel)

        pcall(function()
            connect(g_game, { onGameEnd = onGameEnd })
        end)
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

    pcall(function()
        disconnect(g_game, { onGameEnd = onGameEnd })
    end)

    -- If open, reparent back before destroying
    if isOpen then
        forceRestoreAndClose()
    end

    if chatPopup then
        chatPopup:destroy()
        chatPopup = nil
    end
end

function onEnterPressed()
    if not g_game.isOnline() then return end
    if not isOpen then
        openChatPopup()
    else
        local input = chatPopup:recursiveGetChildById('chatInput')
        if input then
            local text = input:getText()
            if text and #text > 0 then
                sendChatMessage()
            else
                input:focus()
            end
        end
    end
end

function onEscapePressed()
    if not g_game.isOnline() then return end
    if isOpen then
        closeChatPopup()
    end
end

function onGameEnd()
    if isOpen then
        forceRestoreAndClose()
    end
end

function openChatPopup()
    local root = g_ui.getRootWidget()
    if not root then return end

    local consolePanel = root:recursiveGetChildById('consolePanel')
    if not consolePanel then return end

    local tabBar = consolePanel:getChildById('consoleTabBar')
    local contentPanel = consolePanel:getChildById('consoleContentPanel')

    savedWidgets = {
        tabBar = tabBar,
        contentPanel = contentPanel,
        consolePanel = consolePanel,
    }

    consolePanel:hide()

    g_keyboard.unbindKeyDown('Enter', consolePanel)
    g_keyboard.unbindKeyDown('Escape', consolePanel)
    g_keyboard.bindKeyDown('Enter', onEnterPressed, chatPopup)
    g_keyboard.bindKeyDown('Escape', onEscapePressed, chatPopup)

    -- Move contentPanel into popup (this worked before, no crash)
    if contentPanel then
        contentPanel:breakAnchors()
        local slot = chatPopup:recursiveGetChildById('chatContentSlot')
        if slot then
            slot:addChild(contentPanel)
            contentPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
            contentPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            contentPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
            contentPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
            contentPanel:setMargin(0)
            contentPanel:setPadding(0)
        end
        pcall(function()
            contentPanel:setBackgroundColor(THEME.contentBg)
            contentPanel:setBorderWidth(0)
            contentPanel:setBorderColor('transparent')
            contentPanel:setImageSource('')
        end)
    end

    restyleAllTabPanels(tabBar)
    buildSidebar()

    if tabBar then
        originalOnTabChange = tabBar.onTabChange
        tabBar.onTabChange = function(self, tab)
            buildSidebar()
            if tab.tabPanel then
                restyleTabPanelBuffer(tab.tabPanel)
            end
            if originalOnTabChange then
                originalOnTabChange(self, tab)
            end
        end
    end

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
    if not isOpen then return end
    isOpen = false

    local consolePanel = savedWidgets.consolePanel

    if savedWidgets.tabBar then
        pcall(function()
            savedWidgets.tabBar.onTabChange = originalOnTabChange
        end)
        originalOnTabChange = nil
    end

    pcall(function()
        g_keyboard.unbindKeyDown('Enter', chatPopup)
    end)
    pcall(function()
        g_keyboard.unbindKeyDown('Escape', chatPopup)
    end)

    -- Destroy sidebar buttons safely (break anchors first)
    destroySidebarButtons()

    -- Just hide popup and show consolePanel
    -- contentPanel stays inside popup - NO reparenting, NO crash
    pcall(function()
        chatPopup:hide()
    end)

    -- Restore tab styles while they're still in the popup
    restoreTabStyles(savedWidgets.tabBar)

    pcall(function()
        consolePanel:show()
    end)

    -- Rebind keys
    if consolePanel then
        g_keyboard.bindKeyDown('Enter', onEnterPressed, consolePanel)
        g_keyboard.bindKeyDown('Escape', onEscapePressed, consolePanel)
    end

    savedWidgets = {}
end

-- Only used by terminate() and onGameEnd() when we MUST restore contentPanel
function forceRestoreAndClose()
    if not isOpen then return end
    isOpen = false

    local tabBar = savedWidgets.tabBar
    local contentPanel = savedWidgets.contentPanel
    local consolePanel = savedWidgets.consolePanel

    if tabBar then
        pcall(function()
            tabBar.onTabChange = originalOnTabChange
        end)
        originalOnTabChange = nil
    end

    pcall(function()
        g_keyboard.unbindKeyDown('Enter', chatPopup)
    end)
    pcall(function()
        g_keyboard.unbindKeyDown('Escape', chatPopup)
    end)

    destroySidebarButtons()
    restoreTabStyles(tabBar)

    -- Reparent contentPanel back (only on terminate/gameEnd)
    if contentPanel and consolePanel then
        pcall(function() contentPanel:breakAnchors() end)
        pcall(function() consolePanel:addChild(contentPanel) end)
        pcall(function() contentPanel:addAnchor(AnchorTop, 'parent', AnchorTop) end)
        pcall(function() contentPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft) end)
        pcall(function() contentPanel:addAnchor(AnchorRight, 'parent', AnchorRight) end)
        pcall(function() contentPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom) end)
        pcall(function()
            contentPanel:setMarginLeft(3)
            contentPanel:setMarginRight(2)
            contentPanel:setMarginBottom(26)
            contentPanel:setMarginTop(20)
            contentPanel:setPadding(1)
            contentPanel:setBackgroundColor('transparent')
        end)
    end

    pcall(function()
        chatPopup:hide()
    end)
    pcall(function()
        consolePanel:show()
    end)

    if consolePanel then
        pcall(function()
            g_keyboard.bindKeyDown('Enter', onEnterPressed, consolePanel)
        end)
        pcall(function()
            g_keyboard.bindKeyDown('Escape', onEscapePressed, consolePanel)
        end)
    end

    savedWidgets = {}
end

function getAllTabs(tabBar)
    local all = {}
    if not tabBar then return all end
    if tabBar.tabs then
        for _, t in ipairs(tabBar.tabs) do table.insert(all, t) end
    end
    if tabBar.preTabs then
        for _, t in ipairs(tabBar.preTabs) do table.insert(all, t) end
    end
    if tabBar.postTabs then
        for _, t in ipairs(tabBar.postTabs) do table.insert(all, t) end
    end
    return all
end

function buildSidebar()
    local sidebar = chatPopup:recursiveGetChildById('chatTabSidebar')
    if not sidebar then return end
    local tabBar = savedWidgets.tabBar
    if not tabBar then return end

    destroySidebarButtons()

    local allTabs = getAllTabs(tabBar)
    for i, tab in ipairs(allTabs) do
        local ok, btn = pcall(function()
            return g_ui.createWidget('UIButton', sidebar)
        end)
        if ok and btn then
            local text = ''
            pcall(function() text = tab:getText() end)

            pcall(function()
                btn:setHeight(28)
                btn:setText(text)
                btn:setFont('verdana-11px-rounded')
                btn:setImageSource('')
                btn:setBorderWidth(0)
                btn:setBorderColor('transparent')
                btn:setPaddingLeft(8)
                btn:setPaddingRight(6)
                -- Use parent anchor + marginTop (no 'prev' reference)
                btn:addAnchor(AnchorTop, 'parent', AnchorTop)
                btn:addAnchor(AnchorLeft, 'parent', AnchorLeft)
                btn:addAnchor(AnchorRight, 'parent', AnchorRight)
                btn:setMarginTop(1 + (i - 1) * 29)
            end)

            sidebarButtons[tab] = btn

            local tabRef = tab
            btn.onMouseRelease = function(self, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    pcall(function()
                        tabBar:selectTab(tabRef)
                        updateSidebarHighlight(tabRef)
                    end)
                end
            end
        end
    end

    updateSidebarHighlight(nil)
end

function destroySidebarButtons()
    -- Break ALL anchors first, then destroy
    for _, btn in pairs(sidebarButtons) do
        pcall(function() btn:breakAnchors() end)
    end
    for _, btn in pairs(sidebarButtons) do
        pcall(function() btn:destroy() end)
    end
    sidebarButtons = {}
end

function updateSidebarHighlight(selectedTab)
    if not selectedTab then
        local tabBar = savedWidgets.tabBar
        pcall(function()
            selectedTab = tabBar:getCurrentTab()
        end)
    end

    for tab, btn in pairs(sidebarButtons) do
        pcall(function()
            local isSel = (tab == selectedTab)
            if isSel then
                btn:setBackgroundColor(THEME.tabSelectedBg)
                btn:setBorderColor(THEME.tabSelectedBorder)
                btn:setBorderWidth(1)
                btn:setColor(THEME.tabSelectedText)
            else
                btn:setBackgroundColor(THEME.tabBg)
                btn:setBorderWidth(0)
                btn:setBorderColor('transparent')
                btn:setColor(THEME.tabText)
            end
        end)
    end
end

function restyleAllTabPanels(tabBar)
    if not tabBar then return end
    local allTabs = getAllTabs(tabBar)
    for _, tab in ipairs(allTabs) do
        if tab.tabPanel then
            restyleTabPanelBuffer(tab.tabPanel)
        end
    end
end

function restyleTabPanelBuffer(panel)
    pcall(function()
        panel:setBackgroundColor(THEME.contentBg)
        panel:setBorderWidth(0)
        panel:setBorderColor('transparent')
        panel:setPadding(0)
    end)

    local buffer = panel:getChildById('consoleBuffer')
    if buffer then
        pcall(function()
            buffer:setImageSource('')
            buffer:setBackgroundColor(THEME.bufferBg)
            buffer:setBorderWidth(0)
            buffer:setBorderColor('transparent')
            buffer:setPadding(6)
            buffer:setPaddingRight(14)
        end)

        local labels = buffer:getChildren()
        for _, label in ipairs(labels) do
            pcall(function()
                label:setBackgroundColor('transparent')
                label:setBorderWidth(0)
            end)
        end
    end

    restyleScrollbar(panel:getChildById('consoleScrollBar'))
end

function restyleScrollbar(scrollBar)
    if not scrollBar then return end
    pcall(function()
        scrollBar:setWidth(8)
        scrollBar:setMarginRight(2)
        scrollBar:setMarginTop(2)
        scrollBar:setMarginBottom(2)
        scrollBar:setBackgroundColor('transparent')
    end)

    local children = scrollBar:getChildren()
    for _, child in ipairs(children) do
        pcall(function()
            child:setImageSource('')
            child:setBackgroundColor(THEME.scrollThumb)
            child:setBorderWidth(0)
        end)
    end
end

function restoreTabStyles(tabBar)
    if not tabBar then return end
    local allTabs = getAllTabs(tabBar)
    for _, tab in ipairs(allTabs) do
        pcall(function()
            tab:setImageSource('/images/ui/console_button')
            tab:setBackgroundColor('transparent')
            tab:setBorderWidth(0)
            tab:setBorderColor('transparent')
            tab:setColor('#7f7f7fff')
            tab:setFont('verdana-11px-rounded')
            tab:setMarginTop(0)
            tab:setMarginBottom(0)
            tab:setMarginLeft(0)
            tab:setMarginRight(0)
        end)
        if tab.tabPanel then
            restoreTabPanelBuffer(tab.tabPanel)
        end
    end
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
        local children = scrollBar:getChildren()
        for _, child in ipairs(children) do
            pcall(function()
                child:setBackgroundColor('')
            end)
        end
    end
end

function centerWindow()
    if chatPopup then
        local gw = g_window
        if gw then
            local x = (gw.getWidth() - chatPopup:getWidth()) / 2
            local y = (gw.getHeight() - chatPopup:getHeight()) / 2
            chatPopup:setPosition({ x = x, y = y })
        end
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
