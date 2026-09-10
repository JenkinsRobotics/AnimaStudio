import * as THREE from "three";
export function createPlaneVisual(name:string,color:number,rotation:readonly [number,number,number]):THREE.Group {
      const geometry = new THREE.PlaneGeometry(180, 180);
      const surface = new THREE.Mesh(
        geometry,
        new THREE.MeshBasicMaterial({
          color,
          transparent: true,
          opacity: 0.055,
          side: THREE.DoubleSide,
          depthWrite: false,
        }),
      );
      const outline = new THREE.LineSegments(
        new THREE.EdgesGeometry(geometry),
        new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.55 }),
      );
      const group = new THREE.Group();
      group.name = name;
      group.rotation.set(...rotation);
      group.add(surface, outline);
      const labelCanvas=document.createElement("canvas");labelCanvas.width=256;labelCanvas.height=64;
      const context=labelCanvas.getContext("2d");
      if(context){context.font="500 28px system-ui";context.fillStyle="#a9cfff";context.fillText(name.replace(" Plane",""),8,40);
        const label=new THREE.Mesh(new THREE.PlaneGeometry(40,10),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(labelCanvas),side:THREE.DoubleSide,depthWrite:false,transparent:true}));
        label.position.set(-68,83,0.05);label.raycast=()=>{};group.add(label);
      }
return group;
}
