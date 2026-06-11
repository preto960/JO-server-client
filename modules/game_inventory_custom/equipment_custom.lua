-- equipment_custom.lua - Custom equipment window for JO Server
-- Cyberpunk dark/cyan theme, standalone draggable popup
-- Hooks into game inventory events to display equipped items

local equipWindow = nil
local isOpen = false

-- Slot ID -> widget ID mapping (inventory slot constants -> our slot widget IDs)
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

-- Drag state
local dragInfo = {
    active = false,
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

    g_logger.warning("[Equipment] Module loaded, setting up UI...")

    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end
        if not equipWindow:getParent() then
            root:addChild(equipWindow)
        end

        -- Restore saved position or place to the right of chat
        local savedPos = g_settings.getPoint('equipmentCustomWindow/position')
        if savedPos then
            equipWindow:setPosition(savedPos)
        else
            -- Default position: center-right of screen
            local rootSize = root:getSize()
            local winSize = equipWindow:getSize()
            equipWindow:setPosition(topoint(string.format('%d %d',
                math.floor(rootSize.width - winSize.width - 20),
                math.floor((rootSize.height - winSize.height) / 2)
            )))
        end
        equipWindow:hide()

        -- Make header draggable
        local header = equipWindow:recursiveGetChildById('equipHeader')
        if header then
            header.onMousePress = function(widget, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    startDrag(mousePos)
                end
            end
        end

        -- Close button
        local closeBtn = equipWindow:recursiveGetChildById('equipCloseBtn')
        if closeBtn then
            closeBtn.onMouseRelease = function(self, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    addEvent(closeEquipment)
                end
            end
        end

        -- ESC to close
        equipWindow.onKeyPress = function(widget, keyCode, keyboardModifiers)
            if keyboardModifiers == KeyboardNoModifier and keyCode == KeyEscape then
                if isOpen then
                    closeEquipment()
                    return true
                end
            end
        end

        -- Slot hover effect: highlight border on hover
        for slotConst, widgetId in pairs(SLOT_MAP) do
            local slotWidget = equipWindow:recursiveGetChildById(widgetId)
            if slotWidget then
                slotWidget.onHoverChange = function(self, hovered)
                    if hovered then
                        pcall(function()
                            self:setBorderColor('#00B4D8')
                            self:setBorderWidth(2)
                        end)
                    else
                        pcall(function()
                            self:setBorderColor('#00B4D830')
                            self:setBorderWidth(1)
                        end)
                    end
                end
            end
        end

        -- Connect to game start/end events IMMEDIATELY (not deferred)
        connect(g_game, {
            onGameStart = onGameStart,
            onGameEnd = onGameEnd
        })

        -- If already online (e.g. hot-reload), fire onGameStart manually
        if g_game.isOnline() then
            g_logger.warning("[Equipment] Already online, calling onGameStart directly")
            onGameStart()
        else
            g_logger.warning("[Equipment] Waiting for game to start...")
        end
    end)
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    -- Save position
    if equipWindow and equipWindow:getParent() then
        local pos = equipWindow:getPosition()
        g_settings.set('equipmentCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))
    end

    if equipWindow then
        equipWindow:destroy()
        equipWindow = nil
    end
end

-- Drag functions
function startDrag(mousePos)
    if dragInfo.active then return end
    local root = g_ui.getRootWidget()
    if not root then return end

    local overlay = g_ui.createWidget('UIWidget', root)
    overlay:setSize(root:getSize())
    overlay:setBackgroundColor('#00000000')
    overlay:focus()

    local winPos = equipWindow:getPosition()
    local mouseScreen = g_window.getMousePosition()

    dragInfo.active = true
    dragInfo.overlay = overlay
    dragInfo.startPos = {x = winPos.x, y = winPos.y}
    dragInfo.startMouse = {x = mouseScreen.x, y = mouseScreen.y}

    equipWindow:breakAnchors()

    overlay.onMouseMove = function(self, pos, moved)
        if dragInfo.active then
            local dx = pos.x - dragInfo.startMouse.x
            local dy = pos.y - dragInfo.startMouse.y
            equipWindow:setPosition(topoint(string.format('%d %d',
                dragInfo.startPos.x + dx,
                dragInfo.startPos.y + dy
            )))
        end
    end

    overlay.onMouseRelease = function(self, pos, mouseButton)
        if mouseButton == MouseLeftButton then
            stopDrag()
        end
    end
end

function stopDrag()
    if not dragInfo.active then return end
    dragInfo.active = false

    local pos = equipWindow:getPosition()
    g_settings.set('equipmentCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))

    if dragInfo.overlay then
        dragInfo.overlay:destroy()
        dragInfo.overlay = nil
    end

    if equipWindow and equipWindow:isVisible() then
        equipWindow:focus()
    end
end

-- Open / Close
function openEquipment()
    if not equipWindow then return end
    if not g_game.isOnline() then return end

    equipWindow:show()
    equipWindow:raise()
    equipWindow:focus()
    isOpen = true

    -- Refresh all slots
    refreshAllSlots()
end

function closeEquipment()
    if not isOpen then return end
    isOpen = false

    -- Save position
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

-- Game events
function onGameStart()
    -- Register for inventory changes
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

    -- Add sidebar button to open equipment window (3000ms to ensure sidebar is ready)
    scheduleEvent(function()
        pcall(function()
            modules.client_topmenu.addRightGameToggleButton(
                'equipCustomButton',
                'Equipment (Ctrl+E)',
                '/images/options/button_equipment',
                toggleEquipment,
                false
            )
            g_logger.warning("[Equipment] Sidebar button added")
        end)
    end, 3000)

    -- Hotkey: Ctrl+E to toggle equipment
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

-- Inventory change handler
function onInventoryChange(player, slot, item, oldItem)
    local widgetId = SLOT_MAP[slot]
    if not widgetId or not equipWindow then return end

    local slotWidget = equipWindow:recursiveGetChildById(widgetId)
    if not slotWidget then return end

    local itemWidget = slotWidget:recursiveGetChildById('item')
    local labelWidget = slotWidget:recursiveGetChildById('slotLabel')

    if itemWidget then
        pcall(function()
            itemWidget:setItem(item)
            itemWidget:setWidth(34)
            itemWidget:setHeight(34)
        end)
    end

    -- Hide label when item is equipped, show when empty
    if labelWidget then
        pcall(function()
            labelWidget:setVisible(not item)
        end)
    end

    -- Highlight slot briefly when item changes
    if item then
        pcall(function()
            slotWidget:setBackgroundColor('#00B4D820')
            scheduleEvent(function()
                pcall(function()
                    slotWidget:setBackgroundColor('#0A0A1AEE')
                end)
            end, 300)
        end)
    end
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

    -- Refresh soul and capacity
    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())

    -- Refresh all equipment slots
    for slotConst, widgetId in pairs(SLOT_MAP) do
        local item = player:getInventoryItem(slotConst)
        onInventoryChange(player, slotConst, item, nil)
    end
end