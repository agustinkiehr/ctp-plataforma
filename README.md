# CTP · Plataforma de gestión (prototipo interno)

Prototipo navegable de la plataforma para CTP Consultorio Terapéutico Psicofísico, cliente de sobrinos.
**Todos los datos son ficticios** (Paciente 01 a 72, Profesional 1 a 8).

## Cuentas de prueba

La contraseña de todas es `ctp2026`. No hay seguridad real: es un prototipo.

| Rol | Email | Qué ve |
| --- | --- | --- |
| Administración | `admin1@ctp.prueba`, `admin2@ctp.prueba` | Todo el centro, incluido Equipo, donde se crean más usuarios de prueba |
| Profesional | `profesional1@ctp.prueba` a `profesional8@ctp.prueba` | Solo sus turnos, sus pacientes, sus notas e informes |

Los usuarios que se crean desde la pantalla Equipo quedan guardados solo en el navegador donde se crearon.

## Qué hay en esta carpeta

| Archivo | Para qué sirve |
| --- | --- |
| `index.html` | El prototipo completo en un solo archivo. Funciona en cualquier navegador y en cualquier hosting estático. |
| `supabase/schema.sql` | Las tablas de la base de datos real, con permisos por rol (dirección, recepción, profesional, familia). |
| `supabase/seed.sql` | Los mismos datos ficticios del prototipo, para cargar en la base. |

## Paso 1 · Publicar el prototipo (unos 10 minutos)

1. Creá una cuenta en **GitHub** y un repositorio nuevo, privado, llamado `ctp-plataforma`.
2. En el repositorio, tocá **Add file → Upload files**, arrastrá todo el contenido de esta carpeta y confirmá con **Commit changes**.
3. Creá una cuenta en **Vercel** entrando con tu usuario de GitHub.
4. En Vercel, tocá **Add New → Project**, elegí el repositorio `ctp-plataforma` y tocá **Deploy**. No hace falta cambiar ninguna opción.
5. Vercel te da una dirección del tipo `ctp-plataforma.vercel.app`. Esa es la que comparten con el equipo.

Cada vez que se suba un cambio al repositorio, Vercel publica la versión nueva sola. Los archivos de `supabase/` y este README no se publican en la web (ver `.vercelignore`).

> La página no está indexada en buscadores, pero cualquiera que tenga la dirección puede abrirla. Por eso, mientras sea con datos ficticios, no hay problema. Antes de cargar datos reales tiene que tener usuarios y contraseña (paso 3).

## Paso 2 · Crear la base de datos (unos 10 minutos)

1. Creá una cuenta en **Supabase** y un proyecto nuevo llamado `ctp`, en la región **South America (São Paulo)**. Guardá la contraseña de la base en un lugar seguro.
2. Entrá a **SQL Editor**, pegá el contenido de `supabase/schema.sql` y tocá **Run**.
3. En una consulta nueva, pegá `supabase/seed.sql` y tocá **Run**.
4. En **Table Editor** ya deberías ver los 72 pacientes, los 138 turnos de la semana y el resto de las tablas.

## Paso 3 · Conectar la app a la base (lo hacemos juntos)

Cuando los pasos 1 y 2 estén listos:

- Conectá GitHub a Claude, para poder subir el código.
- Pasá la **URL del proyecto** y la clave **anon/public** de Supabase (están en *Project Settings → API*). Esa clave es pública por diseño y la protegen los permisos por rol del esquema. **La clave `service_role` no se comparte nunca.**

Con eso se reemplaza el prototipo por la app real: login por rol, datos guardados en la base y todo lo que se hace en una pantalla visible para el resto del equipo.
