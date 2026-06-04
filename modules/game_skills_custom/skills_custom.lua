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
        -- UI load failed, cannot continue
        return
    end
    -- Override the skills toggle function after game_skills is ready
    addEvent(function()
        if not modules.game_skills or not modules.game_skills.toggle then
            -- game_skills.toggle not found, skip
            return
        end

        -- Save original toggle
        originalToggle = modules.game_skills.toggle

        -- Replace with our custom toggle
        modules.game_skills.toggle = customToggle

        -- Also override the button's onClick directly (in case keybind uses old reference)
        local btn = modules.game_skills.skillsButton
        if btn then
            btn.onClick = function()
                customToggle()
            end
        end

        -- Re-bind the keybind to use our custom toggle
        pcall(function()
            Keybind.delete("Windows", "Show/hide skills windows")
            Keybind.new("Windows", "Show/hide skills windows", "Alt+S", "")
            Keybind.bind("Windows", "Show/hide skills windows", {
                { type = KEY_DOWN, callback = customToggle }
            })
        end)

        -- Close the original skills MiniWindow if it was open
        local sw = modules.game_skills.skillsWindow
        if sw and sw:isVisible() then
            sw:close()
        end
    end)
end

function terminate()
    -- Restore original toggle
    if originalToggle and modules.game_skills then
        modules.game_skills.toggle = originalToggle

        -- Restore button onClick
        local btn = modules.game_skills.skillsButton
        if btn then
            btn.onClick = function()
                originalToggle()
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
    local btn = modules.game_skills and modules.game_skills.skillsButton

    if isOpen then
        -- Close our custom window
        customWindow:hide()
        isOpen = false
        if btn then btn:setOn(false) end
    else
        -- Make sure original MiniWindow is closed
        local sw = modules.game_skills and modules.game_skills.skillsWindow
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
