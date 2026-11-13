@echo off
setlocal DisableDelayedExpansion
set "ORIGINAL_CP="
for /f "tokens=2 delims=:" %%P in ('chcp') do for /f %%C in ("%%P") do set "ORIGINAL_CP=%%C"
chcp 65001 >nul

:: ============================================================================
:: Iniciar-Kali.bat
:: Script portable para desplegar y abrir Kali Linux en terminal de Windows
:: Soporta WSL2 (recomendado para principiantes/persistencia) y Docker Desktop.
:: Uso exclusivo para entornos controlados y laboratorios autorizados.
:: ============================================================================

set "SCRIPT_PATH=%~f0"
set "SCRIPT_NAME=%~nx0"
set "WSL_UTF8=1"
set "DISTRO_NAME=kali-linux"
set "IMAGE_NAME=kalilinux/kali-rolling"
set "CONTAINER_NAME=kali-lab"

set "MODE="
set "PROFILE=minimal"
set "EPHEMERAL=0"
set "HOST_NET=0"
set "NEW_TAB=0"
set "TOOLS_ONLY=0"
set "FORCE_MENU=0"
set "HERE_MODE=0"
set "ELEVATED=0"
set "DRY_RUN=0"
set "CUSTOM_WORKDIR="

:: Captura segura del directorio inicial (evita System32 si se abrió como Admin)
set "WORK_DIR=%CD%"
call :sanitize_workdir

:: Parseo de argumentos CLI
:parse_args
if "%~1"=="" goto :after_args

set "ARG=%~1"
if /i "%ARG%"=="-h" goto :show_help
if /i "%ARG%"=="--help" goto :show_help
if "%ARG%"=="/?" goto :show_help

if /i "%ARG%"=="--wsl" (
    set "MODE=wsl"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--docker" (
    set "MODE=docker"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--ephemeral" (
    set "EPHEMERAL=1"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--host-net" (
    set "HOST_NET=1"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--new-tab" (
    set "NEW_TAB=1"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--tools" (
    set "TOOLS_ONLY=1"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--menu" (
    set "FORCE_MENU=1"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--here" (
    set "HERE_MODE=1"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--elevated" (
    set "ELEVATED=1"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--dry-run" (
    set "DRY_RUN=1"
    shift
    goto :parse_args
)
if /i "%ARG%"=="--profile" (
    if "%~2"=="" (
        echo [ERROR] Falta valor para --profile ^(minimal ^| top10 ^| headless ^| default^).
        goto :fail_pause
    )
    set "PROFILE=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%ARG%"=="--workdir" (
    if "%~2"=="" (
        echo [ERROR] Falta ruta para --workdir.
        goto :fail_pause
    )
    set "CUSTOM_WORKDIR=%~2"
    set "HERE_MODE=1"
    shift
    shift
    goto :parse_args
)
if /i "%ARG%"=="--container" (
    if "%~2"=="" (
        echo [ERROR] Falta nombre para --container.
        goto :fail_pause
    )
    set "CONTAINER_NAME=%~2"
    shift
    shift
    goto :parse_args
)

echo [ERROR] Argumento no reconocido: %ARG%
echo Usa "%SCRIPT_NAME% --help" para ver las opciones disponibles.
goto :fail_pause

:after_args
if defined CUSTOM_WORKDIR (
    if not exist "%CUSTOM_WORKDIR%" (
        echo [ERROR] La carpeta indicada en --workdir no existe: %CUSTOM_WORKDIR%
        goto :fail_pause
    )
    set "WORK_DIR=%CUSTOM_WORKDIR%"
    call :sanitize_workdir
)

call :validate_profile
if errorlevel 1 goto :fail_pause

:: Detectar binarios disponibles
call :detect_tools

:: Si se pidió solo instalar herramientas en Kali WSL
if "%TOOLS_ONLY%"=="1" goto :wsl_tools_flow

:: Si se indicó modo explícito por CLI
if /i "%MODE%"=="docker" goto :docker_flow
if /i "%MODE%"=="wsl" goto :wsl_flow

:: Modo interactivo / arranque inteligente sin argumentos
if "%FORCE_MENU%"=="1" goto :interactive_menu

if "%KALI_WSL_INSTALLED%"=="1" (
    echo [OK] Kali Linux ^(WSL2^) detectado. Abriendo terminal...
    echo      ^(Consejo: ejecuta "%SCRIPT_NAME% --menu" para Docker o instalar herramientas^)
    goto :wsl_launch
)

:: Si Kali WSL aún no está instalado, mostrar menú amigable para el usuario nuevo
:interactive_menu
echo.
echo ========================================================================
echo   Kali Linux en Terminal de Windows - Asistente de Despliegue
echo ========================================================================
if "%KALI_WSL_INSTALLED%"=="1" (
    echo   Estado WSL2  : Kali Linux ^(kali-linux^) INSTALADO
) else (
    echo   Estado WSL2  : Kali Linux no instalado todavia
)
if defined DOCKER_BIN (
    echo   Estado Docker: Docker CLI disponible
) else (
    echo   Estado Docker: No detectado
)
echo   Carpeta base : %WORK_DIR%
echo ========================================================================
echo.
if "%KALI_WSL_INSTALLED%"=="1" goto :menu_installed
goto :menu_fresh

:menu_installed
echo   [1] Abrir Kali Linux en WSL2 ^(Recomendado^)
echo   [2] Instalar herramientas en Kali WSL ^(top10 / headless / default^)
echo   [3] Ejecutar Kali Linux en Docker ^(persistente^)
echo   [4] Ejecutar Kali Linux efimero en Docker ^(se borra al salir^)
echo   [5] Salir
echo.
set "CHOICE="
set /p "CHOICE=Elige una opcion [1-5]: "
call :clean_choice
if "%CHOICE%"=="" goto :end_ok
if "%CHOICE%"=="1" goto :wsl_launch
if "%CHOICE%"=="2" goto :wsl_tools_flow
if "%CHOICE%"=="3" (
    set "MODE=docker"
    set "EPHEMERAL=0"
    goto :docker_flow
)
if "%CHOICE%"=="4" (
    set "MODE=docker"
    set "EPHEMERAL=1"
    goto :docker_flow
)
if "%CHOICE%"=="5" goto :end_ok
echo [AVISO] Opcion no valida.
goto :interactive_menu

:menu_fresh
echo   No se detecto Kali Linux en WSL2 en este equipo.
echo.
echo   [1] Instalar y abrir Kali Linux en WSL2 ^(Recomendado - persistente^)
echo   [2] Ejecutar Kali Linux en Docker ^(requiere Docker Desktop^)
echo   [3] Ejecutar Kali Linux efimero en Docker ^(requiere Docker Desktop^)
echo   [4] Salir
echo.
set "CHOICE="
set /p "CHOICE=Elige una opcion [1-4]: "
call :clean_choice
if "%CHOICE%"=="" goto :end_ok
if "%CHOICE%"=="1" goto :wsl_flow
if "%CHOICE%"=="2" (
    set "MODE=docker"
    set "EPHEMERAL=0"
    goto :docker_flow
)
if "%CHOICE%"=="3" (
    set "MODE=docker"
    set "EPHEMERAL=1"
    goto :docker_flow
)
if "%CHOICE%"=="4" goto :end_ok
echo [AVISO] Opcion no valida.
goto :interactive_menu

:: ============================================================================
:: FLUJO WSL2
:: ============================================================================
:wsl_flow
if not defined WSL_BIN (
    echo [ERROR] No se encontro wsl.exe en este Windows.
    echo         Necesitas Windows 10 ^(compilacion 19041+^) o Windows 11.
    echo         Alternativa: instala Docker Desktop y ejecuta "%SCRIPT_NAME% --docker".
    goto :fail_pause
)

if "%KALI_WSL_INSTALLED%"=="1" goto :wsl_launch

echo.
echo [*] Kali Linux no esta instalado en WSL2. Iniciando instalacion...

if "%DRY_RUN%"=="1" (
    echo [DRY-RUN] Verificaria permisos de Administrador ^(net session^).
    echo [DRY-RUN] Ejecutaria: "%WSL_BIN%" --install -d %DISTRO_NAME% --no-launch
    echo [DRY-RUN] Fallback si falla Store: "%WSL_BIN%" --install -d %DISTRO_NAME% --web-download --no-launch
    goto :end_ok
)

net session >nul 2>&1
if errorlevel 1 (
    echo [*] Se necesitan permisos de Administrador para activar WSL2 e instalar Kali.
    echo     Acepta la ventana de Control de Cuentas de Usuario ^(UAC^)...
    call :elevate_self
    if errorlevel 1 (
        echo [ERROR] No se concedieron permisos de Administrador o se cancelo UAC.
        goto :fail_pause
    )
    echo [OK] Instalacion continuada en la ventana de Administrador.
    goto :end_ok
)

echo [*] Instalando WSL2 y %DISTRO_NAME% ^(puede tardar varios minutos^)...
"%WSL_BIN%" --install -d %DISTRO_NAME% --no-launch
set "INSTALL_EC=%ERRORLEVEL%"

if "%INSTALL_EC%"=="3010" goto :wsl_needs_reboot
if "%INSTALL_EC%"=="0" goto :wsl_post_install

echo [AVISO] La instalacion via Microsoft Store devolvio codigo %INSTALL_EC%.
echo [*] Reintentando descarga directa desde internet ^(--web-download^)...
"%WSL_BIN%" --install -d %DISTRO_NAME% --web-download --no-launch
set "INSTALL_EC=%ERRORLEVEL%"

if "%INSTALL_EC%"=="3010" goto :wsl_needs_reboot
if "%INSTALL_EC%"=="0" goto :wsl_post_install

echo [AVISO] Reintentando sintaxis clasica de instalacion WSL...
"%WSL_BIN%" --install -d %DISTRO_NAME%
set "INSTALL_EC=%ERRORLEVEL%"
if "%INSTALL_EC%"=="3010" goto :wsl_needs_reboot

:wsl_post_install
:: Comprobar si tras la instalacion ya figura kali-linux en WSL
call :check_kali_wsl
if "%KALI_WSL_INSTALLED%"=="1" goto :wsl_installed_ok

if "%INSTALL_EC%"=="0" goto :wsl_needs_reboot
echo.
echo [ERROR] No se pudo completar el registro de %DISTRO_NAME% ^(codigo %INSTALL_EC%^).
echo         Causas habituales:
echo           1. Falta reiniciar Windows para activar WSL2 / VirtualMachinePlatform.
echo           2. La virtualizacion ^(VT-x / AMD-V^) esta desactivada en la BIOS/UEFI.
echo           3. Sin conexion a internet o firewall bloqueando la descarga.
echo.
echo         Reinicia el equipo una vez y vuelve a ejecutar "%SCRIPT_NAME%".
goto :fail_pause

:wsl_installed_ok

echo.
echo [OK] %DISTRO_NAME% registrado en WSL2.
echo      Si es la primera vez, Kali te pedira crear un usuario y contrasena Linux.
if /i not "%PROFILE%"=="minimal" echo      Despues de crear el usuario, ejecuta "%SCRIPT_NAME% --tools --profile %PROFILE%".
goto :wsl_exec_shell

:wsl_needs_reboot
echo.
echo ========================================================================
echo   REINICIO NECESARIO PARA TERMINAR WSL2
echo ========================================================================
echo   Windows activo/actualizo los componentes de WSL2 ^(VirtualMachinePlatform^).
echo.
echo   Siguientes pasos:
echo     1. Guarda tu trabajo y REINICIA Windows ahora.
echo     2. Despues de reiniciar, vuelve a abrir este mismo archivo ^("%SCRIPT_NAME%"^).
echo     3. Crea tu usuario y contrasena de Kali cuando aparezca el asistente.
echo ========================================================================
echo.
goto :fail_pause

:wsl_launch
if not defined WSL_BIN (
    echo [ERROR] No se encontro wsl.exe.
    goto :fail_pause
)

if "%PROFILE%"=="minimal" goto :wsl_exec_shell

:: Si el usuario paso --profile top10|headless|default desde CLI junto con --wsl
call :resolve_apt_package "%PROFILE%"
if defined APT_PKG (
    if "%DRY_RUN%"=="1" (
        echo [DRY-RUN] Instalaria metapaquete en WSL: %APT_PKG%
    ) else (
        echo [*] Comprobando/instalando perfil "%PROFILE%" ^(%APT_PKG%^)...
        "%WSL_BIN%" -d %DISTRO_NAME% -- bash -lc "sudo env DEBIAN_FRONTEND=noninteractive apt-get update && sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y %APT_PKG%"
        if errorlevel 1 (
            echo [AVISO] No se pudo instalar %APT_PKG% automaticamente ^(si aun no creaste usuario Kali, abre Kali primero^).
        )
    )
)

:wsl_exec_shell
if "%DRY_RUN%"=="1" (
    if "%NEW_TAB%"=="1" (
        echo [DRY-RUN] Abriria nueva pestana en Windows Terminal con WSL %DISTRO_NAME%.
    ) else if "%HERE_MODE%"=="1" (
        echo [DRY-RUN] Ejecutaria: "%WSL_BIN%" -d %DISTRO_NAME% --cd "%WORK_DIR%"
    ) else (
        echo [DRY-RUN] Ejecutaria: "%WSL_BIN%" -d %DISTRO_NAME% --cd ~
    )
    goto :end_ok
)

if "%NEW_TAB%"=="1" (
    if defined WT_BIN (
        if "%HERE_MODE%"=="1" (
            start "" "%WT_BIN%" -w 0 nt --title "Kali Linux" -d "%WORK_DIR%" "%WSL_BIN%" -d %DISTRO_NAME%
        ) else (
            start "" "%WT_BIN%" -w 0 nt --title "Kali Linux" "%WSL_BIN%" -d %DISTRO_NAME% --cd ~
        )
        echo [OK] Kali Linux abierto en una nueva pestana de Windows Terminal.
        goto :end_ok
    ) else (
        echo [AVISO] Windows Terminal ^(wt.exe^) no encontrado; abriendo en esta consola.
    )
)

if "%HERE_MODE%"=="1" (
    "%WSL_BIN%" -d %DISTRO_NAME% --cd "%WORK_DIR%"
) else (
    "%WSL_BIN%" -d %DISTRO_NAME% --cd ~
)
set "RUN_EC=%ERRORLEVEL%"

if not "%RUN_EC%"=="0" (
    echo.
    echo [ERROR] No se pudo iniciar %DISTRO_NAME% ^(codigo %RUN_EC%^).
    echo         Si acabas de instalar WSL2, REINICIA Windows e intentalo de nuevo.
    echo         Tambien verifica que VT-x / AMD-V ^(Virtualizacion^) este activado en BIOS.
    goto :fail_pause
)

if "%ELEVATED%"=="1" (
    echo.
    echo [*] Sesion de Kali cerrada.
    pause
)
goto :end_ok

:: ============================================================================
:: INSTALACION DE HERRAMIENTAS EN KALI WSL
:: ============================================================================
:wsl_tools_flow
if not "%KALI_WSL_INSTALLED%"=="1" (
    echo [ERROR] %DISTRO_NAME% aun no esta instalado en WSL2.
    echo         Ejecuta primero "%SCRIPT_NAME% --wsl" para instalarlo y crear tu usuario Linux.
    goto :fail_pause
)

if /i not "%PROFILE%"=="minimal" goto :wsl_tools_ready
echo.
echo   Elige el paquete de herramientas a instalar en Kali ^(WSL2^):
echo     [1] kali-tools-top10     ^(nmap, sqlmap, hydra, john, metasploit, etc.^)
echo     [2] kali-linux-headless  ^(suite Kali completa para terminal^)
echo     [3] kali-linux-default   ^(herramientas estandar de Kali^)
echo     [4] Cancelar
echo.
set "CHOICE="
set /p "CHOICE=Elige una opcion [1-4]: "
call :clean_choice
if "%CHOICE%"=="1" set "PROFILE=top10"
if "%CHOICE%"=="2" set "PROFILE=headless"
if "%CHOICE%"=="3" set "PROFILE=default"
if "%CHOICE%"=="4" goto :end_ok

:wsl_tools_ready
call :resolve_apt_package "%PROFILE%"
if not defined APT_PKG (
    echo [ERROR] No se selecciono ningun metapaquete valido.
    goto :fail_pause
)

if "%DRY_RUN%"=="1" (
    echo [DRY-RUN] Ejecutaria en %DISTRO_NAME%: sudo apt-get update ^&^& sudo apt-get install -y %APT_PKG%
    goto :end_ok
)

echo [*] Actualizando repositorios e instalando %APT_PKG% en %DISTRO_NAME%...
echo     ^(Si Kali te pide tu contrasena de Linux, introducela para sudo^)
"%WSL_BIN%" -d %DISTRO_NAME% -- bash -lc "sudo env DEBIAN_FRONTEND=noninteractive apt-get update && sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y %APT_PKG%"
if errorlevel 1 (
    echo [ERROR] Fallo la instalacion de %APT_PKG%.
    echo         Si aun no habias abierto Kali nunca, entra primero para crear tu usuario/contrasena.
    goto :fail_pause
)

echo [OK] %APT_PKG% instalado. Abriendo Kali...
goto :wsl_exec_shell

:: ============================================================================
:: FLUJO DOCKER
:: ============================================================================
:docker_flow
if "%DRY_RUN%"=="1" (
    echo [DRY-RUN] Comprobando Docker daemon y desplegando %IMAGE_NAME%
    echo [DRY-RUN] Workspace: "%WORK_DIR%" -^> /workspace
    echo [DRY-RUN] Contenedor: %CONTAINER_NAME% ^(Ephemeral=%EPHEMERAL%, HostNet=%HOST_NET%, Profile=%PROFILE%^)
    goto :end_ok
)

if not defined DOCKER_BIN (
    echo [ERROR] No se encontro docker.exe en este equipo.
    echo         Instala Docker Desktop ^(ej. winget install Docker.DockerDesktop^)
    echo         o usa el modo WSL2 con: "%SCRIPT_NAME% --wsl"
    goto :fail_pause
)

"%DOCKER_BIN%" info >nul 2>&1
if errorlevel 1 (
    call :start_docker_desktop
    if errorlevel 1 goto :fail_pause
)

call :resolve_apt_package "%PROFILE%"
set "NET_ARG="
if "%HOST_NET%"=="1" set "NET_ARG=--network host"

set "INIT_CMD=bash"
if defined APT_PKG (
    set "INIT_CMD=apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y %APT_PKG% && exec bash"
)

if "%EPHEMERAL%"=="1" (
    echo [*] Iniciando contenedor Kali efimero ^(%IMAGE_NAME%^)...
    echo     Carpeta compartida: "%WORK_DIR%" -^> /workspace
    if defined APT_PKG (
        "%DOCKER_BIN%" run --rm -it %NET_ARG% -v "%WORK_DIR%:/workspace" -w /workspace %IMAGE_NAME% bash -lc "%INIT_CMD%"
    ) else (
        "%DOCKER_BIN%" run --rm -it %NET_ARG% -v "%WORK_DIR%:/workspace" -w /workspace %IMAGE_NAME% bash
    )
    if errorlevel 1 goto :fail_pause
    goto :end_ok
)

:: Contenedor persistente: comprobar estado actual
set "DOCKER_RUNNING="
for /f "usebackq delims=" %%S in (`call "%DOCKER_BIN%" inspect -f "{{.State.Running}}" "%CONTAINER_NAME%" 2^>nul`) do (
    set "DOCKER_RUNNING=%%S"
)

if /i "%DOCKER_RUNNING%"=="true" (
    echo [*] Contenedor "%CONTAINER_NAME%" ya en ejecucion. Conectando shell...
    "%DOCKER_BIN%" exec -it "%CONTAINER_NAME%" bash
    if errorlevel 1 goto :fail_pause
    goto :end_ok
)

if /i "%DOCKER_RUNNING%"=="false" (
    echo [*] Reanudando contenedor persistente "%CONTAINER_NAME%"...
    "%DOCKER_BIN%" start -ai "%CONTAINER_NAME%"
    if errorlevel 1 goto :fail_pause
    goto :end_ok
)

echo [*] Creando contenedor persistente "%CONTAINER_NAME%" desde %IMAGE_NAME%...
echo     Carpeta compartida: "%WORK_DIR%" -^> /workspace
if defined APT_PKG (
    "%DOCKER_BIN%" run -it --name "%CONTAINER_NAME%" %NET_ARG% -v "%WORK_DIR%:/workspace" -w /workspace %IMAGE_NAME% bash -lc "%INIT_CMD%"
) else (
    "%DOCKER_BIN%" run -it --name "%CONTAINER_NAME%" %NET_ARG% -v "%WORK_DIR%:/workspace" -w /workspace %IMAGE_NAME% bash
)
if errorlevel 1 goto :fail_pause
goto :end_ok

:: ============================================================================
:: SUBRUTINAS AUXILIARES
:: ============================================================================
:detect_tools
set "WSL_BIN="
for /f "usebackq delims=" %%P in (`where wsl.exe 2^>nul`) do (
    if not defined WSL_BIN set "WSL_BIN=%%P"
)
if not defined WSL_BIN if exist "%SystemRoot%\System32\wsl.exe" set "WSL_BIN=%SystemRoot%\System32\wsl.exe"
if not defined WSL_BIN if exist "%SystemRoot%\Sysnative\wsl.exe" set "WSL_BIN=%SystemRoot%\Sysnative\wsl.exe"

set "DOCKER_BIN="
for /f "usebackq delims=" %%P in (`where docker.exe 2^>nul`) do (
    if not defined DOCKER_BIN set "DOCKER_BIN=%%P"
)

set "WT_BIN="
for /f "usebackq delims=" %%P in (`where wt.exe 2^>nul`) do (
    if not defined WT_BIN set "WT_BIN=%%P"
)

call :check_kali_wsl
exit /b 0

:check_kali_wsl
set "KALI_WSL_INSTALLED=0"
if not defined WSL_BIN exit /b 0
for /f "usebackq delims=" %%D in (`call "%WSL_BIN%" -l -q 2^>nul`) do (
    if /i "%%D"=="%DISTRO_NAME%" set "KALI_WSL_INSTALLED=1"
)
exit /b 0

:sanitize_workdir
if /i "%WORK_DIR%"=="%SystemRoot%\System32" set "WORK_DIR=%USERPROFILE%"
if /i "%WORK_DIR%"=="%SystemRoot%\SysWOW64" set "WORK_DIR=%USERPROFILE%"
if "%WORK_DIR:~-1%"=="\" if not "%WORK_DIR:~-2%"==":\" set "WORK_DIR=%WORK_DIR:~0,-1%"
exit /b 0

:validate_profile
if /i "%PROFILE%"=="minimal" exit /b 0
if /i "%PROFILE%"=="top10" exit /b 0
if /i "%PROFILE%"=="headless" exit /b 0
if /i "%PROFILE%"=="default" exit /b 0
echo [ERROR] Perfil no valido: "%PROFILE%". Usa minimal, top10, headless o default.
exit /b 1

:resolve_apt_package
set "APT_PKG="
if /i "%~1"=="top10" set "APT_PKG=kali-tools-top10"
if /i "%~1"=="headless" set "APT_PKG=kali-linux-headless"
if /i "%~1"=="default" set "APT_PKG=kali-linux-default"
exit /b 0

:clean_choice
if not defined CHOICE exit /b 0
set "CHOICE=%CHOICE:"=%"
set "CHOICE=%CHOICE: =%"
exit /b 0

:elevate_self
set "__KALI_BAT=%SCRIPT_PATH%"
set "__KALI_WS=%WORK_DIR%"
set "__KALI_PROF=%PROFILE%"
set "__KALI_HERE=%HERE_MODE%"
set "__KALI_TAB=%NEW_TAB%"
powershell.exe -NoProfile -Command "$q=[char]34; $cmd='/c call ' + $q + $env:__KALI_BAT + $q + ' --wsl --elevated --profile ' + $env:__KALI_PROF; if ($env:__KALI_HERE -eq '1') { $cmd += ' --workdir ' + $q + $env:__KALI_WS + $q }; if ($env:__KALI_TAB -eq '1') { $cmd += ' --new-tab' }; Start-Process -FilePath $env:ComSpec -ArgumentList $cmd -Verb RunAs"
exit /b %ERRORLEVEL%

:start_docker_desktop
set "DD_EXE="
if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" set "DD_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
if not defined DD_EXE if exist "%LocalAppData%\Programs\Docker\Docker\Docker Desktop.exe" set "DD_EXE=%LocalAppData%\Programs\Docker\Docker\Docker Desktop.exe"

if not defined DD_EXE (
    echo [ERROR] El demonio de Docker no esta activo y no se encontro Docker Desktop.
    echo         Abre Docker Desktop manualmente y vuelve a ejecutar este script.
    exit /b 1
)

echo [*] Docker no esta activo. Iniciando Docker Desktop...
start "" "%DD_EXE%"

set /a "WAIT_COUNT=0"
:docker_wait_loop
"%DOCKER_BIN%" info >nul 2>&1
if not errorlevel 1 (
    echo [OK] Docker Desktop listo.
    exit /b 0
)
set /a "WAIT_COUNT+=1"
if %WAIT_COUNT% geq 30 (
    echo [ERROR] Tiempo de espera agotado ^(90s^) esperando a Docker Desktop.
    exit /b 1
)
timeout /t 3 /nobreak >nul
goto :docker_wait_loop

:show_help
echo.
echo Uso: %SCRIPT_NAME% [opciones]
echo.
echo Si se ejecuta sin argumentos ^(doble clic^):
echo   - Si Kali WSL2 ya esta instalado, abre la terminal de Kali directamente.
echo   - Si no esta instalado, muestra un asistente para instalar WSL2 o usar Docker.
echo.
echo Opciones:
echo   --wsl                 Usar / instalar Kali Linux en WSL2
echo   --docker              Usar Kali Linux en Docker Desktop
echo   --ephemeral           ^(Docker^) Contenedor temporal --rm que se borra al salir
echo   --host-net            ^(Docker^) Usar --network host
echo   --container ^<nombre^>  ^(Docker^) Nombre del contenedor persistente ^(def: kali-lab^)
echo   --profile ^<perfil^>    minimal ^(def^), top10, headless, default
echo   --tools               Instalar herramientas en Kali WSL2 existente
echo   --new-tab             Abrir Kali WSL en nueva pestana de Windows Terminal
echo   --here                Abrir WSL en la carpeta actual de Windows ^(en vez de ~^)
echo   --workdir ^<ruta^>      Carpeta Windows a compartir / abrir
echo   --menu                Mostrar menu interactivo aunque Kali ya este instalado
echo   --dry-run             Mostrar acciones sin modificar WSL ni Docker
echo   -h, --help            Mostrar esta ayuda
echo.
goto :end_ok

:fail_pause
echo.
pause
if defined ORIGINAL_CP chcp %ORIGINAL_CP% >nul
endlocal
exit /b 1

:end_ok
if defined ORIGINAL_CP chcp %ORIGINAL_CP% >nul
endlocal
exit /b 0
