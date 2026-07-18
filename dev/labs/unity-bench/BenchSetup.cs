// Builds the demo scene: the three STEP-converted parts side by side,
// camera + lights, saved as Assets/Bench.unity. Run via -executeMethod.
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class BenchSetup {
  public static void Build() {
    var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
    string[] models = { "ARCADP001", "MOTOR", "TIRE" };
    float x = -0.35f;
    foreach (var name in models) {
      var prefab = AssetDatabase.LoadAssetAtPath<GameObject>($"Assets/Models/{name}.obj");
      if (prefab == null) { Debug.LogError($"missing {name}"); continue; }
      var instance = Object.Instantiate(prefab);
      instance.name = name;
      var bounds = new Bounds();
      bool first = true;
      foreach (var renderer in instance.GetComponentsInChildren<Renderer>()) {
        if (first) { bounds = renderer.bounds; first = false; }
        else bounds.Encapsulate(renderer.bounds);
      }
      float scale = 0.22f / Mathf.Max(bounds.extents.magnitude, 0.001f);
      instance.transform.localScale = Vector3.one * scale;
      instance.transform.position = new Vector3(x, 0, 0) - bounds.center * scale;
      x += 0.35f;
    }
    var light = new GameObject("Key Light").AddComponent<Light>();
    light.type = LightType.Directional;
    light.intensity = 1.4f;
    light.transform.rotation = Quaternion.Euler(45, -30, 0);
    var camera = new GameObject("Main Camera").AddComponent<Camera>();
    camera.tag = "MainCamera";
    camera.transform.position = new Vector3(0, 0.35f, 0.8f);
    camera.transform.LookAt(Vector3.zero);
    camera.clearFlags = CameraClearFlags.SolidColor;
    camera.backgroundColor = new Color(0.08f, 0.09f, 0.11f);
    EditorSceneManager.SaveScene(scene, "Assets/Bench.unity");
    Debug.Log("BENCH SCENE SAVED");
  }
}
