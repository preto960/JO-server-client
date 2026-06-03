/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "framework/net/inputmessage.h"
#include "game.h"
#include "protocolgame.h"
#include <fstream>
#include <chrono>
#include <ctime>

// Debug log helper for crash tracing (non-static so protocolgamesend.cpp can use it)
void loginDebugLog(const std::string& msg) {
    std::ofstream f("crash_debug.log", std::ios::app);
    if (f.is_open()) {
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        f << std::put_time(std::localtime(&time), "[%Y-%m-%d %H:%M:%S] ") << "[C++] " << msg << std::endl;
        f.flush();
    }
}

void ProtocolGame::login(const std::string_view accountName, const std::string_view accountPassword, const std::string_view host, uint16_t port,
                         const std::string_view characterName, const std::string_view authenticatorToken, const std::string_view sessionKey)
{
    loginDebugLog("ProtocolGame::login() host=" + std::string(host) + " port=" + std::to_string(port));
    m_accountName = accountName;
    m_accountPassword = accountPassword;
    m_authenticatorToken = authenticatorToken;
    m_sessionKey = sessionKey;
    m_characterName = characterName;

#ifndef __EMSCRIPTEN__
    loginDebugLog("  calling Protocol::connect()...");
    connect(host, port);
    loginDebugLog("  Protocol::connect() returned");
#else
    if (port == 7172)
        port = 443;
    connect(host, port, true);
#endif
}

void ProtocolGame::onConnect()
{
    loginDebugLog("ProtocolGame::onConnect() START");

    m_firstRecv = true;

    loginDebugLog("  calling Protocol::onConnect()...");
    Protocol::onConnect();
    loginDebugLog("  Protocol::onConnect() returned OK");

    loginDebugLog("  getting local player...");
    m_localPlayer = g_game.getLocalPlayer();
    loginDebugLog("  local player obtained");

    if (g_game.getFeature(Otc::GameProtocolChecksum)) {
        loginDebugLog("  enabling checksum");
        enableChecksum();
    }

    if (!g_game.getFeature(Otc::GameChallengeOnLogin)) {
        loginDebugLog("  calling sendLoginPacket(0,0)...");
        sendLoginPacket(0, 0);
        loginDebugLog("  sendLoginPacket(0,0) returned OK");
    } else {
        loginDebugLog("  GameChallengeOnLogin=enabled, waiting for challenge");
    }

    loginDebugLog("  calling recv()...");
    recv();
    loginDebugLog("ProtocolGame::onConnect() END");
}

void ProtocolGame::onRecv(const InputMessagePtr& inputMessage)
{
    loginDebugLog(">> onRecv() msgSize=" + std::to_string(inputMessage->getMessageSize()) + " firstRecv=" + std::to_string(m_firstRecv));

    m_recivedPackeds += 1;
    m_recivedPackedsSize += inputMessage->getMessageSize();

    if (m_firstRecv) {
        m_firstRecv = false;

        if (g_game.getClientVersion() >= 1405) {
            inputMessage->getU8(); // padding
        } else if (g_game.getFeature(Otc::GameMessageSizeCheck)) {
            const int size = inputMessage->getU16();
            loginDebugLog("  onRecv: GameMessageSizeCheck size=" + std::to_string(size) + " unread=" + std::to_string(inputMessage->getUnreadSize()));
            if (size != inputMessage->getUnreadSize()) {
                g_logger.traceError("invalid message size");
                return;
            }
        }
    }

    loginDebugLog("  onRecv: calling parseMessage...");
    parseMessage(inputMessage);
    loginDebugLog("  onRecv: parseMessage returned OK");
    recv();
}

void ProtocolGame::onError(const std::error_code& error)
{
    g_game.processConnectionError(error);
    disconnect();
}
