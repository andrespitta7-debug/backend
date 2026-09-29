// Tests unitarios para las reglas de validación en Deno.
// Ejecutable con `deno test` o `supabase functions test`.

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { validarRegistro } from '../_shared/validation.ts';

const datosValidos = {
  email: 'estudiante@udec.edu.co',
  password: 'Password123',
  nombre: 'Jhony',
  apellido: 'Palacio',
  nombre_usuario: 'jhony_dev',
};

Deno.test('validarRegistro: datos válidos son aceptados y normalizados', () => {
  const resultado = validarRegistro({
    ...datosValidos,
    email: '  ESTUDIANTE@UDEC.EDU.CO  ',
    nombre: '  Jhony  ',
    apellido: '  Palacio  ',
    nombre_usuario: '  jhony_dev  ',
  });

  assertEquals(resultado.valido, true);
  assertEquals(resultado.error, undefined);
  assertEquals(resultado.datos?.email, 'estudiante@udec.edu.co');
  assertEquals(resultado.datos?.nombre, 'Jhony');
  assertEquals(resultado.datos?.apellido, 'Palacio');
  assertEquals(resultado.datos?.nombre_usuario, 'jhony_dev');
  assertEquals(resultado.datos?.password, 'Password123');
});

Deno.test('validarRegistro: email inválido falla', () => {
  const casos = ['', 'invalido', 'sin_arroba.com', 'con espacio@dominio.com', '@sinusuario.com'];
  for (const email of casos) {
    const res = validarRegistro({ ...datosValidos, email });
    assertEquals(res.valido, false);
    assertEquals(res.error, 'El correo electrónico no es válido.');
  }
});

Deno.test('validarRegistro: nombre fuera de rango (2-50) falla', () => {
  const muyCorto = validarRegistro({ ...datosValidos, nombre: 'A' });
  assertEquals(muyCorto.valido, false);
  assertEquals(
    muyCorto.error,
    'El nombre es obligatorio y debe tener entre 2 y 50 caracteres.',
  );

  const muyLargo = validarRegistro({ ...datosValidos, nombre: 'A'.repeat(51) });
  assertEquals(muyLargo.valido, false);
  assertEquals(
    muyLargo.error,
    'El nombre es obligatorio y debe tener entre 2 y 50 caracteres.',
  );
});

Deno.test('validarRegistro: apellido fuera de rango (2-50) falla', () => {
  const muyCorto = validarRegistro({ ...datosValidos, apellido: 'B' });
  assertEquals(muyCorto.valido, false);
  assertEquals(
    muyCorto.error,
    'El apellido es obligatorio y debe tener entre 2 y 50 caracteres.',
  );

  const muyLargo = validarRegistro({ ...datosValidos, apellido: 'B'.repeat(51) });
  assertEquals(muyLargo.valido, false);
  assertEquals(
    muyLargo.error,
    'El apellido es obligatorio y debe tener entre 2 y 50 caracteres.',
  );
});

Deno.test('validarRegistro: nombre_usuario inválido falla', () => {
  // Menos de 3
  const corto = validarRegistro({ ...datosValidos, nombre_usuario: 'ab' });
  assertEquals(corto.valido, false);
  assertEquals(
    corto.error,
    'El nombre de usuario debe tener entre 3 y 20 caracteres y solo puede contener letras, números y guion bajo.',
  );

  // Más de 20
  const largo = validarRegistro({ ...datosValidos, nombre_usuario: 'a'.repeat(21) });
  assertEquals(largo.valido, false);
  assertEquals(
    largo.error,
    'El nombre de usuario debe tener entre 3 y 20 caracteres y solo puede contener letras, números y guion bajo.',
  );

  // Caracteres no permitidos
  const conEspacios = validarRegistro({ ...datosValidos, nombre_usuario: 'user name' });
  assertEquals(conEspacios.valido, false);

  const conGuionMedio = validarRegistro({ ...datosValidos, nombre_usuario: 'user-name' });
  assertEquals(conGuionMedio.valido, false);
});

Deno.test('validarRegistro: password débil falla', () => {
  // Menos de 8 caracteres
  const corto = validarRegistro({ ...datosValidos, password: 'Pass1' });
  assertEquals(corto.valido, false);
  assertEquals(
    corto.error,
    'La contraseña debe tener al menos 8 caracteres, una letra y un número.',
  );

  // Solo letras (sin número)
  const soloLetras = validarRegistro({ ...datosValidos, password: 'PasswordSoloLetras' });
  assertEquals(soloLetras.valido, false);
  assertEquals(
    soloLetras.error,
    'La contraseña debe tener al menos 8 caracteres, una letra y un número.',
  );

  // Solo números (sin letra)
  const soloNumeros = validarRegistro({ ...datosValidos, password: '1234567890' });
  assertEquals(soloNumeros.valido, false);
  assertEquals(
    soloNumeros.error,
    'La contraseña debe tener al menos 8 caracteres, una letra y un número.',
  );
});
