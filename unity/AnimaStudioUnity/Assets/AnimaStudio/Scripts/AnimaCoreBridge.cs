using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Threading;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Debug = UnityEngine.Debug;

namespace AnimaStudio
{
    /// <summary>
    /// C# client for the canonical AnimaCore Python engine. It launches
    /// <c>python -m animacore.bridge</c> and speaks newline-delimited JSON over
    /// stdio — byte-for-byte the same protocol the Swift <c>AnimaCoreClient</c>
    /// uses. The engine stays the single source of truth; this is a thin port of
    /// the front-end. Nothing here reimplements mate/kinematics/animation logic.
    ///
    /// Threading: a background thread reads stdout and enqueues raw lines. Call
    /// <see cref="TryReadResponse"/> from the Unity main thread (e.g. Update) to
    /// drain them — so all JSON parsing and Unity API use stays on the main thread.
    /// </summary>
    public sealed class AnimaCoreBridge : IDisposable
    {
        Process _process;
        StreamWriter _stdin;
        Thread _reader;
        volatile bool _running;
        readonly ConcurrentQueue<string> _incoming = new ConcurrentQueue<string>();
        int _nextId = 1;

        public bool IsRunning => _running && _process != null && !_process.HasExited;

        /// <summary>
        /// Launch the engine. <paramref name="repoRoot"/> must contain the
        /// <c>animacore/</c> package (and ideally the project's <c>.venv</c>).
        /// </summary>
        public void Start(string repoRoot)
        {
            string python = ResolvePython(repoRoot);
            var psi = new ProcessStartInfo
            {
                FileName = python,
                Arguments = "-m animacore.bridge",
                WorkingDirectory = repoRoot,
                UseShellExecute = false,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            };
            psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1";

            _process = Process.Start(psi);
            _stdin = _process.StandardInput;
            _running = true;

            _reader = new Thread(ReadLoop) { IsBackground = true, Name = "AnimaCoreReader" };
            _reader.Start();

            _process.ErrorDataReceived += (_, e) =>
            {
                if (!string.IsNullOrEmpty(e.Data)) Debug.LogWarning("[animacore] " + e.Data);
            };
            _process.BeginErrorReadLine();
        }

        void ReadLoop()
        {
            try
            {
                string line;
                while (_running && (line = _process.StandardOutput.ReadLine()) != null)
                {
                    if (line.Length > 0) _incoming.Enqueue(line);
                }
            }
            catch (Exception e)
            {
                if (_running) Debug.LogWarning("animacore reader stopped: " + e.Message);
            }
        }

        /// <summary>Drain one response the engine has sent. Call from the main thread.</summary>
        public bool TryReadResponse(out JObject response)
        {
            response = null;
            while (_incoming.TryDequeue(out string line))
            {
                try
                {
                    response = JObject.Parse(line);
                    return true;
                }
                catch (Exception e)
                {
                    Debug.LogWarning("bad JSON from animacore: " + e.Message + " :: " + line);
                }
            }
            return false;
        }

        /// <summary>
        /// Send a request. Returns the id used; match responses by <c>["id"]</c>.
        /// </summary>
        public string Send(string method, JObject prms = null)
        {
            if (!IsRunning)
            {
                Debug.LogError("animacore is not running; cannot send '" + method + "'");
                return null;
            }
            string id = (_nextId++).ToString();
            var request = new JObject
            {
                ["id"] = id,
                ["method"] = method,
                ["params"] = prms ?? new JObject(),
            };
            _stdin.WriteLine(request.ToString(Formatting.None));
            _stdin.Flush();
            return id;
        }

        public static string ResolvePython(string repoRoot)
        {
            string[] candidates =
            {
                Path.Combine(repoRoot, ".venv", "bin", "python"),        // macOS / Linux
                Path.Combine(repoRoot, ".venv", "Scripts", "python.exe"), // Windows
            };
            foreach (string candidate in candidates)
            {
                if (File.Exists(candidate)) return candidate;
            }
            // Fall back to whatever `python3` / `python` is on PATH.
            return OperatingSystemIsWindows() ? "python" : "python3";
        }

        static bool OperatingSystemIsWindows() =>
            Environment.OSVersion.Platform == PlatformID.Win32NT;

        public void Stop()
        {
            _running = false;
            try
            {
                if (_process != null && !_process.HasExited)
                {
                    Send("shutdown");
                    _process.WaitForExit(500);
                }
            }
            catch { }
            try
            {
                if (_process != null && !_process.HasExited) _process.Kill();
            }
            catch { }
            _process?.Dispose();
            _process = null;
        }

        public void Dispose() => Stop();
    }
}
