-- skills_custom.lua - Custom skills popup for JO Server
-- Replaces the default docked MiniWindow with a floating popup window
-- Loaded via interface.otmod load-later (after game_skills)

local customWindow = nil
local originalToggle = nil
local isOpen = false

-- Drag state
local dragInfo = {
    active = false,
    widget = nil,
    overlay = nil,
    startPos = {x=0, y=0},
    startMouse = {x=0, y=0}
}

local skillNames = nil
local skillLabels = nil

local function initSkillTables()
    skillNames = {
        [Skill.Fist] = 'Fist Fighting',
        [Skill.Club] = 'Club Fighting',
        [Skill.Sword] = 'Sword Fighting',
        [Skill.Axe] = 'Axe Fighting',
        [Skill.Distance] = 'Distance Fighting',
        [Skill.Shielding] = 'Shielding',
        [Skill.Fishing] = 'Fishing',
    }
    skillLabels = {
        [Skill.Fist] = 'lblFist',
        [Skill.Club] = 'lblClub',
        [Skill.Sword] = 'lblSword',
        [Skill.Axe] = 'lblAxe',
        [Skill.Distance] = 'lblDistance',
        [Skill.Shielding] = 'lblShielding',
        [Skill.Fishing] = 'lblFishing',
    }
end

function init()
    initSkillTables()

    local ok = pcall(function()
        customWindow = g_ui.loadUI('skills_custom')
    end)
    if not ok or not customWindow then
        return
    end

    addEvent(function()
        local root = g_ui.getRootWidget()
        if not root then return end

        -- Parent custom window to root so it displays in the UI tree
        if not customWindow:getParent() then
            root:addChild(customWindow)
        end
        -- Restore saved position or center once
        local savedPos = g_settings.getPoint('skillsCustomWindow/position')
        if savedPos then
            customWindow:setPosition(savedPos)
        else
            local rootSize = root:getSize()
            local winSize = customWindow:getSize()
            customWindow:setPosition(topoint(string.format('%d %d',
                math.floor((rootSize.width - winSize.width) / 2),
                math.floor((rootSize.height - winSize.height) / 2)
            )))
        end
        customWindow:hide()

        -- Make the title bar draggable
        local titleBar = customWindow:getChildById('titleBar')
        if titleBar then
            titleBar.onMousePress = function(widget, mousePos, mouseButton)
                if mouseButton == MouseLeftButton then
                    startWindowDrag(customWindow, mousePos)
                end
            end
        end

        -- ESC to close
        customWindow.onKeyPress = function(widget, keyCode, keyboardModifiers)
            if keyboardModifiers == KeyboardNoModifier and keyCode == KeyEscape then
                if isOpen then
                    close()
                    return true
                end
            end
        end

        -- Find skills button by ID and override its onMouseRelease
        local btn = root:recursiveGetChildById('skillsButton')
        if not btn then return end

        -- Save original handler
        originalToggle = btn.onMouseRelease

        -- Replace with our custom handler
        btn.onMouseRelease = function(widget, mousePos, mouseButton)
            if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
                customToggle()
                return true
            end
        end

        -- Re-bind Alt+S to our toggle
        pcall(function()
            Keybind.delete("Windows", "Show/hide skills windows")
            Keybind.new("Windows", "Show/hide skills windows", "Alt+S", "")
            Keybind.bind("Windows", "Show/hide skills windows", {
                { type = KEY_DOWN, callback = customToggle }
            })
        end)

        pcall(function()
            connect(g_game, {
                onGameEnd = onGameEnd
            })
        end)
    end)
end

-- Drag functions
function startWindowDrag(window, mousePos)
    if dragInfo.active then return end
    local root = g_ui.getRootWidget()
    if not root then return end

    -- Create a full-screen transparent overlay to capture all mouse events
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

    -- Break any centering anchors so position sticks
    window:breakAnchors()

    overlay.onMouseMove = function(self, pos, moved)
        if dragInfo.active then
            local dx = pos.x - dragInfo.startMouse.x
            local dy = pos.y - dragInfo.startMouse.y
            dragInfo.widget:setPosition(topoint(string.format('%d %d',
                dragInfo.startPos.x + dx,
                dragInfo.startPos.y + dy
            )))
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

    -- Save position
    if dragInfo.widget then
        local pos = dragInfo.widget:getPosition()
        g_settings.set(dragInfo.widget:getId() .. '/position', tostring(pos.x) .. ' ' .. tostring(pos.y))
    end

    -- Remove overlay
    if dragInfo.overlay then
        dragInfo.overlay:destroy()
        dragInfo.overlay = nil
    end
    dragInfo.widget = nil

    -- Focus back to window
    if customWindow and customWindow:isVisible() then
        customWindow:focus()
    end
end

function terminate()
    -- Save position before destroy
    if customWindow and customWindow:getParent() then
        local pos = customWindow:getPosition()
        g_settings.set('skillsCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))
    end

    pcall(function()
        disconnect(g_game, {
            onGameEnd = onGameEnd
        })
    end)

    if originalToggle then
        local root = g_ui.getRootWidget()
        if root then
            local btn = root:recursiveGetChildById('skillsButton')
            if btn then
                btn.onMouseRelease = originalToggle
            end
        end
        pcall(function()
            Keybind.delete("Windows", "Show/hide skills windows")
            Keybind.new("Windows", "Show/hide skills windows", "Alt+S", "")
            Keybind.bind("Windows", "Show/hide skills windows", {
                { type = KEY_DOWN, callback = originalToggle }
            })
        end)
    end

    if customWindow then
        customWindow:destroy()
        customWindow = nil
    end
    isOpen = false
end

function customToggle()
    local root = g_ui.getRootWidget()
    local btn = root and root:recursiveGetChildById('skillsButton')

    if isOpen then
        -- Save position on close
        local pos = customWindow:getPosition()
        g_settings.set('skillsCustomWindow/position', tostring(pos.x) .. ' ' .. tostring(pos.y))

        customWindow:hide()
        isOpen = false
        if btn then btn:setOn(false) end
    else
        -- Close original skills MiniWindow if visible
        local sw = root and root:recursiveGetChildById('skillWindow')
        if sw and sw:isVisible() then
            sw:close()
        end

        -- Make sure custom window is in the UI tree
        if not customWindow:getParent() and root then
            root:addChild(customWindow)
        end

        populateSkills()
        customWindow:show()
        customWindow:raise()
        customWindow:focus()
        isOpen = true
        if btn then btn:setOn(true) end
    end
end

function close()
    if isOpen then
        customToggle()
    end
end

function onGameEnd()
    if isOpen then
        customWindow:hide()
        local root = g_ui.getRootWidget()
        local btn = root and root:recursiveGetChildById('skillsButton')
        if btn then btn:setOn(false) end
        isOpen = false
    end
end

function populateSkills()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    setLabel('lblLevel', string.format('Level: %d (%d%%)', player:getLevel(), player:getLevelPercent()))
    setLabel('lblXP', string.format('Experience: %s', comma_value(player:getExperience())))
    setLabel('lblMagic', string.format('Magic Level: %d (%d%%)', player:getMagicLevel(), player:getMagicLevelPercent()))
    setLabel('lblHP', string.format('Hit Points: %s / %s', comma_value(player:getHealth()), comma_value(player:getMaxHealth())))
    setLabel('lblMP', string.format('Mana: %s / %s', comma_value(player:getMana()), comma_value(player:getMaxMana())))
    setLabel('lblCap', string.format('Capacity: %s', comma_value(player:getFreeCapacity())))
    setLabel('lblSpeed', string.format('Speed: %d', player:getSpeed()))
    setLabel('lblSoul', string.format('Soul Points: %d', player:getSoul()))

    local stamina = player:getStamina()
    local hours = math.floor(stamina / 60)
    local mins = stamina % 60
    if mins < 10 then mins = '0' .. mins end
    setLabel('lblStamina', string.format('Stamina: %s:%s', hours, mins))

    for skillId, labelId in pairs(skillLabels) do
        local name = skillNames[skillId] or ('Skill ' .. skillId)
        local level = player:getSkillLevel(skillId)
        local percent = player:getSkillLevelPercent(skillId)
        setLabel(labelId, string.format('%s: %d (%d%%)', name, level, percent))
    end
end

function setLabel(id, text)
    if not customWindow then return end
    local label = customWindow:recursiveGetChildById(id)
    if label then
        label:setText(text)
    end
end
