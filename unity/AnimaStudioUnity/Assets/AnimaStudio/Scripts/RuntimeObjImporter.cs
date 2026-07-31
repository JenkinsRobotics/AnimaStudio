using System.Collections.Generic;
using System.Globalization;
using System.IO;
using UnityEngine;

namespace AnimaStudio
{
    /// <summary>
    /// Minimal runtime Wavefront OBJ → <see cref="Mesh"/> loader. Runs in a
    /// standalone build (unlike Unity's editor-only import), so users can bring
    /// their own parts at runtime. Handles v / vn / f (tris + quads, with or
    /// without normal/uv indices). Groups/materials are ignored — one mesh per
    /// file, which is exactly "one part" for assembly.
    /// </summary>
    public static class RuntimeObjImporter
    {
        public static Mesh Load(string path)
        {
            if (!File.Exists(path)) { Debug.LogError("OBJ not found: " + path); return null; }
            return Parse(File.ReadAllText(path), Path.GetFileNameWithoutExtension(path));
        }

        public static Mesh Parse(string text, string name)
        {
            var positions = new List<Vector3>();
            var normals = new List<Vector3>();
            var outVerts = new List<Vector3>();
            var outNormals = new List<Vector3>();
            var triangles = new List<int>();
            var remap = new Dictionary<string, int>();

            var ci = CultureInfo.InvariantCulture;
            foreach (string raw in text.Split('\n'))
            {
                string line = raw.Trim();
                if (line.Length == 0 || line[0] == '#') continue;
                string[] t = line.Split((char[])null, System.StringSplitOptions.RemoveEmptyEntries);
                if (t.Length == 0) continue;

                if (t[0] == "v" && t.Length >= 4)
                {
                    // OBJ is right-handed; negate X so it reads correctly in Unity's
                    // left-handed space (a tuning point, mirror of the pose convert).
                    positions.Add(new Vector3(
                        -float.Parse(t[1], ci), float.Parse(t[2], ci), float.Parse(t[3], ci)));
                }
                else if (t[0] == "vn" && t.Length >= 4)
                {
                    normals.Add(new Vector3(
                        -float.Parse(t[1], ci), float.Parse(t[2], ci), float.Parse(t[3], ci)));
                }
                else if (t[0] == "f" && t.Length >= 4)
                {
                    // Fan-triangulate the face; reverse winding because we negated X.
                    int n = t.Length - 1;
                    var faceIdx = new int[n];
                    for (int i = 0; i < n; i++) faceIdx[i] = ResolveVertex(t[i + 1]);
                    for (int i = 1; i < n - 1; i++)
                    {
                        triangles.Add(faceIdx[0]);
                        triangles.Add(faceIdx[i + 1]);
                        triangles.Add(faceIdx[i]);
                    }
                }
            }

            int ResolveVertex(string token)
            {
                if (remap.TryGetValue(token, out int existing)) return existing;
                string[] parts = token.Split('/');
                int vi = ParseIndex(parts[0], positions.Count);
                int ni = parts.Length >= 3 && parts[2].Length > 0 ? ParseIndex(parts[2], normals.Count) : -1;
                outVerts.Add(vi >= 0 && vi < positions.Count ? positions[vi] : Vector3.zero);
                outNormals.Add(ni >= 0 && ni < normals.Count ? normals[ni] : Vector3.zero);
                int idx = outVerts.Count - 1;
                remap[token] = idx;
                return idx;
            }

            var mesh = new Mesh { name = name };
            mesh.indexFormat = outVerts.Count > 65000
                ? UnityEngine.Rendering.IndexFormat.UInt32
                : UnityEngine.Rendering.IndexFormat.UInt16;
            mesh.SetVertices(outVerts);
            if (HasNormals(outNormals)) mesh.SetNormals(outNormals);
            mesh.SetTriangles(triangles, 0);
            if (!HasNormals(outNormals)) mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            return mesh;
        }

        static int ParseIndex(string s, int count)
        {
            if (!int.TryParse(s, out int i)) return -1;
            return i > 0 ? i - 1 : count + i; // OBJ is 1-based; negatives are relative
        }

        static bool HasNormals(List<Vector3> normals)
        {
            foreach (Vector3 n in normals) if (n.sqrMagnitude > 1e-8f) return true;
            return false;
        }
    }
}
