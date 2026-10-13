#!/usr/bin/env python3
"""Provision only pinned plugin fixtures required by the legacy CI suites."""
import subprocess
from pathlib import Path
PLUGINS = [
    ('tmux-resurrect','https://github.com/tmux-plugins/tmux-resurrect.git','e87d7d592cac97fa38c12395ebec042c154a1844'),
    ('tmux-which-key','https://github.com/alexwforsythe/tmux-which-key.git','85fb9756447b989f3b94e515d1e6ee7fec76cba2'),
]
for name,url,revision in PLUGINS:
    destination=Path.home()/'.tmux/plugins'/name
    if destination.exists():raise SystemExit(f'Refusing to overwrite existing plugin: {destination}')
    destination.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['git','clone',url,str(destination)],check=True)
    subprocess.run(['git','-C',str(destination),'checkout','--detach',revision],check=True)
    subprocess.run(['git','-C',str(destination),'submodule','update','--init','--recursive'],check=True)
