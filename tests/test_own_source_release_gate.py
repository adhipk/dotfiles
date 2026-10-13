#!/usr/bin/env python3
"""Verify closed source records without running architecture-specific binaries."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock
import zipfile
import warnings

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('gate',ROOT/'scripts/verify-release.py')
gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)


class OwnSourceGateTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)/'root';self.archive=Path(self.temp.name)/'source.zip'
        (self.root/'scripts').mkdir(parents=True);(self.root/'release/vendor/pandoc-source').mkdir(parents=True)
        self.pins=json.loads((ROOT/'release/vendor/pandoc-source/own-build-inputs.json').read_text())
        self.payload={'pandoc-source.tar.gz':b'fixture source','ghc-source.tar.xz':b'fixture compiler source','closure/packages/example.tar.gz':b'fixture Hackage source','closure/revisions/example.cabal':b'license: MIT','closure/licenses/LICENSE':b'Fixture permission notice'}
        sha=lambda name:hashlib.sha256(self.payload[name]).hexdigest()
        self.pins.update(pandocSourceSHA256=sha('pandoc-source.tar.gz'),ghcSourceSHA256=sha('ghc-source.tar.xz'))
        (self.root/'release/vendor/pandoc-source/own-build-inputs.json').write_text(json.dumps(self.pins))
        self.plan={'install-plan':[{'type':'pre-existing','pkg-name':'base','pkg-version':'4.20.2.0'},{'type':'configured','pkg-name':'pandoc-cli','pkg-version':'3.12.1','pkg-src':{'type':'local'}},{'type':'configured','pkg-name':'example','pkg-version':'1.0','pkg-src':{'type':'repo-tar'},'pkg-src-sha256':sha('closure/packages/example.tar.gz'),'pkg-cabal-sha256':sha('closure/revisions/example.cabal')}]}
        package=dict(name='example',version='1.0',id='example-1.0',sha256=sha('closure/packages/example.tar.gz'),archive='packages/example.tar.gz',selectedCabalSHA256=sha('closure/revisions/example.cabal'),cabalRevisionFile='revisions/example.cabal',license='MIT',licenseFiles=['licenses/LICENSE'])
        self.closure={'resolvedSourceClosure':[package],'preExistingGHCUnits':[{'name':'base','version':'4.20.2.0'}],'planSHA256':hashlib.sha256(json.dumps(self.plan,sort_keys=True).encode()).hexdigest()}
        self.arch='x86_64';self.dependency=dict(producer='dotfiles-pinned-source-build',architecture=self.arch,rawBinarySHA256='a'*64,sourceCommit=self.pins['pandocCommit'],ghcVersion=self.pins['ghcVersion'],cabalVersion=self.pins['cabalVersion'],indexState=self.pins['indexState'],toolchain=self.pins['toolchains'][self.arch],captureStatus='source-captured-review-required',buildExecutionURL='https://github.com/adhipk/dotfiles/actions/runs/123',recipeSHA256={})
        for recipe in gate.OWN_RECIPES:
            shutil.copy2(ROOT/'scripts'/recipe,self.root/'scripts'/recipe);self.payload[recipe]=(ROOT/'scripts'/recipe).read_bytes();self.dependency['recipeSHA256'][recipe]=sha(recipe)
        self.payload['own-build-inputs.json']=json.dumps(self.pins,indent=2).encode();self.dependency['recipeSHA256']['own-build-inputs.json']=sha('own-build-inputs.json')
        self.payload['toolchain.json']=json.dumps({'inputs':self.pins['toolchains'][self.arch]}).encode()
        self.payload['runtime-source-inventory.json']=json.dumps({'ghc':{'bootLibraries':{'base':{}},'embeddedGMPAndLibffiSources':[{'path':'gmp-source.tar.gz'},{'path':'libffi-source.tar.gz'}]}}).encode()
        self.payload['standalone-validation.json']=json.dumps({'rawBinarySHA256':'a'*64,'htmlToGFM':'passed','isolatedEnvironment':'passed'}).encode()
        for name in ['plan.json','cabal.project.freeze','captured-repository.freeze','local-source-map.json','ghc-info.txt','ghc-pkg-global.txt']:self.payload[name]=b'fixture reconstruction input'
        self.record=dict(producer='dotfiles-pinned-source-build',architecture=self.arch,pandocVersion=self.pins['pandocVersion'],sourceCommit=self.pins['pandocCommit'],binarySHA256='a'*64,ghcVersion=self.pins['ghcVersion'],cabalVersion=self.pins['cabalVersion'],indexState=self.pins['indexState'],captureStatus='source-captured-review-required',buildExecutionURL=self.dependency['buildExecutionURL'],macOSSDK='15.5',xcodeVersion='Xcode 16.4\nBuild version 16F6')
        self.write_archive()

    def write_archive(self):
        self.payload['captured-repository-plan.json']=json.dumps(self.plan).encode();self.payload['closure/closure.json']=json.dumps(self.closure).encode()
        self.record.update(resolvedSourceClosure=self.closure['resolvedSourceClosure'],preExistingGHCUnits=self.closure['preExistingGHCUnits'],files={name:hashlib.sha256(data).hexdigest() for name,data in self.payload.items()})
        with zipfile.ZipFile(self.archive,'w') as output:
            for name,data in self.payload.items():output.writestr('materials/'+name,data)
            output.writestr('materials/source-materials.json',json.dumps(self.record))
        self.dependency['sourceMaterialsSHA256']=hashlib.sha256(self.archive.read_bytes()).hexdigest()

    def validate(self):
        with mock.patch.object(gate,'ROOT',self.root):return gate.validate_own_source_materials(self.dependency,self.archive,self.arch)

    def test_intel_source_can_be_verified_without_executing_binary_on_arm(self):
        with mock.patch.object(gate,'run',side_effect=AssertionError('No native binary execution permitted')):self.validate()

    def test_duplicate_zip_member_rejected_after_outer_rehash(self):
        with warnings.catch_warnings():
            warnings.simplefilter('ignore',UserWarning)
            with zipfile.ZipFile(self.archive,'a') as output:output.writestr('materials/plan.json',self.payload['plan.json'])
        self.dependency['sourceMaterialsSHA256']=hashlib.sha256(self.archive.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError,'Duplicate own source ZIP'):self.validate()

    def test_external_repository_cannot_supply_source_provenance(self):
        with mock.patch.object(gate,'run',side_effect=AssertionError('Do not contact unrelated repo')):
            with self.assertRaisesRegex(ValueError,'candidate project repository'):
                gate.verify_source_build_ci('https://github.com/external/repo/actions/runs/123',self.arch,self.dependency)

    def test_source_archive_byte_tamper(self):
        self.archive.write_bytes(self.archive.read_bytes()+b'changed')
        with self.assertRaisesRegex(ValueError,'archive checksum'):self.validate()

    def test_root_recipe_change_rejected(self):
        (self.root/'scripts/build-pandoc-from-source.py').write_text('changed implementation')
        with self.assertRaisesRegex(ValueError,'builder recipe differs'):self.validate()

    def test_planned_dependency_omission(self):
        self.closure['resolvedSourceClosure']=[];self.write_archive()
        with self.assertRaisesRegex(ValueError,'omits planned'):self.validate()

    def test_selected_revision_binding(self):
        self.closure['resolvedSourceClosure'][0]['selectedCabalSHA256']='b'*64;self.write_archive()
        with self.assertRaisesRegex(ValueError,'Cabal revision differs'):self.validate()

    def test_boot_source_coverage(self):
        self.payload['runtime-source-inventory.json']=json.dumps({'ghc':{'bootLibraries':{},'embeddedGMPAndLibffiSources':[]}}).encode();self.write_archive()
        with self.assertRaisesRegex(ValueError,'every observed boot'):self.validate()

    def test_raw_binary_binding(self):
        self.dependency['rawBinarySHA256']='b'*64
        with self.assertRaisesRegex(ValueError,'source/binary identity'):self.validate()

    def test_remote_run_requires_actual_immutable_artifact_bytes(self):
        dependency=dict(self.dependency,rawBinarySHA256=hashlib.sha256(b'raw').hexdigest(),sourceMaterialsSHA256=hashlib.sha256(b'source zip').hexdigest())
        remote={'status':'completed','conclusion':'success','path':'.github/workflows/pandoc-source-build.yml','head_sha':'c'*40}
        jobs=[{'jobs':[{'name':name,'conclusion':'success'} for name in ['Own Pandoc source build (arm64)','Own Pandoc source build (x86_64)']]}]
        def run(*args):
            if args[:2]==('gh','api'):return json.dumps(jobs if '/jobs?' in args[-1] else remote)
            directory=Path(args[args.index('--dir')+1]);artifact=directory/'pandoc-artifacts';artifact.mkdir()
            (artifact/'pandoc').write_bytes(b'raw');(artifact/'pandoc-own-source-x86_64.zip').write_bytes(b'source zip')
            (artifact/'own-build.json').write_text(json.dumps({'architecture':'x86_64','producer':'dotfiles-pinned-source-build','binarySHA256':dependency['rawBinarySHA256'],'sourceMaterialsSHA256':dependency['sourceMaterialsSHA256'],'sourceMaterialsArchive':'pandoc-own-source-x86_64.zip'}));return ''
        with mock.patch.object(gate,'run',run):gate.verify_source_build_ci(dependency['buildExecutionURL'],'x86_64',dependency)
        dependency['rawBinarySHA256']='d'*64
        with mock.patch.object(gate,'run',run):
            with self.assertRaisesRegex(ValueError,'Remote raw binary bytes'):gate.verify_source_build_ci(dependency['buildExecutionURL'],'x86_64',dependency)


if __name__=='__main__':unittest.main()
