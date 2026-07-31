using System;
using UnityEngine;

namespace AnimaStudio
{
    /// <summary>
    /// Onshape-style view cube: a real labeled cube rendered by a mini camera
    /// in the viewport's top-right corner, tracking the main orbit. Clicking a
    /// face snaps the view to it. Built entirely at runtime on a reserved
    /// layer the main camera does not draw.
    /// </summary>
    public sealed class ViewCube : MonoBehaviour
    {
        const int CubeLayer = 30;
        static readonly Vector3 Home = new Vector3(1000f, 1000f, 1000f);

        CameraOrbit _orbit;
        Func<Rect> _guiRect;      // GUI-space corner rect supplied by the shell
        Camera _miniCamera;
        Transform _cube;

        public static ViewCube Spawn(CameraOrbit orbit, Func<Rect> guiRect)
        {
            var go = new GameObject("ViewCube");
            var viewCube = go.AddComponent<ViewCube>();
            viewCube._orbit = orbit;
            viewCube._guiRect = guiRect;
            viewCube.Build();
            return viewCube;
        }

        void Build()
        {
            if (Camera.main != null)
                Camera.main.cullingMask &= ~(1 << CubeLayer);

            var cubeObject = GameObject.CreatePrimitive(PrimitiveType.Cube);
            cubeObject.name = "ViewCubeBody";
            cubeObject.layer = CubeLayer;
            cubeObject.transform.SetParent(transform, false);
            cubeObject.transform.position = Home;
            var renderer = cubeObject.GetComponent<Renderer>();
            var material = new Material(Shader.Find("Standard")
                ?? Shader.Find("Unlit/Color"));
            var faceColor = new Color(0.985f, 0.985f, 0.99f);
            if (material.HasProperty("_Color")) material.SetColor("_Color", faceColor);
            if (material.HasProperty("_Glossiness")) material.SetFloat("_Glossiness", 0.02f);
            if (material.HasProperty("_EmissionColor"))
            {
                material.EnableKeyword("_EMISSION");
                material.SetColor("_EmissionColor", faceColor * 0.55f);
            }
            renderer.sharedMaterial = material;
            _cube = cubeObject.transform;

            // Axis lines from the cube's lower corner, per the reference:
            // red X to the right, blue Y (up axis) — with letter labels.
            AddAxisLine("X", new Vector3(1, 0, 0), new Color(0.90f, 0.30f, 0.28f));
            AddAxisLine("Y", new Vector3(0, 1, 0), new Color(0.30f, 0.45f, 0.92f));

            AddLabel("FRONT", new Vector3(0, 0, -0.51f), Quaternion.identity);
            AddLabel("BACK", new Vector3(0, 0, 0.51f), Quaternion.Euler(0, 180, 0));
            AddLabel("RIGHT", new Vector3(0.51f, 0, 0), Quaternion.Euler(0, 90, 0));
            AddLabel("LEFT", new Vector3(-0.51f, 0, 0), Quaternion.Euler(0, -90, 0));
            AddLabel("TOP", new Vector3(0, 0.51f, 0), Quaternion.Euler(90, 0, 0));
            AddLabel("BOTTOM", new Vector3(0, -0.51f, 0), Quaternion.Euler(-90, 0, 0));

            var cameraObject = new GameObject("ViewCubeCamera");
            cameraObject.transform.SetParent(transform, false);
            _miniCamera = cameraObject.AddComponent<Camera>();
            _miniCamera.cullingMask = 1 << CubeLayer;
            _miniCamera.clearFlags = CameraClearFlags.Depth; // transparent overlay
            _miniCamera.orthographic = true;
            _miniCamera.orthographicSize = 0.95f;
            _miniCamera.nearClipPlane = 0.1f;
            _miniCamera.farClipPlane = 10f;
            _miniCamera.depth = 10f;

            var lightObject = new GameObject("ViewCubeLight");
            lightObject.transform.SetParent(transform, false);
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.0f;
            light.cullingMask = 1 << CubeLayer;
            light.transform.rotation = Quaternion.Euler(45f, -30f, 0f);
        }

        void AddAxisLine(string label, Vector3 direction, Color color)
        {
            Vector3 corner = new Vector3(-0.5f, -0.5f, -0.5f);
            var line = GameObject.CreatePrimitive(PrimitiveType.Cube);
            Destroy(line.GetComponent<Collider>());
            line.name = "Axis" + label;
            line.layer = CubeLayer;
            line.transform.SetParent(_cube, false);
            line.transform.localScale =
                Vector3.one * 0.022f + direction * 1.05f;
            line.transform.localPosition = corner + direction * 0.55f;
            var material = new Material(Shader.Find("Unlit/Color")
                ?? Shader.Find("Standard"));
            if (material.HasProperty("_Color")) material.SetColor("_Color", color);
            line.GetComponent<MeshRenderer>().sharedMaterial = material;

            var labelObject = new GameObject("AxisLabel" + label);
            labelObject.layer = CubeLayer;
            labelObject.transform.SetParent(_cube, false);
            labelObject.transform.localPosition = corner + direction * 1.28f;
            var textMesh = labelObject.AddComponent<TextMesh>();
            textMesh.text = label;
            textMesh.anchor = TextAnchor.MiddleCenter;
            textMesh.fontSize = 44;
            textMesh.characterSize = 0.09f;
            textMesh.color = color;
            _billboards.Add(labelObject.transform);
        }

        readonly System.Collections.Generic.List<Transform> _billboards =
            new System.Collections.Generic.List<Transform>();

        void AddLabel(string text, Vector3 offset, Quaternion rotation)
        {
            var go = new GameObject("Label" + text);
            go.layer = CubeLayer;
            go.transform.SetParent(_cube, false);
            go.transform.localPosition = offset;
            go.transform.localRotation = rotation;
            var textMesh = go.AddComponent<TextMesh>();
            textMesh.text = text;
            textMesh.anchor = TextAnchor.MiddleCenter;
            textMesh.alignment = TextAlignment.Center;
            textMesh.fontSize = 48;
            textMesh.characterSize = 0.055f;
            textMesh.color = new Color(0.32f, 0.36f, 0.42f);
        }

        void LateUpdate()
        {
            if (_orbit == null || _miniCamera == null) return;
            Camera main = Camera.main;
            if (main == null) return;

            // Mirror the main view's direction around the static cube.
            _miniCamera.transform.rotation = main.transform.rotation;
            _miniCamera.transform.position =
                Home - main.transform.forward * 3f;

            // Axis letter labels always face the mini camera.
            foreach (Transform billboard in _billboards)
                billboard.rotation = _miniCamera.transform.rotation;

            // Place the mini viewport at the shell-provided corner rect.
            Rect gui = _guiRect();
            _miniCamera.rect = new Rect(
                gui.x / Screen.width,
                1f - (gui.y + gui.height) / Screen.height,
                gui.width / Screen.width,
                gui.height / Screen.height);

            HandleClick(gui);
        }

        void HandleClick(Rect gui)
        {
            if (!Input.GetMouseButtonDown(0)) return;
            var mouse = new Vector2(Input.mousePosition.x,
                Screen.height - Input.mousePosition.y);
            if (!gui.Contains(mouse)) return;
            Ray ray = _miniCamera.ScreenPointToRay(Input.mousePosition);
            if (!Physics.Raycast(ray, out RaycastHit hit, 20f, 1 << CubeLayer))
                return;
            Vector3 n = hit.normal;
            if (Mathf.Abs(n.y) > 0.9f) { _orbit.pitch = n.y > 0 ? 89f : -89f; }
            else
            {
                _orbit.pitch = 0f;
                if (Mathf.Abs(n.x) > 0.9f) _orbit.yaw = n.x > 0 ? 90f : -90f;
                else _orbit.yaw = n.z > 0 ? 180f : 0f;
            }
        }

        /// <summary>True when the mouse (GUI space) is over the cube corner.</summary>
        public bool ContainsGuiPoint(Vector2 guiPoint) => _guiRect().Contains(guiPoint);
    }
}
