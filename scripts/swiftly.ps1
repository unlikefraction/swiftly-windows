function Spin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $chars = @('🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘')
    $i = 0

    while ($true) {
        Write-Host "`b$($chars[$i]) $Message" -NoNewline
        Start-Sleep -Milliseconds 200
        $i = ($i + 1) % $chars.Length
    }
}

function Start-Spin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $Job = Start-Job -ScriptBlock ${function:Spin} -ArgumentList $Message
    return $Job
}

function Stop-Spin {
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Job]$Job,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Status = "success"
    )

    Stop-Job -Job $Job
    Remove-Job -Job $Job

    if ($Status -eq "fail") {
        Write-Host "`r`n✗ $Message"
    } else {
        Write-Host "`r`n✓ $Message"
    }
}

function Handle-Interrupt {
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.Job]$Job
    )

    Stop-Spin -Job $Job -Message "Interrupted" -Status "fail"
    exit 1
}

function Init {
    param(
        [string]$ProjectName
    )

    $Job = Start-Spin -Message "Checking swiftly"
    pip install swiftly-windows --upgrade | Out-Null
    Stop-Spin -Job $Job -Message "Checked swiftly"

    if ([string]::IsNullOrEmpty($ProjectName)) {
        $Job = Start-Spin -Message "Checking remote origin for changes"
        git fetch | Out-Null
        $gitStatus = git status -uno | Out-String

        $pullChanges = python -c "from swiftly_windows.init import pull_changes; print(pull_changes('$gitStatus'))"
        if ($pullChanges -eq "True") {
            git pull | Out-Null
            Stop-Spin -Job $Job -Message "Remote changes pulled"
        } else {
            Stop-Spin -Job $Job -Message "Codebase up-to-date"
        }

        $Job = Start-Spin -Message "Checking your project"
        $projectName = python -c "from swiftly_windows.init import get_project_name; print(get_project_name())"
        $env:PROJECT_NAME = $projectName
        Stop-Spin -Job $Job -Message "Project '$env:PROJECT_NAME' ready"

        $Job = Start-Spin -Message "Activating virtual environment"
        $venvLocation = python -c "from swiftly_windows.init import get_venv_location; print(get_venv_location())"
        # PowerShell doesn't have a built-in way to source scripts, so we'll use this workaround to activate the virtual environment
        cmd /c "$venvLocation\Scripts\activate.bat"
        $env:PROJECT_VENV_LOCATION = $venvLocation

        pip install swiftly-windows --upgrade | Out-Null
        Stop-Spin -Job $Job -Message "Virtual environment activated"

        $Job = Start-Spin -Message "Checking for new packages"
        $availablePackages = pip freeze | Out-String
        $newPackages = python -c "from swiftly_windows.init import check_new_packages; print(check_new_packages('$availablePackages'))"

        if ($newPackages -eq "True") {
            pip install -r requirements.txt | Out-Null
            Stop-Spin -Job $Job -Message "New packages installed"
        } else {
            Stop-Spin -Job $Job -Message "All packages already installed"
        }

        $Job = Start-Spin -Message "Checking swiftly"
        pip install --upgrade pip | Out-Null
        pip install swiftly-windows --upgrade | Out-Null
        Stop-Spin -Job $Job -Message "All checks completed swiftly"
    } else {
        $isGithubRepo = python -c "from swiftly_windows.init import is_repo; print(is_repo('$ProjectName'))"
        if ($isGithubRepo -eq "True") {
            $Job = Start-Spin -Message "Cloning git repository"
            $gitClone = git clone $ProjectName 2>&1 | Out-String

            $cloneSuccessful = python -c "from swiftly_windows.init import clone_successful; print(clone_successful('$gitClone'))"

            if ($cloneSuccessful -eq "True") {
                Stop-Spin -Job $Job -Message "Git repository cloned"
            } else {
                Stop-Spin -Job $Job -Message "$cloneSuccessful" -Status "fail"
                Write-Host "Do you want to create a new project? (y/n)"
                $userInput = Read-Host
                if ($userInput.ToLower().Substring(0, 1) -ne "y") {
                    return
                }
            }
        }

        $Job = Start-Spin -Message "Creating project $ProjectName"
        $venvLocation = python -c "from swiftly_windows.init import initialise; print(initialise('$ProjectName'))"
        cmd /c "$venvLocation\Scripts\activate.bat"
        $env:PROJECT_VENV_LOCATION = $venvLocation

        Set-Location -Path $venvLocation
        Set-Location -Path ..

        pip install swiftly-windows --upgrade | Out-Null

        $projectName = python -c "from swiftly_windows.init import get_project_name; print(get_project_name())"
        $env:PROJECT_NAME = $projectName

        Stop-Spin -Job $Job -Message "Project '$env:PROJECT_NAME' ready"

        $Job = Start-Spin -Message "Installing requirements"
        pip install --upgrade pip | Out-Null

        pip install -r requirements.txt | Out-Null
        Stop-Spin -Job $Job -Message "Requirements installed"

        $Job = Start-Spin -Message "Checking swiftly"
        pip install swiftly-windows --upgrade | Out-Null
        Stop-Spin -Job $Job -Message "All checks completed swiftly"
    }

    Write-Host "✨ Project '$env:PROJECT_NAME' initiated successfully :)"
}


function MakeApp {
    param(
        [string]$AppName
    )

    python -c "from swiftly_windows.makeapp import makeapp; makeapp('$AppName', '$env:PROJECT_VENV_LOCATION')"
    Start-Sleep -Seconds 1
    Write-Host "`e[32m✓`e[0m App '$AppName' created successfully"
}

function Run {
    param(
        [string]$AppName
    )

    $path = python -c "from swiftly_windows.runapp import run_app; print(run_app('$AppName', '$env:PROJECT_NAME'))"
    Write-Host $path
    python -m $path
}

function Install {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Packages
    )

    foreach ($Package in $Packages) {
        pip install $Package
    }

    $updatedPackages = pip freeze
    $requirementsPath = Join-Path -Path $env:PROJECT_VENV_LOCATION -ChildPath "..\requirements.txt"
    Set-Content -Path $requirementsPath -Value $updatedPackages
}


function Uninstall {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Packages
    )

    foreach ($Package in $Packages) {
        pip uninstall -y $Package
    }

    $updatedPackages = pip freeze
    $requirementsPath = Join-Path -Path $env:PROJECT_VENV_LOCATION -ChildPath "..\requirements.txt"
    Set-Content -Path $requirementsPath -Value $updatedPackages
}


function Push {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$CommitMessage
    )

    $CommitMessage = $CommitMessage | Select-Object -Skip 1
    $CommitMessage = $CommitMessage -join " "

    git add *
    git commit -m $CommitMessage
    git push
}



if ($args.Length -eq 0) {
    Write-Host "No command provided"
    exit 1
}

$command = $args[0]
$argument = $args[1]

if ($command -eq "init") {
    Init -ProjectName $argument
} elseif ($command -eq "makeapp") {
    MakeApp -AppName $argument
} elseif ($command -eq "run") {
    Run -AppName $argument
} elseif ($command -eq "install") {
    Install $args[1..($args.Length - 1)]
} elseif ($command -eq "uninstall") {
    Uninstall $args[1..($args.Length - 1)]
} elseif ($command -eq "push") {
    Push -Message $argument
} else {
    Write-Host "Invalid command: $command"
    exit 1
}
