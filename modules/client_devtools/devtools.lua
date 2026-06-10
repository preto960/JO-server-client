local reloadButton = nil
local reloadLabel = nil

function init()
    g_logger.info("[DevTools] init() called")

    addEvent(function()
        local root = g_ui.getRootWidget()
        g_logger.info("[DevTools] root widget: " .. tostring(root))

        if not root then
            g_logger.warning("[DevTools] No root widget found")
            return
        end

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

        g_logger.info("[DevTools] Button created, parent: " .. tostring(reloadButton:getParent()))

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

        -- Raise on any click/move on the button
        reloadButton.onFocusChange = function(self, focused)
            if focused then
                pcall(function() self:raise() end)
            end
        end

        reloadButton:raise()
        g_logger.info("[DevTools] Button raised, visible: " .. tostring(reloadButton:isVisible()))
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
