using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class CodexBenchBuilder {
  public static void BuildWebGL() {
    Directory.CreateDirectory("Assets/Scenes");
    var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
    var bridge = new GameObject("CodexBenchBridge").AddComponent<CodexBenchBridge>();
    bridge.vertexColorShader = Shader.Find("CodexBench/VertexColor");
    var scenePath = "Assets/Scenes/CodexBench.unity";
    EditorSceneManager.SaveScene(scene, scenePath);
    PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Disabled;
    PlayerSettings.WebGL.dataCaching = false;
    PlayerSettings.WebGL.template = "PROJECT:CodexBench";
    PlayerSettings.productName = "Codex Bench Unity WebGL";
    PlayerSettings.companyName = "Anima Studio";
    var output = Path.GetFullPath(Path.Combine(Application.dataPath, "../../../build/unity-webgl"));
    Directory.CreateDirectory(output);
    var report = BuildPipeline.BuildPlayer(
      new[] { scenePath }, output, BuildTarget.WebGL, BuildOptions.None);
    if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
      throw new BuildFailedException("Unity WebGL build failed: " + report.summary.result);
    Debug.Log("CODEX_BENCH_UNITY_WEBGL=" + output);
  }
}
