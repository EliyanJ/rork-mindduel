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

    // Admin review-state routes — real-time persistence of moderation
    // decisions and AI notes (password checked inside the Hub DO).
    if (url.pathname === "/api/review/state" && (request.method === "GET" || request.method === "POST")) {
      const res = await dispatchToDo(env, "Hub", "global", request);
      return withCors(res);
    }

    // Admin question-review tool: stateless AI proxy. The caller's API key is
    // used only for this single outbound request and is never stored, logged,
    // or forwarded anywhere except straight to the chosen provider — this
    // avoids browser CORS restrictions on Anthropic/Google without ever
    // persisting the key server-side.
    if (url.pathname === "/api/moderation/ai-review" && request.method === "POST") {
      return withCors(await handleAiReviewProxy(request));
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

type AiProxyBody = {
  provider?: "anthropic" | "openai" | "google";
  apiKey?: string;
  model?: string;
  systemPrompt?: string;
  userPrompt?: string;
};

async function handleAiReviewProxy(request: Request): Promise<Response> {
  let body: AiProxyBody;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "JSON invalide" }, { status: 400 });
  }
  const { provider, model, systemPrompt, userPrompt } = body;
  const apiKey = body.apiKey?.trim();
  if (!provider || !apiKey || !model || !userPrompt) {
    return Response.json({ error: "Paramètres manquants (provider, apiKey, model, userPrompt)" }, { status: 400 });
  }

  try {
    if (provider === "openai") {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: systemPrompt ?? "" },
            { role: "user", content: userPrompt },
          ],
          temperature: 0.2,
          max_tokens: 1500,
        }),
      });
      if (!res.ok) {
        const errText = await res.text().catch(() => res.statusText);
        return Response.json({ error: `OpenAI ${res.status}: ${errText.slice(0, 300)}` }, { status: 502 });
      }
      const data = (await res.json()) as { choices?: { message?: { content?: string } }[] };
      return Response.json({ content: data?.choices?.[0]?.message?.content ?? "" });
    }

    if (provider === "anthropic") {
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model,
          system: systemPrompt ?? "",
          messages: [{ role: "user", content: userPrompt }],
          max_tokens: 1500,
          temperature: 0.2,
        }),
      });
      if (!res.ok) {
        const errText = await res.text().catch(() => res.statusText);
        return Response.json({ error: `Anthropic ${res.status}: ${errText.slice(0, 300)}` }, { status: 502 });
      }
      const data = (await res.json()) as { content?: { text?: string }[] };
      return Response.json({ content: data?.content?.[0]?.text ?? "" });
    }

    if (provider === "google") {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: `${systemPrompt ?? ""}\n\n${userPrompt}` }] }],
            generationConfig: { temperature: 0.2, maxOutputTokens: 1500 },
          }),
        },
      );
      if (!res.ok) {
        const errText = await res.text().catch(() => res.statusText);
        return Response.json({ error: `Google ${res.status}: ${errText.slice(0, 300)}` }, { status: 502 });
      }
      const data = (await res.json()) as { candidates?: { content?: { parts?: { text?: string }[] } }[] };
      return Response.json({ content: data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "" });
    }

    if (provider === "perplexity") {
      // Perplexity Sonar models search the web in real-time and return citations.
      const res = await fetch("https://api.perplexity.ai/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: systemPrompt ?? "" },
            { role: "user", content: userPrompt },
          ],
          temperature: 0.2,
          max_tokens: 4000,
        }),
      });
      if (!res.ok) {
        const errText = await res.text().catch(() => res.statusText);
        return Response.json({ error: `Perplexity ${res.status}: ${errText.slice(0, 300)}` }, { status: 502 });
      }
      const data = (await res.json()) as { choices?: { message?: { content?: string } }[]; finish_reason?: string };
      return Response.json({ content: data?.choices?.[0]?.message?.content ?? "" });
    }

    return Response.json({ error: "Fournisseur inconnu" }, { status: 400 });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return Response.json({ error: `Erreur proxy IA: ${msg}` }, { status: 500 });
  }
}
