import {expect,it,vi} from 'vitest';
import * as THREE from 'three';
import {createPlaneVisual} from './plane-visual';
it('attaches text as a plane mesh at the same local upper-left corner through rotation',()=>{
 vi.stubGlobal('document',{createElement:()=>({width:0,height:0,getContext:()=>({fillText:()=>{},font:'',fillStyle:''})})});
 try{
 const plane=createPlaneVisual('Front',0x89aaff,[0,0,0]);
 const label=plane.children[2];expect(label).toBeInstanceOf(THREE.Mesh);expect(label).not.toBeInstanceOf(THREE.Sprite);
 const local=label.position.clone();plane.rotation.z=Math.PI;plane.updateMatrixWorld(true);
 expect(label.position.toArray()).toEqual(local.toArray());
 const world=label.getWorldPosition(new THREE.Vector3());expect(world.x).toBeCloseTo(-local.x);expect(world.y).toBeCloseTo(-local.y);
 }finally{vi.unstubAllGlobals();}
});
