const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('Rabbit Hole/game.html','utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(source);
class Element{constructor(){this.children=[];this.hidden=false;this.disabled=false;this.value='';this.style={};this.className='';this.textContent='';this.classList={add:(s)=>{this.className+=' '+s},toggle:()=>{}};}append(...a){this.children.push(...a)}replaceChildren(...a){this.children=a}setAttribute(){}focus(){}}
const els=new Map();const get=id=>{if(!els.has(id))els.set(id,new Element());return els.get(id)};get('pace').value='0';
let responseCode=0,interval;
// Synthetic fixtures exercise mechanics only, and contain no trivia dataset.
const fixture=()=>({response_code:responseCode,results:Array.from({length:10},()=>({question:'Test%20prompt',category:'Test',difficulty:'easy',correct_answer:'A',incorrect_answers:['B','C','D']}))});
const ctx=vm.createContext({document:{getElementById:get,createElement:()=>new Element(),createTextNode:t=>t,addEventListener:()=>{}},window:{addEventListener:()=>{}},URLSearchParams,AbortController,console,fetch:async()=>({ok:true,status:200,json:async()=>fixture()}),setTimeout:()=>1,clearTimeout:()=>{},setInterval:f=>{interval=f;return 1},clearInterval:()=>{}});
vm.runInContext(source,ctx);const run=s=>vm.runInContext(s,ctx);
(async()=>{await run('start()');assert.equal(run('screen'),'game');assert.equal(get('question').textContent,'Test prompt');get('lifeline').onclick();assert.equal(get('answers').children.filter(b=>b.disabled).length,2);run('answer(questions[index].answers.findIndex(a=>a.correct))');assert.equal(run('score'),100);run('answer(0)');assert.equal(run('score'),100);
for(let i=1;i<10;i++){run('next()');run('answer(questions[index].answers.findIndex(a=>a.correct))');}run('next()');assert.equal(run('screen'),'result');assert.equal(run('score'),1875);assert.equal(run('questions.length'),0);assert.equal(get('accuracy').textContent,'10 / 10');
run('lastFetch=0');await run('start()');run('answer(questions[index].answers.findIndex(a=>!a.correct))');assert.equal(run('score'),0);assert.ok(get('feedback').className.includes('bad'));run('home()');assert.equal(run('questions.length'),0);
get('pace').value='20';run('lastFetch=0');await run('start()');run('deadline=0');interval();assert.equal(run('answered'),true);assert.equal(run('score'),0);
responseCode=1;run('lastFetch=0');await run('start()');assert.equal(run('screen'),'error');assert.match(get('errormessage').textContent,/enough questions/);
ctx.fetch=async()=>{throw new TypeError('offline')};run('lastFetch=0');await run('start()');assert.equal(run('screen'),'error');
assert.ok(!/localStorage|sessionStorage|indexedDB|serviceWorker/.test(source));console.log('PASS: syntax, API parsing, 50/50, scoring, duplicate-answer guard, complete round, memory clearing, wrong answer, timer expiry, and API failures.');})();

