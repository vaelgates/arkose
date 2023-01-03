This program is written in platform-independent C#. It takes a google docs file as input and outputs the "interactive arguments" part of the website as markdown.


STEP BY STEP INSTRUCTIONS FOR GETTING THIS TO RUN
=================================================


1. Install a C# development environment - I recommend Visual Studio. 
Download here for Mac and Windows: https://visualstudio.microsoft.com/
Please keep in mind that "Visual Studio Code" is not the same as "Visual Studio". MonoDevelop would also work.

2. Open the Visual Studio project file at aird\tools\BuildInteractiveArguments\BuildInteractiveArguments.csproj

3. Find the line that says "static string privateConfigDir"

4. A few lines below that, please add a new branch with your machine name and referencing some private directory that's not part of the git repository. (similar to the existing branch referencing the machine name "LTLAP"). This directory will contain two secrets that should not be part of the git repository: "aird_documents_id.txt" containing the document ID of the google docs file, and "aird_service_account.json" which is explained below.

5. Create that private directory (if it doesnt exist yet), and open it.

6. In that directory, place a file called "aird_documents_id.txt" containing the document ID of the google docs file. For example, if the Google Docs URL is https://docs.google.com/document/d/1x45678901234567890/edit then the document ID would be "1x45678901234567890"

7. Create a "service worker account" on Google and download the associated JSON file. You can do that at https://console.cloud.google.com/ . I made a short video demonstrating how to do that and included it as part of this repository with the filename "google_service_worker_account.mp4".

8. Place that JSON file in the same private directory you placed the "aird_documents_id.txt" in.

9. If you are not using Visual Studio, then make sure that the working directory of the script is set to tools\BuildInteractiveArguments . If you are using Visual Studio and have opened the included project file, then this should already be set up correctly.

10. Run the program. It will build the arguments.

11. Open a command line and run "bundle exec jekyll build" within the root folder of the website. (The arguments build script contains code to do this automatically, but this is only done on my machine conditionally on my machine name because I did not test it on other platforms.)

12. In the command line, navigate to the tools folder and run "ruby move_arguments.rb" (Same comment as above applies: the script contains code to do this automatically but it is disabled on any machine except my own due to lack of testing)