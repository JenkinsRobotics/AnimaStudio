import { createPortal } from 'react-dom';
import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from 'react';
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { Home, Maximize } from 'lucide-react';
import type { DisplayStyle, ViewName, ViewportHandle } from './types';
export type ViewportProps = {
  navigationHost: HTMLDivElement | null;
  planes: boolean[];
  sketch: boolean;
  hidden?: boolean[];
  color?: string;
  opacity?: number;
  display?: DisplayStyle;
  section?: boolean;
  depthMm?: number;
  widthMm?: number;
  onSelect?: (index: number) => void;
  selectedPart?: number | null;
  onReady?: () => void;
};
function plateShape(w: number, h: number, r: number) {
  const s = new THREE.Shape();
  const x = -w / 2,
    y = -h / 2;
  s.moveTo(x + r, y);
  s.lineTo(x + w - r, y);
  s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r);
  s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h);
  s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r);
  s.quadraticCurveTo(x, y, x + r, y);
  return s;
}
function hole(s: THREE.Shape, x: number, y: number, r: number) {
  const path = new THREE.Path();
  path.absarc(x, y, r, 0, Math.PI * 2, true);
  s.holes.push(path);
}
export const CADViewport = forwardRef<ViewportHandle, ViewportProps>(
  function CADViewport(props, ref) {
    const host = useRef<HTMLDivElement>(null);
    const cubeHost = useRef<HTMLDivElement>(null);
    const runtime = useRef<{
      snap: (view: ViewName) => void;
      fit: () => void;
      update: (p: ViewportProps) => void;
      projection: (p: string) => void;
    } | null>(null);
    const latest = useRef(props);
    useEffect(() => {
      latest.current = props;
    }, [props]);
    const [view, setView] = useState('Isometric');
    const [projection, setProjection] = useState('Orthographic');
    const [error, setError] = useState('');
    useImperativeHandle(
      ref,
      () => ({
        snap: (v) => {
          runtime.current?.snap(v);
          setView(v);
        },
        fit: () => runtime.current?.fit(),
      }),
      [],
    );
    useEffect(() => {
      if (!host.current || !cubeHost.current) return;
      const el = host.current,
        cubeEl = cubeHost.current;
      let renderer: THREE.WebGLRenderer;
      let cubeRenderer: THREE.WebGLRenderer;
      try {
        renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
        cubeRenderer = new THREE.WebGLRenderer({
          antialias: true,
          alpha: true,
        });
      } catch {
        setError(
          'The 3D viewport requires WebGL. Enable hardware acceleration and reload.',
        );
        return;
      }
      renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
      renderer.localClippingEnabled = true;
      renderer.setClearColor(0x000000, 0);
      el.appendChild(renderer.domElement);
      const scene = new THREE.Scene();
      scene.add(new THREE.HemisphereLight(0xffffff, 0x82909e, 2.3));
      const light = new THREE.DirectionalLight(0xffffff, 3.1);
      light.position.set(-130, -180, 230);
      scene.add(light);
      const fill = new THREE.DirectionalLight(0xc9ddff, 1.4);
      fill.position.set(180, 60, 80);
      scene.add(fill);
      const target = new THREE.Vector3(0, 0, 32);
      const ortho = new THREE.OrthographicCamera(
        -100,
        100,
        100,
        -100,
        0.1,
        2000,
      );
      const perspective = new THREE.PerspectiveCamera(35, 1, 0.1, 2000);
      let camera: THREE.OrthographicCamera | THREE.PerspectiveCamera = ortho;
      camera.up.set(0, 0, 1);
      camera.position.set(170, -240, 160);
      camera.lookAt(target);
      let controls: OrbitControls<
        THREE.OrthographicCamera | THREE.PerspectiveCamera
      > = new OrbitControls(camera, renderer.domElement);
      controls.target.copy(target);
      controls.enableDamping = true;
      controls.dampingFactor = 0.12;
      controls.minDistance = 60;
      controls.maxDistance = 800;
      controls.mouseButtons = {
        LEFT: THREE.MOUSE.ROTATE,
        MIDDLE: THREE.MOUSE.DOLLY,
        RIGHT: THREE.MOUSE.PAN,
      };
      const metal = new THREE.MeshStandardMaterial({
        color: 0xa7b5c5,
        metalness: 0.5,
        roughness: 0.36,
      });
      const polymer = new THREE.MeshStandardMaterial({
        color: 0x3f658b,
        metalness: 0.22,
        roughness: 0.37,
      });
      const parts = [new THREE.Group(), new THREE.Group()];
      parts.forEach((p, i) => {
        p.userData.part = i;
        scene.add(p);
      });
      function mesh(
        shape: THREE.Shape,
        depth: number,
        material: THREE.MeshStandardMaterial,
        group: THREE.Group,
      ) {
        const g = new THREE.ExtrudeGeometry(shape, {
          depth,
          bevelEnabled: true,
          bevelSegments: 3,
          steps: 1,
          bevelSize: 0.65,
          bevelThickness: 0.65,
          curveSegments: 48,
        });
        const m = new THREE.Mesh(g, material);
        const edges = new THREE.LineSegments(
          new THREE.EdgesGeometry(g, 35),
          new THREE.LineBasicMaterial({
            color: 0x46566a,
            transparent: true,
            opacity: 0.75,
          }),
        );
        m.add(edges);
        group.add(m);
        return m;
      }
      const base = plateShape(120, 76, 8);
      for (const x of [-45, 45])
        for (const y of [-25, 25]) hole(base, x, y, 5.5);
      const baseMesh = mesh(base, 8, metal, parts[0]);
      const upright = plateShape(82, 78, 15);
      hole(upright, 0, 9, 21);
      const wall = mesh(upright, 10, metal, parts[0]);
      wall.rotation.x = Math.PI / 2;
      wall.position.set(0, 25, 47);
      const bearing = new THREE.Shape();
      bearing.absarc(0, 0, 20.4, 0, Math.PI * 2, false);
      hole(bearing, 0, 0, 13.5);
      const insert = mesh(bearing, 15, polymer, parts[1]);
      insert.rotation.x = Math.PI / 2;
      insert.position.set(0, 27, 56);
      const rim = new THREE.Shape();
      rim.absarc(0, 0, 24, 0, Math.PI * 2, false);
      hole(rim, 0, 0, 13.5);
      const flange = mesh(rim, 3, polymer, parts[1]);
      flange.rotation.x = Math.PI / 2;
      flange.position.set(0, 14, 56);
      const refs = new THREE.Group();
      scene.add(refs);
      const planeMeshes: THREE.Group[] = [];
      ['Top', 'Front', 'Right'].forEach((name, i) => {
        const g = new THREE.Group();
        const pg = new THREE.PlaneGeometry(158, 130);
        const pm = new THREE.Mesh(
          pg,
          new THREE.MeshBasicMaterial({
            color: i === 0 ? 0xb79963 : i === 1 ? 0x7a9ebd : 0xa594b3,
            transparent: true,
            opacity: 0.065,
            side: THREE.DoubleSide,
            depthWrite: false,
          }),
        );
        g.add(
          pm,
          new THREE.LineSegments(
            new THREE.EdgesGeometry(pg),
            new THREE.LineBasicMaterial({
              color: i === 0 ? 0xc9ac75 : i === 1 ? 0x96b4ca : 0xb2a6bb,
              transparent: true,
              opacity: 0.4,
            }),
          ),
        );
        if (i === 1) g.rotation.x = Math.PI / 2;
        if (i === 2) g.rotation.y = Math.PI / 2;
        refs.add(g);
        planeMeshes.push(g);
        const c = document.createElement('canvas');
        c.width = 256;
        c.height = 64;
        const cx = c.getContext('2d')!;
        cx.font = '24px Arial';
        cx.fillStyle = '#8290a0';
        cx.fillText(name, 8, 40);
        const tex = new THREE.CanvasTexture(c);
        const label = new THREE.Sprite(
          new THREE.SpriteMaterial({
            map: tex,
            transparent: true,
            depthTest: false,
          }),
        );
        label.scale.set(25, 6.25, 1);
        label.position.set(-65, 58, 0);
        g.add(label);
      });
      const axes = new THREE.AxesHelper(27);
      axes.position.set(-76, -51, 0.2);
      scene.add(axes);
      const clip = new THREE.Plane(new THREE.Vector3(1, 0, 0), 0);
      const cubeScene = new THREE.Scene();
      const cubeCamera = new THREE.PerspectiveCamera(30, 1, 0.1, 50);
      cubeCamera.up.set(0, 0, 1);
      cubeRenderer.setSize(116, 116);
      cubeRenderer.setPixelRatio(Math.min(devicePixelRatio, 2));
      cubeEl.appendChild(cubeRenderer.domElement);
      const names: ViewName[] = [
        'Right',
        'Left',
        'Back',
        'Front',
        'Top',
        'Bottom',
      ];
      const textures = names.map((name) => {
        const c = document.createElement('canvas');
        c.width = c.height = 256;
        const x = c.getContext('2d')!;
        x.fillStyle = '#f7f9fc';
        x.fillRect(0, 0, 256, 256);
        x.strokeStyle = '#9faebf';
        x.lineWidth = 4;
        x.strokeRect(2, 2, 252, 252);
        x.fillStyle = '#56677b';
        x.font = '500 36px Arial';
        x.textAlign = 'center';
        x.textBaseline = 'middle';
        x.fillText(name.toUpperCase(), 128, 128);
        return new THREE.CanvasTexture(c);
      });
      const cube = new THREE.Mesh(
        new THREE.BoxGeometry(1.7, 1.7, 1.7),
        textures.map((t) => new THREE.MeshBasicMaterial({ map: t })),
      );
      cubeScene.add(cube);
      const cubeAxes = new THREE.AxesHelper(1.6);
      cubeAxes.position.set(-1, -1, -1);
      cubeScene.add(cubeAxes);
      let goal: THREE.Vector3 | null = null;
      let targetGoal: THREE.Vector3 | null = null;
      const vectors: Record<ViewName, number[]> = {
        Isometric: [170, -240, 160],
        Top: [0, -0.001, 310],
        Bottom: [0, -0.001, -310],
        Front: [0, -310, 0],
        Back: [0, 310, 0],
        Right: [310, 0, 0],
        Left: [-310, 0, 0],
      };
      const snap = (name: ViewName) => {
        const v = vectors[name];
        goal = new THREE.Vector3(...(v as [number, number, number])).add(
          target,
        );
        targetGoal = target.clone();
        camera.up.set(0, 0, 1);
        setView(name);
      };
      const fit = () => {
        targetGoal = target.clone();
        goal = camera.position
          .clone()
          .sub(controls.target)
          .normalize()
          .multiplyScalar(320)
          .add(target);
        ortho.zoom = 1;
        ortho.updateProjectionMatrix();
      };
      const resize = () => {
        const w = el.clientWidth,
          h = el.clientHeight;
        if (!w || !h) return;
        renderer.setSize(w, h);
        const a = w / h;
        ortho.left = -107 * a;
        ortho.right = 107 * a;
        ortho.top = 107;
        ortho.bottom = -107;
        ortho.updateProjectionMatrix();
        perspective.aspect = a;
        perspective.updateProjectionMatrix();
      };
      const ro = new ResizeObserver(resize);
      ro.observe(el);
      resize();
      const update = (p: ViewportProps) => {
        planeMeshes.forEach((g, i) => {
          g.visible = p.planes[i] || (i === 0 && p.sketch);
          (
            g.children[0] as THREE.Mesh<
              THREE.PlaneGeometry,
              THREE.MeshBasicMaterial
            >
          ).material.opacity = p.sketch && i === 0 ? 0.18 : 0.065;
        });
        parts.forEach((g, i) => (g.visible = !p.hidden?.[i]));
        metal.color.set(p.color || '#a7b5c5');
        metal.emissive.set(p.selectedPart === 0 ? '#172e46' : '#000000');
        polymer.emissive.set(p.selectedPart === 1 ? '#172e46' : '#000000');
        for (const m of [metal, polymer]) {
          m.wireframe = p.display === 'Wireframe';
          m.clippingPlanes = p.section ? [clip] : [];
          m.opacity = p.opacity ?? 1;
          m.transparent = m.opacity < 1;
        }
        parts.forEach((g) =>
          g.traverse((o) => {
            if (o instanceof THREE.LineSegments) {
              o.visible = p.display !== 'Shaded';
              (o.material as THREE.LineBasicMaterial).depthTest =
                p.display !== 'Hidden edges visible';
            }
          }),
        );
        wall.scale.z = (p.depthMm ?? 25) / 25;
        baseMesh.scale.x = (p.widthMm ?? 120) / 120;
      };
      runtime.current = {
        snap,
        fit,
        update,
        projection: (name) => {
          const old = camera;
          camera = name === 'Perspective' ? perspective : ortho;
          camera.position.copy(old.position);
          camera.quaternion.copy(old.quaternion);
          camera.up.copy(old.up);
          const t = controls.target.clone();
          controls.dispose();
          controls = new OrbitControls(camera, renderer.domElement);
          controls.target.copy(t);
          controls.enableDamping = true;
          resize();
          if (name === 'Isometric') snap('Isometric');
        },
      };
      update(latest.current);
      const raycaster = new THREE.Raycaster();
      let down = [0, 0];
      const onDown = (e: PointerEvent) => {
        down = [e.clientX, e.clientY];
        goal = null;
        targetGoal = null;
      };
      const onUp = (e: PointerEvent) => {
        if (
          e.button !== 0 ||
          Math.hypot(e.clientX - down[0], e.clientY - down[1]) > 4
        )
          return;
        const r = el.getBoundingClientRect();
        raycaster.setFromCamera(
          new THREE.Vector2(
            ((e.clientX - r.left) / r.width) * 2 - 1,
            (-(e.clientY - r.top) / r.height) * 2 + 1,
          ),
          camera,
        );
        const hit = raycaster
          .intersectObjects(
            parts.filter((p) => p.visible),
            true,
          )
          .find((x) => x.object instanceof THREE.Mesh);
        if (hit) {
          let obj = hit.object;
          while (obj.parent && obj.userData.part === undefined)
            obj = obj.parent;
          latest.current.onSelect?.(obj.userData.part);
        }
      };
      const cubeClick = (e: MouseEvent) => {
        const r = cubeEl.getBoundingClientRect();
        raycaster.setFromCamera(
          new THREE.Vector2(
            ((e.clientX - r.left) / r.width) * 2 - 1,
            (-(e.clientY - r.top) / r.height) * 2 + 1,
          ),
          cubeCamera,
        );
        const hit = raycaster.intersectObject(cube)[0];
        if (hit?.face) {
          const nearEdges = [hit.point.x, hit.point.y, hit.point.z].filter(
            (n) => Math.abs(n) > 0.65,
          ).length;
          if (nearEdges > 1) {
            goal = new THREE.Vector3(
              Math.sign(hit.point.x) || 1,
              Math.sign(hit.point.y) || -1,
              Math.sign(hit.point.z) || 1,
            )
              .normalize()
              .multiplyScalar(320)
              .add(target);
            targetGoal = target.clone();
            setView('Isometric');
          } else snap(names[hit.face.materialIndex]);
        }
      };
      renderer.domElement.addEventListener('pointerdown', onDown);
      renderer.domElement.addEventListener('pointerup', onUp);
      cubeEl.addEventListener('click', cubeClick);
      let frame = 0;
      const draw = () => {
        frame = requestAnimationFrame(draw);
        if (goal) {
          camera.position.lerp(goal, 0.16);
          if (camera.position.distanceTo(goal) < 0.02) goal = null;
        }
        if (targetGoal) {
          controls.target.lerp(targetGoal, 0.16);
          if (controls.target.distanceTo(targetGoal) < 0.02) targetGoal = null;
        }
        controls.update();
        renderer.render(scene, camera);
        cubeCamera.position
          .copy(camera.position)
          .sub(controls.target)
          .normalize()
          .multiplyScalar(6.7);
        cubeCamera.up.copy(camera.up);
        cubeCamera.lookAt(0, 0, 0);
        cubeRenderer.render(cubeScene, cubeCamera);
      };
      draw();
      latest.current.onReady?.();
      return () => {
        cancelAnimationFrame(frame);
        ro.disconnect();
        controls.dispose();
        runtime.current = null;
        renderer.domElement.removeEventListener('pointerdown', onDown);
        renderer.domElement.removeEventListener('pointerup', onUp);
        cubeEl.removeEventListener('click', cubeClick);
        [scene, cubeScene].forEach((s) =>
          s.traverse((o) => {
            if (o instanceof THREE.Mesh || o instanceof THREE.LineSegments) {
              o.geometry.dispose();
              const mats = Array.isArray(o.material)
                ? o.material
                : [o.material];
              mats.forEach((m: THREE.Material) => {
                if ('map' in m) (m as THREE.MeshBasicMaterial).map?.dispose();
                m.dispose();
              });
            } else if (o instanceof THREE.Sprite) {
              o.material.map?.dispose();
              o.material.dispose();
            }
          }),
        );
        renderer.dispose();
        cubeRenderer.dispose();
        renderer.domElement.remove();
        cubeRenderer.domElement.remove();
      };
    }, [props.navigationHost]);
    useEffect(() => runtime.current?.update(props), [props]);
    return (
      <>
        <div className="three-host" ref={host} />
        {error && (
          <div role="alert" className="viewport-error">
            {error}
          </div>
        )}
        {props.navigationHost &&
          createPortal(
            <div className="view-navigation">
              <button
                className="view-home"
                title="Isometric view"
                onClick={() => {
                  runtime.current?.snap('Isometric');
                  setView('Isometric');
                }}
              >
                <Home size={15} />
              </button>
              <div
                className="view-cube"
                ref={cubeHost}
                aria-label="Interactive orientation cube"
              />
              <select
                aria-label="Standard view"
                value={view}
                onChange={(e) => {
                  runtime.current?.snap(e.target.value as ViewName);
                  setView(e.target.value);
                }}
              >
                {[
                  'Isometric',
                  'Top',
                  'Front',
                  'Right',
                  'Left',
                  'Back',
                  'Bottom',
                ].map((v) => (
                  <option key={v}>{v}</option>
                ))}
              </select>
              <select
                aria-label="Camera projection"
                value={projection}
                onChange={(e) => {
                  setProjection(e.target.value);
                  runtime.current?.projection(e.target.value);
                }}
              >
                {['Orthographic', 'Perspective', 'Isometric'].map((v) => (
                  <option key={v}>{v}</option>
                ))}
              </select>
              <div className="view-actions">
                <button
                  title="Zoom to fit (F)"
                  onClick={() => runtime.current?.fit()}
                >
                  <Maximize size={16} />
                </button>
              </div>
            </div>,
            props.navigationHost,
          )}
      </>
    );
  },
);
