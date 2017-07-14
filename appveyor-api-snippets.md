## Useful commands for handling many AppVeyor Projects

When migrating all the repositories held in the wheeler-microfluidics channel to AppVeyor for CI Build/Testing I found the following snippets useful for extending the websites UI. These Javascript code snippets were ran directly from the console of the web browser, while logged into the Sci-Bots AppVeyor account.

These snippets may stop working in the future if AppVeyor stops exposing the jQuery and Underscore libraries.



##### Fetch All Projects: #####

```javascript
var projects;
$.ajax({
  type: "GET",
  url: "https://ci.appveyor.com/api/projects/",
  success: function(d){projects = d;}
});
```



##### Cancel All Projects: #####

```  javascript
_.each(projects, function(p){ 
  if (!p.builds.length)return; 
  $.ajax({
  	type: "DELETE",
  	url: "https://ci.appveyor.com/api/builds/SciBots/"+p.slug+"/"+_.last(p.builds)["version"],
  	error: function(d){console.log(d);}
  });
});
```


##### Retrieve all repositories in a github account / organization #####

1. Open Console Window > Network Tab
2. Navigate to https://ci.appveyor.com/projects/new
3. In network tab select gitHub > Response



##### Initiate Project for Every Repository in List 

```javascript
_.each(package_names, function(name){
	$.ajax({
  		type: "POST",
  		url: "https://ci.appveyor.com/projects",
 		data: {"repositoryProvider":"gitHub", "repositoryName":"wheeler-microfluidics/"+name},
  		error: function(d){console.log(d);}
    });
});
```

