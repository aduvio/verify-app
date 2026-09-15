// Isolated headless Chrome fixture. Never grants access to physical devices.
const {spawn} = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const physical = process.env.VERIFY_PHYSICAL === 'authorized';
if (physical) {
  throw new Error('Automated physical-device testing is disabled. Use the visible app: identify devices, prepare the scene, approve the browser permission yourself, review preview/device names, then explicitly start capture.');
}
const profile = path.resolve(__dirname, physical ? '../build/physical-camera-test-profile' : '../build/media-fixture-profile');
const chromePath = process.env.CHROME_EXECUTABLE || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const chrome = spawn(chromePath, ['--headless=new','--remote-debugging-pipe',`--user-data-dir=${profile}`,
  '--no-first-run','--no-default-browser-check','--autoplay-policy=no-user-gesture-required','about:blank'],
  {windowsHide:true, stdio:['ignore','ignore','ignore','pipe','pipe']});
let seq=0, buffer=''; const pending=new Map();
chrome.stdio[4].on('data', data=>{ buffer+=data.toString(); let end; while((end=buffer.indexOf('\0'))>=0) {
  const value=JSON.parse(buffer.slice(0,end));buffer=buffer.slice(end+1);
  if(value.id && pending.has(value.id)){const {resolve,reject,timer}=pending.get(value.id);clearTimeout(timer);pending.delete(value.id);value.error?reject(value.error):resolve(value.result);}
}});
function cdp(method,params={},sessionId){return new Promise((resolve,reject)=>{const id=++seq;const timer=setTimeout(()=>{pending.delete(id);reject(Error('CDP timeout: '+method));},20000);pending.set(id,{resolve,reject,timer});chrome.stdio[3].write(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})})+'\0');});}
(async()=>{
  const {targetId}=await cdp('Target.createTarget',{url:'about:blank'});
  const {sessionId}=await cdp('Target.attachToTarget',{targetId,flatten:true});
  await cdp('Page.enable',{},sessionId);
  await cdp('Page.navigate',{url:'http://127.0.0.1:8765/'+(physical?'physical_media_check.html':'browser_media_fixture.html')},sessionId);
  let result;
  const deadline=Date.now()+90000;
  while(Date.now()<deadline){await new Promise(r=>setTimeout(r,1000));const v=await cdp('Runtime.evaluate',{expression:'window.fixtureResult',returnByValue:true},sessionId);result=v.result?.value;if(result?.passed!==undefined)break;}
  if(!result?.passed)throw Error(JSON.stringify(result||'Fixture did not complete'));
  let adapter;
  if(!physical){
    const value=await cdp('Runtime.evaluate',{expression:'window.adapterFixtureResult',returnByValue:true},sessionId);
    adapter=value.result?.value;
    if(!adapter?.passed)throw Error('Dart IndexedDB adapter: '+JSON.stringify(adapter));
    console.log('Dart IndexedDB adapter: '+JSON.stringify(adapter));
  }
  // Reload to a non-capturing reader: exercise fresh document playback of stored bytes.
  await cdp('Page.navigate',{url:'http://127.0.0.1:8765/'},sessionId);
  await new Promise(r=>setTimeout(r,1500));
  const retained=await cdp('Runtime.evaluate',{expression:`(async()=>{const db=await new Promise((res,rej)=>{const r=indexedDB.open('${physical?'verify_authorized_physical_test':'verify_synthetic_fixture'}',1);r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error);});const tx=db.transaction('bytes');const r=tx.objectStore('bytes').get('clip');const clip=await new Promise((res,rej)=>{r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error);});const duration=await verifyMedia.validate(new Blob([clip.bytes],{type:clip.mimeType}),false);db.close();return {bytes:clip.bytes.length,durationMs:duration};})()`,awaitPromise:true,returnByValue:true},sessionId);
  if(retained.exceptionDetails)throw Error(JSON.stringify(retained.exceptionDetails));
  if(retained.result.value.bytes!==result.videoBytes)throw Error('Reload lost media bytes');
  console.log(JSON.stringify({fixture:result,reloaded:retained.result.value,physicalCamera:physical}));
  fs.writeFileSync(path.resolve(__dirname,physical?'../build/physical-browser-result.json':'../build/media-browser-result.json'),JSON.stringify({fixture:result,adapter,reloaded:retained.result.value,physicalCamera:physical},null,2));
  await cdp('Browser.close');
})().catch(error=>{console.error(error);process.exitCode=1;chrome.kill();});
