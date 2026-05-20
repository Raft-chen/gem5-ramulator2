#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFMPEG="${FFMPEG:-${ROOT_DIR}/.tools/ffmpeg/ffmpeg}"
FFPROBE="${FFPROBE:-${ROOT_DIR}/.tools/ffmpeg/ffprobe}"
TTS_BIN="${TTS_BIN:-${ROOT_DIR}/.tools/tts-venv/bin/edge-tts}"
VOICE="${VOICE:-en-US-RogerNeural}"
RATE="${RATE:-+6%}"

export ROOT_DIR FFMPEG FFPROBE TTS_BIN VOICE RATE

python3 - <<'PY'
import math
import os
import subprocess
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
ffmpeg = Path(os.environ["FFMPEG"])
ffprobe = Path(os.environ["FFPROBE"])
tts_bin = Path(os.environ["TTS_BIN"])
voice = os.environ["VOICE"]
rate = os.environ["RATE"]

out_dir = root / "docs" / "videos"
work_dir = root / "ramulator_out" / "video_work"
audio_dir = work_dir / "audio"
out_mp4 = out_dir / "rowhammer_ras_demo.mp4"
silent_mp4 = work_dir / "rowhammer_ras_demo_silent.mp4"
ass_file = work_dir / "rowhammer_ras_demo.ass"
filter_file = work_dir / "rowhammer_ras_demo.filters"

out_dir.mkdir(parents=True, exist_ok=True)
audio_dir.mkdir(parents=True, exist_ok=True)
for path in audio_dir.glob("*"):
    path.unlink()

if not ffmpeg.exists():
    raise SystemExit(f"ffmpeg not found at {ffmpeg}")
if not ffprobe.exists():
    raise SystemExit(f"ffprobe not found at {ffprobe}")

def run(cmd, **kwargs):
    return subprocess.run([str(c) for c in cmd], check=True, **kwargs)

def ffprobe_duration(path):
    result = subprocess.run(
        [
            str(ffprobe),
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        check=True,
        text=True,
        capture_output=True,
    )
    return float(result.stdout.strip())

def ass_time(seconds):
    cs = int(round(seconds * 100))
    h = cs // 360000
    cs %= 360000
    m = cs // 6000
    cs %= 6000
    s = cs // 100
    c = cs % 100
    return f"{h}:{m:02d}:{s:02d}.{c:02d}"

def ass_text(text):
    return text.replace("\n", r"\N")

def dialogue(start, end, style, text, x, y, extra=""):
    override = f"{{{extra}\\pos({x},{y})}}" if extra else f"{{\\pos({x},{y})}}"
    return (
        f"Dialogue: 0,{ass_time(start)},{ass_time(end)},{style},,0,0,0,,"
        f"{override}{ass_text(text)}"
    )

def box(start, end, x, y, w, h, color, t="fill"):
    return (
        f"drawbox=x={x}:y={y}:w={w}:h={h}:color={color}:t={t}:"
        f"enable='between(t,{start:.2f},{end:.2f})'"
    )

scenes = [
    {
        "id": "01",
        "min": 7.0,
        "title": "RowHammer: a DRAM RAS problem",
        "body": "Repeated row activation can disturb nearby rows.\nThe risk is silent data corruption before normal refresh restores charge.",
        "narration": "RowHammer is a DRAM reliability problem. Repeated row activation can disturb nearby rows, creating a risk of silent data corruption before normal refresh restores charge.",
        "events": [
            ("Label", "Aggressor", 230, 352, ""),
            ("Label", "Victim", 640, 352, ""),
            ("Label", "Aggressor", 1050, 352, ""),
        ],
        "boxes": [
            (64, 255, 1152, 250, "white", "fill"),
            (64, 255, 1152, 250, "0xcbd5e1", "3"),
            (150, 330, 160, 45, "0xf97316", "fill"),
            (560, 330, 160, 45, "0xef4444", "fill"),
            (970, 330, 160, 45, "0xf97316", "fill"),
        ],
    },
    {
        "id": "02",
        "min": 8.0,
        "title": "1. Normal DDR operation",
        "body": "Rows are activated, read, restored, and closed.\nRegular refresh keeps charge margins healthy.",
        "narration": "In normal DDR operation, rows are activated, read, restored, and closed. Periodic refresh keeps cell charge within a healthy margin, so data remains stable.",
        "events": [
            ("Small", "Row N-1", 35, 250, ""),
            ("Small", "Row N", 35, 310, ""),
            ("Small", "Row N+1", 35, 370, ""),
            ("Small", "Row N+2", 35, 430, ""),
            ("Blue", "Refresh restores charge", 720, 330, ""),
            ("Small", "No data error", 720, 370, ""),
        ],
        "boxes": [
            (110, 230, 900, 300, "white", "fill"),
            (110, 230, 900, 300, "0xcbd5e1", "3"),
            (110, 290, 900, 3, "0xcbd5e1", "fill"),
            (110, 350, 900, 3, "0xcbd5e1", "fill"),
            (110, 410, 900, 3, "0xcbd5e1", "fill"),
            (170, 248, 54, 30, "0x22c55e", "fill"),
            (245, 248, 54, 30, "0x22c55e", "fill"),
            (320, 248, 54, 30, "0x22c55e", "fill"),
            (170, 308, 54, 30, "0x22c55e", "fill"),
            (245, 308, 54, 30, "0x22c55e", "fill"),
            (320, 308, 54, 30, "0x22c55e", "fill"),
            (170, 368, 54, 30, "0x22c55e", "fill"),
            (245, 368, 54, 30, "0x22c55e", "fill"),
            (320, 368, 54, 30, "0x22c55e", "fill"),
            (700, 305, 245, 105, "0xecfeff", "fill"),
            (700, 305, 245, 105, "0x06b6d4", "3"),
        ],
    },
    {
        "id": "03",
        "min": 8.0,
        "title": "2. Hammering aggressor rows",
        "body": "The workload alternates two rows in the same bank.\nThis creates repeated ACT -> RD -> PRE commands inside a refresh window.",
        "narration": "The RowHammer access pattern repeatedly opens aggressor rows in the same bank. That creates many activate, read, and precharge commands inside one refresh window.",
        "events": [
            ("Orange", "Aggressor row A", 155, 313, ""),
            ("Red", "Victim row disturbed", 155, 373, ""),
            ("Orange", "Aggressor row B", 155, 433, ""),
            ("Orange", "ACT -> RD -> PRE repeated", 615, 313, ""),
            ("Orange", "ACT -> RD -> PRE repeated", 615, 433, ""),
            ("Red", "Charge margin shrinks", 585, 369, ""),
        ],
        "boxes": [
            (120, 225, 900, 310, "white", "fill"),
            (120, 295, 900, 60, "0xfff7ed", "fill"),
            (120, 355, 900, 60, "0xfef2f2", "fill"),
            (120, 415, 900, 60, "0xfff7ed", "fill"),
            (120, 225, 900, 310, "0xcbd5e1", "3"),
            (565, 360, 330, 45, "0xfee2e2", "fill"),
        ],
    },
    {
        "id": "04",
        "min": 8.0,
        "title": "3. Victim-row bit flip",
        "body": "If disturbance exceeds retention margin, a victim cell can flip.\nThis is the RAS failure mode: data changes without a normal write.",
        "narration": "If the victim row loses enough charge before refresh or mitigation, a stored bit can flip. This is why RowHammer matters for RAS: data changes without a normal write.",
        "events": [
            ("Red", "Victim row data", 160, 290, ""),
            ("Label", "1", 200, 371, ""),
            ("Label", "1", 290, 371, ""),
            ("Label", "0", 380, 371, ""),
            ("Red", "bit flipped", 330, 415, ""),
            ("Red", "RAS impact", 675, 322, ""),
            ("Small", "Silent corruption", 675, 358, ""),
            ("Small", "Crash or security issue", 675, 388, ""),
        ],
        "boxes": [
            (120, 245, 900, 245, "white", "fill"),
            (120, 335, 900, 70, "0xfef2f2", "fill"),
            (120, 245, 900, 245, "0xcbd5e1", "3"),
            (165, 350, 70, 42, "0x22c55e", "fill"),
            (255, 350, 70, 42, "0x22c55e", "fill"),
            (345, 350, 70, 42, "0xdc2626", "fill"),
            (650, 300, 285, 118, "0xfef2f2", "fill"),
            (650, 300, 285, 118, "0xef4444", "3"),
        ],
    },
    {
        "id": "05",
        "min": 9.0,
        "title": "4. DDR4 mitigation in this demo",
        "body": "Ramulator2 model: DDR4-VRR + OracleRH, tRH = 4\n10,000 reads trigger victim-row refresh commands.",
        "narration": "In this demo, DDR4 uses the DDR4 VRR model with Oracle RH. When the activation threshold is crossed, the controller injects victim-row refresh commands.",
        "events": [
            ("Title", "10,000-read simulation result", 120, 260, r"\fs30"),
            ("Green", "DDR4-2400R   ACT 9999   VRR 2135\nDDR4-3200AA  ACT 9999   VRR 1602", 140, 325, ""),
            ("Green", "VRR triggered", 805, 343, ""),
            ("Small", "Victim-row refresh", 805, 378, ""),
        ],
        "boxes": [
            (80, 230, 1120, 270, "white", "fill"),
            (80, 230, 1120, 270, "0xcbd5e1", "3"),
            (760, 310, 300, 92, "0xdcfce7", "fill"),
            (760, 310, 300, 92, "0x22c55e", "3"),
        ],
    },
    {
        "id": "06",
        "min": 9.0,
        "title": "5. DDR5 direction at 3200 MT/s",
        "body": "DDR5 model exposes RFM and DRFM command timing.\nThis pinned source does not yet include an automatic DDR5 RFM RowHammer plugin.",
        "narration": "For DDR5 at 3200 mega transfers per second, Ramulator2 exposes RFM and directed RFM timing. This source tree still needs a DDR5 plugin that turns activation tracking into RFM requests.",
        "events": [
            ("Title", "DDR5 command-level comparison", 120, 260, r"\fs30"),
            ("Blue", "DDR5-3200BN  ACT 9999   RFM/DRFM 0\nNext: ACT counter -> threshold\nIssue RFM/DRFM request", 140, 325, r"\fs25"),
            ("Blue", "RFM support exists", 835, 386, r"\fs25"),
            ("Small", "Plugin still needed", 835, 418, r"\fs19"),
        ],
        "boxes": [
            (80, 230, 1120, 270, "white", "fill"),
            (80, 230, 1120, 270, "0xcbd5e1", "3"),
            (805, 360, 310, 100, "0xeff6ff", "fill"),
            (805, 360, 310, 100, "0x3b82f6", "3"),
        ],
    },
    {
        "id": "07",
        "min": 9.0,
        "title": "6. DDR4 RowHammer test flow",
        "body": "The demo trace performs 10,000 alternating reads.\nThe controller observes 9,999 ACT commands and detects victim-row risk.",
        "narration": "The DDR4 test performs 10,000 alternating reads. When the victim-row risk is detected, the demo records the event, issues victim-row refresh, and reports the result.",
        "events": [
            ("Mono", "1. Hammer aggressor rows\n2. Count ACT commands per row\n3. Threshold crossed: victim row at risk\n4. Issue VRR and halt/report the demo result", 145, 260, r"\fs25"),
            ("Red", "Victim risk detected", 760, 326, ""),
            ("Green", "VRR protects\nneighbor rows", 790, 414, r"\fs25"),
        ],
        "boxes": [
            (100, 230, 1080, 330, "white", "fill"),
            (100, 230, 1080, 330, "0xcbd5e1", "3"),
            (735, 292, 355, 80, "0xfef2f2", "fill"),
            (735, 292, 355, 80, "0xef4444", "3"),
            (760, 390, 355, 80, "0xdcfce7", "fill"),
            (760, 390, 355, 80, "0x22c55e", "3"),
        ],
    },
    {
        "id": "08",
        "min": 9.0,
        "title": "7. DDR5 mitigation next step",
        "body": "DDR5 has standardized RFM and DRFM commands.\nThe missing piece is a controller plugin that issues them from activation tracking.",
        "narration": "The DDR5 next step is clear. Track activations per bank and row, apply a threshold policy, and issue an RFM or directed RFM request.",
        "events": [
            ("Blue", "ACT count\nper bank\nper row", 145, 268, r"\fs25"),
            ("Orange", "Threshold\npolicy", 515, 275, ""),
            ("Green", "RFM / DRFM\nrequest", 865, 275, ""),
            ("Small", "This is the clean next engineering target for the simulator.", 245, 455, ""),
        ],
        "boxes": [
            (125, 250, 250, 135, "0xeff6ff", "fill"),
            (125, 250, 250, 135, "0x3b82f6", "3"),
            (500, 250, 250, 135, "0xfff7ed", "fill"),
            (500, 250, 250, 135, "0xf97316", "3"),
            (850, 250, 250, 135, "0xdcfce7", "fill"),
            (850, 250, 250, 135, "0x22c55e", "3"),
        ],
    },
    {
        "id": "09",
        "min": 8.0,
        "title": "Demo takeaway",
        "body": "RowHammer is a command-rate and refresh-window RAS problem.\nDDR4 demo: VRR mitigation triggers.\nDDR5 demo: equal-frequency command comparison is ready.\nNext engineering step: add an RFM mitigation plugin.",
        "narration": "The takeaway is simple. DDR4 victim-row refresh mitigation works in this demo. DDR5 equal-frequency comparison is ready, and the RFM plugin is next.",
        "events": [
            ("Green", "DDR4: VRR demo works", 130, 455, r"\fs25"),
            ("Blue", "DDR5: add RFM plugin next", 530, 455, r"\fs25"),
        ],
        "boxes": [
            (95, 425, 335, 75, "0xdcfce7", "fill"),
            (95, 425, 335, 75, "0x22c55e", "3"),
            (500, 425, 430, 75, "0xeff6ff", "fill"),
            (500, 425, 430, 75, "0x3b82f6", "3"),
        ],
    },
    {
        "id": "10",
        "min": 10.0,
        "title": None,
        "body": None,
        "narration": "Thank you. I will pause here for questions.",
        "events": [
            ("Title", "Thank you", 470, 265, r"\fs64"),
            ("Body", "Questions and discussion", 392, 360, r"\fs30"),
        ],
        "boxes": [
            (340, 240, 600, 185, "white", "fill"),
            (340, 240, 600, 185, "0xcbd5e1", "3"),
        ],
        "no_transition_after": True,
    },
]

transition_duration = 1.0
transition_hmm_duration = 0.5

scene_audio = []
for scene in scenes:
    mp3 = audio_dir / f"scene_{scene['id']}.mp3"
    if not tts_bin.exists():
        mp3 = None
        duration = scene["min"]
    else:
        run(
            [
                tts_bin,
                "--voice",
                voice,
                f"--rate={rate}",
                "--text",
                scene["narration"],
                "--write-media",
                mp3,
            ],
            stdout=subprocess.DEVNULL,
        )
        duration = ffprobe_duration(mp3)

    scene_duration = max(scene["min"], math.ceil((duration + 0.2) * 2) / 2)
    scene["duration"] = scene_duration
    scene["mp3"] = mp3
    scene_audio.append((scene, mp3))

current = 0.0
ass_lines = [
    "[Script Info]",
    "Title: RowHammer RAS Demo",
    "ScriptType: v4.00+",
    "PlayResX: 1280",
    "PlayResY: 720",
    "",
    "[V4+ Styles]",
    "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
    "Style: Title,DejaVu Sans,42,&H001F2937,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
    "Style: Body,DejaVu Sans,25,&H004B5563,&H000000FF,&H00FFFFFF,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
    "Style: Small,DejaVu Sans,22,&H004B5563,&H000000FF,&H00FFFFFF,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
    "Style: Label,DejaVu Sans,24,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,1,0,0,0,100,100,0,0,1,0,0,5,0,0,0,1",
    "Style: Red,DejaVu Sans,26,&H001C1CB9,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
    "Style: Green,DejaVu Sans,28,&H00346516,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
    "Style: Blue,DejaVu Sans,28,&H00D84D1D,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
    "Style: Orange,DejaVu Sans,24,&H000C41C2,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
    "Style: Mono,DejaVu Sans Mono,28,&H00111827,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1",
    "",
    "[Events]",
    "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
]
filters = []

timeline = []
for idx, scene in enumerate(scenes):
    start = current
    end = start + scene["duration"]
    scene["start"] = start
    scene["end"] = end
    timeline.append((start, end, scene["id"]))

    if scene.get("title"):
        ass_lines.append(dialogue(start, end, "Title", scene["title"], 64, 70 if idx == 0 else 50))
    if scene.get("body"):
        ass_lines.append(dialogue(start, end, "Body", scene["body"], 64, 145 if idx == 0 else 115))
    for style, text, x, y, extra in scene["events"]:
        ass_lines.append(dialogue(start, end, style, text, x, y, extra))
    for x, y, w, h, color, t in scene["boxes"]:
        filters.append(box(start, end, x, y, w, h, color, t))

    current = end
    if not scene.get("no_transition_after"):
        scene["transition_start"] = current
        current += transition_duration

total_duration = current

ass_file.write_text("\n".join(ass_lines) + "\n")
filter_file.write_text(
    "[0:v]\n"
    + ",\n".join(filters)
    + f",\nass={ass_file},\nformat=yuv420p[v]\n"
)

run(
    [
        ffmpeg,
        "-y",
        "-f",
        "lavfi",
        "-i",
        f"color=c=0xf7f8fb:s=1280x720:d={total_duration:.3f}:r=30",
        "-filter_complex_script",
        filter_file,
        "-map",
        "[v]",
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        "20",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        silent_mp4,
    ]
)

def wav_from_mp3(mp3, wav, duration):
    run(
        [
            ffmpeg,
            "-y",
            "-i",
            mp3,
            "-af",
            f"apad,atrim=0:{duration:.3f},asetpts=N/SR/TB",
            "-ar",
            "48000",
            "-ac",
            "2",
            "-c:a",
            "pcm_s16le",
            wav,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

def silence_wav(wav, duration):
    run(
        [
            ffmpeg,
            "-y",
            "-f",
            "lavfi",
            "-i",
            "anullsrc=r=48000:cl=stereo",
            "-t",
            f"{duration:.3f}",
            "-c:a",
            "pcm_s16le",
            wav,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

if tts_bin.exists():
    hmm_mp3 = audio_dir / "hmm.mp3"
    run(
        [
            tts_bin,
            "--voice",
            voice,
            f"--rate={rate}",
            "--text",
            "Hmm.",
            "--write-media",
            hmm_mp3,
        ],
        stdout=subprocess.DEVNULL,
    )

    concat_file = audio_dir / "concat.txt"
    with concat_file.open("w") as concat:
        for idx, scene in enumerate(scenes):
            wav = audio_dir / f"scene_{scene['id']}.wav"
            wav_from_mp3(scene["mp3"], wav, scene["duration"])
            concat.write(f"file '{wav}'\n")

            if not scene.get("no_transition_after"):
                hmm_wav = audio_dir / f"hmm_{scene['id']}.wav"
                silence = audio_dir / f"silence_{scene['id']}.wav"
                wav_from_mp3(hmm_mp3, hmm_wav, transition_hmm_duration)
                silence_wav(silence, transition_duration - transition_hmm_duration)
                concat.write(f"file '{hmm_wav}'\n")
                concat.write(f"file '{silence}'\n")

    narration = audio_dir / "narration.wav"
    run(
        [ffmpeg, "-y", "-f", "concat", "-safe", "0", "-i", concat_file, "-c", "copy", narration],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    run(
        [
            ffmpeg,
            "-y",
            "-i",
            silent_mp4,
            "-i",
            narration,
            "-c:v",
            "copy",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-shortest",
            "-movflags",
            "+faststart",
            out_mp4,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    print(f"Generated {out_mp4} with narration voice {voice}")
else:
    out_mp4.write_bytes(silent_mp4.read_bytes())
    print(f"Generated {out_mp4} without narration; TTS binary not found at {tts_bin}")

print(f"Duration: {total_duration:.1f} seconds")
print("Scene timeline:")
for start, end, sid in timeline:
    print(f"  {sid}: {start:5.1f}s -> {end:5.1f}s")
PY
