#!/usr/bin/env python3
"""Release gates reject stale/incomplete evidence; no signing credentials or desktop writes."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
import hashlib
import plistlib
import shutil
import tempfile
import os
import subprocess
import zipfile
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('release_gate', ROOT / 'scripts/verify-release.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class AcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.matrix = json.loads((ROOT / 'release/support-matrix.json').read_text())
        self.metadata = {'version': '1.0.0', 'sourceCommit': 'a' * 40, 'sha256': 'b' * 64}
        self.data = json.loads((ROOT / 'release/acceptance-template.json').read_text())
        self.data.update(version='1.0.0', sourceCommit='a' * 40)
        self.data['ci'].update(sourceCommit='a' * 40, status='passed', runURL='https://github.com/example/dotfiles/actions/runs/123')
        for value in self.data['licenses'].values():
            value.update(status='passed', evidence='Reviewed pinned notices and corresponding-source archive.')
        for device in self.data['devices']:
            device.update(macOS='13.6.1', cleanDevice=True, tester='Release tester', artifactSHA256='b' * 64)
            for section in ['desktopChecks', 'utilities', 'modules']:
                for value in device[section].values():
                    value.update(status='passed', evidence='Signed downloaded artifact exercised on clean device; recording retained.')

    def validate(self):
        gate.validate_acceptance(self.data, self.matrix, self.metadata, 'arm64')

    def test_complete_acceptance(self):
        self.validate()

    def test_template_is_blocked(self):
        self.data = json.loads((ROOT / 'release/acceptance-template.json').read_text())
        with self.assertRaises(ValueError): self.validate()

    def test_wrong_commit(self):
        self.data['sourceCommit'] = 'c' * 40
        with self.assertRaisesRegex(ValueError, 'commit'): self.validate()

    def test_wrong_ci_commit(self):
        self.data['ci']['sourceCommit'] = 'c' * 40
        with self.assertRaisesRegex(ValueError, 'CI'): self.validate()

    def test_other_artifact(self):
        self.data['devices'][0]['artifactSHA256'] = 'c' * 64
        with self.assertRaisesRegex(ValueError, 'artifact'): self.validate()

    def test_every_utility_required(self):
        for utility in self.matrix['requiredUtilities']:
            with self.subTest(utility=utility):
                record = self.data['devices'][0]['utilities'][utility]
                record['status'] = 'pending'
                with self.assertRaisesRegex(ValueError, utility): self.validate()
                record['status'] = 'passed'

    def test_every_desktop_check_required(self):
        for check in self.matrix['requiredDesktopChecks']:
            with self.subTest(check=check):
                record = self.data['devices'][0]['desktopChecks'][check]
                record['evidence'] = ''
                with self.assertRaisesRegex(ValueError, check): self.validate()
                record['evidence'] = 'Recording retained.'

    def test_license_source_required(self):
        self.data['licenses']['gpl-corresponding-source']['status'] = 'pending'
        with self.assertRaisesRegex(ValueError, 'gpl-corresponding-source'): self.validate()

    def test_no_existing_machine_acceptance(self):
        self.data['devices'][0]['cleanDevice'] = False
        with self.assertRaisesRegex(ValueError, 'Clean device'): self.validate()

    def test_supported_os_required(self):
        self.data['devices'][0]['macOS'] = '12.7'
        with self.assertRaisesRegex(ValueError, 'Unsupported macOS'): self.validate()

    def test_every_module_required(self):
        for module in self.matrix['requiredModules']:
            with self.subTest(module=module):
                record=self.data['devices'][0]['modules'][module]
                record['status']='pending'
                with self.assertRaisesRegex(ValueError, module): self.validate()
                record['status']='passed'

    def test_checked_in_module_coverage(self):
        gate.validate_support_matrix(self.matrix)
        narrowed=copy.deepcopy(self.matrix); narrowed['requiredModules'].remove('gh-create-repo')
        with self.assertRaisesRegex(ValueError, 'enabled desktop'): gate.validate_support_matrix(narrowed)

    def test_known_partial_source_is_blocked(self):
        provenance=json.loads((ROOT/'release/vendor/pandoc-source/provenance.json').read_text())
        with self.assertRaisesRegex(ValueError,'corresponding-source evidence remains incomplete'):
            gate.validate_source_materials(provenance,None)

    def test_complete_label_requires_actual_source_closure(self):
        provenance=json.loads((ROOT/'release/vendor/pandoc-source/provenance.json').read_text())
        provenance.update(completeness='complete',missingEvidence=[])
        with self.assertRaisesRegex(ValueError,'closure and both binary'):
            gate.validate_source_materials(provenance,ROOT/'dist/pandoc-source-materials.zip')

    def test_catalog_matrix_complete(self):
        ids = {json.loads(p.read_text())['id'] for p in (ROOT / 'utility-catalog').glob('*/extension.json')}
        self.assertEqual(ids, set(self.matrix['requiredUtilities']))


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'release').mkdir()
        self.matrix = json.loads((ROOT / 'release/support-matrix.json').read_text())
        (self.root / 'release/support-matrix.json').write_text(json.dumps(self.matrix))
        (self.root / 'VERSION').write_text('1.0.0-dev.1')
        shutil.copytree(ROOT / 'home/.chezmoidata', self.root / 'home/.chezmoidata')
        shutil.copytree(ROOT / 'utility-catalog', self.root / 'utility-catalog')
        for manifest in (ROOT / 'modules').glob('*/module.yaml'):
            target=self.root / 'modules' / manifest.parent.name; target.mkdir(parents=True)
            shutil.copy2(manifest, target / 'module.yaml')
        for document in ['LICENSE', 'NOTICE', 'THIRD_PARTY_NOTICES.md']:
            (self.root / document).write_text('fixture notice')
        self.dist = self.root / 'dist'; self.dist.mkdir()
        self.archive = self.dist / 'Dotfiles-1.0.0-dev.1.zip'
        self.archive.write_bytes(b'fixture archive')
        digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.archive.with_suffix('.zip.sha256').write_text(f'{digest}  {self.archive.name}\n')
        self.metadata = dict(sourceDirty=False,sourceCommit='a'*40,version='1.0.0-dev.1',signing='developer-id',architecture='arm64',supportMatrix=self.matrix,archive=self.archive.name,sha256=digest)
        (self.root / 'scripts').mkdir()
        shutil.copy2(ROOT / 'scripts/bundled-dependencies.py', self.root / 'scripts/bundled-dependencies.py')
        shutil.copytree(ROOT / 'release/vendor/pandoc', self.root / 'release/vendor/pandoc')
        version='3.12.1'
        self.metadata['minimumMacOS']='13.0'
        self.metadata['dependencies']=[dict(name='pandoc',version=version,architecture='arm64',source=f'https://github.com/jgm/pandoc/tree/{version}',binaryURL=f'https://github.com/jgm/pandoc/releases/download/{version}/pandoc-{version}-arm64-macOS.zip',archiveSHA256='c2146cf33a583f3ac93eccddf1bb662371d5cfcce1aad1c87ad860cca1435d46',license='GPL-2.0-or-later',bundledSHA256=hashlib.sha256(b'fixture binary').hexdigest())]
        self.archived_version='1.0.0-dev.1'; self.archived_minimum='13.0'; self.wrong_binary=None; self.tamper_dependency=False; self.tamper_notice=False
        self.dirty = False; self.signature = 'Authority=Developer ID Application: Fixture\nTeamIdentifier=FIXTURE'

    def fake_run(self, *args):
        if args[0] == 'git':
            return 'modified' if args[-1] == '--porcelain' and self.dirty else ('' if args[-1] == '--porcelain' else 'a'*40)
        if args[0] == 'ditto':
            resources = Path(args[-1]) / 'Dotfiles.app/Contents/Resources'
            resources.mkdir(parents=True)
            (resources.parent / 'Info.plist').write_bytes(plistlib.dumps(dict(DotfilesReleaseVersion=self.archived_version,CFBundleShortVersionString='1.0.0',LSMinimumSystemVersion=self.archived_minimum)))
            dependencies=copy.deepcopy(self.metadata['dependencies'])
            if self.tamper_dependency: dependencies[0]['archiveSHA256']='c'*64
            (resources / 'dependencies.json').write_text(json.dumps(dependencies))
            (resources / 'support-matrix.json').write_text(json.dumps(self.matrix))
            for utility in self.matrix['requiredUtilities']:
                package = resources / 'Utilities' / (utility + '.dotutility'); package.mkdir(parents=True)
                (package / 'extension.json').write_text(json.dumps({'id':utility}))
            package=resources / 'Utilities/dotfiles.markdown-clipboard.dotutility'
            (package / 'bin').mkdir(); (package / 'bin/pandoc').write_bytes(b'fixture binary')
            shutil.copytree(self.root / 'release/vendor/pandoc',package / 'licenses/pandoc')
            if self.tamper_notice: (package / 'licenses/pandoc/COPYING').write_text('changed')
            for document in ['LICENSE', 'NOTICE', 'THIRD_PARTY_NOTICES.md']:
                shutil.copy2(self.root / document, resources / document)
        if args[0] == 'codesign' and args[1] == '-d': return self.signature
        if args[0] == 'lipo': return 'x86_64' if self.wrong_binary and str(args[-1]).endswith(self.wrong_binary) else 'arm64'
        return ''

    def verify(self):
        (self.dist / 'build.json').write_text(json.dumps(self.metadata))
        with mock.patch.object(gate, 'ROOT', self.root), mock.patch.object(gate, 'run', self.fake_run), mock.patch('sys.argv', ['verify-release.py', '--candidate', '--dist', str(self.dist)]):
            gate.main()

    def test_complete_candidate_fixture(self): self.verify()

    def test_dirty_build(self):
        self.metadata['sourceDirty'] = True
        with self.assertRaisesRegex(ValueError, 'Dirty-source'): self.verify()

    def test_dirty_checkout(self):
        self.dirty = True
        with self.assertRaisesRegex(ValueError, 'clean checkout'): self.verify()

    def test_checksum_tampering(self):
        self.archive.write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'checksum'): self.verify()

    def test_adhoc_signature(self):
        self.signature = 'Signature=adhoc'
        with self.assertRaisesRegex(ValueError, 'certificate'): self.verify()

    def test_remote_ci_confirmation(self):
        ci={'runURL':'https://github.com/example/dotfiles/actions/runs/123'}
        run={'head_sha':'a'*40,'status':'completed','conclusion':'success','path':'.github/workflows/validate.yml'}
        jobs=[{'jobs':[{'name':n,'conclusion':'success'} for n in ['Native app and extension contracts','Existing integration contracts']]}]
        with mock.patch.object(gate,'run',side_effect=[json.dumps(run),json.dumps(jobs)]): gate.verify_remote_ci(ci,'a'*40)
        run['head_sha']='b'*40
        with mock.patch.object(gate,'run',return_value=json.dumps(run)):
            with self.assertRaisesRegex(ValueError,'exact candidate'): gate.verify_remote_ci(ci,'a'*40)

    def test_archived_plist_version(self):
        self.archived_version='0.9.0'
        with self.assertRaisesRegex(ValueError, 'plist release'): self.verify()

    def test_archived_minimum_os(self):
        self.archived_minimum='14.0'
        with self.assertRaisesRegex(ValueError, 'minimum macOS'): self.verify()

    def test_archived_dependencies(self):
        self.tamper_dependency=True
        with self.assertRaisesRegex(ValueError, 'dependencies differ'): self.verify()

    def test_source_dependency_pin(self):
        self.metadata['dependencies'][0]['archiveSHA256']='c'*64
        with self.assertRaisesRegex(ValueError, 'source archive pin'): self.verify()

    def test_signed_dependency_digest(self):
        self.metadata['dependencies'][0]['bundledSHA256']='c'*64
        with self.assertRaisesRegex(ValueError, 'dependency digest'): self.verify()

    def test_dependency_notices(self):
        self.tamper_notice=True
        with self.assertRaisesRegex(ValueError, 'notices differ'): self.verify()

    def test_all_binary_architectures(self):
        for binary in ['dotfiles-service-runner','bin/pandoc','bin/markdown-clipboard']:
            self.wrong_binary=binary
            with self.subTest(binary=binary):
                with self.assertRaisesRegex(ValueError,'architecture differs'): self.verify()

    def test_final_requires_paired_artifacts(self):
        with mock.patch('sys.argv',['verify-release.py','--dist',str(self.dist)]):
            with self.assertRaisesRegex(ValueError,'every supported architecture'): gate.main()

    def test_policy_tampering(self):
        self.metadata['supportMatrix'] = {}
        with self.assertRaisesRegex(ValueError, 'support matrix'): self.verify()


class CompleteSourceMaterialsTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.archive=Path(self.temp.name)/'materials.zip'
        self.files={'source.tar.gz':b'fixture source','dep.tar.gz':b'fixture dependency','freeze.txt':b'exact package constraints','plan.json':b'fixture plan'}
        checksums={name:hashlib.sha256(data).hexdigest() for name,data in self.files.items()}
        self.provenance=dict(completeness='complete',missingEvidence=[],sourceCommit='a'*40,sourceSHA256=checksums['source.tar.gz'],officialBinaryArchiveSHA256={'arm64':'b'*64,'x86_64':'c'*64},resolvedSourceClosure=[dict(name='fixture-library',version='1.0',license='BSD-3-Clause',sourceURL='https://upstream.example/source',archive='dep.tar.gz',sha256=checksums['dep.tar.gz'])],binaryBuildBindings={arch:dict(archiveSHA256=checksum,sourceCommit='a'*40,buildExecutionURL='https://github.com/example/build/actions/runs/1',ghcVersion='9.10.3',cabalVersion='3.14.2.0',macOSSDK='15.5',indexState='2026-10-08T00:00:00Z',freezeFile='freeze.txt',planFile='plan.json',sourcePackages=['fixture-library']) for arch,checksum in {'arm64':'b'*64,'x86_64':'c'*64}.items()})
        self.record=dict(self.provenance,files=checksums,assembledSourceArchive='source.tar.gz')
        self.write_archive()

    def write_archive(self):
        with zipfile.ZipFile(self.archive,'w') as output:
            for name,data in self.files.items():output.writestr('materials/'+name,data)
            output.writestr('materials/materials-manifest.json',json.dumps(self.record))

    def test_complete_bound_materials_fixture(self):gate.validate_source_materials(self.provenance,self.archive)

    def test_changed_root_provenance(self):
        self.provenance['sourceCommit']='d'*40
        with self.assertRaisesRegex(ValueError,'differs from checked-in'):gate.validate_source_materials(self.provenance,self.archive)

    def test_source_material_bytes_tampered(self):
        self.files['dep.tar.gz']=b'changed';self.write_archive()
        with self.assertRaisesRegex(ValueError,'material digest differs'):gate.validate_source_materials(self.provenance,self.archive)


class NotarizationSnapshotTests(unittest.TestCase):
    def test_staples_submitted_archive_not_mutable_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); (root / 'scripts').mkdir(); dist=root / 'dist'; dist.mkdir(); tools=root / 'tools'; tools.mkdir()
            shutil.copy2(ROOT / 'scripts/notarize-app.sh',root / 'scripts/notarize-app.sh')
            (root / 'scripts/verify-release.py').write_text("import sys,zipfile\nfrom pathlib import Path\np=Path(sys.argv[sys.argv.index('--dist')+1])\nassert zipfile.ZipFile(p/'Dotfiles-1.0.0-dev.1.zip').read('Dotfiles.app/contents.txt')==b'submitted'\n")
            (root / 'VERSION').write_text('1.0.0-dev.1')
            (dist / 'build.json').write_text('{}')
            archive=dist / 'Dotfiles-1.0.0-dev.1.zip'
            with zipfile.ZipFile(archive,'w') as output: output.writestr('Dotfiles.app/contents.txt',b'submitted')
            archive.with_suffix('.zip.sha256').write_text('fixture')
            (dist / 'Dotfiles.app').mkdir(); (dist / 'Dotfiles.app/contents.txt').write_text('mutated app')
            helper = r'''#!/usr/bin/env python3
import sys,json,zipfile,shutil
from pathlib import Path
name=Path(sys.argv[0]).name; args=sys.argv[1:]
if name=='xcrun':
    if args[:2]==['notarytool','submit']:
        assert zipfile.ZipFile(args[2]).read('Dotfiles.app/contents.txt')==b'submitted'
        print(json.dumps({'status':'Accepted','id':'fixture-receipt'}))
    elif args[:2]==['stapler','staple']:
        app=Path(args[2]); assert (app/'contents.txt').read_text()=='submitted'
        (app/'stapled.txt').write_text('accepted')
elif name=='ditto':
    if args[:2]==['-x','-k']: zipfile.ZipFile(args[2]).extractall(args[3])
    elif args[0]=='-c':
        source=Path(args[-2])
        with zipfile.ZipFile(args[-1],'w') as output:
            for path in source.rglob('*'):
                if path.is_file(): output.write(path,str(path.relative_to(source.parent)))
    else: shutil.copytree(args[0],args[1],dirs_exist_ok=True)
'''
            for tool in ['xcrun','ditto','spctl']:
                path=tools / tool; path.write_text(helper);path.chmod(0o755)
            env=dict(os.environ,PATH=str(tools)+os.pathsep+os.environ['PATH'],DOTFILES_NOTARY_PROFILE='fixture')
            result=subprocess.run(['bash',str(root / 'scripts/notarize-app.sh')],env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            with zipfile.ZipFile(archive) as output:
                self.assertEqual(output.read('Dotfiles.app/contents.txt'),b'submitted')
                self.assertEqual(output.read('Dotfiles.app/stapled.txt'),b'accepted')
            self.assertEqual((dist / 'Dotfiles.app/contents.txt').read_text(),'submitted')
            metadata=json.loads((dist / 'build.json').read_text())
            self.assertEqual(metadata['notarizationID'],'fixture-receipt')
            self.assertEqual(metadata['sha256'],hashlib.sha256(archive.read_bytes()).hexdigest())


if __name__ == '__main__': unittest.main()
