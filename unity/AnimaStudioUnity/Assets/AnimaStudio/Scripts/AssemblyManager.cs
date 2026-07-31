using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using UnityEngine;

namespace AnimaStudio
{
    /// <summary>
    /// The import → assemble workbench. Scans a parts folder for OBJ meshes,
    /// lets you add them to the scene, select (click), move (left-drag on the
    /// ground; Q/E for height; [ ] to rotate), and save/load the assembly.
    /// Runtime-only APIs, so it works in a standalone build. STEP parts feed in
    /// once we add STEP→OBJ/glTF conversion — the workflow here is format-neutral.
    /// </summary>
    public sealed class AssemblyManager : MonoBehaviour
    {
        sealed class Placed
        {
            public string source;      // OBJ file name (no extension)
            public GameObject go;
        }

        readonly List<string> _library = new List<string>();   // available part files
        readonly List<Placed> _assembly = new List<Placed>();
        readonly Dictionary<string, Mesh> _meshCache = new Dictionary<string, Mesh>();
        Placed _selected;
        bool _dragging;
        Vector3 _grabOffset;
        string _status = "";
        Vector2 _scroll;

        string PartsFolder => Path.Combine(Application.streamingAssetsPath, "Parts");
        string SavePath => Path.Combine(Application.persistentDataPath, "assembly.json");

        void Start()
        {
            RefreshLibrary();
            _status = _library.Count > 0
                ? $"{_library.Count} parts available — click Add to assemble"
                : "No parts. Drop .obj files into StreamingAssets/Parts.";
        }

        void RefreshLibrary()
        {
            _library.Clear();
            if (Directory.Exists(PartsFolder))
                foreach (string f in Directory.GetFiles(PartsFolder, "*.obj"))
                    _library.Add(Path.GetFileNameWithoutExtension(f));
            _library.Sort();
        }

        Mesh MeshFor(string source)
        {
            if (_meshCache.TryGetValue(source, out Mesh cached)) return cached;
            Mesh mesh = RuntimeObjImporter.Load(Path.Combine(PartsFolder, source + ".obj"));
            _meshCache[source] = mesh;
            return mesh;
        }

        void AddPart(string source)
        {
            Mesh mesh = MeshFor(source);
            if (mesh == null) { _status = "failed to load " + source; return; }

            var go = new GameObject("Part:" + source);
            go.transform.SetParent(transform, false);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            go.AddComponent<MeshRenderer>().sharedMaterial = MakeMaterial(PartColor);
            go.AddComponent<MeshCollider>().sharedMesh = mesh;

            var placed = new Placed { source = source, go = go };
            _assembly.Add(placed);
            Select(placed);
            _status = "added " + source;
        }

        void Update()
        {
            HandleMouse();
            if (_selected != null)
            {
                float dy = (Input.GetKey(KeyCode.E) ? 1 : 0) - (Input.GetKey(KeyCode.Q) ? 1 : 0);
                if (dy != 0) _selected.go.transform.position += Vector3.up * dy * 0.2f * Time.deltaTime;
                float yaw = (Input.GetKey(KeyCode.RightBracket) ? 1 : 0) - (Input.GetKey(KeyCode.LeftBracket) ? 1 : 0);
                if (yaw != 0) _selected.go.transform.Rotate(Vector3.up, yaw * 60f * Time.deltaTime, Space.World);
            }
        }

        void HandleMouse()
        {
            Camera cam = Camera.main;
            if (cam == null) return;

            if (Input.GetMouseButtonDown(0))
            {
                Ray ray = cam.ScreenPointToRay(Input.mousePosition);
                if (Physics.Raycast(ray, out RaycastHit hit))
                {
                    Placed p = _assembly.Find(x => x.go == hit.collider.gameObject);
                    if (p != null)
                    {
                        Select(p);
                        _dragging = true;
                        _grabOffset = p.go.transform.position - GroundPoint(ray, p.go.transform.position.y);
                    }
                    else { Select(null); }
                }
                else { Select(null); }
            }
            else if (Input.GetMouseButton(0) && _dragging && _selected != null)
            {
                Ray ray = cam.ScreenPointToRay(Input.mousePosition);
                Vector3 g = GroundPoint(ray, _selected.go.transform.position.y);
                _selected.go.transform.position = new Vector3(g.x + _grabOffset.x, _selected.go.transform.position.y, g.z + _grabOffset.z);
            }
            else if (Input.GetMouseButtonUp(0)) { _dragging = false; }
        }

        static Vector3 GroundPoint(Ray ray, float y)
        {
            var plane = new Plane(Vector3.up, new Vector3(0, y, 0));
            return plane.Raycast(ray, out float d) ? ray.GetPoint(d) : Vector3.zero;
        }

        void Select(Placed p)
        {
            if (_selected != null && _selected.go != null)
                _selected.go.GetComponent<MeshRenderer>().sharedMaterial = MakeMaterial(PartColor);
            _selected = p;
            if (p != null && p.go != null)
                p.go.GetComponent<MeshRenderer>().sharedMaterial = MakeMaterial(SelectedColor);
        }

        void Delete(Placed p)
        {
            if (p == null) return;
            if (_selected == p) _selected = null;
            _assembly.Remove(p);
            Destroy(p.go);
        }

        // ---- Save / load ---------------------------------------------------

        void SaveAssembly()
        {
            var sb = new StringBuilder();
            sb.Append("{\"parts\":[");
            for (int i = 0; i < _assembly.Count; i++)
            {
                Placed p = _assembly[i];
                Vector3 t = p.go.transform.position;
                Vector3 e = p.go.transform.eulerAngles;
                if (i > 0) sb.Append(',');
                sb.AppendFormat(CultureInfo.InvariantCulture,
                    "{{\"source\":\"{0}\",\"pos\":[{1},{2},{3}],\"rot\":[{4},{5},{6}]}}",
                    p.source, t.x, t.y, t.z, e.x, e.y, e.z);
            }
            sb.Append("]}");
            File.WriteAllText(SavePath, sb.ToString());
            _status = "saved → " + SavePath;
        }

        void LoadAssembly()
        {
            if (!File.Exists(SavePath)) { _status = "no saved assembly"; return; }
            foreach (Placed p in _assembly) Destroy(p.go);
            _assembly.Clear();
            _selected = null;
            var data = JsonUtility.FromJson<SaveData>(WrapForJsonUtility(File.ReadAllText(SavePath)));
            if (data?.parts == null) { _status = "could not read assembly"; return; }
            foreach (PartData pd in data.parts)
            {
                AddPart(pd.source);
                Placed placed = _assembly[_assembly.Count - 1];
                placed.go.transform.position = new Vector3(pd.pos[0], pd.pos[1], pd.pos[2]);
                placed.go.transform.eulerAngles = new Vector3(pd.rot[0], pd.rot[1], pd.rot[2]);
            }
            Select(null);
            _status = "loaded assembly";
        }

        [Serializable] class SaveData { public PartData[] parts; }
        [Serializable] class PartData { public string source; public float[] pos; public float[] rot; }
        static string WrapForJsonUtility(string json) => json; // shape already matches SaveData

        // ---- UI (IMGUI, AnimaStudio dark) ---------------------------------

        static readonly Color PartColor = new Color(0.72f, 0.74f, 0.78f);
        static readonly Color SelectedColor = new Color(1f, 0.55f, 0f);

        void OnGUI()
        {
            const float w = 280f;
            var panel = new GUIStyle(GUI.skin.box) { richText = true, padding = new RectOffset(10, 10, 10, 10) };
            GUILayout.BeginArea(new Rect(12, 12, w, Screen.height - 24), panel);

            if (UnityEngine.SceneManagement.SceneManager.GetSceneByBuildIndex(0).IsValid()
                || Application.CanStreamedLevelBeLoaded("Studio"))
            {
                if (GUILayout.Button("◀ Studio"))
                    UnityEngine.SceneManagement.SceneManager.LoadScene("Studio");
            }

            GUILayout.Label("<size=14><b>AnimaStudio</b></size>  <color=#8a8f98>3D Modeling</color>");
            GUILayout.Label("<color=#8a8f98>" + _status + "</color>");
            GUILayout.Space(8);

            GUILayout.Label("<b>PARTS LIBRARY</b>");
            if (GUILayout.Button("Refresh folder")) { RefreshLibrary(); }
            foreach (string src in _library)
            {
                GUILayout.BeginHorizontal();
                GUILayout.Label(src);
                if (GUILayout.Button("Add", GUILayout.Width(46))) AddPart(src);
                GUILayout.EndHorizontal();
            }

            GUILayout.Space(10);
            GUILayout.Label("<b>ASSEMBLY</b>  <color=#8a8f98>" + _assembly.Count + " parts</color>");
            _scroll = GUILayout.BeginScrollView(_scroll);
            Placed toDelete = null;
            foreach (Placed p in _assembly)
            {
                GUILayout.BeginHorizontal();
                bool sel = p == _selected;
                if (GUILayout.Toggle(sel, "  " + p.source) && !sel) Select(p);
                if (GUILayout.Button("✕", GUILayout.Width(24))) toDelete = p;
                GUILayout.EndHorizontal();
            }
            GUILayout.EndScrollView();
            if (toDelete != null) Delete(toDelete);

            GUILayout.Space(8);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Save")) SaveAssembly();
            if (GUILayout.Button("Load")) LoadAssembly();
            GUILayout.EndHorizontal();

            GUILayout.Space(6);
            GUILayout.Label("<color=#8a8f98>Left-drag: move · Q/E: up-down · [ ]: rotate\nRight-drag: orbit · Middle-drag: pan · Wheel: zoom</color>");
            GUILayout.EndArea();
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
    }
}
