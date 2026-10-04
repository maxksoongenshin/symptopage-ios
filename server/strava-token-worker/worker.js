// Strava token proxy for SymptoPage (Cloudflare Workers, free plan is enough).
// The app sends client_id + code (or refresh_token); this worker adds the client secret,
// which therefore never ships inside the iPhone app. No data is stored here.
export default {
  async fetch(request, env) {
    if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const form = await request.formData();
    const grant = form.get("grant_type");
    if (form.get("client_id") !== env.STRAVA_CLIENT_ID) return new Response("Unknown client", { status: 403 });
    const body = new URLSearchParams({ client_id: env.STRAVA_CLIENT_ID, client_secret: env.STRAVA_CLIENT_SECRET, grant_type: grant });
    if (grant === "authorization_code" && form.get("code")) body.set("code", form.get("code"));
    else if (grant === "refresh_token" && form.get("refresh_token")) body.set("refresh_token", form.get("refresh_token"));
    else return new Response("Bad request", { status: 400 });
    const upstream = await fetch("https://www.strava.com/oauth/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });
    return new Response(upstream.body, {
      status: upstream.status,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  },
};
