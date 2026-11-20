# IsuChatAlertLua Project Summary

## Overview
This project is a chat alert system for Assetto Corsa that provides keyword-based notifications with sound alerts and visual display. The system was enhanced to fix crashes and implement a robust queuing system to prevent overlapping sounds during rapid chat messages.

## Key Changes Implemented

### 1. Core Queue System Integration
- **Fixed Critical Issue**: `ac.onChatMessage` was calling `playAlertSound()` directly instead of using the queue system
- **Implemented Sequential Alert Playback**: Alerts now play sequentially with proper queuing behavior
- **Queue Management**: Maximum 5 alerts in queue with overflow handling (oldest replaced by newest)
- **Status Tracking**: Added `isPlayingAlert` flag to track alert playback state

### 2. Performance Optimizations
- **Sound Caching System**: Implemented sound caching to reduce memory usage and improve performance
- **Memory Monitoring**: Added periodic memory usage monitoring to detect potential leaks
- **Debug Logging**: Integrated debug logging system with configurable log levels
- **Performance Statistics**: Added functions to retrieve system performance metrics

### 3. Crash Fixes
- **Session ID Fallback**: Replaced problematic `ac.getSessionID()` with robust fallback mechanism:
  - Online sessions: `ac.getServerName()` + `ac.getServerIP()`
  - Solo sessions: `ac.getDriverName(0)` + `ac.getCarName()`
- **Window Open Crashes**: Removed problematic `ac.setWindowOpen()` calls that were causing crashes

### 4. Enhanced Functionality
- **Backward Compatibility**: All existing functionality preserved
- **Keyword Detection**: Works in both solo and multiplayer modes
- **Mention Detection**: Properly handles player mentions with sound notifications
- **UI Controls**: Added "Alert Queue" tab in main settings window for queue management

## Files Overview

### Main Files:
1. `isuChatAlertLua.lua` - Core implementation with queue system and performance optimizations
2. `performance_optimizations.lua` - Separate file containing performance enhancements
3. `manifest.ini` - Project manifest defining windows and settings

### Supporting Files:
- `FIX_SUMMARY.md` - Summary of fixes applied
- `IMPLEMENTATION_NOTES.md` - Detailed implementation notes
- `README_AI_NOTES.md` - AI conversation notes and context
- Various sound files in the `sounds/` directory

## Technical Details

### Queue System Components:
- `alertQueue`: Global table storing queued alerts
- `isPlayingAlert`: Flag tracking if an alert is currently playing
- `alertQueueMaxSize`: Maximum queue size (5 alerts)
- `addToAlertQueue()`: Function to add alerts to the queue
- `playNextQueuedAlert()`: Function to play alerts sequentially
- `clearAlertQueue()`: Function to clear all queued alerts

### Performance Features:
- Sound caching with LRU (Least Recently Used) cache management
- Memory usage monitoring with history tracking
- Debug logging system with configurable log levels
- Performance statistics retrieval functions

## Usage Notes

### Queue Management:
- Maximum queue size is 5 alerts by default
- When queue is full, new alerts replace the oldest ones (overflow handling)
- System automatically plays queued alerts sequentially

### Backward Compatibility:
All existing functionality remains intact:
- Keyword matching behavior unchanged
- Mention detection functionality preserved
- Sound playback behavior for non-queued alerts unchanged

## Testing Functions
- `addTestAlert(message, duration)` - For testing the queuing system
- `getAlertQueueStatus()` - To check current queue state
- `getPerformanceStats()` - To retrieve performance metrics

## Implementation Status
✅ All features implemented and verified
✅ No regressions in existing functionality  
✅ Ready for production use

## AI Discussion Context
This project was developed with assistance from an AI coding agent. During development, there was a humorous moment when the AI mentioned "hakuna matata" in response to a question about session ID fallback mechanisms - referencing how the fallback methods provide reliable alternatives when primary methods fail.