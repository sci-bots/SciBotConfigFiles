REM Batch file for AppVeyor install step
REM Requires MINICONDA and PROJECT_NAME environment variables

REM Add Conda to path
set PATH=%MINICONDA%;%MINICONDA%\\Scripts;%PATH%

REM Configure Conda to operate without user input
conda config --set always_yes yes --set changeps1 no

REM Add the conda-force, and wheeler-microfluidics channels
conda config --add channels conda-forge
conda config --add channels wheeler-microfluidics

REM Update conda, and install conda-build (used for building in non-root env)
conda update -q conda
conda install --yes conda-build anaconda-client

REM Create and activate new NadaMq environment
conda create --name %APPVEYOR_PROJECT_NAME%
call %MINICONDA%\\Scripts\\activate.bat %APPVEYOR_PROJECT_NAME%
REM conda info -a

REM Get output package location
echo "Getting package location:"
FOR /F "tokens=*" %%a in (
  conda-build . --output

  IF %ERRORLEVEL% NEQ 0 (
    appveyor AddMessage "Failed to get package location. May be problem in meta.yaml file" -Category Error
    exit 1
  )
) do SET PACKAGE_LOCATION=%%a

echo %PACKAGE_LOCATION%


REM Set environment variable for project location (may be used in bld.bat)
set "PROJECT_DIRECTORY=%cd%"

REM Build package
conda-build .

REM Move back to project directory
cd %PROJECT_DIRECTORY%

REM Capture package location
touch PACKAGE_LOCATION
echo %PACKAGE_LOCATION% > PACKAGE_LOCATION
