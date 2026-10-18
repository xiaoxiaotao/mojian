import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html=fs.readFileSync(new URL('../web/local.html',import.meta.url),'utf8');
const script=html.split('<script>')[1].split('function list()')[0];
let pixels=new Uint8ClampedArray(800*480*4).fill(255),clip=[0,0,800,480],stack=[];
const context={fillStyle:'white',font:'18px sans-serif',save(){stack.push([...clip])},restore(){clip=stack.pop()},beginPath(){},rect(x,y,w,h){clip=[x,y,w,h]},clip(){},createImageData(){return {data:new Uint8ClampedArray(800*480*4)}},putImageData(i){pixels.set(i.data)},getImageData(){return {data:pixels}},measureText(s){return {width:s.length*9}},fillRect(x,y,w,h){for(let yy=Math.max(0,y,clip[1]);yy<Math.min(480,y+h,clip[1]+clip[3]);yy++)for(let xx=Math.max(0,x,clip[0]);xx<Math.min(800,x+w,clip[0]+clip[2]);xx++){let i=(yy*800+xx)*4;pixels[i]=pixels[i+1]=pixels[i+2]=this.fillStyle==='white'?255:0;pixels[i+3]=255}},fillText(s,x,y){if(s)this.fillRect(x,y,3,3)},strokeRect(x,y,w,h){let saved=this.fillStyle;this.fillStyle='black';this.fillRect(x,y,w,1);this.fillRect(x,y,1,h);this.fillStyle=saved}};
const canvas={getContext(){return context},toDataURL(){return 'data:image/png;base64,'}};
const scope=vm.createContext({document:{getElementById(){return {}},createElement(){return canvas}},Uint8Array,Date,Error,Math,Number,console});vm.runInContext(script,scope);
for(const kind of ['focus','agenda','overview','minimal','pomodoro','living','custom']){
 const id='mac.'+kind+'.red-v2'+(kind==='custom'?'.67.weather-stocks-note':'')+'.phone';
 scope.id=id;vm.runInContext("state={layout_id:id};base=new Uint8Array(48000).fill(255);base[20*100+90]=0;base[450*100+95]=0",scope);
 const before=vm.runInContext("render([{title:'test',due:null}])",scope);
 scope.nextBase=before;vm.runInContext('base=nextBase',scope);
 const after=vm.runInContext('render([])',scope),a=vm.runInContext('taskArea(id)',scope);
 assert.equal(after[160*100+6],255,kind+' removed first-row text');
 for(let i=0;i<48000;i++){const x=(i%100)*8,y=Math.floor(i/100);const allowed=x>=a.x&&x<a.x+a.w&&y>=a.y&&y<a.y+a.h||kind==='pomodoro'&&x>=504&&x<776&&y>=348&&y<402;if(!allowed)assert.equal(after[i],before[i],kind+' preserves other modules at byte '+i)}
 assert(after.slice(8000,10400).every(v=>v===255),kind+' fixed red reserve');
}
assert.throws(()=>vm.runInContext("taskArea('phone-todo-v1')",scope));
console.log('PASS: seven layout task removal, weather/stocks preservation, fixed red band and unsupported layout rejection');
