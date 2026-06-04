-- entergame_custom.lua - Custom login screen for JO Server
-- Creates a completely new login window, hides the original
-- Loaded via interface.otmod load-later (after client_entergame)

local customWindow = nil
local originalWindow = nil

function init()
    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        originalWindow = root:recursiveGetChildById('enterGame')
        if not originalWindow then
            scheduleEvent(function()
                local r = g_ui.getRootWidget()
                if r then
                    originalWindow = r:recursiveGetChildById('enterGame')
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

    -- Hide the original window completely
    originalWindow:hide()

    -- Load our custom window
    local ok = pcall(function()
        customWindow = g_ui.loadUI('entergame_custom')
    end)
    if not ok or not customWindow then
        -- If custom UI fails to load, show original as fallback
        originalWindow:show()
        return
    end

    if not customWindow:getParent() then
        local root = g_ui.getRootWidget()
        if root then
            root:addChild(customWindow)
        end
    end

    -- Mirror saved values from original to custom inputs
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

    -- Set up Enter key binding on the custom window
    customWindow.onEnter = function()
        doCustomLogin()
    end
    customWindow.onEscape = function()
        -- Do nothing on escape
    end

    -- Focus the name field
    if customName then
        customName:focus()
    end

    -- Center window on screen
    local gw = g_window
    if gw and customWindow then
        local x = (gw.getWidth() - customWindow:getWidth()) / 2
        local y = (gw.getHeight() - customWindow:getHeight()) / 2
        customWindow:setPosition({ x = x, y = y })
    end
end

function terminate()
    if customWindow then
        customWindow:destroy()
        customWindow = nil
    end

    if originalWindow then
        originalWindow:show()
    end
end

function doCustomLogin()
    local customName = customWindow:recursiveGetChildById('customAccountName')
    local customPass = customWindow:recursiveGetChildById('customPassword')
    local customRemember = customWindow:recursiveGetChildById('customRememberBox')

    if not customName or not customPass or not originalWindow then return end

    -- Sync values to original hidden widgets
    local nameEdit = originalWindow:getChildById('accountNameTextEdit')
    local passEdit = originalWindow:getChildById('accountPasswordTextEdit')
    local rememberBox = originalWindow:getChildById('rememberEmailBox')

    if nameEdit then
        nameEdit:setText(customName:getText())
    end
    if passEdit then
        passEdit:setText(customPass:getText())
    end
    if rememberBox and customRemember then
        rememberBox:setChecked(customRemember:isChecked())
    end

    -- Call the original login function
    pcall(function()
        EnterGame.doLogin()
    end)
end

function onRememberChange(checked)
    -- Sync remember box to original
    if originalWindow then
        local rememberBox = originalWindow:getChildById('rememberEmailBox')
        if rememberBox then
            pcall(function()
                rememberBox:setChecked(checked)
            end)
        end
    end
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
    -- Toggle between password and text mode
    if customPass:isTextHidden() then
        customPass:setTextHidden(false)
    else
        customPass:setTextHidden(true)
    end
end

-- Intercept original show/hide to keep in sync
local origEnterGameShow = EnterGame and EnterGame.show
local origEnterGameHide = EnterGame and EnterGame.hide

-- Override EnterGame.show to show our custom window instead
if EnterGame then
    EnterGame.show = function()
        if g_game.isOnline() then return end
        if customWindow then
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
