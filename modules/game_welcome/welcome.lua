-- game_welcome - Shows a welcome dialog when entering the game
-- This module is loaded via game_interface's load-later list,
-- which guarantees that the game UI is fully ready before init() runs.

local welcomeBox = nil

function init()
    -- Connect to g_game's onGameStart event
    -- Using addEvent + pcall for safety (avoids any interaction with protocol parsing)
    connect(g_game, {
        onGameStart = function()
            addEvent(function()
                if g_game.isOnline() then
                    local ok, box = pcall(displayInfoBox, 'JO Server', 'Hola!')
                    if ok and type(box) == 'userdata' then
                        welcomeBox = box
                    else
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
    -- Disconnect events to prevent leaks
    disconnect(g_game, {
        onGameStart = function() end,
        onGameEnd = function() end
    })
    -- Clean up any remaining welcome box
    if welcomeBox then
        pcall(function()
            welcomeBox:destroy()
        end)
        welcomeBox = nil
    end
end
