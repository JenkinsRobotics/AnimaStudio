using System;
using UnityEngine;
using UnityEngine.Rendering;

public sealed class CodexBenchBridge : MonoBehaviour {
  public Shader vertexColorShader;
  [Serializable] private sealed class MeshPayload {
    public float[] positions;
    public float[] normals;
    public float[] colors;
    public uint[] indices;
    public float[] edgePositions;
    public int triangles;
  }

  [Serializable] private sealed class LightPayload {
    public float[] color;
    public float[] direction;
    public float intensity;
  }

  [Serializable] private sealed class ThemePayload {
    public float[] background;
    public float[] edge;
    public float[] selection;
    public float roughness;
    public float metallic;
    public LightPayload key;
    public LightPayload fill;
    public LightPayload rim;
  }

  private Camera sceneCamera;
  private GameObject model;
  private Material faceMaterial;
  private Material edgeMaterial;
  private Bounds modelBounds;
  private Vector3 target;
  private float distance = 4;
  private float yaw = .65f;
  private float pitch = .42f;
  private float roll;

  private void Awake() {
    gameObject.name = "CodexBenchBridge";
    sceneCamera = Camera.main;
    if (sceneCamera == null) {
      var cameraObject = new GameObject("Main Camera");
      cameraObject.tag = "MainCamera";
      sceneCamera = cameraObject.AddComponent<Camera>();
    }
    sceneCamera.clearFlags = CameraClearFlags.SolidColor;
    sceneCamera.nearClipPlane = .0001f;
    sceneCamera.farClipPlane = 100000;
    sceneCamera.backgroundColor = new Color(.16f, .17f, .19f);
    UpdateCamera();
  }

  public void LoadMesh(string json) {
    var payload = JsonUtility.FromJson<MeshPayload>(json);
    ClearMesh("");
    if (payload == null || payload.positions == null || payload.positions.Length < 3) return;
    model = new GameObject("STEP Tessellation");
    var mesh = new Mesh { indexFormat = IndexFormat.UInt32, name = "Open CASCADE STEP mesh" };
    var vertices = Vectors(payload.positions);
    mesh.vertices = vertices;
    mesh.normals = Vectors(payload.normals);
    mesh.colors = Colors(payload.colors);
    var triangles = new int[payload.indices.Length];
    for (var index = 0; index < triangles.Length; index++) triangles[index] = (int)payload.indices[index];
    mesh.triangles = triangles;
    mesh.RecalculateBounds();
    var filter = model.AddComponent<MeshFilter>();
    filter.sharedMesh = mesh;
    faceMaterial = new Material(vertexColorShader != null ? vertexColorShader : Shader.Find("CodexBench/VertexColor"));
    model.AddComponent<MeshRenderer>().sharedMaterial = faceMaterial;

    if (payload.edgePositions != null && payload.edgePositions.Length >= 6) {
      var edgeObject = new GameObject("B-Rep Edges");
      edgeObject.transform.SetParent(model.transform, false);
      var edgeMesh = new Mesh { indexFormat = IndexFormat.UInt32, name = "B-Rep edge lines" };
      var edgeVertices = Vectors(payload.edgePositions);
      var edgeIndices = new int[edgeVertices.Length];
      for (var index = 0; index < edgeIndices.Length; index++) edgeIndices[index] = index;
      edgeMesh.vertices = edgeVertices;
      edgeMesh.SetIndices(edgeIndices, MeshTopology.Lines, 0);
      edgeObject.AddComponent<MeshFilter>().sharedMesh = edgeMesh;
      edgeMaterial = new Material(Shader.Find("Unlit/Color"));
      edgeMaterial.color = new Color(.16f, .18f, .22f);
      edgeObject.AddComponent<MeshRenderer>().sharedMaterial = edgeMaterial;
    }
    modelBounds = mesh.bounds;
    Fit("");
  }

  public void ClearMesh(string ignored) {
    if (model != null) Destroy(model);
    model = null;
  }

  public void SetTheme(string json) {
    var theme = JsonUtility.FromJson<ThemePayload>(json);
    if (theme == null) return;
    if (theme.background != null && theme.background.Length >= 3)
      sceneCamera.backgroundColor = new Color(theme.background[0], theme.background[1], theme.background[2]);
    if (faceMaterial != null) {
      faceMaterial.SetFloat("_Roughness", theme.roughness);
      faceMaterial.SetFloat("_Metallic", theme.metallic);
      if (theme.selection != null && theme.selection.Length >= 3)
        faceMaterial.SetColor("_SelectionColor", ColorOf(theme.selection));
      if (theme.key != null) faceMaterial.SetColor("_KeyColor", ColorOf(theme.key.color) * theme.key.intensity);
      if (theme.fill != null) faceMaterial.SetColor("_FillColor", ColorOf(theme.fill.color) * theme.fill.intensity);
      if (theme.rim != null) faceMaterial.SetColor("_RimColor", ColorOf(theme.rim.color) * theme.rim.intensity);
    }
    if (edgeMaterial != null && theme.edge != null) edgeMaterial.color = ColorOf(theme.edge);
  }

  public void Fit(string ignored) {
    if (model == null) return;
    target = modelBounds.center;
    distance = Mathf.Max(modelBounds.size.magnitude * 1.6f, .05f);
    UpdateCamera();
  }

  private void Update() {
    var dx = Input.GetAxis("Mouse X");
    var dy = Input.GetAxis("Mouse Y");
    if (Input.GetMouseButton(1)) {
      if (Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift)) roll += dx * .02f;
      else { yaw -= dx * .02f; pitch = Mathf.Clamp(pitch + dy * .02f, -1.52f, 1.52f); }
    } else if (Input.GetMouseButton(2) || ((Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift)) && Input.GetMouseButton(0))) {
      var amount = distance * .003f;
      target += sceneCamera.transform.right * -dx * amount + sceneCamera.transform.up * -dy * amount;
    }
    var wheel = Input.mouseScrollDelta.y;
    if (Mathf.Abs(wheel) > .001f) distance = Mathf.Max(.002f, distance * Mathf.Exp(-wheel * .12f));
    UpdateCamera();
  }

  private void UpdateCamera() {
    var cp = Mathf.Cos(pitch);
    var offset = new Vector3(distance * cp * Mathf.Sin(yaw), distance * Mathf.Sin(pitch), distance * cp * Mathf.Cos(yaw));
    sceneCamera.transform.position = target + offset;
    sceneCamera.transform.rotation = Quaternion.LookRotation(target - sceneCamera.transform.position, Vector3.up) * Quaternion.AngleAxis(roll * Mathf.Rad2Deg, Vector3.forward);
  }

  private static Vector3[] Vectors(float[] values) {
    if (values == null) return Array.Empty<Vector3>();
    var output = new Vector3[values.Length / 3];
    for (var index = 0; index < output.Length; index++)
      output[index] = new Vector3(values[index * 3], values[index * 3 + 1], values[index * 3 + 2]);
    return output;
  }

  private static Color[] Colors(float[] values) {
    if (values == null) return Array.Empty<Color>();
    var output = new Color[values.Length / 4];
    for (var index = 0; index < output.Length; index++)
      output[index] = new Color(values[index * 4], values[index * 4 + 1], values[index * 4 + 2], values[index * 4 + 3]);
    return output;
  }

  private static Color ColorOf(float[] values) {
    return values == null || values.Length < 3 ? Color.white : new Color(values[0], values[1], values[2], 1);
  }
}
