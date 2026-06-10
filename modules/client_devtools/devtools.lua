local reloadButton = nil
local reloadLabel = nil

function init()
    addEvent(function()
        -- Method 1: Ctrl+Shift+R hotkey (always works, no widget visibility issues)
        g_keyboard.bindKeyDown('Ctrl+Shift+R', function()
            g_logger.warning("[DevTools] Reloading all modules...")
            g_modules.reloadModules()
            g_logger.warning("[DevTools] Reload complete.")
        end)

        -- Method 2: Try to add button to topmenu if it exists
        local root = g_ui.getRootWidget()
        if not root then return end

        local topMenu = root:recursiveGetChildById('topMenu')
        if topMenu then
            -- Add button inside topmenu (always visible panel)
            reloadButton = g_ui.createWidget('UIWidget', topMenu)
            reloadButton:setId('devReloadButton')
            reloadButton:setHeight(24)
            reloadButton:setBackgroundColor('#0A0A1ACC')
            reloadButton:setBorderWidth(1)
            reloadButton:setBorderColor('#00B4D860')
            -- Append to right side of topmenu
            reloadButton:addAnchor(AnchorRight, 'parent', AnchorRight)
            reloadButton:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
            reloadButton:setMarginRight(6)

            reloadLabel = g_ui.createWidget('Label', reloadButton)
            reloadLabel:setText('Reload')
            reloadLabel:setFont('verdana-11px-rounded')
            reloadLabel:setColor('#00B4D8')
            reloadLabel:setBackgroundColor('alpha')
            reloadLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
            reloadLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
            reloadLabel:setPaddingLeft(8)
            reloadLabel:setPaddingRight(8)

            reloadButton.onMouseRelease = function(self, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    doReload()
                end
            end

            reloadButton:raise()
        else
            -- Fallback: add to root with anchors
            reloadButton = g_ui.createWidget('UIWidget', root)
            reloadButton:setId('devReloadButton')
            reloadButton:setHeight(28)
            reloadButton:setBackgroundColor('#0A0A1ACC')
            reloadButton:setBorderWidth(1)
            reloadButton:setBorderColor('#00B4D860')
            reloadButton:addAnchor(AnchorBottom, 'parent', AnchorBottom)
            reloadButton:addAnchor(AnchorRight, 'parent', AnchorRight)
            reloadButton:setMarginBottom(8)
            reloadButton:setMarginRight(8)

            reloadLabel = g_ui.createWidget('Label', reloadButton)
            reloadLabel:setText('Reload')
            reloadLabel:setFont('verdana-11px-rounded')
            reloadLabel:setColor('#00B4D8')
            reloadLabel:setBackgroundColor('alpha')
            reloadLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
            reloadLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
            reloadLabel:setPaddingLeft(10)
            reloadLabel:setPaddingRight(10)

            reloadButton.onMouseRelease = function(self, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    doReload()
                end
            end

            reloadButton:raise()
        end
    end)
end

function doReload()
    if not reloadButton then return end

    pcall(function()
        reloadButton:setBackgroundColor('#00B4D860')
        reloadLabel:setColor('#FFD700')
    end)

    scheduleEvent(function()
        pcall(function()
            g_modules.reloadModules()
        end)

        scheduleEvent(function()
            if reloadButton then
                pcall(function()
                    reloadButton:setBackgroundColor('#0A0A1ACC')
                    reloadLabel:setColor('#00B4D8')
                end)
                reloadButton:raise()
            end
        end, 300)
    end, 150)
end

function terminate()
    if reloadButton then
        pcall(function() reloadButton:destroy() end)
        reloadButton = nil
        reloadLabel = nil
    end
end
