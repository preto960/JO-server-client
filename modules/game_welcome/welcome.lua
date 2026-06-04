-- game_welcome - Shows a welcome dialog when entering the game
-- This module is loaded via game_interface's load-later list,
-- which guarantees that the game UI is fully ready before init() runs.

function init()
    -- Connect to g_game's onGameStart event
    -- Using addEvent + pcall for safety (avoids any interaction with protocol parsing)
    connect(g_game, {
        onGameStart = function()
            addEvent(function()
                if g_game.isOnline() then
                    pcall(displayInfoBox, 'JO Server', 'Hola!')
                end
            end)
        end
    })
end

function terminate()
end
