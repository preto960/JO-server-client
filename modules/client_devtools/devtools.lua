local reloadButton = nil
local reloadLabel = nil
local raiseEvent = nil

function init()
    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        reloadButton = g_ui.createWidget('UIWidget', root)
        reloadButton:setId('devReloadButton')
        reloadButton:setHeight(28)
        reloadButton:setBackgroundColor('#0A0A1ACC')
        reloadButton:setBorderWidth(1)
        reloadButton:setBorderColor('#00B4D860')
        -- Anchor to bottom-right corner of screen
        reloadButton:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        reloadButton:addAnchor(AnchorRight, 'parent', AnchorRight)
        reloadButton:setMarginBottom(8)
        reloadButton:setMarginRight(8)

        reloadLabel = g_ui.createWidget('Label', reloadButton)
        reloadLabel:setId('devReloadLabel')
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

        -- Keep button always on top every frame
        raiseEvent = cycleEvent(function()
            if reloadButton then
                pcall(function() reloadButton:raise() end)
            else
                if raiseEvent then
                    raiseEvent:cancel()
                    raiseEvent = nil
                end
            end
        end, 500)
    end)
end

function doReload()
    if not reloadButton then return end

    -- Visual feedback: light up
    pcall(function()
        reloadButton:setBackgroundColor('#00B4D860')
        reloadLabel:setColor('#FFD700')
    end)

    -- Reload after brief delay so user sees the flash
    scheduleEvent(function()
        pcall(function()
            g_modules.reloadModules()
        end)

        -- Restore button appearance after reload finishes
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
    if raiseEvent then
        raiseEvent:cancel()
        raiseEvent = nil
    end
    if reloadButton then
        pcall(function() reloadButton:destroy() end)
        reloadButton = nil
        reloadLabel = nil
    end
end
