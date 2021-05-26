SETLOCAL ENABLEDELAYEDEXPANSION
@ECHO OFF

SET Result=%1
SET ScriptVersion=1.2
SET SCRIPT_DIR=%~dp0

TITLE WeekNumber Release Manager %ScriptVersion%
MODE 39,21
CLS

IF "%Result%" EQU "" GOTO :MENU

IF "%Result%" NEQ "0" (
	@ECHO =======================================
	@ECHO Last operation failed! Return code = %Result%
	@ECHO =======================================
)
IF "%Result%" EQU "0" (
	@ECHO =======================================
	@ECHO Last operation completed successfully!
	@ECHO =======================================
)

:MENU
CD /D "%SCRIPT_DIR%"
COLOR 1E
ECHO =======================================
ECHO WeekNumber Release Manager version %ScriptVersion%
ECHO =======================================
ECHO.
ECHO A) Build solution and create release
ECHO.
ECHO B) Update version, sync source, 
ECHO    build solution and create release
ECHO.
ECHO C) Build solution, create and publish
ECHO    release
ECHO.
ECHO D) Update version, sync source, build
ECHO    solution, create and publish release
ECHO.
ECHO X) Exit
ECHO.
CHOICE /C ABCDX /M "Select action"
SET USER_SELECTION=%ERRORLEVEL%

IF %USER_SELECTION%==1 START /MAX CreateRelease.bat
IF %USER_SELECTION%==2 START /MAX CreateRelease.bat U
IF %USER_SELECTION%==3 START /MAX CreateRelease.bat P
IF %USER_SELECTION%==4 START /MAX CreateRelease.bat UP

EXIT