@echo off
setlocal EnableDelayedExpansion

:: Initialize variables with passed arguments
set "PROJECT_NAME="
set "SERVER_ADDRESS="
set "SSH_KEY="
set "SSH_USERNAME="
set "COMMAND="
set "DB="
set "LOG_FILE="

:: Function to log messages with timestamp
:Log
if defined LOG_FILE (
    echo [%date% %time%] %~1 >> "%LOG_FILE%"
) else (
    echo [%date% %time%] %~1
)
goto :eof

:: Parse input arguments
:parse
if "%~1"=="" goto endparse
if /I "%~1"=="-pn" (
    set "PROJECT_NAME=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-sa" (
    set "SERVER_ADDRESS=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-sk" (
    set "SSH_KEY=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-su" (
    set "SSH_USERNAME=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-cmd" (
    set "COMMAND=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-db" (
    set "DB=%~2"
    shift
    shift
    goto parse
)
if /I "%~1"=="-log" (
    set "LOG_FILE=%~2"
    shift
    shift
    goto parse
)
echo "Unknown argument: %~1" | call :Log
echo "Unknown argument: %~1"
exit /b 1
:endparse

:: Check if necessary arguments are provided
if "%PROJECT_NAME%"=="" (
    echo "Error: Project name (-pn) is required." | call :Log
    exit /b 1
)
if "%SERVER_ADDRESS%"=="" (
    echo "Error: Server address (-sa) is required." | call :Log
    exit /b 1
)
if "%SSH_KEY%"=="" (
    echo "Error: SSH key (-sk) is required." | call :Log
    exit /b 1
)
if "%SSH_USERNAME%"=="" (
    echo "Error: SSH username (-su) is required." | call :Log
    exit /b 1
)
if "%COMMAND%"=="" (
    echo "Error: Command (-cmd) is required." | call :Log
    exit /b 1
)
if "%DB%"=="" (
    echo "Error: DB flag (-db) is required." | call :Log
    exit /b 1
)
if "%LOG_FILE%"=="" (
    echo "Error: Log file path (-log) is required." | call :Log
    exit /b 1
)

:: Validate 'DB' parameter
if /I "%DB%" NEQ "true" if /I "%DB%" NEQ "false" (
    echo "Error: 'DB' flag must be either 'true' or 'false'." | call :Log
    exit /b 1
)

:: Log start of deployer script
call :Log "Starting deployment for project '%PROJECT_NAME%' to server '%SERVER_ADDRESS%'."
call :Log "DB Setup Required: %DB%"

:: Define project-specific variables
set "MAIN_SERVER_DIR=/root"
set "APP_DIR=%MAIN_SERVER_DIR%/%PROJECT_NAME%"
set "SERVICE_FILE=%PROJECT_NAME%.service"
set "SERVICE_PATH=/etc/systemd/system/%SERVICE_FILE%"
set "TEMP_DIR=%PROJECT_NAME%_temp"
set "ZIP_FILE=%PROJECT_NAME%.tar.gz"

:: Create temporary directory
call :Log "Creating temporary directory '%TEMP_DIR%'..."
mkdir "%TEMP_DIR%"
if errorlevel 1 (
    echo "Error: Failed to create temporary directory '%TEMP_DIR%'." | call :Log
    exit /b 1
)
call :Log "Temporary directory created successfully."

:: Compile files into temporary directory
call :Log "Compiling files into temporary directory..."
robocopy . "%TEMP_DIR%" /E /XD "deps" "_build" "node_modules" ".git" ".elixir_ls" ".github" >nul
if errorlevel 8 (
    echo "Error: Robocopy encountered an issue while copying files." | call :Log
    exit /b 1
)
call :Log "Files compiled successfully."

:: Pack files
call :Log "Packing files into '%ZIP_FILE%'..."
tar -czvf "%ZIP_FILE%" -C "%TEMP_DIR%" . >nul
if errorlevel 1 (
    echo "Error: Failed to create archive '%ZIP_FILE%'." | call :Log
    exit /b 1
)
call :Log "Files packed successfully."

:: Download setup.sh from GitHub
call :Log "Downloading 'phoenix_server_setup.sh' from GitHub..."
ssh -i "%SSH_KEY%" "%SSH_USERNAME%@%SERVER_ADDRESS%" "sudo wget -O /root/phoenix_server_setup.sh https://raw.githubusercontent.com/royokello/phoenix-server-setup/main/phoenix_server_setup.sh && sudo chmod +x /root/phoenix_server_setup.sh"
if errorlevel 1 (
    echo "Error: Failed to download or set permissions for 'phoenix_server_setup.sh'." | call :Log
    exit /b 1
)
call :Log "'phoenix_server_setup.sh' downloaded and permissions set."

:: Run setup script
call :Log "Running setup script on server..."
ssh -i "%SSH_KEY%" "%SSH_USERNAME%@%SERVER_ADDRESS%" "sudo bash /root/phoenix_server_setup.sh -pn %PROJECT_NAME% -db %DB%"
if errorlevel 1 (
    echo "Error: Setup script execution failed on server." | call :Log
    exit /b 1
)
call :Log "Setup script executed successfully on server."

:: Stop existing service on server
call :Log "Stopping existing service '%SERVICE_FILE%' on server..."
ssh -i "%SSH_KEY%" "%SSH_USERNAME%@%SERVER_ADDRESS%" "sudo systemctl stop %SERVICE_FILE%"
if errorlevel 1 (
    echo "Error: Failed to stop existing service '%SERVICE_FILE%' on server." | call :Log
    exit /b 1
)
call :Log "Existing service stopped."

:: Upload files and service file
call :Log "Uploading archive '%ZIP_FILE%' to server..."
scp -i "%SSH_KEY%" "%ZIP_FILE%" "%SSH_USERNAME%@%SERVER_ADDRESS%:%MAIN_SERVER_DIR%"

if errorlevel 1 (
    echo "Error: Failed to upload '%ZIP_FILE%' to server." | call :Log
    exit /b 1
)
call :Log "Archive uploaded successfully."

call :Log "Uploading service file '%SERVICE_FILE%' to server..."
scp -i "%SSH_KEY%" "%SERVICE_FILE%" "%SSH_USERNAME%@%SERVER_ADDRESS%:%SERVICE_PATH%"
if errorlevel 1 (
    echo "Error: Failed to upload service file '%SERVICE_FILE%' to server." | call :Log
    exit /b 1
)
call :Log "Service file uploaded successfully."

:: Unpack project archive on server
call :Log "Unpacking archive on server to '%APP_DIR%'..."
ssh -i "%SSH_KEY%" "%SSH_USERNAME%@%SERVER_ADDRESS%" "mkdir -p %APP_DIR% && tar -xzvf %MAIN_SERVER_DIR%/%ZIP_FILE% -C %APP_DIR%"
if errorlevel 1 (
    echo "Error: Failed to unpack archive on server." | call :Log
    exit /b 1
)
call :Log "Archive unpacked successfully on server."

:: Clean up uploaded archive on server
call :Log "Cleaning up uploaded archive on server..."
ssh -i "%SSH_KEY%" "%SSH_USERNAME%@%SERVER_ADDRESS%" "rm %MAIN_SERVER_DIR%/%ZIP_FILE%"
if errorlevel 1 (
    echo "Warning: Failed to remove archive '%ZIP_FILE%' from server." | call :Log
) else (
    call :Log "Uploaded archive removed from server."
)

:: Deploy files and enable service
call :Log "Deploying files and enabling service '%SERVICE_FILE%'..."
ssh -i "%SSH_KEY%" "%SSH_USERNAME%@%SERVER_ADDRESS%" "sudo systemctl daemon-reload && sudo systemctl enable %SERVICE_FILE% && sudo systemctl start %SERVICE_FILE%"
if errorlevel 1 (
    echo "Error: Failed to deploy service '%SERVICE_FILE%' on server." | call :Log
    exit /b 1
)
call :Log "Service '%SERVICE_FILE%' deployed and started successfully."

:: Delete temporary files on the development machine
call :Log "Deleting temporary files on the development machine..."
rmdir /S /Q "%TEMP_DIR%"
if errorlevel 1 (
    echo "Warning: Failed to delete temporary directory '%TEMP_DIR%'." | call :Log
) else (
    call :Log "Temporary directory deleted successfully."
)

del "%ZIP_FILE%"
if errorlevel 1 (
    echo "Warning: Failed to delete archive '%ZIP_FILE%'." | call :Log
) else (
    call :Log "Archive '%ZIP_FILE%' deleted successfully."
)

:: Log completion
call :Log "Deployment process completed successfully for project '%PROJECT_NAME%'."
echo "Process completed successfully. Check the log file '%LOG_FILE%' for details."
pause
endlocal
