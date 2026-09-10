$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourcePath = Join-Path $root 'gadgets_v10.asm'
$exePath = Join-Path $root 'gadgets_v10.exe'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$source = Get-Content -LiteralPath $sourcePath -Raw
$ini = "TimeAnnouncementMinutes=0`r`nSpeechLanguage=0`r`n"
$exeBytes = [IO.File]::ReadAllBytes($exePath)
$exeAscii = [Text.Encoding]::ASCII.GetString($exeBytes)

$requiredContracts = @(
    "app_name          db 'Gadgets v10'",
    "ini_name          db 'gadgets_v10.ini'",
    'proc UpdateCalendarDate',
    'proc PaintCalendar',
    'CreateCompatibleDC',
    'CreateCompatibleBitmap',
    'BitBlt',
    'test    eax, eax',
    'InvalidateRect, [hwnd], 0, FALSE',
    "args_now          db '/p /f'",
    "shutdown_abort_command db 'shutdown.exe /a'",
    'proc SpeakShutdownNow',
    'proc SpeakShutdownScheduled',
    'proc SpeakShutdownCancelled',
    'proc SpeakCurrentDate',
    'proc ReadSpeechLanguageFromDialog',
    'proc SelectSpeechVoice',
    'proc RefreshSpeechAvailability',
    'proc UpdateSpeechLanguageControls',
    'CLSID_SpObjectTokenCategory',
    'IID_ISpObjectTokenCategory',
    'EnumTokens',
    'SetVoice',
    'speech_voice_attributes',
    'speech_voice_fallback_attributes',
    'speech_voice_onecore_category',
    'speech_voice_categories',
    'speech_voice_ready',
    'sapi_default_token',
    'speech_language_available',
    "speech_settings_uri db 'ms-settings:speech'",
    'shutdown_now_prompts',
    'shutdown_scheduled_formats',
    'shutdown_cancelled_prompts',
    'shutdown_failed_prompts',
    'speech_time_formats',
    'speech_date_formats',
    'move_prompt_normal_ptrs',
    'move_prompt_alternate_ptrs',
    "key_speechlanguage db 'SpeechLanguage'",
    'GetTimeFormatW',
    'GetDateFormatW',
    'SPF_IS_XML',
    "language_mandarin db 'Mandarin'",
    "language_french   db 'French'",
    'speech_time_fr',
    'speech_date_fr',
    'move_normal_fr',
    'move_alternate_fr',
    'shutdown_now_fr',
    'shutdown_scheduled_fr',
    'shutdown_cancelled_fr',
    'shutdown_failed_fr',
    'SetWindowText, [min3_button], cancel_text',
    'SetWindowText, [min3_button], delay_text',
    'proc RunShutdownCommand',
    'GetExitCodeProcess',
    'cmp     [shutdown_active], 0',
    'jne     .cancel_shutdown'
)
foreach ($required in $requiredContracts) {
    Assert-True $source.Contains($required) "Missing source contract: $required"
}

$timerBlock = [regex]::Match($source, '(?s)  \.timer:.*?  \.command:').Value
Assert-True $timerBlock.Contains('call    UpdateCalendarDate') 'Timer must use date-aware calendar refresh.'
Assert-True (-not $timerBlock.Contains('InvalidateRect, [calendar_hwnd]')) 'Timer still repaints the calendar every second.'
Assert-True (-not $timerBlock.Contains('InvalidateRect, [volume_hwnd]')) 'Timer still repaints the idle volume panel every second.'

$shutdownBlock = [regex]::Match($source, '(?s)  \.shutdown_now:.*?  \.bad_delay:').Value
Assert-True (-not $shutdownBlock.Contains('MessageBox')) 'Shutdown success paths must not display an app dialog.'
Assert-True (-not $source.Contains('confirm_shutdown')) 'Legacy immediate-shutdown confirmation remains.'
Assert-True (-not $source.Contains('  scheduled_format  db ')) 'Legacy scheduled-shutdown information dialog remains.'

$hoverBlock = [regex]::Match($source, '(?s)  \.mousemove:.*?  \.leftclick:').Value
Assert-True (-not $hoverBlock.Contains('InvalidateRect, [hwnd], 0, TRUE')) 'Hover still requests background-erasing repaints.'

$clickBlock = [regex]::Match($source, '(?s)  \.leftclick:.*?  \.leftup:').Value
Assert-True $clickBlock.Contains('call    SpeakCurrentTime') 'Clock left-click speech is missing.'
Assert-True $clickBlock.Contains('call    SpeakCurrentDate') 'Full-date left-click speech is missing.'
Assert-True $clickBlock.Contains('cmp     eax, 368') 'Full-date click hit area is missing.'

$shutdownPaintBlock = [regex]::Match($source, '(?s)proc PaintShutdown.*?endp').Value
Assert-True $shutdownPaintBlock.Contains('TextOut, ebx, 125, 19, shutdown_label_text') 'Shutdown label is not above the buttons.'
Assert-True ($source -match 'SHUT_H\s+= 126') 'Shutdown panel height does not accommodate the title and lowered controls.'
Assert-True ($source -match 'invoke\s+MulDiv, 28, \[scale_percent\], 100\s+mov\s+\[ctrl_y1\], eax') 'Scaled shutdown buttons were not moved below the title.'
Assert-True ($source -match 'shutdown_progress_track RECT 7,69,243,91') 'Shutdown progress bar was not moved below the buttons.'
Assert-True ($source -match 'edit_y\s+dd 69') 'Shutdown delay field was not moved with the progress area.'

Assert-True ($source -match "dialog settings_dialog, 'Gadget Settings', 0, 0, 280, 340") 'Settings dialog is not the compact voice-aware layout.'
Assert-True $source.Contains("dialogitem 'BUTTON','English',IDC_LANG_ENGLISH") 'Speech-language radio controls are missing.'
Assert-True $source.Contains("dialogitem 'BUTTON','Manage voices...',IDC_MANAGEVOICES") 'Windows voice-management button is missing.'
Assert-True $source.Contains("dialogitem 'BUTTON','Refresh',IDC_REFRESHVOICES") 'Voice availability refresh button is missing.'
foreach ($language in @('English','Polish','Italian','Spanish','German','Japanese','Mandarin','French')) {
    Assert-True $source.Contains("db '$language',0") "Missing speech language: $language"
}
$voiceSelectionBlock = [regex]::Match($source, '(?s)proc SelectSpeechVoice.*?endp').Value
Assert-True $voiceSelectionBlock.Contains('EnumTokens') 'Voice selection must enumerate matching installed SAPI voices.'
Assert-True $voiceSelectionBlock.Contains('GetCount') 'Voice selection must reject an empty matching voice set.'
Assert-True $voiceSelectionBlock.Contains('SetVoice') 'Voice selection must apply the matching installed token.'
Assert-True ($voiceSelectionBlock.Contains('speech_voice_fallback_attributes')) 'Voice selection must try a language-family or Mandarin fallback.'
Assert-True $voiceSelectionBlock.Contains('sapi_default_token') 'English must restore the original default SAPI voice.'
Assert-True $voiceSelectionBlock.Contains('speech_voice_categories') 'Voice selection must search both desktop SAPI and OneCore categories.'
Assert-True ($voiceSelectionBlock -match 'cmp\s+\[category_attempt\], 2') 'Voice selection does not attempt both Windows voice categories.'
Assert-True $source.Contains('EnableWindow, eax, [speech_language_available+esi*4]') 'Unavailable speech languages are not greyed out.'
Assert-True $source.Contains('ShellExecute, [hwnddlg], NULL, speech_settings_uri') 'Manage voices must open Windows Speech settings only on user request.'
Assert-True (([regex]::Matches($source, 'cmp\s+\[speech_voice_ready\], 0')).Count -eq 7) 'Every spoken path must reject a missing selected-language voice.'

Assert-True ($ini -match '(?m)^TimeAnnouncementMinutes=(0|30|60)\r?$') 'v10 INI announcement value must be Off, 30, or 60.'
Assert-True ($ini -match '(?m)^SpeechLanguage=[0-7]\r?$') 'v10 INI speech language must be in the supported 0-7 range.'
foreach ($importName in @('SHELL32.DLL', 'ShellExecuteA', 'OLE32.DLL', 'CoCreateInstance', 'GDI32.DLL', 'BitBlt', 'CreateCompatibleDC', 'CreateCompatibleBitmap', 'CreateProcessA', 'WaitForSingleObject', 'GetExitCodeProcess', 'GetTimeFormatW', 'GetDateFormatW', 'wsprintfW')) {
    Assert-True $exeAscii.Contains($importName) "Missing PE import: $importName"
}

[pscustomobject]@{
    SourceContracts = $requiredContracts.Count
    TimerContracts = 3
    ShutdownContracts = 3
    HoverContracts = 1
    ClickSpeechContracts = 3
    LanguageContracts = 26
    VoiceSelectionContracts = 10
    CompactLayoutContracts = 4
    PeImports = 14
    Result = 'PASS'
}
