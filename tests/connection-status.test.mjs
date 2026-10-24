import test from 'node:test';
import assert from 'node:assert/strict';
import {isGiftCatalogueError,connectionNotice} from '../companion/public/connection-status.js';

test('optional gift catalogue failures remain distinct from real connection failures',()=>{
 assert.equal(isGiftCatalogueError({info:'Failed to fetch room gifts.'}),true);
 assert.equal(isGiftCatalogueError(new Error('Websocket disconnected')),false);
 const notice=connectionNotice({state:'connected',error:'Failed to fetch room gifts.'},728);
 assert.equal(notice.warning,true);
 assert.match(notice.text,/728 preloaded gifts/);
 const failure=connectionNotice({state:'error',error:'Websocket disconnected'},728);
 assert.equal(failure.warning,false);
 assert.equal(failure.text,'Websocket disconnected');
 assert.equal(connectionNotice({state:'connected',error:'Other failure'},728).text,'Other failure');
});
