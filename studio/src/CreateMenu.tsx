import {useEffect,useRef,useState} from 'react';
import {AetherIcon,Button} from '@aether/ui';
export type CreateChoice='project'|'folder'|'part'|'assembly'|'import';
const choices=[['project','Project document','document'],['folder','Folder','folder'],['part','Part','design'],['assembly','Assembly','assembly'],['import','Import file…','import']] as const;
export function CreateMenu({onChoose,disabled}:{onChoose:(choice:CreateChoice)=>void;disabled:boolean}){
 const [open,setOpen]=useState(false);const root=useRef<HTMLDivElement>(null);
 const focusItem=(index:number)=>{const items=root.current?.querySelectorAll<HTMLButtonElement>('[role=menuitem]');if(items?.length)items[(index+items.length)%items.length].focus();};
 useEffect(()=>{if(!open)return;focusItem(0);const outside=(e:PointerEvent)=>{if(!root.current?.contains(e.target as Node))setOpen(false);};document.addEventListener('pointerdown',outside);return()=>document.removeEventListener('pointerdown',outside);},[open]);
 return <div ref={root} className="library-create" onKeyDown={e=>{
  if(e.key==='Escape'){setOpen(false);root.current?.querySelector<HTMLButtonElement>('[aria-haspopup]')?.focus();e.preventDefault();}
  if(['ArrowDown','ArrowUp','Home','End'].includes(e.key)){e.preventDefault();if(!open){setOpen(true);return;}const items=Array.from(root.current?.querySelectorAll('[role=menuitem]')??[]);const current=items.indexOf(document.activeElement!);focusItem(e.key==='Home'?0:e.key==='End'?items.length-1:current+(e.key==='ArrowDown'?1:-1));}
 }}><Button primary aria-haspopup="menu" aria-expanded={open} aria-controls="cad-create-menu" disabled={disabled} onClick={()=>setOpen(!open)}>Create <span aria-hidden="true">▾</span></Button>
 {open&&<div id="cad-create-menu" role="menu" aria-label="Create" className="library-create-menu">{choices.map(([id,label,icon])=><button type="button" role="menuitem" key={id} onClick={()=>{setOpen(false);onChoose(id);}}><AetherIcon name={icon}/>{label}</button>)}</div>}</div>;
}
