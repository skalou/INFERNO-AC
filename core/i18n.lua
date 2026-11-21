-- Interface translations. The English text is the key: lang/<code>.lua returns a table mapping English text to
-- its translation, and a missing entry falls back to English. Extra arguments are applied with string.format.
local modules = require('core.modules')
local I18n = modules.i18n
local Debug = modules.debug
local settings = modules.settings.settings

local languages = {
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

local function languageOption(code)
  for _, language in ipairs(languages) do
    if language.code == code then return language end
  end
  return languages[1]
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

function I18n.setLanguage(code)
  settings.language = languageOption(code).code
end

function I18n.tr(text, ...)
  local pack = loadPack(languageOption(settings.language).code)
  local translated = pack and pack[text] or text
  if select('#', ...) > 0 then return string.format(translated, ...) end
  return translated
end

I18n.languages = languages

return I18n
