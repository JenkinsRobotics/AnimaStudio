using UnityEngine;

namespace AnimaStudio
{
    /// <summary>
    /// Minimal CAD-style orbit camera: right-drag orbits, middle-drag pans,
    /// wheel zooms. A stand-in until we bring in a proper ViewCube + navigation;
    /// enough to inspect the assembly while we build.
    /// </summary>
    public sealed class CameraOrbit : MonoBehaviour
    {
        public Vector3 target = Vector3.zero;
        public float distance = 0.6f;
        public float yaw = 30f;
        public float pitch = 20f;

        [Header("Sensitivity")]
        public float orbitSpeed = 3f;
        public float panSpeed = 0.05f;
        public float zoomSpeed = 0.08f;

        void LateUpdate()
        {
            if (Input.GetMouseButton(1))
            {
                yaw += Input.GetAxis("Mouse X") * orbitSpeed;
                pitch = Mathf.Clamp(pitch - Input.GetAxis("Mouse Y") * orbitSpeed, -85f, 85f);
            }

            if (Input.GetMouseButton(2))
            {
                Vector3 shift =
                    (transform.right * Input.GetAxis("Mouse X") + transform.up * Input.GetAxis("Mouse Y"))
                    * distance * panSpeed;
                target -= shift;
            }

            float scroll = Input.mouseScrollDelta.y;
            if (Mathf.Abs(scroll) > 0.001f)
                distance = Mathf.Clamp(distance * (1f - scroll * zoomSpeed), 0.02f, 100f);

            Quaternion rotation = Quaternion.Euler(pitch, yaw, 0f);
            transform.position = target + rotation * new Vector3(0f, 0f, -distance);
            transform.rotation = Quaternion.LookRotation(target - transform.position, Vector3.up);
        }
    }
}
