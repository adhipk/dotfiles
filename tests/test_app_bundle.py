#!/usr/bin/env python3
"""Exercise the distributed CLI and packages in a new store without changing this Mac."""
from pathlib import Path
import argparse
import json
import plistlib
import shutil
import subprocess
import tempfile
import time
ROOT=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dist',type=Path,default=ROOT/'dist')
APP=parser.parse_args().dist.resolve()/'Dotfiles.app'
CLI=APP/'Contents/MacOS/dotfiles-utility'
CATALOG=APP/'Contents/Resources/Utilities'
info=plistlib.loads((APP/'Contents/Info.plist').read_bytes())
assert info['LSMinimumSystemVersion']=='13.0'
assert (APP/'Contents/MacOS/dotfiles-service-runner').is_file()
dependencies=json.loads((APP/'Contents/Resources/dependencies.json').read_text())
assert dependencies[0]['name']=='pandoc' and dependencies[0]['version']=='3.12.1'
pandoc=CATALOG/'dotfiles.markdown-clipboard.dotutility/bin/pandoc'
assert subprocess.check_output([str(pandoc),'--version'],text=True).splitlines()[0]=='pandoc 3.12.1'
conversion=subprocess.run([str(pandoc),'--sandbox','--from=markdown-raw_html-raw_tex-native_divs-native_spans','--to=html5','--syntax-highlighting=none','--wrap=none'],
    input='# Works without Homebrew\n\n**Bold** and `code`\n',text=True,capture_output=True,check=True,env={'PATH':'/usr/bin:/bin'})
assert '<h1' in conversion.stdout and '<strong>Bold</strong>' in conversion.stdout
assert (pandoc.parent.parent/'licenses/pandoc/COPYRIGHT').is_file()
for license_file in ['LICENSE','NOTICE','THIRD_PARTY_NOTICES.md']:
    assert (APP/'Contents/Resources'/license_file).is_file()
subprocess.run(['codesign','--verify','--deep','--strict',str(APP)],check=True)
for package in CATALOG.glob('*.dotutility'):
    subprocess.run([str(CLI),'check',str(package)],check=True,stdout=subprocess.DEVNULL)
with tempfile.TemporaryDirectory(prefix='dotfiles fresh store ') as temp:
    def cli(*args, ok=True):
        result=subprocess.run([str(CLI),'--root',temp,*map(str,args)],text=True,capture_output=True)
        assert (result.returncode==0)==ok,result.stderr
        return result.stdout
    assert json.loads(cli('list'))==[]
    installed=json.loads(cli('install',CATALOG/'example.hello.dotutility'))
    assert installed['enabled'] is False
    cli('run','example.hello','hello',ok=False)
    cli('enable','example.hello')
    cli('set','example.hello','name','a name with spaces; $(literal)')
    assert cli('run','example.hello','hello')=='Hello, a name with spaces; $(literal)!\n'
    assert json.loads(cli('doctor'))==[]
    cli('install',CATALOG/'example.hello.dotutility',ok=False)
    # Command-only utility: these paths have no launchd actions.
    cli('disable','example.hello')
    cli('remove','example.hello')
    assert json.loads(cli('list'))==[]
    scaffold=Path(temp)/'new.dotutility'
    cli('new','test.scaffold',scaffold)
    cli('check',scaffold)
    cli('install',scaffold)
    cli('enable','test.scaffold')
    assert cli('run','test.scaffold','hello')=='Hello from test.scaffold\n'
    # Exercise the stdin limit using a system executable, without dependencies.
    manifest=json.loads((scaffold/'extension.json').read_text())
    manifest['id']='test.input'
    manifest['commands']=[{'id':'echo','title':'Echo','input':True,'invocation':{'tool':'cat'}}]
    (scaffold/'extension.json').write_text(json.dumps(manifest))
    cli('install',scaffold);cli('enable','test.input')
    result=subprocess.run([str(CLI),'--root',temp,'run','test.input','echo'],input='x'*1048577,text=True,capture_output=True)
    assert result.returncode!=0 and 'Input exceeds 1 MiB' in result.stderr,result

# Two real CLI processes must share the lifecycle lease. Disable cannot race a
# running action or delete its immutable code before execution completes.
with tempfile.TemporaryDirectory(prefix='dotfiles concurrent CLI ') as temp:
    source = Path(temp) / 'concurrent.dotutility'
    (source / 'bin').mkdir(parents=True)
    script = source / 'bin/worker'
    script.write_text('#!/bin/sh\nprintf started > "$DOTFILES_UTILITY_DATA/started"\n/bin/sleep 0.4\nprintf finished\n')
    script.chmod(0o755)
    manifest = {'schemaVersion':1, 'id':'test.concurrent', 'name':'Concurrency', 'version':'1.0.0', 'summary':'Fixture',
                'commands':[{'id':'wait', 'title':'Wait', 'invocation':{'executable':'bin/worker'}}]}
    (source / 'extension.json').write_text(json.dumps(manifest))
    store = Path(temp) / 'store'
    base = [str(CLI), '--root', str(store)]
    subprocess.run(base + ['install', str(source)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(base + ['enable', 'test.concurrent'], check=True)
    action = subprocess.Popen(base + ['run', 'test.concurrent', 'wait'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        marker = store / 'data/test.concurrent/started'
        deadline = time.monotonic() + 5
        while not marker.exists() and time.monotonic() < deadline:
            if action.poll() is not None: raise AssertionError(action.communicate())
            time.sleep(.01)
        assert marker.exists(), 'Action never started'
        disable = subprocess.Popen(base + ['disable', 'test.concurrent'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            time.sleep(.06)
            assert disable.poll() is None, 'Disable raced the active command'
            records = json.loads(subprocess.check_output(base + ['list'], text=True))
            assert records[0]['enabled'] is True
            stdout, stderr = action.communicate(timeout=5)
            assert action.returncode == 0 and stdout == 'finished', (stdout, stderr)
            stdout, stderr = disable.communicate(timeout=5)
            assert disable.returncode == 0, stderr
            records = json.loads(subprocess.check_output(base + ['list'], text=True))
            assert records[0]['enabled'] is False
        finally:
            if disable.poll() is None: disable.kill(); disable.communicate()
    finally:
        if action.poll() is None: action.kill(); action.communicate()

# Build an independent consumer of the public Swift SDK, package it, and run it.
example=ROOT/'examples/hello-utility'
subprocess.run(['swift','build','--package-path',str(example)],check=True)
binaries=Path(subprocess.check_output(['swift','build','--package-path',str(example),'--show-bin-path'],text=True).strip())
with tempfile.TemporaryDirectory(prefix='dotfiles sdk consumer ') as temp:
    package=Path(temp)/'example.dotutility'
    (package/'bin').mkdir(parents=True)
    shutil.copy2(example/'extension.json',package/'extension.json')
    shutil.copy2(binaries/'HelloUtility',package/'bin/hello')
    store=Path(temp)/'store'
    def sdk(*args):
        return subprocess.check_output([str(CLI),'--root',str(store),*map(str,args)],text=True)
    sdk('install',package);sdk('enable','example.swift-hello')
    sdk('set','example.swift-hello','name','independent SDK')
    assert sdk('run','example.swift-hello','hello')=='Hello, independent SDK!\n'
print('PASS: cross-process lifecycle lease, bundle signature, self-contained Pandoc conversion, license files, catalog, clean-store lifecycle, CLI scaffold/input limit, independent SDK consumer')
