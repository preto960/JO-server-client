---
Task ID: 1
Agent: Main Agent
Task: Fix character cards not appearing in OTClient carousel

Work Log:
- Analyzed uploaded image to understand the visual issue
- Read characterlist.otui and characterlist.lua from JO-server-client repo
- Identified root causes:
  1. `fixed-creature-size: true` on UICreature (line 102 of OTUI) - invalid OTClient property that prevents CharacterWidget template from being registered
  2. No manual card positioning in Lua - all cards stacked at (0,0) since cardContainer has no layout
  3. `setVirtualOffset` used in ensureCardVisible - this API doesn't exist in OTClient
- Reset local repo to match remote (commit 7873f48)
- Applied fixes:
  1. Removed `fixed-creature-size: true` from UICreature in OTUI
  2. Added manual card positioning in rebuildCharactersList: setX/setY for each card with CARD_WIDTH=155, CARD_MARGIN=10
  3. Replaced setVirtualOffset with setX for scrolling in ensureCardVisible
  4. Fixed arrow visibility to use calculated totalCardsWidth instead of unreliable container width
- Committed and pushed to correct repo: JO-server-client (commit 01347bd)
- Verified repo is clean (no web project files)

Stage Summary:
- Push successful to https://github.com/preto960/JO-server-client.git
- Commit 01347bd on main branch
- 3 key fixes: remove invalid property, manual positioning, valid scroll API
