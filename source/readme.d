/**
    A command line utility for reading GitHub-flavored Markdown files.

    Author: Jonathan M. Wilbur
    Copyright: Jonathan M. Wilbur
    Date: May 8th, 2017
    License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Standards:
        $(LINK2 https://guides.github.com/features/mastering-markdown/, Mastering Markdown)
    Version: 0.1.1
    See_Also:
        $(LINK2 https://en.wikipedia.org/wiki/Markdown, Wikipedia Page for Markdown)
*/
import std.getopt;
import std.conv : ConvException;
import std.file : readText, exists, isFile, FileException;
import std.stdio : write, writeln, writefln, stdout;
import std.path : isValidFilename, isValidPath, isAbsolute, absolutePath, buildPath;
import std.string : fromStringz, replace;
import core.stdc.stdlib : getenv, EXIT_FAILURE, EXIT_SUCCESS; //Is there any way to do all of this stuff without C?
import std.array : split;
import std.utf : UTFException;

// NOTE: You should try to keep the color-scheme friendly to RG color-blind folks.

// ANSI Escape Codes - Styles
immutable string resetEscape = "\x1B[0m";
immutable string boldEscape = "\x1B[1m";
immutable string faintEscape = "\x1B[2m";
immutable string italicEscape = "\x1B[3m";
immutable string underlineEscape = "\x1B[4m";
immutable string negativeEscape = "\x1B[7m"; // I'm not sure if this one will work.
immutable string strikethroughEscape = "\x1B[9m";
immutable string normalEscape = "\x1B[22m";

// ANSI Escape Codes - Foreground Colors
immutable string blackTextEscape = "\x1B[30m";
immutable string redTextEscape = "\x1B[31m";
immutable string greenTextEscape = "\x1B[32m";
immutable string yellowTextEscape = "\x1B[33m";
immutable string blueTextEscape = "\x1B[34m";
immutable string magentaTextEscape = "\x1B[35m";
immutable string cyanTextEscape = "\x1B[36m";
immutable string whiteTextEscape = "\x1B[37m";

// ANSI Escape Codes - Background Colors
immutable string blackBackgroundEscape = "\x1B[40m";
immutable string redBackgroundEscape = "\x1B[41m";
immutable string greenBackgroundEscape = "\x1B[42m";
immutable string yellowBackgroundEscape = "\x1B[43m";
immutable string blueBackgroundEscape = "\x1B[44m";
immutable string magentaBackgroundEscape = "\x1B[45m";
immutable string cyanBackgroundEscape = "\x1B[46m";
immutable string whiteBackgroundEscape = "\x1B[47m";

bool colorOutput = false;
bool styleOutput = false;
bool pageOutput = false;

int main (string[] args)
{

    // Retrieve and Parse Environment Variables
    string colorOutputEnvVar = cast(string) fromStringz(getenv("COLOR"));
    colorOutput = (colorOutputEnvVar == "true" ? true : false);

    string styleOutputEnvVar = cast(string) fromStringz(getenv("STYLE"));
    styleOutput = (styleOutputEnvVar == "true" ? true : false);

    string pagerEnvVar = cast(string) fromStringz(getenv("PAGER"));
    string pageOutputEnvVar = cast(string) fromStringz(getenv("PAGINATE"));
    pageOutput = (pageOutputEnvVar == "true" && pagerEnvVar != "" ? true : false);

    string readmePath = cast(string) fromStringz(getenv("READMEPATH"));

    // Override them with command line options
    /*
        Potential option ideas:
        p|path          Path
        b|blocks        Show code blocks
        x|section       Section
    */
    // NOTE: '-h' and '--help' are reserved.
    try
    {
        GetoptResult getOptResult = getopt(
            args,
            std.getopt.config.caseInsensitive,
            std.getopt.config.bundling,
            "c|color", &colorOutput,
            "p|page", &pageOutput,
            "s|styleOutput", &styleOutput
        );

        if (getOptResult.helpWanted)
        {
            defaultGetoptPrinter(
                "Usage syntax:\n\treadme [options ...] topic|program|file",
                getOptResult.options);
        }
    }
    catch (ConvException ce)
    {
        writeln("Command line arguments could not be parsed.");
    }
    catch (GetOptException goe)
    {
        writeln(goe.msg);
    }

    debug
    {
        writeln("Color Output: ", colorOutput);
        writeln("Paginated Output: ", pageOutput);
        writeln("Style Output: ", styleOutput);
    }

    if (args.length != 2)
    {
        writeln("You must specify a topic, program, or file to lookup.");
        return(EXIT_FAILURE);
    }

    // Strip ".md" from the file if the user appended it.
    if (args[1][$-4 .. $-1] == ".md") args[1] = args[1][0 .. $-4];

    debug writeln("Opening ", args[1]);

    if (!isValidFilename(args[1]))
    {
        writeln("Invalid file name. Readme aborted.");
        return(EXIT_FAILURE);
    }

    string[] readmeDirectories = [ absolutePath(".") ];
    string readmeFile;

    if (readmePath) readmeDirectories ~= split(readmePath,':');

    foreach (dir; readmeDirectories)
    {
        if (!dir.isValidPath)
        {
            writeln("Invalid directory specified in READMEPATH environment variable! Readme aborted.");
            return(EXIT_FAILURE);
        }
        if (!dir.isAbsolute)
        {
            writeln("All paths in READMEPATH environment variable must be absolute. Readme aborted.");
            return(EXIT_FAILURE);
        }
    }

    foreach (dir; readmeDirectories)
    {
        string pathy = buildPath(dir, (args[$-1] ~ ".md"));
        if (exists(pathy))
        {
            try
            {
                if (isFile(pathy))
                {
                    readmeFile = pathy;
                    break;
                }
            }
            catch (FileException fe) // isFile(x) emits a FE when x is not a file.
            {
                continue;
            }
        }
    }

    if (!readmeFile)
    {
        writeln(
            "No matching readme / markdown pages could be found with the name: '", args[1], "'.\n" ~
            "Check to see that you spelled the name of the readme correctly.\n" ~
            "If you have spelled the name correctly, check the $READMEPATH environment variable.\n" ~
            "$READMEPATH should be set to a colon-delimited list of paths where readme pages can be found.\n" ~
            "If $READMEPATH is not set, manu will just search the current directory for readme pages."
        );
        return(EXIT_FAILURE);
    }

    string readme;
    try
    {
        readme = readText(readmeFile);
    }
    catch (FileException fe)
    {
        writeln("File cannot be opened or read. Readme aborted.");
    }
    catch (UTFException utfe)
    {
        writeln("UTF decoding error while trying to open file. Readme aborted.");
    }

    debug(1)
    {
        writeln(readme);
    }

    /*
        Some pagers, such as less, do not support color and styling unless you
        pass in the '-R' option. It might be advantageous to check stdout with
        std.file.getAttributes to determine if the output is being piped into
        something. I don't know quite how to do that, since D does not have
        istty(file) or S_ISFIFO.

        It may be helpful to set the $PAGER environment variable to "less -R"
        instead of "less" so that it always puts out color.
    */

    // This is where the output begins.

    // Parsing States
    bool quoted = false;
    // bool link = false;
    // bool blockquote = false;
    // bool italic = false;
    // bool bold = false;
    // bool orderedList = false;
    // bool unorderedList = false;
    // bool inlineCode = false;
    // bool taskList = false;
    // bool strikethrough = false;
    // bool emoji = false;
    // bool username = false; // @username

    // enum ParsingState
    // {
    //     h1,
    //     h2,
    //     h3,
    //     h4,
    //     h5,
    //     h6,
    //     quoted,
    //     link,
    //     blockquote,
    //     italic,
    //     bold,
    //     orderedList,
    //     unorderedList,
    //     inlineCode,
    //     taskList,
    //     strikethrough,
    //     emoji,
    //     username,
    //     tableHeader,
    //     tableRow,
    //     image // TODO: This should take the Alt Text of the image, if present.
    // }
    //
    // ParsingState[] currentStates;

    string[] readmeLines = readme.replace("\r", "").split("\n");
    foreach(line; readmeLines)
    {
        int headerLevel;
        foreach(column; [0, 1, 2, 3, 4, 5])
        {
            if (line.length > column && line[column] == '#') headerLevel++;
        }

        // Check if line STARTS with '```'
        if (line == "```")
        {
            quoted = !quoted;
            writeln();
            continue;
        }

        if (line == "---")
        {
            writeln();
            continue;
        }

        if (quoted)
        {
            writeln("\t\x1B[2m", line, "\x1B[0m");
        }
        else
        {
            switch (headerLevel)
            {
                // TODO: Figure out a better way to distinguish headers
                case 1:
                {
                    // writeln("\n\x1B[1;4m", line[headerLevel+1 .. $], "\x1B[0m\n");
                    writeln("\n", boldEscape, underlineEscape, line[headerLevel+1 .. $], resetEscape);
                    break;
                }
                case 2:
                {
                    writeln("\n", boldEscape, underlineEscape, line[headerLevel+1 .. $], resetEscape);
                    break;
                }
                case 3:
                {
                    writeln("\n", boldEscape, line[headerLevel+1 .. $], resetEscape);
                    break;
                }
                case 4:
                {
                    writeln("\n", boldEscape, line[headerLevel+1 .. $], resetEscape);
                    break;
                }
                case 5:
                {
                    writeln("\n", boldEscape, line[headerLevel+1 .. $], resetEscape);
                    break;
                }
                case 6:
                {
                    writeln("\n", boldEscape, line[headerLevel+1 .. $], resetEscape);
                    break;
                }
                default:
                {
                    if (line.length > 2 && line[0] == '>' && line[1] == ' ')
                    {
                        writeln(italicEscape, line, resetEscape);
                    }
                    else
                    {
                        writeln(line);
                    }
                }
            }
        }

    }

    return(EXIT_SUCCESS);
}
