@echo off
:: Initialize cosmosv5 submodules for a specific layer.
:: Usage: setup.bat [kernel|micro-agent|simulator|agent|modules|ground-station|all]
:: Default: agent

set LAYER=%~1
if "%LAYER%"=="" set LAYER=agent

set MODULES=
if "%LAYER%"=="kernel"         set MODULES=kernel
if "%LAYER%"=="micro-agent"    set MODULES=kernel micro-agent
if "%LAYER%"=="simulator"      set MODULES=kernel micro-agent simulator
if "%LAYER%"=="agent"          set MODULES=kernel micro-agent simulator agent
if "%LAYER%"=="modules"        set MODULES=thirdparty kernel micro-agent simulator agent modules
if "%LAYER%"=="ground-station" set MODULES=thirdparty kernel micro-agent simulator agent modules ground-station
if "%LAYER%"=="all"            set MODULES=thirdparty kernel micro-agent simulator agent modules ground-station

if "%MODULES%"=="" (
    echo Usage: setup.bat [kernel^|micro-agent^|simulator^|agent^|modules^|ground-station^|all]
    echo.
    echo   kernel          -- math, time, JSON, serial
    echo   micro-agent     -- adds networking, file transfer, hardware drivers
    echo   simulator       -- adds orbital mechanics
    echo   agent           -- full COSMOS: agents, physics, propagation  [default]
    echo   modules         -- adds pluggable modules
    echo   ground-station  -- adds ground station hardware and agents
    echo   all             -- everything, including physics resource files
    exit /b 1
)

echo Initializing submodules for layer: %LAYER%
git submodule update --init %MODULES%

:: resources is marked update=none in .gitmodules to prevent accidental pulls.
:: Override that setting explicitly when the user requests 'all'.
if "%LAYER%"=="all" (
    echo Initializing resources submodule...
    git -c submodule.resources.update=checkout submodule update --init resources
)

echo Done.
