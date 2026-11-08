"""Generate the opt-in reference driver with bounded I/O; never edit upstream files."""
import hashlib
import json
from pathlib import Path
import re
import shutil


def adapt_base(text):
    text = text.replace('#include "GxEPD2_EPD.h"', '#include "GxEPD2_EPD.h"\n#include "MoJianReferenceIO.h"', 1)
    start = text.index('void GxEPD2_EPD::_waitWhileBusy(')
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    assert 'Busy Timeout!' in text[start:end]
    text = text[:brace] + '{\n  mojian_reference_io::wait(_busy, _busy_level, _busy_timeout);\n}' + text[end:]
    methods = {'_reset': 1, '_writeCommand': 1, '_writeData': 2,
               '_writeDataPGM': 1, '_writeDataPGM_sCS': 1,
               '_writeCommandData': 1, '_writeCommandDataPGM': 1,
               '_startTransfer': 1, '_transfer': 1}
    for method, expected in methods.items():
        pattern = r'(void GxEPD2_EPD::' + method + r'\([^)]*\)\n\{\n)'
        text, count = re.subn(pattern, r'\1  if(displayGuard.failed)return;\n', text)
        assert count == expected, (method, count)
    marker = 'void GxEPD2_EPD::_writeCommand(uint8_t c)\n{\n  if(displayGuard.failed)return;\n'
    assert text.count(marker) == 1
    return text.replace(marker, marker + '  mojian_reference_io::command(c);\n', 1)


def generate(project, destination):
    upstream = project.parent / 'references/gxepd2-1.6.9'
    manifest = json.loads((upstream / 'manifest.json').read_text())
    assert manifest['commit'] == 'de82887e77a78528ea386e68bba2cb0291d2c319'
    for name, digest in manifest['sha256'].items():
        source = upstream / name
        assert hashlib.sha256(source.read_bytes()).hexdigest() == digest, name
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    base = destination / 'src/GxEPD2_EPD.cpp'
    base.write_text(adapt_base(base.read_text()))
    shutil.copyfile(project / 'src/MoJianReferenceIO.h', destination / 'src/MoJianReferenceIO.h')
    (destination / 'library.json').write_text(json.dumps({
        'name': 'MoJianGxReference', 'version': '1.6.9',
        'build': {'srcFilter': ['+<GxEPD2_EPD.cpp>', '+<gdey3c/GxEPD2_750c_GDEY075Z08.cpp>']}
    }))


if 'Import' in globals():
    Import('env')
    if env['PIOENV'] == 'esp32-l-gx-reference-ab':
        project = Path(env['PROJECT_DIR'])
        env.Append(CPPPATH=[str(project / 'src')])
        generate(project, project / '.pio/reference-libs/MoJianGxReference')
