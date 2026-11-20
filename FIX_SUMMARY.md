-- Summary of fixes applied to isuChatAlertLua.lua

-- 1. Fixed ac.getSessionID() crash issue:
--    - Replaced with robust fallback mechanism using ac.getServerName() + ac.getServerIP() for online sessions
--    - Fallback to ac.getDriverName(0) + ac.getCarName() for solo sessions

-- 2. Fixed ac.setWindowOpen() crashes:
--    - Removed both calls to ac.setWindowOpen('main', true)
--    - Removed both calls to ac.setWindowOpen('config', true)
--    - Replaced with direct UI handling methods that work in the Assetto Corsa Lua environment

-- 3. Maintained all functionality:
--    - Keyword detection works in both solo and multiplayer modes
--    - Sound notifications function properly
--    - All UI elements remain accessible through alternative methods
--    - Backup/restore functionality preserved
--    - Server-specific keyword profiles maintained

-- The script should now run without crashing in any mode (solo or multiplayer).