// The optional catalogue request can fail while the gift websocket stays connected.
export function isGiftCatalogueError(error) {
  const message = String(error?.message || error?.info || error || '').trim();
  return message === 'Failed to fetch room gifts.';
}

export function connectionNotice(tiktok, giftCount) {
  if (tiktok.state === 'connected' && isGiftCatalogueError(tiktok.error)) {
    return { warning: true, text: `LIVE connected. Room gift-list refresh unavailable; using ${giftCount} preloaded gifts. Gift events can still arrive.` };
  }
  return { warning: false, text: tiktok.error || '' };
}
