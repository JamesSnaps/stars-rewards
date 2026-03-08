const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const PROFILE_ID   = process.env.TRMNL_PROFILE_ID || '1';

async function sbGet(path) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`
    }
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export default async function handler(req, res) {
  try {
    const [profileRows, stateRows, bRows, rRows] = await Promise.all([
      sbGet(`profiles?id=eq.${PROFILE_ID}&select=*&limit=1`),
      sbGet(`child_state?profile_id=eq.${PROFILE_ID}&select=balance&limit=1`),
      sbGet(`behaviours?profile_id=eq.${PROFILE_ID}&select=*&order=created_at.asc`),
      sbGet(`rewards?profile_id=eq.${PROFILE_ID}&select=*&order=cost.asc`)
    ]);

    const profile    = profileRows?.[0];
    const balance    = stateRows?.[0]?.balance ?? 0;
    const behaviours = bRows || [];
    const rewards    = rRows || [];

    if (!profile) throw new Error('Profile not found');

    const next = rewards.find(r => r.cost > balance);

    res.setHeader('Cache-Control', 'no-store');
    res.status(200).json({
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
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}