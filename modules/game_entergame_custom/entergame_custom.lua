-- entergame_custom.lua - Custom login screen for JO Server
-- Electric Blue Theme - Right-side positioned login
-- Tab/Enter key support, neon accent styling

local customWindow = nil
local originalWindow = nil
local topMenuWidget = nil
local bottomMenuWidget = nil
local versionLabelWidget = nil
local rememberChecked = false

function init()
    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        originalWindow = root:recursiveGetChildById('enterGame')
        topMenuWidget = root:recursiveGetChildById('topMenu')
        bottomMenuWidget = root:recursiveGetChildById('bottomMenu')
        versionLabelWidget = root:recursiveGetChildById('clientVersionLabel')

        if not originalWindow then
            scheduleEvent(function()
                local r = g_ui.getRootWidget()
                if r then
                    if not originalWindow then
                        originalWindow = r:recursiveGetChildById('enterGame')
                    end
                    if not topMenuWidget then
                        topMenuWidget = r:recursiveGetChildById('topMenu')
                    end
                    if not bottomMenuWidget then
                        bottomMenuWidget = r:recursiveGetChildById('bottomMenu')
                    end
                    if not versionLabelWidget then
                        versionLabelWidget = r:recursiveGetChildById('clientVersionLabel')
                    end
                    if originalWindow then
                        setup()
                    end
                end
            end, 500)
            return
        end

        setup()
    end)
end

function setup()
    if not originalWindow then return end

    originalWindow:hide()

    if topMenuWidget then topMenuWidget:hide() end
    if bottomMenuWidget then bottomMenuWidget:hide() end
    if versionLabelWidget then versionLabelWidget:hide() end

    local ok = pcall(function()
        customWindow = g_ui.loadUI('entergame_custom')
    end)
    if not ok or not customWindow then
        originalWindow:show()
        showOriginalUI()
        return
    end

    if not customWindow:getParent() then
        local root = g_ui.getRootWidget()
        if root then
            root:addChild(customWindow)
        end
    end

    local nameEdit = originalWindow:getChildById('accountNameTextEdit')
    local passEdit = originalWindow:getChildById('accountPasswordTextEdit')
    local rememberBox = originalWindow:getChildById('rememberEmailBox')

    local customName = customWindow:recursiveGetChildById('customAccountName')
    local customPass = customWindow:recursiveGetChildById('customPassword')

    if customName and nameEdit then
        customName:setText(nameEdit:getText())
    end
    if customPass and passEdit then
        customPass:setText(passEdit:getText())
    end

    if rememberBox then
        rememberChecked = rememberBox:isChecked()
    end
    updateRememberVisual()

    g_keyboard.bindKeyDown('Enter', onEnterPressed, customWindow)
    g_keyboard.bindKeyDown('Tab', onTabPressed, customWindow)

    if customName then
        customName:focus()
    end

    local gw = g_window
    if gw and customWindow then
        -- Position on the left side, centered vertically with nice spacing
        local x = 80
        local y = (gw.getHeight() - customWindow:getHeight()) / 2
        customWindow:setPosition({ x = x, y = y })
    end

    pcall(function()
        connect(g_game, {
            onGameStart = onGameStart,
            onGameEnd = onGameEnd
        })
    end)
end

function terminate()
    if customWindow then
        g_keyboard.unbindKeyDown('Enter', customWindow)
        g_keyboard.unbindKeyDown('Tab', customWindow)
    end

    pcall(function()
        disconnect(g_game, {
            onGameStart = onGameStart,
            onGameEnd = onGameEnd
        })
    end)

    if customWindow then
        customWindow:destroy()
        customWindow = nil
    end

    showOriginalUI()

    if originalWindow then
        originalWindow:show()
    end
end

function showOriginalUI()
    if topMenuWidget then topMenuWidget:show() end
    if bottomMenuWidget then bottomMenuWidget:show() end
    if versionLabelWidget then versionLabelWidget:show() end
end

function hideOriginalUI()
    if topMenuWidget then topMenuWidget:hide() end
    if bottomMenuWidget then bottomMenuWidget:hide() end
    if versionLabelWidget then versionLabelWidget:hide() end
end

function onGameStart()
    showOriginalUI()
    -- Hide custom login when entering the game
    if customWindow then
        customWindow:hide()
    end
end

function onGameEnd()
    -- Hide custom login on character select screen
    -- It should only show on the actual login screen
    if customWindow then
        customWindow:hide()
    end
end

function onEnterPressed()
    doCustomLogin()
end

function onTabPressed()
    if not customWindow then return end
    local customName = customWindow:recursiveGetChildById('customAccountName')
    local customPass = customWindow:recursiveGetChildById('customPassword')
    if not customName or not customPass then return end

    if customName:isFocused() then
        customPass:focus()
    else
        customName:focus()
    end
end

function toggleRemember()
    rememberChecked = not rememberChecked
    updateRememberVisual()

    if originalWindow then
        local rememberBox = originalWindow:getChildById('rememberEmailBox')
        if rememberBox then
            pcall(function()
                rememberBox:setChecked(rememberChecked)
            end)
        end
    end
end

function updateRememberVisual()
    if not customWindow then return end
    local box = customWindow:recursiveGetChildById('customRememberBox')
    if box then
        pcall(function()
            if rememberChecked then
                box:setBackgroundColor('#00B4D880')
                box:setBorderColor('#00B4D8')
            else
                box:setBackgroundColor('#0A1628CC')
                box:setBorderColor('#1A3A5C')
            end
        end)
    end
end

function doCustomLogin()
    local customName = customWindow:recursiveGetChildById('customAccountName')
    local customPass = customWindow:recursiveGetChildById('customPassword')

    if not customName or not customPass or not originalWindow then return end

    local nameEdit = originalWindow:getChildById('accountNameTextEdit')
    local passEdit = originalWindow:getChildById('accountPasswordTextEdit')
    local rememberBox = originalWindow:getChildById('rememberEmailBox')

    if nameEdit then
        nameEdit:setText(customName:getText())
    end
    if passEdit then
        passEdit:setText(customPass:getText())
    end
    if rememberBox then
        rememberBox:setChecked(rememberChecked)
    end

    pcall(function()
        EnterGame.doLogin()
    end)
end

function onForgotPassword()
    pcall(function()
        g_platform.openUrl(Services.websites)
    end)
end

function onCreateAccount()
    pcall(function()
        local createBtn = originalWindow:getChildById('btnCreateNewAccount')
        if createBtn then
            createBtn:disable()
            createWidgetAccount()
        end
    end)
end

function togglePasswordVisibility()
    local customPass = customWindow:recursiveGetChildById('customPassword')
    if not customPass then return end
    if customPass:isTextHidden() then
        customPass:setTextHidden(false)
    else
        customPass:setTextHidden(true)
    end
end

if EnterGame then
    EnterGame.show = function()
        if g_game.isOnline() then return end
        if customWindow then
            hideOriginalUI()
            customWindow:show()
            customWindow:raise()
            customWindow:focus()
        end
    end

    EnterGame.hide = function()
        if customWindow then
            customWindow:hide()
        end
        if originalWindow then
            originalWindow:hide()
        end
    end
end
