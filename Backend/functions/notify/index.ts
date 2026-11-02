// Lockin `notify` Edge Function — sends push notifications through APNs.
//
// Called by three Database Webhooks (Supabase → Database → Webhooks):
//   friend_requests  INSERT  → "Herrera wants to be friends"
//   group_members    INSERT  → "Herrera invited you to Library crew"
//   groups           UPDATE  → "Library crew is locking in" (to the other joined members)
//   moments          INSERT  → "Herrera shared a moment"
//   cheers           INSERT  → "Herrera cheered you 🔥"
//
// Secrets (Edge Functions → Secrets):
//   APNS_KEY_ID       the 10-character Key ID of your APNs key
//   APNS_PRIVATE_KEY  the full contents of the .p8 file, including the BEGIN/END lines
//   APNS_TEAM_ID      97DF4F6KUN
//   APNS_BUNDLE_ID    com.focustogether.FocusTogether
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase automatically.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

type Payload = {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Record<string, any> | null;
  old_record: Record<string, any> | null;
};

type Message = { key: string; userIds: string[]; title: string; body: string; kind: string };

Deno.serve(async (req) => {
  const payload = (await req.json()) as Payload;
  const message = await messageFor(payload);
  if (!message || message.userIds.length === 0) return json({ sent: 0 });

  // Each event is announced once; a repeat call hits the primary key and stops here.
  const { error: duplicate } = await db.from("push_log").insert({ key: message.key });
  if (duplicate) return json({ sent: 0, skipped: "already notified" });

  const { data: tokens, error } = await db
    .from("push_tokens")
    .select("token, sandbox")
    .in("user_id", message.userIds);
  if (error) return json({ error: error.message }, 500);

  const jwt = await apnsJWT();
  const results = await Promise.all(
    (tokens ?? []).map((t) => sendAPNs(t.token, t.sandbox, jwt, message)),
  );
  // Apple's reasons for any failures (e.g. BadDeviceToken) end up in net._http_response for debugging.
  return json({
    sent: results.filter((r) => r.ok).length,
    of: results.length,
    failures: results.filter((r) => !r.ok).map((r) => r.reason),
  });
});

// What to say, and to whom, for each kind of change. Every event is re-checked against the
// database, so a forged payload can't invent requests, invites or sessions.
async function messageFor({ table, type, record, old_record }: Payload): Promise<Message | null> {
  if (!record) return null;

  if (table === "friend_requests" && type === "INSERT") {
    const { data: request } = await db.from("friend_requests").select("from_id")
      .eq("from_id", record.from_id).eq("to_id", record.to_id).maybeSingle();
    if (!request) return null;
    const from = await nameOf(record.from_id);
    return {
      key: `request:${record.from_id}:${record.to_id}`,
      userIds: [record.to_id], title: `${from} wants to be friends`, body: "Open Lockin to accept.", kind: "friend_request",
    };
  }

  if (table === "group_members" && type === "INSERT" && record.status === "invited") {
    const { data: invite } = await db.from("group_members").select("invited_by")
      .eq("group_id", record.group_id).eq("user_id", record.user_id).eq("status", "invited").maybeSingle();
    if (!invite) return null;
    const [inviter, group] = await Promise.all([nameOf(invite.invited_by), groupName(record.group_id)]);
    return {
      key: `invite:${record.group_id}:${record.user_id}`,
      userIds: [record.user_id], title: `${inviter} invited you to ${group}`, body: "Open Lockin to join the group.", kind: "group_invite",
    };
  }

  if (table === "moments" && type === "INSERT") {
    const { data: moment } = await db.from("moments").select("id, user_id, caption, tag")
      .eq("id", record.id).maybeSingle();
    if (!moment) return null;
    const { data: friends } = await db.from("friendships").select("friend_id").eq("user_id", moment.user_id);
    const name = await nameOf(moment.user_id);
    return {
      key: `moment:${moment.id}`,
      userIds: (friends ?? []).map((f) => f.friend_id),
      title: `${name} shared a moment 📸`,
      body: moment.caption ?? moment.tag ?? "Open Lockin to see it.",
      kind: "moment",
    };
  }

  if (table === "cheers" && type === "INSERT") {
    const { data: cheer } = await db.from("cheers").select("id, from_id, to_id, emoji")
      .eq("id", record.id).maybeSingle();
    if (!cheer) return null;
    const name = await nameOf(cheer.from_id);
    return {
      key: `cheer:${cheer.id}`,
      userIds: [cheer.to_id],
      title: `${name} cheered you ${cheer.emoji}`,
      body: "Keep going — you've got this.",
      kind: "cheer",
    };
  }

  if (table === "groups" && type === "UPDATE") {
    const started = record.session_ends_at && record.session_ends_at !== old_record?.session_ends_at;
    if (!started) return null;
    const { data: group } = await db.from("groups").select("id, name, session_ends_at, session_started_by")
      .eq("id", record.id).single();
    if (!group?.session_ends_at || !group.session_started_by) return null;
    if (new Date(group.session_ends_at).getTime() !== new Date(record.session_ends_at).getTime()) return null;
    record = group;
    const minutes = Math.round((new Date(record.session_ends_at).getTime() - Date.now()) / 60000);
    if (minutes <= 0) return null;
    const { data: members } = await db
      .from("group_members")
      .select("user_id")
      .eq("group_id", record.id)
      .eq("status", "joined")
      .neq("user_id", record.session_started_by);
    const starter = await nameOf(record.session_started_by);
    return {
      key: `session:${record.id}:${record.session_ends_at}`,
      userIds: (members ?? []).map((m) => m.user_id),
      title: `${record.name} is locking in 🔒`,
      body: `${starter} started · ${minutes} min — tap to join`,
      kind: "group_session",
    };
  }

  return null;
}

async function nameOf(id: string | null): Promise<string> {
  if (!id) return "Someone";
  const { data } = await db.from("profiles").select("display_name").eq("id", id).single();
  return data?.display_name ?? "Someone";
}

async function groupName(id: string): Promise<string> {
  const { data } = await db.from("groups").select("name").eq("id", id).single();
  return data?.name ?? "a group";
}

// APNs ------------------------------------------------------------------------

let cachedJWT: { token: string; issuedAt: number } | null = null;

// Token-based APNs auth: an ES256 JWT, reusable for up to an hour (Apple asks for ≥20 min reuse).
async function apnsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && now - cachedJWT.issuedAt < 50 * 60) return cachedJWT.token;

  const pem = Deno.env.get("APNS_PRIVATE_KEY")!;
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);

  const header = b64url(JSON.stringify({ alg: "ES256", kid: env("APNS_KEY_ID") }));
  const claims = b64url(JSON.stringify({ iss: env("APNS_TEAM_ID"), iat: now }));
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const token = `${header}.${claims}.${b64url(new Uint8Array(signature))}`;
  cachedJWT = { token, issuedAt: now };
  return token;
}

async function sendAPNs(
  deviceToken: string,
  sandbox: boolean,
  jwt: string,
  message: Message,
): Promise<{ ok: boolean; reason?: string }> {
  const host = sandbox ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
  const res = await fetch(`${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": env("APNS_BUNDLE_ID"),
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({
      aps: { alert: { title: message.title, body: message.body }, sound: "default" },
      kind: message.kind,
    }),
  });
  if (res.ok) return { ok: true };
  const reason = `${res.status} ${await res.text()}`;
  // A token Apple no longer accepts (app deleted) is removed so we stop trying it.
  if (res.status === 410) {
    await db.from("push_tokens").delete().eq("token", deviceToken);
  }
  return { ok: false, reason };
}

/// Secrets pasted into the dashboard often pick up a trailing newline; trim them.
function env(name: string): string {
  return (Deno.env.get(name) ?? "").trim();
}

function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
