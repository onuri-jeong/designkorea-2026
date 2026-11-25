-- 디자인코리아 관람 여정 · Supabase 초기 설정
-- SQL Editor에 통째로 붙여 넣고 Run 한 번이면 끝.

-- 1) 모든 데이터를 담는 표 하나 (멤버·답변·조 편성·카드)
create table if not exists public.docs (
  col        text   not null,
  id         text   not null,
  data       jsonb  not null default '{}'::jsonb,
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint,
  primary key (col, id)
);
alter table public.docs replica identity full;

-- 2) 링크를 가진 사람은 읽고 쓸 수 있게 (로그인 없음)
alter table public.docs enable row level security;
drop policy if exists "docs read"   on public.docs;
drop policy if exists "docs write"  on public.docs;
drop policy if exists "docs update" on public.docs;
drop policy if exists "docs delete" on public.docs;
create policy "docs read"   on public.docs for select to anon using (true);
create policy "docs write"  on public.docs for insert to anon with check (col in ('members','answers','meta','gstate','notes'));
create policy "docs update" on public.docs for update to anon using (true) with check (col in ('members','answers','meta','gstate','notes'));
create policy "docs delete" on public.docs for delete to anon using (true);

-- 3) 실시간 동기화 켜기
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- 4) 사진 저장 버킷 (공개 읽기, 장당 10MB, 이미지만)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "photos read"   on storage.objects;
drop policy if exists "photos upload" on storage.objects;
drop policy if exists "photos delete" on storage.objects;
create policy "photos read"   on storage.objects for select to anon using (bucket_id = 'photos');
create policy "photos upload" on storage.objects for insert to anon with check (bucket_id = 'photos');
create policy "photos delete" on storage.objects for delete to anon using (bucket_id = 'photos');
