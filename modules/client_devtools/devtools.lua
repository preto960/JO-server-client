local reloadButton = nil
local reloadLabel = nil

function init()
    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        reloadButton = g_ui.createWidget('UIWidget', root)
        reloadButton:setId('devReloadButton')
        reloadButton:setSize(topoint('90 30'))
        reloadButton:setBackgroundColor('#0A0A1ACC')
        reloadButton:setBorderWidth(1)
        reloadButton:setBorderColor('#00B4D860')

        local rootSize = root:getSize()
        reloadButton:setPosition(topoint(string.format('%d %d',
            rootSize.width - 100,
            rootSize.height - 40
        )))

        reloadLabel = g_ui.createWidget('Label', reloadButton)
        reloadLabel:setId('devReloadLabel')
        reloadLabel:setText('Reload')
        reloadLabel:setFont('verdana-11px-rounded')
        reloadLabel:setColor('#00B4D8')
        reloadLabel:setBackgroundColor('alpha')
        reloadLabel:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
        reloadLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)

        reloadButton.onMouseRelease = function(self, mousePos, mouseButton)
            if mouseButton == MouseLeftButton then
                doReload()
            end
        end

        -- Keep button on top
        reloadButton:raise()
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
    if reloadButton then
        pcall(function() reloadButton:destroy() end)
        reloadButton = nil
        reloadLabel = nil
    end
end
