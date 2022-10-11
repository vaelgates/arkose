This script takes a google docs file as input and outputs the "interactive arguments" part of the website as markdown.

It is written in C# and developed on Windows. It should be able to run without problems on other platforms - just make sure you change the path references.

The code is written to be used with LinqPad, which is a minimalist C# development environment with a free version available. Unfortunately, I believe the free version will not run this script out-of-the-box because the free version is not able to automatically download the required packages for the Google Docs library from the package source (which is Nuget).

There are three solutions for that:
1. buy a license to LinqPad
2. download those libraries and reference them manually, I guess this would work
3. Or simply copy the code and use any other C# development environment like Visual Studio.


To run this script, you need two files, which must not be pushed to Github because they contain secrets. Lukas can provide you with these files.
"aird_documents_id.txt" contains the document ID of the google docs file
"aird_service_account.json" is the authentication JSON file associated with a "service worker" account in the Google admin console. Since our document is public, no specific account is required - you can get the credentials to mine or just create your own. (if you create your ownn, bear in mind to also update the user name "aird-build-script@aird-364611.iam.gserviceaccount.com" referenced a bit lower in the code.