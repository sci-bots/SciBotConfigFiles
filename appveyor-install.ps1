Set-PSDebug -Trace 1
# Batch file for AppVeyor install step
# Requires MINICONDA and PROJECT_NAME environment variables

# Add Conda to path
$env:PATH = $env:MINICONDA + ";" + $env:PATH;
$env:PATH = $env:MINICONDA + "\\Scripts;" + $env:PATH;
Write-Host $env:PATH

# Configure Conda to operate without user input
conda config --set always_yes yes --set changeps1 no

# Add the conda-force, and wheeler-microfluidics channels
conda config --add channels conda-forge
conda config --add channels wheeler-microfluidics

# Update conda, and install conda-build (used for building in non-root env)
conda update -q conda
conda install --yes conda-build anaconda-client nose

# Create and activate new NadaMq environment
conda create --name $env:APPVEYOR_PROJECT_NAME
activate $env:APPVEYOR_PROJECT_NAME
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

# Add src_dir to path (to re-activate the build environment)
$env:path = "$($src_dir)\_b_env;$($src_dir)\_b_env\Scripts;$($env:path)"

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
Write-Host "Building Package: $($package_location)"
conda build .
if (!$?) {$build_status = "Failed Conda Tests Stage"}

# Capture package location and build status
touch BUILD_STATUS
touch PACKAGE_LOCATION
echo $build_status > BUILD_STATUS
echo $package_location > PACKAGE_LOCATION
