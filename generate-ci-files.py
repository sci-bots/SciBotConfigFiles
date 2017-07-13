import configparser
from jinja2 import FileSystemLoader, Environment

# Fetch Remote URL from Git Repository
config = configparser.ConfigParser()
config.read('.git/config')
git_url = config['remote "origin"']['url']

# Load AppVeyor template (for Windows Installs)
templateEnvironment = Environment( loader=FileSystemLoader( searchpath="./" ) )
template = templateEnvironment.get_template("appveyor-template.yml")

# Write to file
appveyorFile = open("appveyor.yml","w")
appveyorFile.write(template.render({"git_url":git_url}))
appveyorFile.close()
