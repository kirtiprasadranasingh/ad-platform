import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("migration", Path(__file__).parent / "migrations/create_schema.py")
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class FakeCursor:
    def __init__(self, existing=False, fail=False):
        self.existing, self.fail = existing, fail
        self.calls, self.closed = [], False

    def execute(self, sql, *parameters):
        self.calls.append((sql, parameters))
        if self.fail and sql.startswith("CREATE TABLE msms_obj_type"):
            raise RuntimeError("simulated database error")

    def fetchone(self):
        return (1,) if self.existing else None

    def close(self):
        self.closed = True


class FakeConnection:
    def __init__(self, **kwargs):
        self.cur = FakeCursor(**kwargs)
        self.commits, self.rollbacks = 0, 0

    def cursor(self):
        return self.cur

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1


class MigrationTests(unittest.TestCase):
    def test_untrusted_values_are_bound_not_interpolated(self):
        conn = FakeConnection()
        payload = "sample'); DROP TABLE msms_obj;--"
        self.assertTrue(migration.execute_migration(conn, payload, "cluster-test", "client_metastore"))
        self.assertTrue(any(payload in args for _, args in conn.cur.calls))
        self.assertTrue(all(payload not in sql for sql, _ in conn.cur.calls))
        self.assertEqual(conn.commits, 1)
        self.assertTrue(conn.cur.closed)

    def test_existing_schema_is_noop(self):
        conn = FakeConnection(existing=True)
        self.assertFalse(migration.execute_migration(conn, "synthetic", "cluster-test", "client_metastore"))
        self.assertFalse(any(sql.startswith("INSERT INTO msms") for sql, _ in conn.cur.calls))

    def test_failure_rolls_back_without_suppressing_error(self):
        conn = FakeConnection(fail=True)
        with self.assertRaises(RuntimeError):
            migration.execute_migration(conn, "synthetic", "cluster-test", "client_metastore")
        self.assertEqual(conn.rollbacks, 1)
        self.assertEqual(conn.commits, 0)
        self.assertTrue(conn.cur.closed)


if __name__ == "__main__":
    unittest.main()
