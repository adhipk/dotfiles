#!/usr/bin/env python3
"""Manifest-owned module suites plus explicit cross-module acceptance checks."""
import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
PARENT = ['test_colorscheme.sh','test_configs.sh','test_dotfiles_lib.sh','test_install.sh',
          'test_integration.sh','test_module_integration.sh','test_source_state.sh',
          'test_tmux_which_key.sh','test_whichkey.sh']

def suites():
    result = [(f'parent/{name}', ['bash', str(ROOT/'tests'/name)]) for name in PARENT]
    for manifest in sorted((ROOT/'modules').glob('*/module.yaml')):
        data=json.loads(subprocess.check_output(['yq','-o=json','.',str(manifest)],text=True))
        for relative in data.get('tests',[]):
            path=manifest.parent/relative
            if not path.is_file():raise RuntimeError(f'Missing declared test: {path}')
            result.append((f"{data['id']}/{Path(relative).name}",['bash',str(path)]))
    result.append(('native/swift-tests',['swift','test','--package-path',str(ROOT/'modules/dotfiles-control-center')]))
    result.append(('consumer/lifecycle-contracts',['python3',str(ROOT/'tests/test_consumer_lifecycle.py')]))
    result.append(('consumer/profile-contracts',['python3',str(ROOT/'tests/test_consumer_setup.py')]))
    result.append(('release/pandoc-artifact-bundle',['python3',str(ROOT/'tests/test_pandoc_artifact_bundle.py')]))
    result.append(('release/pandoc-build-closure',['python3',str(ROOT/'tests/test_pandoc_build_closure.py')]))
    result.append(('release/pandoc-source-materials',['python3',str(ROOT/'tests/test_pandoc_source.py')]))
    result.append(('release/own-source-gates',['python3',str(ROOT/'tests/test_own_source_release_gate.py')]))
    result.append(('release/acceptance-gates',['python3',str(ROOT/'tests/test_release_gate.py')]))
    return result

def run_suite(name, command, output, timeout):
    started=time.monotonic()
    log=output/(name.replace('/','__')+'.log')
    env=os.environ.copy();env['TODO_TEST_REPO_ROOT']=str(ROOT)
    process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
    selector=selectors.DefaultSelector();selector.register(process.stdout,selectors.EVENT_READ)
    timed_out=False
    with log.open('wb') as stream:
        while selector.get_map():
            if time.monotonic()-started>timeout and not timed_out:
                timed_out=True
                os.killpg(process.pid,signal.SIGKILL)
            for key,_ in selector.select(.2):
                chunk=os.read(key.fd,65536)
                if not chunk:selector.unregister(key.fileobj);continue
                stream.write(chunk);stream.flush()
                sys.stdout.buffer.write(chunk);sys.stdout.buffer.flush()
            if timed_out and time.monotonic()-started>timeout+5:break
    selector.close();process.stdout.close()
    code=process.wait(timeout=5)
    return dict(name=name,status='timeout' if timed_out else ('passed' if code==0 else 'failed'),exitCode=code,seconds=round(time.monotonic()-started,3),log=str(log.relative_to(output)))

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--list',action='store_true')
    parser.add_argument('--match',default='')
    parser.add_argument('--timeout',type=int,default=180)
    parser.add_argument('--output',type=Path,default=ROOT/'test-results')
    args=parser.parse_args()
    selected=[(n,c) for n,c in suites() if args.match in n]
    if not selected:raise SystemExit('No test suites selected')
    if args.list:
        print('\n'.join(n for n,_ in selected));return
    args.output.mkdir(parents=True,exist_ok=True)
    results=[]
    try:
        for name,command in selected:
            print(f'\nRunning {name}',flush=True)
            results.append(run_suite(name,command,args.output,args.timeout))
    finally:
        (args.output/'results.json').write_text(json.dumps(results,indent=2)+'\n')
        report=ET.Element('testsuite',name='dotfiles',tests=str(len(results)),failures=str(sum(r['status']!='passed' for r in results)))
        for r in results:
            case=ET.SubElement(report,'testcase',name=r['name'],time=str(r['seconds']))
            if r['status']!='passed':ET.SubElement(case,'failure',message=r['status']).text=f"See {r['log']}; exit {r['exitCode']}"
        ET.ElementTree(report).write(args.output/'junit.xml',encoding='utf-8',xml_declaration=True)
    failed=[r['name'] for r in results if r['status']!='passed']
    print(f'\nSuites: {len(results)-len(failed)} passed, {len(failed)} failed')
    if failed:print('\n'.join(failed))
    raise SystemExit(bool(failed))
if __name__=='__main__':main()
