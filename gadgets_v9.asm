


; Gadgets v9 - scalable, hideable, configurable desktop panels with SAPI time announcements.

format PE GUI 4.0
entry start

include 'win32a.inc'

struc GUID def
 {
   match d1-d2-d3-d4-d5, def
    \{
      .Data1 dd 0x\#d1
      .Data2 dw 0x\#d2
      .Data3 dw 0x\#d3
      .Data4 db 0x\#d4 shr 8,0x\#d4 and 0FFh
      .Data5 db 0x\#d5 shr 40,0x\#d5 shr 32 and 0FFh,0x\#d5 shr 24 and 0FFh,0x\#d5 shr 16 and 0FFh,0x\#d5 shr 8 and 0FFh,0x\#d5 and 0FFh
    \}
 }

interface ISpVoice,\
          QueryInterface,\
          AddRef,\
          Release,\
          SetNotifySink,\
          SetNotifyWindowMessage,\
          SetNotifyCallbackFunction,\
          SetNotifyCallbackInterface,\
          SetNotifyWin32Event,\
          WaitForNotifyEvent,\
          GetNotifyEventHandle,\
          SetInterest,\
          GetEvents,\
          GetInfo,\
          SetOutput,\
          GetOutputObjectToken,\
          GetOutputStream,\
          Pause,\
          Resume,\
          SetVoice,\
          GetVoice,\
          Speak,\
          SpeakStream,\
          GetStatus,\
          Skip,\
          SetPriority,\
          GetPriority,\
          SetAlertBoundary,\
          GetAlertBoundary,\
          SetRate,\
          GetRate,\
          SetVolume,\
          GetVolume,\
          WaitUntilDone,\
          SetSyncSpeakTimeout,\
          GetSyncSpeakTimeout,\
          SpeakCompleteEvent,\
          IsUISupported,\
          DisplayUI

IDC_NOW       = 201
IDC_3MIN      = 202
IDC_DELAYEDIT = 203
IDD_SETTINGS  = 300
IDC_APPLY     = 302
IDC_CLOCKSIZE = 301
IDC_CLOCKBOLD = 303
IDC_CALSIZE   = 304
IDC_CALBOLD   = 305
IDC_MONTHSIZE = 306
IDC_MONTHBOLD = 307
IDC_DAYSIZE   = 308
IDC_DAYBOLD   = 309
IDC_SCALE     = 310
IDC_OPACITY   = 311
IDC_SHOWCLOCK = 312
IDC_SHOWCAL   = 313
IDC_SHOWVOL   = 314
IDC_SHOWSHUT  = 315
IDC_QUIT      = 316
IDC_ONTOP     = 317
IDC_DARKMODE  = 318
IDC_MOVEINT   = 319
IDC_ANNOUNCEOFF = 320
IDC_ANNOUNCE30  = 321
IDC_ANNOUNCE60  = 322
IDC_TESTVOICE   = 323
IDC_TESTMOVE    = 324
TIMER_CLOCK   = 1
HTCAPTION     = 2
LOCALE_USER_DEFAULT = 0400h
CLSCTX_INPROC_SERVER = 1
SPF_ASYNC = 1
SPF_PURGEBEFORESPEAK = 2

CLOCK_W       = 250
CLOCK_H       = 250
CAL_W         = 250
CAL_H         = 420
VOL_W         = 250
VOL_H         = 92
SHUT_W        = 250
SHUT_H        = 108
PADDING       = 12
GAP           = 8

section '.text' code readable executable

start:
        invoke  GetModuleHandle, 0
        mov     [instance], eax
        mov     [wc.hInstance], eax
        invoke  LoadIcon, [instance], 1
        mov     [wc.hIcon], eax
        invoke  LoadCursor, 0, IDC_ARROW
        mov     [wc.hCursor], eax
        invoke  RegisterClass, wc
        test    eax, eax
        jz      startup_error

        call    BuildIniPath
        call    LoadSettings
        call    InitSpeech
        call    UpdateThemeColors
        call    UpdateTopmostMode
        call    RecreateFonts
        invoke  waveOutGetVolume, 0, volume_raw
        movzx   eax, word [volume_raw]
        imul    eax, 100
        xor     edx, edx
        mov     ecx, 65535
        div     ecx
        mov     [volume_level], eax
        call    PositionWindows
        test    eax, eax
        jz      startup_error
        call    ResetMoveReminder
        call    ResetTimeAnnouncement

        invoke  SetTimer, [clock_hwnd], TIMER_CLOCK, 1000, 0

message_loop:
        invoke  GetMessage, msg, 0, 0, 0
        cmp     eax, 1
        jb      exit_app
        jne     message_loop
        invoke  TranslateMessage, msg
        invoke  DispatchMessage, msg
        jmp     message_loop

startup_error:
        invoke  MessageBox, 0, error_text, app_name, MB_OK+MB_ICONERROR
exit_app:
        cmp     [font_normal], 0
        je      .no_font1
        invoke  DeleteObject, [font_normal]
  .no_font1:
        cmp     [font_heading], 0
        je      .no_font2
        invoke  DeleteObject, [font_heading]
  .no_font2:
        cmp     [font_day], 0
        je      .no_font3
        invoke  DeleteObject, [font_day]
  .no_font3:
        cmp     [font_volume], 0
        je      .no_font4
        invoke  DeleteObject, [font_volume]
  .no_font4:
        cmp     [font_move], 0
        je      .no_font5
        invoke  DeleteObject, [font_move]
  .no_font5:
        cmp     [font_countdown], 0
        je      .no_font6
        invoke  DeleteObject, [font_countdown]
  .no_font6:
        call    ShutdownSpeech
        invoke  ExitProcess, [msg.wParam]

proc WindowProc uses ebx esi edi, hwnd, wmsg, wparam, lparam
        cmp     [wmsg], WM_PAINT
        je      .paint
        cmp     [wmsg], WM_TIMER
        je      .timer
        cmp     [wmsg], WM_COMMAND
        je      .command
        cmp     [wmsg], WM_RBUTTONUP
        je      .settings
        cmp     [wmsg], WM_MOUSEMOVE
        je      .mousemove
        cmp     [wmsg], WM_MOUSELEAVE
        je      .mouseleave
        cmp     [wmsg], WM_LBUTTONDOWN
        je      .leftclick
        cmp     [wmsg], WM_LBUTTONUP
        je      .leftup
        cmp     [wmsg], WM_MOUSEWHEEL
        je      .mousewheel
        cmp     [wmsg], WM_EXITSIZEMOVE
        je      .moved
        cmp     [wmsg], WM_CLOSE
        je      .close
        cmp     [wmsg], WM_DESTROY
        je      .destroy
        invoke  DefWindowProc, [hwnd], [wmsg], [wparam], [lparam]
        ret

  .paint:
        mov     eax, [hwnd]
        cmp     eax, [clock_hwnd]
        je      .paint_clock
        cmp     eax, [calendar_hwnd]
        je      .paint_calendar
        cmp     eax, [shutdown_hwnd]
        je      .paint_shutdown
        cmp     eax, [volume_hwnd]
        je      .paint_volume
        xor     eax, eax
        ret
  .paint_clock:
        call    PaintClock
        xor     eax, eax
        ret
  .paint_calendar:
        call    PaintCalendar
        xor     eax, eax
        ret
  .paint_shutdown:
        call    PaintShutdown
        xor     eax, eax
        ret
  .paint_volume:
        call    PaintVolume
        xor     eax, eax
        ret

  .timer:
        cmp     [wparam], TIMER_CLOCK
        jne     .handled
        call    UpdateMoveReminder
        call    UpdateTimeAnnouncement
        call    PollHover
        invoke  InvalidateRect, [clock_hwnd], 0, FALSE
        invoke  InvalidateRect, [calendar_hwnd], 0, FALSE
        invoke  InvalidateRect, [volume_hwnd], 0, FALSE
        invoke  InvalidateRect, [shutdown_hwnd], 0, FALSE
        jmp     .handled

  .command:
        mov     eax, [wparam]
        and     eax, 0FFFFh
        cmp     eax, IDC_NOW
        je      .shutdown_now
        cmp     eax, IDC_3MIN
        je      .shutdown_3min
        jmp     .handled
  .shutdown_now:
        invoke  MessageBox, [hwnd], confirm_shutdown, shutdown_title, MB_YESNO+MB_ICONWARNING+MB_DEFBUTTON2
        cmp     eax, IDYES
        jne     .handled
        invoke  ShellExecute, [hwnd], 0, shutdown_exe, args_now, 0, SW_HIDE
        jmp     .handled
  .shutdown_3min:
        lea     eax, [translated]
        invoke  GetDlgItemInt, [shutdown_hwnd], IDC_DELAYEDIT, eax, FALSE
        cmp     [translated], FALSE
        je      .bad_delay
        test    eax, eax
        jz      .bad_delay
        mov     [shutdown_delay], eax
        invoke  GetTickCount
        mov     [shutdown_start_tick], eax
        mov     [shutdown_active], 1
        invoke  ShowWindow, [delay_edit], SW_HIDE
        call    BuildShutdownCommand
        invoke  ShellExecute, [hwnd], 0, shutdown_exe, command_args, 0, SW_HIDE
        cinvoke wsprintf, message_buffer, scheduled_format, [shutdown_delay]
        invoke  MessageBox, [hwnd], message_buffer, shutdown_title, MB_OK+MB_ICONINFORMATION
        jmp     .handled
  .bad_delay:
        invoke  MessageBox, [hwnd], delay_error, shutdown_title, MB_OK+MB_ICONWARNING
        jmp     .handled

  .mousemove:
        mov     eax, [hwnd]
        mov     [track_hwnd], eax
        invoke  TrackMouseEvent, track_mouse
        call    SetHoverForWindow
        invoke  InvalidateRect, [hwnd], 0, TRUE
        jmp     .handled
  .mouseleave:
        mov     eax, [hwnd]
        call    ClearHoverForWindow
        invoke  InvalidateRect, [hwnd], 0, TRUE
        jmp     .handled
  .leftclick:
        mov     eax, [lparam]
        and     eax, 0FFFFh
        imul    eax, 100
        xor     edx, edx
        div     [scale_percent]
        mov     [click_x], eax
        mov     eax, [lparam]
        shr     eax, 16
        imul    eax, 100
        xor     edx, edx
        div     [scale_percent]
        mov     [click_y], eax
        mov     eax, [click_x]
        cmp     eax, 226
        jb      .not_close
        mov     eax, [click_y]
        cmp     eax, 24
        ja      .not_close
        call    SaveSettings
        invoke  PostQuitMessage, 0
        jmp     .handled
  .not_close:
        mov     eax, [hwnd]
        cmp     eax, [volume_hwnd]
        jne     .drag_window
        mov     eax, [click_y]
        cmp     eax, 30
        jb      .drag_window
        mov     eax, [click_x]
        cmp     eax, 246
        jae     .drag_window
        sub     eax, 14
        jns     .vol_nonneg
        xor     eax, eax
  .vol_nonneg:
        cmp     eax, 222
        jbe     .vol_range
        mov     eax, 222
  .vol_range:
        imul    eax, 100
        xor     edx, edx
        mov     ecx, 222
        div     ecx
        mov     [volume_level], eax
        imul    eax, 65535
        xor     edx, edx
        mov     ecx, 100
        div     ecx
        mov     edx, eax
        shl     eax, 16
        or      eax, edx
        invoke  waveOutSetVolume, 0, eax
        invoke  InvalidateRect, [volume_hwnd], 0, TRUE
        jmp     .handled
  .drag_window:
        invoke  ReleaseCapture
        invoke  SendMessage, [hwnd], WM_NCLBUTTONDOWN, HTCAPTION, 0
        jmp     .handled
  .leftup:
        mov     eax, [lparam]
        and     eax, 0FFFFh
        cmp     eax, 226
        jb      .handled
        mov     eax, [lparam]
        shr     eax, 16
        cmp     eax, 24
        ja      .handled
        invoke  PostQuitMessage, 0
        jmp     .handled
  .mousewheel:
        mov     eax, [hwnd]
        cmp     eax, [volume_hwnd]
        jne     .handled
        mov     eax, [wparam]
        sar     eax, 16
        test    eax, eax
        js      .wheel_down
        add     [volume_level], 2
        cmp     [volume_level], 100
        jbe     .set_wheel
        mov     [volume_level], 100
        jmp     .set_wheel
  .wheel_down:
        sub     [volume_level], 2
        jns     .set_wheel
        mov     [volume_level], 0
  .set_wheel:
        call    ApplyVolume
        invoke  InvalidateRect, [volume_hwnd], 0, TRUE
        jmp     .handled
  .moved:
        call    SaveSettings
        jmp     .handled

  .settings:
        invoke  DialogBoxParam, [instance], IDD_SETTINGS, [hwnd], SettingsProc, 0
        jmp     .handled
  .close:
        call    SaveSettings
        invoke  PostQuitMessage, 0
        jmp     .handled
  .destroy:
        invoke  PostQuitMessage, 0
  .handled:
        xor     eax, eax
        ret
endp

proc SettingsProc uses ebx esi edi, hwnddlg, wmsg, wparam, lparam
        cmp     [wmsg], WM_INITDIALOG
        je      .init
        cmp     [wmsg], WM_COMMAND
        je      .command
        cmp     [wmsg], WM_CLOSE
        je      .cancel
        xor     eax, eax
        ret
  .init:
        invoke  SetDlgItemInt, [hwnddlg], IDC_CLOCKSIZE, [clock_font_size], FALSE
        invoke  SetDlgItemInt, [hwnddlg], IDC_CALSIZE, [calendar_font_size], FALSE
        invoke  SetDlgItemInt, [hwnddlg], IDC_MONTHSIZE, [month_font_size], FALSE
        invoke  SetDlgItemInt, [hwnddlg], IDC_DAYSIZE, [day_font_size], FALSE
        invoke  CheckDlgButton, [hwnddlg], IDC_CLOCKBOLD, [clock_bold]
        invoke  CheckDlgButton, [hwnddlg], IDC_CALBOLD, [calendar_bold]
        invoke  CheckDlgButton, [hwnddlg], IDC_MONTHBOLD, [month_bold]
        invoke  CheckDlgButton, [hwnddlg], IDC_DAYBOLD, [day_bold]
        invoke  SetDlgItemInt, [hwnddlg], IDC_SCALE, [scale_percent], FALSE
        invoke  SetDlgItemInt, [hwnddlg], IDC_OPACITY, [opacity_percent], FALSE
        invoke  CheckDlgButton, [hwnddlg], IDC_SHOWCLOCK, [show_clock]
        invoke  CheckDlgButton, [hwnddlg], IDC_SHOWCAL, [show_calendar]
        invoke  CheckDlgButton, [hwnddlg], IDC_SHOWVOL, [show_volume]
        invoke  CheckDlgButton, [hwnddlg], IDC_SHOWSHUT, [show_shutdown]
        invoke  CheckDlgButton, [hwnddlg], IDC_ONTOP, [keep_on_top]
        invoke  CheckDlgButton, [hwnddlg], IDC_DARKMODE, [dark_mode]
        invoke  SetDlgItemInt, [hwnddlg], IDC_MOVEINT, [move_interval_minutes], FALSE
        mov     eax, IDC_ANNOUNCEOFF
        cmp     [time_announcement_minutes], 30
        jne     .check_announce60
        mov     eax, IDC_ANNOUNCE30
        jmp     .set_announcement
  .check_announce60:
        cmp     [time_announcement_minutes], 60
        jne     .set_announcement
        mov     eax, IDC_ANNOUNCE60
  .set_announcement:
        invoke  CheckRadioButton, [hwnddlg], IDC_ANNOUNCEOFF, IDC_ANNOUNCE60, eax
        mov     eax, TRUE
        ret
  .command:
        mov     eax, [wparam]
        and     eax, 0FFFFh
        cmp     eax, IDC_APPLY
        je      .apply
        cmp     eax, IDCANCEL
        je      .cancel
        cmp     eax, IDC_QUIT
        je      .quit
        cmp     eax, IDC_TESTVOICE
        je      .test_voice
        cmp     eax, IDC_TESTMOVE
        je      .test_move
        xor     eax, eax
        ret
  .test_voice:
        call    SpeakCurrentTime
        test    eax, eax
        jnz     .test_done
        invoke  MessageBox, [hwnddlg], speech_unavailable_text, settings_title, MB_OK+MB_ICONWARNING
  .test_done:
        mov     eax, TRUE
        ret
  .test_move:
        call    SpeakMovePrompt
        test    eax, eax
        jnz     .test_move_done
        invoke  MessageBox, [hwnddlg], speech_unavailable_text, settings_title, MB_OK+MB_ICONWARNING
  .test_move_done:
        mov     eax, TRUE
        ret
  .apply:
        lea     eax, [translated]
        invoke  GetDlgItemInt, [hwnddlg], IDC_CLOCKSIZE, eax, FALSE
        cmp     [translated], FALSE
        je      .invalid
        cmp     eax, 10
        jb      .invalid
        cmp     eax, 36
        ja      .invalid
        mov     [clock_font_size], eax
        lea     eax, [translated]
        invoke  GetDlgItemInt, [hwnddlg], IDC_CALSIZE, eax, FALSE
        cmp     [translated], FALSE
        je      .invalid
        cmp     eax, 10
        jb      .invalid
        cmp     eax, 36
        ja      .invalid
        mov     [calendar_font_size], eax
        lea     eax, [translated]
        invoke  GetDlgItemInt, [hwnddlg], IDC_MONTHSIZE, eax, FALSE
        cmp     [translated], FALSE
        je      .invalid
        cmp     eax, 10
        jb      .invalid
        cmp     eax, 36
        ja      .invalid
        mov     [month_font_size], eax
        lea     eax, [translated]
        invoke  GetDlgItemInt, [hwnddlg], IDC_DAYSIZE, eax, FALSE
        cmp     [translated], FALSE
        je      .invalid
        cmp     eax, 10
        jb      .invalid
        cmp     eax, 120
        ja      .invalid
        mov     [day_font_size], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_CLOCKBOLD
        mov     [clock_bold], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_CALBOLD
        mov     [calendar_bold], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_MONTHBOLD
        mov     [month_bold], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_DAYBOLD
        mov     [day_bold], eax
        lea     eax, [translated]
        invoke  GetDlgItemInt, [hwnddlg], IDC_SCALE, eax, FALSE
        cmp     [translated], FALSE
        je      .invalid
        cmp     eax, 50
        jb      .invalid
        cmp     eax, 200
        ja      .invalid
        mov     [scale_percent], eax
        lea     eax, [translated]
        invoke  GetDlgItemInt, [hwnddlg], IDC_OPACITY, eax, FALSE
        cmp     [translated], FALSE
        je      .invalid
        cmp     eax, 20
        jb      .invalid
        cmp     eax, 100
        ja      .invalid
        mov     [opacity_percent], eax
        lea     eax, [translated]
        invoke  GetDlgItemInt, [hwnddlg], IDC_MOVEINT, eax, FALSE
        cmp     [translated], FALSE
        je      .invalid
        cmp     eax, 99
        ja      .invalid
        mov     [move_interval_minutes], eax
        mov     [time_announcement_minutes], 0
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_ANNOUNCE30
        cmp     eax, BST_CHECKED
        jne     .apply_announce60
        mov     [time_announcement_minutes], 30
        jmp     .announcement_applied
  .apply_announce60:
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_ANNOUNCE60
        cmp     eax, BST_CHECKED
        jne     .announcement_applied
        mov     [time_announcement_minutes], 60
  .announcement_applied:
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_SHOWCLOCK
        mov     [show_clock], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_SHOWCAL
        mov     [show_calendar], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_SHOWVOL
        mov     [show_volume], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_SHOWSHUT
        mov     [show_shutdown], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_ONTOP
        mov     [keep_on_top], eax
        invoke  IsDlgButtonChecked, [hwnddlg], IDC_DARKMODE
        mov     [dark_mode], eax
        call    UpdateThemeColors
        call    UpdateTopmostMode
        call    RecreateFonts
        call    ApplyFonts
        call    ResizeAllWindows
        call    ApplyOpacity
        call    ApplyVisibility
        call    ResetMoveReminder
        call    ResetTimeAnnouncement
        call    SaveSettings
        invoke  InvalidateRect, [clock_hwnd], 0, TRUE
        invoke  InvalidateRect, [calendar_hwnd], 0, TRUE
        invoke  InvalidateRect, [volume_hwnd], 0, TRUE
        invoke  InvalidateRect, [shutdown_hwnd], 0, TRUE
        invoke  EndDialog, [hwnddlg], 1
        mov     eax, [show_clock]
        add     eax, [show_calendar]
        add     eax, [show_volume]
        add     eax, [show_shutdown]
        test    eax, eax
        jnz     .applied
        invoke  PostMessage, [clock_hwnd], WM_CLOSE, 0, 0
  .applied:
        mov     eax, TRUE
        ret
  .invalid:
        invoke  MessageBox, [hwnddlg], settings_error_v9, settings_title, MB_OK+MB_ICONWARNING
        mov     eax, TRUE
        ret
  .cancel:
        invoke  EndDialog, [hwnddlg], 0
        mov     eax, TRUE
        ret
  .quit:
        call    SaveSettings
        invoke  EndDialog, [hwnddlg], 0
        invoke  PostMessage, [clock_hwnd], WM_CLOSE, 0, 0
        mov     eax, TRUE
        ret
endp

proc BuildIniPath uses esi edi
        invoke  GetModuleFileName, 0, ini_path, 260
        mov     edi, ini_path
  .find_end:
        cmp     byte [edi], 0
        je      .back
        inc     edi
        jmp     .find_end
  .back:
        cmp     edi, ini_path
        jbe     .copy
        dec     edi
        cmp     byte [edi], '\'
        jne     .back
        inc     edi
  .copy:
        mov     esi, ini_name
  .copy_name:
        lodsb
        stosb
        test    al, al
        jnz     .copy_name
        ret
endp

proc LoadSettings
        invoke  GetPrivateProfileInt, section_clock, key_size, 22, ini_path
        mov     [clock_font_size], eax
        invoke  GetPrivateProfileInt, section_clock, key_bold, 1, ini_path
        mov     [clock_bold], eax
        invoke  GetPrivateProfileInt, section_calendar, key_size, 12, ini_path
        mov     [calendar_font_size], eax
        invoke  GetPrivateProfileInt, section_calendar, key_bold, 0, ini_path
        mov     [calendar_bold], eax
        invoke  GetPrivateProfileInt, section_month, key_size, 18, ini_path
        mov     [month_font_size], eax
        invoke  GetPrivateProfileInt, section_month, key_bold, 1, ini_path
        mov     [month_bold], eax
        invoke  GetPrivateProfileInt, section_today, key_size, 99, ini_path
        mov     [day_font_size], eax
        invoke  GetPrivateProfileInt, section_today, key_bold, 1, ini_path
        mov     [day_bold], eax
        invoke  GetPrivateProfileInt, section_global, key_scale, 90, ini_path
        mov     [scale_percent], eax
        invoke  GetPrivateProfileInt, section_global, key_opacity, 85, ini_path
        mov     [opacity_percent], eax
        invoke  GetPrivateProfileInt, section_global, key_keepontop, 1, ini_path
        mov     [keep_on_top], eax
        invoke  GetPrivateProfileInt, section_global, key_darkmode, 0, ini_path
        mov     [dark_mode], eax
        invoke  GetPrivateProfileInt, section_global, key_moveinterval, 0, ini_path
        cmp     eax, 99
        jbe     .move_ok
        xor     eax, eax
  .move_ok:
        mov     [move_interval_minutes], eax
        invoke  GetPrivateProfileInt, section_global, key_timeannouncement, 0, ini_path
        test    eax, eax
        jz      .announcement_ok
        cmp     eax, 30
        je      .announcement_ok
        cmp     eax, 60
        je      .announcement_ok
        xor     eax, eax
  .announcement_ok:
        mov     [time_announcement_minutes], eax
        invoke  GetPrivateProfileInt, section_visibility, key_showclock, 1, ini_path
        mov     [show_clock], eax
        invoke  GetPrivateProfileInt, section_visibility, key_showcal, 1, ini_path
        mov     [show_calendar], eax
        invoke  GetPrivateProfileInt, section_visibility, key_showvol, 1, ini_path
        mov     [show_volume], eax
        invoke  GetPrivateProfileInt, section_visibility, key_showshut, 1, ini_path
        mov     [show_shutdown], eax
        mov     eax, [show_clock]
        add     eax, [show_calendar]
        add     eax, [show_volume]
        add     eax, [show_shutdown]
        test    eax, eax
        jnz     .visibility_ok
        mov     [show_clock], 1
        mov     [show_calendar], 1
        mov     [show_volume], 1
        mov     [show_shutdown], 1
  .visibility_ok:
        invoke  GetPrivateProfileInt, section_layout, key_clockx, -1, ini_path
        mov     [clock_x], eax
        invoke  GetPrivateProfileInt, section_layout, key_clocky, -1, ini_path
        mov     [clock_y], eax
        invoke  GetPrivateProfileInt, section_layout, key_calx, -1, ini_path
        mov     [cal_x], eax
        invoke  GetPrivateProfileInt, section_layout, key_caly, -1, ini_path
        mov     [cal_y], eax
        invoke  GetPrivateProfileInt, section_layout, key_volx, -1, ini_path
        mov     [vol_x], eax
        invoke  GetPrivateProfileInt, section_layout, key_voly, -1, ini_path
        mov     [vol_y], eax
        invoke  GetPrivateProfileInt, section_layout, key_shutx, -1, ini_path
        mov     [shut_x], eax
        invoke  GetPrivateProfileInt, section_layout, key_shuty, -1, ini_path
        mov     [shut_y], eax
        ret
endp

proc WriteIniInt section, key, value
        cinvoke wsprintf, ini_value, number_format, [value]
        invoke  WritePrivateProfileString, [section], [key], ini_value, ini_path
        ret
endp

proc SaveSettings uses ebx esi edi
        stdcall WriteIniInt, section_clock, key_size, [clock_font_size]
        stdcall WriteIniInt, section_clock, key_bold, [clock_bold]
        stdcall WriteIniInt, section_calendar, key_size, [calendar_font_size]
        stdcall WriteIniInt, section_calendar, key_bold, [calendar_bold]
        stdcall WriteIniInt, section_month, key_size, [month_font_size]
        stdcall WriteIniInt, section_month, key_bold, [month_bold]
        stdcall WriteIniInt, section_today, key_size, [day_font_size]
        stdcall WriteIniInt, section_today, key_bold, [day_bold]
        stdcall WriteIniInt, section_global, key_scale, [scale_percent]
        stdcall WriteIniInt, section_global, key_opacity, [opacity_percent]
        stdcall WriteIniInt, section_global, key_keepontop, [keep_on_top]
        stdcall WriteIniInt, section_global, key_darkmode, [dark_mode]
        stdcall WriteIniInt, section_global, key_moveinterval, [move_interval_minutes]
        stdcall WriteIniInt, section_global, key_timeannouncement, [time_announcement_minutes]
        stdcall WriteIniInt, section_visibility, key_showclock, [show_clock]
        stdcall WriteIniInt, section_visibility, key_showcal, [show_calendar]
        stdcall WriteIniInt, section_visibility, key_showvol, [show_volume]
        stdcall WriteIniInt, section_visibility, key_showshut, [show_shutdown]
        invoke  WritePrivateProfileString, section_notes, key_fontnote, font_note, ini_path
        invoke  WritePrivateProfileString, section_notes, key_scalenote, scale_note, ini_path
        cmp     [clock_hwnd], 0
        je      .done
        invoke  GetWindowRect, [clock_hwnd], save_rect
        stdcall WriteIniInt, section_layout, key_clockx, [save_rect.left]
        stdcall WriteIniInt, section_layout, key_clocky, [save_rect.top]
        invoke  GetWindowRect, [calendar_hwnd], save_rect
        stdcall WriteIniInt, section_layout, key_calx, [save_rect.left]
        stdcall WriteIniInt, section_layout, key_caly, [save_rect.top]
        invoke  GetWindowRect, [volume_hwnd], save_rect
        stdcall WriteIniInt, section_layout, key_volx, [save_rect.left]
        stdcall WriteIniInt, section_layout, key_voly, [save_rect.top]
        invoke  GetWindowRect, [shutdown_hwnd], save_rect
        stdcall WriteIniInt, section_layout, key_shutx, [save_rect.left]
        stdcall WriteIniInt, section_layout, key_shuty, [save_rect.top]
  .done:
        ret
endp

proc ResetMoveReminder
        mov     [move_active], 0
        mov     [move_display_seconds], 0
        mov     [move_beep_count], 0
        mov     [move_speech_pending], 0
        mov     eax, [move_interval_minutes]
        imul    eax, 60
        mov     [move_countdown_seconds], eax
        cmp     [now_button], 0
        je      .done
        invoke  ShowWindow, [now_button], SW_SHOWNA
        invoke  ShowWindow, [min3_button], SW_SHOWNA
        mov     eax, SW_HIDE
        cmp     [shutdown_active], 0
        jne     .show_delay
        mov     eax, SW_SHOWNA
  .show_delay:
        invoke  ShowWindow, [delay_edit], eax
        invoke  InvalidateRect, [shutdown_hwnd], 0, TRUE
  .done:
        ret
endp

proc StartMoveReminder
        invoke  GetWindowLong, [shutdown_hwnd], GWL_STYLE
        and     eax, WS_VISIBLE
        mov     [move_panel_was_visible], eax
        invoke  GetWindowLong, [now_button], GWL_STYLE
        and     eax, WS_VISIBLE
        mov     [move_now_was_visible], eax
        invoke  GetWindowLong, [min3_button], GWL_STYLE
        and     eax, WS_VISIBLE
        mov     [move_delay_was_visible], eax
        invoke  GetWindowLong, [delay_edit], GWL_STYLE
        and     eax, WS_VISIBLE
        mov     [move_edit_was_visible], eax
        invoke  ShowWindow, [now_button], SW_HIDE
        invoke  ShowWindow, [min3_button], SW_HIDE
        invoke  ShowWindow, [delay_edit], SW_HIDE
        invoke  ShowWindow, [shutdown_hwnd], SW_SHOWNA
        mov     [move_active], 1
        mov     [move_display_seconds], 0
        mov     [move_beep_count], 1
        mov     [move_speech_pending], 1
        invoke  MessageBeep, MB_OK
        invoke  InvalidateRect, [shutdown_hwnd], 0, TRUE
        ret
endp

proc FinishMoveReminder
        mov     [move_active], 0
        mov     [move_speech_pending], 0
        mov     eax, SW_HIDE
        cmp     [move_now_was_visible], 0
        je      .now
        mov     eax, SW_SHOWNA
  .now:
        invoke  ShowWindow, [now_button], eax
        mov     eax, SW_HIDE
        cmp     [move_delay_was_visible], 0
        je      .delay
        mov     eax, SW_SHOWNA
  .delay:
        invoke  ShowWindow, [min3_button], eax
        mov     eax, SW_HIDE
        cmp     [move_edit_was_visible], 0
        je      .edit
        mov     eax, SW_SHOWNA
  .edit:
        invoke  ShowWindow, [delay_edit], eax
        mov     eax, SW_HIDE
        cmp     [move_panel_was_visible], 0
        je      .panel
        mov     eax, SW_SHOWNA
  .panel:
        invoke  ShowWindow, [shutdown_hwnd], eax
        mov     eax, [move_interval_minutes]
        imul    eax, 60
        mov     [move_countdown_seconds], eax
        invoke  InvalidateRect, [shutdown_hwnd], 0, TRUE
        ret
endp

proc UpdateMoveReminder
        cmp     [move_interval_minutes], 0
        je      .done
        cmp     [move_active], 0
        je      .countdown
        inc     [move_display_seconds]
        cmp     [move_beep_count], 3
        jae     .check_speech
        inc     [move_beep_count]
        invoke  MessageBeep, MB_OK
  .check_speech:
        cmp     [move_speech_pending], 0
        je      .check_finish
        cmp     [move_display_seconds], 3
        jb      .check_finish
        mov     [move_speech_pending], 0
        call    SpeakMovePrompt
  .check_finish:
        cmp     [move_display_seconds], 30
        jb      .done
        call    FinishMoveReminder
        ret
  .countdown:
        cmp     [move_countdown_seconds], 0
        je      .start
        dec     [move_countdown_seconds]
        jnz     .done
  .start:
        call    StartMoveReminder
  .done:
        ret
endp

proc InitSpeech
        mov     [sapi_com_initialized], 0
        mov     [sapi_voice], 0
        invoke  CoInitialize, NULL
        test    eax, eax
        js      .done
        mov     [sapi_com_initialized], 1
        invoke  CoCreateInstance, CLSID_SpVoice, NULL, CLSCTX_INPROC_SERVER, IID_ISpVoice, sapi_voice
        test    eax, eax
        jns     .done
        mov     [sapi_voice], 0
  .done:
        ret
endp

proc ShutdownSpeech
        cmp     [sapi_voice], 0
        je      .check_com
        cominvk sapi_voice, Release
        mov     [sapi_voice], 0
  .check_com:
        cmp     [sapi_com_initialized], 0
        je      .done
        invoke  CoUninitialize
        mov     [sapi_com_initialized], 0
  .done:
        ret
endp

proc ResetTimeAnnouncement
        lea     eax, [speech_time]
        invoke  GetLocalTime, eax
        movzx   eax, [speech_time.wHour]
        imul    eax, 60
        movzx   ecx, [speech_time.wMinute]
        add     eax, ecx
        mov     [last_announcement_minute], eax
        ret
endp

proc UpdateTimeAnnouncement
        mov     eax, [time_announcement_minutes]
        test    eax, eax
        jz      .done
        cmp     eax, 30
        je      .get_time
        cmp     eax, 60
        jne     .done
  .get_time:
        lea     eax, [speech_time]
        invoke  GetLocalTime, eax
        movzx   ecx, [speech_time.wMinute]
        cmp     [time_announcement_minutes], 60
        je      .hourly
        cmp     ecx, 0
        je      .boundary
        cmp     ecx, 30
        jne     .done
        jmp     .boundary
  .hourly:
        test    ecx, ecx
        jnz     .done
  .boundary:
        movzx   eax, [speech_time.wHour]
        imul    eax, 60
        add     eax, ecx
        cmp     eax, [last_announcement_minute]
        je      .done
        mov     [last_announcement_minute], eax
        cmp     [move_active], 0
        jne     .done
        call    SpeakCurrentTime
  .done:
        ret
endp

proc SpeakCurrentTime uses esi
        cmp     [sapi_voice], 0
        je      .failed
        lea     eax, [speech_time]
        invoke  GetLocalTime, eax
        movzx   eax, [speech_time.wHour]
        mov     esi, am_text
        cmp     eax, 12
        jb      .hour_ready
        mov     esi, pm_text
        je      .hour_ready
        sub     eax, 12
        jmp     .hour_ready
  .hour_ready:
        test    eax, eax
        jnz     .format
        mov     eax, 12
  .format:
        movzx   ecx, [speech_time.wMinute]
        cinvoke wsprintf, speech_buffer, speech_time_format, eax, ecx, esi
        invoke  MultiByteToWideChar, 0, 0, speech_buffer, -1, speech_wide_buffer, 96
        test    eax, eax
        jz      .failed
        cominvk sapi_voice, Speak, speech_wide_buffer, SPF_ASYNC+SPF_PURGEBEFORESPEAK, NULL
        test    eax, eax
        js      .failed
        mov     eax, TRUE
        ret
  .failed:
        xor     eax, eax
        ret
endp

proc SpeakMovePrompt
        cmp     [sapi_voice], 0
        je      .failed
        invoke  GetTickCount
        mov     ecx, eax
        shr     ecx, 8
        xor     eax, ecx
        mov     ecx, eax
        shr     ecx, 16
        xor     eax, ecx
        and     eax, 3
        mov     eax, move_prompt_normal
        jnz     .speak
        mov     eax, move_prompt_biological
  .speak:
        cominvk sapi_voice, Speak, eax, SPF_ASYNC+SPF_PURGEBEFORESPEAK, NULL
        test    eax, eax
        js      .failed
        mov     eax, TRUE
        ret
  .failed:
        xor     eax, eax
        ret
endp

proc UpdateThemeColors
        cmp     [dark_mode], 0
        jne     .dark
        mov     [theme_clock_bg], 00F8F7F1h
        mov     [theme_calendar_bg], 00F8F7F1h
        mov     [theme_shutdown_bg], 00D7D4CBh
        mov     [theme_volume_bg], 00312D2Ah
        mov     [theme_text_primary], 00202020h
        mov     [theme_text_secondary], 00504D48h
        mov     [theme_text_muted], 00404040h
        mov     [theme_track], 00C8C5BEh
        mov     [theme_progress], 00202020h
        mov     [theme_today_fill], 00A85C42h
        mov     [theme_day_card], 00A44A18h
        mov     [theme_accent_text], 00FFFFFFh
        mov     [theme_volume_text], 00FFFFFFh
        mov     [theme_bar_on], 00F4F4F4h
        mov     [theme_bar_off], 00605B57h
        mov     [theme_hover], 0090E090h
        mov     [theme_close], 003030D0h
        mov     [theme_clock_outline], 00252525h
        mov     [theme_clock_hand], 00202020h
        mov     [theme_shutdown_track], 00A44A18h
        mov     [theme_shutdown_fill], 00312D2Ah
        ret
  .dark:
        ; Telemetry-inspired near-black brown with warm text and muted tracks.
        mov     [theme_clock_bg], 00211D1Bh
        mov     [theme_calendar_bg], 00211D1Bh
        mov     [theme_shutdown_bg], 00211D1Bh
        mov     [theme_volume_bg], 00211D1Bh
        mov     [theme_text_primary], 00F0EEEAh
        mov     [theme_text_secondary], 00D5D1CBh
        mov     [theme_text_muted], 009C9892h
        mov     [theme_track], 00403935h
        mov     [theme_progress], 00D8A060h
        mov     [theme_today_fill], 0067C26Ah
        mov     [theme_day_card], 00292522h
        mov     [theme_accent_text], 00F2F0ECh
        mov     [theme_volume_text], 00F2F0ECh
        mov     [theme_bar_on], 0067C26Ah
        mov     [theme_bar_off], 00403935h
        mov     [theme_hover], 00D8A060h
        mov     [theme_close], 007070E8h
        mov     [theme_clock_outline], 00403935h
        mov     [theme_clock_hand], 00F0EEEAh
        mov     [theme_shutdown_track], 00403935h
        mov     [theme_shutdown_fill], 0067C26Ah
        ret
endp

proc UpdateTopmostMode
        mov     eax, WS_EX_TOOLWINDOW+WS_EX_LAYERED
        mov     edx, HWND_NOTOPMOST
        cmp     [keep_on_top], 0
        je      .store
        or      eax, WS_EX_TOPMOST
        mov     edx, HWND_TOPMOST
  .store:
        mov     [window_ex_style], eax
        mov     [zorder_target], edx
        cmp     [clock_hwnd], 0
        je      .done
        invoke  SetWindowPos, [clock_hwnd], [zorder_target], 0, 0, 0, 0, SWP_NOMOVE+SWP_NOSIZE+SWP_NOACTIVATE
        invoke  SetWindowPos, [calendar_hwnd], [zorder_target], 0, 0, 0, 0, SWP_NOMOVE+SWP_NOSIZE+SWP_NOACTIVATE
        invoke  SetWindowPos, [volume_hwnd], [zorder_target], 0, 0, 0, 0, SWP_NOMOVE+SWP_NOSIZE+SWP_NOACTIVATE
        invoke  SetWindowPos, [shutdown_hwnd], [zorder_target], 0, 0, 0, 0, SWP_NOMOVE+SWP_NOSIZE+SWP_NOACTIVATE
  .done:
        ret
endp

proc RestorePositions
        cmp     [clock_x], -1
        je      .calendar
        invoke  SetWindowPos, [clock_hwnd], [zorder_target], [clock_x], [clock_y], 0, 0, SWP_NOSIZE+SWP_NOACTIVATE
  .calendar:
        cmp     [cal_x], -1
        je      .volume
        invoke  SetWindowPos, [calendar_hwnd], [zorder_target], [cal_x], [cal_y], 0, 0, SWP_NOSIZE+SWP_NOACTIVATE
  .volume:
        cmp     [vol_x], -1
        je      .shutdown
        invoke  SetWindowPos, [volume_hwnd], [zorder_target], [vol_x], [vol_y], 0, 0, SWP_NOSIZE+SWP_NOACTIVATE
  .shutdown:
        cmp     [shut_x], -1
        je      .done
        invoke  SetWindowPos, [shutdown_hwnd], [zorder_target], [shut_x], [shut_y], 0, 0, SWP_NOSIZE+SWP_NOACTIVATE
  .done:
        ret
endp

proc ApplyVolume
        mov     eax, [volume_level]
        imul    eax, 65535
        xor     edx, edx
        mov     ecx, 100
        div     ecx
        mov     edx, eax
        shl     eax, 16
        or      eax, edx
        invoke  waveOutSetVolume, 0, eax
        ret
endp

proc CalculateSizes
        invoke  MulDiv, 250, [scale_percent], 100
        mov     [scaled_width], eax
        invoke  MulDiv, CLOCK_H, [scale_percent], 100
        mov     [scaled_clock_h], eax
        invoke  MulDiv, CAL_H, [scale_percent], 100
        mov     [scaled_cal_h], eax
        invoke  MulDiv, VOL_H, [scale_percent], 100
        mov     [scaled_vol_h], eax
        invoke  MulDiv, SHUT_H, [scale_percent], 100
        mov     [scaled_shut_h], eax
        invoke  MulDiv, PADDING, [scale_percent], 100
        mov     [scaled_padding], eax
        invoke  MulDiv, GAP, [scale_percent], 100
        mov     [scaled_gap], eax
        invoke  MulDiv, 7, [scale_percent], 100
        mov     [ctrl_x1], eax
        mov     [ctrl_y1], eax
        invoke  MulDiv, 130, [scale_percent], 100
        mov     [ctrl_x2], eax
        invoke  MulDiv, 113, [scale_percent], 100
        mov     [ctrl_w], eax
        invoke  MulDiv, 32, [scale_percent], 100
        mov     [ctrl_h], eax
        invoke  MulDiv, 45, [scale_percent], 100
        mov     [edit_y], eax
        invoke  MulDiv, 236, [scale_percent], 100
        mov     [edit_w], eax
        invoke  MulDiv, 24, [scale_percent], 100
        mov     [edit_h], eax
        ret
endp

proc ResizeAllWindows
        call    CalculateSizes
        invoke  SetWindowPos, [clock_hwnd], [zorder_target], 0, 0, [scaled_width], [scaled_clock_h], SWP_NOMOVE+SWP_NOACTIVATE
        invoke  SetWindowPos, [calendar_hwnd], [zorder_target], 0, 0, [scaled_width], [scaled_cal_h], SWP_NOMOVE+SWP_NOACTIVATE
        invoke  SetWindowPos, [volume_hwnd], [zorder_target], 0, 0, [scaled_width], [scaled_vol_h], SWP_NOMOVE+SWP_NOACTIVATE
        invoke  SetWindowPos, [shutdown_hwnd], [zorder_target], 0, 0, [scaled_width], [scaled_shut_h], SWP_NOMOVE+SWP_NOACTIVATE
        invoke  MoveWindow, [now_button], [ctrl_x1], [ctrl_y1], [ctrl_w], [ctrl_h], TRUE
        invoke  MoveWindow, [min3_button], [ctrl_x2], [ctrl_y1], [ctrl_w], [ctrl_h], TRUE
        invoke  MoveWindow, [delay_edit], [ctrl_x1], [edit_y], [edit_w], [edit_h], TRUE
        call    AlignWindowsRight
        ret
endp

proc AlignWindowsRight uses ebx esi edi
        local work:RECT
        lea     eax, [work]
        invoke  SystemParametersInfo, SPI_GETWORKAREA, 0, eax, 0
        mov     ebx, [work.right]
        sub     ebx, [scaled_padding]
        sub     ebx, [scaled_width]
        mov     esi, [work.top]
        add     esi, [scaled_padding]
        invoke  SetWindowPos, [clock_hwnd], [zorder_target], ebx, esi, 0, 0, SWP_NOSIZE+SWP_NOACTIVATE
        add     esi, [scaled_clock_h]
        add     esi, [scaled_gap]
        invoke  SetWindowPos, [calendar_hwnd], [zorder_target], ebx, esi, 0, 0, SWP_NOSIZE+SWP_NOACTIVATE
        add     esi, [scaled_cal_h]
        add     esi, [scaled_gap]
        invoke  SetWindowPos, [volume_hwnd], [zorder_target], ebx, esi, 0, 0, SWP_NOSIZE+SWP_NOACTIVATE
        add     esi, [scaled_vol_h]
        add     esi, [scaled_gap]
        invoke  SetWindowPos, [shutdown_hwnd], [zorder_target], ebx, esi, 0, 0, SWP_NOSIZE+SWP_NOACTIVATE
        ret
endp

proc ApplyOpacity
        mov     eax, [opacity_percent]
        imul    eax, 255
        xor     edx, edx
        mov     ecx, 100
        div     ecx
        mov     [layer_alpha], eax
        invoke  SetLayeredWindowAttributes, [clock_hwnd], 00FF00FFh, [layer_alpha], LWA_COLORKEY+LWA_ALPHA
        invoke  SetLayeredWindowAttributes, [calendar_hwnd], 00FF00FFh, [layer_alpha], LWA_COLORKEY+LWA_ALPHA
        invoke  SetLayeredWindowAttributes, [volume_hwnd], 00FF00FFh, [layer_alpha], LWA_COLORKEY+LWA_ALPHA
        invoke  SetLayeredWindowAttributes, [shutdown_hwnd], 00FF00FFh, [layer_alpha], LWA_COLORKEY+LWA_ALPHA
        ret
endp

proc ApplyVisibility
        mov     eax, SW_HIDE
        cmp     [show_clock], 0
        je      .clock
        mov     eax, SW_SHOWNA
  .clock:
        invoke  ShowWindow, [clock_hwnd], eax
        mov     eax, SW_HIDE
        cmp     [show_calendar], 0
        je      .calendar
        mov     eax, SW_SHOWNA
  .calendar:
        invoke  ShowWindow, [calendar_hwnd], eax
        mov     eax, SW_HIDE
        cmp     [show_volume], 0
        je      .volume
        mov     eax, SW_SHOWNA
  .volume:
        invoke  ShowWindow, [volume_hwnd], eax
        mov     eax, SW_HIDE
        cmp     [show_shutdown], 0
        je      .shutdown
        mov     eax, SW_SHOWNA
  .shutdown:
        invoke  ShowWindow, [shutdown_hwnd], eax
        ret
endp

proc SetupScaledDC hdc, basew, baseh
        invoke  SetMapMode, [hdc], MM_ANISOTROPIC
        invoke  SetWindowExtEx, [hdc], [basew], [baseh], 0
        invoke  GetClientRect, [current_paint_hwnd], physical_rect
        mov     eax, [physical_rect.right]
        mov     edx, [physical_rect.bottom]
        invoke  SetViewportExtEx, [hdc], eax, edx, 0
        invoke  SetWindowOrgEx, [hdc], 0, 0, 0
        invoke  SetViewportOrgEx, [hdc], 0, 0, 0
        ret
endp

proc PositionWindows uses ebx esi edi
        local work:RECT
        call    CalculateSizes
        lea     eax, [work]
        invoke  SystemParametersInfo, SPI_GETWORKAREA, 0, eax, 0
        mov     eax, [work.right]
        sub     eax, [scaled_padding]
        sub     eax, [scaled_width]
        mov     ebx, eax
        mov     esi, [work.top]
        add     esi, [scaled_padding]

        invoke  CreateWindowEx, [window_ex_style], class_name, clock_title, WS_VISIBLE+WS_POPUP, ebx, esi, [scaled_width], [scaled_clock_h], 0, 0, [instance], 0
        test    eax, eax
        jz      .fail
        mov     [clock_hwnd], eax
        invoke  SetLayeredWindowAttributes, eax, 00FF00FFh, 255, LWA_COLORKEY

        mov     eax, [work.right]
        sub     eax, [scaled_padding]
        sub     eax, [scaled_width]
        mov     edi, esi
        add     edi, [scaled_clock_h]
        add     edi, [scaled_gap]
        invoke  CreateWindowEx, [window_ex_style], class_name, calendar_title, WS_VISIBLE+WS_POPUP, eax, edi, [scaled_width], [scaled_cal_h], 0, 0, [instance], 0
        test    eax, eax
        jz      .fail
        mov     [calendar_hwnd], eax
        invoke  SetLayeredWindowAttributes, eax, 00FF00FFh, 255, LWA_COLORKEY

        mov     eax, [work.right]
        sub     eax, [scaled_padding]
        sub     eax, [scaled_width]
        add     edi, [scaled_cal_h]
        add     edi, [scaled_gap]
        invoke  CreateWindowEx, [window_ex_style], class_name, volume_title, WS_VISIBLE+WS_POPUP, eax, edi, [scaled_width], [scaled_vol_h], 0, 0, [instance], 0
        test    eax, eax
        jz      .fail
        mov     [volume_hwnd], eax
        invoke  SetLayeredWindowAttributes, eax, 00FF00FFh, 255, LWA_COLORKEY

        mov     eax, [work.right]
        sub     eax, [scaled_padding]
        sub     eax, [scaled_width]
        add     edi, [scaled_vol_h]
        add     edi, [scaled_gap]
        invoke  CreateWindowEx, [window_ex_style], class_name, shutdown_title, WS_VISIBLE+WS_POPUP, eax, edi, [scaled_width], [scaled_shut_h], 0, 0, [instance], 0
        test    eax, eax
        jz      .fail
        mov     [shutdown_hwnd], eax
        invoke  SetLayeredWindowAttributes, eax, 00FF00FFh, 255, LWA_COLORKEY

        invoke  CreateWindowEx, 0, button_class, now_text, WS_VISIBLE+WS_CHILD+WS_TABSTOP+BS_PUSHBUTTON, [ctrl_x1], [ctrl_y1], [ctrl_w], [ctrl_h], [shutdown_hwnd], IDC_NOW, [instance], 0
        mov     [now_button], eax
        invoke  CreateWindowEx, 0, button_class, delay_text, WS_VISIBLE+WS_CHILD+WS_TABSTOP+BS_PUSHBUTTON, [ctrl_x2], [ctrl_y1], [ctrl_w], [ctrl_h], [shutdown_hwnd], IDC_3MIN, [instance], 0
        mov     [min3_button], eax
        invoke  CreateWindowEx, WS_EX_CLIENTEDGE, edit_class, default_delay, WS_VISIBLE+WS_CHILD+WS_TABSTOP+ES_NUMBER+ES_CENTER, [ctrl_x1], [edit_y], [edit_w], [edit_h], [shutdown_hwnd], IDC_DELAYEDIT, [instance], 0
        mov     [delay_edit], eax
        call    ApplyFonts
        call    RestorePositions
        call    ApplyOpacity
        call    ApplyVisibility
        mov     eax, 1
        ret
  .fail:
        xor     eax, eax
        ret
endp

proc RecreateFonts uses ebx esi edi
        cmp     [font_normal], 0
        je      .volume
        invoke  DeleteObject, [font_normal]
  .volume:
        cmp     [font_volume], 0
        je      .controls
        invoke  DeleteObject, [font_volume]
  .controls:
        cmp     [font_controls], 0
        je      .clock
        invoke  DeleteObject, [font_controls]
  .clock:
        cmp     [font_clock], 0
        je      .calendar
        invoke  DeleteObject, [font_clock]
  .calendar:
        cmp     [font_calendar], 0
        je      .heading
        invoke  DeleteObject, [font_calendar]
  .heading:
        cmp     [font_heading], 0
        je      .day
        invoke  DeleteObject, [font_heading]
  .day:
        cmp     [font_day], 0
        je      .move
if 0
        invoke …1109 tokens truncated…TIME
        lea     eax, [ps]
        invoke  BeginPaint, [clock_hwnd], eax
end if
        invoke  DeleteObject, [font_day]
  .move:
        cmp     [font_move], 0
        je      .countdown
        invoke  DeleteObject, [font_move]
  .countdown:
        cmp     [font_countdown], 0
        je      .create
        invoke  DeleteObject, [font_countdown]
  .create:
        invoke  MulDiv, 10, 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, DEFAULT_PITCH+FF_SWISS, font_face
        mov     [font_normal], eax
        invoke  MulDiv, 12, 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, DEFAULT_PITCH+FF_SWISS, font_face
        mov     [font_volume], eax
        invoke  MulDiv, 11, [scale_percent], 100
        invoke  MulDiv, eax, 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, DEFAULT_PITCH+FF_SWISS, font_face
        mov     [font_controls], eax
        mov     ebx, FW_NORMAL
        cmp     [clock_bold], 1
        jne     .clock_weight
        mov     ebx, FW_BOLD
  .clock_weight:
        invoke  MulDiv, [clock_font_size], 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, ebx, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, DEFAULT_PITCH+FF_SWISS, font_face
        mov     [font_clock], eax
        mov     ebx, FW_NORMAL
        cmp     [calendar_bold], 1
        jne     .cal_weight
        mov     ebx, FW_BOLD
  .cal_weight:
        invoke  MulDiv, [calendar_font_size], 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, ebx, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, DEFAULT_PITCH+FF_SWISS, font_face
        mov     [font_calendar], eax
        mov     ebx, FW_NORMAL
        cmp     [month_bold], 1
        jne     .month_weight
        mov     ebx, FW_BOLD
  .month_weight:
        invoke  MulDiv, [month_font_size], 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, ebx, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, DEFAULT_PITCH+FF_SWISS, font_face
        mov     [font_heading], eax
        mov     ebx, FW_NORMAL
        cmp     [day_bold], 1
        jne     .day_weight
        mov     ebx, FW_BOLD
  .day_weight:
        invoke  MulDiv, [day_font_size], 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, ebx, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, DEFAULT_PITCH+FF_SWISS, font_face
        mov     [font_day], eax
        invoke  MulDiv, 34, 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, DEFAULT_PITCH+FF_SWISS, font_face
        mov     [font_move], eax
        invoke  MulDiv, 10, 96, 72
        neg     eax
        invoke  CreateFont, eax, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, 5, FIXED_PITCH+FF_MODERN, font_mono
        mov     [font_countdown], eax
        ret
endp

proc ApplyFonts
        cmp     [now_button], 0
        je      .done
        invoke  SendMessage, [now_button], WM_SETFONT, [font_controls], TRUE
        invoke  SendMessage, [min3_button], WM_SETFONT, [font_controls], TRUE
        invoke  SendMessage, [delay_edit], WM_SETFONT, [font_controls], TRUE
  .done:
        ret
endp

proc SetHoverForWindow
        cmp     eax, [clock_hwnd]
        jne     .calendar
        mov     [hover_clock], 1
        ret
  .calendar:
        cmp     eax, [calendar_hwnd]
        jne     .volume
        mov     [hover_calendar], 1
        ret
  .volume:
        cmp     eax, [volume_hwnd]
        jne     .shutdown
        mov     [hover_volume], 1
        ret
  .shutdown:
        cmp     eax, [shutdown_hwnd]
        jne     .done
        mov     [hover_shutdown], 1
  .done:
        ret
endp

proc ClearHoverForWindow
        cmp     eax, [clock_hwnd]
        jne     .calendar
        mov     [hover_clock], 0
        ret
  .calendar:
        cmp     eax, [calendar_hwnd]
        jne     .volume
        mov     [hover_calendar], 0
        ret
  .volume:
        cmp     eax, [volume_hwnd]
        jne     .shutdown
        mov     [hover_volume], 0
        ret
  .shutdown:
        cmp     eax, [shutdown_hwnd]
        jne     .done
        mov     [hover_shutdown], 0
  .done:
        ret
endp

proc PollHover
        invoke  GetCursorPos, cursor_point
        invoke  WindowFromPoint, [cursor_point.x], [cursor_point.y]
        mov     edx, eax
        invoke  GetParent, edx
        test    eax, eax
        jz      .use_direct
        mov     edx, eax
  .use_direct:
        mov     [hover_clock], 0
        mov     [hover_calendar], 0
        mov     [hover_volume], 0
        mov     [hover_shutdown], 0
        mov     eax, edx
        call    SetHoverForWindow
        ret
endp

proc BuildShutdownCommand uses ebx esi edi
        mov     edi, command_args
        mov     esi, shutdown_prefix
  .prefix:
        lodsb
        stosb
        test    al, al
        jnz     .prefix
        dec     edi
        mov     eax, [shutdown_delay]
        xor     ecx, ecx
        mov     ebx, 10
  .digits:
        xor     edx, edx
        div     ebx
        push    edx
        inc     ecx
        test    eax, eax
        jnz     .digits
  .write:
        pop     eax
        add     al, '0'
        stosb
        loop    .write
        mov     byte [edi], 0
        ret
endp

proc PaintClock uses ebx esi edi
        local ps:PAINTSTRUCT
        local st:SYSTEMTIME
        lea     eax, [ps]
        invoke  BeginPaint, [clock_hwnd], eax
        mov     ebx, eax
        mov     eax, [clock_hwnd]
        mov     [current_paint_hwnd], eax
        stdcall SetupScaledDC, ebx, CLOCK_W, CLOCK_H
        invoke  CreateSolidBrush, 00FF00FFh
        mov     esi, eax
        invoke  FillRect, ebx, base_clock_rect, esi
        invoke  DeleteObject, esi
        invoke  SetBkMode, ebx, TRANSPARENT
        invoke  CreatePen, PS_SOLID, 3, [theme_clock_outline]
        mov     esi, eax
        invoke  SelectObject, ebx, esi
        mov     edi, eax
        invoke  CreateSolidBrush, [theme_clock_bg]
        push    eax
        invoke  SelectObject, ebx, eax
        push    eax
        invoke  Ellipse, ebx, 15, 8, 245, 238
        pop     eax
        invoke  SelectObject, ebx, eax
        pop     eax
        invoke  DeleteObject, eax
        invoke  SelectObject, ebx, edi
        invoke  DeleteObject, esi

        invoke  SelectObject, ebx, [font_clock]
        invoke  SetTextAlign, ebx, TA_CENTER+TA_BASELINE
        invoke  SetTextColor, ebx, [theme_text_primary]
        mov     esi, 1
  .numbers:
        mov     eax, esi
        imul    eax, 5
        cmp     eax, 60
        jb      .idx_ok
        sub     eax, 60
  .idx_ok:
        movsx   ecx, word [unit_x+eax*2]
        imul    ecx, 88
        mov     eax, ecx
        cdq
        mov     ecx, 1000
        idiv    ecx
        add     eax, 130
        mov     edi, eax
        mov     eax, esi
        imul    eax, 5
        cmp     eax, 60
        jb      .idy_ok
        sub     eax, 60
  .idy_ok:
        movsx   ecx, word [unit_y+eax*2]
        imul    ecx, 88
        mov     eax, ecx
        cdq
        mov     ecx, 1000
        idiv    ecx
        add     eax, 128
        push    eax
        cinvoke wsprintf, number_buffer, number_format, esi
        invoke  lstrlen, number_buffer
        pop     edx
        invoke  TextOut, ebx, edi, edx, number_buffer, eax
        inc     esi
        cmp     esi, 13
        jb      .numbers

        lea     eax, [st]
        invoke  GetLocalTime, eax
        movzx   eax, [st.wHour]
        mov     ecx, 12
        xor     edx, edx
        div     ecx
        mov     eax, edx
        imul    eax, 5
        movzx   ecx, [st.wMinute]
        xor     edx, edx
        mov     edi, 12
        xchg    eax, ecx
        div     edi
        xchg    eax, ecx
        add     eax, ecx
        push    [theme_clock_hand]
        push    5
        push    57
        push    eax
        push    ebx
        call    DrawHand
        movzx   eax, [st.wMinute]
        push    [theme_clock_hand]
        push    4
        push    80
        push    eax
        push    ebx
        call    DrawHand
        movzx   eax, [st.wSecond]
        push    000000C8h
        push    2
        push    88
        push    eax
        push    ebx
        call    DrawHand
        invoke  CreateSolidBrush, [theme_clock_hand]
        mov     esi, eax
        invoke  FillRect, ebx, center_rect, esi
        invoke  DeleteObject, esi

        invoke  SelectObject, ebx, [font_clock]
        invoke  SetTextAlign, ebx, TA_CENTER+TA_BASELINE
        movzx   eax, [st.wHour]
        cmp     eax, 12
        jb      .am
        mov     esi, pm_text
        jmp     .ampm
  .am:
        mov     esi, am_text
  .ampm:
        invoke  lstrlen, esi
        invoke  TextOut, ebx, 130, 158, esi, eax
        cmp     [move_interval_minutes], 0
        je      .no_move_countdown
        mov     eax, [move_countdown_seconds]
        cmp     [move_active], 0
        je      .countdown_value
        xor     eax, eax
  .countdown_value:
        xor     edx, edx
        mov     ecx, 60
        div     ecx
        mov     esi, eax
        mov     edi, edx
        cinvoke wsprintf, message_buffer, move_countdown_format, esi, edi
        invoke  SelectObject, ebx, [font_countdown]
        invoke  SetTextColor, ebx, [theme_text_muted]
        invoke  SetTextAlign, ebx, TA_CENTER+TA_BASELINE
        invoke  lstrlen, message_buffer
        invoke  TextOut, ebx, 130, 180, message_buffer, eax
  .no_move_countdown:
        cmp     [hover_clock], 1
        jne     .clock_done
        invoke  SelectObject, ebx, [font_normal]
        invoke  SetTextColor, ebx, [theme_text_muted]
        invoke  lstrlen, clock_hover_text
        invoke  TextOut, ebx, 130, 246, clock_hover_text, eax
        push    ebx
        call    DrawHoverClose
  .clock_done:
        lea     eax, [ps]
        invoke  EndPaint, [clock_hwnd], eax
        ret
endp

proc DrawHand hdc, index, length, width, color
        push    ebx esi edi
        invoke  CreatePen, PS_SOLID, [width], [color]
        mov     ebx, eax
        invoke  SelectObject, [hdc], ebx
        mov     esi, eax
        invoke  MoveToEx, [hdc], 130, 123, 0
        mov     eax, [index]
        and     eax, 63
        cmp     eax, 60
        jb      .valid
        sub     eax, 60
  .valid:
        movsx   ecx, word [unit_x+eax*2]
        imul    ecx, [length]
        mov     eax, ecx
        cdq
        mov     ecx, 1000
        idiv    ecx
        add     eax, 130
        mov     edi, eax
        mov     eax, [index]
        and     eax, 63
        cmp     eax, 60
        jb      .valid_y
        sub     eax, 60
  .valid_y:
        movsx   ecx, word [unit_y+eax*2]
        imul    ecx, [length]
        mov     eax, ecx
        cdq
        mov     ecx, 1000
        idiv    ecx
        add     eax, 123
        invoke  LineTo, [hdc], edi, eax
        invoke  SelectObject, [hdc], esi
        invoke  DeleteObject, ebx
        pop     edi esi ebx
        ret
endp

proc PaintCalendar uses ebx esi edi
        local ps:PAINTSTRUCT
        local st:SYSTEMTIME
        local daynum:DWORD
        local firstdow:DWORD
        local days:DWORD
        lea     eax, [ps]
        invoke  BeginPaint, [calendar_hwnd], eax
        mov     ebx, eax
        mov     eax, [calendar_hwnd]
        mov     [current_paint_hwnd], eax
        stdcall SetupScaledDC, ebx, CAL_W, CAL_H
        invoke  CreateSolidBrush, [theme_calendar_bg]
        mov     esi, eax
        invoke  FillRect, ebx, base_cal_rect, esi
        invoke  DeleteObject, esi
        invoke  SetBkMode, ebx, TRANSPARENT
        invoke  SetTextColor, ebx, [theme_text_primary]
        lea     eax, [st]
        invoke  GetLocalTime, eax

        invoke  SelectObject, ebx, [font_heading]
        lea     eax, [st]
        invoke  GetDateFormat, LOCALE_USER_DEFAULT, 0, eax, month_format, date_buffer, 80
        invoke  SetTextAlign, ebx, TA_CENTER+TA_BASELINE
        invoke  lstrlen, date_buffer
        invoke  TextOut, ebx, 124, 27, date_buffer, eax

        invoke  SelectObject, ebx, [font_calendar]
        mov     esi, 0
  .weekdays:
        mov     edi, [weekday_ptrs+esi*4]
        mov     eax, esi
        imul    eax, 34
        add     eax, 22
        push    eax
        invoke  lstrlen, edi
        pop     ecx
        invoke  TextOut, ebx, ecx, 54, edi, eax
        inc     esi
        cmp     esi, 7
        jb      .weekdays

        movzx   eax, [st.wDay]
        dec     eax
        xor     edx, edx
        mov     ecx, 7
        div     ecx
        movzx   eax, [st.wDayOfWeek]
        sub     eax, edx
        jns     .fd_ok
        add     eax, 7
  .fd_ok:
        add     eax, 6
        xor     edx, edx
        mov     ecx, 7
        div     ecx
        mov     eax, edx
        mov     [firstdow], eax
        movzx   eax, [st.wMonth]
        dec     eax
        movzx   eax, byte [month_days+eax]
        mov     [days], eax
        cmp     [st.wMonth], 2
        jne     .days_ready
        movzx   eax, [st.wYear]
        call    IsLeapYear
        add     [days], eax
  .days_ready:
        mov     [daynum], 1
  .day_loop:
        mov     eax, [daynum]
        dec     eax
        add     eax, [firstdow]
        xor     edx, edx
        mov     ecx, 7
        div     ecx
        mov     esi, eax                    ; row
        mov     edi, edx                    ; column
        mov     eax, edi
        imul    eax, 34
        add     eax, 5
        mov     [day_rect.left], eax
        add     eax, 34
        mov     [day_rect.right], eax
        mov     eax, esi
        imul    eax, 25
        add     eax, 64
        mov     [day_rect.top], eax
        add     eax, 24
        mov     [day_rect.bottom], eax
        movzx   eax, [st.wDay]
        cmp     eax, [daynum]
        jne     .normal_day
        invoke  CreateSolidBrush, [theme_today_fill]
        mov     esi, eax
        invoke  FillRect, ebx, day_rect, esi
        invoke  DeleteObject, esi
        invoke  SetTextColor, ebx, [theme_accent_text]
  .normal_day:
        cinvoke wsprintf, number_buffer, number_format, [daynum]
        mov     eax, [day_rect.left]
        add     eax, 17
        push    eax
        mov     eax, [day_rect.top]
        add     eax, 18
        push    eax
        invoke  lstrlen, number_buffer
        pop     edx
        pop     ecx
        invoke  TextOut, ebx, ecx, edx, number_buffer, eax
        invoke  SetTextColor, ebx, [theme_text_primary]
        inc     [daynum]
        mov     eax, [daynum]
        cmp     eax, [days]
        jbe     .day_loop

        ; A fine month-progress rule immediately above the today card.
        mov     eax, 240
        movzx   ecx, [st.wDay]
        imul    eax, ecx
        xor     edx, edx
        div     [days]
        add     eax, 5
        mov     [month_progress_rect.right], eax
        invoke  CreateSolidBrush, [theme_track]
        mov     esi, eax
        invoke  FillRect, ebx, month_progress_track, esi
        invoke  DeleteObject, esi
        invoke  CreateSolidBrush, [theme_progress]
        mov     esi, eax
        invoke  FillRect, ebx, month_progress_rect, esi
        invoke  DeleteObject, esi

        invoke  CreateSolidBrush, [theme_day_card]
        mov     esi, eax
        invoke  FillRect, ebx, day_card_rect, esi
        invoke  DeleteObject, esi
        invoke  SetTextColor, ebx, [theme_accent_text]
        invoke  SelectObject, ebx, [font_day]
        invoke  SetTextAlign, ebx, TA_CENTER+TA_BASELINE
        movzx   eax, [st.wDay]
        cinvoke wsprintf, number_buffer, number_format, eax
        invoke  lstrlen, number_buffer
        invoke  TextOut, ebx, 125, 350, number_buffer, eax
        invoke  SelectObject, ebx, [font_calendar]
        lea     eax, [st]
        invoke  GetDateFormat, LOCALE_USER_DEFAULT, 0, eax, bottom_date_format, date_buffer, 80
        invoke  lstrlen, date_buffer
        invoke  TextOut, ebx, 125, 395, date_buffer, eax
        cmp     [hover_calendar], 1
        jne     .calendar_done
        invoke  SetTextAlign, ebx, TA_RIGHT+TA_BASELINE
        invoke  lstrlen, settings_label
        invoke  TextOut, ebx, 218, 18, settings_label, eax
        push    ebx
        call    DrawHoverClose
  .calendar_done:

        lea     eax, [ps]
        invoke  EndPaint, [calendar_hwnd], eax
        ret
endp

proc IsLeapYear year
        mov     eax, [year]
        xor     edx, edx
        mov     ecx, 400
        div     ecx
        test    edx, edx
        jz      .yes
        mov     eax, [year]
        xor     edx, edx
        mov     ecx, 100
        div     ecx
        test    edx, edx
        jz      .no
        mov     eax, [year]
        and     eax, 3
        jz      .yes
  .no:
        xor     eax, eax
        ret
  .yes:
        mov     eax, 1
        ret
endp

proc PaintShutdown uses ebx esi edi
        local ps:PAINTSTRUCT
        lea     eax, [ps]
        invoke  BeginPaint, [shutdown_hwnd], eax
        mov     ebx, eax
        mov     eax, [shutdown_hwnd]
        mov     [current_paint_hwnd], eax
        stdcall SetupScaledDC, ebx, SHUT_W, SHUT_H
        invoke  CreateSolidBrush, 00FF00FFh
        mov     esi, eax
        invoke  FillRect, ebx, base_shut_rect, esi
        invoke  DeleteObject, esi
        invoke  CreateSolidBrush, [theme_shutdown_bg]
        mov     esi, eax
        invoke  FillRect, ebx, shutdown_panel_rect, esi
        invoke  DeleteObject, esi
        invoke  SetBkMode, ebx, TRANSPARENT
        cmp     [move_active], 0
        je      .normal_shutdown
        invoke  CreateSolidBrush, [theme_day_card]
        mov     esi, eax
        invoke  FillRect, ebx, shutdown_panel_rect, esi
        invoke  DeleteObject, esi
        invoke  SelectObject, ebx, [font_move]
        invoke  SetTextColor, ebx, [theme_accent_text]
        invoke  SetTextAlign, ebx, TA_CENTER+TA_BASELINE
        invoke  lstrlen, move_text
        invoke  TextOut, ebx, 125, 69, move_text, eax
        jmp     .no_shutdown_title
  .normal_shutdown:
        cmp     [shutdown_active], 0
        je      .shutdown_label
        invoke  GetTickCount
        sub     eax, [shutdown_start_tick]
        xor     edx, edx
        mov     ecx, 1000
        div     ecx
        cmp     eax, [shutdown_delay]
        jbe     .elapsed_ok
        mov     eax, [shutdown_delay]
  .elapsed_ok:
        mov     [shutdown_elapsed], eax
        invoke  CreateSolidBrush, [theme_shutdown_track]
        mov     esi, eax
        invoke  FillRect, ebx, shutdown_progress_track, esi
        invoke  DeleteObject, esi
        mov     eax, 236
        imul    eax, [shutdown_elapsed]
        xor     edx, edx
        div     [shutdown_delay]
        add     eax, 7
        mov     [shutdown_progress_fill.right], eax
        invoke  CreateSolidBrush, [theme_shutdown_fill]
        mov     esi, eax
        invoke  FillRect, ebx, shutdown_progress_fill, esi
        invoke  DeleteObject, esi
        invoke  SelectObject, ebx, [font_calendar]
        invoke  SetTextColor, ebx, [theme_accent_text]
        cinvoke wsprintf, message_buffer, elapsed_format, [shutdown_elapsed], [shutdown_delay]
        invoke  SetTextAlign, ebx, TA_CENTER+TA_BASELINE
        invoke  lstrlen, message_buffer
        invoke  TextOut, ebx, 125, 63, message_buffer, eax
  .shutdown_label:
        invoke  SelectObject, ebx, [font_heading]
        invoke  SetTextColor, ebx, [theme_text_secondary]
        invoke  SetTextAlign, ebx, TA_CENTER+TA_BASELINE
        invoke  SetTextColor, ebx, [theme_text_secondary]
        invoke  lstrlen, shutdown_hover_text
        invoke  TextOut, ebx, 125, 96, shutdown_hover_text, eax
        cmp     [hover_shutdown], 1
        jne     .no_shutdown_title
        push    ebx
        call    DrawHoverClose
  .no_shutdown_title:
        lea     eax, [ps]
        invoke  EndPaint, [shutdown_hwnd], eax
        ret
endp

proc PaintVolume uses ebx esi edi
        local ps:PAINTSTRUCT
        lea     eax, [ps]
        invoke  BeginPaint, [volume_hwnd], eax
        mov     ebx, eax
        mov     eax, [volume_hwnd]
        mov     [current_paint_hwnd], eax
        stdcall SetupScaledDC, ebx, VOL_W, VOL_H
        invoke  CreateSolidBrush, 00FF00FFh
        mov     esi, eax
        invoke  FillRect, ebx, base_vol_rect, esi
        invoke  DeleteObject, esi
        invoke  CreateSolidBrush, [theme_volume_bg]
        mov     esi, eax
        invoke  FillRect, ebx, volume_panel_rect, esi
        invoke  DeleteObject, esi
        invoke  SetBkMode, ebx, TRANSPARENT
        invoke  SetTextColor, ebx, [theme_volume_text]
        invoke  SelectObject, ebx, [font_volume]
        cinvoke wsprintf, message_buffer, volume_format, [volume_level]
        invoke  lstrlen, message_buffer
        invoke  TextOut, ebx, 14, 10, message_buffer, eax
        mov     esi, 0
  .bar_loop:
        mov     eax, esi
        imul    eax, 10
        add     eax, 15
        mov     [bar_rect.left], eax
        add     eax, 7
        mov     [bar_rect.right], eax
        mov     eax, esi
        imul    eax, 3
        mov     edx, 72
        sub     edx, eax
        mov     [bar_rect.top], edx
        mov     [bar_rect.bottom], 76
        mov     eax, esi
        inc     eax
        imul    eax, 100
        xor     edx, edx
        mov     ecx, 22
        div     ecx
        cmp     eax, [volume_level]
        ja      .bar_off
        invoke  CreateSolidBrush, [theme_bar_on]
        jmp     .bar_fill
  .bar_off:
        invoke  CreateSolidBrush, [theme_bar_off]
  .bar_fill:
        mov     edi, eax
        invoke  FillRect, ebx, bar_rect, edi
        invoke  DeleteObject, edi
        inc     esi
        cmp     esi, 22
        jb      .bar_loop
        cmp     [hover_volume], 1
        jne     .vol_done
        invoke  SetTextColor, ebx, [theme_hover]
        invoke  lstrlen, volume_hover_text
        invoke  TextOut, ebx, 112, 10, volume_hover_text, eax
        push    ebx
        call    DrawHoverClose
  .vol_done:
        lea     eax, [ps]
        invoke  EndPaint, [volume_hwnd], eax
        ret
endp

proc DrawHoverClose hdc
        invoke  SelectObject, [hdc], [font_normal]
        invoke  SetTextAlign, [hdc], TA_RIGHT+TA_BASELINE
        invoke  SetTextColor, [hdc], [theme_close]
        invoke  TextOut, [hdc], 242, 18, close_label, 1
        ret
endp

section '.data' data readable writeable

  app_name          db 'Gadgets v9',0
  class_name        db 'FasmGadgetsV9Window',0
  clock_title       db 'Station Clock',0
  calendar_title    db 'Calendar',0
  volume_title      db 'Volume',0
  shutdown_title    db 'Shutdown',0
  settings_title    db 'Gadget Settings',0
  button_class      db 'BUTTON',0
  edit_class        db 'EDIT',0
  font_face         db 'Segoe UI',0
  font_mono         db 'Consolas',0
  now_text          db 'Now',0
  delay_text        db 'Delay',0
  default_delay     db '180',0
  am_text           db 'am',0
  pm_text           db 'pm',0
  clock_hover_text  db 'CLOCK  |  right-click settings',0
  volume_hover_text db 'SETTINGS',0
  settings_label    db 'SETTINGS',0
  shutdown_hover_text db 'ShutDown',0
  move_text         db 'MOVE',0
  move_countdown_format db '%02u:%02u',0
  close_label       db 'X',0
  shutdown_exe      db 'shutdown.exe',0
  args_now          db '/s /t 0',0
  shutdown_prefix   db '/s /t ',0
  confirm_shutdown  db 'Shut down Windows now?',0
  scheduled_format  db 'Windows will shut down in %u seconds.',0
  delay_error       db 'Enter a delay greater than zero seconds.',0
  volume_format     db 'Volume: %u%%',0
  elapsed_format    db '%u / %u sec',0
  error_text        db 'Gadgets could not start.',0
  settings_error_v9 db 'Font sizes: 10-36 points (today number up to 120).',13,10,'Scale: 50-200%. Opacity: 20-100%.',13,10,'Move reminder: 0-99 minutes (0 disables).',0
  speech_time_format db 'The time is %u:%02u %s.',0
  speech_unavailable_text db 'The Windows speech voice is unavailable.',13,10,'No setting was changed.',0
  move_prompt_normal du 'It is time to move your body and get some blood flow going. Ten squats, or take a walk.',0
  move_prompt_biological du 'Biological entity is required to move their body at this time, please. Ten squats at the very least, or find stairs and use them.',0
  month_format      db 'MMMM yyyy',0
  bottom_date_format db 'dddd, MMMM yyyy',0
  day_format        db 'dddd',0
  number_format     db '%u',0
  ini_name          db 'gadgets_v9.ini',0
  section_clock     db 'Clock',0
  section_calendar  db 'Calendar',0
  section_month     db 'MonthHeading',0
  section_today     db 'TodayNumber',0
  section_layout    db 'Layout',0
  section_global    db 'Global',0
  section_visibility db 'Visibility',0
  section_notes     db 'Notes',0
  key_size          db 'Size',0
  key_bold          db 'Bold',0
  key_clockx        db 'ClockX',0
  key_clocky        db 'ClockY',0
  key_calx          db 'CalendarX',0
  key_caly          db 'CalendarY',0
  key_volx          db 'VolumeX',0
  key_voly          db 'VolumeY',0
  key_shutx         db 'ShutdownX',0
  key_shuty         db 'ShutdownY',0
  key_scale         db 'ScalePercent',0
  key_opacity       db 'OpacityPercent',0
  key_keepontop     db 'KeepOnTop',0
  key_darkmode      db 'DarkMode',0
  key_moveinterval  db 'MoveReminderMinutes',0
  key_timeannouncement db 'TimeAnnouncementMinutes',0
  key_showclock     db 'ShowClock',0
  key_showcal       db 'ShowCalendar',0
  key_showvol       db 'ShowVolume',0
  key_showshut      db 'ShowShutdown',0
  key_fontnote      db 'FontSizes',0
  key_scalenote     db 'Scaling',0
  font_note         db 'All Size values are font points.',0
  scale_note        db 'ScalePercent changes every gadget uniformly; OpacityPercent affects all gadgets.',0

  sun db 'Sun',0
  mon db 'Mon',0
  tue db 'Tue',0
  wed db 'Wed',0
  thu db 'Thu',0
  fri db 'Fri',0
  sat db 'Sat',0
  weekday_ptrs dd mon,tue,wed,thu,fri,sat,sun
  month_days db 31,28,31,30,31,30,31,31,30,31,30,31

  CLSID_SpVoice GUID 96749377-3391-11D2-9EE3-00C04F797396
  IID_ISpVoice  GUID 6C44DF74-72B9-4992-A1EC-EF996E0422D4

  ; Unit circle coordinates, index 0 at twelve o'clock, clockwise.
  unit_x dw 0,105,208,309,407,500,588,669,743,809,866,914,951,978,995,1000,995,978,951,914,866,809,743,669,588,500,407,309,208,105,0,-105,-208,-309,-407,-500,-588,-669,-743,-809,-866,-914,-951,-978,-995,-1000,-995,-978,-951,-914,-866,-809,-743,-669,-588,-500,-407,-309,-208,-105
  unit_y dw -1000,-995,-978,-951,-914,-866,-809,-743,-669,-588,-500,-407,-309,-208,-105,0,105,208,309,407,500,588,669,743,809,866,914,951,978,995,1000,995,978,951,914,866,809,743,669,588,500,407,309,208,105,0,-105,-208,-309,-407,-500,-588,-669,-743,-809,-866,-914,-951,-978,-995

  instance          dd 0
  clock_hwnd        dd 0
  calendar_hwnd     dd 0
  shutdown_hwnd     dd 0
  volume_hwnd       dd 0
  now_button        dd 0
  min3_button       dd 0
  delay_edit        dd 0
  font_normal       dd 0
  font_volume       dd 0
  font_controls     dd 0
  font_clock        dd 0
  font_calendar     dd 0
  font_heading      dd 0
  font_day          dd 0
  font_move         dd 0
  font_countdown    dd 0
  clock_font_size   dd 22
  clock_bold        dd 1
  calendar_font_size dd 12
  calendar_bold     dd 0
  month_font_size   dd 18
  month_bold        dd 1
  day_font_size     dd 99
  day_bold          dd 1
  scale_percent     dd 90
  opacity_percent   dd 85
  keep_on_top       dd 1
  dark_mode         dd 0
  move_interval_minutes dd 0
  move_countdown_seconds dd 0
  move_display_seconds dd 0
  move_active       dd 0
  move_beep_count   dd 0
  move_speech_pending dd 0
  move_panel_was_visible dd 1
  move_now_was_visible dd 1
  move_delay_was_visible dd 1
  move_edit_was_visible dd 1
  time_announcement_minutes dd 0
  last_announcement_minute dd -1
  sapi_com_initialized dd 0
  sapi_voice ISpVoice
  window_ex_style   dd WS_EX_TOPMOST+WS_EX_TOOLWINDOW+WS_EX_LAYERED
  zorder_target     dd HWND_TOPMOST
  theme_clock_bg    dd 00F8F7F1h
  theme_calendar_bg dd 00F8F7F1h
  theme_shutdown_bg dd 00D7D4CBh
  theme_volume_bg   dd 00312D2Ah
  theme_text_primary dd 00202020h
  theme_text_secondary dd 00504D48h
  theme_text_muted  dd 00404040h
  theme_track       dd 00C8C5BEh
  theme_progress    dd 00202020h
  theme_today_fill  dd 00A85C42h
  theme_day_card    dd 00A44A18h
  theme_accent_text dd 00FFFFFFh
  theme_volume_text dd 00FFFFFFh
  theme_bar_on      dd 00F4F4F4h
  theme_bar_off     dd 00605B57h
  theme_hover       dd 0090E090h
  theme_close       dd 003030D0h
  theme_clock_outline dd 00252525h
  theme_clock_hand  dd 00202020h
  theme_shutdown_track dd 00A44A18h
  theme_shutdown_fill dd 00312D2Ah
  show_clock        dd 1
  show_calendar     dd 1
  show_volume       dd 1
  show_shutdown     dd 1
  layer_alpha       dd 255
  translated        dd 0
  shutdown_delay    dd 180
  shutdown_active   dd 0
  shutdown_start_tick dd 0
  shutdown_elapsed dd 0
  volume_raw        dd 0
  volume_level      dd 50
  hover_clock       dd 0
  hover_calendar    dd 0
  hover_volume      dd 0
  hover_shutdown    dd 0
  track_mouse       dd 16,2
  track_hwnd        dd 0
                    dd 0
  command_args      rb 40
  message_buffer    rb 96
  speech_buffer     rb 96
  speech_wide_buffer rw 96
  speech_time       SYSTEMTIME
  ini_path          rb 260
  ini_value         rb 32
  clock_x           dd -1
  clock_y           dd -1
  cal_x             dd -1
  cal_y             dd -1
  vol_x             dd -1
  vol_y             dd -1
  shut_x            dd -1
  shut_y            dd -1
  number_buffer     rb 32
  date_buffer       rb 80
  client_rect       RECT
  day_rect          RECT
  center_rect       RECT 126,119,134,127
  shutdown_panel_rect RECT 0,0,250,108
  volume_panel_rect RECT 5,5,245,87
  day_card_rect     RECT 0,214,250,420
  month_progress_track RECT 5,210,245,213
  month_progress_rect RECT 5,210,5,213
  shutdown_progress_track RECT 7,45,243,69
  shutdown_progress_fill RECT 7,45,7,69
  bar_rect          RECT
  cursor_point      POINT
  save_rect         RECT
  physical_rect     RECT
  base_clock_rect   RECT 0,0,CLOCK_W,CLOCK_H
  base_cal_rect     RECT 0,0,CAL_W,CAL_H
  base_vol_rect     RECT 0,0,VOL_W,VOL_H
  base_shut_rect    RECT 0,0,SHUT_W,SHUT_H
  current_paint_hwnd dd 0
  click_x           dd 0
  click_y           dd 0
  scaled_width      dd 250
  scaled_clock_h    dd CLOCK_H
  scaled_cal_h      dd CAL_H
  scaled_vol_h      dd VOL_H
  scaled_shut_h     dd SHUT_H
  scaled_padding    dd PADDING
  scaled_gap        dd GAP
  ctrl_x1           dd 7
  ctrl_x2           dd 130
  ctrl_y1           dd 7
  ctrl_w            dd 113
  ctrl_h            dd 32
  edit_y            dd 45
  edit_w            dd 236
  edit_h            dd 24

  wc WNDCLASS 0,WindowProc,0,0,NULL,NULL,NULL,COLOR_BTNFACE+1,NULL,class_name
  msg MSG

section '.idata' import data readable writeable

  library kernel32, 'KERNEL32.DLL',\
          user32,   'USER32.DLL',\
          gdi32,    'GDI32.DLL',\
          shell32,  'SHELL32.DLL',\
          winmm,    'WINMM.DLL',\
          ole32,    'OLE32.DLL'

  include 'api\kernel32.inc'
  include 'api\user32.inc'
  include 'api\gdi32.inc'
  include 'api\shell32.inc'

  import winmm,\
         waveOutGetVolume, 'waveOutGetVolume',\
         waveOutSetVolume, 'waveOutSetVolume'

  import ole32,\
         CoInitialize, 'CoInitialize',\
         CoCreateInstance, 'CoCreateInstance',\
         CoUninitialize, 'CoUninitialize'

section '.rsrc' resource data readable

  directory RT_ICON, icons, RT_GROUP_ICON, group_icons, RT_DIALOG, dialogs
  resource icons, 1, LANG_ENGLISH+SUBLANG_DEFAULT, icon_data
  resource group_icons, 1, LANG_ENGLISH+SUBLANG_DEFAULT, main_icon
  resource dialogs, IDD_SETTINGS, LANG_ENGLISH+SUBLANG_DEFAULT, settings_dialog

  icon main_icon, icon_data, 'assets\gadgets-fasm.ico'

  dialog settings_dialog, 'Gadget Settings', 0, 0, 280, 443, WS_CAPTION+WS_POPUP+WS_SYSMENU+DS_MODALFRAME+DS_CENTER, 0, 0, 'Segoe UI', 10
    dialogitem 'BUTTON','Clock numbers',-1,8,7,264,44,WS_VISIBLE+BS_GROUPBOX
    dialogitem 'STATIC','Size:',-1,20,25,34,12,WS_VISIBLE
    dialogitem 'EDIT','',IDC_CLOCKSIZE,58,22,55,16,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_NUMBER+ES_AUTOHSCROLL
    dialogitem 'BUTTON','Bold',IDC_CLOCKBOLD,140,22,65,16,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Calendar dates',-1,8,55,264,44,WS_VISIBLE+BS_GROUPBOX
    dialogitem 'STATIC','Size:',-1,20,73,34,12,WS_VISIBLE
    dialogitem 'EDIT','',IDC_CALSIZE,58,70,55,16,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_NUMBER+ES_AUTOHSCROLL
    dialogitem 'BUTTON','Bold',IDC_CALBOLD,140,70,65,16,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Month and year heading',-1,8,103,264,44,WS_VISIBLE+BS_GROUPBOX
    dialogitem 'STATIC','Size:',-1,20,121,34,12,WS_VISIBLE
    dialogitem 'EDIT','',IDC_MONTHSIZE,58,118,55,16,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_NUMBER+ES_AUTOHSCROLL
    dialogitem 'BUTTON','Bold',IDC_MONTHBOLD,140,118,65,16,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Large today number',-1,8,151,264,44,WS_VISIBLE+BS_GROUPBOX
    dialogitem 'STATIC','Size:',-1,20,169,34,12,WS_VISIBLE
    dialogitem 'EDIT','',IDC_DAYSIZE,58,166,55,16,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_NUMBER+ES_AUTOHSCROLL
    dialogitem 'BUTTON','Bold',IDC_DAYBOLD,140,166,65,16,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Global appearance and visibility',-1,8,199,264,94,WS_VISIBLE+BS_GROUPBOX
    dialogitem 'STATIC','Scale %:',-1,20,216,48,12,WS_VISIBLE
    dialogitem 'EDIT','',IDC_SCALE,70,213,45,16,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_NUMBER
    dialogitem 'STATIC','Opacity %:',-1,134,216,58,12,WS_VISIBLE
    dialogitem 'EDIT','',IDC_OPACITY,196,213,45,16,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_NUMBER
    dialogitem 'BUTTON','Clock',IDC_SHOWCLOCK,20,237,54,15,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Calendar',IDC_SHOWCAL,78,237,66,15,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Volume',IDC_SHOWVOL,148,237,60,15,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Shutdown',IDC_SHOWSHUT,210,237,62,15,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Keep windows on top',IDC_ONTOP,20,256,130,15,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'BUTTON','Dark mode',IDC_DARKMODE,160,256,82,15,WS_VISIBLE+WS_TABSTOP+BS_AUTOCHECKBOX
    dialogitem 'STATIC','Uncheck a gadget to hide it.',-1,20,274,220,12,WS_VISIBLE
    dialogitem 'BUTTON','Move reminder',-1,8,297,264,44,WS_VISIBLE+BS_GROUPBOX
    dialogitem 'STATIC','Interval (minutes, 0 disables):',-1,20,315,158,12,WS_VISIBLE
    dialogitem 'EDIT','',IDC_MOVEINT,186,312,55,16,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_NUMBER+ES_AUTOHSCROLL
    dialogitem 'BUTTON','Time announcements (Windows voice)',-1,8,345,264,62,WS_VISIBLE+BS_GROUPBOX
    dialogitem 'BUTTON','Off',IDC_ANNOUNCEOFF,20,363,34,15,WS_VISIBLE+WS_TABSTOP+WS_GROUP+BS_AUTORADIOBUTTON
    dialogitem 'BUTTON','Every 30 minutes',IDC_ANNOUNCE30,60,363,94,15,WS_VISIBLE+WS_TABSTOP+BS_AUTORADIOBUTTON
    dialogitem 'BUTTON','Every hour',IDC_ANNOUNCE60,162,363,70,15,WS_VISIBLE+WS_TABSTOP+BS_AUTORADIOBUTTON
    dialogitem 'BUTTON','Test time',IDC_TESTVOICE,48,383,80,18,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
    dialogitem 'BUTTON','Test MOVE',IDC_TESTMOVE,150,383,80,18,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
    dialogitem 'BUTTON','Apply',IDC_APPLY,52,414,52,19,WS_VISIBLE+WS_TABSTOP+BS_DEFPUSHBUTTON
    dialogitem 'BUTTON','Cancel',IDCANCEL,112,414,52,19,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
    dialogitem 'BUTTON','Exit',IDC_QUIT,172,414,52,19,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
  enddialog
