SETLOCAL ENABLEDELAYEDEXPANSION
@ECHO OFF

SET Result=%1
SET ScriptVersion=1.2
SET SCRIPT_DIR=%~dp0

TITLE Release Manager %ScriptVersion%
MODE 41,24
CLS

IF "%Result%" EQU "" GOTO :MENU

IF "%Result%" NEQ "0" (
	@ECHO  =======================================
	@ECHO  Last operation failed! Return code = %Result%
	@ECHO  =======================================
)
IF "%Result%" EQU "0" (
	@ECHO  =======================================
	@ECHO  Last operation completed successfully!
	@ECHO  =======================================
)

:MENU
CD /D "%SCRIPT_DIR%"
COLOR 1E
ECHO  =======================================
ECHO  WeekNumber Release Manager version %ScriptVersion%
ECHO  =======================================
ECHO. 
ECHO  A) Build solution and create release
ECHO. 
ECHO  B) Update version, sync sources, 
ECHO     build solution and create release
ECHO. 
ECHO  C) Build solution, create and publish
ECHO     release
ECHO. 
ECHO  D) Update version, sync sources, build
ECHO     solution, create and publish release
ECHO. 
ECHO  E) Sync sources
ECHO. 
ECHO  X) Exit
ECHO. 
CHOICE /C ABCDEX /M "Select action"
SET USER_SELECTION=%ERRORLEVEL%

IF %USER_SELECTION%==1 START /MAX CreateRelease.bat
IF %USER_SELECTION%==2 START /MAX CreateRelease.bat U
IF %USER_SELECTION%==3 START /MAX CreateRelease.bat P
IF %USER_SELECTION%==4 START /MAX CreateRelease.bat UP
IF %USER_SELECTION%==5 (
	@CALL :SYNC_SOURCE
	GOTO :MENU
)

EXIT

:SYNC_SOURCE
CLS
ECHO Syncing sources, please wait...
GIT pull -q >NUL 2>&1
GIT add --all >NUL 2>&1
GIT commit -a -m "Auto update via Release Manager %ScriptVersion%" >NUL 2>&1
git push --all >NUL 2>&1
CLS
GOTO :EOF
