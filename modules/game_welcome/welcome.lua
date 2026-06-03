welcomeWindow = nil

function init()
    g_ui.importStyle('welcome')
    -- Create the window hidden at startup (UI is stable at this point)
    welcomeWindow = g_ui.createWidget('WelcomeWindow', rootWidget)
    welcomeWindow:hide()
    -- Show it when entering the game (just show, no creation)
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

function showWelcome(message)
    if welcomeWindow and not welcomeWindow:isDestroyed() then
        welcomeWindow:getChildById('welcomeMessage'):setText(message)
        welcomeWindow:show()
        welcomeWindow:raise()
        welcomeWindow:focus()
    end
end
