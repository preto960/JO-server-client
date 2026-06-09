-- skills_custom.lua - Custom skills popup for JO Server
-- Replaces the default docked MiniWindow with a floating popup window
-- Loaded via interface.otmod load-later (after game_skills)

local customWindow = nil
local originalToggle = nil
local isOpen = false

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
        customWindow:hide()

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

function terminate()
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
        centerWindow()
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

function centerWindow()
    local root = g_ui.getRootWidget()
    if root and customWindow then
        local x = (root:getWidth() - customWindow:getWidth()) / 2
        local y = (root:getHeight() - customWindow:getHeight()) / 2
        customWindow:setPosition({ x = x, y = y })
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
