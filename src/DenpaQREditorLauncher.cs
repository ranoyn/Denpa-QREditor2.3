using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using System.Reflection;

[assembly: AssemblyTitle("Denpa QREditor2.3 1.0.1")]
[assembly: AssemblyProduct("Denpa QREditor2.3")]
[assembly: AssemblyVersion("1.0.1.0")]
[assembly: AssemblyFileVersion("1.0.1.0")]

internal static class DenpaQREditorLauncher
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool DeleteFile(string fileName);

    private static void UnblockFiles(string directory)
    {
        try
        {
            foreach (string file in Directory.GetFiles(directory, "*", SearchOption.AllDirectories))
            {
                try
                {
                    // Explorer propagates the downloaded ZIP's Mark-of-the-Web
                    // to extracted DLL/EXE files. .NET Framework then rejects
                    // Assembly.LoadFrom with HRESULT 0x80131515. Removing only
                    // the Zone.Identifier stream is equivalent to Unblock-File.
                    string zoneStream = file + ":Zone.Identifier";
                    // The managed File.Exists/File.Delete APIs are not reliable
                    // for NTFS alternate data streams on .NET Framework 4.
                    // DeleteFileW directly removes this one stream and leaves
                    // the downloaded file itself untouched.
                    DeleteFile(zoneStream);
                }
                catch { }
            }
        }
        catch { }
    }

    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string script = Path.Combine(root, "_app", "DenpaQREditor.ps1");
        if (!File.Exists(script))
        {
            MessageBox.Show(
                "起動に必要な内部ファイルが見つかりません。\nZIPの中から直接起動せず、先にフォルダーをすべて展開してから Denpa QREditor2.3 1.0.1.exe を開いてください。\n_appフォルダーは移動・改名・削除しないでください。",
                "Denpa QREditor2.3 1.0.1",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 2;
        }

        // Diagnose missing scripts before PowerShell starts. Never recreate a
        // quarantined file or change antivirus settings automatically.
        string[] requiredScripts = { "DenpaQREditor.ps1", "Denpa1QREditor.ps1", "Denpa2QREditor.ps1", "Denpa3QREditor.ps1" };
        var missing = new StringBuilder();
        foreach (string file in requiredScripts)
            if (!File.Exists(Path.Combine(root, "_app", file))) missing.AppendLine(file);
        bool checkOnly = args != null && Array.IndexOf(args, "--check-files") >= 0;
        if (missing.Length > 0)
        {
            if (!checkOnly) MessageBox.Show(
                "Required files are missing / 必須ファイルが見つかりません:\n\n" + missing.ToString() +
                "\nExtract the complete ZIP. If files disappeared after extraction, check your security software's protection/quarantine history and send the detection name. Do not disable protection.\n\nZIPをすべて展開してください。展開後に消えた場合は、セキュリティソフトの保護・隔離履歴を確認し、検出名をお知らせください。保護を無効にしないでください。",
                "Denpa QREditor2.3", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 5;
        }
        if (checkOnly) return 0;

        UnblockFiles(Path.Combine(root, "_app"));

        // Internal diagnostic switch used to verify downloaded-file
        // unblocking without starting the editor UI.
        if (args != null && Array.IndexOf(args, "--unblock-only") >= 0)
            return 0;

        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string powershell = Path.Combine(windows, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
        if (!File.Exists(powershell))
            powershell = Path.Combine(windows, "SysWOW64", "WindowsPowerShell", "v1.0", "powershell.exe");
        if (!File.Exists(powershell))
        {
            MessageBox.Show("Windows PowerShellが見つかりません。", "Denpa QREditor2.3 1.0.1", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 3;
        }

        var errors = new StringBuilder();
        var start = new ProcessStartInfo
        {
            FileName = powershell,
            Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + script.Replace("\"", "\\\"") + "\"",
            WorkingDirectory = root,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardError = true
        };
        if (args != null && Array.IndexOf(args, "--smoke") >= 0)
        {
            // Some Windows environments contain both Path and PATH. Accessing
            // ProcessStartInfo.EnvironmentVariables then throws while building
            // its case-insensitive dictionary, so set the launcher's own
            // environment and let the child inherit it instead.
            Environment.SetEnvironmentVariable("DENPA_UNIFIED_EDITOR_SMOKE", "startup");
        }

        try
        {
            using (var process = new Process { StartInfo = start })
            {
                process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e)
                {
                    if (!String.IsNullOrWhiteSpace(e.Data)) errors.AppendLine(e.Data);
                };
                process.Start();
                process.BeginErrorReadLine();
                process.WaitForExit();
                if (process.ExitCode != 0)
                {
                    string detail = errors.ToString().Trim();
                    if (detail.Length > 1200) detail = detail.Substring(0, 1200);
                    MessageBox.Show(
                        "エディタを起動できませんでした。" + (detail.Length > 0 ? "\n\n" + detail : ""),
                        "Denpa QREditor2.3 1.0.1",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                }
                return process.ExitCode;
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show("エディタを起動できませんでした。\n\n" + ex.Message, "Denpa QREditor2.3 1.0.1", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 4;
        }
    }
}
