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

    const profile   = profileRows?.[0];
    const balance   = stateRows?.[0]?.balance ?? 0;
    const behaviours = bRows || [];
    const rewards   = rRows || [];

    if (!profile) throw new Error('Profile not found');

    const parentB = behaviours.filter(b => b.type === 'parent' || b.type === 'bonus').slice(0, 6);
    const selfB   = behaviours.filter(b => b.type === 'self').slice(0, 4);
    const next    = rewards.find(r => r.cost > balance);

    // build brick slots
    const bricks = Array.from({ length: 20 }, (_, i) =>
      `<div class="brick ${i < balance ? 'filled' : 'empty'}"></div>`
    ).join('');

    const behaviourRow = b =>
      `<div class="b-row">
        <div class="b-emoji">${b.emoji}</div>
        <div class="b-text">${b.description}</div>
        <div class="b-worth">+${b.worth} ⭐</div>
      </div>`;

    const rewardRow = r => {
      const pct = Math.min(100, Math.round((balance / r.cost) * 100));
      const ready = balance >= r.cost;
      const icon = r.image_url
        ? `<img src="${r.image_url}" class="r-icon-img"/>`
        : `<span class="r-icon">${r.emoji}</span>`;
      return `<div class="r-item">
        <div class="r-top">${icon}<div class="r-name">${r.name}</div><div class="r-cost">${r.cost}⭐</div></div>
        ${ready
          ? `<div class="r-ready">✓ Ready to claim!</div>`
          : `<div class="r-bar-bg"><div class="r-bar-fill" style="width:${pct}%"></div></div>
             <div class="r-pct">${pct}% there</div>`}
      </div>`;
    };

    const now = new Date().toLocaleString('en-GB', {
      day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
    });

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;700;800;900&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:'Nunito',sans-serif;background:#fff;color:#000;width:800px;height:480px;overflow:hidden;padding:18px 20px;}
.grid{display:grid;grid-template-columns:210px 1fr 195px;grid-template-rows:56px 1fr;gap:0 18px;height:100%;}
.header{grid-column:1/-1;display:flex;align-items:flex-end;justify-content:space-between;border-bottom:3px solid #000;padding-bottom:10px;margin-bottom:14px;}
.header-left{display:flex;align-items:center;gap:12px;}
.header-avatar{font-size:1.8rem;line-height:1;}
.header-name{font-size:1.4rem;font-weight:900;letter-spacing:.5px;}
.header-sub{font-size:.72rem;color:#555;font-weight:700;margin-top:1px;}
.header-time{font-size:.68rem;color:#777;font-weight:700;text-align:right;line-height:1.5;}
.col-balance{border-right:2px solid #ddd;padding-right:16px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;}
.bal-label{font-size:.62rem;font-weight:900;text-transform:uppercase;letter-spacing:2px;color:#666;}
.bal-number{font-size:5.2rem;font-weight:900;line-height:1;margin:4px 0;}
.bal-unit{font-size:.78rem;font-weight:800;color:#444;margin-bottom:12px;}
.bricks{display:flex;flex-wrap:wrap;gap:3px;justify-content:center;margin-bottom:12px;max-width:180px;}
.brick{width:16px;height:11px;border-radius:2px;border-bottom:2px solid rgba(0,0,0,.25);}
.brick.filled{background:#000;}
.brick.empty{background:#f0f0f0;border:1px solid #ddd;border-bottom:2px solid #ccc;}
.next-label{font-size:.6rem;font-weight:900;text-transform:uppercase;letter-spacing:1.5px;color:#888;margin-bottom:3px;}
.next-name{font-size:.78rem;font-weight:800;}
.next-gap{font-size:.68rem;color:#555;margin-top:2px;}
.col-earn{padding:0 4px;overflow:hidden;}
.col-rewards{border-left:2px solid #ddd;padding-left:16px;overflow:hidden;}
.sec-title{font-size:.6rem;font-weight:900;text-transform:uppercase;letter-spacing:1.5px;color:#666;margin-bottom:5px;padding-bottom:3px;border-bottom:1.5px solid #eee;}
.sec-gap{margin-top:8px;}
.b-row{display:flex;align-items:center;gap:6px;margin-bottom:4px;}
.b-emoji{font-size:.9rem;width:20px;text-align:center;flex-shrink:0;}
.b-text{font-size:.72rem;font-weight:700;flex:1;line-height:1.2;}
.b-worth{font-size:.65rem;font-weight:900;white-space:nowrap;}
.r-item{margin-bottom:9px;}
.r-top{display:flex;align-items:center;gap:5px;margin-bottom:3px;}
.r-icon{font-size:.9rem;flex-shrink:0;}
.r-icon-img{width:18px;height:18px;border-radius:3px;object-fit:cover;flex-shrink:0;}
.r-name{font-size:.72rem;font-weight:800;flex:1;line-height:1.2;}
.r-cost{font-size:.65rem;font-weight:900;white-space:nowrap;}
.r-bar-bg{background:#eee;border-radius:99px;height:5px;overflow:hidden;border:1px solid #ddd;}
.r-bar-fill{height:100%;background:#000;border-radius:99px;}
.r-pct{font-size:.58rem;color:#999;text-align:right;font-weight:700;margin-top:1px;}
.r-ready{font-size:.6rem;font-weight:900;text-transform:uppercase;letter-spacing:1px;}
</style>
</head>
<body>
<div class="grid">
  <div class="header">
    <div class="header-left">
      <div class="header-avatar">${profile.avatar?.startsWith('data:') ? '' : (profile.avatar || '⭐')}</div>
      <div>
        <div class="header-name">${profile.name}'s Star Bank</div>
        <div class="header-sub">Save up or cash in — it's your choice!</div>
      </div>
    </div>
    <div class="header-time">Last updated: ${now}</div>
  </div>
  <div class="col-balance">
    <div class="bal-label">Balance</div>
    <div class="bal-number">${balance}</div>
    <div class="bal-unit">Stars ⭐</div>
    <div class="bricks">${bricks}</div>
    <div class="next-label">Next reward</div>
    <div class="next-name">${next ? next.emoji + ' ' + next.name : '🏆 Everything unlocked!'}</div>
    <div class="next-gap">${next ? (next.cost - balance) + ' more ⭐ to go!' : ''}</div>
  </div>
  <div class="col-earn">
    <div class="sec-title">Ways to earn ⭐</div>
    ${parentB.map(behaviourRow).join('')}
    <div class="sec-title sec-gap">${profile.name} can claim</div>
    ${selfB.map(behaviourRow).join('')}
  </div>
  <div class="col-rewards">
    <div class="sec-title">Rewards 🎁</div>
    ${rewards.slice(0, 6).map(rewardRow).join('')}
  </div>
</div>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html');
    res.setHeader('Cache-Control', 'no-store');
    res.status(200).send(html);

  } catch (err) {
    res.status(500).send(`<html><body style="font-family:sans-serif;padding:40px">
      <h2>⚠️ Error</h2><p>${err.message}</p>
    </body></html>`);
  }
}