"""Launch Firefox with only allowlisted cookies retained between sessions."""

import fcntl
import ipaddress
import json
import os
from pathlib import Path
import shutil
import signal
import sqlite3
import subprocess
import sys
from contextlib import closing


def cleanup_profile(profile, cache, domains):
    if not profile.exists():
        return True

    # lockf uses the same POSIX record lock as Firefox's nsProfileLock.
    fd = os.open(profile / ".parentlock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "r+") as lock:
        try:
            fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False

        def keep_cookie(host):
            host = host.lstrip(".").lower()
            if any(host == domain or host.endswith("." + domain) for domain in domains):
                return True
            try:
                return ipaddress.ip_address(host) in ipaddress.ip_network("192.168.1.0/24")
            except ValueError:
                return False

        storage = profile / "storage"
        if storage.is_symlink():
            raise RuntimeError("Refusing to traverse symlinked site storage")
        website_rows = " OR ".join(
            f"originKey GLOB '{pattern}'" for pattern in
            ("*.:http:*", "*.:https:*", "*.:file", "*.:ftp", "*.:ftp:*")
        )
        for database, statement in (
            (profile / "cookies.sqlite", "DELETE FROM moz_cookies WHERE NOT keep_cookie(host)"),
            (profile / "webappsstore.sqlite", "DELETE FROM webappsstore2 WHERE " + website_rows),
            (storage / "ls-archive.sqlite", "DELETE FROM webappsstore2 WHERE " + website_rows),
        ):
            if database.is_symlink():
                raise RuntimeError("Refusing to modify a symlinked browser database")
            if not database.exists():
                continue
            with closing(sqlite3.connect(database.as_uri() + "?mode=rw", uri=True, timeout=0)) as db:
                db.create_function("keep_cookie", 1, keep_cookie)
                with db:
                    db.execute("PRAGMA secure_delete = ON")
                    db.execute(statement)

        # Never traverse symlinked storage roots or remove extension origins.
        roots = [storage / name for name in ("default", "temporary", "permanent")]
        archives = storage / "archives" / "0"
        if archives.parent.is_symlink() or archives.is_symlink():
            raise RuntimeError("Refusing to traverse symlinked site storage")
        if archives.exists():
            for archive in archives.iterdir():
                if archive.is_symlink():
                    raise RuntimeError("Refusing to traverse symlinked site storage")
                if archive.is_dir():
                    roots.extend(archive / name for name in ("default", "temporary"))
        for root in roots:
            if root.parent.is_symlink() or root.is_symlink():
                raise RuntimeError("Refusing to traverse symlinked site storage")
            if root.exists():
                for origin in root.iterdir():
                    if origin.name.startswith(("http+++", "https+++", "file+++", "ftp+++")):
                        if origin.is_dir() and not origin.is_symlink():
                            shutil.rmtree(origin)
                        else:
                            origin.unlink()

        # Session recovery can restore cookies, form state and sessionStorage.
        for name in (
            "sessionstore.jsonlz4", "sessionstore-backups", "sessionCheckpoints.json",
            "serviceworker.txt", "serviceworker.txt.tmp", "cache2", "startupCache",
            "shader-cache", "thumbnails", "OfflineCache", "SiteSecurityServiceState.bin",
            "SiteSecurityServiceState.txt", "formhistory.sqlite", "formhistory.sqlite-wal",
            "formhistory.sqlite-shm",
        ):
            path = profile / name
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            else:
                path.unlink(missing_ok=True)
        # The configured cache directory is separate from the profile on Linux.
        if cache.is_symlink():
            raise RuntimeError("Refusing to traverse a symlinked cache directory")
        if cache.exists():
            shutil.rmtree(cache)
    return True


def main():
    with open(sys.argv[1]) as source:
        config = json.load(source)
    profile = Path(config["profile"])
    cache = Path(config["cache"])
    command = sys.argv[2:]
    if any(argument in ("--version", "-v", "--full-version", "--help", "-h") for argument in command[1:]):
        os.execv(command[0], command)
    profile.mkdir(mode=0o700, parents=True, exist_ok=True)

    # The gate blocks new link-opening invocations during cleanup. The session
    # lock prevents a second launcher cleaning in the gap before Firefox locks.
    with open(profile / ".cleanup-gate", "a") as gate, open(profile / ".cleanup-session", "a") as session:
        fcntl.flock(gate, fcntl.LOCK_EX)
        try:
            fcntl.flock(session, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            # Usually this only forwards a link to the existing browser. Keep
            # supervising it in case Firefox instead starts a new process while
            # the old one is shutting down. The native lock vetoes live cleanup.
            cleanup_profile(profile, cache, config["domains"])
            result = subprocess.run(command).returncode
            cleanup_profile(profile, cache, config["domains"])
            return result if result >= 0 else 128 - result

        cleanup_profile(profile, cache, config["domains"])
        child = subprocess.Popen(command)
        fcntl.flock(gate, fcntl.LOCK_UN)
        for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            signal.signal(signum, lambda received, frame: child.send_signal(received))
        result = child.wait()
        fcntl.flock(gate, fcntl.LOCK_EX)
        cleanup_profile(profile, cache, config["domains"])
        return result if result >= 0 else 128 - result


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, sqlite3.Error) as error:
        sys.exit(f"Firefox cleanup failed; no browser was started if this happened before launch: {error}")
