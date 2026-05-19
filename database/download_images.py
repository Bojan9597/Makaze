#!/usr/bin/env python3
"""
Download all external salon images into api/uploads/ and update the DB.

Run from the repo root (API venv must be active):
    cd api && .\.venv\Scripts\Activate.ps1
    cd ..\database && python download_images.py
"""

import os
import sys
import urllib.request
import urllib.error
import psycopg2
import psycopg2.extras
from uuid import uuid4
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'api', '.env'))

DATABASE_URL = os.getenv(
    'DATABASE_URL',
    'postgresql://makaze:makaze_password@localhost:5432/makaze_db',
)

UPLOAD_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), '..', 'api', 'uploads',
)

HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0 Safari/537.36'
    ),
    'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
}


def download_file(url: str, dest_path: str) -> bool:
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
        with open(dest_path, 'wb') as f:
            f.write(data)
        return True
    except urllib.error.HTTPError as e:
        print(f'    HTTP {e.code}: {url[:70]}')
        return False
    except Exception as e:
        print(f'    ERROR: {e} | {url[:70]}')
        return False


def main():
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    cur.execute("""
        SELECT si.id, si.salon_id, si.image_url, si.sort_order
        FROM   salon_images si
        WHERE  si.image_url LIKE 'http%'
        ORDER  BY si.salon_id, si.sort_order
    """)
    rows = cur.fetchall()

    if not rows:
        print('No external image URLs found. Run seed.py first.')
        return

    print(f'Downloading {len(rows)} images...\n')

    ok = 0
    fail = 0
    for row in rows:
        salon_id = str(row['salon_id'])
        img_id   = str(row['id'])
        url      = row['image_url']

        target_dir = os.path.join(UPLOAD_DIR, 'salons', salon_id)
        os.makedirs(target_dir, exist_ok=True)

        filename  = f'{uuid4().hex}.jpg'
        dest_path = os.path.join(target_dir, filename)

        short_url = url.split('?')[0].split('/')[-1][:30]
        print(f'  [{ok+fail+1:2d}/{len(rows)}] {short_url}... ', end='', flush=True)

        if download_file(url, dest_path):
            local_path = f'/uploads/salons/{salon_id}/{filename}'
            cur.execute(
                'UPDATE salon_images SET image_url = %s WHERE id = %s',
                (local_path, img_id),
            )
            print('OK')
            ok += 1
        else:
            os.path.exists(dest_path) and os.remove(dest_path)
            fail += 1

    conn.commit()
    cur.close()
    conn.close()

    print(f'\nDone: {ok} downloaded, {fail} failed.')
    if fail:
        print('Failed images keep their Unsplash URL in the DB (still work as CDN fallback).')


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f'FATAL: {e}', file=sys.stderr)
        sys.exit(1)
