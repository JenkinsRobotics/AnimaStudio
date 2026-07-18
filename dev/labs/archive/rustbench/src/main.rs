// Pipeline 2 bench: Rust B-rep kernel (truck) parses + tessellates a STEP
// file; the mesh is embedded into a self-contained Three.js viewer page.
//   rustbench <file.step> [out.html]
use std::time::Instant;

use truck_meshalgo::tessellation::*;
use truck_stepio::r#in::*;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: rustbench <file.step> [out.html]");
        std::process::exit(2);
    }
    let path = &args[1];
    let out = args
        .get(2)
        .cloned()
        .unwrap_or_else(|| "/tmp/rustbench.html".to_string());

    let t0 = Instant::now();
    let step_string = std::fs::read_to_string(path).expect("cannot read file");
    let table = match Table::from_step(&step_string) {
        Some(table) => table,
        None => {
            println!("PARSE FAILED: truck could not parse this STEP file");
            std::process::exit(1);
        }
    };
    let parse_s = t0.elapsed().as_secs_f64();

    let t1 = Instant::now();
    let mut positions: Vec<[f32; 3]> = Vec::new();
    let mut indices: Vec<u32> = Vec::new();
    let mut shell_count = 0usize;
    for shell in table.shell.values() {
        shell_count += 1;
        let compressed = table.to_compressed_shell(shell);
        let Ok(compressed) = compressed else { continue };
        // 0.05mm-class deflection (STEP files here are in mm).
        let mesh = compressed.triangulation(0.05).to_polygon();
        let offset = positions.len() as u32;
        for p in mesh.positions() {
            positions.push([p.x as f32, p.y as f32, p.z as f32]);
        }
        for face in mesh.tri_faces() {
            for v in face.iter() {
                indices.push(offset + v.pos as u32);
            }
        }
    }
    let mesh_s = t1.elapsed().as_secs_f64();

    if positions.is_empty() {
        println!(
            "PARSE OK ({} shells) but tessellation produced no triangles",
            shell_count
        );
        std::process::exit(1);
    }

    println!(
        "RUST KERNEL OK  parse {:.3}s  tessellate {:.3}s  shells={}  vertices={}  triangles={}",
        parse_s,
        mesh_s,
        shell_count,
        positions.len(),
        indices.len() / 3
    );

    let html = format!(
        r#"<!DOCTYPE html><html><head><meta charset="utf-8"><title>rustbench — {name}</title>
<style>body{{margin:0;background:#111;color:#9fe8e2;font:12px monospace}}#hud{{position:fixed;top:8px;left:8px}}</style></head>
<body><div id="hud">PIPELINE 2: Rust (truck) kernel → Three.js — {name}<br>vertices {nv} · triangles {nt} · parse {ps:.0}ms · tessellate {ms:.0}ms</div>
<script type="importmap">{{"imports":{{"three":"https://cdn.jsdelivr.net/npm/three@0.169.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.169.0/examples/jsm/"}}}}</script>
<script type="module">
import * as THREE from 'three';
import {{ OrbitControls }} from 'three/addons/controls/OrbitControls.js';
const positions = new Float32Array({positions});
const indices = new Uint32Array({indices});
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x14161a);
const geometry = new THREE.BufferGeometry();
geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
geometry.setIndex(new THREE.BufferAttribute(indices, 1));
geometry.computeVertexNormals();
geometry.computeBoundingSphere();
const mesh = new THREE.Mesh(geometry, new THREE.MeshStandardMaterial({{color: 0x57bfb7, metalness: 0.1, roughness: 0.55}}));
scene.add(mesh);
const s = geometry.boundingSphere;
const camera = new THREE.PerspectiveCamera(50, innerWidth/innerHeight, s.radius/100, s.radius*20);
camera.position.set(s.center.x + s.radius*1.6, s.center.y + s.radius*1.2, s.center.z + s.radius*1.9);
scene.add(new THREE.AmbientLight(0xffffff, 0.35));
const key = new THREE.DirectionalLight(0xffffff, 1.4); key.position.set(1, 1.6, 1.2); scene.add(key);
const fill = new THREE.DirectionalLight(0xbfd4ff, 0.5); fill.position.set(-1.4, 0.4, 0.6); scene.add(fill);
const renderer = new THREE.WebGLRenderer({{antialias: true}});
renderer.setSize(innerWidth, innerHeight);
document.body.appendChild(renderer.domElement);
const controls = new OrbitControls(camera, renderer.domElement);
controls.target.copy(s.center);
renderer.setAnimationLoop(() => {{ controls.update(); renderer.render(scene, camera); }});
addEventListener('resize', () => {{ camera.aspect = innerWidth/innerHeight; camera.updateProjectionMatrix(); renderer.setSize(innerWidth, innerHeight); }});
</script></body></html>"#,
        name = path.rsplit('/').next().unwrap_or(path),
        nv = positions.len(),
        nt = indices.len() / 3,
        ps = parse_s * 1000.0,
        ms = mesh_s * 1000.0,
        positions = serde_json::to_string(
            &positions.iter().flatten().collect::<Vec<_>>()
        )
        .unwrap(),
        indices = serde_json::to_string(&indices).unwrap(),
    );
    std::fs::write(&out, html).expect("cannot write viewer html");
    println!("VIEWER WRITTEN: {out}");
}
