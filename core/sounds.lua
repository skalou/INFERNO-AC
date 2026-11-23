-- Sound files, playback, and the queue for hidden alerts.
local modules = require('core.modules')
local tr = modules.i18n.tr
local Sounds = modules.sounds

local defaultAlertSoundFile = modules.paths.defaultAlertSoundFile
local soundFolder = modules.paths.soundFolder
local settings = modules.settings.settings
local Debug = modules.debug.Debug
local alertHistory = modules.history.alertHistory

Sounds.alertSoundFiles = {}
Sounds.alertSoundFileSet = {}
local soundWarningsLogged = {}
local currentSoundEvent = nil
local currentSoundTestKey = nil
local lastMissingSoundFileName = nil  -- Track missing sound from playAlertSound
local playAlertSound -- assigned below; the recent sounds list previews through it

local function stopCurrentSound()
  local sound = currentSoundEvent
  currentSoundEvent = nil
  currentSoundTestKey = nil
  if sound then
	pcall(function() sound:stop() end)
	pcall(function() sound:dispose() end)
  end

end

local function isSoundTestPlaying(testKey)
  if not testKey or currentSoundTestKey ~= testKey or not currentSoundEvent then return false end
  local ok, playing = pcall(function() return currentSoundEvent:isPlaying() end)
  return ok and playing
end

local function refreshAlertSoundFiles()
Debug.info('Refreshing alert sound files...')
  local soundFiles = {}
  local soundFileSet = {}
  -- Files in the sounds folder win over files with the same name in subfolders. The stored value is the path relative to soundFolder.
  local function scanFolder(folder, prefix)
	local subFolders = {}
	io.scanDir(folder, '*', function(fileName, attributes)
	  if attributes.isDirectory then
		subFolders[#subFolders + 1] = fileName
		return
	  end
	  local extension = fileName:match('%.([^%.]+)$')
	  if extension then
		extension = extension:lower()
		if (extension == 'wav' or extension == 'mp3') and not soundFileSet[fileName] then
		  soundFileSet[fileName] = prefix .. fileName
		  soundFiles[#soundFiles + 1] = fileName
		end
	  end
	end)
	for _, subFolder in ipairs(subFolders) do
	  scanFolder(folder .. '\\' .. subFolder, prefix .. subFolder .. '\\')
	end
  end
  scanFolder(soundFolder, '')
  table.sort(soundFiles)
  Sounds.alertSoundFiles = soundFiles
  Sounds.alertSoundFileSet = soundFileSet
end

-- Shows a stored sound name that is no longer in the sounds folder, so the player can see it is replaced by the default.
local function describeAlertSound(fileName)
  if not fileName or fileName == '' then return defaultAlertSoundFile end
  if Sounds.alertSoundFileSet[fileName] then return fileName end
  return '/!\\ MISSING /!\\: ' .. fileName
end

refreshAlertSoundFiles()

local function isAlertSoundPlaying()
  if not currentSoundEvent then return false end
  local checked, isPlaying = pcall(function() return currentSoundEvent:isPlaying() end)
  return checked and isPlaying
end

local function playSoundFile(fileName, volumePercent)
  stopCurrentSound()
  local fullPath = soundFolder .. '\\' .. (Sounds.alertSoundFileSet[fileName] or fileName)
  local ok, sound = pcall(ac.AudioEvent.fromFile, {
	filename = fullPath,
	use3D = false,
	loop = false
  })
  if ok and sound then
	local valid, isValid = pcall(function() return sound:isValid() end)
	if valid and isValid then
	  local started, err = pcall(function()
		sound.volume = math.min(3, (volumePercent or 100) / 100 * (settings.masterVolume or 100) / 100)
		sound:start()
	  end)
	  if started then
		currentSoundEvent = sound
		return true
	  end
	  pcall(function() sound:dispose() end)
	  if not soundWarningsLogged[fileName] then
		Debug.error('could not play ' .. fileName .. ': ' .. tostring(err))
		soundWarningsLogged[fileName] = true
	  end
	  return false
	end
	pcall(function() sound:dispose() end)
  end
  if not soundWarningsLogged[fileName] then
	Debug.error('could not load audio file ' .. fileName .. (ok and '' or ': ' .. tostring(sound)))
	soundWarningsLogged[fileName] = true
  end
  return false
end

playAlertSound = function(fileName, force, testKey, volumePercent)
  if testKey and currentSoundTestKey == testKey and currentSoundEvent then
	local checked, isPlaying = pcall(function() return currentSoundEvent:isPlaying() end)
	if checked and isPlaying then
	  stopCurrentSound()
	  return
	end
	stopCurrentSound()
  end
  if (not force and not settings.soundEnabled) or not ac.isAudioReady() then return end
  if not Sounds.alertSoundFileSet[fileName] then
	if not soundWarningsLogged[fileName] then
	  Debug.error('audio file is not available in the app folder: ' .. tostring(fileName))
	  soundWarningsLogged[fileName] = true
	end
	lastMissingSoundFileName = fileName  -- Store for UI feedback
	fileName = defaultAlertSoundFile
		if not Sounds.alertSoundFileSet[fileName] then
		  if not soundWarningsLogged[fileName] then
			Debug.error('default alert sound is missing from the sounds folder: ' .. fileName)
			soundWarningsLogged[fileName] = true
		  end
		  return
		end
  end
	if playSoundFile(fileName, volumePercent) then
	currentSoundTestKey = testKey
  elseif fileName ~= defaultAlertSoundFile and Sounds.alertSoundFileSet[defaultAlertSoundFile] and playSoundFile(defaultAlertSoundFile, volumePercent) then
	currentSoundTestKey = testKey
  end
end

-- Sounds of hidden keywords wait here while another alert sound plays, then play in order. A full queue drops new sounds.
local hiddenSoundQueue = { items = {}, maxSize = 5 }

function hiddenSoundQueue.add(fileName, volumePercent, historyEntry)
  if #hiddenSoundQueue.items >= hiddenSoundQueue.maxSize then
    alertHistory.addEvent(historyEntry, tr('Not played: hidden sound queue is full'))
    return
  end
  table.insert(hiddenSoundQueue.items, { fileName = fileName, volumePercent = volumePercent, historyEntry = historyEntry })
  alertHistory.addEvent(historyEntry, tr('Delayed: waiting for the current alert sound to finish'))
end

function hiddenSoundQueue.playNext()
  if #hiddenSoundQueue.items == 0 or isAlertSoundPlaying() then return end
  local nextSound = table.remove(hiddenSoundQueue.items, 1)
  playAlertSound(nextSound.fileName, false, nil, nextSound.volumePercent)
  alertHistory.addEvent(nextSound.historyEntry, tr('Left the queue and started playing'))
end

Sounds.playAlertSound = playAlertSound
Sounds.stopCurrentSound = stopCurrentSound
Sounds.isSoundTestPlaying = isSoundTestPlaying
Sounds.refreshAlertSoundFiles = refreshAlertSoundFiles
Sounds.describeAlertSound = describeAlertSound
Sounds.isAlertSoundPlaying = isAlertSoundPlaying
Sounds.hiddenSoundQueue = hiddenSoundQueue
-- Get the current missing sound (without clearing, so we can track it persistently)
Sounds.getCurrentMissingSoundIfAny = function()
  return lastMissingSoundFileName
end

-- Manually clear the missing sound tracking (called when file is restored)
Sounds.clearMissingSound = function()
  lastMissingSoundFileName = nil
end

return Sounds
