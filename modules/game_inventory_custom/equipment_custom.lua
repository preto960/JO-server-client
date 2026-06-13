local equipWindow = nil
local isOpen = false

local SLOT_MAP = {
    [InventorySlotHead]   = 'slot_helmet',
    [InventorySlotNeck]   = 'slot_amulet',
    [InventorySlotBack]   = 'slot_backpack',
    [InventorySlotBody]   = 'slot_armor',
    [InventorySlotRight]  = 'slot_shield',
    [InventorySlotLeft]   = 'slot_sword',
    [InventorySlotLeg]    = 'slot_legs',
    [InventorySlotFeet]   = 'slot_boots',
    [InventorySlotFinger] = 'slot_ring',
    [InventorySlotAmmo]   = 'slot_tools',
}

local SLOT_TOGGLER = {
    slot_helmet   = 'helmet',
    slot_amulet   = 'amulet',
    slot_backpack = 'backpack',
    slot_armor    = 'armor',
    slot_shield   = 'shield',
    slot_sword    = 'sword',
    slot_legs     = 'legs',
    slot_boots    = 'boots',
    slot_ring     = 'ring',
    slot_tools    = 'tools',
}

local dragInfo = {
    active = false,
    widget = nil,
    overlay = nil,
    startPos = {x=0, y=0},
    startMouse = {x=0, y=0}
}

function init()
    local ok = pcall(function()
        equipWindow = g_ui.loadUI('equipment_custom')
    end)
    if not ok or not equipWindow then
        g_logger.warning("[Equipment] Failed to load equipment_custom.otui")
        return
    end

    g_logger.warning("[Equipment] Module loaded")

    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        if not equipWindow:getParent() then
            root:addChild(equipWindow)
        end

        local slotIds = {'slot_helmet', 'slot_amulet', 'slot_armor', 'slot_backpack', 'slot_sword', 'slot_legs', 'slot_shield', 'slot_ring', 'slot_boots', 'slot_tools'}
        for _, sid in ipairs(slotIds) do
            local slot = equipWindow:recursiveGetChildById(sid)
            if slot then
                local rb = g_ui.createWidget('UIWidget', slot)
                rb:setWidth(1)
                rb:setBackgroundColor('#00B4D860')
                rb:setPhantom(true)
                rb:addAnchor(AnchorRight, 'parent', AnchorRight)
                rb:addAnchor(AnchorTop, 'parent', AnchorTop)
                rb:addAnchor(AnchorBottom, 'parent', AnchorBottom)

                local bb = g_ui.createWidget('UIWidget', slot)
                bb:setHeight(1)
                bb:setBackgroundColor('#00B4D860')
                bb:setPhantom(true)
                bb:addAnchor(AnchorBottom, 'parent', AnchorBottom)
                bb:addAnchor(AnchorLeft, 'parent', AnchorLeft)
                bb:addAnchor(AnchorRight, 'parent', AnchorRight)
            end
        end

        local savedPos = g_settings.getPoint('equipmentCustomWindow/position')
        if savedPos then
            pcall(function() equipWindow:setPosition(savedPos) end)
        else
            pcall(function()
                local rw = root:getWidth()
                local rh = root:getHeight()
                local ww = equipWindow:getWidth()
                local wh = equipWindow:getHeight()
                if ww > 0 and wh > 0 then
                    equipWindow:setX(rw - ww - 20)
                    equipWindow:setY(math.floor((rh - wh) / 2))
                end
            end)
        end
        equipWindow:hide()

        local titleBar = equipWindow:getChildById('titleBar')
        if titleBar then
            titleBar.onMousePress = function(widget, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    startWindowDrag(equipWindow, mousePos)
                end
            end
        end

        equipWindow.onKeyPress = function(widget, keyCode, keyboardModifiers)
            if keyboardModifiers == KeyboardNoModifier and keyCode == KeyEscape then
                if isOpen then
                    closeEquipment()
                    return true
                end
            end
        end

        connect(g_game, {
            onGameStart = onGameStart,
            onGameEnd = onGameEnd
        })

        if g_game.isOnline() then
            g_logger.warning("[Equipment] Already online, calling onGameStart directly")
            onGameStart()
        else
            g_logger.warning("[Equipment] Waiting for game to start...")
        end
    end)
end

function terminate()
    if equipWindow and equipWindow:getParent() then
        local pos = equipWindow:getPosition()
        g_settings.set('equipmentCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))
    end

    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if equipWindow then
        equipWindow:destroy()
        equipWindow = nil
    end
    isOpen = false
end

function startWindowDrag(window, mousePos)
    if dragInfo.active then return end
    local root = g_ui.getRootWidget()
    if not root then return end

    local overlay = g_ui.createWidget('UIWidget', root)
    overlay:setSize(root:getSize())
    overlay:setBackgroundColor('#00000000')
    overlay:focus()

    local winPos = window:getPosition()
    local mouseScreen = g_window.getMousePosition()

    dragInfo.active = true
    dragInfo.widget = window
    dragInfo.overlay = overlay
    dragInfo.startPos = {x = winPos.x, y = winPos.y}
    dragInfo.startMouse = {x = mouseScreen.x, y = mouseScreen.y}

    window:breakAnchors()

    overlay.onMouseMove = function(self, pos, moved)
        if dragInfo.active then
            local dx = pos.x - dragInfo.startMouse.x
            local dy = pos.y - dragInfo.startMouse.y
            pcall(function()
                dragInfo.widget:setX(dragInfo.startPos.x + dx)
                dragInfo.widget:setY(dragInfo.startPos.y + dy)
            end)
        end
    end

    overlay.onMouseRelease = function(self, pos, mouseButton)
        if mouseButton == MouseLeftButton then
            stopWindowDrag()
        end
    end
end

function stopWindowDrag()
    if not dragInfo.active then return end
    dragInfo.active = false

    if dragInfo.widget then
        local pos = dragInfo.widget:getPosition()
        g_settings.set('equipmentCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))
    end

    if dragInfo.overlay then
        dragInfo.overlay:destroy()
        dragInfo.overlay = nil
    end
    dragInfo.widget = nil

    if equipWindow and equipWindow:isVisible() then
        equipWindow:focus()
    end
end

function openEquipment()
    if not equipWindow then return end
    if not g_game.isOnline() then return end

    if not equipWindow:getParent() then
        local root = g_ui.getRootWidget()
        if root then root:addChild(equipWindow) end
    end

    refreshAllSlots()
    equipWindow:show()
    equipWindow:raise()
    equipWindow:focus()
    isOpen = true

    pcall(function()
        local savedPos = g_settings.getPoint('equipmentCustomWindow/position')
        if savedPos and savedPos.x > 0 and savedPos.y > 0 then
            equipWindow:setX(savedPos.x)
            equipWindow:setY(savedPos.y)
        end
    end)
end

function closeEquipment()
    if not isOpen then return end
    isOpen = false

    if dragInfo.active then
        stopWindowDrag()
    end

    local pos = equipWindow:getPosition()
    g_settings.set('equipmentCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))

    equipWindow:hide()
end

function toggleEquipment()
    if isOpen then
        closeEquipment()
    else
        openEquipment()
    end
end

function onGameStart()
    pcall(function()
        local player = g_game.getLocalPlayer()
        if player then
            connect(player, {
                onInventoryChange = onInventoryChange,
                onSoulChange = onSoulChange,
                onFreeCapacityChange = onFreeCapacityChange
            })
        end
    end)

    addEvent(function()
        pcall(function()
            modules.client_topmenu.addRightGameToggleButton(
                'equipCustomButton',
                'Equipment (Ctrl+E)',
                '/images/options/button_equipment',
                toggleEquipment,
                false
            )
        end)
    end)

    g_keyboard.bindKeyDown('Ctrl+E', function()
        if g_game.isOnline() then
            toggleEquipment()
        end
    end)
end

function onGameEnd()
    closeEquipment()
    pcall(function()
        local player = g_game.getLocalPlayer()
        if player then
            disconnect(player, {
                onInventoryChange = onInventoryChange,
                onSoulChange = onSoulChange,
                onFreeCapacityChange = onFreeCapacityChange
            })
        end
    end)
end

function onInventoryChange(player, slot, item, oldItem)
    local widgetId = SLOT_MAP[slot]
    if not widgetId or not equipWindow then return end

    local slotWidget = equipWindow:recursiveGetChildById(widgetId)
    if not slotWidget then return end

    pcall(function()
        local itemWidget = slotWidget:getChildById('item')
        if itemWidget then
            itemWidget:setItem(item)
        end

        local togglerName = SLOT_TOGGLER[widgetId]
        if togglerName then
            local toggler = slotWidget:getChildById(togglerName)
            if toggler then
                toggler:setEnabled(not item)
            end
        end
    end)
end

function onSoulChange(localPlayer, soul)
    if not equipWindow then return end
    local label = equipWindow:recursiveGetChildById('soulValue')
    if label and soul then
        label:setText(tostring(soul))
    end
end

function onFreeCapacityChange(player, freeCapacity)
    if not equipWindow then return end
    local label = equipWindow:recursiveGetChildById('capValue')
    if label and freeCapacity then
        local text = freeCapacity
        if freeCapacity > 99999 then
            text = math.min(9999, math.floor(freeCapacity / 1000)) .. "k"
        elseif freeCapacity > 999 then
            text = math.floor(freeCapacity)
        elseif freeCapacity > 99 then
            text = math.floor(freeCapacity * 10) / 10
        end
        label:setText(tostring(text))
    end
end

function refreshAllSlots()
    local player = g_game.getLocalPlayer()
    if not player or not equipWindow then return end

    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())

    for slotConst, widgetId in pairs(SLOT_MAP) do
        local item = player:getInventoryItem(slotConst)
        onInventoryChange(player, slotConst, item, nil)
    end
end