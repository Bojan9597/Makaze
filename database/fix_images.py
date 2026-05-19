#!/usr/bin/env python3
"""
Download remaining external (Unsplash) salon images and update DB.
Falls back to picsum.photos if Unsplash is blocked.
"""

import os
import uuid
import urllib.request
import urllib.error
import psycopg2

DB_URL = os.getenv("DATABASE_URL", "postgresql://makaze:makaze_password@localhost:5432/makaze_db")
UPLOAD_BASE = "/var/www/makaze/api/uploads/salons"

# Picsum IDs that look like barbershop/salon photos (consistent seeds)
PICSUM_SEEDS = [
    "barber1", "barber2", "barber3", "salon1", "salon2",
    "salon3", "haircut1", "haircut2", "cuts1", "cuts2",
    "style1", "style2", "trim1", "trim2", "fade1",
]

def download_url(url, dest_path):
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "image/webp,image/apng,image/*,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://unsplash.com/",
    }
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            if resp.status == 200:
                data = resp.read()
                if len(data) > 5000:  # must be a real image
                    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                    with open(dest_path, "wb") as f:
                        f.write(data)
                    return True
    except Exception as e:
        print(f"    Unsplash failed: {e}")
    return False


def download_picsum(seed, dest_path):
    url = f"https://picsum.photos/seed/{seed}/800/600"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = resp.read()
            if len(data) > 5000:
                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                with open(dest_path, "wb") as f:
                    f.write(data)
                return True
    except Exception as e:
        print(f"    Picsum failed: {e}")
    return False


def main():
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()

    cur.execute("""
        SELECT si.id, si.salon_id, si.image_url
        FROM salon_images si
        WHERE si.image_url LIKE 'https://%'
        ORDER BY si.salon_id, si.id
    """)
    rows = cur.fetchall()
    print(f"Found {len(rows)} images with external URLs")

    picsum_idx = 0

    for img_id, salon_id, image_url in rows:
        fname = str(uuid.uuid4()) + ".jpg"
        salon_dir = os.path.join(UPLOAD_BASE, str(salon_id))
        dest = os.path.join(salon_dir, fname)
        local_path = f"/uploads/salons/{salon_id}/{fname}"

        print(f"\n  {salon_id[:8]}... {image_url[:60]}")

        # Try original URL first
        ok = download_url(image_url, dest)

        if not ok:
            # Fallback: picsum with a seed
            seed = PICSUM_SEEDS[picsum_idx % len(PICSUM_SEEDS)]
            picsum_idx += 1
            print(f"    -> Trying picsum seed={seed}")
            ok = download_picsum(seed, dest)

        if ok:
            cur.execute(
                "UPDATE salon_images SET image_url = %s WHERE id = %s",
                (local_path, img_id)
            )
            conn.commit()
            print(f"    -> Saved: {local_path}")
        else:
            print(f"    -> FAILED, keeping external URL")

    cur.close()
    conn.close()
    print("\nDone!")


if __name__ == "__main__":
    main()
