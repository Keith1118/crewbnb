# Crewbnb — Launch Checklist

A plain-English guide to getting Crewbnb live. Work top to bottom.

---

## Where things stand

**Built and working (tested):**
- Guest site: homepage, search (by town + dates + guests), listing pages, booking flow
- 13 real listings: 10 Edenderry rooms + 3 Tulfarris homes (photos, pricing, details)
- Host area ("extranet"): dashboard, availability calendar, bookings, inbox
- Automatic messages to guests (booking received → confirmation → check-in details)
- Real crewbnb branding (logo, favicon, navy colours)
- 3 real accounts, all demo/fake data removed

**The big thing to understand:** the site currently runs **only on your Mac**
(`http://localhost:3000`). Nobody else can see it. "Launching" = putting it on the
internet. That's what the steps below are for.

---

## Your checklist (in order)

### 1. Change the temporary passwords 🔴 do this first
Three accounts still use the temporary password `password123`:
- `keithmckeown@gmail.com` (admin — most important)
- `tullyshome@gmail.com` (your Tulfarris host account)
- `edenderrycentral@gmail.com` (Edenderry host account)

Log in as each → avatar menu → **Account & password** → set a real password.

### 2. Choose where to host the site
A Rails app needs a host. For a beginner, the easiest options are:
- **Render.com** (recommended — simplest, has a free tier to start)
- Fly.io or Railway.app (also beginner-friendly)

You'll create an account and connect it to your GitHub repo
(`github.com/Keith1118/crewbnb`). These services build and run the app for you.
*(This is the step to get help with if any — it's the biggest one.)*

### 3. Add your secret keys (on the host, as "environment variables")
The app looks for these. Without them, some features stay off (that's by design —
nothing breaks, they just don't run):
- `STRIPE_SECRET_KEY` and `STRIPE_PUBLISHABLE_KEY` → turns on **card payments**.
  Until these are set, bookings work as "request to book" (host approves manually).
  Get them free at dashboard.stripe.com.
- SMTP email settings (host, username, password) → so booking/message **emails
  actually send**. A service like Resend.com or Postmark works well. Until set,
  emails won't go out in production.
- `GOOGLE_MAPS_API_KEY` (optional) → the map + nearby places on listing pages.
- `RAILS_MASTER_KEY` → copy from your local `config/master.key` (never share it publicly).

### 4. Get your listings onto the live site
Important: your 13 listings, photos, and accounts live in the database **on your
Mac**. A fresh host starts with an **empty** database. Two ways to handle it:
- **Simplest:** after deploying, log in and re-create the listings/accounts on the
  live site (upload the photos again).
- **Advanced:** copy your local database to production (ask for help — it's fiddly).

Either way, run the database setup on the host once: `rails db:migrate`.

### 5. Turn on the automatic reminder messages
Check-in reminders and review requests are sent by a scheduled task. On your host,
set up a **daily cron job** that runs:
```
rails crewbnb:auto_messages
```
(The "booking received" and "confirmed" messages already send automatically — no
cron needed for those.)

### 6. Final checks before you tell anyone
- [ ] Passwords changed (step 1)
- [ ] You can open the live site in an incognito window
- [ ] You can make a test booking end to end
- [ ] Emails arrive (if SMTP is set)
- [ ] Your domain (e.g. crewbnb.ie) points to the host

---

## Handy commands (local)
- Start the site locally: `./start.sh`  (then open http://localhost:3000)
- Run the reminder task: `bin/rails crewbnb:auto_messages`
- Save your work to GitHub: `git add -A && git commit -m "..." && git push`

## Good to know
- Payments and email are **feature-flagged**: the app checks whether keys exist and
  adjusts what it promises to guests. Add the keys and those features light up on
  their own — no code change needed.
- Time zone is set to Europe/Dublin.
