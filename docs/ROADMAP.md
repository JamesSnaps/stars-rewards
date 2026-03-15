# Star Bank Roadmap

## Current phase

- Reward economy refresh
  - Group rewards into quick wins, medium goals, and big goals.
  - Feature one random reward each day to keep the reward screen fresh.
  - Route reward redemption through a parent approval step.

- Motivation loop
  - Show a current streak and best streak based on days with real earns.
  - Add a weekly milestone target for earned stars.
  - Keep progress visible on the main earn screen.

- Responsive app shell
  - Support phone, tablet, and desktop widths.
  - Avoid a fixed phone-only layout in landscape or wider browser windows.

## Next product improvements

- Behaviour categories
  - Tag behaviours by themes like kindness, independence, effort, and routines.
  - Show category progress so children can see balanced growth, not just total stars.

- Weekly recap
  - Add a simple end-of-week summary with stars earned, stars spent, streak progress, and standout behaviours.

- Reward pacing controls
  - Let parents set caps or cooldowns on specific high-frequency behaviours.
  - Add optional weekly limits for repeat rewards such as screen time.

- Celebration layer
  - Add stronger milestone feedback with richer animations, badges, and unlock moments.

- Better parent controls
  - Add reward-request notes like "delivered" or "planned for Saturday".
  - Add filters for pending, approved, and declined requests.

## Technical roadmap

- Secure parent actions
  - Move parent approval and admin actions behind server-validated routes.
  - Stop relying on a client-side password and open anon policies for sensitive actions.

- Data migrations
  - Create a proper migration for `reward_requests` and any future schema additions.
  - Add a lightweight migration checklist to the repo.

- Reporting and stability
  - Add a small diagnostics mode for failed Supabase requests.
  - Add a smoke-test checklist for reward requests, refunds, one-time rewards, and profile switching.
