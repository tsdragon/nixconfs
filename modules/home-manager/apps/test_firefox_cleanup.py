import importlib.util
import json
from pathlib import Path
import select
import sqlite3
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("firefox-cleanup.py")
SPEC = importlib.util.spec_from_file_location("firefox_cleanup", SCRIPT)
cleanup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cleanup)


class FirefoxCleanupTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.profile = self.root / "profile"
        self.profile.mkdir()
        self.cache = self.root / "cache"
        self.config = self.root / "config.json"
        self.config.write_text(json.dumps({
            "profile": str(self.profile), "cache": str(self.cache),
            "domains": ["example.com"],
        }))

    def touch(self, relative, content="synthetic data"):
        path = self.profile / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def cookies(self, hosts):
        with sqlite3.connect(self.profile / "cookies.sqlite") as db:
            db.execute("CREATE TABLE moz_cookies (host TEXT PRIMARY KEY)")
            db.executemany("INSERT INTO moz_cookies VALUES (?)", [(h,) for h in hosts])

    def hosts(self):
        with sqlite3.connect(self.profile / "cookies.sqlite") as db:
            return {row[0] for row in db.execute("SELECT host FROM moz_cookies")}

    def clean(self):
        return cleanup.cleanup_profile(self.profile, self.cache, ["example.com"])

    def launch(self, code, *args):
        return [sys.executable, "-B", str(SCRIPT), str(self.config),
                sys.executable, "-B", "-c", code, str(self.profile), *args]

    def child(self, command):
        process = subprocess.Popen(command, stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   text=True)
        self.addCleanup(self.stop_child, process)
        return process

    @staticmethod
    def stop_child(process):
        if process.poll() is None:
            process.kill()
        process.communicate(timeout=5)

    def ready(self, process):
        self.assertTrue(select.select([process.stdout], [], [], 5)[0],
                        "child did not become ready within five seconds")
        self.assertEqual(process.stdout.readline(), "ready\n")

    def test_cookie_allowlist_and_ipv4_boundaries(self):
        kept = {"example.com", ".example.com", "sub.example.com",
                ".deep.sub.example.com", "EXAMPLE.COM", "192.168.1.0",
                "192.168.1.42", "192.168.1.255"}
        removed = {"evil-example.com", "notexample.com", "example.com.evil",
                   "exampleXcom", "192.168.0.42", "192.168.2.42",
                   "10.0.0.1", "192.168.1.42.evil", "::1"}
        self.cookies(kept | removed)
        self.assertTrue(self.clean())
        self.assertEqual(self.hosts(), kept)

    def test_site_data_removed_but_history_and_extensions_preserved(self):
        preserved = [self.touch("places.sqlite"),
                     self.touch("browser-extension-data/addon@example/data.json")]
        removed = []
        for storage in ("default", "temporary", "permanent"):
            preserved.append(self.touch(f"storage/{storage}/moz-extension+++addon/idb/data"))
            for origin in ("http+++example.com", "https+++example.com",
                           "https+++example.com^userContextId=2", "file++++tmp"):
                removed.append(self.touch(f"storage/{storage}/{origin}/idb/data").parent.parent)
        for name in ("sessionstore.jsonlz4", "sessionCheckpoints.json",
                     "serviceworker.txt", "serviceworker.txt.tmp",
                     "SiteSecurityServiceState.bin", "SiteSecurityServiceState.txt",
                     "formhistory.sqlite", "formhistory.sqlite-wal", "formhistory.sqlite-shm"):
            removed.append(self.touch(name))
        for name in ("sessionstore-backups", "cache2", "startupCache",
                     "shader-cache", "thumbnails", "OfflineCache"):
            removed.append(self.touch(f"{name}/data").parent)
        self.cache.mkdir()
        (self.cache / "cached").write_text("external cache")
        removed.append(self.cache)
        self.assertTrue(self.clean())
        for path in removed:
            self.assertFalse(path.exists(), str(path))
        for path in preserved:
            self.assertEqual(path.read_text(), "synthetic data", str(path))

    def test_parentlock_held_by_other_process_leaves_data_unchanged(self):
        self.cookies({"example.com", "remove.test"})
        self.touch(".parentlock", "")
        self.touch("sessionstore.jsonlz4")
        self.touch("storage/default/https+++remove.test/data")
        self.cache.mkdir()
        (self.cache / "cached").write_text("cached")
        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        process = self.child([sys.executable, "-B", "-c",
                              "import fcntl, sys; "
                              "f = open(sys.argv[1], 'r+'); "
                              "fcntl.lockf(f, fcntl.LOCK_EX); "
                              "print('ready', flush=True); sys.stdin.read()",
                              str(self.profile / ".parentlock")])
        self.ready(process)
        self.assertFalse(self.clean())
        after = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(after, before)

    def test_legacy_and_archived_local_storage_filters_website_origin_keys(self):
        removed = {"moc.elpmaxe.:http:80", "moc.elpmaxe.:https:443",
                   "moc.elpmaxe.:https:8443", ".:file", "tset.evomer.:ftp",
                   "tset.evomer.:ftp:2121"}
        kept = {"nodda.:moz-extension", "browser.:about", "browser.:chrome"}
        databases = [self.profile / "webappsstore.sqlite",
                     self.profile / "storage/ls-archive.sqlite"]
        for path in databases:
            path.parent.mkdir(parents=True, exist_ok=True)
            with sqlite3.connect(path) as db:
                db.execute("CREATE TABLE webappsstore2 (originKey TEXT, value TEXT)")
                db.executemany("INSERT INTO webappsstore2 VALUES (?, ?)",
                               [(key, "synthetic data") for key in removed | kept])
        self.assertTrue(self.clean())
        for path in databases:
            with self.subTest(database=path.name), sqlite3.connect(path) as db:
                self.assertEqual(set(db.execute("SELECT originKey, value FROM webappsstore2")),
                                 {(key, "synthetic data") for key in kept})

    def test_quota_archives_remove_website_origins_and_preserve_extensions(self):
        removed = []
        preserved = []
        for date in ("2026-10-28", "2026-10-29"):
            for storage in ("default", "temporary"):
                root = f"storage/archives/0/{date}/{storage}"
                preserved.append(self.touch(f"{root}/moz-extension+++addon/idb/data"))
                for origin in ("http+++example.com", "https+++example.com",
                               "https+++example.com+8443^userContextId=2",
                               "file++++tmp", "ftp+++remove.test"):
                    removed.append(self.touch(f"{root}/{origin}/idb/data").parent.parent)
        self.assertTrue(self.clean())
        for path in removed:
            self.assertFalse(path.exists(), str(path))
        for path in preserved:
            self.assertEqual(path.read_text(), "synthetic data", str(path))

    def test_committed_cookies_in_live_wal_are_filtered(self):
        self.cookies(set())
        with sqlite3.connect(self.profile / "cookies.sqlite") as db:
            self.assertEqual(db.execute("PRAGMA journal_mode=WAL").fetchone()[0], "wal")
            db.execute("PRAGMA wal_autocheckpoint=0")
            db.executemany("INSERT INTO moz_cookies VALUES (?)",
                           [("example.com",), ("remove.test",)])
            db.commit()
            self.assertGreater((self.profile / "cookies.sqlite-wal").stat().st_size, 0)
            self.assertTrue(self.clean())
            self.assertEqual(self.hosts(), {"example.com"})
            self.assertEqual(db.execute("SELECT host FROM moz_cookies").fetchall(),
                             [("example.com",)])

    def test_symlinked_storage_refuses_traversal(self):
        target = self.root / "outside"
        target.mkdir()
        sentinel = target / "https+++keep.test"
        sentinel.write_text("untouched")
        for relative in ("storage", "storage/default"):
            with self.subTest(relative=relative):
                link = self.profile / relative
                link.parent.mkdir(parents=True, exist_ok=True)
                link.symlink_to(target, target_is_directory=True)
                try:
                    with self.assertRaisesRegex(RuntimeError, "symlinked site storage"):
                        self.clean()
                    self.assertTrue(link.is_symlink())
                    self.assertEqual(sentinel.read_text(), "untouched")
                finally:
                    link.unlink()

    def test_symlink_origin_is_unlinked_without_removing_target(self):
        target = self.root / "outside"
        target.mkdir()
        sentinel = target / "data"
        sentinel.write_text("untouched")
        storage = self.profile / "storage/default"
        storage.mkdir(parents=True)
        link = storage / "https+++remove.test^userContextId=1"
        link.symlink_to(target, target_is_directory=True)
        self.assertTrue(self.clean())
        self.assertFalse(link.is_symlink())
        self.assertEqual(sentinel.read_text(), "untouched")

    def test_wrapper_cleans_before_and_after_and_forwards_arguments(self):
        self.touch("sessionstore.jsonlz4", "before")
        self.cookies({"example.com", "before.test"})
        code = """
import pathlib, sqlite3, sys
p = pathlib.Path(sys.argv[1])
assert sys.argv[2:] == ['--new-window', 'https://example.com/a b']
assert not (p / 'sessionstore.jsonlz4').exists()
with sqlite3.connect(p / 'cookies.sqlite') as db:
    assert db.execute('SELECT host FROM moz_cookies').fetchall() == [('example.com',)]
    db.execute("INSERT INTO moz_cookies VALUES ('after.test')")
(p / 'sessionstore.jsonlz4').write_text('after')
sys.exit(7)
"""
        result = subprocess.run(self.launch(code, "--new-window", "https://example.com/a b"),
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertFalse((self.profile / "sessionstore.jsonlz4").exists())
        self.assertEqual(self.hosts(), {"example.com"})

    def test_second_launch_preserves_active_session_data_without_hanging(self):
        code = """
import fcntl, pathlib, sys
profile = pathlib.Path(sys.argv[1])
lock = (profile / '.parentlock').open('a+')
fcntl.lockf(lock, fcntl.LOCK_EX)
p = profile / 'sessionstore.jsonlz4'
p.write_text('active session')
print('ready', flush=True)
sys.stdin.readline()
assert p.read_text() == 'active session'
"""
        first = self.child(self.launch(code))
        self.ready(first)
        second = subprocess.run(self.launch(
            "import pathlib, sys; "
            "assert (pathlib.Path(sys.argv[1]) / 'sessionstore.jsonlz4').read_text() "
            "== 'active session'"), capture_output=True, text=True, timeout=5)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual((self.profile / "sessionstore.jsonlz4").read_text(), "active session")
        _, stderr = first.communicate(input="exit\n", timeout=5)
        self.assertEqual(first.returncode, 0, stderr)
        self.assertFalse((self.profile / "sessionstore.jsonlz4").exists())

    def test_version_and_help_preserve_profile_and_cache(self):
        self.cookies({"example.com", "remove.test"})
        self.touch("sessionstore.jsonlz4")
        self.touch("storage/default/https+++remove.test/data")
        self.cache.mkdir()
        (self.cache / "cached").write_text("cached")
        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        for argument in ("--version", "-v", "--full-version", "--help", "-h"):
            with self.subTest(argument=argument):
                result = subprocess.run(self.launch(
                    "import sys; print(sys.argv[2]); sys.exit(7)", argument),
                    capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 7, result.stderr)
                self.assertEqual(result.stdout, argument + "\n")
                after = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
                self.assertEqual(after, before)

    def test_shutdown_overlap_cleans_before_and_after_second_browser(self):
        self.cookies({"example.com"})
        code = """
import fcntl, pathlib, sqlite3, sys
p = pathlib.Path(sys.argv[1])
lock = (p / '.parentlock').open('a+')
fcntl.lockf(lock, fcntl.LOCK_EX)
with sqlite3.connect(p / 'cookies.sqlite') as db:
    db.execute("INSERT INTO moz_cookies VALUES ('stale.test')")
(p / 'sessionstore.jsonlz4').write_text('stale session')
origin = p / 'storage/default/https+++stale.test'
origin.mkdir(parents=True)
(origin / 'data').write_text('stale website data')
print('ready', flush=True)
sys.stdin.readline()
fcntl.lockf(lock, fcntl.LOCK_UN)
print('ready', flush=True)
sys.stdin.readline()
"""
        first = self.child(self.launch(code))
        self.ready(first)
        first.stdin.write("release native lock\n")
        first.stdin.flush()
        self.ready(first)
        self.assertIsNone(first.poll())
        second_code = """
import fcntl, pathlib, sqlite3, sys
p = pathlib.Path(sys.argv[1])
lock = (p / '.parentlock').open('a+')
fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
assert not (p / 'sessionstore.jsonlz4').exists()
assert not (p / 'storage/default/https+++stale.test').exists()
with sqlite3.connect(p / 'cookies.sqlite') as db:
    assert db.execute('SELECT host FROM moz_cookies').fetchall() == [('example.com',)]
    db.execute("INSERT INTO moz_cookies VALUES ('second.test')")
(p / 'sessionstore.jsonlz4').write_text('second session')
origin = p / 'storage/default/https+++second.test'
origin.mkdir(parents=True)
(origin / 'data').write_text('second website data')
"""
        second = subprocess.run(self.launch(second_code), capture_output=True,
                                text=True, timeout=5)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIsNone(first.poll())
        self.assertEqual(self.hosts(), {"example.com"})
        self.assertFalse((self.profile / "sessionstore.jsonlz4").exists())
        self.assertFalse((self.profile / "storage/default/https+++second.test").exists())
        _, stderr = first.communicate(input="exit\n", timeout=5)
        self.assertEqual(first.returncode, 0, stderr)
