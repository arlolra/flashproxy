# PyInstaller spec file for the flash proxy client programs.
# Modelled after example at http://www.pyinstaller.org/export/v2.0/project/doc/Manual.html?format=raw#merge.

# Top-level directory.
tmpdir = os.environ['PYINSTALLER_TMPDIR']
scripts = ('flashproxy-client', 'flashproxy-reg-email', 'flashproxy-reg-http')

# M2Crypto is listed as hidden import so PyInstaller fails if it cannot find it.
analyses = [(Analysis([script], hiddenimports=['M2Crypto']),
            script,
            os.path.join(tmpdir, 'build', script + '.exe')) for script in scripts]

MERGE(*analyses)

tocs = []
for a, _, exename in analyses:
    pyz = PYZ(a.pure)
    tocs.append(EXE(pyz,
                    a.scripts,
                    exclude_binaries=1,
                    console=True,
                    name=exename))
    tocs.append(a.binaries)


COLLECT(*tocs, name=os.path.join(tmpdir, 'dist'))
