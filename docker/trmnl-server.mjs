// Standalone replacement for the Vercel api/trmnl.js serverless function.
// Same output shape, but talks to the local PostgREST instead of Supabase.
import { createServer } from 'node:http';

const POSTGREST_URL = process.env.POSTGREST_URL || 'http://stars-api:3000';
const ANON_JWT      = process.env.ANON_JWT || '';
const PROFILE_ID    = process.env.TRMNL_PROFILE_ID || '1';
const PORT          = 3001;

async function pgGet(path) {
  const res = await fetch(`${POSTGREST_URL}/${path}`, {
    headers: { 'Authorization': `Bearer ${ANON_JWT}` }
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

async function buildPayload() {
  const [profileRows, stateRows, bRows, rRows] = await Promise.all([
    pgGet(`profiles?id=eq.${PROFILE_ID}&select=*&limit=1`),
    pgGet(`child_state?profile_id=eq.${PROFILE_ID}&select=balance&limit=1`),
    pgGet(`behaviours?profile_id=eq.${PROFILE_ID}&select=*&order=created_at.asc`),
    pgGet(`rewards?profile_id=eq.${PROFILE_ID}&select=*&order=cost.asc`)
  ]);

  const profile    = profileRows?.[0];
  const balance    = stateRows?.[0]?.balance ?? 0;
  const behaviours = bRows || [];
  const rewards    = (rRows || []).filter(r => !(r.one_time && r.claimed));

  if (!profile) throw new Error('Profile not found');

  const next = rewards.find(r => r.cost > balance);

  return {
    name:        profile.name,
    avatar:      profile.avatar?.startsWith('data:') ? '⭐' : (profile.avatar || '⭐'),
    balance,
    next_name:   next ? `${next.emoji} ${next.name}` : '🏆 Everything unlocked!',
    next_gap:    next ? `${next.cost - balance} more ⭐ to go!` : '',
    parent_behaviours: behaviours
      .filter(b => b.type === 'parent' || b.type === 'bonus')
      .slice(0, 6)
      .map(b => `${b.emoji} ${b.description} (+${b.worth}⭐)`)
      .join(' · '),
    self_behaviours: behaviours
      .filter(b => b.type === 'self')
      .slice(0, 5)
      .map(b => `${b.emoji} ${b.description}`)
      .join(' · '),
    rewards_list: rewards
      .slice(0, 6)
      .map(r => {
        const pct = Math.min(100, Math.round((balance / r.cost) * 100));
        return balance >= r.cost
          ? `✓ ${r.name}`
          : `${r.emoji} ${r.name} — ${r.cost - balance} more ⭐ (${pct}%)`;
      })
      .join('\n'),
    updated: new Date().toLocaleString('en-GB', {
      day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
    })
  };
}

createServer(async (req, res) => {
  if (!req.url.startsWith('/api/trmnl')) {
    res.writeHead(404).end('Not found');
    return;
  }
  try {
    const payload = await buildPayload();
    res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify(payload));
  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.message }));
  }
}).listen(PORT, () => console.log(`trmnl server on :${PORT}`));
