-- game_welcome - Shows a welcome dialog when entering the game
-- This module is loaded via game_interface's load-later list,
-- which guarantees that the game UI is fully ready before init() runs.

local welcomeBox = nil

function init()
    -- Connect to g_game's onGameStart event
    connect(g_game, {
        onGameStart = function()
            addEvent(function()
                if g_game.isOnline() then
                    welcomeBox = pcall(displayInfoBox, 'JO Server', 'Hola!')
                    -- pcall with displayInfoBox returns the widget on success
                    if type(welcomeBox) ~= 'userdata' then
                        welcomeBox = nil
                    end
                end
            end)
        end,
        onGameEnd = function()
            -- Close welcome box when leaving game
            if welcomeBox then
                pcall(function()
                    welcomeBox:destroy()
                end)
                welcomeBox = nil
            end
        end
    })
end

function terminate()
    if welcomeBox then
        pcall(function()
            welcomeBox:destroy()
        end)
        welcomeBox = nil
    end
end
