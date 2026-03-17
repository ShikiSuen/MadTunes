#load "./../.dotnet-tools.install.csx"  // optional, if you use dotnet-script with tool manifest

using System.IO;
using System.Text;

const string DefaultOutputFileName = "swift_sources_dump.txt";

static void PrintUsage()
{
    Console.WriteLine("Usage: dotnet script CatSwiftFiles.csx [rootDir] [outputFile]");
    Console.WriteLine();
    Console.WriteLine("Arguments:");
    Console.WriteLine("  rootDir     The root directory to scan for .swift files (defaults to current directory)");
    Console.WriteLine($"  outputFile  The output text file to write (defaults to '{DefaultOutputFileName}' in rootDir)");
}

var args = args ?? Array.Empty<string>();
if (args.Length > 0 && (args[0] == "-h" || args[0] == "--help"))
{
    PrintUsage();
    return;
}

var rootDir = args.Length >= 1 ? args[0] : Directory.GetCurrentDirectory();
var outputFile = args.Length >= 2
    ? args[1]
    : Path.Combine(rootDir, DefaultOutputFileName);

rootDir = Path.GetFullPath(rootDir);
outputFile = Path.GetFullPath(outputFile);

if (!Directory.Exists(rootDir))
{
    Console.Error.WriteLine($"ERROR: Root directory does not exist: {rootDir}");
    return;
}

Console.WriteLine($"Scanning for .swift files under: {rootDir}");

var swiftFiles = Directory.EnumerateFiles(rootDir, "*.swift", SearchOption.AllDirectories)
    .OrderBy(p => p, StringComparer.OrdinalIgnoreCase)
    .ToList();

if (swiftFiles.Count == 0)
{
    Console.WriteLine("No .swift files found.");
    return;
}

Console.WriteLine($"Found {swiftFiles.Count} .swift files.");

using var outputStream = new FileStream(outputFile, FileMode.Create, FileAccess.Write, FileShare.Read);
using var writer = new StreamWriter(outputStream, new UTF8Encoding(false));

writer.WriteLine($"# Swift sources dump generated {DateTime.UtcNow:O}");
writer.WriteLine($"# Root: {rootDir}");
writer.WriteLine($"# Files: {swiftFiles.Count}");
writer.WriteLine();

foreach (var swiftFile in swiftFiles)
{
    var relativePath = Path.GetRelativePath(rootDir, swiftFile).Replace(Path.DirectorySeparatorChar, '/');

    writer.WriteLine($"--- file: {relativePath} ---");
    writer.WriteLine();
    writer.WriteLine("```swift");
    writer.Write(File.ReadAllText(swiftFile));
    writer.WriteLine();
    writer.WriteLine("```");
    writer.WriteLine();
}

writer.Flush();
Console.WriteLine($"Wrote file: {outputFile}");
