using System.Collections.Generic;
using UnityEngine;

namespace AnimaStudio
{
    /// <summary>
    /// Mate-connector snapping over tessellated meshes (no BRep available):
    /// grows the smooth surface patch around the hit triangle, classifies it
    /// as planar or cylindrical, and returns an Onshape-style snap —
    /// bore/cylinder axis center, flat-face center, nearby vertex, or the raw
    /// hit point. All positions/axes are in the mesh's LOCAL space.
    /// </summary>
    public static class MeshSnapping
    {
        public enum Kind { Raw, Vertex, EdgePoint, EdgeCenter, FaceCenter, BoreCenter }

        public struct Snap
        {
            public Kind kind;
            public Vector3 localPosition;
            public Vector3 localPrimary;
        }

        sealed class Cache
        {
            public Vector3[] vertices;
            public int[] triangles;         // welded vertex ids per corner
            public Vector3[] positionsById; // welded id → position
            public Vector3[] faceNormals;
            public Dictionary<long, List<int>> edgeToTriangles;
            // Feature edges (dihedral > 32° or boundary), as welded id pairs,
            // indexed per vertex for chain walking.
            public List<(int a, int b)> featureEdges;
            public Dictionary<int, List<int>> featureEdgesByVertex;
        }

        static readonly Dictionary<Mesh, Cache> Caches = new Dictionary<Mesh, Cache>();

        public static Snap Analyze(Mesh mesh, int hitTriangle, Vector3 hitLocal,
            float vertexSnapRadius)
        {
            Cache cache = GetCache(mesh);
            var fallback = new Snap
            {
                kind = Kind.Raw,
                localPosition = hitLocal,
                localPrimary = cache.faceNormals[hitTriangle],
            };
            if (hitTriangle < 0 || hitTriangle * 3 >= cache.triangles.Length)
                return fallback;

            // Near a feature edge? Circular chains snap to their CENTER
            // (bore rims), straight ones to the closest edge point.
            Snap? edgeSnap = TryEdgeSnap(cache, hitTriangle, hitLocal,
                vertexSnapRadius * 1.6f);
            if (edgeSnap.HasValue && edgeSnap.Value.kind == Kind.EdgeCenter)
                return edgeSnap.Value;

            // Vertex snap when the cursor is right on a corner.
            for (int corner = 0; corner < 3; corner++)
            {
                Vector3 v = cache.positionsById[
                    cache.triangles[hitTriangle * 3 + corner]];
                if ((v - hitLocal).sqrMagnitude < vertexSnapRadius * vertexSnapRadius)
                    return new Snap
                    {
                        kind = Kind.Vertex,
                        localPosition = v,
                        localPrimary = cache.faceNormals[hitTriangle],
                    };
            }

            if (edgeSnap.HasValue) return edgeSnap.Value;

            // 48°: coarse tessellations step 30–45° between bore facets, while
            // real feature edges are typically 60°+.
            List<int> patch = GrowPatch(cache, hitTriangle, 600, 48f);
            if (patch.Count < 2) return fallback;

            // Classify: if patch normals barely spread, it is a plane.
            Vector3 hitNormal = cache.faceNormals[hitTriangle];
            float maxSpread = 0f;
            foreach (int triangle in patch)
                maxSpread = Mathf.Max(maxSpread,
                    Vector3.Angle(hitNormal, cache.faceNormals[triangle]));

            var patchVerts = new List<Vector3>();
            var seenIds = new HashSet<int>();
            foreach (int triangle in patch)
                for (int corner = 0; corner < 3; corner++)
                {
                    int id = cache.triangles[triangle * 3 + corner];
                    if (seenIds.Add(id)) patchVerts.Add(cache.positionsById[id]);
                }

            if (maxSpread < 8f)
            {
                Vector3 center = Vector3.zero;
                foreach (Vector3 v in patchVerts) center += v;
                return new Snap
                {
                    kind = Kind.FaceCenter,
                    localPosition = center / patchVerts.Count,
                    localPrimary = hitNormal,
                };
            }

            // Curved patch: cylinder axis = direction the normals never point
            // along. Average cross products of spread normal pairs.
            Vector3 axis = Vector3.zero;
            foreach (int triangle in patch)
            {
                Vector3 n = cache.faceNormals[triangle];
                if (Vector3.Angle(hitNormal, n) < 10f) continue;
                Vector3 cross = Vector3.Cross(hitNormal, n);
                if (Vector3.Dot(cross, axis) < 0f) cross = -cross;
                axis += cross;
            }
            if (axis.sqrMagnitude < 1e-10f) return fallback;
            axis.Normalize();

            if (!FitCircle(patchVerts, axis, out Vector3 centerLocal))
                return fallback;
            return new Snap
            {
                kind = Kind.BoreCenter,
                localPosition = centerLocal,
                localPrimary = axis,
            };
        }

        /// <summary>Kåsa least-squares circle fit of points in the plane ⊥
        /// axis; false when the points are not circle-like.</summary>
        static bool FitCircle(List<Vector3> points, Vector3 axis, out Vector3 center)
        {
            center = default;
            int count = points.Count;
            if (count < 4) return false;
            Vector3 u = Vector3.Cross(axis, Mathf.Abs(axis.y) < 0.9f
                ? Vector3.up : Vector3.right).normalized;
            Vector3 w = Vector3.Cross(axis, u);
            double sxx = 0, sxy = 0, syy = 0, sx = 0, sy = 0, sxz = 0, syz = 0, sz = 0;
            double along = 0;
            foreach (Vector3 v in points)
            {
                double x = Vector3.Dot(v, u);
                double y = Vector3.Dot(v, w);
                double z = x * x + y * y;
                sxx += x * x; sxy += x * y; syy += y * y;
                sx += x; sy += y; sz += z; sxz += x * z; syz += y * z;
                along += Vector3.Dot(v, axis);
            }
            double a11 = sxx, a12 = sxy, a13 = sx;
            double a21 = sxy, a22 = syy, a23 = sy;
            double a31 = sx, a32 = sy, a33 = count;
            double det = a11 * (a22 * a33 - a23 * a32)
                - a12 * (a21 * a33 - a23 * a31)
                + a13 * (a21 * a32 - a22 * a31);
            if (System.Math.Abs(det) < 1e-12) return false;
            double b1 = sxz, b2 = syz, b3 = sz;
            double ca = (b1 * (a22 * a33 - a23 * a32)
                - a12 * (b2 * a33 - a23 * b3)
                + a13 * (b2 * a32 - a22 * b3)) / det;
            double cb = (a11 * (b2 * a33 - a23 * b3)
                - b1 * (a21 * a33 - a23 * a31)
                + a13 * (a21 * b3 - b2 * a31)) / det;
            double centerX = ca / 2.0, centerY = cb / 2.0;

            double meanR = 0, varR = 0;
            foreach (Vector3 v in points)
            {
                double dx = Vector3.Dot(v, u) - centerX;
                double dy = Vector3.Dot(v, w) - centerY;
                meanR += System.Math.Sqrt(dx * dx + dy * dy);
            }
            meanR /= count;
            foreach (Vector3 v in points)
            {
                double dx = Vector3.Dot(v, u) - centerX;
                double dy = Vector3.Dot(v, w) - centerY;
                double r = System.Math.Sqrt(dx * dx + dy * dy);
                varR += (r - meanR) * (r - meanR);
            }
            if (meanR < 1e-6 || System.Math.Sqrt(varR / count) / meanR > 0.18)
                return false;
            center = u * (float)centerX + w * (float)centerY
                + axis * (float)(along / count);
            return true;
        }

        static Vector3 ClosestOnSegment(Vector3 point, Vector3 a, Vector3 b)
        {
            Vector3 ab = b - a;
            float t = Mathf.Clamp01(Vector3.Dot(point - a, ab)
                / Mathf.Max(ab.sqrMagnitude, 1e-12f));
            return a + ab * t;
        }

        /// <summary>Snap to the nearest feature edge: a circular edge chain
        /// (bore rim) yields its CENTER with primary = the rim plane normal;
        /// a straight/other chain yields the closest point on the edge.</summary>
        static Snap? TryEdgeSnap(Cache cache, int hitTriangle, Vector3 hitLocal,
            float radius)
        {
            int bestEdge = -1;
            float bestDistance = radius;
            Vector3 bestPoint = default;
            var candidates = new HashSet<int>();
            for (int corner = 0; corner < 3; corner++)
            {
                int vid = cache.triangles[hitTriangle * 3 + corner];
                if (!cache.featureEdgesByVertex.TryGetValue(vid, out List<int> list))
                    continue;
                foreach (int edgeIndex in list) candidates.Add(edgeIndex);
            }
            foreach (int edgeIndex in candidates)
            {
                (int a, int b) = cache.featureEdges[edgeIndex];
                Vector3 closest = ClosestOnSegment(hitLocal,
                    cache.positionsById[a], cache.positionsById[b]);
                float distance = (closest - hitLocal).magnitude;
                if (distance < bestDistance)
                {
                    bestDistance = distance;
                    bestEdge = edgeIndex;
                    bestPoint = closest;
                }
            }
            if (bestEdge < 0) return null;

            // Walk the connected feature-edge chain.
            var chainVertexIds = new HashSet<int>();
            var visitedEdges = new HashSet<int> { bestEdge };
            var frontier = new Queue<int>();
            frontier.Enqueue(bestEdge);
            while (frontier.Count > 0 && visitedEdges.Count < 200)
            {
                (int a, int b) = cache.featureEdges[frontier.Dequeue()];
                foreach (int vid in new[] { a, b })
                {
                    if (!chainVertexIds.Add(vid)) continue;
                    if (!cache.featureEdgesByVertex.TryGetValue(vid,
                            out List<int> incident))
                        continue;
                    foreach (int edgeIndex in incident)
                        if (visitedEdges.Add(edgeIndex)) frontier.Enqueue(edgeIndex);
                }
            }
            if (chainVertexIds.Count >= 6)
            {
                var chainPoints = new List<Vector3>();
                foreach (int vid in chainVertexIds)
                    chainPoints.Add(cache.positionsById[vid]);
                // Plane from three well-spread chain points.
                Vector3 p0 = chainPoints[0], pa = p0, pb = p0;
                float farthest = 0f;
                foreach (Vector3 p in chainPoints)
                {
                    float d = (p - p0).sqrMagnitude;
                    if (d > farthest) { farthest = d; pa = p; }
                }
                float widest = 0f;
                Vector3 lineDir = (pa - p0).normalized;
                foreach (Vector3 p in chainPoints)
                {
                    Vector3 offAxis = p - p0
                        - lineDir * Vector3.Dot(p - p0, lineDir);
                    if (offAxis.sqrMagnitude > widest)
                    {
                        widest = offAxis.sqrMagnitude;
                        pb = p;
                    }
                }
                Vector3 normal = Vector3.Cross(pa - p0, pb - p0);
                if (normal.sqrMagnitude > 1e-12f
                    && FitCircle(chainPoints, normal.normalized,
                        out Vector3 rimCenter))
                    return new Snap
                    {
                        kind = Kind.EdgeCenter,
                        localPosition = rimCenter,
                        localPrimary = normal.normalized,
                    };
            }
            return new Snap
            {
                kind = Kind.EdgePoint,
                localPosition = bestPoint,
                localPrimary = cache.faceNormals[hitTriangle],
            };
        }

        static List<int> GrowPatch(Cache cache, int start, int maxTriangles,
            float stepAngleDeg)
        {
            var patch = new List<int> { start };
            var visited = new HashSet<int> { start };
            var frontier = new Queue<int>();
            frontier.Enqueue(start);
            while (frontier.Count > 0 && patch.Count < maxTriangles)
            {
                int triangle = frontier.Dequeue();
                for (int edge = 0; edge < 3; edge++)
                {
                    long key = EdgeKey(
                        cache.triangles[triangle * 3 + edge],
                        cache.triangles[triangle * 3 + (edge + 1) % 3]);
                    if (!cache.edgeToTriangles.TryGetValue(key, out List<int> shared))
                        continue;
                    foreach (int neighbor in shared)
                    {
                        if (visited.Contains(neighbor)) continue;
                        if (Vector3.Angle(cache.faceNormals[triangle],
                                cache.faceNormals[neighbor]) > stepAngleDeg)
                            continue;
                        visited.Add(neighbor);
                        patch.Add(neighbor);
                        frontier.Enqueue(neighbor);
                    }
                }
            }
            return patch;
        }

        static long EdgeKey(int a, int b) =>
            a < b ? ((long)a << 32) | (uint)b : ((long)b << 32) | (uint)a;

        static Cache GetCache(Mesh mesh)
        {
            if (Caches.TryGetValue(mesh, out Cache cached)) return cached;
            Vector3[] vertices = mesh.vertices;
            int[] rawTriangles = mesh.triangles;

            // Weld by position: OBJ import splits vertices per-normal, which
            // would otherwise break edge adjacency.
            var idByQuantized = new Dictionary<Vector3Int, int>();
            var positionsById = new List<Vector3>();
            int[] weldedId = new int[vertices.Length];
            for (int i = 0; i < vertices.Length; i++)
            {
                var q = new Vector3Int(
                    Mathf.RoundToInt(vertices[i].x * 200000f),
                    Mathf.RoundToInt(vertices[i].y * 200000f),
                    Mathf.RoundToInt(vertices[i].z * 200000f));
                if (!idByQuantized.TryGetValue(q, out int id))
                {
                    id = positionsById.Count;
                    positionsById.Add(vertices[i]);
                    idByQuantized[q] = id;
                }
                weldedId[i] = id;
            }

            int triangleCount = rawTriangles.Length / 3;
            var welded = new int[rawTriangles.Length];
            var faceNormals = new Vector3[triangleCount];
            var edgeToTriangles = new Dictionary<long, List<int>>();
            for (int t = 0; t < triangleCount; t++)
            {
                for (int corner = 0; corner < 3; corner++)
                    welded[t * 3 + corner] = weldedId[rawTriangles[t * 3 + corner]];
                Vector3 p0 = positionsById[welded[t * 3]];
                Vector3 p1 = positionsById[welded[t * 3 + 1]];
                Vector3 p2 = positionsById[welded[t * 3 + 2]];
                faceNormals[t] = Vector3.Cross(p1 - p0, p2 - p0).normalized;
                for (int edge = 0; edge < 3; edge++)
                {
                    long key = EdgeKey(welded[t * 3 + edge],
                        welded[t * 3 + (edge + 1) % 3]);
                    if (!edgeToTriangles.TryGetValue(key, out List<int> list))
                        edgeToTriangles[key] = list = new List<int>(2);
                    list.Add(t);
                }
            }

            // Feature edges: sharp dihedral (>32°) or open boundary.
            var featureEdges = new List<(int a, int b)>();
            var featureEdgesByVertex = new Dictionary<int, List<int>>();
            foreach (KeyValuePair<long, List<int>> entry in edgeToTriangles)
            {
                bool feature = entry.Value.Count == 1
                    || (entry.Value.Count == 2
                        && Vector3.Angle(faceNormals[entry.Value[0]],
                            faceNormals[entry.Value[1]]) > 32f);
                if (!feature) continue;
                int a = (int)(entry.Key >> 32);
                int b = (int)(uint)entry.Key;
                int index = featureEdges.Count;
                featureEdges.Add((a, b));
                foreach (int vid in new[] { a, b })
                {
                    if (!featureEdgesByVertex.TryGetValue(vid, out List<int> list))
                        featureEdgesByVertex[vid] = list = new List<int>(2);
                    list.Add(index);
                }
            }

            var cache = new Cache
            {
                vertices = vertices,
                triangles = welded,
                positionsById = positionsById.ToArray(),
                faceNormals = faceNormals,
                edgeToTriangles = edgeToTriangles,
                featureEdges = featureEdges,
                featureEdgesByVertex = featureEdgesByVertex,
            };
            Caches[mesh] = cache;
            return cache;
        }
    }
}
