-- CTP · Plataforma de gestión — esquema inicial para Supabase (Postgres)
-- Correr en Supabase > SQL Editor. Después correr seed.sql para cargar los datos ficticios.

create extension if not exists pgcrypto;

-- ---------- Catálogos ----------
create table areas (
  id text primary key,                 -- to, fono, psico, psicoped, apoyo, arte, taller
  nombre text not null,
  corto text not null
);

create table obras_sociales (
  id serial primary key,
  nombre text not null unique,
  descripcion text,
  cobertura_sesion numeric(12,2) not null default 0   -- lo que paga la obra social por sesión
);

-- ---------- Personas ----------
create type rol_usuario as enum ('direccion','recepcion','profesional','familia');

create table profesionales (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,          -- pr1, pr2… (para el prototipo)
  nombre text not null,
  area_id text not null references areas(id),
  consultorio smallint,
  porcentaje numeric(4,3) not null,     -- 0.650 = 65 %
  adicional numeric(12,2) not null default 0,
  matricula text,
  matricula_vence date
);

create table perfiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  rol rol_usuario not null,
  nombre text not null,
  profesional_id uuid references profesionales(id)
);

create table pacientes (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,          -- p01, p02…
  nombre text not null,
  edad smallint,
  obra_social_id int references obras_sociales(id),
  tutor_nombre text,
  origen text,                          -- boca en boca, pediatra, escuela, derivación interna…
  copago_sesion numeric(12,2) not null default 0,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create table paciente_areas (
  paciente_id uuid references pacientes(id) on delete cascade,
  area_id text references areas(id),
  profesional_id uuid references profesionales(id),
  sesiones_semana smallint not null default 1,
  primary key (paciente_id, area_id)
);

create table familia_pacientes (       -- qué usuario de familia ve a qué paciente
  user_id uuid references auth.users(id) on delete cascade,
  paciente_id uuid references pacientes(id) on delete cascade,
  primary key (user_id, paciente_id)
);

-- ---------- Agenda ----------
create type estado_turno as enum ('pendiente','presente','ausente');

create table lista_espera (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  area_id text references areas(id),
  obra_social_id int references obras_sociales(id),
  prioridad text default 'Normal',
  ingreso date not null default current_date,
  asignado boolean not null default false
);

create table turnos (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid references pacientes(id) on delete cascade,
  lista_espera_id uuid references lista_espera(id),
  profesional_id uuid not null references profesionales(id),
  area_id text not null references areas(id),
  inicio timestamptz not null,
  duracion_min smallint not null default 45,
  consultorio smallint not null,
  estado estado_turno not null default 'pendiente',
  unique (consultorio, inicio),
  unique (profesional_id, inicio)
);

-- ---------- Clínica ----------
create type semaforo as enum ('bien','regular','dificil');

create table objetivos (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid not null references pacientes(id) on delete cascade,
  area_id text not null references areas(id),
  descripcion text not null
);

create table objetivo_mediciones (       -- escala GAS mensual
  objetivo_id uuid references objetivos(id) on delete cascade,
  mes date not null,
  valor smallint not null check (valor between -2 and 2),
  primary key (objetivo_id, mes)
);

create table notas_sesion (
  id uuid primary key default gen_random_uuid(),
  turno_id uuid references turnos(id),
  paciente_id uuid not null references pacientes(id) on delete cascade,
  profesional_id uuid not null references profesionales(id),
  area_id text not null references areas(id),
  participacion semaforo,
  regulacion semaforo,
  compromiso_familiar semaforo,
  texto text,
  creado_en timestamptz not null default now()
);

create table mensajes (                  -- comunicación interna del equipo (la familia no la ve)
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid not null references pacientes(id) on delete cascade,
  autor_nombre text not null,
  autor_id uuid references auth.users(id),
  texto text not null,
  creado_en timestamptz not null default now()
);

-- ---------- Documentos, firmas y plata ----------
create table documentos (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid not null references pacientes(id) on delete cascade,
  tipo text not null,                    -- CUD, autorización, prescripción, consentimiento
  vence date,
  archivo_path text,                     -- ruta en Supabase Storage
  renovacion_pedida boolean not null default false
);

create type tipo_firma as enum ('planilla_familia','planilla_profesional','informe_profesional');

create table firmas (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid not null references pacientes(id) on delete cascade,
  periodo date not null,                 -- primer día del mes presentado
  tipo tipo_firma not null,
  firmado_por uuid references auth.users(id),
  firmado_en timestamptz not null default now(),
  metodo text not null default 'electronica_otp',
  evidencia jsonb,                       -- ip, dispositivo, hash del documento
  unique (paciente_id, periodo, tipo)
);

create type estado_pago as enum ('pendiente','pagado','vencido');

create table pagos (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid not null references pacientes(id) on delete cascade,
  periodo date not null,
  monto numeric(12,2) not null,
  estado estado_pago not null default 'pendiente',
  unique (paciente_id, periodo)
);

create table liquidaciones (
  id uuid primary key default gen_random_uuid(),
  profesional_id uuid not null references profesionales(id),
  periodo date not null,
  sesiones int not null,
  monto numeric(12,2) not null,
  estado text not null default 'pendiente',
  unique (profesional_id, periodo)
);

-- ---------- Permisos (Row Level Security) ----------
create or replace function mi_rol() returns rol_usuario language sql stable security definer set search_path = public as
  $$ select rol from perfiles where user_id = auth.uid() $$;
create or replace function mi_profesional() returns uuid language sql stable security definer set search_path = public as
  $$ select profesional_id from perfiles where user_id = auth.uid() $$;
create or replace function veo_paciente(p uuid) returns boolean language sql stable security definer set search_path = public as $$
  select case mi_rol()
    when 'direccion' then true
    when 'recepcion' then true
    when 'profesional' then exists (select 1 from paciente_areas pa where pa.paciente_id = p and pa.profesional_id = mi_profesional())
    when 'familia' then exists (select 1 from familia_pacientes f where f.paciente_id = p and f.user_id = auth.uid())
    else false end $$;

alter table areas enable row level security;
alter table obras_sociales enable row level security;
alter table profesionales enable row level security;
alter table perfiles enable row level security;
alter table pacientes enable row level security;
alter table paciente_areas enable row level security;
alter table familia_pacientes enable row level security;
alter table lista_espera enable row level security;
alter table turnos enable row level security;
alter table objetivos enable row level security;
alter table objetivo_mediciones enable row level security;
alter table notas_sesion enable row level security;
alter table mensajes enable row level security;
alter table documentos enable row level security;
alter table firmas enable row level security;
alter table pagos enable row level security;
alter table liquidaciones enable row level security;

-- Catálogos: cualquier usuario logueado los lee
create policy cat_areas on areas for select to authenticated using (true);
create policy cat_os on obras_sociales for select to authenticated using (true);
create policy cat_prof on profesionales for select to authenticated using (true);
create policy perfil_propio on perfiles for select to authenticated using (user_id = auth.uid() or mi_rol() = 'direccion');

-- Datos de pacientes: cada rol ve lo suyo
create policy pac_ver on pacientes for select to authenticated using (veo_paciente(id));
create policy pa_ver on paciente_areas for select to authenticated using (veo_paciente(paciente_id));
create policy fam_ver on familia_pacientes for select to authenticated using (user_id = auth.uid() or mi_rol() in ('direccion','recepcion'));
create policy tur_ver on turnos for select to authenticated using (paciente_id is null and mi_rol() in ('direccion','recepcion') or veo_paciente(paciente_id));
create policy obj_ver on objetivos for select to authenticated using (veo_paciente(paciente_id));
create policy med_ver on objetivo_mediciones for select to authenticated using (exists (select 1 from objetivos o where o.id = objetivo_id and veo_paciente(o.paciente_id)));
create policy doc_ver on documentos for select to authenticated using (veo_paciente(paciente_id));
create policy fir_ver on firmas for select to authenticated using (veo_paciente(paciente_id));
create policy pag_ver on pagos for select to authenticated using (veo_paciente(paciente_id));
-- Notas clínicas y mensajes internos: solo el equipo, nunca la familia
create policy not_ver on notas_sesion for select to authenticated using (mi_rol() <> 'familia' and veo_paciente(paciente_id));
create policy msg_ver on mensajes for select to authenticated using (mi_rol() <> 'familia' and veo_paciente(paciente_id));

-- Escritura
create policy adm_todo_pac on pacientes for all to authenticated using (mi_rol() in ('direccion','recepcion')) with check (mi_rol() in ('direccion','recepcion'));
create policy adm_todo_tur on turnos for all to authenticated using (mi_rol() in ('direccion','recepcion')) with check (mi_rol() in ('direccion','recepcion'));
create policy prof_tur_estado on turnos for update to authenticated using (profesional_id = mi_profesional()) with check (profesional_id = mi_profesional());
create policy adm_todo_esp on lista_espera for all to authenticated using (mi_rol() in ('direccion','recepcion')) with check (mi_rol() in ('direccion','recepcion'));
create policy adm_todo_doc on documentos for all to authenticated using (mi_rol() in ('direccion','recepcion')) with check (mi_rol() in ('direccion','recepcion'));
create policy adm_todo_pag on pagos for all to authenticated using (mi_rol() in ('direccion','recepcion')) with check (mi_rol() in ('direccion','recepcion'));
create policy dir_liq on liquidaciones for all to authenticated using (mi_rol() = 'direccion') with check (mi_rol() = 'direccion');
create policy prof_liq_ver on liquidaciones for select to authenticated using (profesional_id = mi_profesional());
create policy prof_nota on notas_sesion for insert to authenticated with check (profesional_id = mi_profesional() and veo_paciente(paciente_id));
create policy prof_med on objetivo_mediciones for insert to authenticated with check (mi_rol() = 'profesional');
create policy equipo_msg on mensajes for insert to authenticated with check (mi_rol() <> 'familia' and veo_paciente(paciente_id));
create policy firma_fam on firmas for insert to authenticated with check (tipo = 'planilla_familia' and mi_rol() = 'familia' and veo_paciente(paciente_id) and firmado_por = auth.uid());
create policy firma_prof on firmas for insert to authenticated with check (tipo <> 'planilla_familia' and mi_rol() = 'profesional' and veo_paciente(paciente_id) and firmado_por = auth.uid());
