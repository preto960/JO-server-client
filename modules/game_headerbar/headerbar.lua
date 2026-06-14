local HEADER_HEIGHT = 36
local headerBar = nil
local isSetup = false

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
        returnButtonsToSidebar()
        headerBar:destroy()
        headerBar = nil
    end
    isSetup = false
end

function onGameStart()
    g_logger.info("[HeaderBar] onGameStart fired")
    if isSetup then return end
    isSetup = true
    scheduleEvent(function()
        setupHeaderBar()
    end, 500)
end

function onGameEnd()
    g_logger.info("[HeaderBar] onGameEnd fired")
    if headerBar then
        returnButtonsToSidebar()
        headerBar:hide()
    end
    isSetup = false
end

function setupHeaderBar()
    local rootWidget = g_ui.getRootWidget()
    if not rootWidget then return end

    local gameRootPanel = rootWidget:getChildById('gameRootPanel')
    if not gameRootPanel then return end

    headerBar = g_ui.createWidget('GameHeaderBar', rootWidget)
    headerBar:setId('gameHeaderBar')

    local gameRootY = gameRootPanel:getY()
    local rootW = rootWidget:getWidth()

    headerBar:setX(0)
    headerBar:setY(gameRootY - HEADER_HEIGHT)
    headerBar:setWidth(rootW)
    headerBar:setHeight(HEADER_HEIGHT)
    headerBar:show()
    headerBar:raise()

    g_logger.info("[HeaderBar] Positioned at Y=" .. (gameRootY - HEADER_HEIGHT))

    moveSidebarButtons()
end

function moveSidebarButtons()
    if not headerBar then return end

    local mainPanel = modules.game_mainpanel
    if not mainPanel or not mainPanel.optionsController then
        g_logger.warning("[HeaderBar] mainpanel not ready")
        return
    end

    local oc = mainPanel.optionsController
    if not oc.ui or not oc.ui.onPanel then
        g_logger.warning("[HeaderBar] optionsController UI not ready")
        return
    end

    local optionsPanel = oc.ui.onPanel.options
    local specialsPanel = oc.ui.onPanel.specials

    local btnSize = 28
    local spacing = 2
    local startX = 8
    local count = 0

    -- Move buttons from options panel to headerbar (reparenting existing widgets)
    if optionsPanel then
        for _, btn in ipairs(optionsPanel:getChildren()) do
            if btn:isVisible() and btn:getId() and btn:getImageSource() and btn:getImageSource() ~= '' then
                btn:setParent(headerBar)
                btn:setSize(btnSize, btnSize)
                btn:setX(startX + (count * (btnSize + spacing)))
                btn:setY(math.floor((HEADER_HEIGHT - btnSize) / 2))
                count = count + 1
            end
        end
    end

    -- Move special buttons too
    if specialsPanel then
        for _, btn in ipairs(specialsPanel:getChildren()) do
            if btn:isVisible() and btn:getId() and btn:getImageSource() and btn:getImageSource() ~= '' then
                btn:setParent(headerBar)
                btn:setSize(btnSize, btnSize)
                btn:setX(startX + (count * (btnSize + spacing)))
                btn:setY(math.floor((HEADER_HEIGHT - btnSize) / 2))
                count = count + 1
            end
        end
    end

    g_logger.info("[HeaderBar] Moved " .. count .. " buttons to headerbar")

    -- Shrink the now-empty sidebar controller
    if oc.ui then
        oc.ui:setHeight(0)
    end
end

function returnButtonsToSidebar()
    if not headerBar then return end

    local mainPanel = modules.game_mainpanel
    if not mainPanel or not mainPanel.optionsController then return end

    local oc = mainPanel.optionsController
    if not oc.ui or not oc.ui.onPanel then return end

    local optionsPanel = oc.ui.onPanel.options
    local specialsPanel = oc.ui.onPanel.specials

    -- Move buttons back to their original panels
    local optionsBtns = {}
    local specialBtns = {}

    for _, btn in ipairs(headerBar:getChildren()) do
        local id = btn:getId()
        -- Detect which panel they originally came from by ID
        if id == 'logoutButton' or id == 'optionsMainButton' then
            table.insert(specialBtns, btn)
        else
            table.insert(optionsBtns, btn)
        end
    end

    for _, btn in ipairs(optionsBtns) do
        btn:setParent(optionsPanel)
        btn:setSize(20, 20)
        btn:setX(0)
        btn:setY(0)
    end

    for _, btn in ipairs(specialBtns) do
        btn:setParent(specialsPanel)
        btn:setSize(20, 20)
        btn:setX(0)
        btn:setY(0)
    end

    if oc.ui then
        oc.ui:setHeight(28)
    end

    g_logger.info("[HeaderBar] Returned buttons to sidebar")
end