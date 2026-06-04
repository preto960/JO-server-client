-- skills_custom.lua - Custom skills popup for JO Server
-- Replaces the default docked MiniWindow with a floating popup window
-- Loaded via interface.otmod load-later (after game_skills)

local customWindow = nil
local originalToggle = nil
local isOpen = false

-- Skill name mapping (standard OTClient Skill enum)
-- Initialized inside init() for safety (enums may not be available at parse time)
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
    -- Initialize skill tables (needs Skill enum which is available at runtime)
    initSkillTables()

    -- Load custom UI
    local ok, err = pcall(function()
        customWindow = g_ui.loadUI('skills_custom')
    end)
    if not ok then
        return
    end

    -- Wait for UI to be ready, then find and override the skills button
    addEvent(function()
        -- Find the skills button by ID directly from the UI tree
        -- (modules.game_skills.skillsButton may not be accessible from sandboxed modules)
        local root = g_ui.getRootWidget()
        if not root then return end
        local btn = root:recursiveGetChildById('skillsButton')
        if not btn then return end

        -- Save original onClick to restore on terminate
        originalToggle = btn.onClick

        -- Override the button's onClick with our custom toggle
        btn.onClick = function()
            customToggle()
        end

        -- Re-bind Alt+S keybind to our custom toggle
        pcall(function()
            Keybind.delete("Windows", "Show/hide skills windows")
            Keybind.new("Windows", "Show/hide skills windows", "Alt+S", "")
            Keybind.bind("Windows", "Show/hide skills windows", {
                { type = KEY_DOWN, callback = customToggle }
            })
        end)

        -- Close the original skills MiniWindow if it was open
        local sw = root:recursiveGetChildById('skillWindow')
        if sw and sw:isVisible() then
            sw:close()
        end
    end)
end

function terminate()
    -- Restore original button onClick
    if originalToggle then
        local root = g_ui.getRootWidget()
        if root then
            local btn = root:recursiveGetChildById('skillsButton')
            if btn and originalToggle then
                btn.onClick = originalToggle
            end
        end

        -- Restore keybind
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
        -- Make sure original MiniWindow is closed
        local sw = root and root:recursiveGetChildById('skillWindow')
        if sw and sw:isVisible() then
            sw:close()
        end

        -- Populate and show custom window
        populateSkills()
        customWindow:show()
        customWindow:focus()
        customWindow:raise()
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

function centerWindow()
    local gw = g_window
    if gw then
        local x = (gw.getWidth() - customWindow:getWidth()) / 2
        local y = (gw.getHeight() - customWindow:getHeight()) / 2
        customWindow:setPosition({ x = x, y = y })
    end
end

function populateSkills()
    local player = g_game.getLocalPlayer()
    if not player then
        -- no local player, cannot populate
        return
    end

    -- Level
    setLabel('lblLevel', string.format('Level: %d (%d%%)', player:getLevel(), player:getLevelPercent()))

    -- XP
    setLabel('lblXP', string.format('Experience: %s', comma_value(player:getExperience())))

    -- Magic Level
    setLabel('lblMagic', string.format('Magic Level: %d (%d%%)', player:getMagicLevel(), player:getMagicLevelPercent()))

    -- HP
    setLabel('lblHP', string.format('Hit Points: %s / %s', comma_value(player:getHealth()), comma_value(player:getMaxHealth())))

    -- MP
    setLabel('lblMP', string.format('Mana: %s / %s', comma_value(player:getMana()), comma_value(player:getMaxMana())))

    -- Capacity
    setLabel('lblCap', string.format('Capacity: %s', comma_value(player:getFreeCapacity())))

    -- Speed
    setLabel('lblSpeed', string.format('Speed: %d', player:getSpeed()))

    -- Soul
    setLabel('lblSoul', string.format('Soul Points: %d', player:getSoul()))

    -- Stamina
    local stamina = player:getStamina()
    local hours = math.floor(stamina / 60)
    local mins = stamina % 60
    if mins < 10 then mins = '0' .. mins end
    setLabel('lblStamina', string.format('Stamina: %s:%s', hours, mins))

    -- Combat Skills
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
