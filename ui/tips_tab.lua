-- Settings window, Tips tab: short guide to how the app works, mostly for new users.
local modules = require('core.modules')
local TipsTab = modules.tipsTab
local settings = modules.settings.settings
local Widgets = modules.widgets

local sections = {
  { 'Getting started', {
    'An alert appears when a chat message matches one of your keywords, mentions your name, or comes from a friend. A sound plays with the alert.',
    'Set your keywords in the Alerts tab. If several entries match, the first one in the list chooses the sound.',
    'Use Display > Test short preview or Test long message to check how alerts look before a race.',
  } },
  { 'Alert window', {
    'Move or resize the alert window by hovering over it. A preview line appears to help you place it.',
    'Enable "Hide alert when not hovered" in Display so the alert disappears unless the cursor is over it.',
  } },
  { 'Keywords', {
    "Drag an entry's handle to change its priority.",
    'Each entry has its own sound, volume, and a play button to test the sound.',
    "The mute button silences an entry's sound. The eye button hides it: a hidden entry still plays its sound but shows no alert.",
    'The built-in entries for your driver name and friends can be moved, muted, or hidden, but not deleted.',
  } },
  { 'Sounds', {
    'Place .wav or .mp3 files in the sounds folder or in its subfolders.',
    'If the selected file is missing, the default sound is used. If the default sound is missing too, alerts are silent.',
  } },
  { 'Profiles', {
    'Enable "Use separate display settings for each car" to give each car its own display.',
    'Enable "Use separate keyword settings per server" to keep a keyword list per server.',
    '"Auto-save settings for each server" saves your settings when you leave a server and restores them when you come back.',
    "Export a profile to share it as a .json file. Importing it on a server asks for confirmation before replacing that server's keywords.",
  } },
  { 'Backups', {
    'Profiles > Save current settings keeps a named copy of your settings. Load selected backup restores one.',
    'The Reset buttons in Tools restore the default values. Save first if you want to keep your current configuration.',
  } },
  { 'Troubleshooting', {
    'No sound? Check "Play alert sound" in the Alerts tab, then the mute button and volume of the entry concerned.',
    'Two alerts for the same message? Disable the old IsuChat Alert app in Custom Shaders Patch.',
    'Friends are only recognised when they are connected to the current race. Their names are not stored.',
    'The History tab keeps recent alerts. Copy history copies them to the clipboard.',
  } },
}

local function drawTipsTab()
  local tr = modules.i18n.tr
  modules.widgets.drawLanguageSelector('##tipsLanguage', 'Language / ' .. tr('Language'))

  if ui.checkbox(tr('I understand (move the Tips tab to the end)') .. '##tipsUnderstood', settings.tipsUnderstood) then
    settings.tipsUnderstood = not settings.tipsUnderstood
  end
  ui.separator()

  for index, section in ipairs(sections) do
    if index > 1 then ui.separator() end
    ui.header(tr(section[1]))
    for _, tip in ipairs(section[2]) do
      Widgets.textWrapped('- ' .. tr(tip))
    end
  end
end

TipsTab.drawTipsTab = drawTipsTab

return TipsTab
