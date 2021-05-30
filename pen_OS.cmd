@echo off
setlocal EnableDelayedExpansion

:: =====================================================
::
:: script for creating a pen drive with OS
:: 11.2017 - JG /jg@pwr.pl/
::
:: =====================================================

set $OS=%1
set $dp_file=x:\pen\diskpart.txt
set $path=r:\mb\pendrive
set $wim_path=%$path%\wim
set $script_path=%$path%\scripts

if not exist x:\pen mkdir x:\pen
if "%$OS%"=="" ( 
	set $error=missing parameter
	goto error
)
dir /b /s /w %$wim_path%\x64 | find "%$OS%" > nul
if %ERRORLEVEL% EQU 0 (
	set $platform=x64
	goto prepare
)
dir /b /s /w %$wim_path%\x86 | find "%$OS%" > nul
if %ERRORLEVEL% EQU 0 (
	set $platform=x86
	goto prepare
)

set $error=Bad project...
goto error

:prepare
:: =====================================================
:: checking if is there any pendrive
:: =====================================================
echo.
set $pen=0
for /f "usebackq tokens=1,2" %%A in (`wmic diskdrive get index^,mediatype^|find "Removable"`) do (
    set $disk=%%A 
	set /a $pen+=1
)
if %$pen% GTR 1 (
	set $error=There is more one pendrive connected
	goto error
)
if "%$disk%"=="" (
	set $error=No pendrive
	goto error
)
:: =====================================================
:: formatting drive and create partition
:: =====================================================

if exist %$dp_file% del %$dp_file%

echo rescan>%$dp_file%
echo sel dis %$disk%>>%$dp_file%
echo clean>>%$dp_file%
echo convert mbr>>%$dp_file%
echo creat part prim>>%$dp_file%
echo sel part 1 >>%$dp_file%
echo format fs=fat32 quick label="OS_PEN">>%$dp_file%
echo active>>%$dp_file%
echo assig>>%$dp_file%

set $loop=4
:loop
if %$loop% GTR 0 (
	diskpart /s %$dp_file%
	for /f %%D in ('wmic volume get DriveLetter^, Label ^| find "OS_PEN"') do set $disk_letter=%%D
	if "%$disk_letter%"=="" (
		set /a $loop = $loop - 1
		goto loop)
	goto tu
)
:tu
:: =====================================================
:: checking volume's letter
:: =====================================================

for /f %%D in ('wmic volume get DriveLetter^, Label ^| find "OS_PEN"') do set $disk_letter=%%D

:: =====================================================
:: copying files
:: =====================================================
:copy
echo nothing>%$disk_letter%\remove.it
for /f "usebackq tokens=1,2,3" %%A in (`dir /-c %$disk_letter%\^|find "bytes free"`) do (
	set $tmp=%%C
	set $size=!$tmp:~0,-3!
)
for /f "usebackq tokens=1,2,3" %%A in (`dir /-c %$wim_path%\%$platform%\%$OS%^|find "File(s)"`) do (
	set $tmp=%%C
	set $files=!$tmp:~0,-3!
)
if %$size% LSS %$files% (
	set $error=No enough space on pendrive
	goto error
)
del %$disk_letter%\remove.it
robocopy %$path%\WinPE\  %$disk_letter%\ /e
robocopy %$path%\sources\%$platform%\  %$disk_letter%\sources /e /J /MT:32 
robocopy %$wim_path%\%$platform%\%$OS% %$disk_letter%\src\ /e /J /MT:32

:: =====================================================
:: creating the start script
:: =====================================================
:script
if exist %$disk_letter%\run.cmd del %$disk_letter%\run.cmd

type %$script_path%\run_part_01.txt>%$disk_letter%\run.cmd
echo set $OS=%$OS%>>%$disk_letter%\run.cmd
echo goto preload>>%$disk_letter%\run.cmd
type %$script_path%\run_part_02.txt>>%$disk_letter%\run.cmd
if /I "%$platform%"=="x64" (
	echo %%root_dir%%:\script\w8Rest.cmd %%$OS%% %%$DISK_NR%% >>%$disk_letter%\run.cmd
) else (
	echo %%root_dir%%:\script\w8Rest_x32.cmd %%$OS%% >>%$disk_letter%\run.cmd
)
type %$script_path%\run_part_03.txt>>%$disk_letter%\run.cmd

:: type %$disk_letter%\run.cmd
	
goto end

:error
cls
echo %$error%

:end
echo STOP
pause