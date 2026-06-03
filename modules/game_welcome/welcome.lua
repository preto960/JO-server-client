welcomeWindow = nil

function init()
    g_ui.importStyle('welcome')
    connect(g_game, {
        onGameStart = function()
            scheduleEvent(1000, function()
                if g_game.isOnline() then
                    showWelcome("Hola!")
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
        welcomeWindow:destroy()
    end
    welcomeWindow = g_ui.createWidget('WelcomeWindow', rootWidget)
    welcomeWindow:getChildById('welcomeMessage'):setText(message)
end
