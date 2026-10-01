// SysQuest — JSON Schema para structured output de Gemini
// Sigue la sección 4 del contrato (docs/SysQuest_Contrato_Quest_IA.md)

export const QUEST_JSON_SCHEMA = {
  type: 'object',
  properties: {
    titulo: {
      type: 'string',
      description: 'Título temático de la quest (5 a 80 caracteres)',
    },
    descripcion: {
      type: 'string',
      description: 'Descripción pedagógica y narrativa de la quest (10 a 300 caracteres)',
    },
    encuentros: {
      type: 'array',
      description: 'Exactamente 3 encuentros pedagógicos ordenados (1, 2 y 3)',
      minItems: 3,
      maxItems: 3,
      items: {
        type: 'object',
        properties: {
          numero: {
            type: 'integer',
            description: 'Número consecutivo del encuentro: 1, 2 o 3',
          },
          tipo_encuentro: {
            type: 'string',
            enum: ['normal', 'jefe'],
            description: 'Tipo de encuentro. Los números 1 y 2 son "normal", el número 3 siempre es "jefe"',
          },
          enemigo: {
            type: 'string',
            description: 'Nombre temático del enemigo (3 a 40 caracteres)',
          },
          pregunta: {
            type: 'string',
            description: 'Pregunta o desafío técnico del encuentro (10 a 400 caracteres)',
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
          'pregunta',
          'codigo',
          'opciones',
        ],
      },
    },
  },
  required: ['titulo', 'descripcion', 'encuentros'],
};
