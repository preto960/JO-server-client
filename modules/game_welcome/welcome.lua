welcomeWindow = nil

function init()
    g_ui.importStyle('welcome')
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
