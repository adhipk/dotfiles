#!/usr/bin/env python3
"""Exercise the built CLI without Haskell/user configuration and verify macOS runtime compatibility."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess
import tempfile


def validate(binary,expected_sha):
    if hashlib.sha256(binary.read_bytes()).hexdigest()!=expected_sha:raise ValueError('Raw binary checksum differs')
    architecture=subprocess.check_output(['lipo','-archs',str(binary)],text=True).strip()
    if platform.machine() not in architecture.split():raise ValueError('Binary does not match native architecture')
    load_commands=subprocess.check_output(['otool','-l',str(binary)],text=True)
    minimums=re.findall(r'^\s*minos\s+([0-9.]+)',load_commands,re.M)
    if not minimums or any(tuple(map(int,value.split('.')))>(13,0) for value in minimums):raise ValueError('Binary LC_BUILD_VERSION exceeds supported macOS13 or is missing')
    libraries=subprocess.check_output(['otool','-L',str(binary)],text=True)
    external=[line.strip() for line in libraries.splitlines()[1:] if line.strip() and not line.strip().startswith(('/usr/lib/','/System/Library/'))]
    if external:raise ValueError('Binary needs non-system runtime libraries: '+str(external))
    with tempfile.TemporaryDirectory(prefix='pandoc-clean-env-') as temporary:
        env={'PATH':'/usr/bin:/bin','HOME':temporary,'TMPDIR':temporary,'LANG':'en_US.UTF-8'}
        version=subprocess.check_output([str(binary),'--version'],env=env,text=True)
        if version.splitlines()[0]!='pandoc 3.12.1':raise ValueError('Unexpected Pandoc version')
        result=subprocess.run([str(binary),'--from=html','--to=gfm'],input='<h1>Title</h1><p><strong>Hello</strong> <a href="https://example.com">link</a></p>',env=env,text=True,capture_output=True,check=True)
        if result.stdout!='# Title\n\n**Hello** [link](https://example.com)\n':raise ValueError('Clean-environment HTML conversion failed: '+repr(result.stdout))
    return {'schemaVersion':1,'rawBinarySHA256':expected_sha,'architecture':architecture,'minimumMacOS':minimums,'version':version,'runtimeLibraries':libraries,'htmlToGFM':'passed','isolatedEnvironment':'passed','haskellRuntimeAvailable':False}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--artifact',type=Path,required=True);args=parser.parse_args()
    metadata_path=args.artifact/'own-build.json';metadata=json.loads(metadata_path.read_text())
    if metadata.get('sourceMaterialsArchive'):raise SystemExit('Validate before packaging immutable source materials')
    record=validate(args.artifact/'pandoc',metadata['binarySHA256']);output=args.artifact/'standalone-validation.json';output.write_text(json.dumps(record,indent=2)+'\n')
    metadata['files']['standalone-validation.json']=hashlib.sha256(output.read_bytes()).hexdigest();metadata_path.write_text(json.dumps(metadata,indent=2)+'\n');print(output)


if __name__=='__main__':main()
