# Gadgets v10

> **Use at your own risk.** This experimental software is provided as-is,
> without guarantees or warranties. The shutdown controls can close programs
> and cause loss of unsaved work.

Version 10 is a separate successor to the preserved v9 build.

## Changes

- Calendar painting is double-buffered. Hover repaints happen only when hover
  state changes and never request a background erase. The calendar is no
  longer repainted every second; it refreshes when the local date changes.
- **Now** speaks "Shutting down now" synchronously, then calls
  `shutdown.exe /p /f`. Windows defines `/p` as powering off with no timeout or
  warning, while `/f` forcibly closes running applications. Unsaved work can
  be lost.
- A delayed shutdown changes **Delay** to **Cancel** only after
  `shutdown.exe /s /t ...` exits successfully. **Cancel** waits for the official
  `shutdown.exe /a` abort command to succeed before restoring the delay field
  and speaking "Shutdown cancelled."
- The old Gadgets confirmation and scheduled-information dialogs were removed.
  Invalid delay input still displays an error because no shutdown was started.
- Speech remains local to installed Windows SAPI voices. Shutdown commands
  still run if speech is unavailable.
- The settings dialog remains compact at 340 dialog units rather than the
  former 443-unit layout. A persisted **Speech language** choice applies to
  every spoken path: English, Polish, Italian, Spanish, German, Japanese,
  Mandarin, or French. Choices not exposed to Gadgets by Windows are greyed
  out.
- Clock left-clicks speak the current time. A left-click on the full-date line
  at the bottom of the calendar speaks the current date. Both use Windows
  locale formatting for the selected language.
- The shutdown panel now displays **SHUTDOWN** above the **Now** and
  **Delay/Cancel** buttons.

## Language voice requirement

English restores the original default SAPI voice, matching the behavior that
worked before multilingual speech was added. For other languages, Gadgets
searches both the legacy desktop SAPI category and the newer Windows OneCore
voice category, then selects an installed matching token. Mandarin also accepts
the traditional-Chinese Mandarin locale as a fallback.

Gadgets does not download or install voice packs. Unavailable language buttons
are disabled. **Manage voices...** opens the official Windows Speech settings
page (`ms-settings:speech`); after installing a voice, return to Gadgets and
select **Refresh**.

## Build and safe verification

Run `build_v10.cmd`, followed by:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test_v10_offline.ps1
```

The offline test never launches Gadgets, plays audio, or runs `shutdown.exe`.
A live GUI/audio check and any real shutdown/cancellation test require
separate, explicit authorization.
