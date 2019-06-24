Set-PSDebug -Trace 1
Set-ExecutionPolicy RemoteSigned

# Set version number:
$x = git describe --tags
if (!$?){ $prevTag="v0.0-0"
} else  { $prevTag = $x.Split("-")[0] + "-" + $x.Split("-")[1] }

$buildTag = $prevTag + "+" + $(Get-Date -Format FileDateTime)
Write-Host "Build Tag: $buildTag"
Update-AppveyorBuild -Version $buildTag

# Batch file for AppVeyor install step
# Requires MINICONDA and PROJECT_NAME environment variables

# Configure Conda to operate without user input
& $env:MINICONDA\Scripts\conda.exe config --set always_yes yes --set changeps1 no

Write-Host "Update conda"
& $env:MINICONDA\Scripts\conda.exe install -q "conda>=4.6.11"

Write-Host "Initialize Conda Powershell support and activate base environment."
(& $env:MINICONDA\Scripts\conda.exe "shell.powershell" "hook") | Out-String | Invoke-Expression

# Allow extra Conda channels to be added (e.g., for testing).
if ($env:CONDA_EXTRA_CHANNELS) {
    $env:CONDA_EXTRA_CHANNELS.Split(";") | ForEach {
        Write-Host "Adding Conda channel from %CONDA_EXTRA_CHANNELS%: $_"
        conda config --add channels $_
    }
}

# Update conda, and install conda-build (used for building in non-root env)
conda update -q conda
conda install --yes conda-build anaconda-client nose

# Create and activate new environment
conda create --name $env:APPVEYOR_PROJECT_NAME python
conda activate $env:APPVEYOR_PROJECT_NAME
$build_status = "Success"

# Check for issues in meta yaml file:
if (!$(conda build . --output)){
  $msg = "Failed to get package info";
  $details = "check for issues in conda-recipes meta.yaml file";
  Add-AppveyorMessage -Message $msg -Category Error -Details $details
  throw $msg
}

# Set environment variable for project directory (may be used in bld.bat)
$env:project_directory = (Get-Item -Path ".\" -Verbose).FullName
Write-Host "Project directory: $($env:project_directory)"

# Build Package (skip testing stage)
conda build . --build-only --dirty
if (!$?) { $build_status = "Failed Conda Build Stage" }
$src_dir = $(ls $("$($env:MINICONDA)\\conda-bld") *$($env:APPVEYOR_PROJECT_NAME)* -Directory)[0].FullName
if (!$src_dir) { 
  $msg = "Cannot find src_dir: the project name may not match conda name."
  $details = "This will cause nosetests to fail."
  Add-AppveyorMessage -Message $msg -Category Error -Details $details
}

Write-Host "SRC Directory: $($src_dir)"

# Activate the environment contained by the source directory
conda activate $($src_dir)\_b_env
# $build_env = "$($src_dir)\_b_env;$($src_dir)\_b_env\Scripts"
# $env:path = "$($build_env);$($env:path)"

# Show python location (ensure its in _b_env)
Write-Host "Build Environment: "
Write-Host $build_env
Write-Host "Python Location: "
where.exe python

# Move back to project directory
cd $env:project_directory

# Run nosetests, and check if any tests failed
nosetests $src_dir\\work -vv --with-xunit
if (!$?) {$build_status = "Failed Nosetests"}

# Delete working environment
conda build purge

# Build package again without skipping tests
Write-Host "Getting package location:"
$package_location = conda build . --output
Write-Host "Building Package: $package_location"
conda build .
if (!$?) {$build_status = "Failed Conda Tests Stage"}

# Capture package location and build status
touch BUILD_STATUS
touch PACKAGE_LOCATION
echo $build_status > BUILD_STATUS
echo $package_location > PACKAGE_LOCATION
