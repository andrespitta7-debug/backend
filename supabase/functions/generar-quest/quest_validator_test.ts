import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { validarQuestJson } from '../_shared/quest_validator.ts';

const questBalanceada = {
  titulo: 'Quest Balanceada',
  descripcion: 'Descripcion valida de la quest',
  encuentros: [
    {
      numero: 1,
      tipo_encuentro: 'normal',
      enemigo: 'Bug Uno',
      pregunta: '¿Pregunta 1?',
      codigo: null,
      opciones: [
        { texto: 'Opcion A valida y balanceada', calidad: 2, explicacion: 'Explicacion de calidad 2 valida' },
        { texto: 'Opcion B valida y balanceada', calidad: 1, explicacion: 'Explicacion de calidad 1 valida' },
        { texto: 'Opcion C valida y balanceada', calidad: 0, explicacion: 'Explicacion de calidad 0 valida' },
        { texto: 'Opcion D valida y balanceada', calidad: 1, explicacion: 'Explicacion de calidad 1 valida' },
      ],
    },
    {
      numero: 2,
      tipo_encuentro: 'normal',
      enemigo: 'Bug Dos',
      pregunta: '¿Pregunta 2?',
      codigo: null,
      opciones: [
        { texto: 'Opcion A valida y balanceada', calidad: 2, explicacion: 'Explicacion de calidad 2 valida' },
        { texto: 'Opcion B valida y balanceada', calidad: 1, explicacion: 'Explicacion de calidad 1 valida' },
        { texto: 'Opcion C valida y balanceada', calidad: 0, explicacion: 'Explicacion de calidad 0 valida' },
        { texto: 'Opcion D valida y balanceada', calidad: 1, explicacion: 'Explicacion de calidad 1 valida' },
      ],
    },
    {
      numero: 3,
      tipo_encuentro: 'jefe',
      enemigo: 'Jefe Tres',
      pregunta: '¿Pregunta 3?',
      codigo: null,
      opciones: [
        { texto: 'Opcion A valida y balanceada', calidad: 2, explicacion: 'Explicacion de calidad 2 valida' },
        { texto: 'Opcion B valida y balanceada', calidad: 1, explicacion: 'Explicacion de calidad 1 valida' },
        { texto: 'Opcion C valida y balanceada', calidad: 0, explicacion: 'Explicacion de calidad 0 valida' },
        { texto: 'Opcion D valida y balanceada', calidad: 1, explicacion: 'Explicacion de calidad 1 valida' },
      ],
    },
  ],
};

const questDesbalanceada = {
  ...questBalanceada,
  encuentros: [
    {
      ...questBalanceada.encuentros[0],
      opciones: [
        {
          texto: 'Esta opcion correcta es excesivamente larga en comparacion con las otras tres opciones breves del encuentro para provocar el fallo',
          calidad: 2,
          explicacion: 'Explicacion de calidad 2 valida',
        },
        { texto: 'Opcion corta 1', calidad: 1, explicacion: 'Explicacion de calidad 1 valida' },
        { texto: 'Opcion corta 2', calidad: 0, explicacion: 'Explicacion de calidad 0 valida' },
        { texto: 'Opcion corta 3', calidad: 1, explicacion: 'Explicacion de calidad 1 valida' },
      ],
    },
    questBalanceada.encuentros[1],
    questBalanceada.encuentros[2],
  ],
};

Deno.test('validarQuestJson: quest balanceada es aceptada (V9)', () => {
  const resultado = validarQuestJson(JSON.stringify(questBalanceada), 'debug');
  assertEquals(resultado.valido, true);
});

Deno.test('validarQuestJson: opcion correcta 2x mas larga es rechazada con IA_OPCIONES_DESBALANCEADAS (V9)', () => {
  const resultado = validarQuestJson(JSON.stringify(questDesbalanceada), 'debug');
  assertEquals(resultado.valido, false);
  if (!resultado.valido) {
    assertEquals(resultado.codigo, 'IA_OPCIONES_DESBALANCEADAS');
  }
});
