-- chat_custom.lua - Custom chat popup for JO Server
-- Intercepts Enter key to show a floating chat window instead of bottom bar
-- Loaded via interface.otmod load-later (after game_console)

local chatPopup = nil
local originalSwitchChatOnCall = nil
local originalDisableChatOnCall = nil
local isOpen = false

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

        -- Parent popup to root
        if not chatPopup:getParent() then
            root:addChild(chatPopup)
        end
        chatPopup:hide()

        -- Find the consolePanel to override Enter key handling
        local consolePanel = root:recursiveGetChildById('consolePanel')
        if not consolePanel then return end

        -- Override g_keyboard bindings for Enter and Escape on consolePanel
        -- First unbind the original handlers
        g_keyboard.unbindKeyDown('Enter', consolePanel)
        g_keyboard.unbindKeyDown('Escape', consolePanel)

        -- Bind our custom handlers
        g_keyboard.bindKeyDown('Enter', onEnterPressed, consolePanel)
        g_keyboard.bindKeyDown('Escape', onEscapePressed, consolePanel)
    end)
end

function terminate()
    local root = g_ui.getRootWidget()
    if root then
        local consolePanel = root:recursiveGetChildById('consolePanel')
        if consolePanel then
            -- Restore original keyboard bindings
            g_keyboard.unbindKeyDown('Enter', consolePanel)
            g_keyboard.unbindKeyDown('Escape', consolePanel)

            -- We need access to the original functions - restore via modules
            pcall(function()
                g_keyboard.bindKeyDown('Enter', modules.game_console.switchChatOnCall, consolePanel)
                g_keyboard.bindKeyDown('Escape', modules.game_console.disableChatOnCall, consolePanel)
            end)
        end
    end

    if chatPopup then
        chatPopup:destroy()
        chatPopup = nil
    end
    isOpen = false
end

function onEnterPressed()
    if not g_game.isOnline() then return end

    if isOpen then
        -- If popup is open, focus the input box
        local input = chatPopup:recursiveGetChildById('chatInput')
        if input then
            input:focus()
        end
    else
        -- Open chat popup
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
    -- Hide the original bottom gameBottomPanel's console text edit
    local root = g_ui.getRootWidget()
    local originalInput = root and root:recursiveGetChildById('consoleTextEdit')
    if originalInput then
        originalInput:hide()
    end

    -- Hide the original toggleChat button text edit area
    local toggleChat = root and root:recursiveGetChildById('toggleChat')
    if toggleChat then
        toggleChat:hide()
    end

    -- Show and focus our popup
    if not chatPopup:getParent() and root then
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
    chatPopup:hide()
    isOpen = false

    -- Restore original chat input visibility if chat was enabled
    local root = g_ui.getRootWidget()
    local originalInput = root and root:recursiveGetChildById('consoleTextEdit')
    if originalInput then
        originalInput:show()
    end
    local toggleChat = root and root:recursiveGetChildById('toggleChat')
    if toggleChat then
        toggleChat:show()
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
