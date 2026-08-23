-- ============================================================================
-- BantayDengue — fake demo data for Community Stories (DEV/DEMO ONLY)
-- Run this ONCE in Supabase Studio -> SQL Editor -> New query, after
-- COMMUNITY_STORIES.sql. Guarded/idempotent like every other file here, but
-- this one is NOT part of the app — it exists purely so the feed has enough
-- volume on screen to judge the UI with (requested explicitly: "para makita
-- ko pag madami na nakalagay" — to see how it looks once there's a lot of
-- content). Listed under "Standalone / as-needed" in README.md, not the
-- main run-order table, same as promote_to_admin.sql.
--
-- WHY BACKDATED created_at: enforce_community_post_rate_limit() /
-- enforce_community_comment_rate_limit() (COMMUNITY_STORIES.sql) count
-- existing rows where created_at > now() - interval '24 hours'. Backdating
-- every seeded row to well outside that window means seeding never counts
-- against — or gets blocked by — the same rate limit a real resident is
-- subject to.
--
-- Only confirmed live resident accounts are used as authors (checked via
-- `select id, full_name from public.profiles where role='resident'`) — this
-- does NOT create fake auth.users/profiles rows, only fake posts/comments/
-- reactions attributed to accounts that already exist.
--
-- WHY A ZERO-WIDTH-SPACE MARKER (chr(8203)), NOT A VISIBLE "[seed]" TAG:
-- an earlier version of this file appended a visible " [seed]" to every
-- post, which showed up right in the feed UI and looked exactly like what
-- it was — obviously fake placeholder text sitting in an otherwise real
-- app. A trailing U+200B is invisible in the rendered app (nothing to
-- select, nothing to read) but still lets this file find and remove
-- exactly what it inserted, nothing else.
--
-- TO REMOVE THIS DATA LATER:
--   delete from public.community_reactions where post_id in
--     (select id from public.community_posts where content like '%' || chr(8203));
--   delete from public.community_comments where content like '%' || chr(8203);
--   delete from public.community_posts where content like '%' || chr(8203);
--   delete from public.schema_migrations where filename = 'COMMUNITY_SEED_DEMO_DATA.sql';
-- ============================================================================

do $$
begin
  if exists (select 1 from public.schema_migrations where filename = 'COMMUNITY_SEED_DEMO_DATA.sql') then
    raise exception 'COMMUNITY_SEED_DEMO_DATA.sql has already been applied — see supabase/README.md before re-running. To reseed, first delete the existing seed rows (see the comment block at the top of this file), then remove this file''s row from public.schema_migrations.';
  end if;
end $$;

begin;

do $$
declare
  author_a uuid;
  author_b uuid;
  post_ids uuid[] := array[]::uuid[];
  new_post_id uuid;
  i int;
  marker text := chr(8203);
  -- Deliberately messy — mixed capitalization, run-ons, trailing off with
  -- "...", the occasional all-caps word, code-switched Taglish the way
  -- people actually type it, not textbook sentences.
  contents text[] := array[
    'di ko alam kung dapat ba akong mag alala, 2 days na yung fever tas di gumagalaw. anyone same experience?',
    'update: NS1 positive ako 😭 sabi ni doc mild pa lang, pero grabe yung takot ko kanina sa clinic',
    'sino may alam paano gawin yung papaya leaves extract na sinasabi ng mga tita dito, baka pwede subukan',
    'ilang araw na akong walang gana kumain tapos yung ulo ko parang may nakapatong na bato. sobra',
    'day 3 na wala nang lagnat!! slowly nakakakain na rin ako. salamat sa mga nagcomment kanina huhu',
    'PSA lang sa mga kapitbahay sa amin - linisin niyo na yung mga gutter niyo, andun lahat ng lamok namin nanggagaling',
    'anak ko yung na diagnose, 4 lang siya. ang hirap panoorin pero ok na siya ngayon, dischargeable na daw bukas',
    'sana all makapag balik check up agad, akala ko lang mahal pero libre pala sa health center namin',
    'grabe yung joint pain, feeling ko may binali sakin habang tulog ako. tapos ngayon medyo okay na',
    'may nakakaalam ba san pwede magpa fogging dito sa amin, dami na kasing naospital sa street namin ngayong buwan',
    'one week nakaquarantine sa kwarto, nakakasawa na pero ayaw ko rin ihawa yung pamilya ko',
    'update sa anak ko - discharged na siya kanina! salamat talaga sa lahat dito, sobrang laking tulong',
    'nakakatakot yung rash na lumabas sa braso ko after ng lagnat, agad ako nagpatingin. normal lang daw sabi ni doc',
    'two weeks post recovery na ako, ang bagal talaga bumalik ng energy. di ko alam na ganito pala kahirap',
    'sa mga first time makakaranas nito, wag kayo mag alinlangan magpacheck kahit pa mukhang normal lang sipon',
    'nagpositive din yung roommate ko this week, buti nasabi dito agad yung warning signs kaya naaga namin nahuli',
    'grabe yung uhaw kahit ilang baso na ng tubig, tapos yung sakit ng ulo parang di talaga mawala',
    'salamat sa health workers namin dito, ang bilis ng response nila noong nagreport ako',
    'weak pa rin pero improving naman araw araw, sinusundan ko na rin yung diet na binigay',
    'ilang beses na kong nagkadengue sa buhay ko pero ito talaga pinakamalala. ingat lahat, tignan niyo mga tubig sa paligid niyo',
    'anxious ako nung lumabas yung mga pantal, akala ko lumalala na pero normal lang pala sa recovery',
    'one month check up na, sabi ni doc fully recovered na daw. thank you sa lahat ng nagsuggest ng mga gamot',
    'nagalala kami sa lolo namin kasi matanda na siya, pero nagrecover din siya after 10 days. malakas pa pala',
    'bagong kaso ulit sa kabilang kalye namin. pakiingatan niyo mga paso at drums niyo mga kapatid, wag pabayaan',
    'sobrang pagod ko na lang, ilang linggo na tong ganito, pero salamat at may space to mag share',
    'yung tricycle papunta ng ospital namin, ang layo talaga, sana may mas malapit na health center dito',
    '3rd time ko na dala anak ko sa ER this month, hindi dengue yung dalawa pero sobrang stress talaga',
    'grabe rin pala yung bill kahit nasa public hospital, buti nalang may PhilHealth kami'
  ];
  content_count int;
  -- A wider, uneven pool so replies don't read like the same five lines on
  -- rotation — mixes length, tone, and a couple of short/plain ones the way
  -- real comment sections actually look.
  reply_pool text[] := array[
    'ingat lagi 🙏',
    'sending strength sainyo',
    'salamat sa pagshare nito, helpful talaga',
    'same experience din namin dati, ganyan din umpisa',
    'get well soon!!',
    'ate/kuya kumusta na po ngayon?',
    'huhu nakakaiyak basahin to',
    'praying for you and your family',
    'grabe, ingat din po kayo diyan',
    'salamat sa warning, magbabantay na rin ako sa amin',
    'strong talaga kayo, kaya niyo yan',
    'omg ganito rin nangyari sakin last year',
    'wag kalimutan ang tubig at pahinga po',
    'thank you sa update, natutuwa kami dito',
    'ingat lagi, sobrang dami na kasing kaso ngayon',
    'goodluck sa checkup niyo ulit',
    'this. sobrang totoo nito',
    'nakakatakot pero salamat sa pagshare'
  ];
begin
  select id into author_a from public.profiles where role = 'resident' order by created_at asc limit 1;
  select id into author_b from public.profiles where role = 'resident' order by created_at asc offset 1 limit 1;

  if author_a is null then
    raise exception 'No resident profile found to attribute seed posts to — create/sign up a resident account first.';
  end if;
  if author_b is null then
    author_b := author_a;
  end if;

  content_count := array_length(contents, 1);

  for i in 1..content_count loop
    new_post_id := uuid_generate_v4();
    insert into public.community_posts (id, author_id, content, created_at)
    values (
      new_post_id,
      case when i % 2 = 0 then author_a else author_b end,
      contents[i] || marker,
      now() - (make_interval(days => content_count - i, hours => (i * 3) % 17))
    );
    post_ids := array_append(post_ids, new_post_id);
  end loop;

  -- A handful of comments per post, alternating the two authors, drawn
  -- from a wide/uneven pool (prime-step index so it doesn't visibly cycle
  -- in order) so comment counts and the comment sheet aren't empty either.
  for i in 1..array_length(post_ids, 1) loop
    if i % 3 <> 0 then
      insert into public.community_comments (post_id, author_id, content, created_at)
      values (
        post_ids[i],
        case when i % 2 = 0 then author_b else author_a end,
        reply_pool[1 + ((i * 7) % array_length(reply_pool, 1))] || marker,
        now() - (make_interval(days => content_count - i, hours => ((i * 3) % 17) + 1))
      );
    end if;
    if i % 4 = 0 then
      insert into public.community_comments (post_id, author_id, content, created_at)
      values (
        post_ids[i],
        case when i % 2 = 0 then author_a else author_b end,
        reply_pool[1 + ((i * 11 + 3) % array_length(reply_pool, 1))] || marker,
        now() - (make_interval(days => content_count - i, hours => ((i * 3) % 17) + 2))
      );
    end if;
  end loop;

  -- Reactions — only 2 real resident accounts exist, so at most 2 "loves"
  -- per post (author never reacts to their own post here, mirroring how
  -- most real usage looks).
  for i in 1..array_length(post_ids, 1) loop
    if i % 2 = 1 then
      insert into public.community_reactions (post_id, user_id)
      values (post_ids[i], author_a)
      on conflict (post_id, user_id) do nothing;
    end if;
    if i % 3 = 0 then
      insert into public.community_reactions (post_id, user_id)
      values (post_ids[i], author_b)
      on conflict (post_id, user_id) do nothing;
    end if;
  end loop;
end $$;

insert into public.schema_migrations (filename) values ('COMMUNITY_SEED_DEMO_DATA.sql')
on conflict (filename) do nothing;

commit;

-- ============================================================================
-- Done. Verify with:
--   select count(*) from public.community_posts where content like '%' || chr(8203);
--   select count(*) from public.community_comments where content like '%' || chr(8203);
-- To remove this demo data later, see the comment block at the top of this
-- file, then also: delete from public.schema_migrations where filename =
-- 'COMMUNITY_SEED_DEMO_DATA.sql';
-- ============================================================================
