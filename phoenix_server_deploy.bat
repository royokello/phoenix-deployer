@echo off

REM Load environment variables from file
if not exist "%env_file%" (
    echo Error: Environment file "%env_file%" not found.
    exit /b 1
)

for /f "delims=" %%a in (%env_file%) do set %%a

REM Check if all required variables are set
if "%USERNAME%"=="" goto :missing_username
if "%KEY_PATH%"=="" goto :missing_key_path
if "%SERVER_ADDRESS%"=="" goto :missing_server_address

REM Check if private key is encrypted
set is_encrypted=false
for /f "tokens=1* delims=:" %%A in ('ssh-keygen -y -f "%KEY_PATH%" 2^>nul') do (
    if "%%A"=="-----BEGIN ENCRYPTED PRIVATE KEY-----" (
        set is_encrypted=true
    )
)

REM If key is encrypted, prompt for passphrase
if "%is_encrypted%"=="true" (
    set /p passphrase="Enter passphrase for private key: "
)

REM Execute SSH command
if "%is_encrypted%"=="true" (
    sshpass -p %passphrase% ssh -i "%KEY_PATH%" %USERNAME%@%SERVER_ADDRESS% %*
) else (
    ssh -i "%KEY_PATH%" %USERNAME%@%SERVER_ADDRESS% %*
)
goto :eof

:missing_username
echo Error: Username is not set in the environment file.
exit /b 1

:missing_key_path
echo Error: Private key path is not set in the environment file.
exit /b 1

:missing_server_address
echo Error: Server address is not set in the environment file.
exit /b 1











REM -- Change these variables as per your requirement --
SET "ZIP_FILE=phoenix_app.tar.gz"
SET "SOURCE_DIR=."
set DEST_DIR=/phoenix
set SERVER_USER=root
set SERVER_IP=178.128.36.156
set SERVER_SERVICE=phoenix

REM -- Zip the necessary files, excluding certain directories --
echo Zipping necessary files...
tar -czvf %ZIP_FILE% %SOURCE_DIR% --exclude=deps --exclude=_build --exclude=node_modules --exclude=.git

REM -- Stop the server service --
echo Stopping the server service...
ssh %SERVER_USER%@%SERVER_IP% sudo systemctl stop %SERVER_SERVICE%

REM -- Transfer the zip file --
echo Transferring files...
scp %ZIP_FILE% %SERVER_USER%@%SERVER_IP%:%DEST_DIR%

REM -- Delete old app directory, unzip new files, and restart service --
echo Setting up on server...
ssh %SERVER_USER%@%SERVER_IP% "
    rm -rf %DEST_DIR%
    unzip %DEST_DIR%/%ZIP_FILE% -d %DEST_DIR%
    cd %DEST_DIR%
    mix deps.get --only prod
    MIX_ENV=prod mix compile
    npm install --prefix ./assets
    npm run deploy --prefix ./assets
    mix phx.digest
    mix ecto.migrate
    sudo systemctl start %SERVER_SERVICE%
"

echo Process completed
pause
