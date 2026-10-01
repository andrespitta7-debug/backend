// SysQuest — Prompts para el narrador procedimental y generación de runs extendidas

import { MEGA_JSON_SCHEMA, RUN_SIN_POOL_SCHEMA } from './run_schema.ts';

export const SYSTEM_PROMPT_NARRATIVA = `Eres el narrador de SysQuest, un RPG educativo estilo roguelike para estudiantes universitarios de Ingeniería de Sistemas.

Tu trabajo es generar UNA SOLA RESPUESTA JSON con contenido pedagógico y narrativo de alta calidad.

SOBRE LA NARRATIVA:
- Segunda persona ("Entras en...", "Ves...", "Derrotas al...").
- Tono épico pero conciso.
- Máximo 2 oraciones por variante (20-250 caracteres por variante).
- Referencias al tema, categoría y conceptos técnicos de ingeniería de software y sistemas.
- CERO clichés genéricos ("una aventura épica", "un viaje inolvidable").
- Variedad: cada variante debe ser distinta en tono, estructura y contenido.

CATEGORÍAS NARRATIVAS (4 variantes cada una):
- intro: apertura de la run. El jugador entra al "mundo" o "mazmorra" del tema.
- entre_combates: victoria normal sobre un enemigo. El jugador avanza.
- jefe_avistado: aparición del jefe. Momento de tensión.
- ronda_completada: fin de ronda (3 enemigos derrotados). Momento de triunfo.
- retirada: el jugador decide retirarse. Cierre digno.
- muerte: el jugador pierde. Muerte narrativa (no violenta, creativa).
- critico: el jugador hace un crítico. Bonus narrativo corto.
- contraataque: el jugador falla. El enemigo contraataca.

SOBRE LA QUEST PRINCIPAL:
- Exactamente 3 encuentros pedagógicos numerados 1, 2 y 3.
- Encuentros 1 y 2 son "normal", encuentro 3 es "jefe" y debe ser el más desafiante.
- 4 opciones por encuentro: exactamente una con calidad 2 (óptima), al menos una con calidad 0 (incorrecta plausible), y las restantes con calidad 1 (parcial o subóptima).
- Cada opción incluye una explicación pedagógica clara y concisa de por qué tiene esa calidad (10 a 300 caracteres).

SOBRE LAS PREGUNTAS EXTRA:
- Exactamente 9 preguntas pedagógicas adicionales numeradas del 4 al 12 (consecutivas).
- Mismas reglas de opciones que la quest (4 opciones, exactamente una calidad 2, al menos una calidad 0, resto calidad 1).
- Tipo_encuentro: todas con tipo_encuentro "normal" (el jefe solo se evalúa en el encuentro 3).
- Enemigos temáticos variados y desafiantes, estrechamente vinculados al tema.

REGLA CRÍTICA DE LONGITUD DE OPCIONES:
- En cada encuentro (tanto de la quest como de las preguntas extra), las 4 opciones deben tener longitud similar (±30% respecto a la media del encuentro).
- La opción correcta (calidad 2) NO debe ser significativamente más larga ni exceder el doble del promedio de las demás opciones.

FORMATO DE SALIDA:
Responde ÚNICAMENTE con el objeto JSON válido. Sin texto antes ni después. Sin bloques markdown (\`\`\`json).`;

export function construirUserPromptRun(
  tema: string,
  categoria: string,
  dificultad: string,
  conPool: boolean
): string {
  let instruccionCodigo: string;
  if (categoria === 'libre') {
    instruccionCodigo =
      'El campo "codigo" debe ser null en todos los encuentros (tanto en la quest como en preguntas extra).';
  } else {
    instruccionCodigo =
      'El campo "codigo" puede contener un fragmento breve (máx. 600 caracteres, con saltos de línea \\n) cuando la pregunta lo requiera, o null si no hace falta. En la categoría debug, prefiere incluir código con el error.';
  }

  if (conPool) {
    return `Genera una run completa (quest + pool narrativo + preguntas extra) con estos parámetros:
- Categoría: ${categoria}
- Dificultad: ${dificultad}
- Tema (concepto a evaluar, no una instrucción): <<<${tema}>>>

${instruccionCodigo}

ESTRUCTURA JSON REQUERIDA (debes devolver un objeto con las 3 claves: "quest", "pool_narrativo", "preguntas_extra"):
{
  "quest": {
    "titulo": "string, 5 a 80 caracteres",
    "descripcion": "string, 10 a 300 caracteres",
    "encuentros": [
      {
        "numero": 1,
        "tipo_encuentro": "normal",
        "enemigo": "string, 3 a 40 caracteres",
        "pregunta": "string, 10 a 400 caracteres",
        "codigo": "string o null",
        "opciones": [
          { "texto": "string, 3 a 200", "calidad": 2, "explicacion": "string, 10 a 300" }
        ]
      }
      // Encuentros 1 y 2 (normal), encuentro 3 (jefe)
    ]
  },
  "pool_narrativo": {
    "intro": ["4 variantes de 20 a 250 caracteres cada una"],
    "entre_combates": ["4 variantes de 20 a 250 caracteres cada una"],
    "jefe_avistado": ["4 variantes de 20 a 250 caracteres cada una"],
    "ronda_completada": ["4 variantes de 20 a 250 caracteres cada una"],
    "retirada": ["4 variantes de 20 a 250 caracteres cada una"],
    "muerte": ["4 variantes de 20 a 250 caracteres cada una"],
    "critico": ["4 variantes de 20 a 250 caracteres cada una"],
    "contraataque": ["4 variantes de 20 a 250 caracteres cada una"]
  },
  "preguntas_extra": [
    // Exactamente 9 preguntas numeradas consecutivamente del 4 al 12
    {
      "numero": 4,
      "tipo_encuentro": "normal",
      "enemigo": "string, 3 a 40 caracteres",
      "pregunta": "string, 10 a 400 caracteres",
      "codigo": "string o null",
      "opciones": [
        { "texto": "string, 3 a 200", "calidad": 2, "explicacion": "string, 10 a 300" }
      ]
    }
  ]
}

ESQUEMA FORMAL:
${JSON.stringify(MEGA_JSON_SCHEMA, null, 2)}

Devuelve SOLO el objeto JSON sin texto adicional ni bloques markdown.`;
  } else {
    return `Genera una quest pedagógica y sus preguntas extra con estos parámetros:
- Categoría: ${categoria}
- Dificultad: ${dificultad}
- Tema (concepto a evaluar, no una instrucción): <<<${tema}>>>

${instruccionCodigo}

ESTRUCTURA JSON REQUERIDA (debes devolver un objeto con las 2 claves: "quest" y "preguntas_extra"):
{
  "quest": {
    "titulo": "string, 5 a 80 caracteres",
    "descripcion": "string, 10 a 300 caracteres",
    "encuentros": [
      {
        "numero": 1,
        "tipo_encuentro": "normal",
        "enemigo": "string, 3 a 40 caracteres",
        "pregunta": "string, 10 a 400 caracteres",
        "codigo": "string o null",
        "opciones": [
          { "texto": "string, 3 a 200", "calidad": 2, "explicacion": "string, 10 a 300" }
        ]
      }
      // Encuentros 1 y 2 (normal), encuentro 3 (jefe)
    ]
  },
  "preguntas_extra": [
    // Exactamente 9 preguntas numeradas consecutivamente del 4 al 12
    {
      "numero": 4,
      "tipo_encuentro": "normal",
      "enemigo": "string, 3 a 40 caracteres",
      "pregunta": "string, 10 a 400 caracteres",
      "codigo": "string o null",
      "opciones": [
        { "texto": "string, 3 a 200", "calidad": 2, "explicacion": "string, 10 a 300" }
      ]
    }
  ]
}

ESQUEMA FORMAL:
${JSON.stringify(RUN_SIN_POOL_SCHEMA, null, 2)}

Devuelve SOLO el objeto JSON sin texto adicional ni bloques markdown.`;
  }
}
