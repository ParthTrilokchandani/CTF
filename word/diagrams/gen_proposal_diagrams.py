"""
Diagrams for the client-facing CTF proposal document (CTF_Client_Proposal.docx).
Run from this directory: python3 gen_proposal_diagrams.py
Requires: Pillow. Reuses helpers from gen_diagrams.py.
"""
import os
import math
from PIL import Image, ImageDraw

from gen_diagrams import (
    font, wrap, text_h, draw_centered_block, rounded_box, arrow,
    F_DIAGRAM_TITLE, F_BOX_TITLE, F_BOX_DESC, F_TAG, F_SMALL,
    C_BG, C_BOX_FILL, C_BOX_OUTLINE, C_BOX_TEXT, C_DESC_TEXT,
    C_ARROW, C_TITLE, C_OK_FILL, C_OK_OUTLINE, C_OK_TEXT,
)

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

C_KALI_FILL = (222, 233, 246)
C_KALI_OUTLINE = (30, 80, 140)
C_UBUNTU_FILL = (241, 224, 210)
C_UBUNTU_OUTLINE = (170, 90, 30)
C_PROXMOX_FILL = (235, 235, 240)
C_PROXMOX_OUTLINE = (90, 90, 110)

F_FLAG_NUM = font("segoeuib.ttf", 20)
F_STAGE = font("segoeuib.ttf", 15)
F_NOTE = font("segoeuii.ttf", 13)


# ---------------------------------------------------------------------------
def architecture_diagram():
    filename = os.path.join(OUT_DIR, "proposal_architecture.png")
    scratch = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(scratch)

    W, H = 1180, 700
    img = Image.new("RGB", (W, H), C_BG)
    draw = ImageDraw.Draw(img)
    draw.text((44, 30), "Proposed Environment Architecture", font=F_DIAGRAM_TITLE, fill=C_TITLE)

    # Outer Proxmox boundary
    outer = (44, 100, W - 44, H - 90)
    rounded_box(draw, outer, C_PROXMOX_FILL, C_PROXMOX_OUTLINE, radius=16)
    draw.text((outer[0] + 24, outer[1] + 16), "Proxmox Virtualization Platform",
              font=F_BOX_TITLE, fill=C_BOX_TEXT)

    # Kali/Parrot box (participants)
    kali_box = (100, 190, 560, 520)
    rounded_box(draw, kali_box, C_KALI_FILL, C_KALI_OUTLINE, radius=14)
    draw_centered_block(draw, (kali_box[0] + kali_box[2]) / 2, kali_box[1] + 24, [
        (["Participant Machines"], F_BOX_TITLE, C_BOX_TEXT),
        (["Kali Linux / Parrot Security"], F_STAGE, C_KALI_OUTLINE),
        (wrap(d, "Example network: 10.10.x.x  (illustrative, configurable)", F_BOX_DESC, kali_box[2] - kali_box[0] - 60),
         F_BOX_DESC, C_DESC_TEXT),
        (["One VM per participant / team"], F_BOX_DESC, C_DESC_TEXT),
    ], para_gap=16)

    # Ubuntu target box
    ubu_box = (620, 190, 1080, 520)
    rounded_box(draw, ubu_box, C_UBUNTU_FILL, C_UBUNTU_OUTLINE, radius=14)
    draw_centered_block(draw, (ubu_box[0] + ubu_box[2]) / 2, ubu_box[1] + 24, [
        (["CTF Target"], F_BOX_TITLE, C_BOX_TEXT),
        (["Dedicated Ubuntu Server"], F_STAGE, C_UBUNTU_OUTLINE),
        (wrap(d, "Example network: 10.20.x.x  (illustrative, configurable)", F_BOX_DESC, ubu_box[2] - ubu_box[0] - 60),
         F_BOX_DESC, C_DESC_TEXT),
        (wrap(d, "Hosts the website, five flags, and every intended challenge stage", F_BOX_DESC, ubu_box[2] - ubu_box[0] - 60),
         F_BOX_DESC, C_DESC_TEXT),
    ], para_gap=16)

    mid_y = (kali_box[1] + kali_box[3]) / 2
    arrow(draw, (kali_box[2], mid_y), (ubu_box[0], mid_y), width=3)
    lbl = "Simulated attack traffic - isolated network segment only"
    w = d.textlength(lbl, font=F_SMALL)
    draw.text(((kali_box[2] + ubu_box[0]) / 2 - w / 2, mid_y - 26), lbl, font=F_SMALL, fill=C_ARROW)

    note = "10.10.x.x and 10.20.x.x are illustrative examples only - both ranges are fully configurable to match the client's environment."
    nw = d.textlength(note, font=F_NOTE)
    draw.text((W / 2 - nw / 2, H - 60), note, font=F_NOTE, fill=C_DESC_TEXT)

    img.save(filename)
    print("wrote", filename, img.size)


# ---------------------------------------------------------------------------
def flag_progression_diagram():
    filename = os.path.join(OUT_DIR, "flag_progression.png")
    scratch = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(scratch)

    stages = [
        ("1", "Web\nReconnaissance"),
        ("2", "Initial\nAccess"),
        ("3", "Lateral\nDiscovery"),
        ("4", "Secondary\nAccess"),
        ("5", "Full\nCompromise"),
    ]
    W, H = 1180, 340
    img = Image.new("RGB", (W, H), C_BG)
    draw = ImageDraw.Draw(img)
    draw.text((44, 24), "Five-Flag Progression", font=F_DIAGRAM_TITLE, fill=C_TITLE)

    n = len(stages)
    margin = 44
    gap = 30
    box_w = (W - 2 * margin - gap * (n - 1)) / n
    y0, y1 = 120, 260
    x = margin
    centers = []
    for num, label in stages:
        box = (x, y0, x + box_w, y1)
        fill, outline, textcolor = (C_OK_FILL, C_OK_OUTLINE, C_OK_TEXT) if num == "5" else (C_BOX_FILL, C_BOX_OUTLINE, C_BOX_TEXT)
        rounded_box(draw, box, fill, outline, radius=14)
        cx = (box[0] + box[2]) / 2
        draw_centered_block(draw, cx, y0 + 14, [
            ([f"FLAG {num}"], F_FLAG_NUM, outline),
            (label.split("\n"), F_STAGE, textcolor),
        ], para_gap=10)
        centers.append(cx)
        x += box_w + gap

    for c0, c1 in zip(centers, centers[1:]):
        arrow(draw, (c0 + box_w / 2, (y0 + y1) / 2), (c1 - box_w / 2, (y0 + y1) / 2), width=3)

    note = "Difficulty and required skill depth increase with each successive flag."
    nw = d.textlength(note, font=F_NOTE)
    draw.text((W / 2 - nw / 2, H - 40), note, font=F_NOTE, fill=C_DESC_TEXT)

    img.save(filename)
    print("wrote", filename, img.size)


# ---------------------------------------------------------------------------
def difficulty_curve_diagram():
    filename = os.path.join(OUT_DIR, "difficulty_curve.png")
    scratch = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(scratch)

    labels = ["Flag 1\nEasy", "Flag 2\nEasy-Medium", "Flag 3\nMedium", "Flag 4\nMedium-Hard", "Flag 5\nHard"]
    heights = [0.30, 0.48, 0.64, 0.82, 1.0]

    W, H = 1000, 460
    img = Image.new("RGB", (W, H), C_BG)
    draw = ImageDraw.Draw(img)
    draw.text((40, 24), "Difficulty Progression", font=F_DIAGRAM_TITLE, fill=C_TITLE)

    chart_left, chart_right = 90, W - 60
    baseline = 360
    top = 90
    n = len(labels)
    gap = 36
    bar_w = (chart_right - chart_left - gap * (n - 1)) / n

    # baseline axis
    draw.line([(chart_left - 20, baseline), (chart_right, baseline)], fill=C_ARROW, width=2)

    x = chart_left
    for label, h in zip(labels, heights):
        bar_h = (baseline - top) * h
        box = (x, baseline - bar_h, x + bar_w, baseline)
        shade = int(180 - 90 * h)
        fill = (231 - shade // 3, 238 - shade // 4, 246)
        rounded_box(draw, box, C_BOX_FILL if h < 1.0 else C_OK_FILL,
                    C_BOX_OUTLINE if h < 1.0 else C_OK_OUTLINE, radius=8)
        cx = (box[0] + box[2]) / 2
        lines = label.split("\n")
        ty = baseline + 14
        for i, l in enumerate(lines):
            fnt = F_STAGE if i == 0 else F_BOX_DESC
            color = C_BOX_TEXT if i == 0 else C_DESC_TEXT
            w = d.textlength(l, font=fnt)
            draw.text((cx - w / 2, ty), l, font=fnt, fill=color)
            ty += text_h(d, l, fnt) + 4
        x += bar_w + gap

    img.save(filename)
    print("wrote", filename, img.size)


if __name__ == "__main__":
    architecture_diagram()
    flag_progression_diagram()
    difficulty_curve_diagram()
