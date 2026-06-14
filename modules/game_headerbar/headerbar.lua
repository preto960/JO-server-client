local HEADER_HEIGHT = 36
local headerBar = nil
local isSetup = false
local headerButtons = {}

function init()
    g_ui.importStyle('/game_headerbar/headerbar.otui')
    g_logger.info("[HeaderBar] Module loaded")
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
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
    isSetup = false
    headerButtons = {}
end

function onGameStart()
    g_logger.info("[HeaderBar] onGameStart fired")
    if isSetup then return end
    isSetup = true
    -- Small delay to let mainpanel finish creating its buttons
    scheduleEvent(function()
        setupHeaderBar()
    end, 200)
end

function onGameEnd()
    g_logger.info("[HeaderBar] onGameEnd fired")
    if headerBar then
        headerBar:hide()
    end
    isSetup = false
    headerButtons = {}
end

function setupHeaderBar()
    local rootWidget = g_ui.getRootWidget()
    if not rootWidget then
        g_logger.error("[HeaderBar] rootWidget not found")
        return
    end

    local gameRootPanel = rootWidget:getChildById('gameRootPanel')
    if not gameRootPanel then
        g_logger.error("[HeaderBar] gameRootPanel not found")
        return
    end

    -- Create headerBar as a child of rootWidget
    headerBar = g_ui.createWidget('GameHeaderBar', rootWidget)
    headerBar:setId('gameHeaderBar')

    local gameRootY = gameRootPanel:getY()
    local rootW = rootWidget:getWidth()
    local barY = gameRootY - HEADER_HEIGHT

    headerBar:setX(0)
    headerBar:setY(barY)
    headerBar:setWidth(rootW)
    headerBar:setHeight(HEADER_HEIGHT)
    headerBar:show()
    headerBar:raise()

    g_logger.info("[HeaderBar] gameRootY=" .. gameRootY .. " barY=" .. barY .. " W=" .. rootW)

    -- Mirror sidebar buttons into the headerbar
    mirrorSidebarButtons()
end

function mirrorSidebarButtons()
    if not headerBar then return end

    -- Access the mainpanel options panel where all toggle buttons live
    local mainPanel = modules.game_mainpanel
    if not mainPanel or not mainPanel.optionsController then
        g_logger.warning("[HeaderBar] mainpanel not ready, retrying in 500ms")
        scheduleEvent(mirrorSidebarButtons, 500)
        return
    end

    local optionsController = mainPanel.optionsController
    if not optionsController.ui or not optionsController.ui.onPanel then
        g_logger.warning("[HeaderBar] optionsController UI not ready, retrying in 500ms")
        scheduleEvent(mirrorSidebarButtons, 500)
        return
    end

    local optionsPanel = optionsController.ui.onPanel.options
    local specialsPanel = optionsController.ui.onPanel.specials
    local storePanel = optionsController.ui.onPanel.store

    local allButtons = {}

    -- Collect all visible buttons from options panel
    if optionsPanel then
        for _, btn in ipairs(optionsPanel:getChildren()) do
            if btn:isVisible() and btn:getId() then
                table.insert(allButtons, btn)
            end
        end
    end

    -- Collect special buttons
    if specialsPanel then
        for _, btn in ipairs(specialsPanel:getChildren()) do
            if btn:isVisible() and btn:getId() then
                table.insert(allButtons, btn)
            end
        end
    end

    if #allButtons == 0 then
        g_logger.warning("[HeaderBar] No sidebar buttons found, retrying in 500ms")
        scheduleEvent(mirrorSidebarButtons, 500)
        return
    end

    g_logger.info("[HeaderBar] Found " .. #allButtons .. " sidebar buttons to mirror")

    local btnSize = 28
    local spacing = 2
    local startX = 8

    for i, srcBtn in ipairs(allButtons) do
        local id = srcBtn:getId()
        local tooltip = srcBtn:getTooltip() or id
        local imageSource = srcBtn:getImageSource()
        local imageClip = srcBtn:getImageClip()

        -- Create a headerbar-style mirror button
        local mirrorBtn = g_ui.createWidget('HeaderBarIconButton', headerBar)
        mirrorBtn:setId('hb_' .. id)
        mirrorBtn:setTooltip(tooltip)

        -- Copy the icon from the source button
        if imageSource and imageSource ~= '' then
            mirrorBtn:setImageSource(imageSource)
            if imageClip and imageClip ~= '' then
                mirrorBtn:setImageClip(imageClip)
            end
        end

        local x = startX + ((i - 1) * (btnSize + spacing))
        mirrorBtn:setX(x)
        mirrorBtn:setY(math.floor((HEADER_HEIGHT - btnSize) / 2))
        mirrorBtn:setSize(btnSize, btnSize)

        -- Store reference to source button and wire up click
        headerButtons[id] = {
            mirror = mirrorBtn,
            source = srcBtn
        }

        mirrorBtn.onClick = function()
            if not srcBtn or srcBtn:isDestroyed() then return end
            -- Trigger the same mouse release callback as the original
            if srcBtn.onMouseRelease then
                srcBtn.onMouseRelease(srcBtn, { x = 10, y = 10 }, MouseLeftButton)
            end
            updateMirrorButtonState(id)
        end

        -- Sync initial state (on/off)
        updateMirrorButtonState(id)
    end
end

function updateMirrorButtonState(id)
    local entry = headerButtons[id]
    if not entry then return end

    local srcBtn = entry.source
    local mirrorBtn = entry.mirror

    if srcBtn:isDestroyed() then
        mirrorBtn:setChecked(false)
        return
    end

    -- Sync checked state with source button's on state
    if srcBtn.isOn then
        local isOn = srcBtn:isOn()
        mirrorBtn:setChecked(isOn)
    end
end