# Sci-Bots-Configs Repository

This repository holds all files relating to CI Worlkflow scripts, code snippets, etc. When this repo is pushed to GitHub after making changes, the build script will update the build configuration for all packages in the wheeler-microfluidics organization listed in the *wheeler-package-names.json* file. This then cues these packages to be re-build on AppVeyor with the updated configuration information.


A table of packages with status information being build by AppVeyor can be found here:

[AppVeyor Package Table](https://benefique-gerard-47512.herokuapp.com/) ([json](https://benefique-gerard-47512.herokuapp.com/json))



## TODO:

- [ ] Change wheeler-package-names.json to blacklist style vs. whitelist style (easier to update given almost all packages will have CI Workflows)
- [ ] And Sci-Bots Organization Packages
- [ ] Find better way to update build version name (since this package needs to be pushed to GitHub for package version numbers to increment). This could be done using a custom script in the .conda-recipe folder
- [ ] Come up with version naming convention for packages without git tags
- [ ] Finish everything mention [here](https://github.com/wheeler-microfluidics/microdrop/issues/228)



## Setting Up Conda Authentication Token

Before uploading to Anaconda Cloud, you must make an authentication token for your conda account

```python
# Login to your account:
> anaconda login
#Using Anaconda API: https://api.anaconda.org
#Username: lucaszw
#lucaszw's Password:
#login successful

# Generate an authentication token
> binstar auth -n someNameForToken --max-age 22896000 -c --scopes api
```

Enter the token above using the AppVeyor UI located here:

https://ci.appveyor.com/project/USERNAME/PROJECTNAME/settings/environment

Select Environment Variables > Add Variable:

| Name          | Value                |
| ------------- | -------------------- |
| binstar_token | AUTHENTICATION_TOKEN |



## Handling Packages / AppVeyor Projects ###

To make it easier to add , remove, and update batches of projects at once within AppVeyor I wrote up some documentation with code snippets [here](https://github.com/sci-bots/sci-bots-configs/blob/master/appveyor-api-snippets.md) .



### Adding project to AppVeyor / Sci-Bots-Configs: ####

1. Whitelist the project by adding the name of the repository to the [wheeler_package_names.json](https://github.com/sci-bots/sci-bots-configs/blob/master/wheeler_package_names.json) file. TODO: I should change this to a Blacklist file (since we will likely want to track 90% of the repositories)
2. Add the project to AppVeyor: https://ci.appveyor.com/projects/new



### Adding all projects of organization to AppVeyor at once: ####

AppVeyor's UI requires manually adding individual packages one at a time (this can be tedious, since the behavior of the add button also emits a javascript based re-direct response in the web browser ). Therefore for adding many projects at once, it is better to defer to the javascript console window, and use AppVeyors rest API.  To make things more simple, AppVeyor exposes both the jQuery and Underscore JS frameworks (while also not requiring Authentication Tokens when making requests directly from the javascript console)

**1. Retrieve all repositories in a github account / organization**

1. Open Console Window > Network Tab
2. Navigate to [https://ci.appveyor.com/projects/new](https://ci.appveyor.com/projects/new)
3. In network tab select gitHub > Response

**2. Copy the value of the response, store as variable in javascript console window, and publish using AppVeyors rest API**

```javascript
// Copy response from gitHub > Response
// Pase response into variable
var package_names = "{PASTE_HERE}"
_.each(package_names, function(name){
	$.ajax({
  		type: "POST",
  		url: "https://ci.appveyor.com/projects",
 		data: {"repositoryProvider":"gitHub", "repositoryName":"{ORGANIZATION_NAME}/"+name},
  		error: function(d){console.log(d);}
    });
});
```

**3. Add the package names to  [wheeler_package_names.json](https://github.com/sci-bots/sci-bots-configs/blob/master/wheeler_package_names.json)**



## Generating CI Files

The process of generating CI Files is automated using [generate_ci_files.py](https://github.com/sci-bots/sci-bots-configs/blob/master/generate-ci-files.py) . This file is called through Sci-Bots-Configs [Appveyor.yml](https://github.com/sci-bots/sci-bots-configs/blob/master/appveyor.yml) file. The process is outlined in the steps below:

1. Iterate through each package in wheeler-package-names.json
2. Clone the corresponding git repository
3. Write a new Appveyor.yml for the project using the appveyor-template.yml file
4. Push git repository onto master (triggering a rebuild)



## YAML template for all packages



For all packages, I used a standard template for the yaml file. This file is filled by generate_ci_files.py . The install and after test stage logic are separated into there own files linked here: [install](https://github.com/sci-bots/sci-bots-configs/blob/master/appveyor-install.bat), [after_test](https://github.com/sci-bots/sci-bots-configs/blob/master/appveyor-after-test.ps1) .

```yaml
environment:
  GIT_REPOSITORY: {{git_url}}
  matrix:
    - PYTHON_VERSION: 2.7
      MINICONDA: C:\Miniconda
      PYTHON_ARCH: "32"

version: '{{version_number}}'

init:
  - "ECHO %PYTHON_VERSION% %MINICONDA%"

install:
  # Exit if no .conda-recipe folder
  - IF NOT EXIST .conda-recipe exit 1

  - git clone --depth=1 https://github.com/sci-bots/sci-bots-configs.git
  - .\sci-bots-configs\appveyor-install.bat

# Handle build and tests using conda (defined in .conda-recipe/meta.yaml)
build: false
test_script:
  - echo Build Complete

after_test:
  - powershell -executionpolicy remotesigned -File .\sci-bots-configs\appveyor-after-test.ps1
```





## Common config problems

For the most part, packages should not need any modification in order to properly build on AppVeyor.  However, particularily in cases where packages open separate processes'; modifications to the packages source code may be required in order to ensure AppVeyor can successfully terminate. An example of how to solve this for [jupyter_helpers](https://github.com/sci-bots/jupyter-helpers) is shown below.



1. Ensure the build phase is turned off for python development

2. Ensure the environment is activated

3. For debugging connect using Remote Desktop

4. Subprocess' need to be physically terminated at end of test scripts (otherwise the AppVeyor process will hang). To do this:

   1. Ensure that Subprocesses are not flagged to be terminated with main subprocess

   2. Add a stop method to the Thread, and call it at the end of the tests

   3. Use PSutil to terminate process, since this will ensure that Windows doesn't open a confirmation prompt (which causes that AppVeyor tests to hang

      ```python
      import psutil
      ```

      ```python
      def test_get_session():
          sm = notebook.SessionManager()
          session = sm.get_session()
          session.thread.stop()
          process = psutil.Process(session.process.pid)
          for proc in process.children(recursive=True):
              proc.kill()
          process.kill()
          return session
      ```



## Sample Code

For AppVeyor to build and terminate successfully, all threads started by tests must be terminated. Sample code for simplifying the termination of threads in python is shown below.



```python
class StoppableThread(Thread):
    """Thread class with a stop() method. The thread itself has to check
    regularly for the stopped() condition.
    From: https://stackoverflow.com/questions/323972/is-there-any-way-to-kill-a-thread-in-python"""

    def __init__(self, *args, **kwargs):
        super(StoppableThread, self).__init__(*args,**kwargs)
        self._stop_event = threading.Event()

    def stop(self):
        self._stop_event.set()

    def stopped(self):
        return self._stop_event.is_set()
```

```python
def enqueue_output(out, queue):
    """ Ensure break statement in StoppableThread target """
    for line in iter(out.readline, b''):
        if self.thread.stopped(): break
            queue.put(line)
            out.close()
```



## Resources



1. Tutorial for handling Conda with AppVeyor: http://tjelvarolsson.com/blog/how-to-continuously-test-your-python-code-on-windows-using-appveyor/
2. Ensuring termination of subprocesses before main process: https://stackoverflow.com/questions/4789837/how-to-terminate-a-python-subprocess-launched-with-shell-true/25134985
3. Uploading test results to AppVeyor: https://www.appveyor.com/docs/running-tests/#uploading-xml-test-results
4. Ensuring thread is not killed abruptly: https://stackoverflow.com/questions/323972/is-there-any-way-to-kill-a-thread-in-python
5. Support for figuring out why nosetests was hanging on AppVeyor: http://help.appveyor.com/discussions/problems/6777-appveyor-with-pythonminiconda-hanging-after-completing-nosetests
6. How to connect to Remote Desktop for AppVeyor instance: https://www.appveyor.com/docs/how-to/rdp-to-build-worker/
