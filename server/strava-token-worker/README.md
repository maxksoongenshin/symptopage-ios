# Strava token proxy (free)

Needed only when the app is given to other people. For your own phone, personal mode
(Client ID + Secret typed in Integracje) works without any server.

1. Strava: https://www.strava.com/settings/api → create an app, Authorization Callback Domain = `localhost`.
2. Cloudflare (free account): in this folder
   ```sh
   npx wrangler login
   # edit wrangler.toml: STRAVA_CLIENT_ID
   npx wrangler secret put STRAVA_CLIENT_SECRET
   npx wrangler deploy
   ```
   You get a URL like `https://symptopage-strava-token.<you>.workers.dev`.
3. Build the app with these two values (no secret inside the app):
   ```sh
   STRAVA_CLIENT_ID=12345 STRAVA_TOKEN_URL=https://symptopage-strava-token.<you>.workers.dev bash scripts/install_on_iphone.sh
   ```
Users then only tap "Połącz Strava".

Strava limits for a new API app: 1 connected athlete until Strava approves the app
("Developer Program" review, free), 200 requests / 15 min, 2 000 / day.
