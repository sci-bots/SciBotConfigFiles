import json
import os
import stat
import subprocess

import configparser
from jinja2 import FileSystemLoader, Environment

# https://stackoverflow.com/questions/2656322/shutil-rmtree-fails-on-windows-with-access-is-denied/28476782
def rmtree(top):
    for root, dirs, files in os.walk(top, topdown=False):
        for name in files:
            filename = os.path.join(root, name)
            os.chmod(filename, stat.S_IWUSR)
            os.remove(filename)
        for name in dirs:
            os.rmdir(os.path.join(root, name))
    os.rmdir(top)

# Load AppVeyor template (for Windows Installs)
templateEnvironment = Environment( loader=FileSystemLoader( searchpath="./" ) )
template = templateEnvironment.get_template("appveyor-template.yml")

# Open json file containing all package names:
with open('wheeler_package_names.json') as data_file:
    package_names = json.load(data_file)["package_names"]

cwd = os.getcwd()

for name in package_names:
    # Get markdown for AppVeyor Badge
    appveyor_root = "https://ci.appveyor.com/api/projects/status/github/wheeler-microfluidics/"
    appveyor_badge_url = appveyor_root+name+"?branch=master&svg=true"
    appveyor_badge = "!["+appveyor_badge_url+"]("+appveyor_badge_url+")"

    # Clone Repository
    if os.path.isdir('./'+name): rmtree(name)
    subprocess.check_call(["git", "clone", "https://github.com/wheeler-microfluidics/"+name+".git"])

    # Change into Repository
    os.chdir(os.path.join(cwd, name))

    # Store README as string:
    with open('README.md', 'r') as myfile: readme=myfile.read()
    readme = readme.split("\n")

    # If first line is not badge then append it
    if readme[0] != appveyor_badge:
        readme.insert(0,appveyor_badge)
        with open('README.md', "w") as myfile: myfile.write('\n'.join(readme))
        subprocess.check_call(["git", "add", "README.md"])

    # Fetch Remote URL from Git Repository
    config = configparser.ConfigParser()
    config.read('.git/config')
    git_url = config['remote "origin"']['url']

    # Get package version number:
    try:
        version_number = '.'.join(subprocess.check_output(["git", "describe","--tags"]).split("-")[0:2])[1::]
    except:
        version_number = 'not set'

    # Write to file
    appveyorFile = open("appveyor.yml","w")
    appveyorFile.write(template.render({"git_url": git_url, "version_number": version_number}))
    appveyorFile.close()

    # Commit changes, and push upsteam
    try:
        subprocess.check_call(["git", "add", "appveyor.yml"])
        subprocess.check_call(["git", "commit", "-m", "AppVeyor Configuration Updated"])
        subprocess.check_call(["git", "push", "origin", "master"])
    except:
        pass

    # Change out of Repository
    os.chdir(cwd)

    # delete Repository
    rmtree(name)
