#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace AnimaStudio.EditorTools
{
    /// <summary>
    /// One-click scene setup so you never wire GameObjects by hand. Builds a
    /// camera + light + the Assembly component, saves it, and tells you to Play.
    /// Menu: <b>AnimaStudio ▸ Build Assembly Scene</b>.
    /// </summary>
    public static class AnimaStudioSceneBuilder
    {
        const string StudioScenePath = "Assets/AnimaStudio/Scenes/Studio.unity";
        const string WorkbenchScenePath = "Assets/AnimaStudio/Scenes/AssemblyWorkbench.unity";

        /// <summary>
        /// The app scene: engine-connected StudioShell with the dark shell UI.
        /// </summary>
        [MenuItem("AnimaStudio/Build Studio Scene")]
        public static void BuildStudioScene()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var cameraObject = new GameObject("Main Camera") { tag = "MainCamera" };
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.925f, 0.933f, 0.945f, 1f); // light CAD canvas
            camera.nearClipPlane = 0.001f;
            var orbit = cameraObject.AddComponent<CameraOrbit>();
            orbit.distance = 0.8f;

            var lightObject = new GameObject("Directional Light");
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.15f;
            light.transform.rotation = Quaternion.Euler(50f, -30f, 0f);

            // CAD reference grid (replaces the old solid ground plane). The
            // editor-created material pins Unlit/Color into the build.
            var ground = new GameObject("Ground");
            var grid = ground.AddComponent<GridFloor>();
            grid.lineMaterial = new Material(Shader.Find("Unlit/Color"));

            var studio = new GameObject("Studio");
            studio.AddComponent<StudioShell>();

            Directory.CreateDirectory("Assets/AnimaStudio/Scenes");
            EditorSceneManager.SaveScene(scene, StudioScenePath);
            RegisterScenes();
            AssetDatabase.Refresh();
            Debug.Log("[AnimaStudio] Built Studio scene. Press Play — the engine "
                + "launches and the character loads with the full shell UI.");
        }

        /// <summary>
        /// Standalone player: unity/AnimaStudioUnity/Builds/AnimaStudio.app.
        /// The app finds the repo by walking up from its own location (keep the
        /// build inside the repo) or via ANIMASTUDIO_REPO.
        /// </summary>
        [MenuItem("AnimaStudio/Build macOS App")]
        public static void BuildMacApp()
        {
            if (!File.Exists(StudioScenePath)) BuildStudioScene();
            if (!File.Exists(WorkbenchScenePath)) BuildAssemblyWorkbench();
            RegisterScenes();

            var options = new BuildPlayerOptions
            {
                scenes = new[] { StudioScenePath, WorkbenchScenePath },
                locationPathName = "Builds/AnimaStudio.app",
                target = BuildTarget.StandaloneOSX,
                options = BuildOptions.None,
            };
            var report = BuildPipeline.BuildPlayer(options);
            Debug.Log("[AnimaStudio] Build " + report.summary.result + " → "
                + Path.GetFullPath("Builds/AnimaStudio.app")
                + " (" + report.summary.totalErrors + " errors)");
            if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
                throw new BuildFailedException("AnimaStudio player build failed");
            RegisterStepDocumentTypes("Builds/AnimaStudio.app/Contents/Info.plist");
        }

        /// <summary>
        /// Declare STEP/OBJ document types so Finder offers AnimaStudio under
        /// "Open With" (the user still picks it as default via Get Info).
        /// Receiving the Apple open-document event needs a native plugin —
        /// tracked as a follow-up; until then use Import inside the app.
        /// </summary>
        static void RegisterStepDocumentTypes(string plistPath)
        {
            if (!File.Exists(plistPath)) return;
            string plist = File.ReadAllText(plistPath);
            if (plist.Contains("CFBundleDocumentTypes")) return;
            const string docTypes =
                "\t<key>CFBundleDocumentTypes</key>\n"
                + "\t<array>\n"
                + "\t\t<dict>\n"
                + "\t\t\t<key>CFBundleTypeName</key>\n"
                + "\t\t\t<string>STEP model</string>\n"
                + "\t\t\t<key>CFBundleTypeExtensions</key>\n"
                + "\t\t\t<array>\n"
                + "\t\t\t\t<string>step</string>\n"
                + "\t\t\t\t<string>stp</string>\n"
                + "\t\t\t\t<string>obj</string>\n"
                + "\t\t\t</array>\n"
                + "\t\t\t<key>CFBundleTypeRole</key>\n"
                + "\t\t\t<string>Viewer</string>\n"
                + "\t\t</dict>\n"
                + "\t</array>\n";
            int insertAt = plist.LastIndexOf("</dict>");
            if (insertAt < 0) return;
            File.WriteAllText(plistPath,
                plist.Substring(0, insertAt) + docTypes + plist.Substring(insertAt));
            Debug.Log("[AnimaStudio] Registered STEP/OBJ document types in Info.plist");
        }

        static void RegisterScenes()
        {
            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(StudioScenePath, true),
                new EditorBuildSettingsScene(WorkbenchScenePath, true),
            };
        }

        /// <summary>Batchmode entry: build scenes + the standalone app.</summary>
        public static void BuildAll()
        {
            BuildStudioScene();
            BuildAssemblyWorkbench();
            BuildMacApp();
        }

        [MenuItem("AnimaStudio/Build Assembly Scene")]
        public static void BuildAssemblyScene()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var cameraObject = new GameObject("Main Camera") { tag = "MainCamera" };
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.16f, 0.17f, 0.19f, 1f);
            camera.nearClipPlane = 0.001f;
            cameraObject.AddComponent<CameraOrbit>();

            var lightObject = new GameObject("Directional Light");
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.1f;
            light.transform.rotation = Quaternion.Euler(50f, -30f, 0f);

            var assemblyObject = new GameObject("Assembly");
            assemblyObject.AddComponent<AssemblyScene>();

            Directory.CreateDirectory("Assets/AnimaStudio/Scenes");
            EditorSceneManager.SaveScene(scene, "Assets/AnimaStudio/Scenes/Assembly.unity");
            AssetDatabase.Refresh();

            Debug.Log(
                "[AnimaStudio] Built Assembly scene. Press Play — it launches the "
                + "AnimaCore engine and loads examples/pan_tilt_head.character.anima.");
        }

        [MenuItem("AnimaStudio/Build Assembly Workbench")]
        public static void BuildAssemblyWorkbench()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var cameraObject = new GameObject("Main Camera") { tag = "MainCamera" };
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.16f, 0.17f, 0.19f, 1f);
            camera.nearClipPlane = 0.001f;
            var orbit = cameraObject.AddComponent<CameraOrbit>();
            orbit.distance = 0.6f;

            var lightObject = new GameObject("Directional Light");
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.2f;
            light.transform.rotation = Quaternion.Euler(50f, -30f, 0f);

            // A subtle ground plane for orientation (10 x 10 m, scaled Unity plane).
            var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
            ground.name = "Ground";
            ground.transform.localScale = new Vector3(1f, 1f, 1f);
            var groundRenderer = ground.GetComponent<Renderer>();
            var groundShader = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
            var groundMat = new Material(groundShader);
            if (groundMat.HasProperty("_BaseColor")) groundMat.SetColor("_BaseColor", new Color(0.055f, 0.06f, 0.07f));
            if (groundMat.HasProperty("_Color")) groundMat.SetColor("_Color", new Color(0.055f, 0.06f, 0.07f));
            if (groundMat.HasProperty("_Glossiness")) groundMat.SetFloat("_Glossiness", 0.05f);
            groundRenderer.sharedMaterial = groundMat;

            var workbench = new GameObject("AssemblyWorkbench");
            workbench.AddComponent<AssemblyManager>();

            Directory.CreateDirectory("Assets/AnimaStudio/Scenes");
            EditorSceneManager.SaveScene(scene, "Assets/AnimaStudio/Scenes/AssemblyWorkbench.unity");
            AssetDatabase.Refresh();

            Debug.Log(
                "[AnimaStudio] Built Assembly Workbench. Press Play — add parts from "
                + "the library (base_plate, bracket), drag to position, save the assembly.");
        }
    }
}
#endif
