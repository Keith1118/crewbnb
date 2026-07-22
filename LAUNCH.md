# Crewbase — Launch Checklist

A plain-English guide to getting Crewbase fully live. Work top to bottom.

---

## Where things stand

**The site is live.** It runs on Render at **https://crewbase.ie** with the real
listings, photos and accounts on it. Anyone can visit it right now.

What's live and working:
- Guest site: homepage, search (town + dates + beds), listing pages, FAQ
- Real listings with photos, pricing and drive-distance chips
- Host area ("extranet"): dashboard, availability calendar, bookings, inbox
- Host listing setup, including the weekday rate + weekly discount
- Automatic messages to guests (booking received → confirmed → check-in → review)
- Photos stored permanently in Cloudflare R2 (they survive every deploy)
- Email sending through Resend, from `info@crewbase.ie`
- Real crewbase branding, `crewbase.ie` domain, sitemap and robots.txt

**What is deliberately switched off:** guests can browse and see prices, but they
**cannot place a booking**. The booking form says "Bookings opening soon" and the
server refuses bookings even if someone posts to it directly. That's the
`BOOKINGS_OPEN` flag — flipping it is the actual go-live moment (step 4 below).

---

## Your checklist (in order)

### 1. Move the database off the free plan 🔴 most urgent
Render's **free Postgres expires after 90 days and is then deleted.** That
database holds your live listings, photos and accounts. Losing it means starting
over.

In the Render dashboard → your `crewbnb-db` database → **Upgrade** to a paid
plan. Do this before anything else on this list.

*(The database is named `crewbnb-db` on purpose — renaming it would make Render
build a brand-new empty one and orphan the real data. It's an internal label
nobody sees.)*

### 2. Sync the blueprint to pick up the two infrastructure changes
`render.yaml` now sets two things that need a blueprint sync to take effect:
- the web service moves from **free → starter**, so the site stops going to sleep
  after 15 minutes idle (no more ~30-second wait on the first visit)
- a new **`crewbase-auto-messages` cron job** runs daily at 08:00 UTC (09:00 Irish
  summer time), which is what actually sends check-in reminders and review
  requests. Until this exists, those two messages never go out.

In Render → **Blueprints** → your blueprint → **Sync**. Both are paid services;
Render has no free tier for cron jobs.

Then open the new **crewbase-auto-messages** service → **Environment** and paste in
the four secrets it can't inherit (they're the same values already on the web
service): `RAILS_MASTER_KEY`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, and
`SMTP_PASSWORD`. It won't send anything until you do.

You can prove it works with **Trigger Run** on that service — it prints how many
messages it sent.

### 3. Add your Stripe keys (turns on card payments)
In Render → web service → **Environment**, set:
- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY`

Get them free at dashboard.stripe.com. Until they're set the app quietly runs as
"request to book" (host approves each booking by hand) — nothing breaks, the app
just stops promising instant booking. Add the keys and payments light up on their
own; no code change needed.

### 4. Open bookings — this is go-live 🚀
In Render → web service → **Environment**, add:
```
BOOKINGS_OPEN = true
```
Do this **last**, after you've walked through a test booking yourself. Setting it
back to `false` closes bookings again at any time.

### 5. Final checks
- [ ] Database on a paid plan (step 1) — no 90-day time bomb
- [ ] Blueprint synced; cron job triggered once by hand and it reported success
- [ ] Every account has a real password (no `password123` left anywhere)
- [ ] Open https://crewbase.ie in an incognito window — listings and prices show
- [ ] Make a test booking end to end and confirm the emails arrive
- [ ] Then, and only then, flip `BOOKINGS_OPEN` to `true`

---

## Handy commands (local)
- Start the site locally: `./start.sh`  (then open http://localhost:3000)
- Run the reminder task by hand: `bin/rails crewbase:auto_messages`
- Save your work to GitHub: `git add -A && git commit -m "..." && git push`
  (Render redeploys automatically on every push to `main`.)

## Good to know
- **Payments, email and bookings are all feature-flagged.** The app checks whether
  the keys/flags exist and adjusts what it promises guests. This is why the site
  can be live and safe before it can take money.
- The map on listing pages uses Google's **free embed** — there's no Maps API key
  to buy or configure.
- Time zone is Europe/Dublin. Render's cron schedules are always in UTC.
