#!/usr/bin/env python3
"""Crash/failure recovery uses temporary sources and a fake installer only."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('lifecycle', ROOT/'scripts/consumer-lifecycle.py')
lifecycle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lifecycle)

class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='consumer lifecycle with spaces ')
        self.base = Path(self.temp.name)
        for name, version in [('source','old'),('source-next','new')]:
            path = self.base/name; path.mkdir()
            (path/'consumer-profile.json').write_text('{}')
            (path/'version').write_text(version)
    def tearDown(self): self.temp.cleanup()
    def version(self): return (self.base/'source/version').read_text()
    def test_update_and_rollback_keep_both_sources(self):
        visited = []
        install = lambda source: visited.append((source.name,(source/'version').read_text()))
        lifecycle.transition(self.base,self.base/'source-next','update',install)
        self.assertEqual(self.version(),'new')
        self.assertEqual((self.base/'previous/version').read_text(),'old')
        lifecycle.transition(self.base,self.base/'previous','rollback',install)
        self.assertEqual(self.version(),'old')
        self.assertEqual((self.base/'previous/version').read_text(),'new')
        self.assertEqual(visited,[('source','new'),('source','old')])
    def test_failed_update_restores_and_reapplies_prior_source(self):
        visited = []
        def install(source):
            version = (source/'version').read_text(); visited.append(version)
            if version == 'new': raise RuntimeError('candidate failed')
        with self.assertRaises(RuntimeError): lifecycle.transition(self.base,self.base/'source-next','update',install)
        self.assertEqual(self.version(),'old')
        self.assertEqual(visited,['new','old'])
        self.assertEqual(lifecycle.read_journal(self.base)['outcome'],'restored-original')
    def test_interrupted_apply_requires_recovery(self):
        def interrupt(source): raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt): lifecycle.transition(self.base,self.base/'source-next','update',interrupt)
        self.assertEqual(self.version(),'new')
        with self.assertRaises(ValueError): lifecycle.transition(self.base,self.base/'source-next','update',lambda _:None)
        lifecycle.recover(self.base,lambda _:None)
        self.assertEqual(self.version(),'old')
    def test_interrupted_finalization_restores_original(self):
        (self.base/'source').rename(self.base/'previous')
        (self.base/'source-next').rename(self.base/'source')
        lifecycle.journal(self.base,{'phase':'finalizing','operation':'update'})
        lifecycle.recover(self.base,lambda _:None)
        self.assertEqual(self.version(),'old')
    def test_recovery_failure_is_retryable(self):
        def fail(source): raise RuntimeError('restore failed')
        def interrupt(source): raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt): lifecycle.transition(self.base,self.base/'source-next','update',interrupt)
        with self.assertRaises(RuntimeError): lifecycle.recover(self.base,fail)
        self.assertEqual(lifecycle.read_journal(self.base)['phase'],'restore-failed')
        lifecycle.recover(self.base,lambda _:None)
        self.assertEqual(self.version(),'old')

if __name__ == '__main__': unittest.main()
