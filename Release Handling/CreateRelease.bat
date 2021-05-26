SETLOCAL ENABLEDELAYEDEXPANSION
@ECHO OFF

:: ==========================
:: Optional input parameter
:: ==========================
:: Parameter values:
::  <no value given> = do not update version and do not publish
::  U                = update version but do not publish
::  P                = do not update version only publish
::  UP               = update version and publish
SET SCRIPT_PARAMETER=%1

:: ==========================
:: Global script variables
:: ==========================
SET "VERSION="
SET "PUBLISH_REL=FALSE"
SET "UPDATE_VER=FALSE"
IF "%SCRIPT_PARAMETER%" EQU "U" SET "UPDATE_VER=TRUE"
IF "%SCRIPT_PARAMETER%" EQU "P" SET "PUBLISH_REL=TRUE"
IF "%SCRIPT_PARAMETER%" EQU "UP" SET "UPDATE_VER=TRUE" && SET "PUBLISH_REL=TRUE"
SET "SCRIPT_DIR=%~dp0"
SET "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
SET "RELEASE_MANAGER=%SCRIPT_DIR%\ReleaseManager.bat"
SET "NSIS_SCRIPT_FOLDER=%SCRIPT_DIR%\..\NSIS Installation"

:: ==========================
:: GitHub release API variables
:: ==========================
:: Get secret GitHub access token from external file into variable 'GITHUB_ACCESS_TOKEN'
CALL GITHUB_ACCESS_TOKEN.bat
SET "REPO_OWNER=voltura"
SET "REPO_NAME=WeekNumber"
:: v%VERSION%
SET "TAG_NAME=" 
:: BRANCH (master)
SET "TARGET_COMMITISH=master"
:: WeekNumber %VERSION%
SET "NAME="
::"Release of version %VERSION%"
SET "BODY="
SET "DRAFT=false"
SET "PRERELEASE=false"
SET "CURL_RESULT="
SET "UPLOAD_URL="

:: ==========================
:: Tools
:: ==========================
SET "SEVEN_ZIP_FULLPATH=C:\Program Files\7-Zip\7z.exe"
SET "MSBUILD_FULLPATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\amd64\MSBuild.exe"
SET "FART=%SCRIPT_DIR%\..\Tools\fart.exe"
SET "CURL=C:\Program Files\curl-7.76.1-win64-mingw\bin\curl.exe"

:: ==========================
:: Script logic
:: ==========================
TITLE Creating WeekNumber release...
COLOR 1E
CLS
CALL :UPDATE_VERSION
CALL :COMPILE_RELEASE
CALL :CREATE_INSTALLER_AND_FILES_FOR_RELEASE
CALL :PUBLISH_RELEASE
CALL :DISP_MSG "All tasks completed successfully, launching the Release Manager..." 2
START "Release Manager" "%RELEASE_MANAGER%" 0
EXIT

:: ==========================
:: Functions
:: ==========================
:CREATE_INSTALLER_AND_FILES_FOR_RELEASE
ECHO.
ECHO Compiling installer, please be patient...
START "Compile Installer" /MIN /WAIT "%NSIS_SCRIPT_FOLDER%\CompileInstaller.bat" %VERSION%
SET RESULT=%ERRORLEVEL%
CD /D "%NSIS_SCRIPT_FOLDER%"
IF "%RESULT%" EQU "0" (
	@CALL :DISP_MSG "Installer successfully compiled." 2
	@CALL :GENERATE_MD5 WeekNumber_%VERSION%_Installer.exe
	@CALL :COMPRESS_INSTALLER
	@CALL :GENERATE_MD5 WeekNumber_%VERSION%_Installer.7z
	@CALL :COMPRESS_WEEKNUMBER_ZIP
	@CALL :GENERATE_MD5 WeekNumber.zip
	@CALL :GENERATE_VERSION_INFO %VERSION% WeekNumber_%VERSION%_Installer.exe
	@CALL :COPY_RELEASE
	@DEL /F /Q "%NSIS_SCRIPT_FOLDER%\WeekNumber_%VERSION%_Installer.log"
	@CALL :DISP_MSG "Generated all release files successfully." 2
) ELSE (
	@NOTEPAD.EXE "%NSIS_SCRIPT_FOLDER%\WeekNumber_%VERSION%_Installer.log"
	@CALL :ERROR_MESSAGE_EXIT "Failed to compile installer." %RESULT%
)
CD /D "%SCRIPT_DIR%"
GOTO :EOF

:GENERATE_MD5
ECHO.
ECHO Generating MD5 for '%1'...
SET "MD5="
FOR /F "skip=1" %%G IN ('CertUtil -hashfile %1 MD5') DO (
	@SET "MD5=%%G"
	@GOTO :CREATE_MD5 %1
)
CALL :ERROR_MESSAGE_EXIT "Failed to generate MD5 for '%1'." 10
:CREATE_MD5
SET FILE_NAME=%1
ECHO.
ECHO %MD5%  %FILE_NAME%> "%NSIS_SCRIPT_FOLDER%\%FILE_NAME%.MD5"
ECHO.>> "%NSIS_SCRIPT_FOLDER%\%FILE_NAME%.MD5"
ECHO Generated MD5 checksum file '%NSIS_SCRIPT_FOLDER%\%FILE_NAME%.MD5'.
GOTO :EOF

:COMPRESS_INSTALLER
IF NOT EXIST "%SEVEN_ZIP_FULLPATH%" CALL :ERROR_MESSAGE_EXIT "Compress tool not found, cannot compress installer." 10
CD /D %NSIS_SCRIPT_FOLDER%
"%SEVEN_ZIP_FULLPATH%" a -t7z -y WeekNumber_%VERSION%_Installer.7z WeekNumber_%VERSION%_Installer.exe WeekNumber_%VERSION%_Installer.exe.MD5
SET SEVEN_ZIP_RESULT=%ERRORLEVEL%
CD /D %SCRIPT_DIR%
IF "%SEVEN_ZIP_RESULT%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Failed to compress installer" %SEVEN_ZIP_RESULT%
GOTO :EOF

:COMPRESS_WEEKNUMBER_ZIP
ECHO.
ECHO Archiving installer...
IF NOT EXIST "%SEVEN_ZIP_FULLPATH%" CALL :ERROR_MESSAGE_EXIT "7-zip not found '%SEVEN_ZIP_FULLPATH%', cannot compress installer." 10
CD /D "%NSIS_SCRIPT_FOLDER%"
"%SEVEN_ZIP_FULLPATH%" a -tzip -y WeekNumber.zip WeekNumber_%VERSION%_Installer.exe WeekNumber_%VERSION%_Installer.exe.MD5
SET SEVEN_ZIP_RESULT=%ERRORLEVEL%
CD /D "%SCRIPT_DIR%"
IF "%SEVEN_ZIP_RESULT%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "7-zip failed to generate 'WeekNumber.zip'." %SEVEN_ZIP_RESULT%
ECHO Completed.
GOTO :EOF

:GENERATE_VERSION_INFO
ECHO.
ECHO %1 %2> "%NSIS_SCRIPT_FOLDER%\VERSION.TXT"
ECHO '%NSIS_SCRIPT_FOLDER%\VERSION.TXT' created.
GOTO :EOF

:COPY_RELEASE
ECHO.
ECHO Copying release files to release folder...
MD "%SCRIPT_DIR%\..\Releases\%VERSION%" >NUL 2>&1
IF NOT EXIST "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber.zip" CALL :ERROR_MESSAGE_EXIT "WeekNumber.zip could not be copied" 10
MOVE /Y "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber.zip" "%SCRIPT_DIR%\..\Releases\%VERSION%\"
IF "%ERRORLEVEL%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Failed to move WeekNumber.zip" 10
IF NOT EXIST "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber.zip.MD5" CALL :ERROR_MESSAGE_EXIT "WeekNumber.zip.MD5 not found" 10
MOVE /Y "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber.zip.MD5" "%SCRIPT_DIR%\..\Releases\%VERSION%\"
IF "%ERRORLEVEL%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Failed to move WeekNumber.zip.MD5" 10
IF NOT EXIST "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber_%VERSION%_Installer.7z" CALL :ERROR_MESSAGE_EXIT "WeekNumber_%VERSION%_Installer.7z not found" 10
MOVE /Y "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber_%VERSION%_Installer.7z" "%SCRIPT_DIR%\..\Releases\%VERSION%\"
IF "%ERRORLEVEL%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Failed to move WeekNumber_%VERSION%_Installer.7z" 10
IF NOT EXIST "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber_%VERSION%_Installer.7z.MD5" CALL :ERROR_MESSAGE_EXIT "Failed, missing file" 11
MOVE /Y "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber_%VERSION%_Installer.7z.MD5" "%SCRIPT_DIR%\..\Releases\%VERSION%\"
IF "%ERRORLEVEL%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Move failed" 11
IF NOT EXIST "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber_%VERSION%_Installer.exe" GOTO :FAILED_COPY_RELEASE
MOVE /Y "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber_%VERSION%_Installer.exe" "%SCRIPT_DIR%\..\Releases\%VERSION%\"
IF "%ERRORLEVEL%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Copy failed" 12
IF NOT EXIST "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber_%VERSION%_Installer.exe.MD5" CALL :ERROR_MESSAGE_EXIT "Failed, missing file" 12
MOVE /Y "%SCRIPT_DIR%\..\NSIS Installation\WeekNumber_%VERSION%_Installer.exe.MD5" "%SCRIPT_DIR%\..\Releases\%VERSION%\"
IF "%ERRORLEVEL%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Move failed" 13
IF NOT EXIST "%SCRIPT_DIR%\..\NSIS Installation\VERSION.TXT" CALL :ERROR_MESSAGE_EXIT "Failed, missing file" 13
MOVE /Y "%SCRIPT_DIR%\..\NSIS Installation\VERSION.TXT" "%SCRIPT_DIR%\..\Releases\%VERSION%\"
IF "%ERRORLEVEL%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Failed to copy release files." 10
GOTO :EOF

:UPDATE_VERSION
ECHO.
ECHO Getting current version from project...
TYPE "%SCRIPT_DIR%\..\Properties\AssemblyInfo.cs"|FINDSTR AssemblyFileVersion >"%SCRIPT_DIR%\VERSION_REPLACE.TXT"
SET /P AssemblyFileVersion=<"%SCRIPT_DIR%\VERSION_REPLACE.TXT"
DEL /F /Q "%SCRIPT_DIR%\VERSION_REPLACE.TXT"
SET "CurrentAssemblyFileVersion=%AssemblyFileVersion:~32,-3%"
SET "MAJOR="
SET "MINOR="
SET "BUILD="
SET "REVISION="

FOR /F "tokens=1,2,3,4 delims=." %%G IN ("%CurrentAssemblyFileVersion%") DO (
	SET /A MAJOR=%%G
	SET /A MINOR=%%H
	SET /A BUILD=%%I
	SET /A REVISION=%%J
)
SET VERSION=%MAJOR%.%MINOR%.%BUILD%.%REVISION%
IF "%UPDATE_VER%" EQU "TRUE" (
	@CALL :UPDATE_REVISION
) ELSE (
	@CALL :SKIP_VERSION_UPDATE
)
GOTO :EOF

:SKIP_VERSION_UPDATE
CALL :DISP_MSG "Current version = %VERSION%." 2
GOTO :EOF

:UPDATE_REVISION
IF %REVISION% GEQ 9 GOTO :UPDATE_BUILD
ECHO Updating revision number
SET /A REVISION=%REVISION%+1
SET NewAssemblyFileVersion=%MAJOR%.%MINOR%.%BUILD%.%REVISION%
GOTO :DO_VER_UPDATE

:UPDATE_BUILD
IF %BUILD% GEQ 9 GOTO :UPDATE_MINOR
ECHO Updating build number
SET /A BUILD=%BUILD%+1
SET NewAssemblyFileVersion=%MAJOR%.%MINOR%.%BUILD%.0
GOTO :DO_VER_UPDATE

:UPDATE_MINOR
IF %MINOR% GEQ 9 GOTO :UPDATE_MAJOR
ECHO Updating minor number
SET /A MINOR=%MINOR%+1
SET NewAssemblyFileVersion=%MAJOR%.%MINOR%.0.0
GOTO :DO_VER_UPDATE

:UPDATE_MAJOR
SET /A MAJOR=%MAJOR%+1
ECHO Updating major number
SET NewAssemblyFileVersion=%MAJOR%.0.0.0
GOTO :DO_VER_UPDATE

:DO_VER_UPDATE
ECHO.
ECHO Updating version from '%CurrentAssemblyFileVersion%' to '%NewAssemblyFileVersion%'...
"%FART%" -q "%SCRIPT_DIR%\..\Properties\AssemblyInfo.cs" %CurrentAssemblyFileVersion% %NewAssemblyFileVersion%
SET FART_RESULT=%ERRORLEVEL%
IF "%FART_RESULT%" NEQ "1" CALL :ERROR_MESSAGE_EXIT "Failed to update version." 10
SET VERSION=%NewAssemblyFileVersion%
CALL :DISP_MSG "Version updated from '%CurrentAssemblyFileVersion%' to '%NewAssemblyFileVersion%'." 2
GIT pull -q
GIT add --all
GIT commit -a  -m "Updated version to %VERSION%"
git push --all
GOTO :EOF

:COMPILE_RELEASE
ECHO.
ECHO Compiling solution release build...
PUSHD "%SCRIPT_DIR%\.."
	CALL "%MSBUILD_FULLPATH%" WeekNumber.sln /p:Platform=x86 /t:Rebuild /property:Configuration=Release -m
	SET BUILD_RESULT=%ERRORLEVEL%
POPD
IF "%BUILD_RESULT%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Build failed. Cannot create release." 10
IF "%BUILD_RESULT%" EQU "0" CALL :DISP_MSG "Build was successfully executed." 2
GOTO :EOF

:PUBLISH_RELEASE
IF "%PUBLISH_REL%" NEQ "TRUE" GOTO :EOF
CALL :DISP_MSG "Publishing release to Github..." 1
SET "TAG_NAME=v%VERSION%"
SET "NAME=WeekNumber %VERSION%"
SET "BODY=Release of version %VERSION%"
"%CURL%" -s -H "Accept: application/vnd.github.v3+json" -H "Authorization: token %GITHUB_ACCESS_TOKEN%" -H "Content-Type:application/json" "https://api.github.com/repos/%REPO_OWNER%/%REPO_NAME%/releases" -d "{ \"tag_name\": \"%TAG_NAME%\", \"target_commitish\": \"%TARGET_COMMITISH%\",\"name\": \"%NAME%\",\"body\": \"%BODY%\",\"draft\": %DRAFT%, \"prerelease\": %PRERELEASE%}" >"%SCRIPT_DIR%\release_info.txt"
SET CURL_RESULT=%ERRORLEVEL%
IF "%CURL_RESULT%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Failed to publish release" 10
CALL :DISP_MSG "Successfully published release." 2
CALL :PARSE_RELEASE_INFO
CALL :UPLOAD_RELEASE_ASSETS
GOTO :EOF

:PARSE_RELEASE_INFO
ECHO.
ECHO Parsing release info...
TYPE "%SCRIPT_DIR%\release_info.txt"|FINDSTR upload_url >"%SCRIPT_DIR%\UPLOAD_URL.TXT"
DEL /F /Q "%SCRIPT_DIR%\release_info.txt" >NUL
SET /P UPLOAD_URL=<"%SCRIPT_DIR%\UPLOAD_URL.TXT"
DEL /F /Q "%SCRIPT_DIR%\UPLOAD_URL.TXT" >NUL
SET UPLOAD_URL=%UPLOAD_URL:~17,-15%
ECHO UPLOAD_URL=%UPLOAD_URL%
CALL :DISP_MSG "Successfully parsed received release info." 1
GOTO :EOF

:UPLOAD_RELEASE_ASSETS
ECHO.
CALL :DISP_MSG "Uploading release '%NAME%' assets to Github..." 1
PUSHD "%SCRIPT_DIR%\..\Releases\%VERSION%"
	CALL :UPLOAD_FILE WeekNumber.zip
	CALL :UPLOAD_FILE WeekNumber.zip.MD5
	CALL :UPLOAD_FILE WeekNumber_%VERSION%_Installer.7z
	CALL :UPLOAD_FILE "WeekNumber_%VERSION%_Installer.7z.MD5"
	CALL :UPLOAD_FILE "WeekNumber_%VERSION%_Installer.exe"
	CALL :UPLOAD_FILE "WeekNumber_%VERSION%_Installer.exe.MD5"
	CALL :UPLOAD_FILE VERSION.TXT
POPD
CALL :DISP_MSG "Upload completed." 2
GOTO :EOF

:UPLOAD_FILE
ECHO.
SET FILE_TO_UPLOAD=%1
CALL :CHECK_IF_MISSING_FILE %FILE_TO_UPLOAD%
ECHO Uploading '%FILE_TO_UPLOAD%' to release '%NAME%' on Github...
"%CURL%" -s -H "Accept: application/vnd.github.v3+json" -H "Authorization: token %GITHUB_ACCESS_TOKEN%" -H "Content-Type: application/octet-stream" --data-binary @%FILE_TO_UPLOAD% "%UPLOAD_URL%?name=%FILE_TO_UPLOAD%&label=%FILE_TO_UPLOAD%"
SET CURL_RESULT=%ERRORLEVEL%
:: Note: curl result can be 0 but file not uploaded, need to parse received json to validate success
IF "%CURL_RESULT%" NEQ "0" CALL :ERROR_MESSAGE_EXIT "Failed to upload '%FILE_TO_UPLOAD%'" 10
CALL :DISP_MSG "Successfully uploaded '%FILE_TO_UPLOAD%'."
GOTO :EOF

:CHECK_IF_MISSING_FILE
SET FILE_TO_CHECK=%1
IF NOT EXIST "%FILE_TO_CHECK%" CALL :ERROR_MESSAGE_EXIT "Missing '%FILE_TO_CHECK%', cannot publish file." 10
GOTO :EOF

:ERROR_MESSAGE_EXIT
SET MSG=%1
SET MSG=%MSG:~1,-1%
SET CODE=%2
COLOR 4F
ECHO.
ECHO   ==================================================
ECHO   CODE:  %CODE%
ECHO   ERROR: %MSG%
ECHO   ==================================================
ECHO Press any key to restart the Release Manager...
PAUSE >NUL
START "Release Manager" "%RELEASE_MANAGER%" %CODE%
EXIT

:DISP_MSG
SET MSG=%1
SET MSG=%MSG:~1,-1%
SET /A DELAY_SEC=%2+0
COLOR 1F
ECHO.
ECHO   ==================================================
ECHO   %MSG%
ECHO   ==================================================
TIMEOUT /T %DELAY_SEC% /NOBREAK >NUL
COLOR 1E
GOTO :EOF