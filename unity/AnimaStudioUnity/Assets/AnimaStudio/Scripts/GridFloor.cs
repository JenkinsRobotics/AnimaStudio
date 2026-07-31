using System.Collections.Generic;
using UnityEngine;

namespace AnimaStudio
{
    /// <summary>
    /// CAD-style reference grid: fine + major line grids on the ground plane
    /// and X/Z axis lines through the origin. Meshes are built at runtime from
    /// line topology; the materials are assigned by the scene builder so their
    /// shader ships in the player.
    /// </summary>
    public sealed class GridFloor : MonoBehaviour
    {
        [Tooltip("Template material (Unlit/Color); instanced per line set.")]
        public Material lineMaterial;
        public float extent = 5f;        // grid covers ±extent metres
        public float fineStep = 0.1f;
        public float majorStep = 1f;

        static readonly Color FineColor = new Color(0.88f, 0.895f, 0.915f);
        static readonly Color MajorColor = new Color(0.78f, 0.80f, 0.83f);
        static readonly Color AxisXColor = new Color(0.85f, 0.45f, 0.45f);
        static readonly Color AxisZColor = new Color(0.42f, 0.55f, 0.85f);

        void Start()
        {
            Build("GridFine", FineLines(), FineColor);
            Build("GridMajor", MajorLines(), MajorColor);
            Build("AxisX", new[] { new Vector3(-extent, 0, 0), new Vector3(extent, 0, 0) },
                AxisXColor);
            Build("AxisZ", new[] { new Vector3(0, 0, -extent), new Vector3(0, 0, extent) },
                AxisZColor);
        }

        Vector3[] FineLines() => GridLines(fineStep, skipMajor: true);
        Vector3[] MajorLines() => GridLines(majorStep, skipMajor: false);

        Vector3[] GridLines(float step, bool skipMajor)
        {
            var points = new List<Vector3>();
            for (float v = -extent; v <= extent + step * 0.5f; v += step)
            {
                if (Mathf.Abs(v) < step * 0.25f) continue; // axes drawn separately
                if (skipMajor && Mathf.Abs(v / majorStep - Mathf.Round(v / majorStep)) < 0.01f)
                    continue;
                points.Add(new Vector3(v, 0, -extent));
                points.Add(new Vector3(v, 0, extent));
                points.Add(new Vector3(-extent, 0, v));
                points.Add(new Vector3(extent, 0, v));
            }
            return points.ToArray();
        }

        void Build(string childName, Vector3[] points, Color color)
        {
            var mesh = new Mesh { vertices = points };
            var indices = new int[points.Length];
            for (int i = 0; i < indices.Length; i++) indices[i] = i;
            mesh.SetIndices(indices, MeshTopology.Lines, 0);

            var go = new GameObject(childName);
            go.transform.SetParent(transform, false);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = go.AddComponent<MeshRenderer>();
            var material = lineMaterial != null
                ? new Material(lineMaterial)
                : new Material(Shader.Find("Unlit/Color") ?? Shader.Find("Standard"));
            if (material.HasProperty("_Color")) material.SetColor("_Color", color);
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            renderer.receiveShadows = false;
        }
    }
}
