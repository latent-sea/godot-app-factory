"""app_sql_check.py against good and bad app tables.

    python3 platform/checks/test_app_sql_check.py
"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("app_sql_check", Path(__file__).with_name("app_sql_check.py"))
app_sql_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app_sql_check)

GOOD = """
-- the blog's posts
create table if not exists public.blog_posts (
  id bigint generated always as identity primary key,
  author uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body text not null default ''
);
alter table public.blog_posts enable row level security;
drop policy if exists "read" on public.blog_posts;
create policy "read" on public.blog_posts for select to anon, authenticated using (true);
create index if not exists blog_posts_author on public.blog_posts (author);
create table if not exists blog_tags (  -- no player data
  name text primary key
);
alter table blog_tags enable row level security;
create or replace function public.blog_count() returns bigint language sql stable as $$
  select count(*) from public.blog_posts; -- a semicolon inside the body
$$;
"""


class AppSqlCheckTest(unittest.TestCase):
    def check(self, sql: str) -> list[str]:
        with tempfile.TemporaryDirectory(dir=app_sql_check.ROOT) as tmp:
            path = Path(tmp) / "blog" / "backend.sql"
            path.parent.mkdir()
            path.write_text(sql)
            return app_sql_check.check(path)

    def assertFound(self, problems: list[str], words: str) -> None:
        self.assertTrue(any(words in p for p in problems), f"{words!r} not in {problems}")

    def test_tables_that_hold_the_rules_pass(self) -> None:
        self.assertEqual(self.check(GOOD), [])

    def test_another_apps_name_is_refused(self) -> None:
        self.assertFound(self.check(GOOD + "create table if not exists notes_x (id int); alter table notes_x enable row level security;"), "notes_x: not blog's")

    def test_a_table_must_be_made_if_not_exists(self) -> None:
        self.assertFound(self.check(GOOD.replace("create table if not exists public.blog_posts", "create table public.blog_posts")), "if not exists")

    def test_a_table_without_row_level_security_is_refused(self) -> None:
        self.assertFound(self.check(GOOD.replace("alter table blog_tags enable row level security;", "")), "blog_tags: no 'alter table")

    def test_a_table_must_belong_to_players_or_say_it_holds_none(self) -> None:
        self.assertFound(self.check(GOOD.replace("on delete cascade", "")), "blog_posts: no column")
        self.assertFound(self.check(GOOD.replace("-- no player data", "")), "blog_tags: no column")

    def test_policies_on_another_table_are_refused(self) -> None:
        self.assertFound(self.check(GOOD + 'create policy "x" on public.notes_notes for select using (true);'), "notes_notes is not blog's")

    def test_drops_roles_and_other_schemas_are_refused(self) -> None:
        self.assertFound(self.check(GOOD + "drop table blog_tags;"), "only policies and triggers")
        self.assertFound(self.check(GOOD + "create role sneaky;"), "the platform's")
        self.assertFound(self.check(GOOD + "select * from auth.sessions;"), "auth.sessions")


if __name__ == "__main__":
    unittest.main()
