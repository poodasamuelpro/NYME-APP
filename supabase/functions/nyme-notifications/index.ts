// supabase/functions/nyme-notifications/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function getFCMToken(): Promise<string> {
  const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
  const now = Math.floor(Date.now() / 1000);
  const enc = (o: object) => btoa(JSON.stringify(o)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=/g,"");
  const header = enc({ alg: "RS256", typ: "JWT" });
  const payload = enc({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token", exp: now+3600, iat: now });
  const input = `${header}.${payload}`;
  const der = Uint8Array.from(atob(sa.private_key.replace("-----BEGIN PRIVATE KEY-----","").replace("-----END PRIVATE KEY-----","").replace(/\n/g,"")), c=>c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name:"RSASSA-PKCS1-v1_5", hash:"SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(input));
  const jwt = `${input}.${btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/\+/g,"-").replace(/\//g,"_").replace(/=/g,"")}`;
  const res = await fetch("https://oauth2.googleapis.com/token", { method:"POST", headers:{"Content-Type":"application/x-www-form-urlencoded"}, body:`grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}` });
  const d = await res.json();
  if (!d.access_token) throw new Error("FCM token impossible");
  return d.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const body = await req.json();

    // EMAIL
    if (body.action === "email") {
      const res = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "accept":"application/json", "api-key": Deno.env.get("BREVO_API_KEY")??"", "content-type":"application/json" },
        body: JSON.stringify({
          sender: { name: "NYME Livraison", email: "nyme.contact@gmail.com" },
          to: [{ email: body.destinataire, name: body.nom_destinataire ?? body.destinataire }],
          subject: body.sujet,
          htmlContent: body.html,
        }),
      });
      const r = await res.json();
      if (!res.ok) throw new Error("Brevo: " + JSON.stringify(r));
      return new Response(JSON.stringify({ success: true }), { headers: { ...cors, "Content-Type": "application/json" } });
    }

    // PUSH FCM
    if (body.action === "push") {
      const supabase = createClient(Deno.env.get("SUPABASE_URL")??"", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"");
      const { data: user } = await supabase.from("utilisateurs").select("fcm_token").eq("id", body.destinataire_id).single();
      if (!user?.fcm_token) return new Response(JSON.stringify({ error: "Pas de token FCM" }), { status:400, headers: { ...cors, "Content-Type":"application/json" } });
      const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")??"{}");
      const token = await getFCMToken();
      const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method:"POST", headers:{ "Authorization":`Bearer ${token}`, "Content-Type":"application/json" },
        body: JSON.stringify({ message: { token: user.fcm_token, notification:{ title: body.titre, body: body.corps }, android:{ priority:"high" }, apns:{ payload:{ aps:{ sound:"default" } } } } }),
      });
      if (!r.ok) throw new Error("FCM: " + await r.text());
      return new Response(JSON.stringify({ success: true }), { headers: { ...cors, "Content-Type":"application/json" } });
    }

    return new Response(JSON.stringify({ error: "action inconnue" }), { status:400, headers: { ...cors, "Content-Type":"application/json" } });
  } catch(e) {
    return new Response(JSON.stringify({ error: e.message }), { status:500, headers: { ...cors, "Content-Type":"application/json" } });
  }
});
