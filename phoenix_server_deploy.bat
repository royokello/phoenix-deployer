@echo off

:: Initialize variables with passed arguments
set PROJECT_NAME=
set SERVER_ADDRESS=
set SSH_KEY=
set SSH_USERNAME=

:: Parse input arguments
:parse
if "%1"=="" goto endparse
if "%1"=="-pn" (
    set PROJECT_NAME=%2
    shift
    shift
    goto parse
)
if "%1"=="-sa" (
    set SERVER_ADDRESS=%2
    shift
    shift
    goto parse
)
if "%1"=="-sk" (
    set SSH_KEY=%2
    shift
    shift
    goto parse
)
if "%1"=="-su" (
    set SSH_USERNAME=%2
    shift
    shift
    goto parse
)
shift
goto parse
:endparse

:: Check if necessary arguments are provided
if "%PROJECT_NAME%"=="" (
    echo "Error: Project name (-pn) is required."
    exit /b 1
)
if "%SERVER_ADDRESS%"=="" (
    echo "Error: Server address (-sa) is required."
    exit /b 1
)
if "%SSH_KEY%"=="" (
    echo "Error: SSH key (-sk) is required."
    exit /b 1
)
if "%SSH_USERNAME%"=="" (
    echo "Error: SSH username (-su) is required."
    exit /b 1
)

:: Define the project-specific variables
set APP_DIR=/root/%PROJECT_NAME%
set SERVICE_FILE=%PROJECT_NAME%.service
set SERVICE_PATH=/etc/systemd/system/%SERVICE_FILE%

echo Deleting packed file...
del %PROJECT_NAME%.tar.gz

echo Delete compilation directory...
rmdir /S /Q %PROJECT_NAME%_tar

echo Create compilation directory...
IF NOT EXIST %PROJECT_NAME%_tar mkdir %PROJECT_NAME%_tar

echo Compiling files...
robocopy . %PROJECT_NAME%_tar /E /XD "deps" "_build" "node_modules" ".git" ".elixir_ls" ".github"

echo Packing files...
tar -czvf %PROJECT_NAME%.tar.gz -C %PROJECT_NAME%_tar .

echo Generating custom service file...
(
echo [Unit]
echo Description=%PROJECT_NAME% service
echo After=network.target
echo.
echo [Service]
echo User=%SSH_USERNAME%
echo Group=%SSH_USERNAME%
echo Environment="PORT=4001"
echo Environment="MIX_ENV=prod"
echo Environment="DATABASE_URL=ecto://%PROJECT_NAME%:%PROJECT_NAME%@localhost/%PROJECT_NAME%"
echo WorkingDirectory=%APP_DIR%
echo ExecStart=%APP_DIR%/phoenix_server_start.sh
echo Restart=on-failure
echo RestartSec=180s
echo KillSignal=SIGQUIT
echo SyslogIdentifier=%PROJECT_NAME%
echo RemainAfterExit=no
echo.
echo [Install]
echo WantedBy=multi-user.target
) > %SERVICE_FILE%

echo Stopping existing service on server...
ssh -i %SSH_KEY% %SSH_USERNAME%@%SERVER_ADDRESS% "systemctl stop %PROJECT_NAME%.service"

echo Uploading files and customized service file...
scp -i %SSH_KEY% %PROJECT_NAME%.tar.gz %SSH_USERNAME%@%SERVER_ADDRESS%:%APP_DIR%
scp -i %SSH_KEY% %SERVICE_FILE% %SSH_USERNAME%@%SERVER_ADDRESS%:%SERVICE_PATH%

echo Downloading phoenix_server_start.sh from GitHub...
ssh -i %SSH_KEY% %SSH_USERNAME%@%SERVER_ADDRESS% "sudo wget -O %APP_DIR%/phoenix_server_start.sh https://raw.githubusercontent.com/royokello/phoenix-server-start/main/phoenix_server_start.sh; sudo chmod +x %APP_DIR%/phoenix_server_start.sh"
echo phoenix_server_start.sh downloaded.

echo Deploying files and enabling service...
ssh -i %SSH_KEY% %SSH_USERNAME%@%SERVER_ADDRESS% ^
"tar -xzvf %APP_DIR%/%PROJECT_NAME%.tar.gz -C %APP_DIR% &&
 systemctl daemon-reload &&
 systemctl enable %PROJECT_NAME%.service &&
 systemctl start %PROJECT_NAME%.service"

echo Process completed.
pause
