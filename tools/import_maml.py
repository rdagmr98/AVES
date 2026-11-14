"""Importa le scansioni MAML in aves-data (stesso formato di MamlScanService).

uso: python -I import_maml.py <aves-data> <cartella doc istruttori> [--write]
File: maml/<uid>/<ms>.bin = IV(16) + AES-256-CBC PKCS7, chiave di CryptoService.
"""
import base64, datetime, hashlib, json, os, sys, time

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

KEY = b'd694b158908b35cc05cf4f4b39ab0e3c'


def dec(v):
    if not isinstance(v, str) or not v.startswith('ENC:'):
        return v
    d = Cipher(algorithms.AES(KEY), modes.CBC(bytes(16))).decryptor()
    raw = d.update(base64.b64decode(v[4:])) + d.finalize()
    u = padding.PKCS7(128).unpadder()
    return (u.update(raw) + u.finalize()).decode()


def enc_bytes(data):
    iv = os.urandom(16)
    p = padding.PKCS7(128).padder()
    e = Cipher(algorithms.AES(KEY), modes.CBC(iv)).encryptor()
    return iv + e.update(p.update(data) + p.finalize()) + e.finalize()


def dec_bytes(data):
    d = Cipher(algorithms.AES(KEY), modes.CBC(data[:16])).decryptor()
    raw = d.update(data[16:]) + d.finalize()
    u = padding.PKCS7(128).unpadder()
    return u.update(raw) + u.finalize()


def blob_sha(data):
    return hashlib.sha1(b'blob %d\0' % len(data) + data).hexdigest()


def main(repo, docs, write):
    users = json.load(open(os.path.join(repo, 'db', 'users.json'), encoding='utf-8'))
    by_surname = {}
    for u in users:
        by_surname.setdefault((dec(u.get('cognome')) or '').strip().upper(), []).append(u)
    idx_path = os.path.join(repo, 'db', 'maml_scans.json')
    index = json.load(open(idx_path, encoding='utf-8')) if os.path.exists(idx_path) else []
    have = {r['id'] for r in index if r.get('approved')}
    for folder in sorted(os.listdir(docs)):
        d = os.path.join(docs, folder)
        pdfs = [os.path.join(r, f) for r, _, fs in os.walk(d) for f in fs
                if 'maml' in (r + f).lower() and f.lower().endswith('.pdf')]
        if not pdfs:
            print(f'{folder}: nessuna MAML')
            continue
        match = by_surname.get(folder.upper(), [])
        if len(match) != 1:
            print(f'{folder}: {len(match)} utenti con questo cognome, salto')
            continue
        u = match[0]
        if u['id'] in have:
            print(f'{folder}: già presente, salto')
            continue
        src = pdfs[0]
        data = open(src, 'rb').read()
        assert data.startswith(b'%PDF'), src
        blob = enc_bytes(data)
        assert dec_bytes(blob) == data
        ms = int(time.time() * 1000) + len(index)
        path = f"maml/{u['id']}/{ms}.bin"
        at = datetime.datetime.fromtimestamp(os.path.getmtime(src)).isoformat()
        index.append({'id': u['id'], 'approved': {
            'path': path, 'sha': blob_sha(blob), 'mime': 'application/pdf',
            'at': at, 'by': 'import', 'approved_by': 'import'}, 'pending': None})
        print(f"{folder}: {dec(u.get('nome'))} {dec(u.get('cognome'))} <- {os.path.basename(src)}")
        if write:
            os.makedirs(os.path.join(repo, 'maml', u['id']), exist_ok=True)
            open(os.path.join(repo, path), 'wb').write(blob)
    if write:
        open(idx_path, 'w', encoding='utf-8').write(
            json.dumps(index, ensure_ascii=False, separators=(',', ':')))
    print(f'{len(index)} record' + ('' if write else ' (a secco)'))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], '--write' in sys.argv)
