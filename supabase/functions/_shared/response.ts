// Helper para estandarizar las respuestas HTTP JSON con headers CORS.

import { corsHeaders } from './cors.ts';

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

export function errorResponse(error: string, status = 400): Response {
  return jsonResponse({ ok: false, error }, status);
}

export function corsPreflightResponse(): Response {
  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}
