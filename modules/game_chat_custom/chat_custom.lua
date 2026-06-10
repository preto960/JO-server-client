-- chat_custom.lua - Custom chat popup for JO Server
-- Uses separate popup (open worked fine), close only hides popup
-- contentPanel stays inside popup between open/close cycles
-- No reparenting on close = no crash

local chatPopup = nil
local isOpen = false
local savedWidgets = {}
local originalOnTabChange = nil
local originalAddTab = nil
local originalAddTabText = nil
local sidebarButtons = {}

-- Drag state
local chatDragInfo = {
    active = false,
    overlay = nil,
    startPos = {x=0, y=0},
    startMouse = {x=0, y=0}
}

local THEME = {
    tabBg = '#0A0A1ACC',
    tabSelectedBg = '#00B4D860',
    tabSelectedBorder = '#00B4D8',
    tabText = '#FFFFFF90',
    tabSelectedText = '#00B4D8',
    contentBg = 'alpha',
    bufferBg = 'alpha',
    scrollThumb = '#00B4D890',
    scrollBg = '#00B4D818',
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
        -- Restore saved position or center once
        local savedPos = g_settings.getPoint('chatCustomWindow/position')
        if savedPos then
            chatPopup:setPosition(savedPos)
        else
            local rootSize = root:getSize()
            local winSize = chatPopup:getSize()
            chatPopup:setPosition(topoint(string.format('%d %d',
                math.floor((rootSize.width - winSize.width) / 2),
                math.floor((rootSize.height - winSize.height) / 2)
            )))
        end
        chatPopup:hide()

        -- Make the chat header (top block) draggable
        local chatHeader = chatPopup:recursiveGetChildById('chatHeader')
        if chatHeader then
            chatHeader.onMousePress = function(widget, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    startChatDrag(mousePos)
                end
            end
        end

        -- ESC to close via onKeyPress (same approach as skills window)
        chatPopup.onKeyPress = function(widget, keyCode, keyboardModifiers)
            if keyboardModifiers == KeyboardNoModifier and keyCode == KeyEscape then
                if isOpen then
                    closeChatPopup()
                    return true
                end
            end
        end

        -- Close button via Lua (not @onClick in OTUI)
        local closeBtn = chatPopup:recursiveGetChildById('chatCloseButton')
        if closeBtn then
            closeBtn.onMouseRelease = function(self, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    addEvent(closeChatPopup)
                end
            end
        end

        local consolePanel = root:recursiveGetChildById('consolePanel')
        if not consolePanel then return end

        g_keyboard.unbindKeyDown('Enter', consolePanel)
        g_keyboard.unbindKeyDown('Escape', consolePanel)
        g_keyboard.bindKeyDown('Enter', onEnterPressed, consolePanel)

        pcall(function()
            connect(g_game, { onGameEnd = onGameEnd })
        end)
    end)
end

-- Drag functions for chat
function startChatDrag(mousePos)
    if chatDragInfo.active then return end
    local root = g_ui.getRootWidget()
    if not root then return end

    local overlay = g_ui.createWidget('UIWidget', root)
    overlay:setSize(root:getSize())
    overlay:setBackgroundColor('#00000000')
    overlay:focus()

    local winPos = chatPopup:getPosition()
    local mouseScreen = g_window.getMousePosition()

    chatDragInfo.active = true
    chatDragInfo.overlay = overlay
    chatDragInfo.startPos = {x = winPos.x, y = winPos.y}
    chatDragInfo.startMouse = {x = mouseScreen.x, y = mouseScreen.y}

    chatPopup:breakAnchors()

    overlay.onMouseMove = function(self, pos, moved)
        if chatDragInfo.active then
            local dx = pos.x - chatDragInfo.startMouse.x
            local dy = pos.y - chatDragInfo.startMouse.y
            chatPopup:setPosition(topoint(string.format('%d %d',
                chatDragInfo.startPos.x + dx,
                chatDragInfo.startPos.y + dy
            )))
        end
    end

    overlay.onMouseRelease = function(self, pos, mouseButton)
        if mouseButton == MouseLeftButton then
            stopChatDrag()
        end
    end
end

function stopChatDrag()
    if not chatDragInfo.active then return end
    chatDragInfo.active = false

    local pos = chatPopup:getPosition()
    g_settings.set('chatCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))

    if chatDragInfo.overlay then
        chatDragInfo.overlay:destroy()
        chatDragInfo.overlay = nil
    end

    if chatPopup and chatPopup:isVisible() then
        chatPopup:focus()
        local input = chatPopup:recursiveGetChildById('chatInput')
        if input then input:focus() end
    end
end

function terminate()
    -- Restore hooked functions
    if originalAddTab and modules.game_console then
        modules.game_console.addTab = originalAddTab
        originalAddTab = nil
    end
    if originalAddTabText and modules.game_console then
        modules.game_console.addTabText = originalAddTabText
        originalAddTabText = nil
    end

    -- Save chat position before destroy
    if chatPopup and chatPopup:getParent() then
        local pos = chatPopup:getPosition()
        g_settings.set('chatCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))
        end

    local root = g_ui.getRootWidget()
    if root then
        local consolePanel = root:recursiveGetChildById('consolePanel')
        if consolePanel then
            g_keyboard.unbindKeyDown('Enter', consolePanel)
            pcall(function()
                g_keyboard.bindKeyDown('Enter', modules.game_console.switchChatOnCall, consolePanel)
            end)
        end
    end

    pcall(function()
        disconnect(g_game, { onGameEnd = onGameEnd })
    end)

    forceRestoreAndClose()

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

function onGameEnd()
    forceRestoreAndClose()
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

    -- Only rebind Enter (ESC is handled by onKeyPress)
    g_keyboard.unbindKeyDown('Enter', consolePanel)
    g_keyboard.bindKeyDown('Enter', onEnterPressed, chatPopup)

    -- Move contentPanel into popup only on first open
    if contentPanel and contentPanel:getParent() ~= chatPopup then
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
            contentPanel:setBackgroundColor('alpha')
            contentPanel:setBorderWidth(0)
            contentPanel:setBorderColor('transparent')
            contentPanel:setImageSource('')
        end)
    end

    restyleAllTabPanels(tabBar)
    buildSidebar()

    if tabBar and not originalOnTabChange then
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

    -- Hook addTab to rebuild sidebar when new tabs are created
    if not originalAddTab and modules.game_console then
        originalAddTab = modules.game_console.addTab
        modules.game_console.addTab = function(name, focus)
            local result = originalAddTab(name, focus)
            if isOpen then
                buildSidebar()
            end
            return result
        end
    end

    -- Hook addTabText to make player names clickable for private chat
    if not originalAddTabText and modules.game_console then
        originalAddTabText = modules.game_console.addTabText
        modules.game_console.addTabText = function(tab, text, focus, ...)
            originalAddTabText(tab, text, focus, ...)
            -- Hook labels inside the buffer for left-click on player names
            if tab and tab.tabPanel then
                local buffer = tab.tabPanel:getChildById('consoleBuffer')
                if buffer then
                    local labels = buffer:getChildren()
                    for _, label in ipairs(labels) do
                        if label.creatureName and not label._customChatHooked then
                            label._customChatHooked = true
                            local origRelease = label.onMouseRelease
                            label.onMouseRelease = function(self, mousePos, mouseButton)
                                if mouseButton == MouseLeftButton and self.creatureName then
                                    local localPlayer = g_game.getLocalPlayer()
                                    if localPlayer and self.creatureName ~= localPlayer:getName() then
                                pcall(function()
                                    g_game.openPrivateChannel(self.creatureName)
                                end)
                                    return true
                                end
                                end
                                if origRelease then
                                    origRelease(self, mousePos, mouseButton)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not chatPopup:getParent() then
        root:addChild(chatPopup)
    end

    -- Show, raise, focus popup for onKeyPress, then focus input
    chatPopup:show()
    chatPopup:raise()
    chatPopup:focus()

    local input = chatPopup:recursiveGetChildById('chatInput')
    if input then
        input:focus()
    end

    isOpen = true
end

function closeChatPopup()
    if not isOpen then return end
    isOpen = false

    -- Save position on close
    local pos = chatPopup:getPosition()
    g_settings.set('chatCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))

    chatPopup:hide()

    -- Rebind Enter back to consolePanel so Enter can reopen
    local consolePanel = savedWidgets.consolePanel
    if consolePanel then
        g_keyboard.unbindKeyDown('Enter', chatPopup)
        g_keyboard.bindKeyDown('Enter', onEnterPressed, consolePanel)
        consolePanel:show()
    end
end

function forceRestoreAndClose()
    if not isOpen then
        if chatPopup and savedWidgets.contentPanel and savedWidgets.consolePanel then
            local contentPanel = savedWidgets.contentPanel
            local consolePanel = savedWidgets.consolePanel
            if contentPanel:getParent() ~= consolePanel then
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
            pcall(function() consolePanel:show() end)
        end
        return
    end
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

    pcall(function() g_keyboard.unbindKeyDown('Enter', chatPopup) end)

    -- Restore hooked functions
    if originalAddTab and modules.game_console then
        modules.game_console.addTab = originalAddTab
        originalAddTab = nil
    end
    if originalAddTabText and modules.game_console then
        modules.game_console.addTabText = originalAddTabText
        originalAddTabText = nil
    end

    destroySidebarButtons()
    restoreTabStyles(tabBar)

    chatPopup:hide()

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

    pcall(function() consolePanel:show() end)

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
    local btnIndex = 1
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
                btn:setPaddingLeft(12)
                btn:setPaddingRight(12)
                btn:setPaddingTop(4)
                btn:setPaddingBottom(4)
                -- Auto-resize to text but with proper button spacing
                pcall(function() btn:setAutoResize(true) end)
                pcall(function() btn:setTextAutoResize(true) end)
                -- Each tab gets a visible background
                btn:setBackgroundColor(THEME.tabBg)
                btn:setColor(THEME.tabText)
                -- Align to RIGHT of sidebar (flush with chat window left edge)
                btn:addAnchor(AnchorTop, 'parent', AnchorTop)
                btn:addAnchor(AnchorRight, 'parent', AnchorRight)
                btn:setMarginTop(1 + (btnIndex - 1) * 29)
                btnIndex = btnIndex + 1
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

    -- Add "+" button at the bottom for new private chat
    local plusBtn = g_ui.createWidget('UIButton', sidebar)
    pcall(function()
        plusBtn:setHeight(28)
        plusBtn:setText('+')
        plusBtn:setFont('Verdana Bold-11px')
        plusBtn:setImageSource('')
        plusBtn:setBorderWidth(0)
        plusBtn:setBorderColor('transparent')
        plusBtn:setPaddingLeft(12)
        plusBtn:setPaddingRight(12)
        plusBtn:setPaddingTop(4)
        plusBtn:setPaddingBottom(4)
        plusBtn:setBackgroundColor('#00B4D840')
        plusBtn:setColor('#00B4D8')
        plusBtn:addAnchor(AnchorTop, 'parent', AnchorTop)
        plusBtn:addAnchor(AnchorRight, 'parent', AnchorRight)
        plusBtn:setMarginTop(1 + (btnIndex - 1) * 29)
    end)

    sidebarButtons._plusBtn = plusBtn

    plusBtn.onMouseRelease = function(self, mousePos, mouseButton)
        if mouseButton == MouseLeftButton then
            openPrivateChatDialog()
        end
    end
end

function destroySidebarButtons()
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
        scrollBar:setWidth(10)
        scrollBar:setMarginRight(2)
        scrollBar:setMarginTop(2)
        scrollBar:setMarginBottom(2)
        scrollBar:setBackgroundColor(THEME.scrollBg)
        scrollBar:setBorderWidth(1)
        scrollBar:setBorderColor('#00B4D820')
    end)

    local children = scrollBar:getChildren()
    for _, child in ipairs(children) do
        pcall(function()
            child:setImageSource('')
            child:setBackgroundColor(THEME.scrollThumb)
            child:setBorderWidth(0)
            child:setBorderRadius(4)
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
    local input = chatPopup:recursiveGetChildById('chatInput')
    if not input then return end

    local message = input:getText()
    if not message or #message == 0 then return end

    pcall(function()
        modules.game_console.sendMessage(message)
    end)

    input:clearText()
end

function openPrivateChatDialog()
    local root = g_ui.getRootWidget()
    if not root then return end

    -- Create a small input dialog
    local dialog = g_ui.createWidget('UIWidget', root)
    dialog:setId('chatPrivateDialog')
    dialog:setSize(topoint('220 80'))
    dialog:setBackgroundColor('#0A0A1ADD')
    dialog:setBorderWidth(1)
    dialog:setBorderColor('#00B4D860')
    dialog:raise()
    dialog:focus()

    local chatPos = chatPopup:getPosition()
    dialog:setPosition(topoint(string.format('%d %d', chatPos.x + 140, chatPos.y + 50)))

    local label = g_ui.createWidget('Label', dialog)
    pcall(function()
        label:setId('privateChatLabel')
        label:setText('Chat privado con:')
        label:setFont('verdana-11px-rounded')
        label:setColor('#FFFFFFBB')
        label:addAnchor(AnchorTop, 'parent', AnchorTop)
        label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        label:setMarginTop(8)
        label:setMarginLeft(10)
    end)

    local nameInput = g_ui.createWidget('TextEdit', dialog)
    pcall(function()
        nameInput:setId('privateChatNameInput')
        nameInput:setFont('verdana-11px-antialised')
        nameInput:setColor('#CAF0F8')
        nameInput:setBackgroundColor('#0A0A1AFF')
        nameInput:setBorderWidth(1)
        nameInput:setBorderColor('#00B4D840')
        nameInput:setPlaceholder('Nombre del jugador...')
        nameInput:setPlaceholderColor('#FFFFFF60')
        nameInput:addAnchor(AnchorTop, label, AnchorBottom)
        nameInput:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        nameInput:addAnchor(AnchorRight, 'parent', AnchorRight)
        nameInput:setMarginTop(4)
        nameInput:setMarginLeft(10)
        nameInput:setMarginRight(10)
        nameInput:setHeight(22)
        nameInput:focus()
    end)

    local sendBtn = g_ui.createWidget('UIButton', dialog)
    pcall(function()
        sendBtn:setId('privateChatSendBtn')
        sendBtn:setText('Abrir')
        sendBtn:setFont('Verdana Bold-11px')
        sendBtn:setColor('#0A0A1A')
        sendBtn:setBackgroundColor('#00B4D8')
        sendBtn:setBorderWidth(1)
        sendBtn:setBorderColor('#0090B0')
        sendBtn:setHeight(28)
        sendBtn:addAnchor(AnchorTop, nameInput, AnchorBottom)
        sendBtn:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        sendBtn:addAnchor(AnchorRight, 'parent', AnchorRight)
        sendBtn:setMarginTop(6)
        sendBtn:setMarginLeft(10)
        sendBtn:setMarginRight(10)
    end)

    local function closeDialog()
        pcall(function() dialog:destroy() end)
    end

    sendBtn.onMouseRelease = function(self, mousePos, mouseButton)
        if mouseButton == MouseLeftButton then
            local name = nameInput:getText()
            if name and #name > 0 then
                pcall(function()
                    g_game.openPrivateChannel(name)
                end)
            end
            closeDialog()
        end
    end

    dialog.onKeyPress = function(widget, keyCode, keyboardModifiers)
        if keyCode == KeyEscape then
            closeDialog()
            return true
        elseif keyCode == KeyEnter then
            local name = nameInput:getText()
            if name and #name > 0 then
                pcall(function()
                    g_game.openPrivateChannel(name)
                end)
            end
            closeDialog()
            return true
        end
    end
end
