import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {cleanGifts,mergeGifts} from '../companion/gifts.mjs';
test('preloaded catalogue contains 728 unique gifts with real selectable IDs',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../companion/assets/gifts.json',import.meta.url),'utf8'));
 const gifts=cleanGifts(data.gifts);
 assert.equal(gifts.length,728);assert.equal(new Set(gifts.map(g=>g.id)).size,728);
 const rose=gifts.find(g=>g.id==='5655');assert.equal(rose.name,'Rose');assert.equal(rose.diamonds,1);assert.match(rose.image,/^https:\/\//);
 assert.ok(gifts.some(g=>g.name==='Galaxy'));assert.ok(gifts.some(g=>g.name==='Lion'));
});
test('room catalogue updates an existing ID and adds every valid new gift without duplicates',()=>{
 const gifts=mergeGifts([{id:'5655',name:'Rose',diamonds:1}],[{id:'5655',name:'Room Rose',diamond_count:2},{id:'9999',name:'New Room Gift',diamond_count:3}]);
 assert.equal(gifts.length,2);assert.equal(gifts[0].name,'Room Rose');assert.equal(gifts[0].diamonds,2);assert.equal(gifts[1].id,'9999');
});
test('catalogue rejects invalid IDs and untrusted icon hosts',()=>{
 const gifts=cleanGifts([{id:'bad;quit',name:'Bad'},{id:1,name:'Good',image:'https://example.com/track'},{id:2,name:'Good 2',image:{url_list:['https://p16-webcast.tiktokcdn.com/test.webp']}}]);
 assert.equal(gifts.length,2);assert.equal(gifts[0].image,'');assert.match(gifts[1].image,/tiktokcdn\.com/);
});
