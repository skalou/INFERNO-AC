-- Handles a chat message: matching, sound, history, and popup.
local modules = require('core.modules')
local Alert = modules.alert
local Chat = modules.chat

local defaultAlertSoundFile = modules.paths.defaultAlertSoundFile
local settings = modules.settings.settings
local alertHistory = modules.history.alertHistory
local playAlertSound = modules.sounds.playAlertSound
local isAlertSoundPlaying = modules.sounds.isAlertSoundPlaying
local hiddenSoundQueue = modules.sounds.hiddenSoundQueue
local specialAlertKeys = modules.keywords.specialAlertKeys
local lowerText = modules.keywords.lowerText
local isPlayerMentioned = modules.keywords.isPlayerMentioned
local findMatchedAlert = modules.keywords.findMatchedAlert
local loadKeywordSoundAssignments = modules.keywords.loadKeywordSoundAssignments
local loadMutedKeywords = modules.keywords.loadMutedKeywords
local keywordOptionStore = modules.keywords.keywordOptionStore
local friendList = modules.friends.friendList
local syncKeywordProfile = modules.profiles.syncKeywordProfile

local function handleChatMessage(message, senderCarIndex, simulatedAuthor, simulatedFriend)
  if not message or message == '' then
	return false
  end
  syncKeywordProfile()
  local playerMentioned = isPlayerMentioned(message)
  local friendMessage = simulatedFriend or (senderCarIndex ~= nil and senderCarIndex >= 0 and friendList.isFriend(ac.getDriverName(senderCarIndex)))
  -- Any car on the server counts as a player; the server itself (-1) does not.
  local playerMessage = simulatedAuthor ~= nil or (senderCarIndex ~= nil and senderCarIndex >= 0)
  local senderColor = friendMessage and settings.friendColor or (playerMessage and settings.playerColor) or nil
  local matchedAlert = findMatchedAlert(message, playerMentioned, friendMessage)
  -- Showing all messages does not make non-matching messages play a sound.
  if not matchedAlert and not settings.showAllChatMessages then
	return false
  end

  local author = simulatedAuthor
  if not author and senderCarIndex == -1 then
	author = 'Server'
  elseif not author and senderCarIndex and senderCarIndex >= 0 then
	author = ac.getDriverName(senderCarIndex)
  end
  author = author and author ~= '' and author or 'Unknown'

  local alertOption
  local historyEntry
  if matchedAlert then
	local alertKey = lowerText(matchedAlert)
	alertOption = keywordOptionStore.get(alertKey)
	local muted, soundFile
	if matchedAlert == specialAlertKeys.player then
	  muted, soundFile = settings.mentionSoundMuted, settings.mentionSound
	elseif matchedAlert == specialAlertKeys.friend then
	  muted, soundFile = settings.friendSoundMuted, settings.friendSound
	else
	  muted, soundFile = loadMutedKeywords()[alertKey], loadKeywordSoundAssignments()[alertKey] or defaultAlertSoundFile
	end
	local soundToPlay = (soundFile and soundFile ~= '') and soundFile or defaultAlertSoundFile
	historyEntry = alertHistory.add({
	  time = os.date('%H:%M:%S'),
	  trigger = matchedAlert == specialAlertKeys.player and 'Player mention' or matchedAlert == specialAlertKeys.friend and 'Friend message' or matchedAlert,
	  author = author,
	  authorColor = senderColor or settings.authorColor,
	  message = message,
	  textColor = settings.textColor,
	  hidden = alertOption.hidden and true or false,
	  muted = muted and true or false,
	  soundName = soundToPlay,
	})
	if not muted then
	  -- A hidden entry waits its turn behind the alert sound instead of interrupting it.
	  if alertOption.hidden and (isAlertSoundPlaying() or #hiddenSoundQueue.items > 0) then
		hiddenSoundQueue.add(soundToPlay, alertOption.volume, historyEntry)
	  else
		playAlertSound(soundToPlay, false, nil, alertOption.volume)
	  end
	end
  end
  -- Hidden entries never show the popup, and leave the current or next display untouched.
  if alertOption and alertOption.hidden then
	return false
  end

  Alert.testMode = nil
  local authorPrefix = author:sub(1, 15)
  local maxMessageLength = 2048
  local displayMessage = message:sub(1, maxMessageLength)
  alertHistory.popupReplaced()
  alertHistory.current = historyEntry
  Alert.latestMessage = authorPrefix .. ' : ' .. displayMessage
  Alert.latestAuthorColor = senderColor
  Alert.measuredMessage = nil
  Alert.textScrollElapsed = 0
  Alert.firstScrollRequired = false
  Alert.firstScrollComplete = false
  local duration = math.min(settings.duration + #Alert.latestMessage * 0.08, 15.0)
  Alert.alertDuration = duration
  Alert.alertTimeLeft = Alert.alertDuration
  return false
end

Chat.handleChatMessage = handleChatMessage

return Chat
