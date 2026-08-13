@echo off
setlocal
set "FASM=..\tools\fasm\FASM.EXE"
set "INCLUDE=..\tools\fasm\INCLUDE"

if not exist "%FASM%" (
  echo FASM was not found at %FASM%
  exit /b 1
)

"%FASM%" gadgets_v9.asm gadgets_v9.exe
if errorlevel 1 exit /b 1
echo.
echo Built gadgets_v9.exe successfully.
