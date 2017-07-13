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
    # Clone Repository
    if os.path.isdir('./'+name): rmtree(name)
    subprocess.check_call(["git", "clone", "https://github.com/wheeler-microfluidics/"+name+".git"])

    # Change into Repository
    os.chdir(os.path.join(cwd, name))

    # Fetch Remote URL from Git Repository
    config = configparser.ConfigParser()
    config.read('.git/config')
    git_url = config['remote "origin"']['url']

    # Write to file
    appveyorFile = open("appveyor.yml","w")
    appveyorFile.write(template.render({"git_url": git_url}))
    appveyorFile.close()

    # Commit changes, and push upsteam
    try:
        subprocess.check_call(["git", "add", "appveyor.yml"])
        subprocess.check_call(["git", "commit", "-m", "added appveyor.yml"])
        subprocess.check_call(["git", "push", "origin", "master"])
    except:
        pass

    # Change out of Repository
    os.chdir(cwd)

    # delete Repository
    rmtree(name)
