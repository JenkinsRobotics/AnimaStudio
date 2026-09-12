import * as THREE from "three";
export interface PlaneVisualStyle {
  fillOpacity?: number;
  borderOpacity?: number;
  labelColor?: string;
}
export function createPlaneVisual(name:string,color:number,rotation:readonly [number,number,number],style:PlaneVisualStyle={}):THREE.Group {
      // Reference planes read as compact datums, not a backdrop.
      const geometry = new THREE.PlaneGeometry(110, 110);
      const surface = new THREE.Mesh(
        geometry,
        new THREE.MeshBasicMaterial({
          color,
          transparent: true,
          opacity: style.fillOpacity ?? 0.055,
          side: THREE.DoubleSide,
          depthWrite: false,
        }),
      );
      const outline = new THREE.LineSegments(
        new THREE.EdgesGeometry(geometry),
        new THREE.LineBasicMaterial({ color, transparent: true, opacity: style.borderOpacity ?? 0.55 }),
      );
      const group = new THREE.Group();
      group.name = name;
      group.rotation.set(...rotation);
      group.add(surface, outline);
      const labelCanvas=document.createElement("canvas");labelCanvas.width=256;labelCanvas.height=64;
      const context=labelCanvas.getContext("2d");
      if(context){context.font="500 28px system-ui";context.fillStyle=style.labelColor ?? "#a9cfff";context.fillText(name.replace(" Plane",""),8,40);
        const label=new THREE.Mesh(new THREE.PlaneGeometry(26,6.5),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(labelCanvas),side:THREE.DoubleSide,depthWrite:false,transparent:true}));
        label.position.set(-41,50,0.05);label.raycast=()=>{};group.add(label);
      }
return group;
}
