#!/usr/bin/env python3
"""Check binary/source/recipe binding without compiling Haskell or signing."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('dependencies',ROOT/'scripts/bundled-dependencies.py')
dependencies = importlib.util.module_from_spec(spec);spec.loader.exec_module(dependencies)

class ArtifactBundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='own artifact with spaces ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)/'repo'; self.artifact = Path(self.temp.name)/'artifact'
        self.artifact.mkdir(); (self.root/'scripts').mkdir(parents=True)
        (self.root/'release/vendor/pandoc-source').mkdir(parents=True)
        shutil.copytree(ROOT/'release/vendor/pandoc',self.root/'release/vendor/pandoc')
        for name in dependencies.OWN_BUILD_RECIPES:
            shutil.copy2(ROOT/'scripts'/name,self.root/'scripts'/name)
            shutil.copy2(ROOT/'scripts'/name,self.artifact/name)
        self.pins = json.loads((ROOT/'release/vendor/pandoc-source/own-build-inputs.json').read_text())
        for name,data,pin in [('pandoc-source.tar.gz',b'fixture upstream source','pandocSourceSHA256'),('ghc-source.tar.xz',b'fixture compiler source','ghcSourceSHA256')]:
            (self.artifact/name).write_bytes(data);self.pins[pin] = hashlib.sha256(data).hexdigest()
        (self.root/'release/vendor/pandoc-source/own-build-inputs.json').write_text(json.dumps(self.pins))
        (self.artifact/'own-build-inputs.json').write_text(json.dumps(self.pins,indent=2))
        self.arch = 'arm64'
        (self.artifact/'pandoc').write_bytes(b'fixture raw binary')
        self.raw_sha = dependencies.sha256(self.artifact/'pandoc')
        self.record = {'schemaVersion':1,'producer':'dotfiles-pinned-source-build','architecture':self.arch,
            'pandocVersion':self.pins['pandocVersion'],'sourceCommit':self.pins['pandocCommit'],
            'binarySHA256':self.raw_sha,'ghcVersion':self.pins['ghcVersion'],'cabalVersion':self.pins['cabalVersion'],
            'indexState':self.pins['indexState'],'captureStatus':'source-captured-review-required',
            'buildExecutionURL':'https://example.test/build/123','sourceMaterialsArchive':'pandoc-own-source-arm64.zip'}
        (self.artifact/'toolchain.json').write_text(json.dumps({'architecture':self.arch,'inputs':self.pins['toolchains'][self.arch],
            'ghcVersion':self.pins['ghcVersion'],'cabalVersion':self.pins['cabalVersion']}))
        self.validation = {'rawBinarySHA256':self.raw_sha,'architecture':self.arch,'htmlToGFM':'passed','isolatedEnvironment':'passed'}
        (self.artifact/'standalone-validation.json').write_text(json.dumps(self.validation))
        (self.artifact/'runtime-source-inventory.json').write_text('{}')
        (self.artifact/'closure').mkdir(); (self.artifact/'closure/closure.json').write_text('{}')
        self.package_sources()
        self.validator = mock.patch.object(dependencies,'validate_source_binary',return_value=self.validation)
        self.validator.start();self.addCleanup(self.validator.stop)

    def package_sources(self):
        excluded = {'pandoc','own-build.json','source-materials.json',self.record['sourceMaterialsArchive']}
        files = {str(path.relative_to(self.artifact)):dependencies.sha256(path) for path in self.artifact.rglob('*') if path.is_file() and str(path.relative_to(self.artifact)) not in excluded}
        materials = dict(self.record,files=files)
        (self.artifact/'source-materials.json').write_text(json.dumps(materials))
        archive = self.artifact/self.record['sourceMaterialsArchive']
        with zipfile.ZipFile(archive,'w') as output:
            for name in files: output.write(self.artifact/name,'materials/'+name)
            output.write(self.artifact/'source-materials.json','materials/source-materials.json')
        self.record['sourceMaterialsSHA256'] = dependencies.sha256(archive)
        self.record['files'] = {str(path.relative_to(self.artifact)):dependencies.sha256(path) for path in self.artifact.rglob('*') if path.is_file() and path.name != 'own-build.json'}
        (self.artifact/'own-build.json').write_text(json.dumps(self.record))

    def inspect(self): return dependencies.inspect_own_artifact(self.root,self.artifact,self.arch)

    def test_bundle_preserves_raw_hash_and_source_recipe_binding(self):
        package = Path(self.temp.name)/'package'
        result = dependencies.bundle_pandoc(self.root,package,self.arch,Path('/unused'),self.artifact)
        self.assertEqual(dependencies.sha256(package/'bin/pandoc'),self.raw_sha)
        self.assertEqual(result['rawBinarySHA256'],self.raw_sha)
        self.assertEqual(result['producer'],'dotfiles-pinned-source-build')
        self.assertEqual(result['sourceMaterialsSHA256'],self.record['sourceMaterialsSHA256'])
        self.assertEqual(set(result['recipeSHA256']),set(dependencies.OWN_BUILD_RECIPES+['own-build-inputs.json']))
        self.assertTrue((package/'licenses/pandoc/COPYRIGHT').exists())

    def test_architecture_and_toolchain_pins_rejected(self):
        with self.assertRaisesRegex(ValueError,'architecture'):dependencies.inspect_own_artifact(self.root,self.artifact,'x86_64')
        self.record['ghcVersion'] = 'untrusted';(self.artifact/'own-build.json').write_text(json.dumps(self.record))
        with self.assertRaisesRegex(ValueError,'pins differ'):self.inspect()

    def test_raw_binary_tamper_rejected_before_copy(self):
        (self.artifact/'pandoc').write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError,'checksum differs'):self.inspect()
        self.assertFalse((Path(self.temp.name)/'package').exists())

    def test_source_archive_tamper_rejected(self):
        archive = self.artifact/self.record['sourceMaterialsArchive'];archive.write_bytes(archive.read_bytes()+b'tampered')
        with self.assertRaisesRegex(ValueError,'checksum differs'):self.inspect()

    def test_recipe_replacement_rejected_even_after_rehashing_manifest(self):
        (self.artifact/'build-pandoc-from-source.py').write_text('replaced builder')
        self.package_sources()
        with self.assertRaisesRegex(ValueError,'recipe differs'):self.inspect()

    def test_pin_snapshot_drift_rejected(self):
        pins = dict(self.pins,indexState='different');(self.artifact/'own-build-inputs.json').write_text(json.dumps(pins))
        self.package_sources()
        with self.assertRaisesRegex(ValueError,'input pins differ'):self.inspect()

    def test_standalone_validation_raw_binding_required(self):
        validation = dict(self.validation,rawBinarySHA256='0'*64)
        (self.artifact/'standalone-validation.json').write_text(json.dumps(validation));self.package_sources()
        with self.assertRaisesRegex(ValueError,'Bound standalone'):self.inspect()

    def test_zip_member_hash_checked_after_outer_archive_rehashed(self):
        archive = self.artifact/self.record['sourceMaterialsArchive']
        with zipfile.ZipFile(archive) as source: entries = {name:source.read(name) for name in source.namelist()}
        entries['materials/runtime-source-inventory.json'] = b'tampered'
        with zipfile.ZipFile(archive,'w') as output:
            for name,data in entries.items():output.writestr(name,data)
        self.record['sourceMaterialsSHA256'] = dependencies.sha256(archive)
        self.record['files'][archive.name] = self.record['sourceMaterialsSHA256']
        (self.artifact/'own-build.json').write_text(json.dumps(self.record))
        with self.assertRaisesRegex(ValueError,'member differs'):self.inspect()

    def test_fresh_standalone_validation_is_not_trusted_from_saved_status(self):
        with mock.patch.object(dependencies,'validate_source_binary',side_effect=ValueError('External runtime')):
            with self.assertRaisesRegex(ValueError,'External runtime'):self.inspect()

if __name__ == '__main__':unittest.main()
