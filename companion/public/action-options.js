export function groupedActions(actions){
 return [['help','Help the player'],['chaos','Create chaos']].map(([kind,label])=>({
  kind,label,actions:actions.filter(a=>a.kind===kind&&a.id!=='ping').slice().sort((a,b)=>a.label.localeCompare(b.label,'en',{sensitivity:'base',numeric:true}))
 }));
}
