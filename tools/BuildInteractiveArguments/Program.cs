using System.Net;
using System.Text.RegularExpressions;
using System.Text;
using System.Web;
using Google.Apis.Docs.v1;
using Google.Apis.Auth.OAuth2;
using System.Security.Cryptography;
using Google.Apis.Services;
using System.Diagnostics;
using System;
using HtmlAgilityPack;
using System.Collections.Immutable;

class Program
{


	#region Configuration that needs to be adjusted when running on different platforms
	static string privateConfigDir
	{
		get

		{
			if (Environment.MachineName == "LTLAP")
				return "c:\\temp\\";
			else
				throw new NotImplementedException("Under privateConfigDir, please add a branch referencing a private directory on your computer");
		}
	}
	#endregion






	#region Configuration that does NOT need to be adjusted when running on different platforms.
	static string folderInWebsite = "arguments";

	/// <summary>
	/// this is assuming that the folder tools\BuldInteractiveArguments is used as the scripts working directory
	/// </summary>
	static string baseDir = Directory.GetCurrentDirectory() + Path.DirectorySeparatorChar+".." + Path.DirectorySeparatorChar + ".." + Path.DirectorySeparatorChar;
	static string argumentsDir = baseDir + Path.DirectorySeparatorChar + folderInWebsite + Path.DirectorySeparatorChar;

	static string assetsDirRelative = "assets" + Path.DirectorySeparatorChar + "images" + Path.DirectorySeparatorChar + "arguments" + Path.DirectorySeparatorChar;
	static string assetsDir = baseDir + assetsDirRelative;
	static string imageCacheFile = assetsDir + "images.txt";
	static string pageFileExtension = ".html";

	static bool VerboseDebugOutput = false;

	#endregion


	static string documentsId => File.ReadLines(privateConfigDir + "aird_documents_id.txt").First();

	public static void Main()
	{
		new Program().main();
	}
	void main()
	{




		// We remember these links and check them after all processing, including jekyll, has finished.
		List<string> localLinkstoCHeck = new List<string>();


		string argumentsYamlFile = baseDir + Path.DirectorySeparatorChar + "_data" + Path.DirectorySeparatorChar + "arguments.yml";

		var rgxml = @"\[([^\]]*?)\]\((.*?)\)";
		Regex markdownLinkNav = new Regex("nav:" + rgxml);
		Regex markdownLinkRgxWithoutNav = new Regex("(?<!nav:)" + rgxml);


		Directory.CreateDirectory(argumentsDir);
		System.IO.DirectoryInfo di = new DirectoryInfo(argumentsDir);

		foreach (FileInfo file in di.GetFiles())
		{
			file.Delete();
		}



		ServiceAccountCredential credential;
		var gSecretFilename = privateConfigDir + "aird_service_account.json";
		// 
		using (var stream = new FileStream(gSecretFilename, FileMode.Open, FileAccess.Read))
		{
			// https://stackoverflow.com/questions/41267813/authenticate-to-use-google-sheets-with-service-account-instead-of-personal-accou

			credential = (ServiceAccountCredential)
				GoogleCredential.FromStream(stream).UnderlyingCredential;

			var initializer = new ServiceAccountCredential.Initializer(credential.Id)
			{
				User = Between(File.ReadAllText(gSecretFilename), "\"client_email\": \"", "\""),
				Key = credential.Key,
				Scopes = new[] { DocsService.Scope.DocumentsReadonly }
			};
			credential = new ServiceAccountCredential(initializer);
		}


		var service = new DocsService(new BaseClientService.Initializer() { HttpClientInitializer = credential, ApplicationName = "AIRD Build Script" });

		var docReq = service.Documents.Get(documentsId);
		docReq.SuggestionsViewMode = DocumentsResource.GetRequest.SuggestionsViewModeEnum.PREVIEWWITHOUTSUGGESTIONS;


		var doc = docReq.Execute();


		bool encounteredStartMarker = false;

		Dictionary<string, string> textblocks = new Dictionary<string, string>();
		string currentTextblock = null;



		Document currentDocument = null;
		var outputFiles = new List<Document>();


		bool parseNavMode = false;
		bool justStartedNewdocumentAndWaitingForYmlData = false;
		foreach (var element in doc.Body.Content)
		{
			if (element.Paragraph == null)
				continue;



			string style = element.Paragraph.ParagraphStyle.NamedStyleType;

			string gdocGlyph = "";
			int? bulletLevel = null;
			ListTypeEnum? bulletType = null;
			string firstLinePrefix = "";


			if (encounteredStartMarker)
			{
				if (element.Paragraph.Bullet != null)
				{
					bulletLevel = element.Paragraph.Bullet.NestingLevel;
					if (bulletLevel == null)
					{
						bulletLevel = 0;
					}
					var associatedList = doc.Lists[element.Paragraph.Bullet.ListId];
					string markdownBulletSymbol;
					var nl = associatedList.ListProperties.NestingLevels[bulletLevel.Value];
					gdocGlyph = nl.GlyphSymbol;
					switch (gdocGlyph)
					{
						case "■":
						case "○":
						case "●": markdownBulletSymbol = "*"; bulletType = ListTypeEnum.Bullet; break;
						case "-": markdownBulletSymbol = "-"; bulletType = ListTypeEnum.Bullet; break;
						case null:
							if (nl.GlyphType == "DECIMAL")
							{
								markdownBulletSymbol = "1.";
								bulletType = ListTypeEnum.Number;
							}
							else if (nl.GlyphType == "ALPHA")
							{
								markdownBulletSymbol = "A.";
								bulletType = ListTypeEnum.Number;
							}
							else
								throw new NotImplementedException();
							break;
						default: throw new NotImplementedException("What is the Markdown equivalent of this google docs list glyph? " + gdocGlyph); ;
					}
					firstLinePrefix = bulletLevel == null ? "" : (new string('\t', bulletLevel.Value) + markdownBulletSymbol + " ");
				}

				#region starting a new document
				if (style.StartsWith("HEADING_") && int.TryParse(style.Substring("HEADING_".Length, 1), out var x))
				{
					if (element.Paragraph.Elements.Count > 1)
						throw new InvalidOperationException("There are two different styles in a headline here - " + element.Paragraph.Elements[0].TextRun.Content + " - if you dont know why this happens, then simply cut the headline and re-insert using CTRL+SHIFT+V which inserts without style");
					var txt = element.Paragraph.Elements[0].TextRun.Content;

					if (txt.Trim() == "")
						continue;
					if (VerboseDebugOutput)
						Console.WriteLine($"Starting new document {txt}");
					justStartedNewdocumentAndWaitingForYmlData = true;
					currentDocument = new Document();
					currentDocument.HierarchyLevel = x - 2;
					outputFiles.Add(currentDocument);
					var internalIdAndShortHeadline = Between(txt, "[", "]").Trim();
					currentDocument.InternalID = EverythingBefore(internalIdAndShortHeadline, "|");



					currentDocument.Headline = EverythingAfter(txt, "]").Trim();

					if (internalIdAndShortHeadline.Contains("|"))
						currentDocument.ShorterHeadline = EverythingAfter(internalIdAndShortHeadline, "|");
					else
						currentDocument.ShorterHeadline = currentDocument.Headline;

					if (currentDocument.InternalID == "")
						currentDocument.InternalID = currentDocument.Headline;
					else if (currentDocument.Headline == "")
					{
						currentDocument.Headline = currentDocument.InternalID;
					}

					if (currentDocument.InternalID == "")
						throw new InvalidOperationException("Cannot determine internal ID for headline: " + txt);
					if (currentDocument.Headline == "")
						throw new InvalidOperationException("Cannot determine headline for " + txt);

					if (currentDocument.ShorterHeadline.Trim() == "")
						currentDocument.ShorterHeadline = currentDocument.Headline;

					currentDocument.FilenameWithoutPathOrExtension =
					RemoveDoubleOccurences('-',
					CamelToDash(currentDocument.InternalID).Replace(" ", "-"));

					if (currentDocument.FilenameWithoutPathOrExtension.Contains(",") || currentDocument.FilenameWithoutPathOrExtension.Contains("'") || currentDocument.FilenameWithoutPathOrExtension.Contains("’"))
						throw new InvalidOperationException("Make sure you specify a shorthand here: " + currentDocument.FilenameWithoutPathOrExtension); // we could simply replace it, but these characters are indications of a text thats too complex to be an URL.

					if (currentDocument.FilenameWithoutPathOrExtension.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
						throw new InvalidOperationException("This ID is not a valid filename: " + currentDocument.FilenameWithoutPathOrExtension);

					// syntax sample breadcrumbs: breadcrumbs: The Alignment Problem:the-alignment-problem,Test Before Deploying:test-before-deploying

					var breadcrumbs = GetBreadcrumbs(outputFiles, currentDocument);
					currentDocument.JekyllFrontmatter = $@"---
layout: argument
title: {"\"" + currentDocument.ShorterHeadline + "\""}
breadcrumbs: {breadcrumbs}
---";

					if (currentDocument.FilenameWithoutPathOrExtension.Contains("the-ali"))
					{

					}

					continue; // this is important, dont remove.


				}
				#endregion


			}

			// when we encounter an image, the very next element must be the image caption and start with a "(".

			bool first = true;
			int imageCaptionBracketCounter = 0;




			foreach (var el in element.Paragraph.Elements)
			{
				bool bold = false;
				if (el.TextRun?.TextStyle?.Strikethrough == true)
					continue;
				if (el.TextRun?.TextStyle?.Bold == true)
					bold = true;
				if (!encounteredStartMarker)
				{
					if (el.TextRun != null && el.TextRun.Content.Contains("#content_begin"))
						encounteredStartMarker = true;
					continue;
				}
				else
				{
					if (el.TextRun != null && el.TextRun.Content.Contains("#content_end"))
						goto quit;
				}



				bool currentlyBuildingAnImage = currentDocument != null && currentDocument.Content.Count > 0 && currentDocument.Content.Last().ImageUrls.Count > 0
				&& (currentDocument.Content.Last().ImageCaption.Length == 0 || imageCaptionBracketCounter > 0);// if the caption is filled ( ")" encountered) in then the image block is finished.
				if (el.TextRun != null)
				{
					var txt = el.TextRun.Content.Trim();

					if (parseNavMode && !el.TextRun.Content.StartsWith("  "))
						parseNavMode = false;

					if (el.TextRun.Content.StartsWith("nav:"))
					{
						parseNavMode = true;
						currentDocument.ExtraYmlNavigation.Add(new Dictionary<string, string>());
						continue;
					}

					if (parseNavMode)
					{
						string key = Between(el.TextRun.Content, "  ", ":");
						string value = EverythingAfter(el.TextRun.Content, ":").Trim();


						currentDocument.ExtraYmlNavigation.Last()[key] = value;
						continue;
					}

					if (txt == "")
						continue;

					if (justStartedNewdocumentAndWaitingForYmlData) //  collecting YAML information
					{
						if (txt.StartsWith("yml:"))
						{
							txt = EverythingAfter(txt, "yml:");
							currentDocument.extraYamlData[EverythingBefore(txt, ":")] = EverythingAfter(txt, ":");

							continue;
						}
						else
							justStartedNewdocumentAndWaitingForYmlData = false;

					}


					// make sure beginning and ending blockquotes are always on a separate line
					txt = txt.Replace("[quote]", "\n<blockquote>\n");

					txt = txt.Replace("[/quote]", "\n</blockquote>\n");

					if (bold)
						txt = "<em>" + txt + "</em>";

					if (currentDocument == null)
						throw new InvalidOperationException("Error: after #content_begin, there immediately must be the headline");

					if (currentlyBuildingAnImage) // currently building an image --> this text is the caption for one or several preceeding images
					{
						if (VerboseDebugOutput)
							Console.WriteLine($"adding to caption: {txt}");
						currentDocument.Content.Last().ImageCaption += HttpUtility.HtmlEncode(txt);
						imageCaptionBracketCounter += txt.Count(f => f == '(') - txt.Count(f => f == ')');
					}
					else
					{
						if (!first) // adding to previous elements of the same paragraph. for example, if you have text and then a link and then some more text, this will be 3 elements
							currentDocument.Content.Last().HtmlText += " " + txt;
						else
							currentDocument.Content.Add(new ContentParagraph(txt) { BulletLevel = bulletLevel, BulletType = bulletType });
					}
					first = false;

				}
				else if (el.InlineObjectElement != null)
				{
					var ilo = doc.InlineObjects[el.InlineObjectElement.InlineObjectId];
					var imageProps = ilo.InlineObjectProperties.EmbeddedObject.ImageProperties;
					if (!currentlyBuildingAnImage)
						currentDocument.Content.Add(new ContentParagraph("") { BulletLevel = bulletLevel, BulletType = bulletType });
					// we are constructing an image block consisting of several images
					currentDocument.Content.Last().ImageUrls.Add(new GDocsImage() { ContentUrl = imageProps.ContentUri, EmbeddedObjectId = el.InlineObjectElement.InlineObjectId });

					if (VerboseDebugOutput)
						Console.WriteLine("Image at " + imageProps.ContentUri + ", waiting for caption or additional images...");
					continue;


				}
				else
					throw new NotImplementedException();
				justStartedNewdocumentAndWaitingForYmlData = false;
			}

		}
	quit:


		string GetDocumentLink(Document matchingPage)
		{
			return matchingPage.FilenameWithoutPathOrExtension ;
		}
		(string, string) ProcessMarkdownLink(string title, string url)
		{
			if (url.StartsWith("http") || url.StartsWith("mailto:"))
			{
				// external link or email, nothing to check here
			}
			else if (url.StartsWith("/") || url.StartsWith("."))// link to a page address
			{
				localLinkstoCHeck.Add(url);
			} 
			else // link to a page title.
			{
				url = "###link:" + url + "###"; // to be handled at the very end
				
			}


			return (title, url);

		}
		string MakeMarkdownLink(string title, string url)
		{
			url = url.Trim();
			title = title.Trim();
			var attributes = "";
			if (url.StartsWith("http")) //--> external link
				attributes = "target='_blank'";

			(title, url) = ProcessMarkdownLink(title, url);


			return $"<a href='{url}' {attributes}>{title}</a>";
		}
		string ConvertMarkdownLinksToHtml(string input)
		{

			return (markdownLinkRgxWithoutNav).Replace(input, match =>
			{
				string attributes = "";

				return MakeMarkdownLink(match.Groups[1].Value, match.Groups[2].Value);

			}
			);
		}

		#region output
		var lastHighlevelArticle = outputFiles.Last(x => x.HierarchyLevel == 0);
		foreach (var of in outputFiles)
		{



			StringBuilder outText = new StringBuilder();

			int? previousBulletLevel = null;
			Stack<string> listTags = new Stack<string>();

			void CloseList()
			{

				outText.Append(listTags.Pop().Replace("<", "</"));
			}
			bool argnavWritten = false;
			void WriteNavAnchor()
			{
				if (!argnavWritten)
				{
					outText.AppendLine("<a name='argnav'/>");
					outText.AppendLine("<br/><br/><br/><!-- temporary fix for issue 19 -->");
					argnavWritten = true;
				}
			}
			#region loop over paragraphs
			for (int i = 0; i < of.Content.Count; i++)
			{
				var thisParagraph = of.Content[i];

				if (VerboseDebugOutput)
					Console.WriteLine(thisParagraph);


				thisParagraph.HtmlText = thisParagraph.HtmlText.Replace(new string(new[] { (char)0x0B }), "<br/>");
				// 0x0b (line tabulation) is returned from the google docs API to make line breaks without creating a new paragraph
				if (thisParagraph.Bold == true)
					thisParagraph.HtmlText = "<em>" + thisParagraph.HtmlText + "</em>";




				if (thisParagraph.BulletLevel == null && previousBulletLevel != null) // close all lists
				{
					while (listTags.Any())
						CloseList();
					previousBulletLevel = null;
				}
				string prefix = "";
				string postfix = "";

				if (thisParagraph.BulletLevel != null)
				{
					if (previousBulletLevel != thisParagraph.BulletLevel)
					{
						if (previousBulletLevel == null || previousBulletLevel < thisParagraph.BulletLevel) // open new list
						{
							listTags.Push(thisParagraph.BulletType == ListTypeEnum.Bullet ? "<ul>" : "<ol>");
							outText.Append(listTags.Peek());
						}
						else while (previousBulletLevel > thisParagraph.BulletLevel)
							{
								CloseList();
								previousBulletLevel--;
							}
					}

					previousBulletLevel = thisParagraph.BulletLevel;
					prefix = "<li>";
					postfix = "</li>";
				}
				else
				{
					// have everything enclosed in DIVs that
					// 	> is not a bulletpoint
					//  > is not a beginmarker or endmarker of a textblock





					var trim = thisParagraph.HtmlText;
					if (!trim.StartsWith("[") && !trim.EndsWith("]"))
					{
						if (trim.Contains("<blockquote>"))
						{
							prefix = "";
							thisParagraph.HtmlText = thisParagraph.HtmlText.Replace("<blockquote>", "<blockquote><p>");	
						}
						else
							prefix = "<p>";
						if (trim.Contains("</blockquote>"))
						{
							postfix = "";
							thisParagraph.HtmlText = thisParagraph.HtmlText.Replace("</blockquote>", "</p></blockquote>");
						}
						else
							postfix = "</p>";
						previousBulletLevel = null;
					}



					if (trim.StartsWith("q:")) // a question to the reader
					{
						if (trim.StartsWith("q:single-choice:"))
							of.QuestionIsSingleChoice = true;
						if (trim.Contains("buttons:"))
							of.MakeButtonsForQuestionAnswers = true;
						WriteNavAnchor(); // TODO ask keenan to move that nav anchor into his system

						of.Question = EverythingAfter(thisParagraph.HtmlText, "q:").Replace("single-choice:", "").Replace("multiple-choice", "").Replace("buttons:", "");


						prefix = "<p><em>"; // TODO remove
						postfix = "</em></p>"; // TODO remove
						thisParagraph.HtmlText = "";
					}
					if (trim.StartsWith("q-subtext:"))
					{
						of.QuestionSubtext = EverythingAfter(trim, "q-subtext:");
						thisParagraph.HtmlText = "";
					}
				}




				if (of.Content[i].ImageUrls.Count > 0) // write an image block
				{
					if (!of.Content[i].ImageCaption.StartsWith("("))
						ExitAndComplainAboutImageCaption(of.Content[i].ImageUrls);
					var img = new StringBuilder();

					if (!thisParagraph.ImageCaption.StartsWith("(") || !thisParagraph.ImageCaption.EndsWith(")"))
						ExitAndComplainAboutImageCaption(thisParagraph.ImageUrls);
					img.Append(prefix);
					img.Append(@"<figure>");
					foreach (var imageUrl in thisParagraph.ImageUrls)
					{
						var fn = assetsDirRelative + DownloadImageAndReturnFilename(imageUrl);
						img.Append("<img src='{{site.baseurl}}{% link " + fn.Replace("\\", "/") + " %}' referrerpolicy='no-referrer'/>"); // referrerpolicy is required to make images from googleusercontent.com work
					}
					var capt = thisParagraph.ImageCaption;

					// remove open and closed brackets:
					capt = capt.Remove(0, 1);
					capt = capt.Remove(capt.Length - 1, 1);
					capt = ConvertMarkdownLinksToHtml(capt);
					img.Append("<figcaption markdown='1'>" + capt + "\n</figcaption></figure>"); // gotta add \n before </figcaption> otherwise "figcaption" is taken as a code block.
					img.Append(postfix);
					outText.AppendLine(img.ToString());
					// to reference local, use {% link assets/images/palm.png %}
					// known deficiency: we dont generate alt texts

				}
				else // write a text block
				{
					var conv = ConvertMarkdownLinksToHtml(thisParagraph.HtmlText);


					// prefix must come after other html tags that might be used to start the line.
					// find the first character thats not whitespace or a html tag:
					int firstCharacterThatsNotTags = 0;
					bool inTag = false;
					for (int j = 0; j < conv.Length; j++)
					{
						if (conv[j] == ' ')
							continue;
						if (conv[j] == '<' || conv[j] == '[')
							inTag = true;
						if (conv[j] == '>' || conv[j] == ']')
						{
							inTag = false;
							continue;
						}
						if (!inTag)
						{
							firstCharacterThatsNotTags = j;
							break;
						}
					}
					conv = conv.Insert(firstCharacterThatsNotTags, prefix);
					outText.AppendLine(conv + postfix);
				}
			}
			#endregion

			while (listTags.Any())
				CloseList();



			WriteNavAnchor();


			#region navigation to the children - this is old code, these things are now handled via JavaScript.
			//int nrNavLinksCreated = 0;
			//bool weAlreadyHadAFeedbackLink = false;
			//void MakeNav(string text, string url, string icon = "&#10149;")
			//{
			//	if (url == "#feedback")
			//	{
			//		if (weAlreadyHadAFeedbackLink)
			//			return;
			//		weAlreadyHadAFeedbackLink = true;
			//	}
			//	string prefix = "";


			//	//outText.AppendLine($"<div>{icon} <a href='{prefix}{url}'>{text}</a></div>"); // TODO move to new system
			//	nrNavLinksCreated++;
			////}
			//void MakeNavFromDoc(string text, Document dc, string urlAppendix = "")
			//{
			//	MakeNav(text, GetDocumentLink(dc) + urlAppendix);
			//}


			// there are several ways to get links.

			// Option 1: Children get a link automatically.
			//foreach (var child in GetChildren(outputFiles, of))
			//	MakeNav(child.Headline, MakeUrl(child));

			// Option 2: linking to the next major-level argument. This is not useful.
			//if (of.HierarchyLevel == 0)
			//{
			//	var next = GetNextSiblingOrNull(outputFiles, of);
			//	if (next != null)
			//		outText.AppendLine(MakeNav(next.Headline, MakeUrl(next)));
			//}


			// Option 3: Make a normal markdown link but prepend it with "nav:"

			//List<Match> navMatches = markdownLinkNav.Matches(outText.ToString()).Cast<Match>().ToList();


			//foreach (var nm in navMatches)
			//{
			//	string title, url;
			//	(title, url) = ProcessMarkdownLink(nm.Groups[1].Value, nm.Groups[2].Value);
			//	MakeNav(title, url);
			//}




			//if (nrNavLinksCreated == 0)
			//{
			//	Console.WriteLine("No outgoing links at " + of.FilenameWithoutPathOrExtension + " - creating link back to parent");
			//	var parent = GetParent(outputFiles, of);
			//	if (parent == null)
			//	{
			//		//if (of!=lastHighlevelArticle)
			//		//	throw new NotImplementedException("All high-level sections must have outgoing links (except the last one): " + of.InternalID);
			//	}
			//	else
			//		MakeNavFromDoc("Go back", parent, "#argnav");
			//}

			//MakeNav("Send Feedback", "#feedback", "&#9993;");
			#endregion



			of.OutLines = markdownLinkNav.Replace(outText.ToString(), "");


		}

		#region resolving text blocks
		var textblockRegex = new Regex(@"(\[textblock:(.*?)\])([\s\S]*?)(\[\/textblock\])");// The dot matches all except newlines (\r\n). So use \s\S, which will match ALL characters
		string[] tagsThatNeedToBeBalanedWithinATextblock = new[] { "ul", "ol", "li" };
		var tagsRegex = new Regex("</?(" + string.Join('|', tagsThatNeedToBeBalanedWithinATextblock) + ")>");
		// part 1: capture
		foreach (var of in outputFiles)
		{
			foreach (Match match in textblockRegex.Matches(of.OutLines))
			{
				// bugfix update 2023-01-06: Currently, we do not capture closing list tags after a textblock. What would be the right behaviour?
				// --> let's simply count any open list-related tags and then close them properly at the end of a textblock.

				#region make sure tags are properly closed after the end of a textblock
				var txt = match.Groups[3].Value;
				bool thisTextblockIsJustOneBulletPoint = txt.StartsWith("<li>")&& txt.IndexOf("<li>", 4) == -1;
				if (thisTextblockIsJustOneBulletPoint)
					txt = txt.Replace("<li>", "").Replace("</li>", "");
				var tagStack = new Stack<string>();
				foreach (Match tr in tagsRegex.Matches(txt))


				{
					if (tr.Groups[0].Value.StartsWith("</")) // closing tag
					{
						if (tagStack.Count == 0)
							throw new InvalidOperationException("This textblock contains a closing HTML tag thats never opened");
						else if (tagStack.Peek() != tr.Groups[1].Value)
							throw new InvalidOperationException("This textblock contains a closing HTML tag without an opening tag at the right position");
						else
							tagStack.Pop();
					}
					else
						tagStack.Push(tr.Groups[1].Value);

				}

				while (tagStack.Count > 0) // close any unclosed tags
					txt = txt + "</" + tagStack.Pop() + ">";
				#endregion

				// remember the block
				textblocks[match.Groups[2].Value] = txt;

				// remove the [textblock:asdf] and [/textblock] tags from the output
				of.OutLines = of.OutLines.Replace(match.Groups[1].Value, "");
				of.OutLines = of.OutLines.Replace(match.Groups[4].Value, "");



			}
		}
		// part 2: replace
		var copyRgx = new Regex(@"\[copy:(.*?)\]");
		foreach (var of in outputFiles)
			of.OutLines = copyRgx.Replace(of.OutLines, m =>
			{
				if (!textblocks.ContainsKey(m.Groups[1].Value))
					throw new InvalidOperationException("Textblock not found: " + m.Groups[1].Value);
				return textblocks[m.Groups[1].Value];


			});
		#endregion


		foreach (var of in outputFiles)
		{
			if (of.OutLines.Contains("<blockquote>"))
			{
				// removing attributions from quotes
				of.OutLines = Regex.Replace(of.OutLines, @"<blockquote>([\S\s]*?)\<\/blockquote>",
				x => Regex.Replace(x.Value, @"\(.*\)", ""));
			}
		}

		foreach (var of in outputFiles)
		{

			Console.WriteLine(("Writing file " + of.FilenameWithoutPathOrExtension));
			File.WriteAllText(argumentsDir + of.FilenameWithoutPathOrExtension + pageFileExtension, of.JekyllFrontmatter + "\n" + of.OutLines);

		}

		File.WriteAllText(argumentsYamlFile, GetYamlDataForTOC(outputFiles));

		string startingUrl = "./"+outputFiles.First().FilenameWithoutPathOrExtension;
		File.WriteAllText(argumentsDir + "index.html", @$"<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv=""refresh"" content=""0; url='{startingUrl}'"" />
  </head>
  <body>
    <p>Please follow <a href=""{startingUrl}"">this link</a>.</p>
  </body>
</html>");


		#endregion

		if (Environment.MachineName == "LTLAP")
		{
			Console.WriteLine("Triggering Jekyll rebuild...");
			var jekyll = Process.Start(new ProcessStartInfo("bundle", "exec jekyll build")
			{
				UseShellExecute = true
			});
			jekyll.WaitForExit();
			if (jekyll.ExitCode != 0)
				throw new InvalidOperationException("Jekyll build failed");
		}
		else
		{
			Console.WriteLine("Please trigger jekyll rebuild, then press ENTER");
			Console.ReadLine();
		}


		foreach (var outputFile in Directory.GetFiles(argumentsDir))
		{
			var txt = File.ReadAllText(outputFile);
			// replace links to chapter IDs
			txt=Regex.Replace(txt, "###link:(.*?)###", match =>
			{
				var url = match.Groups[1].Value;
				var matchingPage = outputFiles.SingleOrDefault(o => o.InternalID.Equals(url, StringComparison.InvariantCultureIgnoreCase));
				if (matchingPage == null)
					throw new InvalidOperationException("This page ID was used in a link but not found: " + url);
				return GetDocumentLink(matchingPage);
				//if (title == "")
				//	title = matchingPage.Headline;
			}
			);

			File.WriteAllText(outputFile, txt);
		}

		Console.WriteLine("Checking local links...");
		foreach (var url in localLinkstoCHeck)
		{
			Console.Write("  Checking: " + url + " ...");
			var normalizedLinkTarget = url.Replace(".html", "")
				.Replace('/', Path.DirectorySeparatorChar); // this does nothing on linux, and replaced / with \ on Windows
			bool found = false;
			foreach (var ending in new[] { ".md", ".html" }) // both of these get turned into .html
			{
				// the file could be on disk (this is the case if we are looking at stuff outside the "arguments" dir)
				var fileOnDisk = Path.Combine(argumentsDir, normalizedLinkTarget + ending);
				if (File.Exists(fileOnDisk))
					found = true;

				// or it could be a section within this 
			}
			if (!found)
				throw new InvalidOperationException("Link target not found: " + url);

			Console.WriteLine("OK");

		}

		if (Environment.MachineName=="LTLAP")
		{

			Console.WriteLine("calling move_arguments.rb");
			var moveArguments = Process.Start(new ProcessStartInfo("ruby", "move_arguments.rb") { UseShellExecute = true, WorkingDirectory = baseDir + "tools\\" });
			moveArguments.WaitForExit();
			if (moveArguments.ExitCode != 0)
				throw new InvalidOperationException("move_arguments.rb failed");
		}
	}

	Document GetParent(List<Document> outputFiles, Document of)
	{
		for (int i = outputFiles.IndexOf(of); i >= 0; i--)
			if (outputFiles[i].HierarchyLevel == of.HierarchyLevel - 1)
				return outputFiles[i];
		return null;
	}

	string RemoveDoubleOccurences(char thingThatmustNotOccurDoubly, string sentence)
	{
		var sb = new StringBuilder();
		for (int i = 0; i < sentence.Length; i++)
		{
			if (i == 0 || sentence[i - 1] != sentence[i] || sentence[i] != thingThatmustNotOccurDoubly)
				sb.Append(sentence[i]);
		}
		return sb.ToString();
	}

	string DownloadImageAndReturnFilename(GDocsImage gdi)
	{
		if (gdi.ContentUrl.Contains("|"))
			throw new InvalidOperationException("Cannot reference images that contain the | character: " + gdi);
		if (!File.Exists(imageCacheFile))
			File.WriteAllText(imageCacheFile, "");

		var imgCacheLines = File.ReadLines(imageCacheFile).Select(l => l.Split('|'));
		var match = imgCacheLines.FirstOrDefault(l => l[0] == gdi.EmbeddedObjectId);
		if (match != null) // we already got it
		{
			return match[1];
		}

		using (var wc = new WebClient())
		{
			var bytes = wc.DownloadData(gdi.ContentUrl);
			var filename = GetMD5(bytes) + (GetFileExtensionFromUrl(gdi.ContentUrl) ?? ".png");
			File.AppendAllLines(imageCacheFile, new[] { gdi.EmbeddedObjectId + "|" + filename });
			File.WriteAllBytes(assetsDir + filename, bytes);
			return filename;
		}

	}

	static string GetFileExtensionFromUrl(string url)
	{
		url = url.Split('?')[0];
		url = url.Split('/').Last();
		return url.Contains('.') ? url.Substring(url.LastIndexOf('.')) : null;
	}
	string GetMD5(byte[] data)
	{
		using (var md5 = MD5.Create())
		{
			return BitConverter.ToString(md5.ComputeHash(data)).Replace("-", "");
		}
	}

	string MakeUrl(Document child)
	{
		return child.FilenameWithoutPathOrExtension; // DO NOT add .html to the links.
	}

	List<Document> GetChildren(List<Document> outputFiles, Document x)
	{
		var res = new List<Document>();
		for (int i = outputFiles.IndexOf(x) + 1; i < outputFiles.Count; i++)
		{
			if (outputFiles[i].HierarchyLevel == x.HierarchyLevel + 1)
				res.Add(outputFiles[i]);
			if (outputFiles[i].HierarchyLevel <= x.HierarchyLevel)
				break;
		}
		return res;
	}

	Document GetNextSiblingOrNull(List<Document> outputFiles, Document x)
	{
		return outputFiles.Skip(outputFiles.IndexOf(x) + 1)
		.FirstOrDefault(y => y.HierarchyLevel == x.HierarchyLevel);
	}

	string GetBreadcrumbs(List<Document> allDocs, Document currentDocument)
	{
		// syntax sample: "The Alignment Problem:the-alignment-problem,Test Before Deploying:test-before-deploying"
		System.Collections.Generic.List<Document> trail = new List<Document>();
		trail.Add(currentDocument);
		for (int i = allDocs.IndexOf(currentDocument); i >= 0; i--)
		{
			if (allDocs[i].HierarchyLevel == trail.Last().HierarchyLevel - 1)
				trail.Add(allDocs[i]);
		}
		trail.Reverse();
		return string.Join(",", trail.Select(t => t.ShorterHeadline.Replace(",", "").Replace(":", " - ") + ":" + t.FilenameWithoutPathOrExtension));
	}
	string GetYamlDataForTOC(List<Document> allDocs)
	{
		var sb = new StringBuilder();



		for (int i = 0; i < allDocs.Count; i++)
		{
			if (allDocs[i].ShorterHeadline == "hide")
				continue;

			var parent = GetParent(allDocs, allDocs[i]);

			int hierarchyLevelToUse = allDocs[i].HierarchyLevel;
			if (parent != null && parent.AddChildrenHere)
				hierarchyLevelToUse++;

			string prefix = new string(' ', hierarchyLevelToUse * 4);
			void writeIfNotNull(string key, string value)
			{
				if (value == null)
					return;
				sb.AppendLine(prefix + "  " + key + ": " + value);
			}



			string SanitizeForYaml(string x) => x.Replace(":", ". ");

			if (allDocs[i].ShorterHeadline.Contains("how might AGI be dangerous"))
				Console.WriteLine("dbg");

			sb.AppendLine(prefix + "- node:");
			writeIfNotNull("name", SanitizeForYaml(allDocs[i].ShorterHeadline));
			writeIfNotNull("url", "/" + folderInWebsite + "/" + allDocs[i].FilenameWithoutPathOrExtension);


			if (allDocs[i].Headline != allDocs[i].ShorterHeadline)
				allDocs[i].extraYamlData["text"] = SanitizeForYaml(allDocs[i].Headline);

			if (!allDocs[i].extraYamlData.ContainsKey("effect") && allDocs[i].HierarchyLevel == 0)
				allDocs[i].extraYamlData["effect"] = "calculated";


			foreach (var kvp in allDocs[i].extraYamlData)
				writeIfNotNull(kvp.Key, kvp.Value);




			writeIfNotNull("question", allDocs[i].Question);
			if (allDocs[i].Question != null && allDocs[i].Question.Contains("highly intelligent"))
				Console.WriteLine("asdf");

			writeIfNotNull("questionSubtext", allDocs[i].QuestionSubtext);

			if (parent != null && parent.QuestionIsSingleChoice)
				writeIfNotNull("overridesSiblings", "true");

			if (parent != null && parent.MakeButtonsForQuestionAnswers)
				writeIfNotNull("parentListingType", "button");



			if ((i + 1 < allDocs.Count && allDocs[i + 1].HierarchyLevel > allDocs[i].HierarchyLevel) || allDocs[i].ExtraYmlNavigation.Any())
				sb.AppendLine(prefix + "  nodes:");

			bool startNodesListBelow = false;
			if (allDocs[i].ExtraYmlNavigation.Any())
			{
				prefix = prefix + "    ";
				foreach (var eyd in allDocs[i].ExtraYmlNavigation)
				{
					sb.AppendLine(prefix + "- node:");
					foreach (var kvp in eyd)
					{
						if (kvp.Key == "add-children-here" && kvp.Value.Trim() == "true")
						{ // this is an internal option affecting the build script only
							allDocs[i].AddChildrenHere = true;
							startNodesListBelow = true;
							continue;
						}

						string v = kvp.Value;
						if (v.StartsWith("[") && v.EndsWith("]"))
						{
							var referringDocument = allDocs.FirstOrDefault(d => d.InternalID == v.Substring(1, v.Length - 2));
							if (referringDocument == null)
								throw new InvalidOperationException("Error: nav block refers to document ID of non-existent document - " + v);
							v = "/"+folderInWebsite+"/"+MakeUrl(referringDocument);
						}
						writeIfNotNull(kvp.Key, v);
					}
				}
			}
			if (startNodesListBelow)
				sb.AppendLine(prefix + "  nodes:");


		}
		return sb.ToString();
	}

	string GetEntireFile(List<string> lines)
	{
		return string.Join(Environment.NewLine, lines);
	}

	string StripHtml(string caption)
	{
		throw new NotImplementedException();
	}

	void ExitAndComplainAboutImageCaption(List<GDocsImage> imageUrls)
	{
		throw new InvalidOperationException($"Couldnt find caption for images {string.Join(" ", imageUrls)}. Every image must have a caption, that is written right next to it, and starts & ends with a bracket. You can also have several images next to each other and then one caption.");
	}

	// Define other methods and classes here

	enum ListTypeEnum { Bullet, Number };


	class GDocsImage
	{
		/// warning - this might be different each time you fetch the document
		public string ContentUrl { get; set; }
		public string EmbeddedObjectId { get; set; }
		public override string ToString()
		{
			return ContentUrl;
		}
	}

	class ContentParagraph
	{

		public List<GDocsImage> ImageUrls = new List<GDocsImage>();
		public string ImageCaption = "";
		public string HtmlText;
		public int? BulletLevel;
		public bool? Bold;

		public ListTypeEnum? BulletType;
		public ContentParagraph(string text)
		{

			HtmlText = text;
		}
		public override string ToString()
		{
			return HtmlText + " at bullet level " + BulletLevel;
		}
	}

	class Document
	{
		public List<Dictionary<string, string>> ExtraYmlNavigation = new List<System.Collections.Generic.Dictionary<string, string>>();
		public string Question;
		public bool QuestionIsSingleChoice = false;
		public bool MakeButtonsForQuestionAnswers = false;
		public string JekyllFrontmatter;
		public string OutLines;
		public int HierarchyLevel;
		public string FilenameWithoutPathOrExtension, Headline, ShorterHeadline, InternalID;
		public bool AddChildrenHere = false;

		public Dictionary<string, string> extraYamlData = new Dictionary<string, string>();


		public List<ContentParagraph> Content = new List<ContentParagraph>();

		public string QuestionSubtext;
	}


	static string EverythingBefore(string s, string findStr)
	{
		int index = s.IndexOf(findStr);
		if (index == -1)
			return s;
		else
			return s.Substring(0, index);
	}

	static string EverythingAfter(string s, string findCh)
	{
		int index = s.IndexOf(findCh);
		if (index == -1)
			return s;

		index += findCh.Length;
		if (index >= s.Length)
			return "";
		else
			return s.Substring(index);
	}

	static string CamelToDash(string str)
	{
		return string.Concat(str.Select((x, i) => i > 0 && char.IsUpper(x) && !char.IsUpper(str[i - 1]) ? "-" + x.ToString() : x.ToString())).ToLower();
	}

	static string Between(string content, string startMarker, string endMarker)
	{
		var index = content.IndexOf(startMarker);
		if (index == -1)
			return "";

		int startOfTextWeWant = index + startMarker.Length;

		if (startOfTextWeWant >= content.Length)
			return "";
		int end = content.IndexOf(endMarker, startOfTextWeWant);

		if (end == -1)
			return content.Substring(startOfTextWeWant);
		else
			return content.Substring(startOfTextWeWant, end - startOfTextWeWant);
	}
}