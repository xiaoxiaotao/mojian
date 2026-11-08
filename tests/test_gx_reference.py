import importlib.util
import hashlib
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prepare_gx_reference', ROOT / 'firmware/tools/prepare_gx_reference.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class ReferenceTest(unittest.TestCase):
    def test_reference_hash_mismatch_fails_closed(self):
        with tempfile.TemporaryDirectory(prefix='mojian-gxref-hash-') as tmp:
            root = Path(tmp)
            shutil.copytree(ROOT/'references/gxepd2-1.6.9', root/'references/gxepd2-1.6.9')
            panel = root/'references/gxepd2-1.6.9/src/gdey3c/GxEPD2_750c_GDEY075Z08.cpp'
            panel.write_bytes(panel.read_bytes()+b'\n')
            with self.assertRaises(AssertionError):
                prepare.generate(root/'firmware', root/'generated')

    def test_real_reference_and_guarded_normal_trace_equivalence(self):
        with tempfile.TemporaryDirectory(prefix='mojian-gxref-') as tmp:
            out = Path(tmp)
            lib = out / 'library'
            prepare.generate(ROOT / 'firmware', lib)
            upstream = ROOT / 'references/gxepd2-1.6.9'
            panel = 'src/gdey3c/GxEPD2_750c_GDEY075Z08.cpp'
            self.assertEqual((lib / panel).read_bytes(), (upstream / panel).read_bytes())
            self.assertIn('mojian_reference_io::wait', (lib / 'src/GxEPD2_EPD.cpp').read_text())
            for variant in ('guarded', 'original'):
                base = lib / 'src/GxEPD2_EPD.cpp' if variant == 'guarded' else upstream / 'src/GxEPD2_EPD.cpp'
                exe = out / variant
                flags = ['-DMOJIAN_REFERENCE_UNADAPTED_TEST=1'] if variant == 'original' else []
                subprocess.run(['c++', '-std=c++17', '-DESP32=1', '-DMOJIAN_EXPERIMENT_GX_REFERENCE=1', *flags,
                    '-I'+str(ROOT/'tests/display_stubs'), '-I'+str(ROOT/'firmware/src'), '-I'+str(lib/'src'),
                    str(ROOT/'tests/gx_reference_test.cpp'), str(ROOT/'firmware/src/reference_partial.cpp'),
                    str(ROOT/'firmware/src/EPD.cpp'), str(ROOT/'firmware/src/EPD_SPI.cpp'),
                    str(base), str(lib/panel), '-o', str(exe)], check=True)
                subprocess.run([str(exe), str(out/(variant+'.bin'))], check=True)
            self.assertEqual((out/'guarded.bin').read_bytes(), (out/'original.bin').read_bytes())
            print('PASS: guarded vs original reference normal SPI trace byte-for-byte identical')
            portal = (ROOT/'firmware/src/local_portal.h').read_text()
            start = portal.index('bool localPaint(')
            end = portal.index('// The worker only owns', start)
            (out/'actual_local_paint.h').write_text(portal[start:end])
            exe = out/'local-integration'
            subprocess.run(['c++', '-std=c++17', '-DESP32=1', '-DMOJIAN_EXPERIMENT_GX_REFERENCE=1',
                '-I'+str(ROOT/'tests/display_stubs'), '-I'+str(ROOT/'firmware/src'),
                '-I'+str(lib/'src'), '-I'+str(out), str(ROOT/'tests/gx_reference_local_test.cpp'),
                str(ROOT/'firmware/src/reference_partial.cpp'), str(ROOT/'firmware/src/EPD.cpp'),
                str(ROOT/'firmware/src/EPD_SPI.cpp'), str(lib/'src/GxEPD2_EPD.cpp'),
                str(lib/panel), '-o', str(exe)], check=True)
            subprocess.run([str(exe)], check=True)


if __name__ == '__main__':
    unittest.main()
