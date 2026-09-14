import { readFile,mkdir,writeFile,stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve,join } from 'node:path';
import { parseArgs } from 'node:util';
import { createHash } from 'node:crypto';
import { validateConfig,recipients,prepareMessage,submitMessage } from '../cli/src/client.js';
const root=fileURLToPath(new URL('../',import.meta.url));
const {values}=parseArgs({options:{locale:{type:'string',default:'zh-Hans'},config:{type:'string'},device:{type:'string'},send:{type:'boolean',default:false},check:{type:'boolean',default:false}}});
if(!['zh-Hans','en'].includes(values.locale))throw new Error('Use --locale zh-Hans or en');
const content=JSON.parse(await readFile(new URL('./review-screenshot-messages.json',import.meta.url),'utf8'));
const messages=content.messages.map(item=>({id:item.id,evidence:item.evidence,payload:item[values.locale]}));
// Default is a local content preview. Sending requires an explicit --send invocation.
if(!values.send&&!values.check){console.log(JSON.stringify({mode:'preview',locale:values.locale,messages},null,2));process.exit(0);}
const path=resolve(root,values.config??'.secrets/real-device-sender.json');
if((await stat(path)).mode&0o077)throw new Error('Credential file must have mode 0600');
const config=validateConfig(JSON.parse(await readFile(path,'utf8')));
if(config.api_url!=='https://api.pushnow.dev')throw new Error('This content is for the current production inbox');
const devices=await recipients(config);
const selected=values.device?devices.filter(d=>d.id===values.device):devices.filter(d=>d.notifications_enabled);
if(selected.length!==1)throw new Error('Select exactly one active authorized device with --device');
if(!values.send){console.log(JSON.stringify({mode:'check',user_id:config.user_id,device_id:selected[0].id,active:true,notifications_enabled:selected[0].notifications_enabled,private_keys_printed:false}));process.exit(0);}
const outboxDir=join(root,'.secrets','review-screenshot-outbox');await mkdir(outboxDir,{recursive:true,mode:0o700});
for(const item of messages){
 const file=join(outboxDir,`${content.batch}-${values.locale}-${item.id}.json`);
 const contentHash=createHash('sha256').update(JSON.stringify(item.payload)).digest('hex');
 let saved;
 try{saved=JSON.parse(await readFile(file,'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
 if(saved&&(saved.content_hash!==contentHash||saved.user_id!==config.user_id||saved.device_id!==selected[0].id))throw new Error('Saved outbox context changed; review before resending');
 if(saved?.accepted){console.log(JSON.stringify({id:item.id,status:'previously_accepted',message_id:saved.envelope.message_id,delivery_confirmed:false}));continue;}
 if(!saved){saved={user_id:config.user_id,device_id:selected[0].id,content_hash:contentHash,envelope:await prepareMessage(config,devices,item.payload,{deviceIds:[selected[0].id]}),accepted:false};await writeFile(file,JSON.stringify(saved),{mode:0o600,flag:'wx'});}
 await submitMessage(config,saved.envelope);
 saved.accepted=true;await writeFile(file,JSON.stringify(saved),{mode:0o600});
 console.log(JSON.stringify({id:item.id,status:'accepted',message_id:saved.envelope.message_id,delivery_confirmed:false}));
}
