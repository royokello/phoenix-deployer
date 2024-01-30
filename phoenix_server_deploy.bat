@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM -- Change these variables as per your requirement --
SET "ZIP_FILE=phoenix_app.zip"
SET "DEST_DIR=/path/on/server"
SET "SERVER_USER=username"
SET "SERVER_IP=server_ip"
SET "SERVER_SERVICE=your_service"
SET "7ZIP_PATH=C:\Program Files\7-Zip\7z.exe"

REM -- Ensure 7-Zip is installed --
IF NOT EXIST "%7ZIP_PATH%" (
    echo 7-Zip not found at %7ZIP_PATH%
    echo Please install 7-Zip or update 7ZIP_PATH in this script.
    exit /b
)

REM -- Zip the necessary files, excluding certain directories --
echo Zipping necessary files...
"%7ZIP_PATH%" a -tzip %ZIP_FILE% . -xr!deps -xr!_build -xr!node_modules -xr!.git -xr!phoenix_server_deploy.bat

REM -- Stop the server service --
echo Stopping the server service...
ssh %SERVER_USER%@%SERVER_IP% sudo systemctl stop %SERVER_SERVICE%

REM -- Transfer the zip file --
echo Transferring files...
scp %ZIP_FILE% %SERVER_USER%@%SERVER_IP%:%DEST_DIR%

REM -- Delete old app directory, unzip new files, and restart service --
echo Setting up on server...
ssh %SERVER_USER%@%SERVER_IP% "
    rm -rf %DEST_DIR%/app_folder
    unzip %DEST_DIR%/%ZIP_FILE% -d %DEST_DIR%
    cd %DEST_DIR%/app_folder
    mix deps.get --only prod
    MIX_ENV=prod mix compile
    npm install --prefix ./assets
    npm run deploy --prefix ./assets
    mix phx.digest
    mix ecto.migrate
    sudo systemctl start %SERVER_SERVICE%
"

echo Process completed
ENDLOCAL
