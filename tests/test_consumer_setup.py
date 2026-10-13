#!/usr/bin/env python3
"""Check consumer profile generation without installing software or services."""
import importlib.util
from pathlib import Path
import tempfile
import tomllib
import unittest
from unittest import mock
from types import SimpleNamespace
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('consumer', ROOT/'scripts/consumer-setup.py')
consumer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(consumer)

class ConsumerTests(unittest.TestCase):
    def checked_doctor(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp)
            (source/'consumer-profile.json').write_text('{}')
            (source/'consumer-state.json').write_text('{"phase":"installed-needs-acceptance"}')
            return consumer.doctor(source)

    def test_default_scope_and_opt_in(self):
        plan = consumer.plan()
        self.assertNotIn('cask "slack"', plan['brewfile'])
        self.assertNotIn('cask "microsoft-teams"', plan['brewfile'])
        self.assertNotIn('cask "codex"', plan['brewfile'])
        self.assertIn('brew "tmux"', plan['brewfile'])
        self.assertIn('cask "slack"', consumer.plan(work_apps=True)['brewfile'])
        self.assertIn('cask "codex"', consumer.plan(agents=True)['brewfile'])
        self.assertTrue(all(project['url'].startswith('https://github.com/') for project in plan['projects']))

    def test_prepared_source_has_public_project_pins_and_no_personal_plugins(self):
        with tempfile.TemporaryDirectory() as temp:
            source = consumer.materialize(Path(temp)/'source', consumer.plan())
            data = tomllib.loads((source/'home/.chezmoidata.toml').read_text())
            self.assertEqual(data['chromeExtensions'], [])
            self.assertEqual(data['vscodeExtensions'], [])
            self.assertEqual(len(data['externalProjects']), 5)
            project_paths = {project['path'] for project in data['externalProjects']}
            pin_paths = {pin['path'] for pin in data['gitPins']}
            self.assertTrue(project_paths.issubset(pin_paths))
            self.assertTrue(all(project['url'].startswith('https://') for project in data['externalProjects']))
            self.assertIn('.agents/**', (source/'home/.chezmoiignore').read_text())
            self.assertNotIn('Microsoft Teams', (source/'home/.chezmoidata/20-preferences.yaml').read_text())
            self.assertFalse((source/'.git').exists())
            self.assertIn("codex) printf '\\n' ;;", (source/'modules/terminal-window-types/bin/tmux-session-template').read_text())
            self.assertIn('$HOME/.local/share/dotfiles-consumer/source', (source/'modules/dotfiles-manager/bin/dotfiles-manager').read_text())
            consumer.write_state(source, 'failed', 'test failure')
            self.assertIn('test failure', (source/'consumer-state.json').read_text())
            with self.assertRaises(ValueError): consumer.materialize(source, consumer.plan())
            installation = Path(temp)/'.local/share/dotfiles-consumer/source'
            installation.parent.mkdir(parents=True)
            source.rename(installation)
            with mock.patch.object(consumer.Path, 'home', return_value=Path(temp)), mock.patch.object(consumer.sys, 'platform', 'darwin'), mock.patch.object(consumer, 'doctor', return_value={'status':'installed-needs-acceptance','pendingAcceptance':['Accessibility'],'exitCode':0}):
                with mock.patch.object(consumer.sys, 'argv', ['consumer', '--resume', '--agents']), mock.patch.object(consumer.subprocess, 'run') as run:
                    with self.assertRaises(SystemExit): consumer.main()
                    run.assert_not_called()
                with mock.patch.object(consumer.sys, 'argv', ['consumer', '--resume']), mock.patch.object(consumer.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'bootstrap')):
                    with self.assertRaises(subprocess.CalledProcessError): consumer.main()
                    self.assertEqual(json.loads((installation/'consumer-state.json').read_text())['phase'], 'failed')
                with mock.patch.object(consumer.sys, 'argv', ['consumer', '--resume']), mock.patch.object(consumer.subprocess, 'run') as run:
                    consumer.main()
                    run.assert_called_once()
                    self.assertEqual(json.loads((installation/'consumer-state.json').read_text())['phase'], 'installed-needs-acceptance')
                    self.assertEqual(json.loads((installation/'consumer-doctor.json').read_text())['pendingAcceptance'], ['Accessibility'])

    def test_doctor_missing_dependency_and_failed_service_are_degraded(self):
        with mock.patch.object(consumer.shutil, 'which', side_effect=lambda command,**kwargs: None if command == 'yazi' else '/fake/'+command), mock.patch.object(consumer.Path,'is_dir',return_value=True), mock.patch.object(consumer.os.path,'isfile',return_value=True), mock.patch.object(consumer.subprocess,'run',return_value=subprocess.CompletedProcess([],1,stdout='',stderr='permission denied')):
            report = self.checked_doctor()
        self.assertEqual(report['status'],'degraded')
        self.assertEqual(report['exitCode'],1)
        self.assertIn('Missing executable: yazi',report['failures'])
        self.assertIn('Failed required service probe: yabai',report['failures'])
        self.assertIn('Accessibility',report['pendingAcceptance'])
        self.assertEqual(len(report['modules']),24)
        self.assertIn('nvim',report['dependencies'])
        self.assertIn('sesh',report['dependencies'])
        self.assertIn('Ghostty',report['applications'])
        self.assertNotIn('core.sh',report['dependencies'])
        self.assertNotIn('locks.sh',report['dependencies'])

    def test_doctor_success_still_requires_acceptance_and_timeouts_fail(self):
        def healthy_probe(arguments,**kwargs):
            return subprocess.CompletedProcess(arguments,0,stdout='[{"id":1}]' if '--displays' in arguments else 'state = running',stderr='')
        with mock.patch.object(consumer.shutil,'which',side_effect=lambda command,**kwargs:'/fake/'+command), mock.patch.object(consumer.Path,'is_dir',return_value=True), mock.patch.object(consumer.os.path,'isfile',return_value=True), mock.patch.object(consumer.subprocess,'run',side_effect=healthy_probe):
            report = self.checked_doctor()
            self.assertEqual(report['status'],'installed-needs-acceptance')
            self.assertEqual(report['exitCode'],0)
            self.assertTrue(report['pendingAcceptance'])
        with mock.patch.object(consumer.shutil,'which',side_effect=lambda command,**kwargs:'/fake/'+command), mock.patch.object(consumer.Path,'is_dir',return_value=True), mock.patch.object(consumer.os.path,'isfile',return_value=True), mock.patch.object(consumer.subprocess,'run',side_effect=subprocess.TimeoutExpired('probe',10)):
            report = self.checked_doctor()
            self.assertEqual(report['status'],'degraded')
            self.assertIsNone(report['services']['yabai']['probeStatus'])

    def test_doctor_does_not_claim_existing_personal_tools_are_consumer_install(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp)
            self.assertEqual(consumer.doctor(source)['status'],'not-installed')
            (source/'consumer-profile.json').write_text('{}')
            self.assertEqual(consumer.doctor(source)['status'],'prepared')
            consumer.write_state(source,'failed','interrupted')
            self.assertEqual(consumer.doctor(source)['status'],'failed')

    def test_orphan_preparations_are_retained_and_activation_failure_restores_source(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp); source = base/'source'
            (base/'source-preparing').mkdir(); (base/'source-preparing/incomplete').write_text('keep')
            recover = SimpleNamespace(recover=True,resume=False,rollback=False,update=False)
            consumer.mutate(recover,consumer.plan(),source)
            self.assertFalse((base/'source-preparing').exists())
            self.assertTrue(list((base/'history').glob('*/incomplete')))
            def make_profile(path,selection):
                path.mkdir()
                (path/'consumer-profile.json').write_text(json.dumps(selection))
                data = path/'home/.chezmoidata'; data.mkdir(parents=True)
                (data/'10-modules.yaml').write_text('modules:\n  todo:\n    enabled: true\n')
                (data/'20-preferences.yaml').write_text('preferences:\n  assistant: codex\n')
                return path
            make_profile(source,consumer.plan())
            (source/'version').write_text('old')
            (base/'source-next').mkdir(); (base/'source-next/interrupted').write_text('keep')
            update = SimpleNamespace(recover=False,resume=False,rollback=False,update=True)
            reports = [{'status':'degraded','exitCode':1,'failures':['missing required tool']}, {'status':'installed-needs-acceptance','exitCode':0}]
            with mock.patch.object(consumer,'materialize',side_effect=make_profile), mock.patch.object(consumer.subprocess,'run') as run, mock.patch.object(consumer,'doctor',side_effect=reports):
                with self.assertRaises(consumer.ConsumerActivationError): consumer.mutate(update,consumer.plan(),source)
                self.assertEqual(run.call_count,2)
            self.assertEqual((source/'version').read_text(),'old')
            self.assertTrue(list((base/'history').glob('*/interrupted')))
            self.assertEqual(consumer.lifecycle.read_journal(base)['outcome'],'restored-original')

    def test_resume_uses_saved_source_after_new_checkout_changes_and_degraded_is_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp)/'source'; source.mkdir()
            selection = consumer.plan()
            (source/'consumer-profile.json').write_text(json.dumps(selection))
            changed = dict(selection,brewfile='changed dependencies')
            resume = SimpleNamespace(recover=False,resume=True,rollback=False,update=False)
            with mock.patch.object(consumer.subprocess,'run') as run, mock.patch.object(consumer,'doctor',return_value={'status':'degraded','exitCode':1}):
                with self.assertRaises(consumer.ConsumerActivationError): consumer.mutate(resume,changed,source)
                self.assertEqual(run.call_args.args[0],[str(source/'bootstrap.sh')])
                self.assertEqual(json.loads((source/'consumer-state.json').read_text())['phase'],'degraded')

    def test_rollback_preserves_compatible_preferences_and_enablement(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            for name in ['source','previous']:
                path = base/name; path.mkdir()
                (path/'consumer-profile.json').write_text('{}')
                data = path/'home/.chezmoidata'; data.mkdir(parents=True)
                (data/'10-modules.yaml').write_text('modules:\n  todo:\n    enabled: '+('false' if name == 'source' else 'true')+'\n')
                (data/'20-preferences.yaml').write_text('preferences:\n  assistant: '+('claude' if name == 'source' else 'codex')+'\n')
            rollback = SimpleNamespace(recover=False,resume=False,rollback=True,update=False)
            with mock.patch.object(consumer.subprocess,'run'), mock.patch.object(consumer,'doctor',return_value={'status':'installed-needs-acceptance','exitCode':0}):
                consumer.mutate(rollback,consumer.plan(),base/'source')
            self.assertIn('enabled: false',(base/'source/home/.chezmoidata/10-modules.yaml').read_text())
            self.assertIn('assistant: claude',(base/'source/home/.chezmoidata/20-preferences.yaml').read_text())

if __name__ == '__main__': unittest.main()
