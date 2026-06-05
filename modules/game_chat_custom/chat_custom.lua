-- chat_custom.lua - Custom chat popup for JO Server
-- Modern dark-themed floating chat, press Enter to open/send

local chatPopup = nil
local isOpen = false
local savedWidgets = {}
local originalOnTabChange = nil

local THEME = {
    tabBarBg = '#14142C',
    tabBg = '#1C1C38',
    tabSelectedBg = '#282848',
    tabText = '#686880',
    tabSelectedText = '#C0C0D0',
    tabBorder = '#282844',
    tabBorderSelected = '#343460',
    contentBg = '#101024',
    bufferBg = '#0E0E20',
    bufferPadding = 6,
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
    if textEdit then savedWidgets.textEdit = textEdit end

    consolePanel:hide()

    if tabBar then
        tabBar:breakAnchors()
        local slot = chatPopup:recursiveGetChildById('chatTabBarSlot')
        if slot then
            slot:addChild(tabBar)
            tabBar:addAnchor(AnchorTop, 'parent', AnchorTop)
            tabBar:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            tabBar:addAnchor(AnchorRight, 'parent', AnchorRight)
            tabBar:setMargin(0)
        end
        pcall(function()
            tabBar:setBackgroundColor(THEME.tabBarBg)
        end)
        restyleAllTabs(tabBar)
    end

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

    if tabBar then
        originalOnTabChange = tabBar.onTabChange
        tabBar.onTabChange = function(self, tab)
            restyleAllTabs(tabBar)
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

function restyleTab(tab, isSelected)
    pcall(function()
        tab:setImageSource('')
        tab:setBorderWidth(1)
        tab:setBorderColor(isSelected and THEME.tabBorderSelected or THEME.tabBorder)
        tab:setBorderRadius(4)
        tab:setFont('verdana-11px-rounded')
        tab:setMarginTop(2)
        tab:setMarginBottom(2)
        tab:setMarginLeft(1)
        tab:setMarginRight(1)
        if isSelected then
            tab:setBackgroundColor(THEME.tabSelectedBg)
            tab:setColor(THEME.tabSelectedText)
        else
            tab:setBackgroundColor(THEME.tabBg)
            tab:setColor(THEME.tabText)
        end
    end)
end

function restyleAllTabs(tabBar)
    if not tabBar then return end
    local allTabs = getAllTabs(tabBar)
    for _, tab in ipairs(allTabs) do
        local selected = false
        pcall(function() selected = tab:isChecked() end)
        restyleTab(tab, selected)
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
            buffer:setPadding(THEME.bufferPadding)
            buffer:setPaddingRight(THEME.bufferPadding + 8)
        end)

        local labels = buffer:getChildren()
        for _, label in ipairs(labels) do
            pcall(function()
                label:setBackgroundColor('transparent')
                label:setBorderWidth(0)
            end)
        end
    end

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

    local allTabs = getAllTabs(tabBar)
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
        if tab.tabPanel then
            restoreTabPanelBuffer(tab.tabPanel)
        end
    end

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
