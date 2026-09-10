import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';
import assert from 'node:assert/strict';
const base=process.env.JRC_TEST_URL || 'http://localhost:3000';
const env=await readFile(new URL('../local/nico.env',import.meta.url),'utf8');
const password=env.match(/^NICO_LOCAL_PASSWORD=(.+)$/m)[1].trim();
const headers={'Content-Type':'application/json'};
async function request(method,path,input,status=200){
 const response=await fetch(base+path,{method,headers,body:input?JSON.stringify(input):undefined,signal:AbortSignal.timeout(60000)});
 for(const key of ['access-token','client','uid','token-type'])if(response.headers.get(key))headers[key]=response.headers.get(key);
 assert.equal(response.status,status,`${method} ${path}: HTTP ${response.status}`);return response.json();
}
try{
 await request('POST','/auth/sign_in',{email:'admin@gopure.test',password});
 const reports=[];
 const before=await request('GET','/api/v1/accounts/1/conversations/1/messages');
 const path='/api/v1/accounts/1/jrc_nico/runs';
 for(const agentKey of ['nico','comercial','cx','suporte_n1','financeiro','implantacao','supervisor']) {
 const input={agent_key:agentKey,request_id:randomUUID(),conversation_id:1,message:'Analise o pedido de implantação e suporte do cliente. Considere também o lead do CRM fornecido, cite as referências utilizadas e sugira uma resposta curta com perguntas para qualificação. Não invente preços, prazos nem ações já executadas.'};
 let run=await request('POST',path,input,202);
 const until=Date.now()+120000;
 while(['queued','running'].includes(run.status)&&Date.now()<until){await delay(1000);run=await request('GET',`${path}/${run.id}`);}
 assert.equal(run.status,'completed',`NICO ${run.status}: ${run.error_code}`);
 assert.equal(run.result.mode,'provider');assert.ok(run.result.usage.total_tokens>0);assert.ok(run.result.summary);assert.ok(run.result.suggested_reply);
 const after=await request('GET','/api/v1/accounts/1/conversations/1/messages');
 assert.deepEqual(before.payload.map(x=>x.id),after.payload.map(x=>x.id));
 const report={agent_key:run.agent_key,passed:true,at:new Date().toISOString(),account_id:1,run_id:run.id,mode:run.result.mode,model:run.result.model,usage:run.result.usage,summary:run.result.summary,suggested_reply:run.result.suggested_reply,evidence:run.result.evidence,public_messages_unchanged:true};
 assert.equal(run.agent_key,agentKey);reports.push(report);console.log(agentKey+': integração concluída');
 }
 await writeFile(new URL('../docs/validation/gopure-full-e2e-destination.json',import.meta.url),JSON.stringify({passed:true,reports},null,2));
}catch(e){console.error(JSON.stringify({passed:false,error:e.message}));process.exitCode=1;}
finally{if(headers['access-token'])await fetch(base+'/auth/sign_out',{method:'DELETE',headers,signal:AbortSignal.timeout(15000)}).catch(()=>{});}


