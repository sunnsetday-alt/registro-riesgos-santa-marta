// =====================================================================
// Edge Function: classify-report
// ---------------------------------------------------------------------
// Uso concreto de IA (opcional): sugiere categoría y nivel de importancia a
// partir del título y la descripción. La app SIEMPRE tiene un clasificador
// local por palabras clave; esta función solo se usa si está desplegada y
// configurada (AI_API_KEY). Nunca decide por el ciudadano: solo sugiere.
//
// Variables de entorno (supabase secrets set ...):
//   AI_API_KEY      Clave de la API de Anthropic (obligatoria para activar)
//   AI_MODEL        Modelo (por defecto: claude-haiku-4-5-20251001)
//   SUPABASE_URL / SUPABASE_ANON_KEY  (inyectadas automáticamente)
//
// Despliegue:  supabase functions deploy classify-report
// =====================================================================
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);

  const apiKey = Deno.env.get("AI_API_KEY");
  if (!apiKey) return json({ error: "Clasificador IA no configurado" }, 501);

  // Solo usuarios autenticados.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) return json({ error: "No autenticado" }, 401);

  let title = "";
  let description = "";
  try {
    const body = await req.json();
    title = String(body.title ?? "").slice(0, 120);
    description = String(body.description ?? "").slice(0, 2000);
  } catch {
    return json({ error: "JSON inválido" }, 400);
  }
  if (description.trim().length < 10) return json({ error: "Descripción muy corta" }, 400);

  const { data: categories, error: catError } = await supabase
    .from("categories")
    .select("code,name")
    .eq("is_active", true);
  if (catError || !categories) return json({ error: "No se pudieron cargar categorías" }, 500);

  const prompt =
    `Eres un asistente que clasifica reportes ciudadanos de problemáticas urbanas en Santa Marta, Colombia.\n` +
    `Categorías disponibles (code: nombre):\n` +
    categories.map((c) => `- ${c.code}: ${c.name}`).join("\n") +
    `\n\nNiveles de importancia: 1 Muy baja, 2 Baja, 3 Media, 4 Alta, 5 Crítica (riesgo para la vida o la integridad).\n\n` +
    `Título: ${title}\nDescripción: ${description}\n\n` +
    `Responde SOLO con JSON: {"category_code": "<code>", "severity": <1-5>, "reason": "<máx 25 palabras>"}`;

  const aiResponse = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: Deno.env.get("AI_MODEL") ?? "claude-haiku-4-5-20251001",
      max_tokens: 200,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!aiResponse.ok) return json({ error: "Error del proveedor de IA" }, 502);
  const aiJson = await aiResponse.json();
  const text: string = aiJson?.content?.[0]?.text ?? "";
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return json({ error: "Respuesta de IA no interpretable" }, 502);

  try {
    const parsed = JSON.parse(match[0]);
    const validCode = categories.some((c) => c.code === parsed.category_code);
    const severity = Math.min(5, Math.max(1, Number(parsed.severity) || 3));
    return json({
      category_code: validCode ? parsed.category_code : "otros",
      severity,
      reason: String(parsed.reason ?? "").slice(0, 200),
      source: "ai",
    });
  } catch {
    return json({ error: "Respuesta de IA no interpretable" }, 502);
  }
});
