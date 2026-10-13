#!/usr/bin/env python3
"""Source materials preserve exact archives and never disguise incomplete closure."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
from unittest import mock

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('source_materials',ROOT/'scripts/assemble-pandoc-source.py')
source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.archive=self.root/'source.tar.gz';self.doc=self.root/'PROVENANCE.md';self.doc.write_text('Partial; exact dependency closure unresolved.')
        self.provenance=dict(schemaVersion=1,version='3.12.1',sourceCommit='a'*40,recipes=['cabal.project'],packageDescriptions=['pandoc.cabal'],notices=['COPYING.md'],completeness='partial',missingEvidence=['resolved dependency source closure'])
        self.write_archive()

    def write_archive(self,omit=None,symlink=None):
        with tarfile.open(self.archive,'w:gz') as output:
            for name,contents in {'cabal.project':'packages: .','pandoc.cabal':'library\n  build-depends: base >= 4.18,\n    aeson >= 2.2\n  default-language: Haskell2010','COPYING.md':'Fixture GPL notice'}.items():
                if name==omit:continue
                entry=tarfile.TarInfo('pandoc-'+self.provenance['sourceCommit']+'/'+name)
                if name==symlink:entry.type=tarfile.SYMTYPE;entry.linkname='/etc/passwd';output.addfile(entry)
                else:entry.size=len(contents.encode());output.addfile(entry,io.BytesIO(contents.encode()))
        self.provenance['sourceSHA256']=source.digest(self.archive)

    def test_partial_bundle_retains_archive_and_recipe_checksums(self):
        destination=self.root/'materials';bundle=source.assemble(self.archive,destination,self.provenance,self.doc)
        record=json.loads((destination/'materials-manifest.json').read_text())
        self.assertEqual(record['completeness'],'partial');self.assertTrue(record['missingEvidence'])
        self.assertEqual((destination/record['assembledSourceArchive']).read_bytes(),self.archive.read_bytes())
        for name,digest in record['files'].items():self.assertEqual(source.digest(destination/name),digest)
        inventory=json.loads((destination/'declared-dependencies.json').read_text())
        self.assertEqual(inventory['packages']['pandoc.cabal'],['aeson >= 2.2','base >= 4.18'])
        with zipfile.ZipFile(bundle) as contents:self.assertIn('materials/upstream/COPYING.md',contents.namelist())
        self.assertEqual(bundle.with_suffix('.zip.sha256').read_text().strip(),f'{source.digest(bundle)}  {bundle.name}')

    def test_tampered_source(self):
        self.archive.write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError,'checksum'):source.assemble(self.archive,self.root/'materials',self.provenance,self.doc)

    def test_missing_recipe(self):
        self.write_archive(omit='cabal.project')
        with self.assertRaisesRegex(ValueError,'missing'):source.assemble(self.archive,self.root/'materials',self.provenance,self.doc)

    def test_symlink_recipe_not_followed(self):
        self.write_archive(symlink='cabal.project')
        with self.assertRaisesRegex(ValueError,'missing'):source.assemble(self.archive,self.root/'materials',self.provenance,self.doc)

    def test_path_traversal_manifest(self):
        self.provenance['recipes']=['../../etc/passwd']
        with self.assertRaisesRegex(ValueError,'Unsafe'):source.assemble(self.archive,self.root/'materials',self.provenance,self.doc)

    def test_existing_output_preserved(self):
        destination=self.root/'materials';destination.mkdir();(destination/'user').write_text('preserve')
        with self.assertRaisesRegex(ValueError,'overwrite'):source.assemble(self.archive,destination,self.provenance,self.doc)
        self.assertEqual((destination/'user').read_text(),'preserve')

    def test_complete_requirement_fails_after_partial_assembly(self):
        metadata=self.root/'release/vendor/pandoc-source';metadata.mkdir(parents=True)
        (metadata/'provenance.json').write_text(json.dumps(self.provenance))
        (metadata/'SOURCE_PROVENANCE.md').write_text(self.doc.read_text())
        with mock.patch.object(source,'ROOT',self.root),mock.patch('sys.argv',['assemble-pandoc-source.py','--archive',str(self.archive),'--output',str(self.root/'materials'),'--require-complete']):
            with self.assertRaisesRegex(SystemExit,'Blocked: resolved dependency'):source.main()
        self.assertTrue((self.root/'materials.zip').is_file())


if __name__=='__main__':unittest.main()
