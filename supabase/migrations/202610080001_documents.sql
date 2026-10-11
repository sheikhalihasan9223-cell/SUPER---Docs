create table public.documents (
  owner_id uuid not null references auth.users(id) on delete cascade,
  id text not null check (id ~ '^[A-Za-z0-9_-]{1,128}$'),
  name text not null check (length(name) between 1 and 255),
  object_path text not null,
  size_bytes bigint not null check (size_bytes between 0 and 52428800),
  tool text not null check (length(tool) <= 100),
  favorite boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (owner_id, id),
  check (object_path = owner_id::text || '/' || id)
);
alter table public.documents enable row level security;
grant select, insert, update, delete on public.documents to authenticated;
revoke all on public.documents from anon;
create policy "Read own documents" on public.documents for select to authenticated using ((select auth.uid()) = owner_id);
create policy "Insert own documents" on public.documents for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "Update own documents" on public.documents for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "Delete own documents" on public.documents for delete to authenticated using ((select auth.uid()) = owner_id);
create index documents_owner_created on public.documents(owner_id, created_at desc);

insert into storage.buckets (id, name, public, file_size_limit)
values ('documents', 'documents', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;
create policy "Read own document objects" on storage.objects for select to authenticated
using (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Upload own document objects" on storage.objects for insert to authenticated
with check (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Update own document objects" on storage.objects for update to authenticated
using (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Delete own document objects" on storage.objects for delete to authenticated
using (bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Atomic per-user daily request budget; no document contents are logged.
create table public.processing_usage (
  owner_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  requests integer not null,
  primary key (owner_id, day)
);
alter table public.processing_usage enable row level security;
revoke all on public.processing_usage from anon, authenticated;
create function public.claim_processing_request() returns boolean
language plpgsql security definer set search_path = '' as $$
declare used integer;
begin
  if auth.uid() is null then return false; end if;
  insert into public.processing_usage(owner_id, day, requests)
  values (auth.uid(), (now() at time zone 'UTC')::date, 1)
  on conflict (owner_id, day) do update set requests = public.processing_usage.requests + 1
    where public.processing_usage.requests < 100
  returning requests into used;
  return used is not null;
end;
$$;
revoke all on function public.claim_processing_request() from public, anon;
grant execute on function public.claim_processing_request() to authenticated;
