#!/usr/bin/env python3
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('capture',ROOT/'scripts/capture-pandoc-closure.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)


spec2=importlib.util.spec_from_file_location('builder',ROOT/'scripts/build-pandoc-from-source.py')
builder=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(builder)


spec3=importlib.util.spec_from_file_location('inventory',ROOT/'scripts/inventory-pandoc-runtime-source.py')
inventory=importlib.util.module_from_spec(spec3);spec3.loader.exec_module(inventory)


class ClosureTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.plan={'compiler-id':'ghc-9.10.3','install-plan':[{'type':'pre-existing','pkg-name':'base','pkg-version':'4.20.1.0','id':'base-unit'},{'type':'configured','pkg-name':'pandoc','pkg-version':'3.12.1','pkg-src':{'type':'local','path':'/source'}},{'type':'configured','pkg-name':'fixture','pkg-version':'1.2','pkg-src':{'type':'repo-tar'},'pkg-src-sha256':'a'*64,'pkg-cabal-sha256':'b'*64}]}

    def test_plan_requires_exact_source_hash_and_captures_boot_units(self):
        packages,boot,local=capture.resolved_packages(self.plan)
        self.assertEqual(packages[0]['sha256'],'a'*64);self.assertEqual(boot[0]['unitID'],'base-unit');self.assertEqual(local[0]['name'],'pandoc')

    def test_unknown_source_type_fails(self):
        self.plan['install-plan'][-1]['pkg-src']['type']='source-repo'
        with self.assertRaisesRegex(ValueError,'Uncaptured'):capture.resolved_packages(self.plan)

    def test_missing_secure_hash_fails(self):
        self.plan['install-plan'][-1].pop('pkg-src-sha256')
        with self.assertRaisesRegex(ValueError,'secure source archive hash'):capture.resolved_packages(self.plan)

    def test_selected_revision_by_hash_not_latest(self):
        index=self.root/'01-index.tar';first=b'license: BSD-3-Clause\n';latest=b'license: MIT\n'
        with tarfile.open(index,'w') as output:
            for data in [first,latest]:
                entry=tarfile.TarInfo('fixture/1.2/fixture.cabal');entry.size=len(data);output.addfile(entry,io.BytesIO(data))
        package={'name':'fixture','version':'1.2','cabalSHA256':hashlib.sha256(first).hexdigest()}
        self.assertEqual(capture.revision_files(index,[package])['fixture/1.2/fixture.cabal'],first)
        package['cabalSHA256']='c'*64
        with self.assertRaisesRegex(ValueError,'revisions missing'):capture.revision_files(index,[package])

    def test_license_files_preserved(self):
        archive=self.root/'fixture.tar.gz'
        with tarfile.open(archive,'w:gz') as output:
            for name,data in {'fixture.cabal':b'license: BSD-3-Clause\nlicense-file: LICENSE\n','LICENSE':b'Fixture copyright and permission'}.items():
                entry=tarfile.TarInfo('fixture-1.2/'+name);entry.size=len(data);output.addfile(entry,io.BytesIO(data))
        cabal,license_name,notices=capture.package_metadata(archive,'fixture','1.2')
        self.assertEqual(license_name,'BSD-3-Clause');self.assertEqual(notices['LICENSE'],b'Fixture copyright and permission')

    def test_local_staging_applies_exact_revision(self):
        closure=self.root/'closure';closure.mkdir();archive=closure/'fixture.tar.gz'
        with tarfile.open(archive,'w:gz') as output:
            for name,data in {'fixture.cabal':b'license: BSD-3-Clause\n','code.hs':b'upstream code unchanged'}.items():
                entry=tarfile.TarInfo('fixture-1.2/'+name);entry.size=len(data);output.addfile(entry,io.BytesIO(data))
        revision=closure/'revised.cabal';revision.write_bytes(b'license: MIT\n')
        record={'resolvedSourceClosure':[{'id':'fixture-1.2','name':'fixture','archive':'fixture.tar.gz','sha256':capture.tools.sha256(archive),'cabalRevisionFile':'revised.cabal','selectedCabalSHA256':capture.tools.sha256(revision)}]}
        (closure/'closure.json').write_text(json.dumps(record))
        mapping=builder.stage_captured_sources(closure,self.root/'sources')
        self.assertEqual((self.root/'sources/fixture-1.2/fixture.cabal').read_bytes(),revision.read_bytes())
        self.assertEqual((self.root/'sources/fixture-1.2/code.hs').read_bytes(),b'upstream code unchanged')
        self.assertEqual(mapping[0]['appliedCabalSHA256'],capture.tools.sha256(revision))
        (self.root/'sources/fixture-1.2/code.hs').write_bytes(b'modified implementation')
        with self.assertRaisesRegex(ValueError,'upstream source drift'):
            builder.stage_captured_sources(closure,self.root/'sources')

    def test_offline_project_scopes_flags_and_disables_repositories(self):
        project=builder.offline_project('2026-10-08T00:00:00Z',[{'directory':'/path with spaces/fixture'}])
        self.assertIn('active-repositories: :none',project);self.assertIn('tests: False',project)
        self.assertIn('  "/path with spaces/fixture"',project)
        self.assertIn('package pandoc-cli\n  flags: +server +lua',project)
        self.assertNotIn('package *',project)

    def test_boot_and_bundled_gmp_libffi_inventory(self):
        archive=self.root/'ghc-source.tar.xz'
        with tarfile.open(archive,'w:xz') as output:
            for name,data in {'libraries/base/base.cabal':b'name: base\nversion: 4.20.2.0\n','libraries/base/LICENSE':b'BSD notice','libraries/ghc-bignum/gmp/gmp-tarballs/gmp-6.3.0.tar.xz':b'fixture GMP source','libffi-tarballs/libffi-3.4.6.tar.gz':b'fixture FFI source'}.items():
                entry=tarfile.TarInfo('ghc-9.10.3/'+name);entry.size=len(data);output.addfile(entry,io.BytesIO(data))
        report=inventory.inventory_ghc(archive,[{'name':'base','version':'4.20.2.0','unitID':'base-unit'}])
        self.assertIn('base',report['bootLibraries']);self.assertEqual(len(report['embeddedGMPAndLibffiSources']),2)
        with self.assertRaisesRegex(ValueError,'does not describe installed'):
            inventory.inventory_ghc(archive,[{'name':'missing','version':'1.0','unitID':'missing-unit'}])

    def test_cached_toolchain_checksum_mismatch(self):
        archive=self.root/'input';archive.write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError,'Cached checksum'):capture.tools.download('https://example.invalid/input','a'*64,archive)


if __name__=='__main__':unittest.main()
