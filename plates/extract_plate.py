#!/usr/bin/env python3
"""
FAA d-TPP Approach Plate PDF → Structured JSON extractor.
Proof of concept using PyMuPDF to extract minimums, comms, and approach data.
"""

import json
import re
import sys
import fitz  # PyMuPDF

# Fraction map: "12" → "½", "14" → "¼", etc.
FRACTION_MAP = {
    "12": "½", "14": "¼", "34": "¾",
    "18": "⅛", "38": "⅜", "58": "⅝", "78": "⅞",
}


def extract_text_items(page):
    """Extract all text spans with bounding boxes from a PDF page."""
    items = []
    blocks = page.get_text("dict")["blocks"]
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
                    "x0": span["bbox"][0],
                    "y0": span["bbox"][1],
                    "x1": span["bbox"][2],
                    "y1": span["bbox"][3],
                    "size": span["size"],
                    "font": span["font"],
                })
    return items


def preprocess_minimums_items(items):
    """Pre-process minimums items: merge stacked fractions and resolve inline fractions."""
    # Step 1: Merge stacked single-digit fractions (e.g., '1' over '2' → ½)
    singles = [i for i in items if re.match(r'^[1-9]$', i["text"])]
    merged_ids = set()
    new_items = []

    for top in singles:
        if id(top) in merged_ids:
            continue
        for bot in singles:
            if id(top) == id(bot) or id(bot) in merged_ids:
                continue
            if (abs(top["x0"] - bot["x0"]) < 8
                    and 2 < bot["y0"] - top["y0"] < 10):
                combined = top["text"] + bot["text"]
                if combined in FRACTION_MAP:
                    new_items.append({
                        "text": FRACTION_MAP[combined],
                        "x0": min(top["x0"], bot["x0"]),
                        "y0": top["y0"],
                        "x1": max(top["x1"], bot["x1"]),
                        "y1": bot["y1"],
                        "size": top["size"],
                        "font": top["font"],
                        "_fraction": True,
                    })
                    merged_ids.add(id(top))
                    merged_ids.add(id(bot))
                    break

    result = [i for i in items if id(i) not in merged_ids] + new_items

    # Step 2: Resolve inline fraction patterns (e.g., "12" → "½") at any font size
    for item in result:
        if item["text"] in FRACTION_MAP and not item.get("_fraction"):
            item["text"] = FRACTION_MAP[item["text"]]
            item["_fraction"] = True

    return result


def find_category_row(items):
    """Find CATEGORY header and column centers/boundaries for A, B, C, D."""
    cat = [i for i in items if i["text"] == "CATEGORY"]
    if not cat:
        return None, {}, {}

    cat_y = cat[0]["y0"]
    row = [i for i in items
           if abs(i["y0"] - cat_y) < 8
           and i["text"] in ("A", "B", "C", "D")]

    centers = {}
    for item in row:
        centers[item["text"]] = (item["x0"] + item["x1"]) / 2

    # Column boundaries (midpoints between adjacent columns)
    col_names = sorted(centers.keys())
    bounds = {}
    for i, name in enumerate(col_names):
        left = 270 if i == 0 else (centers[col_names[i - 1]] + centers[name]) / 2
        right = 560 if i == len(col_names) - 1 else (centers[name] + centers[col_names[i + 1]]) / 2
        bounds[name] = (left, right)

    return cat_y, centers, bounds


def assign_to_column(item, col_bounds):
    """Assign a single item to a column based on its x-center."""
    x_center = (item["x0"] + item["x1"]) / 2
    for col, (left, right) in col_bounds.items():
        if left <= x_center <= right:
            return col
    return None


def merge_column_items(items):
    """Merge items assigned to a single column into text with smart spacing."""
    if not items:
        return ""

    # Group items into y-rows (items within 8px are same visual row)
    items_sorted = sorted(items, key=lambda i: i["y0"])
    rows = []
    for item in items_sorted:
        placed = False
        for row in rows:
            if abs(item["y0"] - row[0]["y0"]) < 8:
                row.append(item)
                placed = True
                break
        if not placed:
            rows.append([item])

    rows.sort(key=lambda r: r[0]["y0"])

    # Merge each row's items, then join rows with spaces
    parts = []
    for row in rows:
        row.sort(key=lambda i: i["x0"])
        row_parts = []
        for idx, item in enumerate(row):
            if idx > 0:
                prev = row[idx - 1]
                gap = item["x0"] - prev["x1"]
                if gap > 3 and not item.get("_fraction"):
                    row_parts.append(" ")
                # Fractions attach directly (no space)
            row_parts.append(item["text"])
        if parts:
            parts.append(" ")
        parts.append("".join(row_parts))

    return "".join(parts)


def extract_minimums(items, page_width):
    """Extract the minimums table into structured data."""
    cat_y, col_centers, col_bounds = find_category_row(items)
    if cat_y is None:
        return {"error": "CATEGORY row not found"}

    # Collect items in minimums area (below CATEGORY, above footer)
    min_items = [i for i in items
                 if i["y0"] > cat_y + 5
                 and i["y0"] < cat_y + 88  # Stay above footer text
                 and i["x0"] > 120]

    # Pre-process: merge stacked fractions, resolve inline fractions
    min_items = preprocess_minimums_items(min_items)

    # Find procedure labels
    proc_labels = []
    for item in min_items:
        if item["x0"] < 280 and re.match(r'S-ILS|S-LOC|SIDESTEP|CIRCLING', item["text"]):
            proc_labels.append({"name": item["text"], "y": item["y0"]})
    proc_labels.sort(key=lambda p: p["y"])

    # Value items only (x >= 280, exclude left-side airport diagram labels)
    value_items = [i for i in min_items if i["x0"] >= 280]

    # Assign each value item to a column
    for item in value_items:
        item["_col"] = assign_to_column(item, col_bounds)

    # Associate each item with a procedure using smart y-range detection
    def find_procedure_for_y(y):
        """Find which procedure a data row belongs to."""
        above = None
        below = None
        for pl in proc_labels:
            if pl["y"] <= y + 3:
                above = pl
            elif below is None:
                below = pl

        if above and below:
            dist_above = y - above["y"]
            dist_below = below["y"] - y
            # If clearly closer to next label, assign there
            if dist_above > 12 and dist_below < 15:
                return below["name"]
        if above:
            return above["name"]
        if below:
            return below["name"]
        return None

    # Build per-procedure, per-column item lists
    proc_col_items = {}
    for proc in proc_labels:
        proc_col_items[proc["name"]] = {"A": [], "B": [], "C": [], "D": []}

    for item in value_items:
        col = item.get("_col")
        if not col:
            continue
        proc_name = find_procedure_for_y(item["y0"])
        if proc_name and proc_name in proc_col_items:
            proc_col_items[proc_name][col].append(item)

    # Merge items within each column and parse
    result = {}
    for proc_name, cols in proc_col_items.items():
        col_texts = {}
        for col, col_items in cols.items():
            text = merge_column_items(col_items)
            if text.strip():
                col_texts[col] = text.strip()

        # Post-process: combine complementary columns
        # When a value spans two adjacent columns (one has altitude, other has HAT),
        # combine them and assign to both columns.
        col_texts = combine_complementary_columns(col_texts)

        # Parse each column's text
        proc_result = {}
        for col, text in col_texts.items():
            if text:
                proc_result[col] = parse_min_value(text)

        if proc_result:
            result[proc_name] = proc_result

    return result


def combine_complementary_columns(col_texts):
    """Combine complementary columns where altitude is in one column and HAT in another.

    This handles FAA plate layout where a value spanning A/B has altitude items in
    one column zone and HAT items in the adjacent column zone.
    """
    has_alt = {}
    has_hat = {}
    for col, text in col_texts.items():
        has_alt[col] = bool(re.search(r'\d{4,5}[-–]', text))
        has_hat[col] = bool(re.search(r'\d{2,3}\s*\(', text))

    # Check pairs: A+B, C+D, and also A+B+C+D
    pairs = [("A", "B"), ("C", "D")]
    for c1, c2 in pairs:
        if c1 in col_texts and c2 in col_texts:
            # One has only altitude, other has only HAT → combine
            if has_alt[c1] and not has_hat[c1] and has_hat[c2] and not has_alt[c2]:
                combined = col_texts[c1] + " " + col_texts[c2]
                col_texts[c1] = combined
                col_texts[c2] = combined
            elif has_hat[c1] and not has_alt[c1] and has_alt[c2] and not has_hat[c2]:
                combined = col_texts[c2] + " " + col_texts[c1]
                col_texts[c1] = combined
                col_texts[c2] = combined

    # Check if ALL filled columns have the same value → span all
    filled = {k: v for k, v in col_texts.items() if v}
    if filled:
        unique = set(filled.values())
        if len(unique) == 1:
            val = list(unique)[0]
            for col in ("A", "B", "C", "D"):
                col_texts[col] = val
        elif len(unique) == 2 and len(filled) == 2:
            # Two unique values in two columns — check if they're complementary halves
            cols = list(filled.keys())
            t1, t2 = filled[cols[0]], filled[cols[1]]
            h1_alt = bool(re.search(r'\d{4,5}[-–]', t1))
            h1_hat = bool(re.search(r'\d{2,3}\s*\(', t1))
            h2_alt = bool(re.search(r'\d{4,5}[-–]', t2))
            h2_hat = bool(re.search(r'\d{2,3}\s*\(', t2))
            if h1_alt and not h1_hat and h2_hat and not h2_alt:
                combined = t1 + " " + t2
                for col in ("A", "B", "C", "D"):
                    col_texts[col] = combined

    return col_texts


def parse_min_value(text):
    """Parse a minimums value like '6460-1½ 575 (600-1½)' into structured data."""
    result = {"raw": text}

    # Extract MDA/DA-visibility: "6460-1½" or "6085-½"
    m = re.match(r'(\d{4,5})[-–](\S+?)(?:\s|$)', text)
    if m:
        result["altitude"] = int(m.group(1))
        result["visibility"] = m.group(2)

    # Extract HAT: "575 (600-1)" or "200 (200-½)" or "200 (200-    )½"
    # Handle fractions that appear after the closing paren (PDF rendering artifact)
    hat = re.search(r'(\d{2,4})\s*\((\d{2,4})[-–]\s*(\d*)\s*\)\s*([½¼¾⅛⅜⅝⅞])?', text)
    if hat:
        result["hat"] = int(hat.group(1))
        result["hat_ref"] = int(hat.group(2))
        # Combine whole number part + fraction part for visibility
        whole = hat.group(3) or ""
        frac = hat.group(4) or ""
        result["hat_visibility"] = whole + frac if (whole or frac) else None
        if not result["hat_visibility"]:
            del result["hat_visibility"]
    else:
        # Try standard format: "575 (600-1½)"
        hat2 = re.search(r'(\d{2,4})\s*\((\d{2,4})[-–](\S+?)\)', text)
        if hat2:
            result["hat"] = int(hat2.group(1))
            result["hat_ref"] = int(hat2.group(2))
            result["hat_visibility"] = hat2.group(3)

    return result


def extract_comms(items):
    """Extract communications frequencies from the briefing strip."""
    comms = []
    comm_row = [i for i in items if 125 < i["y0"] < 160]
    comm_row.sort(key=lambda i: i["x0"])

    labels = ["ATIS", "DENVER APP CON", "CENTENNIAL TOWER", "GND CON", "CLNC DEL"]

    for label in labels:
        label_item = None
        for item in comm_row:
            if label in item["text"]:
                label_item = item
                break
        if not label_item:
            continue

        freqs = [i for i in items
                 if i["y0"] > label_item["y1"] - 2
                 and i["y0"] < label_item["y1"] + 16
                 and abs(i["x0"] - label_item["x0"]) < 40
                 and re.match(r'\d{2,3}\.\d', i["text"])]

        freq_list = [f["text"].strip() for f in freqs]
        comms.append({
            "name": label.replace("DENVER APP CON", "Denver Approach")
                         .replace("CENTENNIAL TOWER", "Centennial Tower")
                         .replace("GND CON", "Ground")
                         .replace("CLNC DEL", "Clearance Delivery"),
            "frequency": freq_list[0] if len(freq_list) == 1 else freq_list,
        })

    return comms


def extract_approach_info(items):
    """Extract localizer, course, GS, TCH, TDZE, elevation from briefing strip."""
    info = {}
    header = [i for i in items if i["y0"] < 130]

    for item in header:
        if re.match(r'^1\d{2}\.\d$', item["text"]):
            freq = float(item["text"])
            if 108.0 <= freq <= 112.0:
                info["localizer_frequency"] = freq
                break

    for item in items:
        m = re.match(r'^I-[A-Z]{3}$', item["text"])
        if m:
            info["localizer_id"] = m.group(0)
            break

    for item in header:
        m = re.match(r'^Chan\s*(\d+)$', item["text"])
        if m:
            info["channel"] = int(m.group(1))

    for item in header:
        if item["text"] == "APP CRS":
            course_items = [i for i in header
                            if abs(i["x0"] - item["x0"]) < 40
                            and i["y0"] > item["y1"] - 5
                            and re.match(r'\d{3}°?$', i["text"])]
            if course_items:
                info["course"] = int(course_items[0]["text"].replace("°", ""))
                break

    for item in items:
        m = re.search(r'GS\s*(\d+\.\d+)°?', item["text"])
        if m:
            info["glide_slope_angle"] = float(m.group(1))
            break

    for item in items:
        m = re.search(r'TCH\s*(\d+)', item["text"])
        if m:
            info["tch"] = int(m.group(1))
            break

    for item in header:
        m = re.search(r'Apt\s*Elev\s*(\d+)', item["text"])
        if m:
            info["airport_elevation"] = int(m.group(1))
            break
    if "airport_elevation" not in info:
        for item in items:
            if item["text"].startswith("ELEV"):
                nearby = [i for i in items
                          if abs(i["y0"] - item["y0"]) < 5
                          and i["x0"] > item["x1"]
                          and re.match(r'^\d{4,5}$', i["text"])]
                if nearby:
                    info["airport_elevation"] = int(nearby[0]["text"])
                    break

    tdze_list = []
    for item in items:
        m = re.search(r'TDZE\s+(\d+\w*)\s+(\d{4,5})', item["text"])
        if m:
            tdze_list.append({"runway": m.group(1), "elevation": int(m.group(2))})
    if tdze_list:
        info["tdze"] = tdze_list

    return info


def extract_missed_approach(items):
    """Extract missed approach text."""
    ma_label = [i for i in items if "MISSED APPROACH" in i["text"]]
    if not ma_label:
        return None

    label = ma_label[0]
    ma_items = [i for i in items
                if i["y0"] >= label["y0"] - 2
                and i["y0"] <= label["y0"] + 35
                and i["x0"] >= label["x0"] - 5
                and i["x0"] < 560]

    ma_items = [i for i in ma_items
                if not re.match(r'^[A-Z]\d$', i["text"])
                and i["text"] not in ("Rwy 35R", "MALSR")]

    ma_items.sort(key=lambda i: (round(i["y0"] / 5) * 5, i["x0"]))

    text = " ".join(i["text"] for i in ma_items)
    text = re.sub(r'\s+', ' ', text).strip()
    text = text.replace("MISSED APPROACH:", "").strip()
    return text


def extract_notes(items):
    """Extract notes/cautions from the plate."""
    notes = []
    note_items = [i for i in items
                  if 85 < i["y0"] < 130
                  and i["x0"] < 350
                  and not re.match(r'^(ATIS|DENVER|CENTENNIAL|GND|CLNC|MISSED)', i["text"])
                  and not re.match(r'^\d{2,3}\.\d', i["text"])]
    note_items.sort(key=lambda i: (round(i["y0"] / 6) * 6, i["x0"]))

    lines = {}
    for item in note_items:
        y_key = round(item["y0"] / 6) * 6
        if y_key not in lines:
            lines[y_key] = []
        lines[y_key].append(item)

    for y_key in sorted(lines.keys()):
        text = " ".join(i["text"] for i in sorted(lines[y_key], key=lambda i: i["x0"]))
        text = re.sub(r'\s+', ' ', text).strip()
        if text and len(text) > 5:
            notes.append(text)

    return notes


def extract_airport_info(items):
    """Extract airport identifier, name, city/state."""
    info = {}

    for item in items:
        if "CENTENNIAL" in item["text"] and "(APA)" in item["text"]:
            info["name"] = "CENTENNIAL"
            info["faa_id"] = "APA"
            break

    if "name" not in info:
        for item in items:
            if item["text"] == "CENTENNIAL" and item["y0"] > 700:
                info["name"] = "CENTENNIAL"
            if "(APA)" in item["text"] and item["y0"] > 700:
                info["faa_id"] = "APA"

    if "faa_id" not in info:
        for item in items:
            m = re.search(r'\(([A-Z]{3,4})\)', item["text"])
            if m and item["y0"] > 700:
                info["faa_id"] = m.group(1)

    for item in items:
        m = re.match(r'^(K[A-Z]{3})$', item["text"])
        if m:
            info["icao"] = m.group(1)

    for item in items:
        if item["y0"] > 700:
            m = re.match(r'^([A-Z]+),\s*([A-Z]+)$', item["text"])
            if m:
                info["city"] = m.group(1)
                info["state"] = m.group(2)

    return info


def extract_plate(pdf_path):
    """Main extraction — parse FAA approach plate PDF into structured JSON."""
    doc = fitz.open(pdf_path)
    page = doc[0]
    items = extract_text_items(page)

    result = {"source": pdf_path}

    title = [i for i in items if "ILS or LOC" in i["text"] and i["size"] > 12]
    if title:
        result["procedure_name"] = title[0]["text"]

    result["airport"] = extract_airport_info(items)
    result["approach"] = extract_approach_info(items)
    result["communications"] = extract_comms(items)
    result["missed_approach"] = extract_missed_approach(items)
    result["notes"] = extract_notes(items)
    result["minimums"] = extract_minimums(items, page.rect.width)

    doc.close()
    return result


if __name__ == "__main__":
    pdf_path = sys.argv[1] if len(sys.argv) > 1 else "apa-ils35-faa.pdf"
    result = extract_plate(pdf_path)
    print(json.dumps(result, indent=2, ensure_ascii=False))
