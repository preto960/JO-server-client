welcomeWindow = nil

function init()
    g_ui.importStyle('welcome')
    -- Create window hidden at startup (UI is stable before any connection)
    welcomeWindow = g_ui.createWidget('WelcomeWindow', rootWidget)
    welcomeWindow:hide()
    -- Show it 5 seconds after entering the game
    connect(g_game, {
        onGameStart = function()
            scheduleEvent(5000, function()
                if g_game.isOnline() and welcomeWindow and not welcomeWindow:isDestroyed() then
                    welcomeWindow:show()
                    welcomeWindow:raise()
                    welcomeWindow:focus()
                end
            end)
        end,
    })
end

function terminate()
    if welcomeWindow and not welcomeWindow:isDestroyed() then
        welcomeWindow:destroy()
    end
end
