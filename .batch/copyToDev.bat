.batch\kOS-Generic.ffs_batch
timeout /t 1 /nobreak
:: Regex explaination
:::::::::::::::::::::::
:: ($1 first block ensures string literals are not touched in any way.) |
:: ($2 second block similarly preserves // #comment-directives.) |
:: third block catches line comments. |
:: fourth catches leading (whitespace). |
:: fifth catches trailing (whitespace). |
:: sixth block looks for (whitespace) in front of ($6[operators] or| a .) followed by (whitespace),
::     but preserves the space after a . for multiple commands in one line |
:: last group does a (?<=lookbehind) to find multiple consecutive (whitespace) and reduce to one character,
::     to collapse alignments that aren't attached to operators
:: Remember to replace with $1$2$6 or it will remove strings, comment-directives and operators
:: Designed to minify kOS scripts. kOS does not permit escaped quotes, so no considerations are made to account for them. If needed, modify the first capture group.
.batch\fnr.exe --cl --dir "D:\KSP\KSP_1.10.1_KOS\Ships\Script" --fileMask "*.ks" --excludeFileMask "*.dll, *.exe" --includeSubDirectories --useRegEx --find "/(""[^""]*"")|(\/\/ #.*)| *?\/\/.*|^( |\t)*|( |\t)*$|( |\t)*([/*\-+=^<>{}()\[\],:]|\. ?)( |\t)*|(?<= |\t)( |\t)+/gm" --replace "$1$2$6"