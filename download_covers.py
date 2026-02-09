import re
import os
import urllib.request
import ssl

# Read the mock data file
with open("lib/data/sb_data.mock.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Extract cover_image URLs (only "cover_image", not "first_cover_image" or others)
# Pattern: "cover_image":\n              "https://..."
pattern = r'"cover_image":\s*\n\s*"(https://[^"]+)"'
urls = re.findall(pattern, content)

# Deduplicate while preserving order
seen = set()
unique_urls = []
for url in urls:
    if url not in seen:
        seen.add(url)
        unique_urls.append(url)

print(f"Found {len(urls)} cover_image URLs ({len(unique_urls)} unique)")

# Create output directory
output_dir = "cover_images"
os.makedirs(output_dir, exist_ok=True)

# Skip SSL verification for this download
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

# Download each URL
for i, url in enumerate(unique_urls):
    filename = url.split("/")[-1]
    filepath = os.path.join(output_dir, filename)

    if os.path.exists(filepath):
        print(f"[{i+1}/{len(unique_urls)}] Already exists: {filename}")
        continue

    print(f"[{i+1}/{len(unique_urls)}] Downloading: {filename}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, context=ctx) as response:
            data = response.read()
            with open(filepath, "wb") as out:
                out.write(data)
        print(f"  -> Saved ({len(data)} bytes)")
    except Exception as e:
        print(f"  -> FAILED: {e}")

print(f"\nDone! Files saved to: {output_dir}/")
