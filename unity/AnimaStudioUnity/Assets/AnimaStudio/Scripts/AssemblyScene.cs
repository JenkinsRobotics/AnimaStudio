using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace AnimaStudio
{
    /// <summary>
    /// First end-to-end 3D proof: launch the AnimaCore engine, load a
    /// <c>.character.anima</c> file, resolve every part's world pose, and render a
    /// box per part. Orbit + click-select use Unity built-ins. Real STEP meshes
    /// replace the placeholder boxes in a later slice — the engine bridge, the
    /// part list, and the pose loop are what this proves.
    /// </summary>
    public sealed class AssemblyScene : MonoBehaviour
    {
        [Tooltip("Path to a .character.anima file, relative to the repo root.")]
        public string characterPath = "examples/pan_tilt_head.character.anima";

        AnimaCoreBridge _bridge;
        string _repoRoot;
        string _handle;
        string _loadReqId;
        string _poseReqId;
        readonly Dictionary<string, GameObject> _partObjects = new Dictionary<string, GameObject>();
        readonly List<string> _partNames = new List<string>();
        string _selected;
        string _status = "starting…";

        void Start()
        {
            _repoRoot = ResolveRepoRoot();
            _bridge = new AnimaCoreBridge();
            try
            {
                _bridge.Start(_repoRoot);
                string full = Path.Combine(_repoRoot, characterPath);
                if (!File.Exists(full))
                {
                    _status = "character file not found:\n" + full;
                    Debug.LogError("[AnimaStudio] " + _status);
                    return;
                }
                string text = File.ReadAllText(full);
                _loadReqId = _bridge.Send("load_character", new JObject { ["text"] = text });
                _status = "loading character…";
            }
            catch (System.Exception e)
            {
                _status = "engine launch failed: " + e.Message;
                Debug.LogError("[AnimaStudio] " + e);
            }
        }

        void Update()
        {
            if (_bridge == null) return;
            while (_bridge.TryReadResponse(out JObject res)) HandleResponse(res);
            HandleClickSelection();
        }

        void HandleResponse(JObject res)
        {
            string id = (string)res["id"];
            bool ok = res["ok"] != null && (bool)res["ok"];
            if (!ok)
            {
                _status = "engine error: " + res["error"];
                Debug.LogWarning("[AnimaStudio] " + _status);
                return;
            }
            var result = res["result"] as JObject;
            if (id == _loadReqId)
            {
                _handle = (string)result["handle"];
                BuildParts(result["rig"] as JObject);
                _poseReqId = _bridge.Send(
                    "resolve_pose", new JObject { ["handle"] = _handle, ["time_s"] = 0.0 });
                _status = $"loaded {_partNames.Count} parts; resolving pose…";
            }
            else if (id == _poseReqId)
            {
                ApplyPose(result["parts"] as JObject);
                _status = $"ready — {_partNames.Count} parts (engine-resolved)";
            }
        }

        void BuildParts(JObject rig)
        {
            foreach (GameObject go in _partObjects.Values) Destroy(go);
            _partObjects.Clear();
            _partNames.Clear();

            var parts = rig?["parts"] as JArray;
            if (parts == null) return;
            foreach (JToken part in parts)
            {
                string name = (string)part["name"];
                if (string.IsNullOrEmpty(name)) continue;
                _partNames.Add(name);
                var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
                go.name = "Part:" + name;
                go.transform.SetParent(transform, false);
                go.transform.localScale = Vector3.one * 0.05f; // 5 cm placeholder
                _partObjects[name] = go;
            }
        }

        void ApplyPose(JObject parts)
        {
            if (parts == null) return;
            foreach (var kv in parts)
            {
                if (!_partObjects.TryGetValue(kv.Key, out GameObject go)) continue;
                JToken pos = kv.Value["position"];
                JToken rot = kv.Value["orientation"];
                if (pos != null) go.transform.localPosition = ToUnityPosition(pos);
                if (rot != null) go.transform.localRotation = ToUnityRotation(rot);
            }
        }

        // AnimaCore is right-handed, Y-up, metres; Unity is left-handed, Y-up.
        // Convert by negating Z. Tuning point: if the assembly looks mirrored or
        // rotations are wrong, this is the first place to flip.
        static Vector3 ToUnityPosition(JToken p) =>
            new Vector3((float)p[0], (float)p[1], -(float)p[2]);

        static Quaternion ToUnityRotation(JToken q) =>
            new Quaternion(-(float)q[0], -(float)q[1], (float)q[2], (float)q[3]);

        void HandleClickSelection()
        {
            if (!Input.GetMouseButtonDown(0)) return;
            Camera cam = Camera.main;
            if (cam == null) return;
            Ray ray = cam.ScreenPointToRay(Input.mousePosition);
            if (Physics.Raycast(ray, out RaycastHit hit) && hit.collider.name.StartsWith("Part:"))
                Select(hit.collider.name.Substring("Part:".Length));
            else
                Select(null);
        }

        void Select(string name)
        {
            if (_selected != null && _partObjects.TryGetValue(_selected, out GameObject prev))
                prev.GetComponent<Renderer>().material.color = Color.white;
            _selected = name;
            if (name != null && _partObjects.TryGetValue(name, out GameObject go))
                go.GetComponent<Renderer>().material.color = new Color(1f, 0.55f, 0f);
        }

        void OnGUI()
        {
            var boxStyle = new GUIStyle(GUI.skin.box) { richText = true };
            GUILayout.BeginArea(new Rect(10, 10, 260, Screen.height - 20), boxStyle);
            GUILayout.Label("<b>AnimaStudio — Assembly</b>");
            GUILayout.Label(_status);
            GUILayout.Space(6);
            foreach (string name in _partNames)
            {
                bool isSelected = name == _selected;
                bool now = GUILayout.Toggle(isSelected, "  " + name);
                if (now && !isSelected) Select(name);
            }
            GUILayout.EndArea();
        }

        void OnDestroy() => _bridge?.Stop();
        void OnApplicationQuit() => _bridge?.Stop();

        // Assets → <project> → unity → <repo root>
        static string ResolveRepoRoot()
        {
            string project = Directory.GetParent(Application.dataPath).FullName;
            string unity = Directory.GetParent(project).FullName;
            return Directory.GetParent(unity).FullName;
        }
    }
}
