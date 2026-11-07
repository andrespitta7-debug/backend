// SysQuest — Tests unitarios para el validador de run extendida (run_validator.ts)

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import {
  validarPoolNarrativo,
  validarPreguntasExtra,
  validarRunCompleta,
  PoolNarrativoIa,
} from '../_shared/run_validator.ts';

function generarPoolValido(): PoolNarrativoIa {
  return {
    intro: [
      'Entras al compilador donde sombras de errores acechan en la oscuridad.',
      'El sistema se inicializa mientras los registros se cargan con tensión.',
      'Cruzas las compuertas del kernel con tu código listo para la batalla.',
    ],
    entre_combates: [
      'Derrotas al proceso hostil y avanzas hacia el siguiente bloque.',
      'El hilo de ejecución se estabiliza tras superar la anomalía.',
      'Recuperas el control de los punteros y continúas tu camino.',
    ],
    jefe_avistado: [
      'Una presencia colosal satura los registros de la CPU frente a ti.',
      'El proceso maestro emerge desbordando la pila de llamadas del sistema.',
      'Las alarmas del kernel resuenan ante la llegada del guardián supremo.',
    ],
    ronda_completada: [
      'Completas la ronda con éxito limpiando todos los sectores infectados.',
      'Los tres desafíos caen resueltos y el sistema entra en modo seguro.',
      'La memoria queda liberada y una nueva fase de pruebas se desbloquea.',
    ],
    retirada: [
      'Decides abortar la misión de forma controlada guardando tu progreso.',
      'Envías una señal de interrupción limpia y te retiras con dignidad.',
      'Cierras los descriptores de archivo y aseguras tus datos obtenidos.',
    ],
    muerte: [
      'El flujo de control colapsa y el sistema se apaga en silencio.',
      'Un kernel panic irreversible termina con tu intento actual.',
      'La memoria se desborda y el entorno se congela irremediablemente.',
    ],
    critico: [
      '¡Tu algoritmo optimizado asesta un golpe devastador al enemigo!',
      '¡Encuentras el fallo exacto provocando un colapso en su estructura!',
      '¡Una instrucción precisa destruye la defensa del proceso rival!',
    ],
    contraataque: [
      'El enemigo detecta tu vacilación y te castiga con una excepción.',
      'Tu intento fallido desencadena una trampa de interrupción hostil.',
      'El proceso rival aprovecha tu error y reduce tu energía vital.',
    ],
  };
}

function generarPreguntasExtraValidas(): unknown[] {
  const preguntas: unknown[] = [];
  for (let i = 4; i <= 12; i++) {
    preguntas.push({
      numero: i,
      tipo_encuentro: 'normal',
      enemigo: `Bug del Sistema #${i}`,
      pregunta: `¿Cuál es el comportamiento esperado en el módulo #${i}?`,
      codigo: null,
      opciones: [
        {
          texto: 'Comportamiento óptimo y canónico del módulo',
          calidad: 2,
          explicacion: 'Es la solución estándar y óptima para esta situación.',
        },
        {
          texto: 'Comportamiento subóptimo que mitiga temporalmente',
          calidad: 1,
          explicacion: 'Es un parche que funciona pero no resuelve la causa.',
        },
        {
          texto: 'Comportamiento erróneo que causa fuga de memoria',
          calidad: 0,
          explicacion: 'Es incorrecto y genera inestabilidad en el sistema.',
        },
        {
          texto: 'Comportamiento alternativo que consume más CPU',
          calidad: 1,
          explicacion: 'Funciona pero tiene un costo de rendimiento alto.',
        },
      ],
    });
  }
  return preguntas;
}

function generarQuestValida(): unknown {
  return {
    titulo: 'Quest de Prueba Algorítmica',
    descripcion: 'Una prueba completa de estructuras de datos y algoritmos en el kernel.',
    encuentros: [
      {
        numero: 1,
        tipo_encuentro: 'normal',
        enemigo: 'Puntero Nulo',
        pregunta: '¿Qué ocurre al desreferenciar un puntero que apunta a NULL en C?',
        codigo: null,
        opciones: [
          {
            texto: 'Se produce un fallo de segmentación por acceso inválido',
            calidad: 2,
            explicacion: 'El SO impide acceder a direcciones no mapeadas.',
          },
          {
            texto: 'El valor se inicializa en cero de manera silenciosa',
            calidad: 0,
            explicacion: 'Falso, ningún sistema seguro permite esto.',
          },
          {
            texto: 'Se genera una advertencia en tiempo de compilación',
            calidad: 1,
            explicacion: 'Solo algunos analizadores estáticos pueden alertarlo.',
          },
          {
            texto: 'El programa ignora la instrucción y continúa',
            calidad: 0,
            explicacion: 'No se puede continuar con una dirección inválida.',
          },
        ],
      },
      {
        numero: 2,
        tipo_encuentro: 'normal',
        enemigo: 'Bucle Infinito',
        pregunta: '¿Cuál es la causa más común de una condición de parada no alcanzada?',
        codigo: null,
        opciones: [
          {
            texto: 'La variable de control nunca actualiza su valor hacia el límite',
            calidad: 2,
            explicacion: 'Si el estado no cambia hacia el caso base, no terminará.',
          },
          {
            texto: 'El procesador no tiene suficientes núcleos para iterar',
            calidad: 0,
            explicacion: 'Los núcleos no afectan la lógica de iteración de un bucle.',
          },
          {
            texto: 'Falta un sleep dentro del bloque para dar respiro a la CPU',
            calidad: 0,
            explicacion: 'Un sleep solo ralentiza el bucle, no lo finaliza.',
          },
          {
            texto: 'Se usó un while en lugar de una recursión bien formada',
            calidad: 1,
            explicacion: 'El tipo de estructura no evita el error de condición.',
          },
        ],
      },
      {
        numero: 3,
        tipo_encuentro: 'jefe',
        enemigo: 'Dragón del Desbordamiento',
        pregunta: '¿Cómo se previene un desbordamiento de búfer en memoria dinámica?',
        codigo: null,
        opciones: [
          {
            texto: 'Validando estrictamente los límites antes de escribir datos',
            calidad: 2,
            explicacion: 'El chequeo de límites previene accesos fuera de rango.',
          },
          {
            texto: 'Aumentando la memoria RAM física en el servidor',
            calidad: 0,
            explicacion: 'Más RAM no previene accesos fuera del tamaño reservado.',
          },
          {
            texto: 'Utilizando llamadas de bajo nivel sin librerías seguras',
            calidad: 0,
            explicacion: 'Las funciones inseguras son la causa principal.',
          },
          {
            texto: 'Compilando con flags de optimización agresiva en release',
            calidad: 1,
            explicacion: 'Puede mitigar algunos casos pero no soluciona el código.',
          },
        ],
      },
    ],
  };
}

Deno.test('Pool narrativo con faltantes → rechazado (IA_POOL_INVALIDO)', () => {
  const pool = generarPoolValido();
  // deno-lint-ignore no-explicit-any
  delete (pool as any).contraataque;

  const resultado = validarPoolNarrativo(pool);
  assertEquals(resultado.valido, false);
  if (!resultado.valido) {
    assertEquals(resultado.codigo, 'IA_POOL_INVALIDO');
  }
});

Deno.test('Pool narrativo con 3 variantes en una categoría → rechazado (IA_POOL_INVALIDO)', () => {
  const pool = generarPoolValido();
  pool.intro.pop(); // Solo 3 variantes

  const resultado = validarPoolNarrativo(pool);
  assertEquals(resultado.valido, false);
  if (!resultado.valido) {
    assertEquals(resultado.codigo, 'IA_POOL_INVALIDO');
  }
});

Deno.test('Preguntas extra con 8 en vez de 9 → rechazadas (IA_PREGUNTAS_INVALIDAS)', () => {
  const preguntas = generarPreguntasExtraValidas();
  preguntas.pop(); // 8 preguntas

  const resultado = validarPreguntasExtra(preguntas, 'algorithm');
  assertEquals(resultado.valido, false);
  if (!resultado.valido) {
    assertEquals(resultado.codigo, 'IA_PREGUNTAS_INVALIDAS');
  }
});

Deno.test('Preguntas extra con números erróneos (1..9 en vez de 4..12) → rechazadas', () => {
  const preguntas = generarPreguntasExtraValidas();
  // deno-lint-ignore no-explicit-any
  (preguntas[0] as any).numero = 1;

  const resultado = validarPreguntasExtra(preguntas, 'algorithm');
  assertEquals(resultado.valido, false);
  if (!resultado.valido) {
    assertEquals(resultado.codigo, 'IA_PREGUNTAS_INVALIDAS');
  }
});

Deno.test('Todo válido → aceptado', () => {
  const megaJson = {
    quest: generarQuestValida(),
    pool_narrativo: generarPoolValido(),
    preguntas_extra: generarPreguntasExtraValidas(),
  };

  const resultado = validarRunCompleta(JSON.stringify(megaJson), 'algorithm', true);
  assertEquals(resultado.valido, true);
  if (resultado.valido) {
    assertEquals(resultado.run.quest.encuentros.length, 3);
    assertEquals(resultado.run.preguntas_extra.length, 9);
    assertEquals(resultado.run.pool_narrativo?.intro.length, 3);
  }
});

Deno.test('Todo válido en modo caché (sin pool_narrativo en JSON) → aceptado', () => {
  const runSinPool = {
    quest: generarQuestValida(),
    preguntas_extra: generarPreguntasExtraValidas(),
  };

  const resultado = validarRunCompleta(JSON.stringify(runSinPool), 'algorithm', false);
  assertEquals(resultado.valido, true);
  if (resultado.valido) {
    assertEquals(resultado.run.quest.encuentros.length, 3);
    assertEquals(resultado.run.preguntas_extra.length, 9);
    assertEquals(resultado.run.pool_narrativo, undefined);
  }
});

Deno.test('Formato académico desacoplado (quest_title, resolved_topic, 8 questions) → aceptado', () => {
  const academicJson = {
    quest_title: 'La Cripta de la Alquimia Culinaria',
    resolved_topic: 'Gastronomía: Pastas',
    questions: [
      {
        pregunta: '¿Qué tipo de harina se utiliza tradicionalmente para la pasta seca?',
        opciones: ['Sémola de trigo duro', 'Harina de maíz', 'Harina de arroz', 'Fécula de papa'],
        correct_index: 0,
        semantic_hint: 'Es un derivado del trigo conocido por su textura granulada y alto gluten.',
      },
      {
        pregunta: '¿Cuál es el término italiano para la pasta cocida al dente?',
        opciones: ['Al dente', 'Molto cotto', 'Crudo', 'Stufato'],
        correct_index: 0,
        semantic_hint: 'Describe que la pasta ofrece una ligera resistencia al morderla.',
      },
      {
        pregunta: '¿Qué ingrediente tradicional emulsiona la salsa carbonara original?',
        opciones: ['Yema de huevo y queso pecorino', 'Crema de leche espesa', 'Mantequilla y harina', 'Aceite de oliva y ajo'],
        correct_index: 0,
        semantic_hint: 'Se utiliza el calor residual de la pasta para cocinarlo sin cuajarlo.',
      },
      {
        pregunta: '¿De qué región de Italia es originaria la pasta pesto genovese?',
        opciones: ['Liguria', 'Sicilia', 'Lombardía', 'Toscana'],
        correct_index: 0,
        semantic_hint: 'Es una región costera del noroeste italiano famosa por la albahaca.',
      },
      {
        pregunta: '¿Cuál es la función principal de la sal gruesa en el agua de cocción?',
        opciones: ['Sazonar la masa desde su interior', 'Hacer que el agua hierva a menor temperatura', 'Evitar que la pasta se pegue a la olla', 'Conservar el color original de la pasta'],
        correct_index: 0,
        semantic_hint: 'Permite que el sabor penetre directamente en el almidón hidratado.',
      },
      {
        pregunta: '¿Qué forma tiene la pasta denominada orecchiette?',
        opciones: ['Pequeñas orejas', 'Cilindros estriados', 'Lazos o mariposas', 'Espirales finas'],
        correct_index: 0,
        semantic_hint: 'Su nombre en italiano hace referencia a una parte anatómica auditiva.',
      },
      {
        pregunta: '¿Qué salsa clásica italiana lleva guanciale, tomate y pecorino?',
        opciones: ['Amatriciana', 'Boloñesa', 'Alfredo', 'Arrabbiata'],
        correct_index: 0,
        semantic_hint: 'Es originaria de la ciudad de Amatrice en la región del Lacio.',
      },
      {
        pregunta: '¿Por qué se debe reservar un poco de agua de cocción antes de colar la pasta?',
        opciones: ['Para emulsionar salsas gracias a su almidón', 'Para enfriar rápidamente la pasta cocida', 'Para enjuagar el exceso de gluten', 'Para agregar volumen líquido a la salsa'],
        correct_index: 0,
        semantic_hint: 'El agua caliente contiene almidones disueltos que ligan grasa y líquido.',
      },
    ],
  };

  const resultado = validarRunCompleta(JSON.stringify(academicJson), 'libre', false);
  assertEquals(resultado.valido, true);
  if (resultado.valido) {
    assertEquals(resultado.run.quest_title, 'La Cripta de la Alquimia Culinaria');
    assertEquals(resultado.run.resolved_topic, 'Gastronomía: Pastas');
    assertEquals(resultado.run.quest.encuentros.length, 3);
    assertEquals(resultado.run.preguntas_extra.length, 5);
    assertEquals(resultado.run.quest.encuentros[0].semantic_hint, 'Es un derivado del trigo conocido por su textura granulada y alto gluten.');
    assertEquals(resultado.run.quest.encuentros[2].tipo_encuentro, 'jefe');
    assertEquals(resultado.run.quest.encuentros[2].vida_enemigo, 100);
  }
});
