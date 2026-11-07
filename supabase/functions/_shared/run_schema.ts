// SysQuest — Schemas JSON para run extendida (quest + pool narrativo + preguntas extra)
// Utilizado para structured output de proveedores de IA (Groq, Gemini, etc.)

import { QUEST_JSON_SCHEMA } from './quest_schema.ts';

export { QUEST_JSON_SCHEMA };

/**
 * Esquema desacoplado académico:
 * Groq SOLO genera quest_title, resolved_topic y entre 5 y 12 preguntas directas y rigurosas.
 * La narrativa de mazmorra se genera localmente en Flutter.
 */
export const ACADEMIC_QUEST_SCHEMA = {
  type: 'object',
  properties: {
    quest_title: {
      type: 'string',
      minLength: 3,
      maxLength: 80,
      description: 'Título épico que combina una mazmorra con el tema (3 a 80 caracteres)',
    },
    resolved_topic: {
      type: 'string',
      minLength: 3,
      maxLength: 80,
      description: 'Tema limpio y normalizado en 2 a 5 palabras',
    },
    questions: {
      type: 'array',
      description: 'Lista de preguntas educativas rigurosas y progresivas (entre 5 y 12 preguntas, idealmente 9)',
      minItems: 5,
      maxItems: 12,
      items: {
        type: 'object',
        properties: {
          pregunta: {
            type: 'string',
            minLength: 5,
            maxLength: 150,
            description: 'Enunciado directo al concepto educativo, sin relleno ni fantasía (máx. 150 caracteres)',
          },
          opciones: {
            type: 'array',
            description: 'Exactamente 4 opciones cortas de respuesta',
            minItems: 4,
            maxItems: 4,
            items: {
              type: 'string',
              minLength: 1,
              maxLength: 55,
              description: 'Opción corta de respuesta (máx. 55 caracteres)',
            },
          },
          correct_index: {
            type: 'integer',
            minimum: 0,
            maximum: 3,
            description: 'Índice de la opción correcta (0 a 3)',
          },
          semantic_hint: {
            type: 'string',
            minLength: 3,
            maxLength: 110,
            description: 'Pista conceptual orientadora sin regalar la respuesta ni hablar de cantidad de letras (máx. 110 caracteres)',
          },
        },
        required: ['pregunta', 'opciones', 'correct_index', 'semantic_hint'],
      },
    },
  },
  required: ['quest_title', 'resolved_topic', 'questions'],
};

export const POOL_NARRATIVO_SCHEMA = {
  type: 'object',
  properties: {
    intro: {
      type: 'array',
      description: 'Variantes de apertura de la run (opcional)',
      items: { type: 'string' },
    },
    entre_combates: {
      type: 'array',
      description: 'Variantes de avance entre combates (opcional)',
      items: { type: 'string' },
    },
    jefe_avistado: {
      type: 'array',
      description: 'Variantes de avistamiento del jefe (opcional)',
      items: { type: 'string' },
    },
    ronda_completada: {
      type: 'array',
      description: 'Variantes de triunfo de ronda (opcional)',
      items: { type: 'string' },
    },
    retirada: {
      type: 'array',
      description: 'Variantes de retirada (opcional)',
      items: { type: 'string' },
    },
    muerte: {
      type: 'array',
      description: 'Variantes de derrota (opcional)',
      items: { type: 'string' },
    },
    critico: {
      type: 'array',
      description: 'Variantes de golpe crítico (opcional)',
      items: { type: 'string' },
    },
    contraataque: {
      type: 'array',
      description: 'Variantes de contraataque (opcional)',
      items: { type: 'string' },
    },
  },
  required: [],
};

export const PREGUNTAS_EXTRA_SCHEMA = {
  type: 'array',
  description: 'Preguntas pedagógicas extra numeradas consecutivamente',
  minItems: 2,
  maxItems: 12,
  items: {
    type: 'object',
    properties: {
      numero: {
        type: 'integer',
        description: 'Número consecutivo del encuentro extra',
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
      semantic_hint: {
        type: 'string',
        maxLength: 150,
        description: 'Una pista conceptual que ayude a resolver la pregunta sin revelar la respuesta exacta.',
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

export const MEGA_JSON_SCHEMA = ACADEMIC_QUEST_SCHEMA;
export const RUN_SIN_POOL_SCHEMA = ACADEMIC_QUEST_SCHEMA;

export const ENCUENTROS_EXTRA_SCHEMA = {
  type: 'object',
  properties: {
    encuentros: {
      type: 'array',
      description: 'Exactamente 3 preguntas pedagógicas extra numeradas consecutivamente',
      minItems: 3,
      maxItems: 3,
      items: PREGUNTAS_EXTRA_SCHEMA.items,
    },
  },
  required: ['encuentros'],
};
