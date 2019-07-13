@echo off
cd /d %~dp0

echo Searching command wish and awk

set SEARCH_PATH="c:\Program Files\Git"

set PATH_LIST="path.list"

if EXIST %PATH_LIST% (
  del %PATH_LIST%
)

set BASH_CMD="bash.exe"
dir /s /b %SEARCH_PATH%\bin | findstr "%BASH_CMD%$" > path_list.tmp
for /f "delims=" %%i in (path_list.tmp) do (
  echo "%%i"
  echo %%i>> %PATH_LIST%
  echo %%i> bash_path.list
  echo @echo off > logcatch.bat
  echo "%%i" -l -c "wish src/LogCatch.tcl --dir src" >> logcatch.bat
  break
)
del path_list.tmp

set WISH_CMD="wish.exe"
dir /s /b %SEARCH_PATH% | findstr "%WISH_CMD%$" > path_list.tmp
for /f "delims=" %%i in (path_list.tmp) do (
  echo "%%i"
  echo %%i>> %PATH_LIST%
  echo %%i> wish_path.list
  :: echo @echo off > logcatch.bat
  :: echo "%%i" src\LogCatch.tcl --dir src >> logcatch.bat
  :: move /y logcatch.bat ..\
  break
)
:: exit /b 0
del path_list.tmp


set AWK_CMD="awk.exe"
dir /s /b %SEARCH_PATH% | findstr "%AWK_CMD%$" > path_list.tmp
for /f "delims=" %%i in (path_list.tmp) do (
  echo "%%i"
  echo %%i>> %PATH_LIST%
  echo %%i> awk_path.list
  break
)
del path_list.tmp


@rem set /P ans=""
@rem echo %ans%

exit /b 0

