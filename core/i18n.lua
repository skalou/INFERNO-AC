-- Interface translations. The English text is the key: lang/<code>.lua returns a table mapping English text to
-- its translation, and a missing entry falls back to English. Extra arguments are applied with string.format.
local modules = require('core.modules')
local I18n = modules.i18n
local Debug = modules.debug
local settings = modules.settings.settings

local languages = {
  { code = 'auto', name = 'Automatic detection' },
  { code = 'en', name = 'English' },
  { code = 'fr', name = 'Français' },
  { code = 'de', name = 'Deutsch' },
  { code = 'it', name = 'Italiano' },
  { code = 'es', name = 'Español' },
  { code = 'pt_BR', name = 'Português Brasileiro' },
  { code = 'ru', name = 'Русский' },
  { code = 'pl', name = 'Polski' },
  { code = 'tr', name = 'Türkçe' },
  { code = 'nl', name = 'Nederlands' },
  { code = 'cs', name = 'Čeština' },
  { code = 'hu', name = 'Magyar' },
  { code = 'ro', name = 'Română' },
  { code = 'sv', name = 'Svenska' },
  { code = 'fi', name = 'Suomi' },
  { code = 'uk', name = 'Українська' },
  { code = 'zh-CN', name = '简体中文' },
  { code = 'zh-TW', name = '繁體中文' },
}

local packs = {}
local detectedCode

local function languageOption(code)
  local english
  for _, language in ipairs(languages) do
    if language.code == code then return language end
    if language.code == 'en' then english = language end
  end
  return english
end

local function normaliseCode(code)
  return (code:lower():gsub('_', '-'))
end

local launcherCodes = {}
for _, language in ipairs(languages) do
  if language.code ~= 'auto' then launcherCodes[normaliseCode(language.code)] = language.code end
end

-- The launcher uses locale codes such as pt-BR, es-419 or en-US: the full code is tried first, then its language part.
function I18n.languageFromLauncher(value)
  local key = normaliseCode(value or '')
  if launcherCodes[key] then return launcherCodes[key] end
  local primary = key:match('^(%a+)')
  return primary and launcherCodes[primary] or 'en'
end

local function readLauncherLanguage()
  local path = ac.getFolder(ac.FolderID.ACDocuments) .. '\\cfg\\launcher.ini'
  if not io.fileExists(path) then return nil end
  for line in (io.load(path) or ''):gmatch('[^\r\n]+') do
    local value = line:match('^%s*LANGUAGE%s*=%s*(.-)%s*$')
    if value then return value end
  end
  return nil
end

-- Reads the language chosen in the Assetto Corsa launcher (Documents\Assetto Corsa\cfg\launcher.ini).
function I18n.detectLanguage()
  local ok, value = pcall(readLauncherLanguage)
  if not ok then Debug.warn('Cannot read the Assetto Corsa language: %s', tostring(value)) end
  detectedCode = I18n.languageFromLauncher(ok and value or nil)
  return detectedCode
end

local function loadPack(code)
  if code == 'en' then return nil end
  if packs[code] == nil then
    local ok, pack = pcall(require, 'lang.' .. code)
    if not ok then
      Debug.error('Cannot load language %s: %s', code, tostring(pack))
      pack = false
    end
    packs[code] = pack
  end
  return packs[code] or nil
end

function I18n.currentLanguage()
  return languageOption(settings.language)
end

-- The language actually used: the detected one when 'auto' is selected.
function I18n.activeLanguage()
  local language = languageOption(settings.language)
  if language.code == 'auto' then return languageOption(detectedCode or I18n.detectLanguage()) end
  return language
end

function I18n.setLanguage(code)
  settings.language = languageOption(code).code
end

function I18n.tr(text, ...)
  local pack = loadPack(I18n.activeLanguage().code)
  local translated = pack and pack[text] or text
  if select('#', ...) > 0 then return string.format(translated, ...) end
  return translated
end

-- The automatic entry is stored under its English key and translated like any other text.
function I18n.languageName(language)
  if language.code == 'auto' then return I18n.tr(language.name) end
  return language.name
end

I18n.languages = languages

return I18n
