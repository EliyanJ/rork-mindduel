// functions/index.ts — Cortex multiplayer backend entrypoint.
// Routes: profile/friends/leaderboard/matchmaking (Hub DO, HTTP) and
// ranked duel rooms (MatchRoom DO, WebSocket).

export { Hub } from "./hub";
export { MatchRoom } from "./match-room";

type Env = { DO: Fetcher };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // CORS preflight — browser sends OPTIONS before cross-origin POST.
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(),
      });
    }

    if (url.pathname === "/ping") {
      return corsResponse(Response.json({ ok: true, now: new Date().toISOString() }));
    }

    // Content delivery routes — public GET (app fetches latest content),
    // password-protected POST (admin pushes from generator panel).
    // Both need CORS headers for cross-origin browser access.
    if (url.pathname === "/api/content" && request.method === "GET") {
      const res = await dispatchToDo(env, "Hub", "global", request);
      return withCors(res);
    }
    if (url.pathname === "/api/content/publish" && request.method === "POST") {
      const res = await dispatchToDo(env, "Hub", "global", request);
      return withCors(res);
    }

    // Hub routes (auth required — the platform stamps X-Rork-User-Id when
    // the Bearer token is valid; the Hub itself rejects missing identity).
    if (url.pathname.startsWith("/api/hub/")) {
      return dispatchToDo(env, "Hub", "global", request);
    }

    // Ranked match WebSocket: /api/match/<matchId>/ws
    const matchRoute = url.pathname.match(/^\/api\/match\/([^/]+)\/ws$/);
    if (matchRoute && request.headers.get("Upgrade") === "websocket") {
      const userId = request.headers.get("X-Rork-User-Id");
      if (!userId) {
        return Response.json({ error: "authentification requise" }, { status: 401 });
      }
      url.searchParams.set("userId", userId);
      return dispatchToDo(env, "MatchRoom", matchRoute[1]!, new Request(url.toString(), request));
    }

    return Response.json({ error: "not found" }, { status: 404 });
  },
} satisfies ExportedHandler<Env>;

function dispatchToDo(env: Env, className: string, id: string, request: Request): Promise<Response> {
  const wrapped = new Request(request.url, request);
  const headers = new Headers(wrapped.headers);
  headers.set("X-Rork-DO-Class", className);
  headers.set("X-Rork-DO-Id", id);
  return env.DO.fetch(
    new Request(wrapped.url, {
      method: wrapped.method,
      headers,
      body: wrapped.body,
      redirect: wrapped.redirect,
    }),
  );
}

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Max-Age": "86400",
  };
}

function withCors(res: Response): Response {
  const newHeaders = new Headers(res.headers);
  for (const [k, v] of Object.entries(corsHeaders())) {
    newHeaders.set(k, v);
  }
  return new Response(res.body, {
    status: res.status,
    statusText: res.statusText,
    headers: newHeaders,
  });
}

function corsResponse(res: Response): Response {
  return withCors(res);
}
