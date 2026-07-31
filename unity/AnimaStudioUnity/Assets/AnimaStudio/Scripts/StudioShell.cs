using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace AnimaStudio
{
    /// <summary>
    /// The AnimaStudio Unity app shell, mirroring the Swift app's workspace
    /// model: header tabs (Assets · 3D Modeling · Animate · Show · Hardware),
    /// a contextual toolbar, left navigator, right inspector, and a bottom
    /// transport bar in Animate. Everything semantic goes through the canonical
    /// Python engine bridge — load/serialize, resolve_pose (clip playback +
    /// live dof_values posing), mate_types/add_mate/remove_mate. Nothing here
    /// reimplements animation/mate/kinematics logic.
    /// </summary>
    public sealed class StudioShell : MonoBehaviour
    {
        [Tooltip("Path to a .character.anima file, relative to the repo root. "
            + "Empty = start with no character (import a STEP or open one).")]
        public string characterPath = "";

        // ---- engine ----
        AnimaCoreBridge _bridge;
        string _repoRoot;
        string _handle;
        string _loadReqId;
        string _poseReqId;
        string _mateTypesReqId;
        string _authorReqId;
        bool _poseDirty;
        string _status = "starting…";
        bool _engineFailed;

        // ---- rig model (from the load_character summary; display only) ----
        sealed class PartInfo
        {
            public string name;
            public string parent;
            public string model;
            public string modelNode;
            public string description;
            public bool suppressed;
            public bool grounded;
            public float[] positionM = { 0f, 0f, 0f };
            public float[] rotationEulerRad = { 0f, 0f, 0f };
            public int depth;
            public GameObject go;

            /// <summary>The full-entry DTO `add_part`/`update_part` take.</summary>
            public JObject ToDto() => new JObject
            {
                ["name"] = name,
                ["parent"] = string.IsNullOrEmpty(parent) ? null : parent,
                ["model"] = model,
                ["model_node"] = string.IsNullOrEmpty(modelNode) ? null : modelNode,
                ["description"] = description ?? "",
                ["suppressed"] = suppressed,
                ["grounded"] = grounded,
                ["position_m"] = new JArray(positionM[0], positionM[1], positionM[2]),
                ["rotation_euler_rad"] = new JArray(
                    rotationEulerRad[0], rotationEulerRad[1], rotationEulerRad[2]),
            };
        }

        sealed class MateInfo
        {
            public string name;
            public string type;
            public string parentPart;
            public string childPart;
            public bool suppressed;
            public readonly List<string> dofPaths = new List<string>();
        }

        sealed class DofInfo
        {
            public string path;
            public float min;      // slider range; unlimited DOF get neutral ± π
            public float max;
            public float neutral;
            public float shown;    // current slider position
            public bool touched;   // user override active
        }

        sealed class ClipInfo
        {
            public string name;
            public float durationS;
            public bool loop;
        }

        readonly List<PartInfo> _parts = new List<PartInfo>();
        readonly List<MateInfo> _mates = new List<MateInfo>();
        readonly List<string> _relations = new List<string>();
        readonly List<DofInfo> _dofs = new List<DofInfo>();
        readonly List<ClipInfo> _clips = new List<ClipInfo>();
        string _characterName = "";
        string _characterDescription = "";

        // ---- selection: parts multi-select (click/box), mates single ----
        enum SelKind { None, Part, Mate }
        SelKind _selKind = SelKind.None;
        string _selName;                 // mate selection
        readonly HashSet<string> _selectedParts = new HashSet<string>();
        readonly HashSet<string> _matedChildren = new HashSet<string>();

        // ---- viewport drag (move a FREE part) + box select ----
        PartInfo _dragPart;
        bool _dragMoved;
        Vector3 _grabOffset;
        bool _boxSelecting;
        Vector2 _boxStart;               // GUI space

        // ---- move gizmo (Onshape-style axis arrows on the selection) ----
        GameObject _gizmo;
        string _gizmoAxis;               // "X"/"Y"/"Z" while dragging
        Vector3 _gizmoAxisDir;
        Vector3 _gizmoStartPartPos;
        float _gizmoGrabT;

        static readonly (string name, Vector3 dir, Color color)[] GizmoAxes =
        {
            ("X", Vector3.right, new Color(0.86f, 0.26f, 0.26f)),
            ("Y", Vector3.up, new Color(0.30f, 0.72f, 0.32f)),
            ("Z", Vector3.forward, new Color(0.24f, 0.44f, 0.92f)),
        };

        void EnsureGizmo()
        {
            if (_gizmo != null) return;
            _gizmo = new GameObject("MoveGizmo");
            foreach (var (axisName, dir, color) in GizmoAxes)
            {
                var shaft = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
                shaft.name = "GizmoAxis:" + axisName;
                shaft.transform.SetParent(_gizmo.transform, false);
                shaft.transform.localScale = new Vector3(0.05f, 0.5f, 0.05f);
                shaft.transform.localRotation = Quaternion.FromToRotation(Vector3.up, dir);
                shaft.transform.localPosition = dir * 0.5f;
                shaft.GetComponent<MeshRenderer>().sharedMaterial = MakeMaterial(color);
                var tip = GameObject.CreatePrimitive(PrimitiveType.Cube);
                tip.name = "GizmoAxis:" + axisName;
                tip.transform.SetParent(_gizmo.transform, false);
                tip.transform.localScale = new Vector3(0.12f, 0.12f, 0.12f);
                tip.transform.localRotation = Quaternion.FromToRotation(Vector3.up, dir);
                tip.transform.localPosition = dir * 1.05f;
                tip.GetComponent<MeshRenderer>().sharedMaterial = MakeMaterial(color);
            }
            _gizmo.SetActive(false);
        }

        PartInfo GizmoTarget()
        {
            if (_selectedParts.Count != 1 || _mateOpen) return null;
            foreach (string name in _selectedParts)
            {
                PartInfo part = _parts.Find(p => p.name == name);
                if (part == null || part.go == null || part.grounded
                    || _matedChildren.Contains(part.name))
                    return null;
                return part;
            }
            return null;
        }

        void UpdateGizmoTarget()
        {
            EnsureGizmo();
            _gizmo.SetActive(GizmoTarget() != null);
        }

        void UpdateGizmoTransform()
        {
            if (_gizmo == null || !_gizmo.activeSelf) return;
            PartInfo target = GizmoTarget();
            if (target == null) { _gizmo.SetActive(false); return; }
            var renderer = target.go.GetComponent<Renderer>();
            _gizmo.transform.position = renderer != null
                ? renderer.bounds.center : target.go.transform.position;
            var orbit = Camera.main != null
                ? Camera.main.GetComponent<CameraOrbit>() : null;
            float scale = orbit != null ? orbit.distance * 0.14f : 0.08f;
            _gizmo.transform.localScale = Vector3.one * Mathf.Max(0.02f, scale);
        }

        /// <summary>Axis parameter of the point on `axis through origin` closest
        /// to the mouse ray — the standard skew-line closest-point formula.</summary>
        static float AxisGrabT(Ray mouse, Vector3 origin, Vector3 axisDir)
        {
            Vector3 w = origin - mouse.origin;
            float b = Vector3.Dot(axisDir, mouse.direction);
            float d = Vector3.Dot(axisDir, w);
            float e = Vector3.Dot(mouse.direction, w);
            float denominator = 1f - b * b;
            if (Mathf.Abs(denominator) < 1e-5f) return 0f;
            return (b * e - d) / denominator;
        }

        // ---- workspaces ----
        enum Workspace { Assets, Modeling, Animate, Show, Hardware }
        static readonly string[] WorkspaceTitles =
            { "Assets", "3D Modeling", "Animate", "Show", "Hardware" };
        Workspace _workspace = Workspace.Modeling;

        // ---- mate dialog (Onshape-style popup) ----
        sealed class ConnectorPick
        {
            public string part;
            public float[] originM;    // engine part-local metres
            public float[] primary;    // engine part-local unit axes
            public float[] secondary;
            public GameObject gizmo;   // XYZ triad in the viewport
        }

        readonly List<JObject> _mateTypes = new List<JObject>(); // kinematic schemas
        bool _mateOpen;
        int _mateType;
        bool _mateTypeListOpen;
        readonly List<ConnectorPick> _matePicks = new List<ConnectorPick>();
        bool _mateOffsetOn;
        string _mateOffsetField = "0";
        bool _mateFlip;
        int _mateSecondaryRot;
        bool _mateSimConn = true;
        string _previewReqId;

        // Hover ghost + snap memo for connector placement.
        GameObject _ghostTriad;
        Mesh _lastSnapMesh;
        int _lastSnapTri = -1;
        MeshSnapping.Snap _lastSnap;

        // ---- asset library ----
        readonly List<string> _characterFiles = new List<string>(); // repo-relative
        readonly List<string> _meshFiles = new List<string>();      // absolute paths
        string _importField = "";
        string _newAssemblyField = "my_robot";

        // ---- authoring pipeline ----
        JObject _lastRig;                                   // serialize input
        string _saveReqId;
        // Serialized authoring sends: {method, params} pairs, one in flight.
        readonly Queue<JObject> _authorQueue = new Queue<JObject>();

        static JObject Author(string method, JObject prms) =>
            new JObject { ["method"] = method, ["params"] = prms };
        System.Threading.Thread _stepThread;
        volatile string _stepResult;                        // converter stdout JSON
        volatile string _stepError;

        // ---- transport ----
        int _activeClip = -1;
        bool _playing;
        float _timeS;

        // ---- UI state (dock variant: icon rails + collapsible tabbed panels) ----
        string _pathField;
        Vector2 _leftScroll;
        Vector2 _rightScroll;
        bool _leftOpen = true;
        bool _rightOpen = true;
        int _rightTab;                                   // 0 Inspector · 1 View
        readonly Dictionary<Workspace, int> _leftTab = new Dictionary<Workspace, int>();

        static readonly Dictionary<Workspace, string[]> LeftTabs =
            new Dictionary<Workspace, string[]>
            {
                { Workspace.Assets, new[] { "PROJ" } },
                { Workspace.Modeling, new[] { "PROJ" } },
                { Workspace.Animate, new[] { "PROJ" } },
                { Workspace.Show, new[] { "SCENE" } },
                { Workspace.Hardware, new[] { "DEV" } },
            };

        // Project-tree fold state (Onshape-style disclosure rows).
        bool _foldParts = true, _foldMates = true, _foldRelations,
            _foldClips = true, _foldAssets = true, _foldExamples;
        string _treeFilter = "";
        ViewCube _viewCube;

        Rect ViewCubeRect => new Rect(
            Screen.width - RightOccupied - 136f, HeaderH + ToolbarH + 10f, 124f, 124f);

        int LeftTab
        {
            get => _leftTab.TryGetValue(_workspace, out int t) ? t : 0;
            set => _leftTab[_workspace] = value;
        }

        // "-anima-screenshot <path>": capture the shell once loading and any
        // pending import settle, then quit. "-anima-import <file>": run the
        // STEP/OBJ import flow at startup. CI/agent verification hooks.
        string _shotPath;
        string _importArg;
        float _shotDeadline = -1f;
        bool _fitPending;

        bool ImportBusy => (_stepThread != null && _stepThread.IsAlive)
            || _stepResult != null || _authorQueue.Count > 0 || _authorReqId != null
            || _pendingImport != null;

        void Start()
        {
            // The engine bridge keeps working while the window is unfocused.
            Application.runInBackground = true;
            string[] args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (args[i] == "-anima-screenshot") _shotPath = args[i + 1];
                if (args[i] == "-anima-import") _importArg = args[i + 1];
            }
            _pathField = characterPath;
            _repoRoot = ResolveRepoRoot();
            if (_repoRoot == null)
            {
                _engineFailed = true;
                _status = "repo not found — set ANIMASTUDIO_REPO to the AnimaStudio checkout";
                Debug.LogError("[AnimaStudio] " + _status);
                return;
            }
            RefreshLibraries();
            _bridge = new AnimaCoreBridge();
            try
            {
                _bridge.Start(_repoRoot);
                _mateTypesReqId = _bridge.Send("mate_types");
                // CI screenshot runs need a loaded rig; a user session starts
                // empty — no demo character is loaded on their behalf.
                if (_importArg != null) ImportChosen(_importArg);
                else if (_shotPath != null && string.IsNullOrEmpty(characterPath))
                    characterPath = "examples/pan_tilt_head.character.anima";
                if (_handle == null && _loadReqId == null
                    && !string.IsNullOrEmpty(characterPath))
                    LoadCharacter(characterPath);
                else if (_importArg == null && string.IsNullOrEmpty(characterPath))
                    _status = "import a STEP (Assets ▸ Import) or open a character";
                var orbit = Camera.main != null
                    ? Camera.main.GetComponent<CameraOrbit>() : null;
                if (orbit != null)
                    _viewCube = ViewCube.Spawn(orbit, () => ViewCubeRect);
            }
            catch (Exception e)
            {
                _engineFailed = true;
                _status = "engine launch failed: " + e.Message;
                Debug.LogError("[AnimaStudio] " + e);
            }
        }

        // ---- asset library -------------------------------------------------

        string ImportedPartsFolder => Path.Combine(Application.persistentDataPath, "Parts");

        void RefreshLibraries()
        {
            _characterFiles.Clear();
            foreach (string dir in new[] { "examples", "characters" })
            {
                string full = Path.Combine(_repoRoot, dir);
                if (!Directory.Exists(full)) continue;
                foreach (string f in Directory.GetFiles(
                             full, "*.character.anima", SearchOption.AllDirectories))
                    _characterFiles.Add(f.Substring(_repoRoot.Length + 1));
            }
            _characterFiles.Sort();

            // Source assets: the open character's assets/ plus user imports —
            // nothing bundled with the app.
            _meshFiles.Clear();
            var meshDirs = new List<string> { ImportedPartsFolder };
            if (!string.IsNullOrEmpty(characterPath))
                meshDirs.Add(Path.Combine(CharacterDir, "assets"));
            foreach (string dir in meshDirs)
            {
                if (!Directory.Exists(dir)) continue;
                foreach (string f in Directory.GetFiles(dir, "*.obj")) _meshFiles.Add(f);
            }
            _meshFiles.Sort();
        }

        void ImportMesh(string sourcePath)
        {
            sourcePath = sourcePath.Trim().Trim('"');
            if (!File.Exists(sourcePath) ||
                !sourcePath.EndsWith(".obj", StringComparison.OrdinalIgnoreCase))
            {
                _status = "import wants an existing .obj file";
                return;
            }
            Directory.CreateDirectory(ImportedPartsFolder);
            string target = Path.Combine(ImportedPartsFolder, Path.GetFileName(sourcePath));
            File.Copy(sourcePath, target, true);
            RefreshLibraries();
            _status = "imported " + Path.GetFileName(sourcePath);
        }

        // ---- STEP import → parts (geometry via unity/Tools/step_to_obj.py,
        // semantics via the engine's add_part verb) --------------------------

        string CharacterDir => Path.GetDirectoryName(
            Path.IsPathRooted(characterPath)
                ? characterPath
                : Path.Combine(_repoRoot, characterPath));

        /// <summary>
        /// Native macOS file picker via osascript (blocks while the dialog is
        /// up — it is modal anyway). Returns null on cancel or non-macOS.
        /// ponytail: type the path into the field on Windows/Linux until a
        /// picker plugin is warranted.
        /// </summary>
        static string[] ChooseFilesNative(string prompt)
        {
            if (Application.platform != RuntimePlatform.OSXPlayer
                && Application.platform != RuntimePlatform.OSXEditor)
                return null;
            try
            {
                var psi = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "/usr/bin/osascript",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                };
                foreach (string line in new[]
                {
                    "set fs to choose file with prompt \"" + prompt
                        + "\" with multiple selections allowed",
                    "set out to \"\"",
                    "repeat with f in fs",
                    "set out to out & POSIX path of f & linefeed",
                    "end repeat",
                    "out",
                })
                {
                    psi.ArgumentList.Add("-e");
                    psi.ArgumentList.Add(line);
                }
                using var process = System.Diagnostics.Process.Start(psi);
                string output = process.StandardOutput.ReadToEnd();
                process.WaitForExit();
                if (process.ExitCode != 0) return null;
                string[] files = output.Split('\n',
                    StringSplitOptions.RemoveEmptyEntries);
                return files.Length > 0 ? files : null;
            }
            catch
            {
                return null;
            }
        }

        readonly Queue<string> _importFiles = new Queue<string>();

        string _pendingImport; // runs after the auto-created assembly loads

        void ImportChosen(string path)
        {
            if (string.IsNullOrEmpty(path)) return;
            _importField = path;
            _importPhase = true;
            _importingFile = Path.GetFileName(path.Trim().Trim('"'));
            if (_handle == null)
            {
                // No character open: create an assembly named after the file
                // and finish the import once it has loaded.
                var name = new System.Text.StringBuilder();
                foreach (char c in Path.GetFileNameWithoutExtension(path))
                    name.Append(char.IsLetterOrDigit(c) ? c : '_');
                _pendingImport = path;
                Debug.Log("[AnimaStudio] import: creating assembly '" + name
                    + "' for " + path);
                NewAssembly(name.ToString());
                return;
            }
            if (path.EndsWith(".obj", StringComparison.OrdinalIgnoreCase))
                ImportMesh(path);
            else ImportStep(path);
        }

        string _importingFile; // shown in the loading card
        float _stepStartedAt;
        bool _loadingShotDone;
        bool _importPhase;     // card visibility: true only during real imports

        void ImportStep(string stepPath)
        {
            stepPath = stepPath.Trim().Trim('"');
            _importingFile = Path.GetFileName(stepPath);
            _stepStartedAt = Time.time;
            if (!File.Exists(stepPath)
                || !(stepPath.EndsWith(".step", StringComparison.OrdinalIgnoreCase)
                     || stepPath.EndsWith(".stp", StringComparison.OrdinalIgnoreCase)))
            {
                _status = "import wants an existing .step/.stp file";
                return;
            }
            if (_stepThread != null && _stepThread.IsAlive)
            {
                _status = "a STEP import is already running";
                return;
            }
            string python = AnimaCoreBridge.ResolvePython(_repoRoot);
            string tool = Path.Combine(_repoRoot, "unity", "Tools", "step_to_obj.py");
            string outDir = Path.Combine(CharacterDir, "assets");
            _status = "tessellating " + Path.GetFileName(stepPath) + "…";
            _stepResult = null;
            _stepError = null;
            _stepThread = new System.Threading.Thread(() =>
            {
                try
                {
                    var psi = new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = python,
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true,
                    };
                    psi.ArgumentList.Add(tool);
                    psi.ArgumentList.Add(stepPath);
                    psi.ArgumentList.Add(outDir);
                    using var process = System.Diagnostics.Process.Start(psi);
                    string stdout = process.StandardOutput.ReadToEnd();
                    string stderr = process.StandardError.ReadToEnd();
                    process.WaitForExit();
                    if (process.ExitCode == 0) _stepResult = stdout;
                    else _stepError = string.IsNullOrEmpty(stdout) ? stderr : stdout;
                }
                catch (Exception e)
                {
                    _stepError = e.Message;
                }
            }) { IsBackground = true, Name = "StepImport" };
            _stepThread.Start();
        }

        void PollStepImport()
        {
            if (_stepError != null)
            {
                _status = "STEP import failed: " + _stepError;
                Debug.LogWarning("[AnimaStudio] " + _status);
                _stepError = null;
                return;
            }
            if (_stepResult == null) return;
            string raw = _stepResult;
            _stepResult = null;
            JObject report;
            try { report = JObject.Parse(raw); }
            catch (Exception e)
            {
                _status = "bad converter output: " + e.Message;
                return;
            }
            var parts = report["parts"] as JArray;
            if (parts == null || parts.Count == 0)
            {
                _status = "STEP import: " + (report["error"] ?? "no parts");
                return;
            }
            foreach (JToken part in parts)
            {
                string name = UniquePartName((string)part["name"]);
                _authorQueue.Enqueue(Author("add_part", new JObject
                {
                    ["part"] = new JObject
                    {
                        ["name"] = name,
                        ["model"] = "assets/" + Path.GetFileName((string)part["obj"]),
                        ["position_m"] = part["position_m"],
                        ["rotation_euler_rad"] = part["rotation_euler_rad"],
                    },
                }));
            }
            _status = "adding " + parts.Count + " parts from STEP…";
            RefreshLibraries();
        }

        string UniquePartName(string baseName)
        {
            var taken = new HashSet<string>();
            foreach (PartInfo part in _parts) taken.Add(part.name);
            foreach (JObject queued in _authorQueue)
            {
                string queuedName = (string)queued["params"]?["part"]?["name"];
                if (queuedName != null) taken.Add(queuedName);
            }
            if (!taken.Contains(baseName)) return baseName;
            for (int i = 2; ; i++)
                if (!taken.Contains(baseName + "_" + i)) return baseName + "_" + i;
        }

        void AddMeshAsPart(string objPath)
        {
            string assets = Path.Combine(CharacterDir, "assets");
            Directory.CreateDirectory(assets);
            string target = Path.Combine(assets, Path.GetFileName(objPath));
            if (!File.Exists(target)) File.Copy(objPath, target);
            _authorQueue.Enqueue(Author("add_part", new JObject
            {
                ["part"] = new JObject
                {
                    ["name"] = UniquePartName(
                        Path.GetFileNameWithoutExtension(objPath)),
                    ["model"] = "assets/" + Path.GetFileName(objPath),
                },
            }));
        }

        void NewAssembly(string name)
        {
            name = name.Trim();
            if (name.Length == 0) { _status = "assembly needs a name"; return; }
            foreach (char c in name)
                if (!char.IsLetterOrDigit(c) && c != '_' && c != '-')
                {
                    _status = "name: letters/digits/_/- only";
                    return;
                }
            string dir = Path.Combine(_repoRoot, "characters", name);
            Directory.CreateDirectory(Path.Combine(dir, "assets"));
            string file = Path.Combine(dir, name + ".character.anima");
            if (!File.Exists(file))
                File.WriteAllText(file,
                    "anima_version: \"2.0\"\n"
                    + "type: character\n"
                    + "identity: { name: " + name + " }\n");
            LoadCharacter(Path.Combine("characters", name, name + ".character.anima"));
        }

        void SaveCharacter()
        {
            if (_lastRig == null || _handle == null) { _status = "nothing to save"; return; }
            _saveReqId = _bridge.Send("serialize_character",
                new JObject { ["rig"] = _lastRig });
            _status = "saving…";
        }

        // ---- engine flow ---------------------------------------------------

        void LoadCharacter(string relativePath)
        {
            string full = Path.IsPathRooted(relativePath)
                ? relativePath
                : Path.Combine(_repoRoot, relativePath);
            if (!File.Exists(full))
            {
                _status = "not found: " + full;
                return;
            }
            characterPath = relativePath;
            _pathField = relativePath;
            if (_handle != null)
            {
                _bridge.Send("release", new JObject { ["handle"] = _handle });
                _handle = null;
            }
            _loadReqId = _bridge.Send(
                "load_character", new JObject { ["text"] = File.ReadAllText(full) });
            _status = "loading " + Path.GetFileName(full) + "…";
        }

        void Update()
        {
            if (_bridge == null) return;
            while (_bridge.TryReadResponse(out JObject res)) HandleResponse(res);

            if (_playing && _activeClip >= 0)
            {
                ClipInfo clip = _clips[_activeClip];
                _timeS += Time.deltaTime;
                if (_timeS > clip.durationS)
                {
                    if (clip.loop) _timeS %= Mathf.Max(clip.durationS, 1e-6f);
                    else { _timeS = clip.durationS; _playing = false; }
                }
                _poseDirty = true;
            }

            // One request in flight; newer state coalesces into the next send.
            if (_poseDirty && _handle != null && _poseReqId == null)
            {
                _poseDirty = false;
                _poseReqId = _bridge.Send("resolve_pose", PoseParams());
            }

            // Serialized rig authoring: one mutation at a time, in order.
            if (_authorReqId == null && _authorQueue.Count > 0 && _handle != null)
            {
                JObject request = _authorQueue.Dequeue();
                var prms = (JObject)request["params"];
                prms["handle"] = _handle;
                _authorReqId = _bridge.Send((string)request["method"], prms);
            }

            // Multi-file import: one file's full pipeline at a time.
            if (_importFiles.Count > 0 && !ImportBusy)
                ImportChosen(_importFiles.Dequeue());
            if (_importPhase && !ImportBusy && _importFiles.Count == 0)
                _importPhase = false;

            PollStepImport();
            HandleClickSelection();
            UpdateGizmoTransform();
            if (Camera.main != null) UpdateConnectorHover(Camera.main);

            // CI hook: also capture the loading card mid-import.
            if (_shotPath != null && !_loadingShotDone && _stepThread != null
                && _stepThread.IsAlive && Time.time > _stepStartedAt + 1.2f)
            {
                ScreenCapture.CaptureScreenshot(_shotPath + ".loading.png");
                _loadingShotDone = true;
            }

            if (_shotPath != null && _handle != null && !ImportBusy
                && _shotDeadline < 0f)
                _shotDeadline = Time.time + 2f; // let the pose land + UI settle
            if (_shotDeadline > 0f && Time.time > _shotDeadline)
            {
                ScreenCapture.CaptureScreenshot(_shotPath);
                Debug.Log("[AnimaStudio] screenshot → " + _shotPath);
                _shotDeadline = float.MaxValue * 0.5f; // once
                Invoke(nameof(QuitAfterShot), 1.5f);
            }
        }

        void QuitAfterShot() => Application.Quit();

        JObject PoseParams()
        {
            var prms = new JObject { ["handle"] = _handle, ["time_s"] = _timeS };
            if (_activeClip >= 0) prms["clip"] = _clips[_activeClip].name;
            var overrides = new JObject();
            foreach (DofInfo dof in _dofs)
                if (dof.touched) overrides[dof.path] = dof.shown;
            if (overrides.Count > 0) prms["dof_values"] = overrides;
            return prms;
        }

        void HandleResponse(JObject res)
        {
            string id = (string)res["id"];
            if (res["ok"] == null || !(bool)res["ok"])
            {
                if (id == _poseReqId) _poseReqId = null;
                if (id == _authorReqId) _authorReqId = null; // keep the queue moving
                if (id == _saveReqId) _saveReqId = null;
                if (id == _previewReqId) _previewReqId = null;
                _status = "engine: " + res["error"]?["message"];
                Debug.LogWarning("[AnimaStudio] engine error: " + res["error"]);
                return;
            }
            var result = res["result"] as JObject;
            if (id == _loadReqId)
            {
                _handle = (string)result["handle"];
                ReadRig(result["rig"] as JObject);
                BuildPartObjects();
                _activeClip = -1;
                _playing = false;
                _timeS = 0f;
                _poseDirty = true;
                _fitPending = true;
                _status = _characterName + " — " + _parts.Count + " parts";
                Debug.Log("[AnimaStudio] loaded " + _characterName + ": "
                    + _parts.Count + " parts, " + _dofs.Count + " dofs, "
                    + _clips.Count + " clips");
                RefreshLibraries();
                if (_pendingImport != null)
                {
                    string pending = _pendingImport;
                    _pendingImport = null;
                    if (pending.EndsWith(".obj", StringComparison.OrdinalIgnoreCase))
                        ImportMesh(pending);
                    else ImportStep(pending);
                }
            }
            else if (id == _poseReqId)
            {
                _poseReqId = null;
                ApplyPose(result["parts"] as JObject);
            }
            else if (id == _mateTypesReqId)
            {
                _mateTypes.Clear();
                foreach (JToken schema in result["mate_types"] as JArray ?? new JArray())
                    if ((string)schema["category"] == "kinematic")
                        _mateTypes.Add((JObject)schema);
            }
            else if (id == _authorReqId)
            {
                _authorReqId = null;
                var keepSelection = new List<string>(_selectedParts);
                ReadRig(result["rig"] as JObject, preserveOverrides: true);
                BuildPartObjects();
                SelectParts(keepSelection);
                _poseDirty = true;
                if (_authorQueue.Count > 0)
                {
                    _status = "adding parts… " + _authorQueue.Count + " left";
                }
                else
                {
                    _status = _parts.Count + " parts · " + _mates.Count + " mates";
                    _fitPending = true; // frame the result of the batch
                    RefreshLibraries();
                }
            }
            else if (id == _previewReqId)
            {
                _previewReqId = null;
                ApplyPose(result["parts"] as JObject);
                _status = "solved — ✓ to commit, ✕ to discard";
            }
            else if (id == _saveReqId)
            {
                _saveReqId = null;
                string full = Path.IsPathRooted(characterPath)
                    ? characterPath
                    : Path.Combine(_repoRoot, characterPath);
                Directory.CreateDirectory(Path.GetDirectoryName(full));
                File.WriteAllText(full, (string)result["text"]);
                _status = "saved " + Path.GetFileName(full);
                RefreshLibraries();
            }
        }

        void ReadRig(JObject rig, bool preserveOverrides = false)
        {
            _lastRig = rig;
            var kept = new Dictionary<string, float>();
            if (preserveOverrides)
                foreach (DofInfo dof in _dofs)
                    if (dof.touched) kept[dof.path] = dof.shown;

            _parts.Clear();
            _mates.Clear();
            _relations.Clear();
            _dofs.Clear();
            _clips.Clear();
            _selKind = SelKind.None;
            _selName = null;
            _selectedParts.Clear();
            _dragPart = null;
            _characterName = (string)rig?["identity"]?["display_name"];
            if (string.IsNullOrEmpty(_characterName))
                _characterName = (string)rig?["identity"]?["name"] ?? "character";
            _characterDescription = (string)rig?["identity"]?["description"] ?? "";

            var byName = new Dictionary<string, PartInfo>();
            foreach (JToken part in rig?["parts"] as JArray ?? new JArray())
            {
                var info = new PartInfo
                {
                    name = (string)part["name"],
                    parent = (string)part["parent"] ?? "",
                    model = (string)part["model"] ?? "",
                    modelNode = (string)part["model_node"] ?? "",
                    description = (string)part["description"] ?? "",
                    suppressed = part["suppressed"] != null && (bool)part["suppressed"],
                    grounded = part["grounded"] != null && (bool)part["grounded"],
                };
                if (part["position_m"] is JArray pos && pos.Count == 3)
                    info.positionM = new[] { (float)pos[0], (float)pos[1], (float)pos[2] };
                if (part["rotation_euler_rad"] is JArray rot && rot.Count == 3)
                    info.rotationEulerRad = new[] { (float)rot[0], (float)rot[1], (float)rot[2] };
                if (string.IsNullOrEmpty(info.name)) continue;
                _parts.Add(info);
                byName[info.name] = info;
            }
            foreach (PartInfo part in _parts)
            {
                int depth = 0;
                for (PartInfo p = part;
                     !string.IsNullOrEmpty(p.parent) && byName.TryGetValue(p.parent, out p);)
                    depth++;
                part.depth = depth;
            }

            _matedChildren.Clear();
            foreach (JToken joint in rig?["joints"] as JArray ?? new JArray())
            {
                var mate = new MateInfo
                {
                    name = (string)joint["name"],
                    type = (string)joint["type"],
                    parentPart = (string)joint["parent_part"],
                    childPart = (string)joint["child_part"],
                    suppressed = joint["suppressed"] != null && (bool)joint["suppressed"],
                };
                _mates.Add(mate);
                if (!string.IsNullOrEmpty(mate.childPart))
                    _matedChildren.Add(mate.childPart);
                foreach (JToken dof in joint["dofs"] as JArray ?? new JArray())
                {
                    mate.dofPaths.Add((string)dof["path"]);
                    float neutral = dof["neutral"]?.Type == JTokenType.Null
                        ? 0f : (float?)dof["neutral"] ?? 0f;
                    bool limited = dof["min"] != null && dof["min"].Type != JTokenType.Null
                        && dof["max"] != null && dof["max"].Type != JTokenType.Null;
                    var info = new DofInfo
                    {
                        path = (string)dof["path"],
                        min = limited ? (float)dof["min"] : neutral - Mathf.PI,
                        max = limited ? (float)dof["max"] : neutral + Mathf.PI,
                        neutral = neutral,
                        shown = neutral,
                    };
                    if (kept.TryGetValue(info.path, out float v))
                    {
                        info.shown = v;
                        info.touched = true;
                    }
                    _dofs.Add(info);
                }
            }

            foreach (JToken relation in rig?["relations"] as JArray ?? new JArray())
                _relations.Add((string)relation["kind"] + ": "
                    + relation["driver"] + " → " + relation["driven"]);

            foreach (JToken clip in rig?["clips"] as JArray ?? new JArray())
            {
                _clips.Add(new ClipInfo
                {
                    name = (string)clip["name"],
                    durationS = (float?)clip["duration_s"] ?? 0f,
                    loop = clip["loop"] != null && (bool)clip["loop"],
                });
            }
            if (_activeClip >= _clips.Count) _activeClip = -1;
        }

        void BuildPartObjects()
        {
            foreach (Transform child in transform)
                if (child.name.StartsWith("Part:")) Destroy(child.gameObject);

            string charDir = Path.GetDirectoryName(
                Path.IsPathRooted(characterPath)
                    ? characterPath
                    : Path.Combine(_repoRoot, characterPath));

            foreach (PartInfo part in _parts)
            {
                GameObject go = null;
                if (part.model.EndsWith(".obj", StringComparison.OrdinalIgnoreCase))
                {
                    Mesh mesh = RuntimeObjImporter.Load(Path.Combine(charDir, part.model));
                    if (mesh != null)
                    {
                        go = new GameObject();
                        go.AddComponent<MeshFilter>().sharedMesh = mesh;
                        go.AddComponent<MeshRenderer>();
                        go.AddComponent<MeshCollider>().sharedMesh = mesh;
                    }
                }
                if (go == null)
                {
                    // ponytail: box placeholder until STEP/STL→OBJ conversion
                    // lands; the pose loop and picking are format-neutral.
                    go = GameObject.CreatePrimitive(PrimitiveType.Cube);
                    go.transform.localScale = Vector3.one * 0.05f;
                }
                go.name = "Part:" + part.name;
                go.transform.SetParent(transform, false);
                go.GetComponent<MeshRenderer>().sharedMaterial = MakeMaterial(PartColor);
                part.go = go;
            }
        }

        void ApplyPose(JObject parts)
        {
            if (parts == null) return;
            foreach (PartInfo part in _parts)
            {
                if (part.go == null) continue;
                if (part == _dragPart) continue; // don't fight the user's drag
                JToken t = parts[part.name];
                part.go.SetActive(t != null); // suppressed parts are omitted
                if (t == null) continue;
                JToken pos = t["position"];
                JToken rot = t["orientation"];
                if (pos != null) part.go.transform.localPosition = ToUnityPosition(pos);
                if (rot != null) part.go.transform.localRotation = ToUnityRotation(rot);
            }
            if (_fitPending)
            {
                _fitPending = false;
                var orbit = Camera.main != null
                    ? Camera.main.GetComponent<CameraOrbit>() : null;
                if (orbit != null) ZoomToFit(orbit);
            }
        }

        // AnimaCore is right-handed, Y-up, metres; Unity is left-handed, Y-up.
        static Vector3 ToUnityPosition(JToken p) =>
            new Vector3((float)p[0], (float)p[1], -(float)p[2]);

        static Quaternion ToUnityRotation(JToken q) =>
            new Quaternion(-(float)q[0], -(float)q[1], (float)q[2], (float)q[3]);

        // ---- mate authoring (Onshape-style dialog + connector picking) -----

        void OpenMateDialog(int typeIndex)
        {
            CloseMateDialog();
            _mateType = typeIndex;
            _mateOpen = true;
            _status = "click a face — first pick is the part that MOVES";
        }

        void CloseMateDialog()
        {
            foreach (ConnectorPick pick in _matePicks)
                if (pick.gizmo != null) Destroy(pick.gizmo);
            _matePicks.Clear();
            if (_ghostTriad != null) _ghostTriad.SetActive(false);
            _mateOpen = false;
            _mateTypeListOpen = false;
            _mateOffsetOn = false;
            _mateOffsetField = "0";
            _mateFlip = false;
            _mateSecondaryRot = 0;
            _mateSimConn = true;
            _poseDirty = true; // clear any Solve preview
        }

        static float[] ToEngineVec(Vector3 v) => new[] { v.x, v.y, -v.z };

        void PickConnector(PartInfo part, Vector3 worldPoint, Vector3 worldNormal)
        {
            Vector3 localPos = part.go.transform.InverseTransformPoint(worldPoint);
            Vector3 localPrimary =
                part.go.transform.InverseTransformDirection(worldNormal).normalized;
            Vector3 localSecondary = Vector3.Cross(localPrimary, Vector3.up);
            if (localSecondary.sqrMagnitude < 1e-4f)
                localSecondary = Vector3.Cross(localPrimary, Vector3.right);
            localSecondary.Normalize();

            if (_matePicks.Count >= 2)
            {
                if (_matePicks[1].gizmo != null) Destroy(_matePicks[1].gizmo);
                _matePicks.RemoveAt(1);
            }
            _matePicks.Add(new ConnectorPick
            {
                part = part.name,
                originM = ToEngineVec(localPos),
                primary = ToEngineVec(localPrimary),
                secondary = ToEngineVec(localSecondary),
                gizmo = BuildTriad(worldPoint, worldNormal),
            });
            _status = _matePicks.Count == 1
                ? "now click the target face (the part it mates TO)"
                : "two connectors set — Solve to preview, ✓ to commit";
        }

        void PickConnectorAtOrigin(PartInfo part)
        {
            if (part.go == null) return;
            PickConnector(part, part.go.transform.position, part.go.transform.up);
        }

        /// <summary>
        /// Raycast the viewport and compute the snapped connector placement:
        /// bore/cylinder center, flat-face center, vertex, or raw surface
        /// point (Shift = no snap). World-space result.
        /// </summary>
        bool SnapAtMouse(Camera cam, out PartInfo part, out Vector3 position,
            out Vector3 primary, out MeshSnapping.Kind kind)
        {
            part = null;
            position = default;
            primary = default;
            kind = MeshSnapping.Kind.Raw;
            Ray ray = cam.ScreenPointToRay(Input.mousePosition);
            if (!Physics.Raycast(ray, out RaycastHit hit)
                || !hit.collider.name.StartsWith("Part:"))
                return false;
            string name = hit.collider.name.Substring("Part:".Length);
            part = _parts.Find(p => p.name == name);
            if (part == null) return false;

            position = hit.point;
            primary = hit.normal;
            bool noSnap = Input.GetKey(KeyCode.LeftShift)
                || Input.GetKey(KeyCode.RightShift);
            var meshCollider = hit.collider as MeshCollider;
            if (noSnap || meshCollider == null || hit.triangleIndex < 0)
                return true;

            if (meshCollider.sharedMesh != _lastSnapMesh
                || hit.triangleIndex != _lastSnapTri)
            {
                var orbit = cam.GetComponent<CameraOrbit>();
                float vertexRadius = orbit != null ? orbit.distance * 0.012f : 0.006f;
                Transform t = hit.collider.transform;
                _lastSnap = MeshSnapping.Analyze(meshCollider.sharedMesh,
                    hit.triangleIndex, t.InverseTransformPoint(hit.point),
                    vertexRadius);
                _lastSnapMesh = meshCollider.sharedMesh;
                _lastSnapTri = hit.triangleIndex;
            }
            Transform partTransform = hit.collider.transform;
            position = partTransform.TransformPoint(_lastSnap.localPosition);
            primary = partTransform.TransformDirection(_lastSnap.localPrimary)
                .normalized;
            kind = _lastSnap.kind;
            if (kind != MeshSnapping.Kind.BoreCenter
                && Vector3.Dot(primary, hit.normal) < 0f)
                primary = -primary;
            return true;
        }

        void UpdateConnectorHover(Camera cam)
        {
            bool show = false;
            if (_mateOpen && !MouseOverUi()
                && SnapAtMouse(cam, out _, out Vector3 pos, out Vector3 primary,
                    out MeshSnapping.Kind kind))
            {
                if (_ghostTriad == null) _ghostTriad = BuildTriad(pos, primary);
                _ghostTriad.SetActive(true);
                _ghostTriad.transform.position = pos;
                _ghostTriad.transform.rotation = Quaternion.LookRotation(primary);
                show = true;
                _status = kind switch
                {
                    MeshSnapping.Kind.BoreCenter => "snap: bore center — click to place",
                    MeshSnapping.Kind.EdgeCenter => "snap: circular edge center — click to place",
                    MeshSnapping.Kind.EdgePoint => "snap: edge — click to place",
                    MeshSnapping.Kind.FaceCenter => "snap: face center — click to place",
                    MeshSnapping.Kind.Vertex => "snap: vertex — click to place",
                    _ => "surface point — click to place (Shift = no snap)",
                };
            }
            if (!show && _ghostTriad != null) _ghostTriad.SetActive(false);
        }

        /// <summary>Keeps a connector triad small and screen-constant,
        /// Onshape-style, regardless of zoom.</summary>
        sealed class TriadScaler : MonoBehaviour
        {
            void LateUpdate()
            {
                Camera cam = Camera.main;
                if (cam == null) return;
                float distance =
                    (cam.transform.position - transform.position).magnitude;
                transform.localScale = Vector3.one * Mathf.Max(0.004f,
                    distance * 0.045f);
            }
        }

        /// <summary>Onshape-style connector triad (unit-sized; TriadScaler
        /// keeps it screen-constant): primary blue, secondary red/green.</summary>
        static GameObject BuildTriad(Vector3 worldPos, Vector3 worldPrimary)
        {
            var root = new GameObject("MateConnectorGizmo");
            root.transform.position = worldPos;
            root.transform.rotation = Quaternion.LookRotation(worldPrimary);
            root.AddComponent<TriadScaler>();
            void Axis(Vector3 dir, Color color)
            {
                var bar = GameObject.CreatePrimitive(PrimitiveType.Cube);
                Destroy(bar.GetComponent<Collider>());
                bar.transform.SetParent(root.transform, false);
                bar.transform.localScale = new Vector3(0.045f, 0.045f, 0.42f);
                bar.transform.localRotation = Quaternion.LookRotation(dir);
                bar.transform.localPosition = dir * 0.21f;
                bar.GetComponent<MeshRenderer>().sharedMaterial = MakeMaterial(color);
            }
            Axis(Vector3.forward, new Color(0.25f, 0.45f, 0.95f)); // primary
            Axis(Vector3.right, new Color(0.9f, 0.3f, 0.3f));      // secondary
            Axis(Vector3.up, new Color(0.3f, 0.75f, 0.35f));
            var hub = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            Destroy(hub.GetComponent<Collider>());
            hub.transform.SetParent(root.transform, false);
            hub.transform.localScale = Vector3.one * 0.14f;
            hub.GetComponent<MeshRenderer>().sharedMaterial =
                MakeMaterial(new Color(0.95f, 0.85f, 0.2f));
            return root;
        }

        JObject BuildMateJoint()
        {
            JObject schema = _mateTypes[_mateType];
            var dofs = new JArray();
            foreach (JToken slot in schema["dofs"] as JArray ?? new JArray())
                dofs.Add(new JObject
                {
                    ["name"] = (string)slot["name"],
                    ["kind"] = (string)slot["kind"],
                });
            JObject Connector(ConnectorPick pick) => new JObject
            {
                ["part"] = pick.part,
                ["origin_m"] = new JArray(pick.originM[0], pick.originM[1], pick.originM[2]),
                ["primary_axis"] = new JArray(pick.primary[0], pick.primary[1], pick.primary[2]),
                ["secondary_axis"] = new JArray(
                    pick.secondary[0], pick.secondary[1], pick.secondary[2]),
            };
            float.TryParse(_mateOffsetField, out float offsetM);
            var controls = new JObject
            {
                // First pick moves: it is the CHILD (connector b).
                ["connectors"] = new JObject
                {
                    ["a"] = Connector(_matePicks[1]),
                    ["b"] = Connector(_matePicks[0]),
                },
                ["flip_primary_axis"] = _mateFlip,
                ["secondary_axis_rotation_deg"] = _mateSecondaryRot,
                ["simulation_connection"] = _mateSimConn,
            };
            if (_mateOffsetOn)
                controls["offset"] = new JObject
                {
                    ["enabled"] = true,
                    ["translation_m"] = new JArray(0f, 0f, offsetM),
                };
            return new JObject
            {
                ["name"] = UniqueMateName((string)schema["type"]),
                ["type"] = (string)schema["type"],
                ["parent_part"] = _matePicks[1].part,
                ["child_part"] = _matePicks[0].part,
                ["dofs"] = dofs,
                ["controls"] = controls,
            };
        }

        string UniqueMateName(string baseName)
        {
            var taken = new HashSet<string>();
            foreach (MateInfo mate in _mates) taken.Add(mate.name);
            if (!taken.Contains(baseName)) return baseName;
            for (int i = 2; ; i++)
                if (!taken.Contains(baseName + "_" + i)) return baseName + "_" + i;
        }

        void RemoveMate(string name)
        {
            _authorReqId = _bridge.Send("remove_mate",
                new JObject { ["handle"] = _handle, ["name"] = name });
            _status = "removing mate " + name + "…";
        }

        // ---- selection -----------------------------------------------------

        /// <summary>
        /// Onshape-style left button: click = single select; drag on a FREE
        /// (unmated, ungrounded) part = move it, committed to the engine as
        /// its rest transform on release; drag on empty space = box select.
        /// Selection is NOT additive (per Jonathan).
        /// </summary>
        void HandleClickSelection()
        {
            Camera cam = Camera.main;
            if (cam == null) return;

            if (Input.GetMouseButtonDown(0) && !MouseOverUi())
            {
                Ray ray = cam.ScreenPointToRay(Input.mousePosition);
                // The move gizmo has first claim on the click.
                if (!_mateOpen && Physics.Raycast(ray, out RaycastHit gizmoHit)
                    && gizmoHit.collider.name.StartsWith("GizmoAxis:"))
                {
                    PartInfo target = GizmoTarget();
                    if (target != null)
                    {
                        _gizmoAxis = gizmoHit.collider.name.Substring("GizmoAxis:".Length);
                        foreach (var (axisName, dir, _) in GizmoAxes)
                            if (axisName == _gizmoAxis) _gizmoAxisDir = dir;
                        _gizmoStartPartPos = target.go.transform.position;
                        _gizmoGrabT = AxisGrabT(ray, _gizmo.transform.position,
                            _gizmoAxisDir);
                        _dragPart = target;
                        _dragMoved = false;
                        return;
                    }
                }
                bool hitPart = Physics.Raycast(ray, out RaycastHit hit)
                    && hit.collider.name.StartsWith("Part:");
                string name = hitPart ? hit.collider.name.Substring("Part:".Length) : null;
                if (_mateOpen)
                {
                    if (SnapAtMouse(cam, out PartInfo picked, out Vector3 snapPos,
                            out Vector3 snapPrimary, out _))
                        PickConnector(picked, snapPos, snapPrimary);
                    return; // dialog owns viewport clicks
                }
                if (name != null)
                {
                    SelectParts(new[] { name });
                    PartInfo part = _parts.Find(p => p.name == name);
                    if (part != null && !part.grounded && !_matedChildren.Contains(name))
                    {
                        _dragPart = part;
                        _dragMoved = false;
                        _grabOffset = part.go.transform.position
                            - GroundPoint(ray, part.go.transform.position.y);
                    }
                    else if (part != null && (part.grounded || _matedChildren.Contains(name)))
                    {
                        _status = part.grounded
                            ? name + " is grounded — cannot drag"
                            : name + " is mated — drive its DOF in Animate";
                    }
                }
                else
                {
                    _boxSelecting = true;
                    _boxStart = GuiMouse();
                }
            }

            if (Input.GetMouseButton(0) && _dragPart != null)
            {
                Ray ray = cam.ScreenPointToRay(Input.mousePosition);
                Vector3 target;
                if (_gizmoAxis != null)
                {
                    float t = AxisGrabT(ray, _gizmo.transform.position, _gizmoAxisDir);
                    target = _gizmoStartPartPos + _gizmoAxisDir * (t - _gizmoGrabT);
                }
                else
                {
                    Vector3 ground = GroundPoint(ray, _dragPart.go.transform.position.y);
                    target = new Vector3(
                        ground.x + _grabOffset.x,
                        _dragPart.go.transform.position.y,
                        ground.z + _grabOffset.z);
                }
                if ((target - _dragPart.go.transform.position).sqrMagnitude > 1e-10f)
                {
                    _dragPart.go.transform.position = target;
                    _dragMoved = true;
                }
            }

            if (Input.GetMouseButtonUp(0))
            {
                if (_dragPart != null && _dragMoved) CommitDraggedPart(_dragPart);
                _dragPart = null;
                _dragMoved = false;
                _gizmoAxis = null;
                if (_boxSelecting)
                {
                    _boxSelecting = false;
                    Rect box = BoxRect(_boxStart, GuiMouse());
                    if (box.width < 4f && box.height < 4f) SelectParts(null); // empty click
                    else BoxSelect(cam, box);
                }
            }
        }

        static Vector2 GuiMouse() =>
            new Vector2(Input.mousePosition.x, Screen.height - Input.mousePosition.y);

        static Rect BoxRect(Vector2 a, Vector2 b) => Rect.MinMaxRect(
            Mathf.Min(a.x, b.x), Mathf.Min(a.y, b.y),
            Mathf.Max(a.x, b.x), Mathf.Max(a.y, b.y));

        static Vector3 GroundPoint(Ray ray, float y)
        {
            var plane = new Plane(Vector3.up, new Vector3(0, y, 0));
            return plane.Raycast(ray, out float d) ? ray.GetPoint(d) : Vector3.zero;
        }

        void BoxSelect(Camera cam, Rect guiBox)
        {
            // ponytail: a part is "in the box" when its renderer-bounds center
            // projects inside — no enclosed-vs-crossing distinction yet.
            var picked = new List<string>();
            foreach (PartInfo part in _parts)
            {
                if (part.go == null || !part.go.activeSelf) continue;
                var renderer = part.go.GetComponent<Renderer>();
                if (renderer == null) continue;
                Vector3 screen = cam.WorldToScreenPoint(renderer.bounds.center);
                if (screen.z < 0) continue;
                var gui = new Vector2(screen.x, Screen.height - screen.y);
                if (guiBox.Contains(gui)) picked.Add(part.name);
            }
            SelectParts(picked);
            _status = picked.Count + " selected";
        }

        void CommitDraggedPart(PartInfo part)
        {
            Vector3 p = part.go.transform.localPosition;
            part.positionM = new[] { p.x, p.y, -p.z }; // Unity → engine handedness
            _authorQueue.Enqueue(Author("update_part",
                new JObject { ["part"] = part.ToDto() }));
            _status = "moving " + part.name + "…";
        }

        void SelectParts(IEnumerable<string> names)
        {
            _selectedParts.Clear();
            if (names != null) foreach (string n in names) _selectedParts.Add(n);
            _selKind = _selectedParts.Count > 0 ? SelKind.Part : SelKind.None;
            _selName = null;
            foreach (PartInfo part in _parts)
            {
                if (part.go == null) continue;
                part.go.GetComponent<MeshRenderer>().sharedMaterial =
                    _selectedParts.Contains(part.name)
                        ? MakeSelectedMaterial()
                        : MakeMaterial(PartColor);
            }
            UpdateGizmoTarget();
        }

        static Material MakeSelectedMaterial()
        {
            Material m = MakeMaterial(SelectedColor);
            if (m.HasProperty("_EmissionColor"))
            {
                m.EnableKeyword("_EMISSION");
                m.SetColor("_EmissionColor", SelectedColor * 0.35f);
            }
            return m;
        }

        void SelectMate(string name)
        {
            SelectParts(null);
            _selKind = SelKind.Mate;
            _selName = name;
        }

        bool MouseOverUi()
        {
            Vector2 m = Input.mousePosition;
            var gui = new Vector2(m.x, Screen.height - m.y);
            if (_viewCube != null && _viewCube.ContainsGuiPoint(gui)) return true;
            if (_mateOpen && MateDialogRect.Contains(gui)) return true;
            return gui.y < HeaderH + ToolbarH || gui.y > Screen.height - BottomH
                || gui.x < LeftOccupied || gui.x > Screen.width - RightOccupied;
        }

        // ---- theme ---------------------------------------------------------

        const float QuickRowH = 30f;   // brand + quick actions + document
        const float TabsRowH = 30f;    // left-aligned workspace tabs
        const float HeaderH = QuickRowH + TabsRowH;
        const float ToolbarH = 72f;
        const float BottomH = 64f;
        const float RailW = 44f;      // Swift dock variant: 44 pt icon rails
        const float PanelW = 248f;

        float LeftOccupied => RailW + (_leftOpen ? PanelW : 0f);
        float RightOccupied => RailW + (_rightOpen ? PanelW : 0f);

        // Light theme matching the Swift AnimaStudio app.
        static readonly Color PartColor = new Color(0.55f, 0.62f, 0.68f);
        // Onshape selection cyan (bright, slightly emissive).
        static readonly Color SelectedColor = new Color(0.05f, 0.78f, 0.89f);
        static readonly Color PanelBg = new Color(0.966f, 0.970f, 0.977f, 0.99f);
        static readonly Color HeaderBg = new Color(1f, 1f, 1f, 1f);
        static readonly Color ToolbarBg = new Color(0.988f, 0.99f, 0.993f, 1f);
        static readonly Color RailBg = new Color(0.936f, 0.942f, 0.952f, 1f);
        static readonly Color Accent = new Color(0.207f, 0.467f, 0.945f);
        static readonly Color TextMain = new Color(0.118f, 0.13f, 0.15f);
        static readonly Color TextDim = new Color(0.46f, 0.49f, 0.54f);

        GUIStyle _panel, _bar, _header, _toolbar, _brand, _h1, _dim, _row, _rowSelected,
            _tab, _tabActive, _tool, _toolActive, _center, _rail, _railBtn,
            _railBtnActive, _groupLabel, _field;
        Texture2D _panelTex, _headerTex, _toolbarTex, _rowTex, _accentTex, _railTex;

        static Texture2D Solid(Color c)
        {
            var tex = new Texture2D(1, 1);
            tex.SetPixel(0, 0, c);
            tex.Apply();
            return tex;
        }

        /// <summary>Rounded-rect texture for floating Onshape-style panels
        /// (9-sliced via the style border).</summary>
        static Texture2D Rounded(Color c, int radius = 10, int size = 32)
        {
            var tex = new Texture2D(size, size);
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    float dx = Mathf.Max(0, Mathf.Max(radius - x, x - (size - 1 - radius)));
                    float dy = Mathf.Max(0, Mathf.Max(radius - y, y - (size - 1 - radius)));
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    float a = Mathf.Clamp01(radius + 0.5f - d);
                    tex.SetPixel(x, y, new Color(c.r, c.g, c.b, c.a * a));
                }
            tex.Apply();
            return tex;
        }

        void EnsureStyles()
        {
            if (_panel != null) return;
            _panelTex = Solid(PanelBg);
            _headerTex = Solid(HeaderBg);
            _toolbarTex = Solid(ToolbarBg);
            _rowTex = Solid(new Color(0f, 0f, 0f, 0.055f));
            _accentTex = Solid(Accent);

            _panel = new GUIStyle
            {
                padding = new RectOffset(12, 12, 10, 10),
                border = new RectOffset(12, 12, 12, 12),
            };
            _panel.normal.background = Rounded(new Color(1f, 1f, 1f, 0.98f));

            _bar = new GUIStyle { padding = new RectOffset(12, 12, 10, 10) };
            _bar.normal.background = _panelTex;

            _header = new GUIStyle { padding = new RectOffset(14, 14, 0, 0) };
            _header.normal.background = _headerTex;

            _toolbar = new GUIStyle { padding = new RectOffset(12, 12, 4, 2) };
            _toolbar.normal.background = _toolbarTex;

            _brand = new GUIStyle(GUI.skin.label)
            {
                fontSize = 14, fontStyle = FontStyle.Bold, alignment = TextAnchor.MiddleLeft,
            };
            _brand.normal.textColor = TextMain;

            _h1 = new GUIStyle(GUI.skin.label) { fontSize = 11, fontStyle = FontStyle.Bold };
            _h1.normal.textColor = TextDim;

            _dim = new GUIStyle(GUI.skin.label) { fontSize = 11, wordWrap = true };
            _dim.normal.textColor = TextDim;

            _row = new GUIStyle(GUI.skin.label)
            {
                padding = new RectOffset(6, 6, 3, 3), alignment = TextAnchor.MiddleLeft,
                wordWrap = false, clipping = TextClipping.Clip,
            };
            _row.normal.textColor = TextMain;

            _field = new GUIStyle(GUI.skin.textField)
            {
                fontSize = 11,
                padding = new RectOffset(8, 8, 4, 4),
                border = new RectOffset(6, 6, 6, 6),
            };
            Texture2D fieldTex = Rounded(Color.white, 6, 20);
            _field.normal.background = fieldTex;
            _field.normal.textColor = TextMain;
            _field.focused.background = fieldTex;
            _field.focused.textColor = TextMain;
            _field.hover.background = fieldTex;
            _field.hover.textColor = TextMain;

            _rowSelected = new GUIStyle(_row);
            _rowSelected.normal.background = _accentTex;
            _rowSelected.normal.textColor = Color.white;

            _tab = new GUIStyle(GUI.skin.label)
            {
                fontSize = 12, alignment = TextAnchor.MiddleCenter,
                padding = new RectOffset(14, 14, 0, 0), fixedHeight = HeaderH,
            };
            _tab.normal.textColor = TextDim;

            _tabActive = new GUIStyle(_tab) { fontStyle = FontStyle.Bold };
            _tabActive.normal.textColor = Color.white;
            _tabActive.normal.background = _accentTex;

            Texture2D buttonTex = Solid(new Color(0.895f, 0.91f, 0.932f));
            Texture2D buttonHotTex = Solid(new Color(0.845f, 0.865f, 0.895f));
            _tool = new GUIStyle(GUI.skin.button)
            {
                fontSize = 11,
                padding = new RectOffset(10, 10, 4, 4),
            };
            _tool.normal.background = buttonTex;
            _tool.normal.textColor = TextMain;
            _tool.hover.background = buttonHotTex;
            _tool.hover.textColor = TextMain;
            _tool.active.background = buttonHotTex;
            _tool.active.textColor = TextMain;
            _tool.focused.background = buttonTex;
            _tool.focused.textColor = TextMain;

            _toolActive = new GUIStyle(_tool) { fontStyle = FontStyle.Bold };
            _toolActive.normal.background = _accentTex;
            _toolActive.normal.textColor = Color.white;
            _toolActive.hover.background = _accentTex;
            _toolActive.hover.textColor = Color.white;

            _center = new GUIStyle(GUI.skin.label)
            {
                fontSize = 13, alignment = TextAnchor.MiddleCenter, wordWrap = true,
            };
            _center.normal.textColor = TextDim;

            _railTex = Solid(RailBg);
            _rail = new GUIStyle { padding = new RectOffset(3, 3, 8, 8) };
            _rail.normal.background = _railTex;

            _railBtn = new GUIStyle(GUI.skin.label)
            {
                fontSize = 9, fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleCenter, fixedHeight = 34,
                padding = new RectOffset(0, 0, 0, 0),
            };
            _railBtn.normal.textColor = TextDim;

            _railBtnActive = new GUIStyle(_railBtn);
            _railBtnActive.normal.background = _accentTex;
            _railBtnActive.normal.textColor = Color.white;

            _groupLabel = new GUIStyle(GUI.skin.label)
            {
                fontSize = 9, fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleLeft,
            };
            _groupLabel.normal.textColor = TextDim;

            // Mate-dialog chrome (Onshape's popup look).
            _dialogTitle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 12, fontStyle = FontStyle.Bold,
            };
            _dialogTitle.normal.textColor = new Color(0.78f, 0.18f, 0.18f);

            _confirmBtn = new GUIStyle(_tool) { fontStyle = FontStyle.Bold };
            _confirmBtn.normal.background = Solid(new Color(0.36f, 0.70f, 0.42f));
            _confirmBtn.normal.textColor = Color.white;
            _confirmBtn.hover.background = Solid(new Color(0.30f, 0.62f, 0.36f));
            _confirmBtn.hover.textColor = Color.white;

            _cancelBtn = new GUIStyle(_tool) { fontStyle = FontStyle.Bold };
            _cancelBtn.normal.textColor = new Color(0.82f, 0.2f, 0.2f);
            _cancelBtn.hover.textColor = new Color(0.82f, 0.2f, 0.2f);

            _toggle = new GUIStyle(GUI.skin.toggle) { fontSize = 11 };
            _toggle.normal.textColor = TextMain;
            _toggle.onNormal.textColor = TextMain;
            _toggle.hover.textColor = TextMain;
            _toggle.onHover.textColor = TextMain;

            _connectorBox = new GUIStyle
            {
                padding = new RectOffset(8, 8, 6, 6),
                border = new RectOffset(8, 8, 8, 8),
            };
            _connectorBox.normal.background =
                Rounded(new Color(0.90f, 0.94f, 1.0f), 8, 24);

            // Ribbon: icon-over-label buttons, tiny group captions, separators.
            _toolBig = new GUIStyle
            {
                fontSize = 9, richText = true, alignment = TextAnchor.MiddleCenter,
                padding = new RectOffset(2, 2, 3, 3),
                border = new RectOffset(8, 8, 8, 8),
            };
            _toolBig.normal.textColor = TextMain;
            _toolBig.hover.background = Rounded(new Color(0f, 0f, 0f, 0.06f), 8, 24);
            _toolBig.hover.textColor = TextMain;
            _toolBig.active.background = Rounded(new Color(0f, 0f, 0f, 0.10f), 8, 24);
            _toolBig.active.textColor = TextMain;

            _toolBigActive = new GUIStyle(_toolBig);
            _toolBigActive.normal.background = Rounded(Accent, 8, 24);
            _toolBigActive.normal.textColor = Color.white;
            _toolBigActive.hover.background = _toolBigActive.normal.background;
            _toolBigActive.hover.textColor = Color.white;

            _ribbonCaption = new GUIStyle(GUI.skin.label)
            {
                fontSize = 8, fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleCenter,
            };
            _ribbonCaption.normal.textColor = TextDim;

            _separator = new GUIStyle();
            _separator.normal.background = Solid(new Color(0f, 0f, 0f, 0.12f));

            _iconSmall = new GUIStyle
            {
                padding = new RectOffset(3, 3, 3, 3),
                border = new RectOffset(6, 6, 6, 6),
            };
            _iconSmall.hover.background = Rounded(new Color(0f, 0f, 0f, 0.07f), 6, 20);

            _docTitle = new GUIStyle(GUI.skin.label)
            {
                fontSize = 12, fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleCenter,
            };
            _docTitle.normal.textColor = TextMain;

            _wsTab = new GUIStyle(GUI.skin.label)
            {
                fontSize = 11, fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleCenter,
                padding = new RectOffset(12, 12, 0, 0),
            };
            _wsTab.normal.textColor = TextDim;
            _wsTab.hover.textColor = TextMain;

            _wsTabActive = new GUIStyle(_wsTab);
            _wsTabActive.normal.textColor = TextMain;

            _iconBtn = new GUIStyle
            {
                padding = new RectOffset(6, 6, 4, 4),
                border = new RectOffset(8, 8, 8, 8),
                imagePosition = ImagePosition.ImageOnly,
            };
            _iconBtn.hover.background = Rounded(new Color(0f, 0f, 0f, 0.06f), 8, 24);
            _iconBtn.active.background = Rounded(new Color(0f, 0f, 0f, 0.10f), 8, 24);

            _iconBtnActive = new GUIStyle(_iconBtn);
            _iconBtnActive.normal.background =
                Rounded(new Color(Accent.r, Accent.g, Accent.b, 0.22f), 8, 24);

            _iconLabel = new GUIStyle(GUI.skin.label)
            {
                fontSize = 9, alignment = TextAnchor.UpperCenter,
                clipping = TextClipping.Clip,
            };
            _iconLabel.normal.textColor = TextMain;
        }

        GUIStyle _toolBig, _toolBigActive, _ribbonCaption, _separator,
            _iconSmall, _docTitle, _wsTab, _wsTabActive, _iconBtn, _iconBtnActive,
            _iconLabel;

        GUIStyle _dialogTitle, _confirmBtn, _cancelBtn, _toggle, _connectorBox;
        Texture2D _spinnerTex;

        /// <summary>Onshape-style modal import card: spinner, filename, stage.</summary>
        void DrawLoadingCard()
        {
            if (_spinnerTex == null) _spinnerTex = BuildSpinnerArc();
            var card = new Rect(Screen.width / 2f - 130, Screen.height / 2f - 85,
                260, 170);
            GUI.Box(card, GUIContent.none, _panel);

            var spin = new Rect(card.x + card.width / 2f - 22, card.y + 18, 44, 44);
            Matrix4x4 saved = GUI.matrix;
            GUIUtility.RotateAroundPivot(Time.realtimeSinceStartup * 220f, spin.center);
            GUI.DrawTexture(spin, _spinnerTex);
            GUI.matrix = saved;

            GUI.Label(new Rect(card.x, card.y + 70, card.width, 24), "Importing",
                CenteredStyle(_brand));
            GUI.Label(new Rect(card.x, card.y + 96, card.width, 20),
                _importingFile ?? "…", CenteredStyle(_row));
            string stage =
                _stepThread != null && _stepThread.IsAlive ? "Tessellating geometry…"
                : _authorQueue.Count > 0 || _authorReqId != null
                    ? "Adding parts… " + _authorQueue.Count + " left"
                : _importFiles.Count > 0 ? _importFiles.Count + " file(s) queued"
                : "Finishing…";
            GUI.Label(new Rect(card.x, card.y + 122, card.width, 20), stage,
                CenteredStyle(_dim));
        }

        GUIStyle _centeredBrand, _centeredRow, _centeredDim;

        GUIStyle CenteredStyle(GUIStyle source)
        {
            if (source == _brand) return _centeredBrand ??=
                new GUIStyle(source) { alignment = TextAnchor.MiddleCenter };
            if (source == _row) return _centeredRow ??=
                new GUIStyle(source) { alignment = TextAnchor.MiddleCenter };
            return _centeredDim ??=
                new GUIStyle(source) { alignment = TextAnchor.MiddleCenter };
        }

        static Texture2D BuildSpinnerArc()
        {
            const int size = 64;
            var tex = new Texture2D(size, size);
            Color accent = Accent;
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    float dx = x - size / 2f + 0.5f, dy = y - size / 2f + 0.5f;
                    float r = Mathf.Sqrt(dx * dx + dy * dy);
                    float angle = Mathf.Atan2(dy, dx);
                    bool ring = r > size * 0.32f && r < size * 0.44f;
                    bool arc = angle > -2.4f && angle < 0.6f; // ~170° sweep
                    tex.SetPixel(x, y, ring && arc
                        ? accent : new Color(0, 0, 0, 0));
                }
            tex.Apply();
            return tex;
        }

        Rect MateDialogRect => new Rect(LeftOccupied + 12, HeaderH + ToolbarH + 12,
            256, 330 + (_mateTypeListOpen ? 22 * _mateTypes.Count : 0));

        void DrawMateDialog()
        {
            JObject schema = _mateTypes[_mateType];
            GUILayout.BeginArea(MateDialogRect, _panel);

            GUILayout.BeginHorizontal();
            GUILayout.Label((string)schema["label"] + " " + (_mates.Count + 1),
                _dialogTitle);
            GUILayout.FlexibleSpace();
            GUI.enabled = _matePicks.Count == 2
                && _matePicks[0].part != _matePicks[1].part;
            if (GUILayout.Button("✓", _confirmBtn, GUILayout.Width(34)))
            {
                _authorQueue.Enqueue(Author("add_mate",
                    new JObject { ["joint"] = BuildMateJoint() }));
                CloseMateDialog();
                _status = "committing mate…";
            }
            GUI.enabled = true;
            if (GUILayout.Button("✕", _cancelBtn, GUILayout.Width(30)))
                CloseMateDialog();
            GUILayout.EndHorizontal();
            GUILayout.Space(4);

            if (GUILayout.Button((string)schema["label"] + "   ▾", _tool))
                _mateTypeListOpen = !_mateTypeListOpen;
            if (_mateTypeListOpen)
                for (int i = 0; i < _mateTypes.Count; i++)
                    if (GUILayout.Button((string)_mateTypes[i]["label"],
                            i == _mateType ? _toolActive : _row))
                    {
                        _mateType = i;
                        _mateTypeListOpen = false;
                    }
            GUILayout.Space(6);

            GUILayout.Label("Mate connectors", _groupLabel);
            GUILayout.BeginVertical(_connectorBox);
            for (int i = 0; i < _matePicks.Count; i++)
            {
                GUILayout.BeginHorizontal();
                GUILayout.Label("Connector of " + _matePicks[i].part, _row);
                if (GUILayout.Button("✕", _cancelBtn, GUILayout.Width(24)))
                {
                    if (_matePicks[i].gizmo != null) Destroy(_matePicks[i].gizmo);
                    _matePicks.RemoveAt(i);
                    GUILayout.EndHorizontal();
                    break;
                }
                GUILayout.EndHorizontal();
            }
            if (_matePicks.Count < 2)
                GUILayout.Label(_matePicks.Count == 0
                    ? "click a face — first pick MOVES"
                    : "click the target face", _dim);
            GUILayout.EndVertical();
            GUILayout.Space(6);

            var universalControls = new HashSet<string>();
            foreach (JToken control in schema["universal_controls"] as JArray ?? new JArray())
                universalControls.Add((string)control);
            if (universalControls.Contains("offset"))
            {
                GUILayout.BeginHorizontal();
                _mateOffsetOn = GUILayout.Toggle(_mateOffsetOn, " Offset", _toggle);
                if (_mateOffsetOn)
                {
                    _mateOffsetField = GUILayout.TextField(_mateOffsetField, _field,
                        GUILayout.Width(56));
                    GUILayout.Label("m", _dim);
                }
                GUILayout.EndHorizontal();
            }
            if (universalControls.Contains("flip_primary_axis"))
                _mateFlip = GUILayout.Toggle(_mateFlip, " Flip primary axis", _toggle);
            if (universalControls.Contains("secondary_axis_rotation")
                && GUILayout.Button("Secondary rotation: " + _mateSecondaryRot + "°",
                    _tool))
                _mateSecondaryRot = (_mateSecondaryRot + 90) % 360;
            if (universalControls.Contains("simulation_connection"))
                _mateSimConn = GUILayout.Toggle(_mateSimConn,
                    " Simulation connection", _toggle);
            GUILayout.Space(4);

            var dofText = new System.Text.StringBuilder("DOF: ");
            var dofSlots = schema["dofs"] as JArray ?? new JArray();
            if (dofSlots.Count == 0) dofText.Append("none (rigid)");
            foreach (JToken slot in dofSlots)
                dofText.Append((string)slot["name"] + " (" + (string)slot["unit"]
                    + ", " + (string)slot["axis"] + ")  ");
            GUILayout.Label(dofText.ToString(), _dim);
            GUILayout.Space(4);

            GUI.enabled = _matePicks.Count == 2
                && _matePicks[0].part != _matePicks[1].part;
            if (GUILayout.Button("Solve", _tool, GUILayout.Width(60))
                && _previewReqId == null)
            {
                _previewReqId = _bridge.Send("preview_mate", new JObject
                {
                    ["handle"] = _handle,
                    ["joint"] = BuildMateJoint(),
                });
                _status = "solving…";
            }
            GUI.enabled = true;
            GUILayout.EndArea();
        }

        // ---- UI ------------------------------------------------------------

        void OnGUI()
        {
            EnsureStyles();
            DrawHeader();
            DrawToolbar();
            DrawLeftDock();
            DrawRightDock();
            DrawBottomBar();
            if (_mateOpen && _mateTypes.Count > 0) DrawMateDialog();
            if (_importPhase) DrawLoadingCard();
            if (_workspace == Workspace.Show || _workspace == Workspace.Hardware)
                DrawComingSoon();
            if (_boxSelecting)
            {
                Rect box = BoxRect(_boxStart, GuiMouse());
                GUI.color = new Color(Accent.r, Accent.g, Accent.b, 0.18f);
                GUI.DrawTexture(box, _accentTex);
                GUI.color = Color.white;
            }
        }

        static readonly Dictionary<string, Texture2D> IconCache =
            new Dictionary<string, Texture2D>();

        static Texture2D Icon(string name)
        {
            if (!IconCache.TryGetValue(name, out Texture2D icon))
            {
                icon = Resources.Load<Texture2D>("Icons/" + name);
                IconCache[name] = icon;
            }
            return icon;
        }

        void DrawHeader()
        {
            // Row 1 — brand, quick actions, document name, status.
            GUILayout.BeginArea(new Rect(0, 0, Screen.width, QuickRowH), _header);
            GUILayout.BeginHorizontal(GUILayout.Height(QuickRowH));
            GUILayout.Label("◆ ANIMA STUDIO", _brand, GUILayout.Height(QuickRowH));
            GUILayout.Space(10);
            GUI.enabled = _handle != null;
            Texture2D saveIcon = Icon("save");
            if (saveIcon != null
                ? GUILayout.Button(saveIcon, _iconSmall,
                    GUILayout.Width(24), GUILayout.Height(24))
                : GUILayout.Button("Save", _tool))
                SaveCharacter();
            GUI.enabled = true;
            GUILayout.FlexibleSpace();
            GUILayout.Label(
                string.IsNullOrEmpty(_characterName) ? "Untitled" : _characterName,
                _docTitle, GUILayout.Height(QuickRowH));
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("Workbench", _tab, GUILayout.Height(QuickRowH))
                && Application.CanStreamedLevelBeLoaded("AssemblyWorkbench"))
                SceneManager.LoadScene("AssemblyWorkbench");
            GUILayout.Label(_status, _dim, GUILayout.Height(QuickRowH),
                GUILayout.MaxWidth(360));
            GUILayout.EndHorizontal();
            GUILayout.EndArea();

            // Row 2 — Fusion-style left-aligned workspace tabs with an
            // accent underline on the active one.
            GUILayout.BeginArea(new Rect(0, QuickRowH, Screen.width, TabsRowH),
                _header);
            GUILayout.BeginHorizontal(GUILayout.Height(TabsRowH));
            GUILayout.Space(12);
            for (int i = 0; i < WorkspaceTitles.Length; i++)
            {
                bool active = (int)_workspace == i;
                if (GUILayout.Button(WorkspaceTitles[i].ToUpper(),
                        active ? _wsTabActive : _wsTab, GUILayout.Height(TabsRowH)))
                {
                    _workspace = (Workspace)i;
                    CloseMateDialog();
                }
                if (active)
                {
                    Rect r = GUILayoutUtility.GetLastRect();
                    GUI.DrawTexture(
                        new Rect(r.x + 6, r.yMax - 3, r.width - 12, 3), _accentTex);
                }
            }
            GUILayout.FlexibleSpace();
            GUILayout.EndHorizontal();
            GUILayout.EndArea();
        }

        /// <summary>Ribbon button: real icon (Resources/Icons) above a small
        /// label; text-only fallback when the icon asset is missing.</summary>
        void ToolButton(string iconName, string label, Action action,
            bool active = false, bool enabled = true)
        {
            GUI.enabled = enabled;
            GUI.color = enabled ? Color.white : new Color(1f, 1f, 1f, 0.4f);
            GUILayout.BeginVertical(GUILayout.Width(58));
            Texture2D icon = Icon(iconName);
            bool clicked;
            if (icon != null)
            {
                GUILayout.BeginHorizontal();
                GUILayout.FlexibleSpace();
                clicked = GUILayout.Button(icon,
                    active ? _iconBtnActive : _iconBtn,
                    GUILayout.Width(36), GUILayout.Height(30));
                GUILayout.FlexibleSpace();
                GUILayout.EndHorizontal();
                GUILayout.Label(label, _iconLabel, GUILayout.Height(14));
            }
            else
            {
                clicked = GUILayout.Button(label,
                    active ? _toolBigActive : _toolBig,
                    GUILayout.Height(44));
            }
            GUILayout.EndVertical();
            GUI.color = Color.white;
            if (clicked) action?.Invoke();
            GUI.enabled = true;
        }

        static void BeginGroup()
        {
            GUILayout.BeginVertical(GUILayout.ExpandWidth(false));
            GUILayout.BeginHorizontal();
        }

        void EndGroup(string caption)
        {
            GUILayout.EndHorizontal();
            GUILayout.Label(caption, _ribbonCaption, GUILayout.Height(12));
            GUILayout.EndVertical();
        }

        void Separator()
        {
            GUILayout.Space(10);
            GUILayout.Box(GUIContent.none, _separator,
                GUILayout.Width(1), GUILayout.Height(ToolbarH - 16));
            GUILayout.Space(10);
        }

        void DrawToolbar()
        {
            GUILayout.BeginArea(new Rect(0, HeaderH, Screen.width, ToolbarH), _toolbar);
            GUILayout.BeginHorizontal();
            GUILayout.Space(6);
            switch (_workspace)
            {
                case Workspace.Assets:
                    BeginGroup();
                    ToolButton("import", "Import", () =>
                    {
                        string[] picked = ChooseFilesNative(
                            "Choose .step/.stp/.obj files (⌘-click for several)");
                        if (picked != null)
                        {
                            foreach (string file in picked)
                                _importFiles.Enqueue(file.Trim());
                            _status = picked.Length + " file(s) queued";
                        }
                        else if (_importField.Trim().Length > 0)
                            ImportChosen(_importField.Trim().Trim('"'));
                        else
                            _status = "pick files (or paste a path in the field)";
                    });
                    ToolButton("rescan", "Rescan", RefreshLibraries);
                    GUILayout.BeginVertical();
                    GUILayout.Space(14);
                    _importField = GUILayout.TextField(_importField, _field,
                        GUILayout.Width(190));
                    GUILayout.EndVertical();
                    EndGroup("IMPORT");
                    Separator();
                    BeginGroup();
                    GUILayout.BeginVertical();
                    GUILayout.Space(14);
                    _newAssemblyField = GUILayout.TextField(_newAssemblyField, _field,
                        GUILayout.Width(120));
                    GUILayout.EndVertical();
                    ToolButton("assembly_new", "Assembly",
                        () => { if (!_engineFailed) NewAssembly(_newAssemblyField); });
                    EndGroup("CREATE");
                    break;

                case Workspace.Modeling:
                    BeginGroup();
                    for (int i = 0; i < _mateTypes.Count; i++)
                    {
                        int index = i;
                        string type = (string)_mateTypes[i]["type"];
                        bool active = _mateOpen && _mateType == i;
                        ToolButton(
                            type, // icon names match the engine's mate types
                            (string)_mateTypes[i]["label"],
                            () =>
                            {
                                if (active) CloseMateDialog();
                                else OpenMateDialog(index);
                            },
                            active);
                    }
                    EndGroup("MATE");
                    Separator();
                    BeginGroup();
                    ToolButton("remove_part", "Part", () =>
                    {
                        foreach (string name in _selectedParts)
                            _authorQueue.Enqueue(Author("remove_part",
                                new JObject { ["name"] = name }));
                    }, enabled: _selectedParts.Count == 1);
                    ToolButton("remove_mate", "Mate", () => RemoveMate(_selName),
                        enabled: _selKind == SelKind.Mate && _selName != null);
                    EndGroup("EDIT");
                    break;

                case Workspace.Animate:
                    bool any = false;
                    foreach (DofInfo dof in _dofs) any |= dof.touched;
                    BeginGroup();
                    ToolButton("reset", "Reset", () =>
                    {
                        foreach (DofInfo dof in _dofs)
                        {
                            dof.touched = false;
                            dof.shown = dof.neutral;
                        }
                        _poseDirty = true;
                    }, enabled: any);
                    EndGroup("POSE");
                    break;

                default:
                    GUILayout.Label(WorkspaceTitles[(int)_workspace].ToUpper(), _h1,
                        GUILayout.Height(ToolbarH - 10));
                    break;
            }
            GUILayout.FlexibleSpace();
            GUILayout.EndHorizontal();
            GUILayout.EndArea();
        }

        void DrawLeftDock()
        {
            float top = HeaderH + ToolbarH;
            float height = Screen.height - top - BottomH;
            string[] tabs = LeftTabs[_workspace];

            GUILayout.BeginArea(new Rect(0, top, RailW, height), _rail);
            for (int i = 0; i < tabs.Length; i++)
            {
                bool active = _leftOpen && LeftTab == i;
                if (GUILayout.Button(tabs[i], active ? _railBtnActive : _railBtn,
                        GUILayout.Width(RailW - 6)))
                {
                    if (active) { _leftOpen = false; }
                    else { _leftOpen = true; LeftTab = i; }
                }
                GUILayout.Space(2);
            }
            GUILayout.FlexibleSpace();
            if (GUILayout.Button(_leftOpen ? "◀" : "▶", _railBtn,
                    GUILayout.Width(RailW - 6)))
                _leftOpen = !_leftOpen;
            GUILayout.EndArea();

            if (!_leftOpen) return;
            GUILayout.BeginArea(
                new Rect(RailW + 8, top + 8, PanelW - 8, height - 16), _panel);
            _leftScroll = GUILayout.BeginScrollView(_leftScroll, GUIStyle.none, GUIStyle.none);
            if (tabs[Mathf.Min(LeftTab, tabs.Length - 1)] == "PROJ")
                DrawProjectTab();
            else
                GUILayout.Label("lands with the engine session verbs", _dim);
            GUILayout.EndScrollView();
            GUILayout.EndArea();
        }

        bool FoldRow(ref bool open, string title, int count)
        {
            if (GUILayout.Button((open ? "▾  " : "▸  ") + title + "  (" + count + ")",
                    _row))
                open = !open;
            return open;
        }

        bool PassesFilter(string name) =>
            _treeFilter.Length == 0
            || name.IndexOf(_treeFilter, StringComparison.OrdinalIgnoreCase) >= 0;

        /// <summary>The persistent project navigator (Onshape-style tree).</summary>
        void DrawProjectTab()
        {
            _treeFilter = GUILayout.TextField(_treeFilter, _field);
            if (_treeFilter.Length == 0)
            {
                Rect hint = GUILayoutUtility.GetLastRect();
                GUI.Label(hint, "  Filter by name", _dim);
            }
            GUILayout.Space(6);
            if (_handle == null)
            {
                GUILayout.Label("no assembly open", _row);
                GUILayout.Label("Import a STEP from the Assets toolbar (an "
                    + "assembly is created for it automatically), create a New "
                    + "Assembly, or open an example below.", _dim);
            }
            else
            {
                GUILayout.Label(_characterName, _brand);
                GUILayout.Label(characterPath, _dim);
            }
            GUILayout.Space(6);

            if (FoldRow(ref _foldParts, "Instances", _parts.Count))
            {
                foreach (PartInfo part in _parts)
                {
                    if (!PassesFilter(part.name)) continue;
                    GUILayout.BeginHorizontal();
                    GUILayout.Space(14 + part.depth * 12);
                    string label = part.name
                        + (part.grounded ? " ⏚" : "")
                        + (part.suppressed ? "  (suppressed)" : "");
                    bool sel = _selectedParts.Contains(part.name);
                    if (GUILayout.Button(label, sel ? _rowSelected : _row))
                    {
                        if (_mateOpen) PickConnectorAtOrigin(part);
                        else SelectParts(sel ? null : new[] { part.name });
                    }
                    GUILayout.EndHorizontal();
                }
            }

            if (FoldRow(ref _foldMates, "Mate features", _mates.Count))
            {
                foreach (MateInfo mate in _mates)
                {
                    if (!PassesFilter(mate.name)) continue;
                    GUILayout.BeginHorizontal();
                    GUILayout.Space(14);
                    bool sel = _selKind == SelKind.Mate && mate.name == _selName;
                    if (GUILayout.Button(mate.name + "  ·  " + mate.type,
                            sel ? _rowSelected : _row))
                        SelectMate(sel ? null : mate.name);
                    GUILayout.EndHorizontal();
                }
            }

            if (FoldRow(ref _foldRelations, "Relations", _relations.Count))
            {
                foreach (string relation in _relations)
                {
                    GUILayout.BeginHorizontal();
                    GUILayout.Space(14);
                    GUILayout.Label(relation, _row);
                    GUILayout.EndHorizontal();
                }
            }

            if (FoldRow(ref _foldClips, "Clips", _clips.Count))
            {
                for (int i = 0; i < _clips.Count; i++)
                {
                    ClipInfo clip = _clips[i];
                    GUILayout.BeginHorizontal();
                    GUILayout.Space(14);
                    string label = clip.name + "  ·  "
                        + clip.durationS.ToString("0.##") + "s" + (clip.loop ? " ⟳" : "");
                    if (GUILayout.Button(label, i == _activeClip ? _rowSelected : _row))
                    {
                        _activeClip = i == _activeClip ? -1 : i;
                        _timeS = 0f;
                        _playing = false;
                        _poseDirty = true;
                    }
                    GUILayout.EndHorizontal();
                }
            }

            if (FoldRow(ref _foldAssets, "Source Assets", _meshFiles.Count))
            {
                foreach (string file in _meshFiles)
                {
                    GUILayout.BeginHorizontal();
                    GUILayout.Space(14);
                    GUILayout.Label(Path.GetFileNameWithoutExtension(file), _row);
                    if (_handle != null
                        && GUILayout.Button("Add", _tool, GUILayout.Width(42)))
                        AddMeshAsPart(file);
                    GUILayout.EndHorizontal();
                }
            }

            GUILayout.Space(10);
            GUILayout.Label("LIBRARY", _h1);
            if (FoldRow(ref _foldExamples, "Examples", _characterFiles.Count))
            {
                foreach (string file in _characterFiles)
                {
                    GUILayout.BeginHorizontal();
                    GUILayout.Space(14);
                    bool current = file == characterPath;
                    GUILayout.Label(Path.GetFileName(file).Replace(".character.anima", ""),
                        current ? _rowSelected : _row);
                    if (!current && GUILayout.Button("Open", _tool, GUILayout.Width(48))
                        && !_engineFailed)
                        LoadCharacter(file);
                    GUILayout.EndHorizontal();
                }
            }
        }

        static readonly string[] RightTabs = { "INS", "VIEW", "APP" };

        void DrawRightDock()
        {
            float top = HeaderH + ToolbarH;
            float height = Screen.height - top - BottomH;

            GUILayout.BeginArea(
                new Rect(Screen.width - RailW, top, RailW, height), _rail);
            for (int i = 0; i < RightTabs.Length; i++)
            {
                bool active = _rightOpen && _rightTab == i;
                if (GUILayout.Button(RightTabs[i], active ? _railBtnActive : _railBtn,
                        GUILayout.Width(RailW - 6)))
                {
                    if (active) { _rightOpen = false; }
                    else { _rightOpen = true; _rightTab = i; }
                }
                GUILayout.Space(2);
            }
            GUILayout.FlexibleSpace();
            if (GUILayout.Button(_rightOpen ? "▶" : "◀", _railBtn,
                    GUILayout.Width(RailW - 6)))
                _rightOpen = !_rightOpen;
            GUILayout.EndArea();

            if (!_rightOpen) return;
            GUILayout.BeginArea(new Rect(Screen.width - RailW - PanelW, top + 8,
                PanelW - 8, height - 16), _panel);
            if (_rightTab == 1) DrawViewTab();
            else if (_rightTab == 2) DrawAppearanceTab();
            else DrawInspectorTab();
            GUILayout.EndArea();
        }

        void DrawAppearanceTab()
        {
            GUILayout.Label("APPEARANCE", _h1);
            if (_selectedParts.Count == 0)
            {
                GUILayout.Label("select parts, then pick a color", _dim);
                return;
            }
            GUILayout.Label(_selectedParts.Count + " part(s)", _row);
            GUILayout.Space(6);
            // ponytail: appearance is app-side display only until the
            // character format carries a per-part appearance block.
            Color[] swatches =
            {
                new Color(0.55f, 0.62f, 0.68f), new Color(0.36f, 0.56f, 0.72f),
                new Color(0.34f, 0.62f, 0.55f), new Color(0.78f, 0.60f, 0.34f),
                new Color(0.72f, 0.42f, 0.42f), new Color(0.58f, 0.48f, 0.72f),
                new Color(0.85f, 0.85f, 0.87f), new Color(0.30f, 0.32f, 0.36f),
            };
            GUILayout.BeginHorizontal();
            for (int i = 0; i < swatches.Length; i++)
            {
                if (i == 4) { GUILayout.EndHorizontal(); GUILayout.BeginHorizontal(); }
                GUI.backgroundColor = swatches[i];
                if (GUILayout.Button(" ", _tool, GUILayout.Width(34), GUILayout.Height(24)))
                    foreach (PartInfo part in _parts)
                        if (_selectedParts.Contains(part.name) && part.go != null)
                            part.go.GetComponent<MeshRenderer>().sharedMaterial =
                                MakeMaterial(swatches[i]);
                GUI.backgroundColor = Color.white;
            }
            GUILayout.EndHorizontal();
            GUILayout.Space(6);
            GUILayout.Label("display colors only — not yet saved to the "
                + "character file", _dim);
        }

        void DrawViewTab()
        {
            GUILayout.Label("VIEW", _h1);
            var orbit = Camera.main != null
                ? Camera.main.GetComponent<CameraOrbit>() : null;
            if (orbit == null) { GUILayout.Label("no orbit camera", _dim); return; }

            GUILayout.Label("view presets", _dim);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Front", _tool)) { orbit.yaw = 0; orbit.pitch = 0; }
            if (GUILayout.Button("Right", _tool)) { orbit.yaw = 90; orbit.pitch = 0; }
            if (GUILayout.Button("Top", _tool)) { orbit.yaw = 0; orbit.pitch = 89; }
            if (GUILayout.Button("Iso", _tool)) { orbit.yaw = 30; orbit.pitch = 25; }
            GUILayout.EndHorizontal();
            GUILayout.Space(6);
            if (GUILayout.Button("Zoom to fit", _tool)) ZoomToFit(orbit);
            GUILayout.Space(10);

            GameObject ground = GameObject.Find("Ground");
            if (ground != null)
            {
                bool show = GUILayout.Toggle(ground.activeSelf, " ground plane");
                if (show != ground.activeSelf) ground.SetActive(show);
            }
        }

        void ZoomToFit(CameraOrbit orbit)
        {
            var bounds = new Bounds();
            bool any = false;
            foreach (PartInfo part in _parts)
            {
                if (part.go == null || !part.go.activeSelf) continue;
                var renderer = part.go.GetComponent<Renderer>();
                if (renderer == null) continue;
                if (!any) { bounds = renderer.bounds; any = true; }
                else bounds.Encapsulate(renderer.bounds);
            }
            if (!any) return;
            orbit.target = bounds.center;
            orbit.distance = Mathf.Max(0.15f, bounds.extents.magnitude * 2.4f);
        }

        void DrawInspectorTab()
        {
            GUILayout.Label("INSPECTOR", _h1);
            _rightScroll = GUILayout.BeginScrollView(_rightScroll, GUIStyle.none, GUIStyle.none);

            if (_workspace == Workspace.Assets)
            {
                GUILayout.Label(_characterName, _brand);
                if (!string.IsNullOrEmpty(_characterDescription))
                    GUILayout.Label(_characterDescription, _dim);
                GUILayout.Space(6);
                GUILayout.Label(_parts.Count + " parts · " + _mates.Count + " mates · "
                    + _clips.Count + " clips", _dim);
            }
            else if (_mateOpen)
            {
                GUILayout.Label("MATE IN PROGRESS", _brand);
                GUILayout.Label("use the mate dialog in the viewport", _dim);
            }
            else if (_selKind == SelKind.Mate)
            {
                MateInfo mate = _mates.Find(m => m.name == _selName);
                if (mate != null)
                {
                    GUILayout.Label(mate.name, _brand);
                    GUILayout.Label("type: " + mate.type, _dim);
                    GUILayout.Label(mate.parentPart + "  →  " + mate.childPart, _dim);
                    foreach (string path in mate.dofPaths)
                        GUILayout.Label("dof: " + path, _dim);
                    GUILayout.Space(8);
                    if (GUILayout.Button("Remove mate", _tool)) RemoveMate(mate.name);
                }
            }
            else if (_selKind == SelKind.Part && _selectedParts.Count > 1)
            {
                GUILayout.Label(_selectedParts.Count + " parts selected", _brand);
                foreach (string name in _selectedParts)
                    GUILayout.Label(name, _dim);
            }
            else if (_selKind == SelKind.Part)
            {
                PartInfo part = null;
                foreach (string name in _selectedParts)
                    part = _parts.Find(p => p.name == name);
                if (part != null)
                {
                    GUILayout.Label(part.name, _brand);
                    if (!string.IsNullOrEmpty(part.parent))
                        GUILayout.Label("parent: " + part.parent, _dim);
                    if (!string.IsNullOrEmpty(part.model))
                        GUILayout.Label("model: " + part.model, _dim);
                    GUILayout.Label(string.Format("position: ({0:0.###}, {1:0.###}, {2:0.###}) m",
                        part.positionM[0], part.positionM[1], part.positionM[2]), _dim);
                    if (part.grounded) GUILayout.Label("grounded", _dim);
                    else if (_matedChildren.Contains(part.name))
                        GUILayout.Label("mated — pose via its DOF", _dim);
                    else GUILayout.Label("free — drag in viewport to place", _dim);
                }
            }
            else
            {
                GUILayout.Label("click a part or mate to inspect", _dim);
            }

            if (_workspace == Workspace.Animate)
            {
                GUILayout.Space(12);
                GUILayout.Label("POSE — DEGREES OF FREEDOM", _h1);
                GUILayout.Label("engine-evaluated; drag to pose live", _dim);
                GUILayout.Space(4);
                foreach (DofInfo dof in _dofs)
                {
                    GUILayout.BeginHorizontal();
                    GUILayout.Label((dof.touched ? "● " : "") + dof.path, _row,
                        GUILayout.Width(150));
                    GUILayout.Label(dof.shown.ToString("0.00"), _dim, GUILayout.Width(44));
                    GUILayout.EndHorizontal();
                    float value = GUILayout.HorizontalSlider(dof.shown, dof.min, dof.max);
                    if (!Mathf.Approximately(value, dof.shown))
                    {
                        dof.shown = value;
                        dof.touched = true;
                        _poseDirty = true;
                    }
                    GUILayout.Space(4);
                }
            }

            GUILayout.EndScrollView();
        }

        void DrawBottomBar()
        {
            GUILayout.BeginArea(
                new Rect(0, Screen.height - BottomH, Screen.width, BottomH), _bar);
            GUILayout.BeginHorizontal(GUILayout.Height(BottomH - 20));

            if (_workspace == Workspace.Animate)
            {
                ClipInfo clip = _activeClip >= 0 ? _clips[_activeClip] : null;
                GUI.enabled = clip != null;
                if (GUILayout.Button(_playing ? "❚❚" : "▶", GUILayout.Width(44),
                        GUILayout.Height(28)))
                {
                    _playing = !_playing;
                    if (_playing && clip != null && _timeS >= clip.durationS) _timeS = 0f;
                }
                GUI.enabled = true;

                GUILayout.Space(10);
                if (clip != null)
                {
                    GUILayout.BeginVertical();
                    GUILayout.Space(4);
                    float scrubbed = GUILayout.HorizontalSlider(_timeS, 0f, clip.durationS);
                    if (!Mathf.Approximately(scrubbed, _timeS))
                    {
                        _timeS = scrubbed;
                        _playing = false;
                        _poseDirty = true;
                    }
                    GUILayout.EndVertical();
                    GUILayout.Space(10);
                    GUILayout.Label(_timeS.ToString("0.00") + " / "
                        + clip.durationS.ToString("0.00") + " s   " + clip.name,
                        _dim, GUILayout.Width(200));
                }
                else
                {
                    GUILayout.Label("select a clip in the navigator to play", _dim);
                }
            }
            else
            {
                GUILayout.Label("Right-drag: orbit · Middle-drag: pan · Wheel: zoom · "
                    + "Click: select · Drag free part: move · Drag empty: box select",
                    _dim);
            }
            GUILayout.EndHorizontal();
            GUILayout.EndArea();
        }

        void DrawComingSoon()
        {
            var rect = new Rect(LeftOccupied, HeaderH + ToolbarH,
                Screen.width - LeftOccupied - RightOccupied,
                Screen.height - HeaderH - ToolbarH - BottomH);
            GUI.Label(rect, _workspace == Workspace.Show
                ? "Show workspace — .scene.anima playback lands with the engine "
                    + "session verbs."
                : "Hardware workspace — channel mapping + simulator/serial output "
                    + "land with the engine session verbs.", _center);
        }

        static Material MakeMaterial(Color color)
        {
            Shader shader = Shader.Find("Universal Render Pipeline/Lit")
                ?? Shader.Find("Standard")
                ?? Shader.Find("Sprites/Default");
            var m = new Material(shader);
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", color);
            if (m.HasProperty("_Color")) m.SetColor("_Color", color);
            return m;
        }

        // ---- lifecycle -----------------------------------------------------

        void OnDestroy() => _bridge?.Stop();
        void OnApplicationQuit() => _bridge?.Stop();

        /// <summary>
        /// Editor: Assets → project → unity → repo. Player: the .app can live
        /// anywhere under the repo (walk up), or ANIMASTUDIO_REPO points at it.
        /// </summary>
        static string ResolveRepoRoot()
        {
            string env = Environment.GetEnvironmentVariable("ANIMASTUDIO_REPO");
            if (!string.IsNullOrEmpty(env) && Directory.Exists(Path.Combine(env, "animacore")))
                return env;
            for (var dir = new DirectoryInfo(Application.dataPath);
                 dir != null; dir = dir.Parent)
            {
                if (Directory.Exists(Path.Combine(dir.FullName, "animacore"))
                    && Directory.Exists(Path.Combine(dir.FullName, "examples")))
                    return dir.FullName;
            }
            return null;
        }
    }
}
