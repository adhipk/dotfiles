"""Journaled source transitions; package-manager changes are not reversible."""
import json
from pathlib import Path
import uuid

def journal(base, value):
    temporary = base/'lifecycle.json.tmp'
    temporary.write_text(json.dumps(value, indent=2)+'\n')
    temporary.replace(base/'lifecycle.json')

def read_journal(base):
    path = base/'lifecycle.json'
    return json.loads(path.read_text()) if path.exists() else None

def retain(base, path, label):
    if path.exists() or path.is_symlink():
        history = base/'history'
        history.mkdir(exist_ok=True)
        path.rename(history/f'{label}-{uuid.uuid4()}')

def recover(base, install):
    state = read_journal(base)
    if not state or state['phase'] == 'complete':
        raise ValueError('No interrupted consumer transition to recover')
    source = base/'source'
    backup = base/'transaction-backup'
    if state['phase'] == 'finalizing' and not backup.exists() and (base/'previous').exists():
        (base/'previous').rename(backup)
    # A pre-move interruption leaves the original active source intact.
    if backup.exists():
        retain(base, source, 'failed-candidate')
        backup.rename(source)
    if not (source/'consumer-profile.json').exists():
        raise ValueError('Recovery source is missing; no configuration was applied')
    state['phase'] = 'restoring'
    journal(base, state)
    try:
        install(source)
    except Exception as error:
        state['phase'] = 'restore-failed'; state['error'] = str(error)
        journal(base, state)
        raise
    state['phase'] = 'complete'; state['outcome'] = 'restored-original'
    journal(base, state)
    retain(base, base/'source-next', 'interrupted-candidate')

def transition(base, candidate, operation, install):
    """Preserve original source before changing its stable managed location."""
    source = base/'source'
    backup = base/'transaction-backup'
    previous = base/'previous'
    state = read_journal(base)
    if backup.exists() or (state and state['phase'] != 'complete'):
        raise ValueError('Interrupted transition exists; run --recover first')
    if not (source/'consumer-profile.json').exists() or not (candidate/'consumer-profile.json').exists():
        raise ValueError('Both current and candidate profiles must be complete')
    state = {'operation':operation, 'phase':'prepared', 'outcome':None,
             'externalEffects':'Homebrew and external utility changes are not rolled back'}
    journal(base, state)
    source.rename(backup)
    state['phase'] = 'source-backed-up'; journal(base, state)
    candidate.rename(source)
    state['phase'] = 'applying'; journal(base, state)
    try:
        install(source)
    except Exception as error:
        state['phase'] = 'apply-failed'; state['error'] = str(error); journal(base, state)
        recover(base, install)
        raise
    # A completed rollback makes the source it replaced available for reversal.
    state['phase'] = 'finalizing'; journal(base, state)
    retain(base, previous, 'older-previous')
    backup.rename(previous)
    state['phase'] = 'complete'; state['outcome'] = operation
    journal(base, state)
