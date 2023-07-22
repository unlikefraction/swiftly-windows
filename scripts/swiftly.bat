@echo off
REM Disable echo

REM Check if the first argument is 'init', 'makeapp', 'run', 'install', 'uninstall', or 'push'
IF NOT "%~1"=="init" IF NOT "%~1"=="makeapp" IF NOT "%~1"=="run" IF NOT "%~1"=="install" IF NOT "%~1"=="uninstall" IF NOT "%~1"=="push" (
    echo Invalid command.
    exit /b
)

REM Check if required commands exist
where /q pip
IF ERRORLEVEL 1 (
    echo pip is not available.
    exit /b
)
where /q python
IF ERRORLEVEL 1 (
    echo python is not available.
    exit /b
)

IF "%~1"=="init" (
    REM Call the init function with the second argument as a parameter
    call:init "%~2"
    goto :eof
)

IF "%~1"=="makeapp" (
    REM Call the makeapp function with the second argument as a parameter
    call:makeapp "%~2"
    goto :eof
)

IF "%~1"=="run" (
    REM Call the run function with the second argument as a parameter
    call:run "%~2"
    goto :eof
)

IF "%~1"=="install" (
    REM Call the install function with all the rest arguments as a parameter
    call:install %*:~2
    goto :eof
)

IF "%~1"=="uninstall" (
    REM Call the uninstall function with all the rest arguments as a parameter
    call:uninstall %*:~2
    goto :eof
)

IF "%~1"=="push" (
    REM Call the push function with all the rest arguments as a parameter
    call:push %*:~2
    goto :eof
)

:init
    echo Initiating project
    REM Call pip install
    call pip install swiftly-windows --upgrade > NUL

    REM Check if parameter is empty
    IF "%~1"=="" (
        REM The commands in this block will execute if the parameter is empty
        call:init_no_param
    ) ELSE (
        REM The commands in this block will execute if the parameter is not empty
        call:init_with_param "%~1"
    )
    goto :eof

:init_no_param
    call git fetch > NUL 2>&1
    for /f "delims=" %%a in ('git status -uno') do set "git_status=%%a"
    for /f "delims=" %%a in ('python -c "from swiftly_windows.init import pull_changes; print(pull_changes('%git_status%'))"') do set "pull_changes=%%a"
    IF "%pull_changes%"=="True" (
        call git pull > NUL
        echo git changes pulled
    ) ELSE (
        echo git up to date
    )

    for /f "delims=" %%a in ('python -c "from swiftly_windows.init import get_project_name; print(get_project_name())"') do set "PROJECT_NAME=%%a"
    echo  Project '%PROJECT_NAME%' ready
    for /f "delims=" %%a in ('python -c "from swiftly_windows.init import get_venv_location; print(get_venv_location())"') do set "venv_location=%%a"
    call %venv_location%\Scripts\activate.bat

    set PROJECT_VENV_LOCATION=%venv_location%

    call python.exe -m pip install --upgrade pip
    call pip install swiftly-windows --upgrade > NUL 2>&1
    echo  Virtual environment activated
    for /f "delims=" %%a in ('pip freeze') do set "available_packages=%%a"
    for /f "delims=" %%a in ('python -c "from swiftly_windows.init import check_new_packages; print(check_new_packages(\'\'\'%available_packages%\'\'\'))"') do set "new_packages=%%a"
    IF "%new_packages%"=="True" (
        call pip install -r requirements.txt > NUL
        echo  New packages installed
    ) ELSE (
        echo  All packages already installed
    )
    pip freeze > %PROJECT_VENV_LOCATION%\..\requirements.txt
    echo  All checks completed swiftly
    echo ☆ Project '%PROJECT_NAME%' initiated successfully ☺
    goto :eof

:init_with_param
    call python.exe -m pip install --upgrade pip > NUL 2>&1
    call pip install swiftly-windows --upgrade > NUL 2>&1
    for /f "delims=" %%a in ('python -c "from swiftly_windows.init import is_repo; print(is_repo('%~1'))"') do set "is_github_repo=%%a" > NUL 2>&1
    IF "%is_github_repo%"=="True" (
        for /f "delims=" %%a in ('git clone %~1 2^>^&1') do set "git_clone=%%a"
        for /f "delims=" %%a in ('python -c "from swiftly_windows.init import clone_successful; print(clone_successful(\'\'\'%git_clone%\'\'\'))"') do set "clone_successful=%%a"
        IF "%clone_successful%"=="True" (
            echo  Git repository cloned
        ) ELSE (
            echo  %clone_successful% fail
            echo Do you want to create a new project? (y/n)
            set /p user_input="> "
            set user_input=%user_input:~0,1%
            IF /I NOT "%user_input%"=="y" (
                exit /b 1
            )
        )
    )
    for /f "delims=" %%a in ('python -c "from swiftly_windows.init import initialise; print(initialise('%~1'))"') do set "venv_location=%%a"
    call %venv_location%\Scripts\activate
    set "PROJECT_VENV_LOCATION=%venv_location%"
    cd %PROJECT_VENV_LOCATION%
    cd ..
    for /f "delims=" %%a in ('python -c "from swiftly_windows.init import get_project_name; print(get_project_name())"') do set "project_name=%%a"
    set "PROJECT_NAME=%project_name%"
    echo  Project '%PROJECT_NAME%' ready

    call python.exe -m pip install --upgrade pip > NUL 2>&1

    call pip install -r requirements.txt > NUL
    echo Requirements installed
    call pip install swiftly-windows --upgrade > NUL 2>&1
    pip freeze > %PROJECT_VENV_LOCATION%\..\requirements.txt
    echo  All checks completed swiftly
    echo ☆ Project '%PROJECT_NAME%' initiated successfully ☺
    goto :eof

:makeapp
    REM Call Python function with arguments
    python -c "from swiftly_windows.makeapp import makeapp; makeapp('%~1', r'%PROJECT_VENV_LOCATION%')" > NUL
    TIMEOUT /T 1 /NOBREAK > NUL
    echo ✓ App '%~1' created successfully
    goto :eof

:run
    for /f %%i in ('python -c "from swiftly_windows.runapp import run_app; print(run_app('%~1', r'%PROJECT_NAME%'))"') do set script_path=%%i
    python -m %script_path%
    goto :eof

:install
    setlocal EnableDelayedExpansion
    set "params="
    for %%a in (%*) do (
        for /f "delims=: tokens=1" %%b in ("%%~a") do (
            set "params=%params% %%b"
        )
    )
    pip install %params%
    pip freeze > %PROJECT_VENV_LOCATION%\..\requirements.txt
    endlocal
    goto :eof

:uninstall
    setlocal EnableDelayedExpansion
    set "params="
    for %%a in (%*) do (
        for /f "delims=: tokens=1" %%b in ("%%~a") do (
            set "params=%params% %%b"
        )
    )
    pip uninstall %params%
    pip freeze > %PROJECT_VENV_LOCATION%\..\requirements.txt
    endlocal
    goto :eof

:push
    git add *
    git commit -m "%*"
    git push
    goto :eof
