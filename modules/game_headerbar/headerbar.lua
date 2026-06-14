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

    mirrorSidebarButtons()
end

function mirrorSidebarButtons()
    if not headerBar then return end

    local ok, err = pcall(function()
        doMirrorSidebarButtons()
    end)
    if not ok then
        g_logger.error("[HeaderBar] mirrorSidebarButtons error: " .. tostring(err))
    end
end

function doMirrorSidebarButtons()
    local mainPanel = modules.game_mainpanel
    if not mainPanel then
        g_logger.warning("[HeaderBar] mainpanel not ready, retrying")
        scheduleEvent(mirrorSidebarButtons, 500)
        return
    end

    local optionsController = mainPanel.optionsController
    if not optionsController or not optionsController.ui or not optionsController.ui.onPanel then
        g_logger.warning("[HeaderBar] optionsController not ready, retrying")
        scheduleEvent(mirrorSidebarButtons, 500)
        return
    end

    local optionsPanel = optionsController.ui.onPanel.options
    local specialsPanel = optionsController.ui.onPanel.specials

    local allButtons = {}

    if optionsPanel then
        for _, btn in ipairs(optionsPanel:getChildren()) do
            if btn:isVisible() and btn:getId() then
                table.insert(allButtons, btn)
            end
        end
    end

    if specialsPanel then
        for _, btn in ipairs(specialsPanel:getChildren()) do
            if btn:isVisible() and btn:getId() then
                table.insert(allButtons, btn)
            end
        end
    end

    if #allButtons == 0 then
        g_logger.warning("[HeaderBar] No sidebar buttons found, retrying")
        scheduleEvent(mirrorSidebarButtons, 500)
        return
    end

    g_logger.info("[HeaderBar] Found " .. #allButtons .. " sidebar buttons")

    local btnSize = 28
    local spacing = 2
    local startX = 8
    local created = 0

    for i, srcBtn in ipairs(allButtons) do
        local ok, _ = pcall(function()
            local id = srcBtn:getId()
            local tooltip = srcBtn:getTooltip() or id

            -- Safely get image source
            local imageSource = ''
            local ok1 = pcall(function() imageSource = srcBtn:getImageSource() end)

            -- Skip buttons without a valid image
            if not ok1 or not imageSource or imageSource == '' then
                g_logger.warning("[HeaderBar] Skipping button '" .. id .. "' (no image)")
                return
            end

            local mirrorBtn = g_ui.createWidget('HeaderBarIconButton', headerBar)
            mirrorBtn:setId('hb_' .. id)
            mirrorBtn:setTooltip(tooltip)
            mirrorBtn:setImageSource(imageSource)

            -- Safely copy image clip
            pcall(function()
                local clip = srcBtn:getImageClip()
                if clip then
                    mirrorBtn:setImageClip(clip)
                end
            end)

            local x = startX + (created * (btnSize + spacing))
            mirrorBtn:setX(x)
            mirrorBtn:setY(math.floor((HEADER_HEIGHT - btnSize) / 2))
            mirrorBtn:setSize(btnSize, btnSize)

            -- Store reference
            headerButtons[id] = {
                mirror = mirrorBtn,
                source = srcBtn
            }

            -- Wire click to trigger original button's callback
            mirrorBtn.onClick = function()
                pcall(function()
                    if not srcBtn or srcBtn:isDestroyed() then return end
                    if srcBtn.onMouseRelease then
                        srcBtn.onMouseRelease(srcBtn, { x = 10, y = 10 }, MouseLeftButton)
                    end
                end)
            end

            created = created + 1
        end)
        if not ok then
            g_logger.warning("[HeaderBar] Failed to mirror button #" .. i)
        end
    end

    g_logger.info("[HeaderBar] Created " .. created .. " mirror buttons")
end