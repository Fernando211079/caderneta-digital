-- Cardeneta Fiado Digital: estrutura do banco (Supabase)
-- Como usar: Supabase > SQL Editor > New query > cole tudo > Run

-- Clientes (o código é gerado automaticamente)
create table if not exists public.clientes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  codigo      integer generated always as identity unique,
  nome        text not null,
  telefone    text,
  trabalho    text,
  created_at  timestamptz not null default now()
);

-- Lista de doces com preço (usada para lançar vendas mais rápido)
create table if not exists public.produtos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome        text not null,
  preco       numeric(10,2) not null check (preco > 0),
  created_at  timestamptz not null default now()
);

-- Vendas fiadas (data e hora automáticas)
create table if not exists public.vendas (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  cliente_id  uuid not null references public.clientes(id) on delete cascade,
  descricao   text,
  valor       numeric(10,2) not null check (valor > 0),
  created_at  timestamptz not null default now()
);

-- Pagamentos recebidos (totais ou parciais)
create table if not exists public.pagamentos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  cliente_id  uuid not null references public.clientes(id) on delete cascade,
  valor       numeric(10,2) not null check (valor > 0),
  created_at  timestamptz not null default now()
);

-- Ajustes: nome do negócio e chave Pix
create table if not exists public.configuracoes (
  user_id       uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  nome_negocio  text,
  chave_pix     text
);

create index if not exists vendas_cliente_idx     on public.vendas(cliente_id);
create index if not exists pagamentos_cliente_idx on public.pagamentos(cliente_id);

-- Cada cliente com o saldo devedor (vendas menos pagamentos)
create or replace view public.clientes_saldo
with (security_invoker = true) as
select
  c.*,
  coalesce((select sum(v.valor) from public.vendas v where v.cliente_id = c.id), 0)
  - coalesce((select sum(p.valor) from public.pagamentos p where p.cliente_id = c.id), 0) as saldo
from public.clientes c;

-- Segurança: cada usuário só enxerga os próprios dados
alter table public.clientes      enable row level security;
alter table public.produtos      enable row level security;
alter table public.vendas        enable row level security;
alter table public.pagamentos    enable row level security;
alter table public.configuracoes enable row level security;

create policy "clientes: só do dono"      on public.clientes      for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "produtos: só do dono"      on public.produtos      for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "vendas: só do dono"        on public.vendas        for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "pagamentos: só do dono"    on public.pagamentos    for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "configuracoes: só do dono" on public.configuracoes for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.clientes, public.produtos, public.vendas, public.pagamentos, public.configuracoes to authenticated;
grant select on public.clientes_saldo to authenticated;
