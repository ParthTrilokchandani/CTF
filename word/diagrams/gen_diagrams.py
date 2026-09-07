"""
Generates the flowchart/diagram PNGs used inside the Word documentation.
Run once from anywhere: python3 gen_diagrams.py
Requires: Pillow (PIL). No internet access needed.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = "C:/Windows/Fonts/"


def font(name, size):
    try:
        return ImageFont.truetype(FONT_DIR + name, size)
    except Exception:
        return ImageFont.load_default()


F_DIAGRAM_TITLE = font("segoeuib.ttf", 26)
F_BOX_TITLE = font("segoeuib.ttf", 17)
F_BOX_DESC = font("segoeui.ttf", 14)
F_TAG = font("segoeuib.ttf", 15)
F_SMALL = font("segoeui.ttf", 13)

C_BG = (255, 255, 255)
C_BOX_FILL = (231, 238, 246)
C_BOX_OUTLINE = (35, 62, 96)
C_BOX_TEXT = (24, 33, 46)
C_DESC_TEXT = (70, 80, 92)
C_FLAG_FILL = (255, 242, 209)
C_FLAG_OUTLINE = (163, 110, 12)
C_FLAG_TEXT = (110, 74, 8)
C_ARROW = (70, 80, 95)
C_TITLE = (122, 31, 43)
C_DANGER_FILL = (250, 226, 226)
C_DANGER_OUTLINE = (150, 40, 40)
C_DANGER_TEXT = (110, 25, 25)
C_OK_FILL = (223, 238, 227)
C_OK_OUTLINE = (46, 110, 68)
C_OK_TEXT = (30, 80, 48)


def text_h(draw, line, fnt):
    if line == "":
        line = "Ag"
    b = draw.textbbox((0, 0), line, font=fnt)
    return b[3] - b[1]


def wrap(draw, text, fnt, max_w):
    out = []
    for para in text.split("\n"):
        if para == "":
            out.append("")
            continue
        words = para.split(" ")
        cur = ""
        for w in words:
            trial = (cur + " " + w).strip()
            if draw.textlength(trial, font=fnt) <= max_w or not cur:
                cur = trial
            else:
                out.append(cur)
                cur = w
        if cur:
            out.append(cur)
    return out


def draw_centered_block(draw, cx, top_y, lines_with_fonts, line_gap=5, para_gap=10):
    y = top_y
    for lines, fnt, color in lines_with_fonts:
        for i, l in enumerate(lines):
            w = draw.textlength(l, font=fnt)
            draw.text((cx - w / 2, y), l, font=fnt, fill=color)
            y += text_h(draw, l, fnt) + line_gap
        y += para_gap - line_gap
    return y


def block_height(draw, lines_with_fonts, line_gap=5, para_gap=10):
    h = 0
    for lines, fnt, _ in lines_with_fonts:
        for l in lines:
            h += text_h(draw, l, fnt) + line_gap
        h += para_gap - line_gap
    return h


def rounded_box(draw, box, fill, outline, width=2, radius=12):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def arrow(draw, p0, p1, color=C_ARROW, width=3, head=9):
    draw.line([p0, p1], fill=color, width=width)
    angle = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
    for da in (0.5, -0.5):
        a = angle + math.pi - da
        hx = p1[0] + head * math.cos(a)
        hy = p1[1] + head * math.sin(a)
        draw.line([p1, (hx, hy)], fill=color, width=width)


# ---------------------------------------------------------------------------
def vertical_flow(filename, title, nodes, box_w=700, tag_w=190, gap=46, pad=18,
                   margin=44, top=110):
    scratch = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(scratch)

    prepared = []
    for n in nodes:
        title_lines = wrap(d, n["title"], F_BOX_TITLE, box_w - 2 * pad)
        desc_lines = wrap(d, n.get("desc", ""), F_BOX_DESC, box_w - 2 * pad) if n.get("desc") else []
        parts = [(title_lines, F_BOX_TITLE, C_BOX_TEXT)]
        if desc_lines:
            parts.append((desc_lines, F_BOX_DESC, C_DESC_TEXT))
        h = block_height(d, parts) + 2 * pad
        h = max(h, 74)
        prepared.append((n, parts, h))

    total_h = top + sum(h for _, _, h in prepared) + gap * (len(prepared) - 1) + margin
    W = margin + box_w + 60 + tag_w + margin

    img = Image.new("RGB", (int(W), int(total_h)), C_BG)
    draw = ImageDraw.Draw(img)
    draw.text((margin, 38), title, font=F_DIAGRAM_TITLE, fill=C_TITLE)

    x0 = margin
    x1 = x0 + box_w
    y = top
    prev_bottom_center = None
    for n, parts, h in prepared:
        box = (x0, y, x1, y + h)
        rounded_box(draw, box, C_BOX_FILL, C_BOX_OUTLINE)
        draw_centered_block(draw, (x0 + x1) / 2, y + pad, parts)

        if prev_bottom_center is not None:
            arrow(draw, prev_bottom_center, ((x0 + x1) / 2, y))

        if n.get("tag"):
            tag_h = 44
            tag_box = (x1 + 46, y + h / 2 - tag_h / 2, x1 + 46 + tag_w, y + h / 2 + tag_h / 2)
            rounded_box(draw, tag_box, C_FLAG_FILL, C_FLAG_OUTLINE, radius=10)
            tw = draw.textlength(n["tag"], font=F_TAG)
            draw.text((tag_box[0] + (tag_w - tw) / 2, y + h / 2 - text_h(draw, n["tag"], F_TAG) / 2),
                       n["tag"], font=F_TAG, fill=C_FLAG_TEXT)
            arrow(draw, (x1, y + h / 2), (tag_box[0], y + h / 2), C_FLAG_OUTLINE, width=2, head=7)

        prev_bottom_center = ((x0 + x1) / 2, y + h)
        y += h + gap

    img.save(filename)
    print("wrote", filename, img.size)


# ---------------------------------------------------------------------------
def attack_path_diagram():
    nodes = [
        {"title": "1. LAN", "desc": "Players receive only the target IP address."},
        {"title": "2. Website reconnaissance",
         "desc": "Homepage, About, Contact, and navigation. Look for what isn't linked."},
        {"title": "3. robots.txt -> hidden page", "tag": "FLAG 1",
         "desc": "A disallowed path leads to an internal-looking page. Scroll past the filler content."},
        {"title": "4. Homepage image -> steghide -> rockyou.txt",
         "desc": "Crack the passphrase, extract the hidden file (its filename reveals the username), decode the password inside it."},
        {"title": "5. SSH as the low-privileged user", "tag": "FLAG 2",
         "desc": "Enumerate the home directory, including a directory a plain listing won't show."},
        {"title": "6. Follow the hidden clue to the backups", "tag": "FLAG 3",
         "desc": "Two backup directories exist on the system. Only one of them is real."},
        {"title": "7. Recover the second user's access key",
         "desc": "The key was left behind in the backup area, readable by more than it should be."},
        {"title": "8. SSH as the mid-privileged user", "tag": "FLAG 4",
         "desc": "Review its command history for something that was never fully erased."},
        {"title": "9. sudo -l -> exactly one allowed root command",
         "desc": "Transfer the target binary out (a built-in Python HTTP server works), then reverse engineer it."},
        {"title": "10. Run the allowed command with the recovered password", "tag": "FLAG 5",
         "desc": "The resulting shell is root. Decode the file left behind in root's home directory."},
    ]
    vertical_flow(os.path.join(OUT_DIR, "attack_path.png"),
                  "Intended Attack Path", nodes, box_w=760, tag_w=180)


# ---------------------------------------------------------------------------
def install_workflow_diagram():
    nodes = [
        {"title": "Pre-flight checks",
         "desc": "Root, Ubuntu, and a real (non-placeholder) steghide passphrase are all required before anything runs."},
        {"title": "Persist project source",
         "desc": "The checkout is copied to /opt/ctf/src so later scripts can run without the original copy."},
        {"title": "Install packages",
         "desc": "apache2, steghide, imagemagick, openssh-server, gcc, make, ufw, openssl, python3."},
        {"title": "Generate secrets",
         "desc": "5 random flags plus the Agent99 and .beroot passwords - recorded only in the root-only organizer manifest."},
        {"title": "Deploy website + stego image",
         "desc": "Website, robots.txt, hidden Flag-1 page; a placeholder image generated and embedded with steghide."},
        {"title": "Create users + populate home directories",
         "desc": "Agent99 and Agent999 accounts, Flag 2, the hidden clue, Flag 4 in bash history, authorized_keys."},
        {"title": "Backup challenge + SSH configuration",
         "desc": "Flag 3 and the access key deployed; SSH moved to its custom port, root login disabled."},
        {"title": "Build .beroot + sudo rule",
         "desc": "Compiled with a random password, source removed; one exact-match sudoers rule installed."},
        {"title": "Flags 1 & 5, rabbit hole, firewall",
         "desc": "Web flag embedded, root flag written, decoy SUID binary installed, ufw opened only for web, SSH, and the file-transfer port range."},
        {"title": "Validate",
         "desc": "health_check.sh runs automatically and reports CTF STATUS: READY or FAILED."},
    ]
    vertical_flow(os.path.join(OUT_DIR, "install_workflow.png"),
                  "install_ctf.sh Workflow", nodes, box_w=760, tag_w=1, gap=40)


# ---------------------------------------------------------------------------
def reset_workflow_diagram():
    filename = os.path.join(OUT_DIR, "reset_workflow.png")
    scratch = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(scratch)

    W, H = 1180, 620
    img = Image.new("RGB", (W, H), C_BG)
    draw = ImageDraw.Draw(img)
    draw.text((44, 30), "Reset Options", font=F_DIAGRAM_TITLE, fill=C_TITLE)

    top_box = (44, 100, W - 44, 170)
    rounded_box(draw, top_box, C_BOX_FILL, C_BOX_OUTLINE)
    lines = wrap(d, "Need the CTF back in a clean state?", F_BOX_TITLE, top_box[2] - top_box[0] - 40)
    draw_centered_block(draw, W / 2, 118, [(lines, F_BOX_TITLE, C_BOX_TEXT)])

    col_w = (W - 44 * 2 - 40 * 2) / 3
    cols = [
        ("Option A", "Proxmox snapshot restore", C_OK_FILL, C_OK_OUTLINE, C_OK_TEXT,
         "Fastest & most reliable. Restores the exact\nstate you verified READY.\nNever touches other VMs/host/LAN."),
        ("Option B", "reset_ctf.sh", C_BOX_FILL, C_BOX_OUTLINE, C_BOX_TEXT,
         "uninstall + reinstall in place.\nNew random flags & passwords.\nGood between back-to-back sessions."),
        ("Option C", "uninstall_ctf.sh", C_DANGER_FILL, C_DANGER_OUTLINE, C_DANGER_TEXT,
         "Full teardown, no reinstall.\nKeeps /opt/ctf/src + secrets.\nUse when decommissioning."),
    ]
    y0 = 230
    y1 = 560
    x = 44
    for label, name, fill, outline, textcolor, desc in cols:
        box = (x, y0, x + col_w, y1)
        rounded_box(draw, box, fill, outline)
        arrow(draw, (W / 2, 170), ((box[0] + box[2]) / 2, y0), C_ARROW, width=2, head=7)
        cx = (box[0] + box[2]) / 2
        label_lines = [label]
        name_lines = wrap(d, name, F_BOX_TITLE, col_w - 30)
        desc_lines = []
        for para in desc.split("\n"):
            desc_lines.extend(wrap(d, para, F_BOX_DESC, col_w - 30))
        parts = [
            (label_lines, F_TAG, textcolor),
            (name_lines, F_BOX_TITLE, C_BOX_TEXT),
            (desc_lines, F_BOX_DESC, C_DESC_TEXT),
        ]
        draw_centered_block(draw, cx, y0 + 22, parts, para_gap=14)
        x += col_w + 40

    img.save(filename)
    print("wrote", filename, img.size)


# ---------------------------------------------------------------------------
def user_privilege_diagram():
    filename = os.path.join(OUT_DIR, "user_privilege.png")
    scratch = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(scratch)

    W, H = 1180, 520
    img = Image.new("RGB", (W, H), C_BG)
    draw = ImageDraw.Draw(img)
    draw.text((44, 30), "Users & Privilege Boundaries", font=F_DIAGRAM_TITLE, fill=C_TITLE)

    col_w = (W - 44 * 2 - 60 * 2) / 3
    y0, y1 = 110, 430
    cols = [
        ("Agent99", "Low privilege", C_BOX_FILL, C_BOX_OUTLINE,
         "Password login (from the\nsteghide payload).\nNo sudo rights at all.\nCannot read Agent999's\nhome directory or /root."),
        ("Agent999", "Mid privilege", C_BOX_FILL, C_BOX_OUTLINE,
         "Key-only login (key recovered\nfrom the backup area).\nExactly one sudo rule:\none binary, no arguments.\nCannot read Agent99's home."),
        ("root", "Full privilege", C_OK_FILL, C_OK_OUTLINE,
         "SSH login disabled entirely\n(PermitRootLogin no, password\nlocked).\nOnly reachable through the one\npermitted sudo command."),
    ]
    x = 44
    centers = []
    for name, sub, fill, outline, desc in cols:
        box = (x, y0, x + col_w, y1)
        rounded_box(draw, box, fill, outline)
        cx = (box[0] + box[2]) / 2
        name_lines = [name]
        sub_lines = [sub]
        desc_lines = []
        for para in desc.split("\n"):
            desc_lines.extend(wrap(d, para, F_BOX_DESC, col_w - 30))
        parts = [
            (name_lines, F_DIAGRAM_TITLE, C_TITLE),
            (sub_lines, F_TAG, C_DESC_TEXT),
            (desc_lines, F_BOX_DESC, C_DESC_TEXT),
        ]
        draw_centered_block(draw, cx, y0 + 20, parts, para_gap=16)
        centers.append(cx)
        x += col_w + 60

    mid_y = (y0 + y1) / 2
    arrow(draw, (centers[0] + col_w / 2, mid_y), (centers[1] - col_w / 2, mid_y))
    arrow(draw, (centers[1] + col_w / 2, mid_y), (centers[2] - col_w / 2, mid_y))

    label1 = "steghide password"
    label2 = "sudo + recovered password"
    w1 = draw.textlength(label1, font=F_SMALL)
    w2 = draw.textlength(label2, font=F_SMALL)
    draw.text(((centers[0] + centers[1]) / 2 - w1 / 2, mid_y - 28), label1, font=F_SMALL, fill=C_ARROW)
    draw.text(((centers[1] + centers[2]) / 2 - w2 / 2, mid_y - 28), label2, font=F_SMALL, fill=C_ARROW)

    img.save(filename)
    print("wrote", filename, img.size)


# ---------------------------------------------------------------------------
def network_topology_diagram():
    filename = os.path.join(OUT_DIR, "network_topology.png")
    scratch = Image.new("RGB", (10, 10))
    d = ImageDraw.Draw(scratch)

    W, H = 1180, 640
    img = Image.new("RGB", (W, H), C_BG)
    draw = ImageDraw.Draw(img)
    draw.text((44, 30), "Network Isolation", font=F_DIAGRAM_TITLE, fill=C_TITLE)

    # Proxmox host boundary (danger zone)
    host_box = (44, 100, 560, 430)
    rounded_box(draw, host_box, (250, 248, 240), (150, 130, 40), radius=14)
    draw.text((host_box[0] + 20, host_box[1] + 16), "Proxmox Host", font=F_BOX_TITLE, fill=C_BOX_TEXT)

    prod_box = (80, 160, 300, 240)
    rounded_box(draw, prod_box, C_DANGER_FILL, C_DANGER_OUTLINE, radius=10)
    draw_centered_block(draw, (prod_box[0] + prod_box[2]) / 2, prod_box[1] + 14,
                         [(["Production", "VMs"], F_BOX_DESC, C_DANGER_TEXT)])

    infra_box = (320, 160, 524, 240)
    rounded_box(draw, infra_box, C_DANGER_FILL, C_DANGER_OUTLINE, radius=10)
    draw_centered_block(draw, (infra_box[0] + infra_box[2]) / 2, infra_box[1] + 6,
                         [(["Router / switch mgmt", "NAS / cloud infra"], F_BOX_DESC, C_DANGER_TEXT)])

    ctf_box = (80, 290, 524, 400)
    rounded_box(draw, ctf_box, C_DANGER_FILL, C_DANGER_OUTLINE, radius=10)
    draw_centered_block(draw, (ctf_box[0] + ctf_box[2]) / 2, ctf_box[1] + 14,
                         [(["Proxmox management network"], F_BOX_DESC, C_DANGER_TEXT)])

    # CTF VM (isolated)
    vm_box = (700, 150, 1136, 320)
    rounded_box(draw, vm_box, C_OK_FILL, C_OK_OUTLINE, radius=14)
    draw_centered_block(draw, (vm_box[0] + vm_box[2]) / 2, vm_box[1] + 16,
                         [(["CTF VM", "(Ubuntu Server 24.04, isolated VLAN/bridge)"], F_BOX_TITLE, C_OK_TEXT),
                          (["Exposes only: 80/tcp (web), 2222/tcp (ssh),", "1337/tcp (file transfer)"], F_BOX_DESC, C_DESC_TEXT)])

    # LAN / players
    lan_box = (700, 400, 1136, 500)
    rounded_box(draw, lan_box, C_BOX_FILL, C_BOX_OUTLINE, radius=14)
    draw_centered_block(draw, (lan_box[0] + lan_box[2]) / 2, lan_box[1] + 24,
                         [(["Player LAN"], F_BOX_TITLE, C_BOX_TEXT)])

    # Arrows
    arrow(draw, ((lan_box[0] + lan_box[2]) / 2, lan_box[1]), ((vm_box[0] + vm_box[2]) / 2, vm_box[3]))
    lbl = "ports 80, 2222 + 1337 only"
    w = draw.textlength(lbl, font=F_SMALL)
    draw.text(((vm_box[0] + vm_box[2]) / 2 - w / 2, (vm_box[3] + lan_box[1]) / 2 - 8), lbl, font=F_SMALL, fill=C_ARROW)

    # No route, host <-> vm
    no_route_y = 230
    draw.line([(host_box[2], no_route_y), (vm_box[0], no_route_y)], fill=C_DANGER_OUTLINE, width=3)
    # cross mark
    cx = (host_box[2] + vm_box[0]) / 2
    draw.line([(cx - 12, no_route_y - 12), (cx + 12, no_route_y + 12)], fill=C_DANGER_OUTLINE, width=4)
    draw.line([(cx - 12, no_route_y + 12), (cx + 12, no_route_y - 12)], fill=C_DANGER_OUTLINE, width=4)
    lbl2 = "NO ROUTE"
    w2 = draw.textlength(lbl2, font=F_TAG)
    draw.text((cx - w2 / 2, no_route_y - 38), lbl2, font=F_TAG, fill=C_DANGER_OUTLINE)

    note = "Dedicated VLAN / isolated bridge recommended between the CTF VM and everything else on the host."
    nw = draw.textlength(note, font=F_SMALL)
    draw.text((W / 2 - nw / 2, H - 40), note, font=F_SMALL, fill=C_DESC_TEXT)

    img.save(filename)
    print("wrote", filename, img.size)


if __name__ == "__main__":
    attack_path_diagram()
    install_workflow_diagram()
    reset_workflow_diagram()
    user_privilege_diagram()
    network_topology_diagram()
