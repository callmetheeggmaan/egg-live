export function cleanGifts(input){
  const rows=Array.isArray(input)?input:input?.gifts||[];
  const result=new Map();
  for(const g of rows){
    const id=String(g.id??g.giftId??'');
    if(!/^\d{1,20}$/.test(id))continue;
    const name=String(g.name??g.giftName??id).trim().slice(0,100)||id;
    const raw=g.image?.url_list?.[0]||g.icon?.url_list?.[0]||g.image||g.icon||'';
    let image='';
    try{const u=new URL(raw);if(u.protocol==='https:'&&['tiktokcdn.com','tiktokcdn-eu.com','byteoversea.com','ibytedtos.com'].some(d=>u.hostname===d||u.hostname.endsWith('.'+d)))image=u.href;}catch{}
    const diamonds=Math.max(0,Math.floor(Number(g.diamonds??g.diamond_count??g.diamondCount)||0));
    result.set(id,{id,name,diamonds,image});
  }
  return [...result.values()];
}
export function mergeGifts(...lists){
  const result=new Map();for(const list of lists)for(const g of cleanGifts(list))result.set(g.id,g);
  return [...result.values()].sort((a,b)=>a.diamonds-b.diamonds||a.name.localeCompare(b.name)||a.id.localeCompare(b.id));
}
