// SysQuest — Schemas JSON para run extendida (quest + pool narrativo + preguntas extra)
// Utilizado para structured output de proveedores de IA (Groq, Gemini, etc.)

import { QUEST_JSON_SCHEMA } from './quest_schema.ts';

export { QUEST_JSON_SCHEMA };

export const POOL_NARRATIVO_SCHEMA = {
  type: 'object',
  properties: {
    intro: {
      type: 'array',
      description: '3 variantes de apertura de la run (20 a 250 caracteres cada una)',
      minItems: 3,
      maxItems: 3,
      items: { type: 'string' },
    },
    entre_combates: {
      type: 'array',
      description: '3 variantes de avance victorioso entre combates (20 a 250 caracteres cada una)',
      minItems: 3,
      maxItems: 3,
      items: { type: 'string' },
    },
    jefe_avistado: {
      type: 'array',
      description: '3 variantes de avistamiento o aparición del jefe (20 a 250 caracteres cada una)',
      minItems: 3,
      maxItems: 3,
      items: { type: 'string' },
    },
    ronda_completada: {
      type: 'array',
      description: '3 variantes de triunfo tras completar una ronda (20 a 250 caracteres cada una)',
      minItems: 3,
      maxItems: 3,
      items: { type: 'string' },
    },
    retirada: {
      type: 'array',
      description: '3 variantes de retirada táctica o voluntaria del jugador (20 a 250 caracteres cada una)',
      minItems: 3,
      maxItems: 3,
      items: { type: 'string' },
    },
    muerte: {
      type: 'array',
      description: '3 variantes creativas y no violentas de derrota narrativa (20 a 250 caracteres cada una)',
      minItems: 3,
      maxItems: 3,
      items: { type: 'string' },
    },
    critico: {
      type: 'array',
      description: '3 variantes cortas de impacto crítico del jugador (20 a 250 caracteres cada una)',
      minItems: 3,
      maxItems: 3,
      items: { type: 'string' },
    },
    contraataque: {
      type: 'array',
      description: '3 variantes de fallo y contraataque del enemigo (20 a 250 caracteres cada una)',
      minItems: 3,
      maxItems: 3,
      items: { type: 'string' },
    },
  },
  required: [
    'intro',
    'entre_combates',
    'jefe_avistado',
    'ronda_completada',
    'retirada',
    'muerte',
    'critico',
    'contraataque',
  ],
};

export const PREGUNTAS_EXTRA_SCHEMA = {
  type: 'array',
  description: 'Exactamente 9 preguntas pedagógicas extra numeradas consecutivamente del 4 al 12',
  minItems: 9,
  maxItems: 9,
  items: {
    type: 'object',
    properties: {
      numero: {
        type: 'integer',
        description: 'Número consecutivo del encuentro extra: 4, 5, 6, 7, 8, 9, 10, 11 o 12',
      },
      tipo_encuentro: {
        type: 'string',
        enum: ['normal', 'jefe'],
        description: 'Tipo de encuentro. En preguntas extra siempre es "normal"',
      },
      enemigo: {
        type: 'string',
        description: 'Nombre temático del enemigo (3 a 40 caracteres)',
      },
      vida_enemigo: {
        type: 'integer',
        description: 'Puntos de vida del enemigo (normal: 40-60, jefe: 80-120)',
      },
      concepto: {
        type: 'string',
        minLength: 1,
        maxLength: 40,
        description: 'Concepto evaluado por la pregunta (máx. 40 caracteres)',
      },
      pregunta: {
        type: 'string',
        description: 'Pregunta o desafío técnico (10 a 400 caracteres)',
      },
      codigo: {
        type: ['string', 'null'],
        description: 'Fragmento de código opcional (máx. 600 caracteres) o null si no aplica',
      },
      opciones: {
        type: 'array',
        description: 'Exactamente 4 opciones de respuesta para el combate',
        minItems: 4,
        maxItems: 4,
        items: {
          type: 'object',
          properties: {
            texto: {
              type: 'string',
              description: 'Texto de la opción de respuesta (3 a 200 caracteres)',
            },
            calidad: {
              type: 'integer',
              enum: [0, 1, 2],
              description: 'Calidad: 2 = óptima (crítico), 1 = parcial/subóptima (acierto), 0 = incorrecta (contraataque)',
            },
            explicacion: {
              type: 'string',
              description: 'Explicación pedagógica de por qué tiene esa calidad (10 a 300 caracteres)',
            },
          },
          required: ['texto', 'calidad', 'explicacion'],
        },
      },
    },
    required: [
      'numero',
      'tipo_encuentro',
      'enemigo',
      'vida_enemigo',
      'concepto',
      'pregunta',
      'codigo',
      'opciones',
    ],
  },
};

export const MEGA_JSON_SCHEMA = {
  type: 'object',
  properties: {
    quest: QUEST_JSON_SCHEMA,
    pool_narrativo: POOL_NARRATIVO_SCHEMA,
    preguntas_extra: PREGUNTAS_EXTRA_SCHEMA,
  },
  required: ['quest', 'pool_narrativo', 'preguntas_extra'],
};

export const RUN_SIN_POOL_SCHEMA = {
  type: 'object',
  properties: {
    quest: QUEST_JSON_SCHEMA,
    preguntas_extra: PREGUNTAS_EXTRA_SCHEMA,
  },
  required: ['quest', 'preguntas_extra'],
};

export const ENCUENTROS_EXTRA_SCHEMA = {
  type: 'object',
  properties: {
    encuentros: {
      type: 'array',
      description: 'Exactamente 3 preguntas pedagógicas extra numeradas consecutivamente',
      minItems: 3,
      maxItems: 3,
      items: PREGUNTAS_EXTRA_SCHEMA.items,
    }
  },
  required: ['encuentros']
};
