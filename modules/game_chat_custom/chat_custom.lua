-- chat_custom.lua - Custom chat popup for JO Server
-- Styles consolePanel AS the popup (zero reparenting approach)
-- contentPanel stays inside consolePanel at ALL times - no crashes

local isOpen = false
local savedWidgets = {}
local originalOnTabChange = nil
local sidebarWidget = nil
local sidebarButtons = {}
local closeButton = nil
local headerWidget = nil

local THEME = {
    tabBg = '#1C1C38',
    tabSelectedBg = '#282848',
    tabSelectedBorder = '#3A3A60',
    tabText = '#686880',
    tabSelectedText = '#C0C0D0',
    contentBg = '#101024',
    bufferBg = '#0E0E20',
    scrollThumb = '#3A3A5888',
    headerBg = '#13132ACC',
    popupBg = '#16162EBB',
    popupBorder = '#2A2A4066',
    sidebarBg = '#13132CCC',
    inputFieldBg = '#1C1C3EEE',
    inputFieldBorder = '#282840AA',
    inputText = '#D0D0DC',
    placeholderColor = '#505068',
    headerText = '#7878A0',
    closeText = '#505068',
    closeHoverText = '#A0A0B8',
}

function init()
    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end
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
    if isOpen then
        closeChatPopup()
    end

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
end

function onEnterPressed()
    if not g_game.isOnline() then return end
    if not isOpen then
        -- Defer open to next event loop tick to avoid segfault
        -- from breakAnchors during C++ keyboard event dispatch
        addEvent(openChatPopup)
    else
        -- Popup is open, Enter should send message
        sendChatMessage()
    end
end

function onEscapePressed()
    if not g_game.isOnline() then return end
    if isOpen then
        -- Defer close like the close button does
        addEvent(closeChatPopup)
    end
end

function onGameEnd()
    if isOpen then
        closeChatPopup()
    end
end

function openChatPopup()
    local root = g_ui.getRootWidget()
    local consolePanel = root:recursiveGetChildById('consolePanel')
    if not consolePanel or isOpen then return end

    local tabBar = consolePanel:getChildById('consoleTabBar')
    local contentPanel = consolePanel:getChildById('consoleContentPanel')
    local textEdit = consolePanel:getChildById('consoleTextEdit')
    local readOnlyPanel = consolePanel:getChildById('readOnlyPanel')

    savedWidgets = {
        consolePanel = consolePanel,
        tabBar = tabBar,
        contentPanel = contentPanel,
        textEdit = textEdit,
        readOnlyPanel = readOnlyPanel,
    }

    -- 1. Make consolePanel a fixed-size floating panel
    pcall(function() consolePanel:breakAnchors() end)
    pcall(function()
        consolePanel:setSize(560, 400)
        local x = (g_window.getWidth() - 560) / 2
        local y = (g_window.getHeight() - 400) / 2
        consolePanel:setPosition({ x = x, y = y })
        consolePanel:setMargin(0)
        consolePanel:setBackgroundColor(THEME.popupBg)
        consolePanel:setBorderWidth(1)
        consolePanel:setBorderColor(THEME.popupBorder)
        consolePanel:raise()
    end)

    -- 2. Hide all original chrome elements
    local idsToHide = {
        'consoleTabBar', 'sayModeButton', 'channelsButton', 'closeChannelButton',
        'ignoreButton', 'prevChannelButton', 'nextChannelButton', 'toggleChat',
        'extendedViewDraggable', 'extendedViewHide', 'readOnlyButton',
    }
    for _, id in ipairs(idsToHide) do
        local w = consolePanel:getChildById(id)
        if w then pcall(function() w:hide() end) end
    end
    if readOnlyPanel then pcall(function() readOnlyPanel:hide() end) end

    -- Hide the anonymous background frame UIWidget (first child, no id)
    local children = consolePanel:getChildren()
    for _, child in ipairs(children) do
        local cid = ''
        pcall(function() cid = child:getId() end)
        if cid == '' then
            pcall(function() child:hide() end)
        end
    end

    -- 3. Create header with label and close button
    headerWidget = g_ui.createWidget('UIWidget', consolePanel)
    pcall(function()
        headerWidget:setId('customChatHeader')
        headerWidget:setHeight(28)
        headerWidget:addAnchor(AnchorTop, 'parent', AnchorTop)
        headerWidget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        headerWidget:addAnchor(AnchorRight, 'parent', AnchorRight)
        headerWidget:setBackgroundColor(THEME.headerBg)
    end)

    local label = g_ui.createWidget('Label', headerWidget)
    pcall(function()
        label:setText('Chat')
        label:setFont('verdana-11px-rounded')
        label:setColor(THEME.headerText)
        label:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        label:setMarginLeft(12)
    end)

    closeButton = g_ui.createWidget('UIButton', headerWidget)
    pcall(function()
        closeButton:setText('x')
        closeButton:setFont('verdana-11px-rounded')
        closeButton:setColor(THEME.closeText)
        closeButton:setWidth(28)
        closeButton:setHeight(28)
        closeButton:addAnchor(AnchorTop, 'parent', AnchorTop)
        closeButton:addAnchor(AnchorRight, 'parent', AnchorRight)
        closeButton:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        closeButton:setMarginRight(6)
        closeButton:setImageSource('')
        closeButton:setBorderWidth(0)
        closeButton:setBorderColor('transparent')
    end)
    closeButton.onMouseRelease = function(self, mousePos, mouseButton)
        if mouseButton == MouseLeftButton then
            addEvent(closeChatPopup)
        end
    end

    -- 4. Create sidebar widget
    sidebarWidget = g_ui.createWidget('UIWidget', consolePanel)
    pcall(function()
        sidebarWidget:setId('customChatSidebar')
        sidebarWidget:setWidth(96)
        sidebarWidget:addAnchor(AnchorTop, 'customChatHeader', AnchorBottom)
        sidebarWidget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        sidebarWidget:addAnchor(AnchorBottom, 'customChatInputArea', AnchorTop)
        sidebarWidget:setBackgroundColor(THEME.sidebarBg)
    end)

    -- 5. Re-anchor contentPanel to sit between header, sidebar, and input
    if contentPanel then
        pcall(function()
            contentPanel:breakAnchors()
            contentPanel:addAnchor(AnchorTop, 'customChatHeader', AnchorBottom)
            contentPanel:addAnchor(AnchorLeft, 'customChatSidebar', AnchorRight)
            contentPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
            contentPanel:addAnchor(AnchorBottom, 'customChatInputArea', AnchorTop)
            contentPanel:setMargin(0)
            contentPanel:setPadding(0)
            contentPanel:setBackgroundColor(THEME.contentBg)
            contentPanel:setBorderWidth(0)
            contentPanel:setBorderColor('transparent')
            contentPanel:setImageSource('')
        end)
    end

    -- 6. Re-anchor textEdit to bottom (acts as popup input field)
    if textEdit then
        pcall(function()
            textEdit:breakAnchors()
            textEdit:setHeight(36)
            textEdit:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            textEdit:addAnchor(AnchorRight, 'parent', AnchorRight)
            textEdit:addAnchor(AnchorBottom, 'parent', AnchorBottom)
            textEdit:setMargin(4)
            textEdit:setBackgroundColor(THEME.inputFieldBg)
            textEdit:setColor(THEME.inputText)
            textEdit:setBorderColor(THEME.inputFieldBorder)
            textEdit:setBorderWidth(1)
            textEdit:setFont('verdana-11px-antialised')
            textEdit:focus()
        end)
    end

    -- 7. Restyle all tab panel buffers
    restyleAllTabPanels(tabBar)

    -- 8. Build sidebar tab buttons
    buildSidebar()

    -- 9. Hook tab change for sidebar refresh
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

    isOpen = true
end

function closeChatPopup()
    if not isOpen then return end
    isOpen = false

    local consolePanel = savedWidgets.consolePanel
    local tabBar = savedWidgets.tabBar
    local contentPanel = savedWidgets.contentPanel
    local textEdit = savedWidgets.textEdit
    local readOnlyPanel = savedWidgets.readOnlyPanel

    -- STEP 1: Destroy sidebar buttons (break anchors first)
    safeDestroySidebarButtons()

    -- STEP 2: Re-anchor contentPanel back to original position
    -- (remove references to custom widgets BEFORE destroying them)
    if contentPanel then
        pcall(function()
            contentPanel:breakAnchors()
            contentPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
            contentPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            contentPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
            contentPanel:addAnchor(AnchorBottom, 'consoleTextEdit', AnchorTop)
            contentPanel:setMarginLeft(3)
            contentPanel:setMarginRight(2)
            contentPanel:setMarginBottom(4)
            contentPanel:setMarginTop(20)
            contentPanel:setPadding(1)
            contentPanel:setBackgroundColor('transparent')
        end)
    end

    -- STEP 3: Re-anchor textEdit back to original position
    if textEdit then
        pcall(function()
            textEdit:breakAnchors()
            textEdit:setHeight(18)
            textEdit:addAnchor(AnchorLeft, 'sayModeButton', AnchorRight)
            textEdit:addAnchor(AnchorRight, 'toggleChat', AnchorLeft)
            textEdit:addAnchor(AnchorBottom, 'parent', AnchorBottom)
            textEdit:setMarginRight(5)
            textEdit:setMarginLeft(5)
            textEdit:setMarginBottom(3)
            textEdit:setBackgroundColor('')
            textEdit:setColor('')
            textEdit:setBorderColor('')
            textEdit:setBorderWidth(0)
            textEdit:clearText()
        end)
    end

    -- STEP 4: Re-anchor readOnlyPanel back
    if readOnlyPanel then
        pcall(function()
            readOnlyPanel:breakAnchors()
            readOnlyPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
            readOnlyPanel:addAnchor(AnchorLeft, 'parent', AnchorHorizontalCenter)
            readOnlyPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
            readOnlyPanel:addAnchor(AnchorBottom, 'consoleTextEdit', AnchorTop)
            readOnlyPanel:setMarginLeft(2)
            readOnlyPanel:setMarginRight(6)
            readOnlyPanel:setMarginBottom(4)
            readOnlyPanel:setMarginTop(20)
            readOnlyPanel:setPadding(1)
        end)
    end

    -- STEP 5: NOW safe to destroy dynamically created widgets
    -- (all references to them removed in steps 2-4)
    if headerWidget then
        pcall(function() headerWidget:destroy() end)
        headerWidget = nil
    end
    if sidebarWidget then
        pcall(function() sidebarWidget:destroy() end)
        sidebarWidget = nil
    end
    closeButton = nil

    -- STEP 6: Restore consolePanel to fill parent
    pcall(function()
        consolePanel:breakAnchors()
        consolePanel:addAnchor(AnchorTop, 'parent', AnchorTop)
        consolePanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        consolePanel:addAnchor(AnchorRight, 'parent', AnchorRight)
        consolePanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        consolePanel:setMargin(0)
        consolePanel:setBackgroundColor('transparent')
        consolePanel:setBorderWidth(0)
    end)

    -- STEP 7: Show all hidden original chrome
    local idsToShow = {
        'consoleTabBar', 'sayModeButton', 'channelsButton', 'closeChannelButton',
        'ignoreButton', 'prevChannelButton', 'nextChannelButton', 'toggleChat',
        'extendedViewDraggable', 'extendedViewHide', 'readOnlyButton',
    }
    for _, id in ipairs(idsToShow) do
        local w = consolePanel:getChildById(id)
        if w then pcall(function() w:show() end) end
    end
    if readOnlyPanel then pcall(function() readOnlyPanel:show() end) end

    -- Show the anonymous background frame
    local children = consolePanel:getChildren()
    for _, child in ipairs(children) do
        local cid = ''
        pcall(function() cid = child:getId() end)
        if cid == '' then
            pcall(function() child:show() end)
        end
    end

    -- STEP 8: Restore original tab styles
    restoreTabStyles(tabBar)

    -- STEP 9: Restore tab change handler
    if tabBar then
        pcall(function()
            tabBar.onTabChange = originalOnTabChange
        end)
        originalOnTabChange = nil
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
    if not sidebarWidget then return end
    local tabBar = savedWidgets.tabBar
    if not tabBar then return end

    safeDestroySidebarButtons()

    local allTabs = getAllTabs(tabBar)
    for i, tab in ipairs(allTabs) do
        local ok, btn = pcall(function()
            return g_ui.createWidget('UIButton', sidebarWidget)
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
                -- All buttons anchor to parent top with marginTop offset
                -- (no 'prev' reference that could dangle on destroy)
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

function safeDestroySidebarButtons()
    -- Break ALL anchors on ALL buttons first to prevent
    -- dangling parent references during C++ layout recalc
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

function sendChatMessage()
    local consolePanel = savedWidgets.consolePanel
    if not consolePanel then return end
    local textEdit = consolePanel:getChildById('consoleTextEdit')
    if not textEdit then return end

    local message = textEdit:getText()
    if not message or #message == 0 then return end

    pcall(function()
        modules.game_console.sendCurrentMessage()
    end)
end
