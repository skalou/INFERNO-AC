-- State of the alert popup: current message, timers, test previews.
local modules = require('core.modules')
local Alert = modules.alert

Alert.latestMessage = ''
Alert.latestAuthorColor = nil
Alert.alertTimeLeft = 0
Alert.alertDuration = 0
Alert.testMode = nil
Alert.textScrollElapsed = 0
Alert.firstScrollRequired = false
Alert.firstScrollComplete = false
Alert.measuredMessage = nil
Alert.testMessagePending = nil

return Alert
