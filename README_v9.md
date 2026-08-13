# Gadgets v9

Version 9 preserves all v5 through v8 source, executables, settings, and documentation.

New in v9:

- Settings adds time announcements with three choices: Off, every 30 minutes,
  or every hour. Off is the default.
- Announcements follow real wall-clock boundaries such as 10:00 and 10:30,
  rather than an interval measured from application startup.
- Test time speaks the current time immediately. Test MOVE plays the same
  spoken movement prompt used by the reminder.
- Speech uses the installed default Windows SAPI voice asynchronously. No
  internet connection, downloaded voice model, or bundled speech DLL is used.
- If Windows speech is unavailable, Gadgets continues normally and the Test
  buttons report the problem.
- After the existing three MOVE beeps, SAPI speaks an encouragement. Most
  reminders ask for ten squats or a walk; approximately one in four uses the
  alternate "biological entity" prompt and suggests squats or stairs.
- A MOVE prompt takes priority over a simultaneous clock announcement so one
  message cannot immediately purge the other.

All v8 behavior is retained, including the optional Move reminder and clock
countdown. Time announcement values are stored in `gadgets_v9.ini` as
`TimeAnnouncementMinutes=0`, `30`, or `60`.

Run `build_v9.cmd` to compile `gadgets_v9.exe`.
