#!/usr/bin/env python3
"""Debug: dump all text items in the minimums area with exact positions."""

import json
import sys
import fitz

pdf_path = sys.argv[1] if len(sys.argv) > 1 else "apa-ils35-faa.pdf"
doc = fitz.open(pdf_path)
page = doc[0]

# Get all text with character-level detail
blocks = page.get_text("dict")["blocks"]
items = []
for block in blocks:
    if "lines" not in block:
        continue
    for line in block["lines"]:
        for span in line["spans"]:
            text = span["text"].strip()
            if not text:
                continue
            items.append({
                "text": text,
                "x0": round(span["bbox"][0], 1),
                "y0": round(span["bbox"][1], 1),
                "x1": round(span["bbox"][2], 1),
                "y1": round(span["bbox"][3], 1),
                "size": round(span["size"], 1),
            })

# Find CATEGORY row
cat = [i for i in items if i["text"] == "CATEGORY"]
if cat:
    cat_y = cat[0]["y0"]
    print(f"CATEGORY found at y={cat_y}")
    print(f"Page height: {page.rect.height}")
    print()

    # Show everything from CATEGORY down, sorted by y then x
    below = [i for i in items if i["y0"] >= cat_y - 2]
    below.sort(key=lambda i: (round(i["y0"] / 4) * 4, i["x0"]))

    current_y_bucket = None
    for item in below:
        y_bucket = round(item["y0"] / 4) * 4
        if y_bucket != current_y_bucket:
            print(f"\n--- y≈{y_bucket} ---")
            current_y_bucket = y_bucket
        print(f"  x={item['x0']:6.1f}  size={item['size']:4.1f}  \"{item['text']}\"")

doc.close()
