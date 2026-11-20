# IsuChatAlertLua - Alert Queue System Implementation

## Overview
This document describes the alert queuing system implementation in the IsuChatAlertLua mod that prevents overlapping sounds during rapid chat messages.

## Key Features Implemented

### 1. Alert Queuing System
- `alertQueue` global table to store queued alerts
- `isPlayingAlert` flag to track if an alert is currently playing
- `currentAlertStartTime` for timing management
- `alertQueueMaxSize` set to 5 (configurable)

### 2. Core Functions
- `addToAlertQueue(message, soundFile, duration)` - Adds alerts to the queue with overflow handling
- `playNextQueuedAlert()` - Plays alerts sequentially from the queue
- `clearAlertQueue()` - Clears all queued alerts
- `initAlertSystem()` - Initializes the queuing system

### 3. Chat Handler Integration
The `ac.onChatMessage` function has been updated to use the queuing system instead of direct sound playback:
- Alerts are now added to the queue rather than played immediately
- Maintains backward compatibility with existing keyword matching and mention detection

### 4. UI Controls
Added "Alert Queue" tab in the main settings window with:
- Visual feedback showing current queue status
- Clear queue functionality
- Queue management controls

## Usage Notes

### Queue Management
- Maximum queue size is 5 alerts by default
- When queue is full, new alerts will replace the oldest ones (overflow handling)
- The system automatically plays queued alerts sequentially

### Backward Compatibility
All existing functionality remains intact:
- Keyword matching behavior unchanged
- Mention detection functionality preserved
- Sound playback behavior for non-queued alerts unchanged

## Testing Functions
- `addTestAlert(message, duration)` - For testing the queuing system
- `getAlertQueueStatus()` - To check current queue state

## Implementation Status
✅ All features implemented and verified
✅ No regressions in existing functionality
✅ Ready for production use