# Get the package location, and package name
$package_location = $(& cat PACKAGE_LOCATION).Trim();
$package_name = (( $package_location -split '\\') | Select-Object -Last 1) -split '\.bz2' | Select-Object -First 1;

# Unarchive package
7z e $package_location -tbzip2;
7z x $package_name -opackage -ttar;
$json = Get-Content '.\\package\\info\\index.json' | Out-String | ConvertFrom-Json;

# Add members to info.json:
$json | Add-Member git_repository $($env:GIT_REPOSITORY);
$json | Add-Member git_repo_name $($env:APPVEYOR_REPO_NAME);
$json | Add-Member git_repo_branch $($env:APPVEYOR_REPO_BRANCH);
$json | ConvertTo-JSON | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Set-Content .\package\info\index.json;

# re-archive package
7z a $package_name .\package\* -ttar;
7z a $($package_name+'.bz2') $package_name -tbzip2;

# Save tarfile as artifact
appveyor PushArtifact $($package_name+'.bz2');

# Upload to Anaconda Cloud
# binstar -t $($BINSTAR_TOKEN) upload --force $($package_name+'.bz2');

# Upload Test Results
$wc = New-Object 'System.Net.WebClient';
$wc.UploadFile("https://ci.appveyor.com/api/testresults/junit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path .\nosetests.xml));