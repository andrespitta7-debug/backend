// SysQuest — Edge Function: generar-encuentros-extra
// Genera por demanda 3 nuevos encuentros consecutivos para una quest en curso,
// los valida, los persiste atómicamente vía RPC y los retorna enriquecidos con IDs.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, jsonResponse } from '../_shared/response.ts';
import { obtenerProveedor } from '../_shared/ai/ai_factory.ts';
import {
  SYSTEM_PROMPT_NARRATIVA,
  construirUserPromptEncuentrosExtra,
} from '../_shared/narrativa_prompts.ts';
import { ENCUENTROS_EXTRA_SCHEMA } from '../_shared/run_schema.ts';
import { validarLoteEncuentrosExtra } from '../_shared/run_validator.ts';

const LETRAS = ['A', 'B', 'C', 'D'];
const VIDA_MIN_NORMAL = 40;
const VIDA_MAX_NORMAL = 60;

function barajarArray<T>(array: T[]): T[] {
  const copia = [...array];
  for (let i = copia.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
}

function normalizarVidaEnemigos(encuentros: any[]): void {
  for (const enc of encuentros) {
    const min = VIDA_MIN_NORMAL;
    const max = VIDA_MAX_NORMAL;
    const vida = enc.vida_enemigo;
    if (typeof vida !== 'number' || vida < min || vida > max) {
      enc.vida_enemigo = 50;
    }
  }
}

Deno.serve(async (req: Request) => {
  // 1. Manejo de preflight CORS
  if (req.method === 'OPTIONS') {
    return corsPreflightResponse();
  }

  // 2. Solo método POST
  if (req.method !== 'POST') {
    return jsonResponse(
      { ok: false, codigo: 'METODO_NO_PERMITIDO' },
      405
    );
  }

  // 3. Cliente Supabase con service_role
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error('Variables de entorno SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY no configuradas');
    return jsonResponse(
      { ok: false, codigo: 'CONFIG_FALTANTE', usar_fallback: true },
      500
    );
  }

  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

  // 4. Autenticación JWT del usuario
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return jsonResponse(
      { ok: false, codigo: 'NO_AUTORIZADO' },
      401
    );
  }

  const jwt = authHeader.replace('Bearer ', '').trim();
  const {
    data: { user },
    error: authErr,
  } = await supabaseAdmin.auth.getUser(jwt);

  if (authErr || !user) {
    return jsonResponse(
      { ok: false, codigo: 'NO_AUTORIZADO' },
      401
    );
  }

  // 5. Parsear y validar body
  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(
      { ok: false, codigo: 'DATOS_INVALIDOS', detalle: 'JSON en el cuerpo de solicitud inválido.' },
      400
    );
  }

  if (
    !body ||
    typeof body.id_quest !== 'string' ||
    body.id_quest.trim() === '' ||
    typeof body.tema !== 'string' ||
    body.tema.trim().length < 3 ||
    typeof body.categoria !== 'string' ||
    typeof body.dificultad !== 'string' ||
    typeof body.ultimo_numero !== 'number' ||
    !Number.isInteger(body.ultimo_numero) ||
    body.ultimo_numero < 1
  ) {
    return jsonResponse(
      {
        ok: false,
        codigo: 'DATOS_INVALIDOS',
        detalle: 'Parámetros requeridos: id_quest (uuid), tema (min 3 chars), categoria, dificultad, ultimo_numero (int >= 1).',
      },
      400
    );
  }

  const idQuest = body.id_quest.trim();
  const temaLimpio = body.tema.replace(/[<>{}]/g, '').trim();
  const categoria = body.categoria.trim();
  const dificultad = body.dificultad.trim();
  const ultimoNumero = body.ultimo_numero;

  // 6. Construir prompt y llamar al proveedor de IA
  const userPrompt = construirUserPromptEncuentrosExtra(
    temaLimpio,
    categoria,
    dificultad,
    ultimoNumero
  );

  const proveedor = obtenerProveedor();
  const resultadoIa = await proveedor.generarQuest({
    systemInstruction: SYSTEM_PROMPT_NARRATIVA,
    userPrompt,
    schema: ENCUENTROS_EXTRA_SCHEMA,
    timeoutMs: 60000,
  });

  // 7. Manejo de errores de IA
  if (!resultadoIa.ok) {
    console.error('Fallo proveedor IA en generar-encuentros-extra:', resultadoIa);
    if (resultadoIa.codigo === 'IA_TIMEOUT') {
      return jsonResponse(
        { ok: false, codigo: 'IA_TIMEOUT', usar_fallback: true },
        504
      );
    }
    return jsonResponse(
      {
        ok: false,
        codigo: resultadoIa.codigo,
        detalle: resultadoIa.detalle,
        usar_fallback: true,
      },
      502
    );
  }

  // 8. Parsear JSON devuelto por IA
  // deno-lint-ignore no-explicit-any
  let dataJson: any;
  try {
    dataJson = JSON.parse(resultadoIa.texto);
  } catch {
    console.error('JSON inválido retornado por IA:', resultadoIa.texto);
    return jsonResponse(
      { ok: false, codigo: 'IA_JSON_INVALIDO', usar_fallback: true },
      502
    );
  }

  const rawEncuentros = Array.isArray(dataJson)
    ? dataJson
    : dataJson?.encuentros ?? dataJson?.preguntas_extra;

  // 9. Validar encuentros con validador de lote
  const resValidacion = validarLoteEncuentrosExtra(
    rawEncuentros,
    categoria,
    ultimoNumero
  );

  if (!resValidacion.valido) {
    console.error('Validación de lote extra falló:', resValidacion.detalle);
    return jsonResponse(
      {
        ok: false,
        codigo: resValidacion.codigo,
        detalle: resValidacion.detalle,
        usar_fallback: true,
      },
      502
    );
  }

  const encuentrosValidados = resValidacion.encuentros;

  // 10. Barajar opciones, asignar letras y preparar payload para RPC
  const encuentrosParaRpc = encuentrosValidados.map((encuentro) => {
    const vidaEnemigo = typeof encuentro.vida_enemigo === 'number'
      ? encuentro.vida_enemigo
      : 50;
    const opcionesBarajadas = barajarArray(encuentro.opciones).map((op, idx) => ({
      letra: LETRAS[idx],
      texto: op.texto,
      calidad: op.calidad,
      explicacion: op.explicacion,
    }));

    return {
      numero: encuentro.numero,
      tipo_encuentro: encuentro.tipo_encuentro,
      dificultad,
      vida_enemigo: vidaEnemigo,
      concepto: encuentro.concepto ?? '',
      enemigo: encuentro.enemigo,
      pregunta: encuentro.pregunta,
      codigo: encuentro.codigo ?? null,
      opciones: opcionesBarajadas,
    };
  });

  // 11. Red de seguridad: normalizar vida
  normalizarVidaEnemigos(encuentrosParaRpc);

  // 12. Insertar atómicamente en Postgres vía RPC
  const { data: rpcData, error: rpcErr } = await supabaseAdmin.rpc(
    'insertar_encuentros_extra',
    {
      p_id_quest: idQuest,
      p_encuentros: encuentrosParaRpc,
    }
  );

  if (rpcErr || !rpcData) {
    console.error('Error en RPC insertar_encuentros_extra:', rpcErr);
    return jsonResponse(
      {
        ok: false,
        codigo: 'ERROR_PERSISTENCIA',
        detalle: rpcErr?.message ?? 'Fallo al insertar en base de datos',
      },
      500
    );
  }

  // 13. Retornar 200 con la lista de encuentros enriquecida con sus UUIDs
  return jsonResponse(
    {
      ok: true,
      encuentros: rpcData.encuentros ?? [],
    },
    200
  );
});
