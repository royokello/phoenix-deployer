@echo off

echo Deleting packed file...
del deploy.tar.gz

echo Delete compilation directory...
rmdir /S /Q deploy_tar

echo Create compilation directory...
IF NOT EXIST deploy_tar mkdir deploy_tar

echo Compiling files...
robocopy . deploy_tar /E /XD "deps" "_build" "node_modules" ".git" ".elixir_ls" ".github"

echo Packing files...
tar -czvf deploy.tar.gz -C deploy_tar .

echo Loading environment variables ...
if not exist "%env_file%" (
    echo Error: Environment file "%env_file%" not found!
    exit /b 1
)

for /f "delims=" %%a in (%env_file%) do set %%a

echo Checking if private key is encrypted ...
set is_encrypted=false

for /f "tokens=1* delims=:" %%A in ('ssh-keygen -y -f "%KEY_PATH%" 2^>nul') do (
    if "%%A"=="-----BEGIN ENCRYPTED PRIVATE KEY-----" (
        set is_encrypted=true
    )
)

REM If key is encrypted, prompt for passphrase
if "%is_encrypted%"=="true" (
    set /p passphrase="enter passphrase for private key: "
)

echo Stopping service...
ssh %SERVER_USER%@%SERVER_IP% sudo systemctl stop phoenix.service

echo Uploading files...
scp deploy.tar.gz %SERVER_USER%@%SERVER_IP%:%SERVER_DIR%

echo Deleting packed file...
del deploy.tar.gz

echo Delete compilation directory...
rmdir /S /Q deploy_tar

echo Unpacking files...
ssh %SERVER_USER%@%SERVER_IP% "rm -rf phoenix; mkdir -p phoenix; tar -xzvf deploy.tar.gz -C phoenix"

echo Downloading phoenix-server-start.sh from GitHub...
ssh %SERVER_USER%@%SERVER_IP% "sudo wget -O /root/phoenix/phoenix_server_start.sh https://raw.githubusercontent.com/royokello/phoenix-server-start/main/phoenix_server_start.sh; sudo chmod +x /root/phoenix/phoenix_server_start.sh"
echo phoenix_server_start.sh downloaded.

echo Downloading phoenix.service from GitHub...
ssh %SERVER_USER%@%SERVER_IP% "sudo wget -O /etc/systemd/system/phoenix.service https://raw.githubusercontent.com/royokello/phoenix-service-file/main/phoenix.service; sudo systemctl daemon-reload"
echo phoenix.service.

echo Starting phoenix.service...
ssh %SERVER_USER%@%SERVER_IP% sudo systemctl start phoenix.service
echo phoenix.service started.

echo Process completed
pause
