// Reglas de validación para registro de usuario.
// Idénticas a RegistrarUsuarioUseCase en Flutter (lib/domain/usecases/auth_usecases.dart).

export interface DatosRegistroEntrada {
  email?: unknown;
  password?: unknown;
  nombre?: unknown;
  apellido?: unknown;
  nombre_usuario?: unknown;
}

export interface DatosRegistroNormalizados {
  email: string;
  password: string;
  nombre: string;
  apellido: string;
  nombre_usuario: string;
}

export interface ResultadoValidacion {
  valido: boolean;
  error?: string;
  datos?: DatosRegistroNormalizados;
}

export function validarRegistro(datos: DatosRegistroEntrada): ResultadoValidacion {
  const emailRaw = typeof datos.email === 'string' ? datos.email : '';
  const passwordRaw = typeof datos.password === 'string' ? datos.password : '';
  const nombreRaw = typeof datos.nombre === 'string' ? datos.nombre : '';
  const apellidoRaw = typeof datos.apellido === 'string' ? datos.apellido : '';
  const nombreUsuarioRaw =
    typeof datos.nombre_usuario === 'string' ? datos.nombre_usuario : '';

  const emailNormalizado = emailRaw.trim().toLowerCase();
  const nombreNormalizado = nombreRaw.trim();
  const apellidoNormalizado = apellidoRaw.trim();
  const nombreUsuarioNormalizado = nombreUsuarioRaw.trim();
  const passwordPlano = passwordRaw;

  // 1. Validar email (formato y no vacío)
  const regexEmail = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  if (!regexEmail.test(emailNormalizado)) {
    return {
      valido: false,
      error: 'El correo electrónico no es válido.',
    };
  }

  // 2. Validar nombre (2 a 50 caracteres)
  if (nombreNormalizado.length < 2 || nombreNormalizado.length > 50) {
    return {
      valido: false,
      error: 'El nombre es obligatorio y debe tener entre 2 y 50 caracteres.',
    };
  }

  // 3. Validar apellido (2 a 50 caracteres)
  if (apellidoNormalizado.length < 2 || apellidoNormalizado.length > 50) {
    return {
      valido: false,
      error: 'El apellido es obligatorio y debe tener entre 2 y 50 caracteres.',
    };
  }

  // 4. Validar nombre_usuario (3 a 20 caracteres, letras, números y guión bajo)
  const regexNombreUsuario = /^[A-Za-z0-9_]+$/;
  if (
    nombreUsuarioNormalizado.length < 3 ||
    nombreUsuarioNormalizado.length > 20 ||
    !regexNombreUsuario.test(nombreUsuarioNormalizado)
  ) {
    return {
      valido: false,
      error:
        'El nombre de usuario debe tener entre 3 y 20 caracteres y solo puede contener letras, números y guion bajo.',
    };
  }

  // 5. Validar password (mínimo 8 caracteres, al menos una letra y un número)
  const tieneLetra = /[A-Za-z]/.test(passwordPlano);
  const tieneNumero = /[0-9]/.test(passwordPlano);
  if (passwordPlano.length < 8 || !tieneLetra || !tieneNumero) {
    return {
      valido: false,
      error:
        'La contraseña debe tener al menos 8 caracteres, una letra y un número.',
    };
  }

  return {
    valido: true,
    datos: {
      email: emailNormalizado,
      password: passwordPlano,
      nombre: nombreNormalizado,
      apellido: apellidoNormalizado,
      nombre_usuario: nombreUsuarioNormalizado,
    },
  };
}
