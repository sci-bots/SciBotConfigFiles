Set-PSDebug -Trace 1
# Batch file for AppVeyor install step
# Requires MINICONDA and PROJECT_NAME environment variables

# Add Conda to path
$env:PATH = $env:MINICONDA + ";" + $env:PATH;
$env:PATH = $env:MINICONDA + "\\Scripts;" + $env:PATH;

# Configure Conda to operate without user input
conda config --set always_yes yes --set changeps1 no

# Add the conda-force, and wheeler-microfluidics channels
conda config --add channels conda-forge
conda config --add channels wheeler-microfluidics

# Update conda, and install conda-build (used for building in non-root env)
conda update -q conda
conda install --yes conda-build anaconda-client

# Create and activate new NadaMq environment
conda create --name $env:APPVEYOR_PROJECT_NAME
activate $env:APPVEYOR_PROJECT_NAME

# Run conda build and capture error message, then run again to fetch package location
echo "Getting package location:"
$package_location = conda build . --output
if (!$package_location){
  $msg = "Failed to get package info";
  $details = "check for issues in conda-recipes meta.yaml file";
  Add-AppveyorMessage -Message $msg -Category Error -Details $details
  throw $msg
}

echo "Location set to: " + $package_location

# Set environment variable for project directory (may be used in bld.bat)
$project_directory = (Get-Item -Path ".\" -Verbose).FullName
echo "Project Directory: " + $project_directory

# Build package
echo "Building conda package"
Try {
  conda build .
} Catch {
  $msg = "Failed to build conda package";
  Add-AppveyorMessage -Message $msg -Category Error
  throw $msg
}

# Move back to project directory
cd $project_diectory

# Capture package location
touch $package_location
echo $package_location > PACKAGE_LOCATION
