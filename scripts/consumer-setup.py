#!/usr/bin/env python3
"""Prepare a reproducible desktop profile without the author's accounts or SSH."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import importlib.util
import fcntl

ROOT = Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location('consumer_lifecycle', ROOT/'scripts/consumer-lifecycle.py')
lifecycle = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lifecycle)
WORK_CASKS = {'microsoft-teams', 'slack'}
AGENT_CASKS = {'codex', 'codex-app'}

def plan(agents=False, work_apps=False):
    # macOS ships Python 3.9 on some supported releases. Avoid a bootstrap-time
    # tomllib dependency before Homebrew provisions the modern Python runtime.
    projects = []
    for section in re.findall(r'\[\[externalProjects\]\](.*?)(?=\[\[|\Z)', (ROOT / 'home/.chezmoidata.toml').read_text(), re.S):
        fields = dict(re.findall(r'^(name|url|path) = "([^"]+)"', section, re.M))
        if set(fields) != {'name','url','path'}: raise ValueError('Invalid external project declaration')
        if fields['name'] == 'raycast-lucide-excalidraw': continue
        fields['url'] = re.sub(r'^git@github.com:', 'https://github.com/', fields['url'])
        if not fields['url'].startswith('https://github.com/'): raise ValueError('Consumer projects require public HTTPS URLs')
        projects.append(fields)
    brew = []
    for line in (ROOT / 'Brewfile').read_text().splitlines():
        match = re.match(r'cask "([^"]+)"', line)
        if match and ((match[1] in WORK_CASKS and not work_apps) or (match[1] in AGENT_CASKS and not agents)):
            continue
        brew.append(line)
    return {'profile':'consumer-desktop', 'agents':agents, 'workApps':work_apps,
            'brewfile':'\n'.join(brew)+'\n', 'projects':projects,
            'capabilities':['app focus','windows and spaces','scratchpads','tmux and sessions',
                            'terminal window types','Yazi','shortcut guide','settings control panel',
                            'notifications','explicit timer','Markdown clipboard','tasks',
                            'text to speech','unescape','GitHub repository creation','default apps','qutebrowser'],
            'formulaTrust':['asmvik/formulae/yabai','asmvik/formulae/skhd','felixkratz/formulae/borders'],
            'permissions':['Accessibility: yabai, skhd, Ghostty',
                           'Karabiner: DriverKit extension and Input Monitoring',
                           'Space scripting: optional SIP setup followed by setup-yabai-sa'],
            'changes':['Installs Brewfile packages and pinned HTTPS utility projects under ~/projects',
                       'Applies shell, terminal, editor, keyboard and desktop settings with Chezmoi',
                       'Starts yabai/skhd; Markdown clipboard watcher follows module lifecycle'],
            'accounts':'No credentials included. Agent and work application installs are opt-in.'}

def materialize(destination, selection):
    if destination.exists():
        raise ValueError(f'Refusing to overwrite existing profile source: {destination}')
    shutil.copytree(ROOT, destination, ignore=shutil.ignore_patterns('.git', '.build', 'dist', 'test-results', '__pycache__', '.DS_Store'))
    (destination / 'Brewfile').write_text(selection['brewfile'])
    datafile = destination / 'home/.chezmoidata.toml'
    text = datafile.read_text().replace('git@github.com:', 'https://github.com/')
    # Browser/editor plugin and extension lists are personal, not utility prerequisites.
    text = re.sub(r'vscodeExtensions = \[.*?\]', 'vscodeExtensions = []', text, count=1, flags=re.S)
    text = re.sub(r'\[\[chromeExtensions\]\].*?(?=\[\[|\Z)', '', text, flags=re.S)
    text = re.sub(r'\[\[gitPins\]\]\nid = "chezmoi-git:\.local/share/(chrome|raycast)-extensions/.*?(?=\[\[|\Z)', '', text, flags=re.S)
    text = re.sub(r'\[\[externalProjects\]\]\nname = "raycast-lucide-excalidraw".*?(?=\[\[|\Z)', '', text, flags=re.S)
    # Template ranges require these empty arrays even when optional plugins are absent.
    text = 'chromeExtensions = []\n' + text
    datafile.write_text(text)
    preferences = destination / 'home/.chezmoidata/20-preferences.yaml'
    content = preferences.read_text().replace('"Microsoft Teams"', '"Finder"').replace('"Slack"', '"Notes"')
    if selection['workApps']: content = preferences.read_text()
    preferences.write_text(content)
    if not selection['agents']:
        ignore = destination / 'home/.chezmoiignore'
        existing = ignore.read_text() if ignore.exists() else ''
        ignore.write_text(existing + '\n# Consumer profile: agent configuration is opt-in.\n.agents\n.agents/**\n.codex\n.codex/**\n.claude\n.claude/**\n')
        # Preserve terminal window slots without launching an absent assistant.
        template = destination / 'modules/terminal-window-types/bin/tmux-session-template'
        content = template.read_text()
        needle = 'codex) dotfiles_pref assistant codex ;;'
        if needle not in content: raise ValueError('Assistant window template changed; review consumer fallback')
        template.write_text(content.replace(needle, "codex) printf '\\n' ;;"))
        window_manifest = destination/'modules/terminal-window-types/module.yaml'
        window_manifest.write_text(window_manifest.read_text().replace('    - codex\n', ''))
    (destination / 'consumer-profile.json').write_text(json.dumps(selection, indent=2)+'\n')
    manager = destination/'modules/dotfiles-manager/bin/dotfiles-manager'
    manager.write_text(manager.read_text().replace('${DOTFILES_MANAGER_ROOT:-$HOME/dotfiles}', '${DOTFILES_MANAGER_ROOT:-$HOME/.local/share/dotfiles-consumer/source}'))
    manager_ui = destination/'modules/dotfiles-manager/bin/dotfiles-manager-ui'
    manager_ui.write_text(manager_ui.read_text().replace('str(Path.home() / "dotfiles")', 'str(Path.home() / ".local/share/dotfiles-consumer/source")'))
    return destination

def write_state(destination, phase, error=None):
    state = {'phase':phase, 'error':error}
    temporary = destination / 'consumer-state.json.tmp'
    temporary.write_text(json.dumps(state, indent=2)+'\n')
    temporary.replace(destination / 'consumer-state.json')

class ConsumerActivationError(RuntimeError):
    pass

def doctor(source=None, activation_probe=False):
    source = source or Path.home()/'.local/share/dotfiles-consumer/source'
    inventory_root = source if (source/'home/.chezmoidata/10-modules.yaml').exists() else ROOT
    flags = (inventory_root/'home/.chezmoidata/10-modules.yaml').read_text()
    enabled = dict(re.findall(r'^  (\w+):\n    enabled: (true|false)', flags, re.M))
    modules = {}
    libraries = set()
    commands = {'brew','chezmoi','python3','tmux','git','jq','yq','uv','nvim','yazi','sesh','borders','pandoc'}
    for manifest in sorted((inventory_root/'modules').glob('*/module.yaml')):
        text = manifest.read_text()
        key = re.search(r'^dataKey: modules\.(\w+)$', text, re.M)
        if not key or enabled.get(key[1]) != 'true': continue
        requirements = re.search(r'^requires:\n(.*?)(?=^[^ \n]|\Z)', text, re.M|re.S)
        executable_block = re.search(r'^  executables:\n(.*?)(?=^  [^ ]|\Z)', requirements[1] if requirements else '', re.M|re.S)
        tools = re.findall(r'^    - ([a-zA-Z0-9_.+-]+)$', executable_block[1] if executable_block else '', re.M)
        library_block = re.search(r'^  libraries:\n(.*?)(?=^  [^ ]|\Z)', requirements[1] if requirements else '', re.M|re.S)
        required_libraries = re.findall(r'^    - ([a-zA-Z0-9_.+-]+)$', library_block[1] if library_block else '', re.M)
        libraries.update(required_libraries)
        commands.update(tools)
        module_commands = re.search(r'^commands:\n(.*?)(?=^[^ \n]|\Z)', text, re.M|re.S)
        for entry in re.split(r'^  - name: ', module_commands[1] if module_commands else '', flags=re.M)[1:]:
            target = re.search(r'^    target: (~/bin/[^\n]+)$', entry, re.M)
            if target: commands.add(entry.splitlines()[0])
        modules[manifest.parent.name] = {'requiredExecutables':tools,'requiredLibraries':required_libraries,'acceptance':'Desktop behavior not verified'}
    tool_path = os.pathsep.join([str(Path.home()/'bin'), '/opt/homebrew/bin','/usr/local/bin',os.environ.get('PATH','')])
    app_names = {'Ghostty':'Ghostty.app','Chrome':'Google Chrome.app','Karabiner':'Karabiner-Elements.app',
                 'Qutebrowser':'qutebrowser.app','Raycast':'Raycast.app','VSCodium':'VSCodium.app'}
    selected = json.loads((source/'consumer-profile.json').read_text()) if (source/'consumer-profile.json').exists() else {}
    if selected.get('agents'):
        commands.add('codex'); app_names['Codex'] = 'Codex.app'
    if selected.get('workApps'):
        app_names.update({'Teams':'Microsoft Teams.app','Slack':'Slack.app'})
    result = {'dependencies':{command:shutil.which(command, path=tool_path) for command in sorted(commands)},
              'applications':{name:next((str(root/app) for root in [Path('/Applications'),Path.home()/'Applications'] if (root/app).is_dir()),None) for name,app in app_names.items()},
              'modules':modules,
              'libraries':{name:os.path.isfile(str(Path.home()/'.local/lib/dotfiles'/name)) for name in sorted(libraries)},
              'permissions':{'Accessibility':'Requires manual System Settings verification',
                             'Input Monitoring':'Requires manual System Settings verification',
                             'SIP setup':'Requires explicit user review; never altered by setup'}, 'services':{}}
    for command in ['yabai','skhd']:
        executable = shutil.which(command, path=tool_path)
        if executable:
            arguments = [executable,'-m','query','--displays'] if command == 'yabai' else ['/bin/launchctl','print',f'gui/{os.getuid()}/com.koekeishiya.skhd']
            try:
                check = subprocess.run(arguments,capture_output=True,text=True,timeout=10)
                probe_status = check.returncode
                if probe_status == 0:
                    if command == 'yabai':
                        try:
                            displays = json.loads(check.stdout)
                            if not isinstance(displays,list) or not displays: probe_status = 1
                        except (ValueError,TypeError): probe_status = 1
                    elif 'state = running' not in check.stdout: probe_status = 1
                result['services'][command] = {'probeStatus':probe_status,
                    'meaning':'Display query' if command == 'yabai' else 'launchd registration; actual shortcut behavior still requires acceptance'}
            except (OSError, subprocess.TimeoutExpired) as error:
                result['services'][command] = {'probeStatus':None,'error':str(error)}
        else: result['services'][command] = {'probeStatus':None,'error':'Executable missing'}
    result['failures'] = ([f'Missing executable: {name}' for name,path in result['dependencies'].items() if path is None]
                          + [f'Missing application: {name}' for name,path in result['applications'].items() if path is None]
                          + [f'Missing managed library: {name}' for name,available in result['libraries'].items() if not available]
                          + [f'Failed required service probe: {name}' for name,probe in result['services'].items() if probe['probeStatus'] != 0])
    result['status'] = 'degraded' if result['failures'] else 'installed-needs-acceptance'
    marker = source/'consumer-profile.json'
    state_file = source/'consumer-state.json'
    phase = json.loads(state_file.read_text()).get('phase') if state_file.exists() else None
    if not marker.exists():
        result['status'] = 'not-installed'; result['failures'].insert(0,'Consumer profile is not installed')
    elif not activation_probe and phase not in ['installed','degraded','installed-needs-acceptance']:
        result['status'] = 'failed' if phase == 'failed' else 'prepared'
        result['failures'].insert(0,'Consumer installation has not completed; resume the saved profile')
    result['pendingAcceptance'] = list(result['permissions']) + ['Desktop shortcuts, service recovery, upgrades and uninstall']
    result['exitCode'] = 1 if result['failures'] else 0
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', action='store_true', help='Print the read-only installation plan (default)')
    parser.add_argument('--agents', action='store_true', help='Include Codex and shared personal agent guidance')
    parser.add_argument('--work-apps', action='store_true', help='Include Teams and Slack installs/app slots')
    parser.add_argument('--apply', action='store_true', help='Install the reviewed desktop profile into this account')
    parser.add_argument('--resume', action='store_true', help='Resume a prepared or interrupted installation with the same options')
    parser.add_argument('--doctor', action='store_true', help='Read-only dependency and permission report')
    parser.add_argument('--update', action='store_true', help='Apply this checkout as a new desktop source, preserving preferences')
    parser.add_argument('--rollback', action='store_true', help='Restore and apply the retained prior desktop source')
    parser.add_argument('--recover', action='store_true', help='Restore the original source after an interrupted transition')
    parser.add_argument('--prepare', type=Path, help='Write a reviewable profile source only; no installs')
    args = parser.parse_args()
    if sum([bool(args.plan), bool(args.apply or args.resume), bool(args.prepare), bool(args.doctor), bool(args.update), bool(args.rollback), bool(args.recover)]) > 1:
        parser.error('Choose one consumer operation')
    if args.doctor:
        report = doctor()
        print(json.dumps(report, indent=2))
        raise SystemExit(report['exitCode'])
    selection = plan(args.agents, args.work_apps)
    if args.prepare:
        print(materialize(args.prepare.resolve(), selection)); return
    if not any([args.apply,args.resume,args.update,args.rollback,args.recover]):
        print(json.dumps(selection, indent=2)); return
    if sys.platform != 'darwin': raise SystemExit('Consumer desktop setup requires macOS')
    destination = Path.home() / '.local/share/dotfiles-consumer/source'
    base = destination.parent
    base.mkdir(parents=True, exist_ok=True)
    with (base/'.lock').open('a') as lock:
        try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: raise SystemExit('Another consumer setup operation is active')
        return mutate(args, selection, destination)

def mutate(args, selection, destination):
    base = destination.parent
    def install(source):
        env = dict(os.environ, DOTFILES_CONSUMER_PROFILE='1', DOTFILES_DIR=str(source))
        write_state(source, 'installing')
        try: subprocess.run([str(source/'bootstrap.sh')], env=env, check=True)
        except Exception as error:
            write_state(source, 'failed', str(error)); raise
        report = doctor(source, activation_probe=True)
        (source/'consumer-doctor.json').write_text(json.dumps(report, indent=2)+'\n')
        write_state(source, report['status'])
        if report['exitCode']:
            raise ConsumerActivationError(f'Consumer activation failed required checks. Review {source / "consumer-doctor.json"}; permissions and dependencies need diagnosis.')
    state = lifecycle.read_journal(base)
    retained = []
    stages = ['source-preparing'] + (['source-next'] if not state or state['phase'] == 'complete' else [])
    for name in stages:
        stage = base/name
        if stage.exists() or stage.is_symlink():
            lifecycle.retain(base, stage, 'interrupted-'+name); retained.append(name)
    if args.recover and (not state or state['phase'] == 'complete') and retained:
        print('Retained interrupted preparation in history. Retry --apply or --update; the active source is preserved.'); return
    if args.recover or (args.resume and state and state['phase'] != 'complete'):
        lifecycle.recover(base, install); return
    if args.rollback:
        previous = base/'previous'
        if not (previous/'consumer-profile.json').exists(): raise SystemExit('No retained source to roll back')
        preserve_preferences(destination, previous)
        lifecycle.transition(base, base/'previous', 'rollback', install); return
    if args.update:
        if not (destination/'consumer-profile.json').exists(): raise SystemExit('No installed profile to update')
        if state and state['phase'] != 'complete': raise SystemExit('Interrupted transition exists; run --recover first')
        recorded = json.loads((destination/'consumer-profile.json').read_text())
        selection = plan(recorded['agents'], recorded['workApps'])
        candidate = materialize(base/'source-next', selection)
        for filename in ['10-modules.yaml','20-preferences.yaml']:
            shutil.copy2(destination/'home/.chezmoidata'/filename, candidate/'home/.chezmoidata'/filename)
        lifecycle.transition(base, candidate, 'update', install); return
    if args.resume:
        if not (destination/'consumer-profile.json').exists(): raise SystemExit('No prepared consumer profile to resume')
        recorded = json.loads((destination/'consumer-profile.json').read_text())
        if any(recorded.get(key) != selection.get(key) for key in ['agents','workApps']):
            raise SystemExit('Resume options differ from recorded profile. Use the original --agents/--work-apps choices; existing source is preserved.')
    else:
        # Build in a sibling temporary source so failed preparation cannot leave
        # an apparently complete install source. Never replace an existing profile.
        if destination.exists(): raise SystemExit('Consumer profile already exists. Use --resume with the original options.')
        temporary = destination.with_name('source-preparing')
        materialize(temporary, selection)
        temporary.rename(destination)
        write_state(destination, 'prepared')
    install(destination)
    print('Desktop profile applied; doctor report saved. Review consumer-doctor.json and verify permissions and desktop acceptance.')

def preserve_preferences(current, candidate):
    files = ['10-modules.yaml','20-preferences.yaml']
    compatible = True
    for filename in files:
        old = candidate/'home/.chezmoidata'/filename
        latest = current/'home/.chezmoidata'/filename
        if not old.exists() or not latest.exists(): compatible = False; break
        if set(re.findall(r'^  (\w+):',old.read_text(),re.M)) != set(re.findall(r'^  (\w+):',latest.read_text(),re.M)):
            compatible = False; break
    if compatible:
        for filename in files: shutil.copy2(current/'home/.chezmoidata'/filename,candidate/'home/.chezmoidata'/filename)
    else:
        print('Rollback settings schemas differ; restoring the prior settings snapshot. Current settings remain retained with the replaced source.')
    (candidate/'consumer-rollback-preferences.json').write_text(json.dumps({'preservedCurrentPreferences':compatible})+'\n')

if __name__ == '__main__':
    try: main()
    except ConsumerActivationError as error:
        print(str(error),file=sys.stderr); raise SystemExit(1)
