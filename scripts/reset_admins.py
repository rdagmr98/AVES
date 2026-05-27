#!/usr/bin/env python3
"""Reset admin accounts in aves-data with fresh, verified credentials."""

from Crypto.Cipher import AES
import base64, hashlib, json, datetime, shutil, os

KEY = b'd694b158908b35cc05cf4f4b39ab0e3c'
IV = bytes(16)
SALT = 'aves_salt_2024'
USERS_PATH = r'C:\Users\Gianmarco\aves-data\db\users.json'
BACKUP_DIR = r'C:\Users\Gianmarco\aves-data\backups'


def pkcs7_pad(data):
    pad_len = 16 - (len(data) % 16)
    return data + bytes([pad_len] * pad_len)


def encrypt_field(plaintext):
    if not plaintext:
        return plaintext
    data = pkcs7_pad(plaintext.encode('utf-8'))
    cipher = AES.new(KEY, AES.MODE_CBC, IV)
    return 'ENC:' + base64.b64encode(cipher.encrypt(data)).decode()


def decrypt_field(ciphertext):
    if not ciphertext or not str(ciphertext).startswith('ENC:'):
        return ciphertext
    data = base64.b64decode(ciphertext[4:])
    cipher = AES.new(KEY, AES.MODE_CBC, IV)
    dec = cipher.decrypt(data)
    pad_len = dec[-1]
    return dec[:-pad_len].decode('utf-8', 'ignore')


def hash_password(password):
    return hashlib.sha256((password + SALT).encode()).hexdigest()


# Load current users.json
with open(USERS_PATH, 'r', encoding='utf-8') as f:
    users = json.load(f)

print('=== Current state (decrypted) ===')
for u in users:
    uid = u.get('id', '')
    uname = decrypt_field(u.get('username', ''))
    nome = decrypt_field(u.get('nome', ''))
    cognome = decrypt_field(u.get('cognome', ''))
    role = u.get('role', '')
    print(f'  {uid}: username={uname}, nome={nome}, cognome={cognome}, role={role}')

# Backup
os.makedirs(BACKUP_DIR, exist_ok=True)
ts = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
backup_path = os.path.join(BACKUP_DIR, f'users_{ts}.json')
shutil.copy2(USERS_PATH, backup_path)
print(f'\n[BACKUP] Saved to {backup_path}')

# New admin password
NEW_ADMIN_PWD = 'aves2024'
NEW_HASH = hash_password(NEW_ADMIN_PWD)
print(f'\n[NEW PASSWORD] "{NEW_ADMIN_PWD}" -> hash: {NEW_HASH}')

# Rebuild admin entries from scratch
admin_csl = {
    "id": "admin_priv_001",
    "username": encrypt_field("admincsl"),
    "password_hash": NEW_HASH,
    "role": "admin_priv",
    "nome": encrypt_field("Admin"),
    "cognome": encrypt_field("CSL"),
    "email": encrypt_field("admincsl@esercito.difesa.it"),
    "numero_licenza": None,
    "approved": True,
    "createdAt": "2024-01-01T00:00:00.000Z"
}
admin_volo = {
    "id": "admin_crew_001",
    "username": encrypt_field("adminvolo"),
    "password_hash": NEW_HASH,
    "role": "admin_crew",
    "nome": encrypt_field("Admin"),
    "cognome": encrypt_field("Volo"),
    "email": encrypt_field("adminvolo@esercito.difesa.it"),
    "numero_licenza": None,
    "approved": True,
    "createdAt": "2024-01-01T00:00:00.000Z"
}

# Keep all non-admin users, replace admin entries
new_users = []
admin_ids = {'admin_priv_001', 'admin_crew_001'}
for u in users:
    if u.get('id') not in admin_ids:
        new_users.append(u)

new_users.insert(0, admin_csl)
new_users.insert(1, admin_volo)

# Save
with open(USERS_PATH, 'w', encoding='utf-8') as f:
    json.dump(new_users, f, ensure_ascii=False, indent=2)

print('\n[SAVED] users.json updated')
print('\n=== Verification (decrypted) ===')
for u in new_users[:2]:
    uid = u.get('id', '')
    uname = decrypt_field(u.get('username', ''))
    nome = decrypt_field(u.get('nome', ''))
    role = u.get('role', '')
    print(f'  {uid}: username={uname}, nome={nome}, role={role}')
    computed = hash_password(NEW_ADMIN_PWD)
    match = computed == u['password_hash']
    print(f'    hash matches {NEW_ADMIN_PWD}: {match}')

print('\n[DONE] Admin accounts reset. Credentials:')
print(f'  admincsl / {NEW_ADMIN_PWD}')
print(f'  adminvolo / {NEW_ADMIN_PWD}')
