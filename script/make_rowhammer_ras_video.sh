#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFMPEG="${FFMPEG:-${ROOT_DIR}/.tools/ffmpeg/ffmpeg}"
OUT_DIR="${ROOT_DIR}/docs/videos"
WORK_DIR="${ROOT_DIR}/ramulator_out/video_work"
OUT_MP4="${OUT_DIR}/rowhammer_ras_demo.mp4"

if [[ ! -x "${FFMPEG}" ]]; then
  echo "ffmpeg not found at ${FFMPEG}" >&2
  echo "Set FFMPEG=/path/to/ffmpeg or install the local static ffmpeg first." >&2
  exit 1
fi

mkdir -p "${OUT_DIR}" "${WORK_DIR}"

ASS_FILE="${WORK_DIR}/rowhammer_ras_demo.ass"
FILTER_FILE="${WORK_DIR}/rowhammer_ras_demo.filters"

cat > "${ASS_FILE}" <<'EOF'
[Script Info]
Title: RowHammer RAS Demo
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Title,DejaVu Sans,42,&H001F2937,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1
Style: Body,DejaVu Sans,25,&H004B5563,&H000000FF,&H00FFFFFF,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1
Style: Small,DejaVu Sans,22,&H004B5563,&H000000FF,&H00FFFFFF,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1
Style: Label,DejaVu Sans,24,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,1,0,0,0,100,100,0,0,1,0,0,5,0,0,0,1
Style: Red,DejaVu Sans,26,&H001C1CB9,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1
Style: Green,DejaVu Sans,28,&H00346516,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1
Style: Blue,DejaVu Sans,28,&H00D84D1D,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1
Style: Orange,DejaVu Sans,24,&H000C41C2,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1
Style: Mono,DejaVu Sans Mono,28,&H00111827,&H000000FF,&H00FFFFFF,&H00000000,1,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:00:07.00,Title,,0,0,0,,{\pos(64,70)}RowHammer: a DRAM RAS problem
Dialogue: 0,0:00:00.00,0:00:07.00,Body,,0,0,0,,{\pos(64,145)}Repeated row activation can disturb nearby rows.\NThe risk is silent data corruption before normal refresh restores charge.
Dialogue: 0,0:00:00.00,0:00:07.00,Label,,0,0,0,,{\pos(230,352)}Aggressor
Dialogue: 0,0:00:00.00,0:00:07.00,Label,,0,0,0,,{\pos(640,352)}Victim
Dialogue: 0,0:00:00.00,0:00:07.00,Label,,0,0,0,,{\pos(1050,352)}Aggressor

Dialogue: 0,0:00:07.00,0:00:15.00,Title,,0,0,0,,{\pos(64,50)}1. Normal DDR operation
Dialogue: 0,0:00:07.00,0:00:15.00,Body,,0,0,0,,{\pos(64,115)}Rows are activated, read, restored, and closed.\NRegular refresh keeps charge margins healthy.
Dialogue: 0,0:00:07.00,0:00:15.00,Small,,0,0,0,,{\pos(35,250)}Row N-1
Dialogue: 0,0:00:07.00,0:00:15.00,Small,,0,0,0,,{\pos(35,310)}Row N
Dialogue: 0,0:00:07.00,0:00:15.00,Small,,0,0,0,,{\pos(35,370)}Row N+1
Dialogue: 0,0:00:07.00,0:00:15.00,Small,,0,0,0,,{\pos(35,430)}Row N+2
Dialogue: 0,0:00:07.00,0:00:15.00,Blue,,0,0,0,,{\pos(720,330)}Refresh restores charge
Dialogue: 0,0:00:07.00,0:00:15.00,Small,,0,0,0,,{\pos(720,370)}No data error

Dialogue: 0,0:00:15.00,0:00:23.00,Title,,0,0,0,,{\pos(64,50)}2. Hammering aggressor rows
Dialogue: 0,0:00:15.00,0:00:23.00,Body,,0,0,0,,{\pos(64,115)}The workload alternates two rows in the same bank.\NThis creates repeated ACT -> RD -> PRE commands inside a refresh window.
Dialogue: 0,0:00:15.00,0:00:23.00,Orange,,0,0,0,,{\pos(155,313)}Aggressor row A
Dialogue: 0,0:00:15.00,0:00:23.00,Red,,0,0,0,,{\pos(155,373)}Victim row disturbed
Dialogue: 0,0:00:15.00,0:00:23.00,Orange,,0,0,0,,{\pos(155,433)}Aggressor row B
Dialogue: 0,0:00:15.00,0:00:23.00,Orange,,0,0,0,,{\pos(615,313)}ACT -> RD -> PRE repeated
Dialogue: 0,0:00:15.00,0:00:23.00,Orange,,0,0,0,,{\pos(615,433)}ACT -> RD -> PRE repeated
Dialogue: 0,0:00:15.00,0:00:23.00,Red,,0,0,0,,{\pos(585,369)}Charge margin shrinks

Dialogue: 0,0:00:23.00,0:00:31.00,Title,,0,0,0,,{\pos(64,50)}3. Victim-row bit flip
Dialogue: 0,0:00:23.00,0:00:31.00,Body,,0,0,0,,{\pos(64,115)}If disturbance exceeds retention margin, a victim cell can flip.\NThis is the RAS failure mode: data changes without a normal write.
Dialogue: 0,0:00:23.00,0:00:31.00,Red,,0,0,0,,{\pos(160,290)}Victim row data
Dialogue: 0,0:00:23.00,0:00:31.00,Label,,0,0,0,,{\pos(200,371)}1
Dialogue: 0,0:00:23.00,0:00:31.00,Label,,0,0,0,,{\pos(290,371)}1
Dialogue: 0,0:00:23.00,0:00:31.00,Label,,0,0,0,,{\pos(380,371)}0
Dialogue: 0,0:00:23.00,0:00:31.00,Red,,0,0,0,,{\pos(330,415)}bit flipped
Dialogue: 0,0:00:23.00,0:00:31.00,Red,,0,0,0,,{\pos(675,322)}RAS impact
Dialogue: 0,0:00:23.00,0:00:31.00,Small,,0,0,0,,{\pos(675,358)}Silent corruption
Dialogue: 0,0:00:23.00,0:00:31.00,Small,,0,0,0,,{\pos(675,388)}Crash or security issue

Dialogue: 0,0:00:31.00,0:00:40.00,Title,,0,0,0,,{\pos(64,50)}4. DDR4 mitigation in this demo
Dialogue: 0,0:00:31.00,0:00:40.00,Body,,0,0,0,,{\pos(64,115)}Ramulator2 model: DDR4-VRR + OracleRH, tRH = 4\N10,000 reads trigger victim-row refresh commands.
Dialogue: 0,0:00:31.00,0:00:40.00,Title,,0,0,0,,{\fs30\pos(120,260)}10,000-read simulation result
Dialogue: 0,0:00:31.00,0:00:40.00,Green,,0,0,0,,{\pos(140,325)}DDR4-2400R   ACT 9999   VRR 2135\NDDR4-3200AA  ACT 9999   VRR 1602
Dialogue: 0,0:00:31.00,0:00:40.00,Green,,0,0,0,,{\pos(805,343)}VRR triggered
Dialogue: 0,0:00:31.00,0:00:40.00,Small,,0,0,0,,{\pos(805,378)}Victim-row refresh

Dialogue: 0,0:00:40.00,0:00:49.00,Title,,0,0,0,,{\pos(64,50)}5. DDR5 direction at 3200 MT/s
Dialogue: 0,0:00:40.00,0:00:49.00,Body,,0,0,0,,{\pos(64,115)}DDR5 model exposes RFM and DRFM command timing.\NThis pinned source does not yet include an automatic DDR5 RFM RowHammer plugin.
Dialogue: 0,0:00:40.00,0:00:49.00,Title,,0,0,0,,{\fs30\pos(120,260)}DDR5 command-level comparison
Dialogue: 0,0:00:40.00,0:00:49.00,Blue,,0,0,0,,{\fs25\pos(140,325)}DDR5-3200BN  ACT 9999   RFM/DRFM 0\NNext: ACT counter -> threshold\NIssue RFM/DRFM request
Dialogue: 0,0:00:40.00,0:00:49.00,Blue,,0,0,0,,{\fs25\pos(835,386)}RFM support exists
Dialogue: 0,0:00:40.00,0:00:49.00,Small,,0,0,0,,{\fs19\pos(835,418)}Plugin still needed

Dialogue: 0,0:00:49.00,0:00:57.00,Title,,0,0,0,,{\pos(64,60)}Demo takeaway
Dialogue: 0,0:00:49.00,0:00:57.00,Body,,0,0,0,,{\pos(64,140)}RowHammer is a command-rate and refresh-window RAS problem.\NDDR4 demo: VRR mitigation triggers.\NDDR5 demo: equal-frequency command comparison is ready.\NNext engineering step: add an RFM mitigation plugin.
Dialogue: 0,0:00:49.00,0:00:57.00,Green,,0,0,0,,{\fs25\pos(130,455)}DDR4: VRR demo works
Dialogue: 0,0:00:49.00,0:00:57.00,Blue,,0,0,0,,{\fs25\pos(530,455)}DDR5: add RFM plugin next
EOF

cat > "${FILTER_FILE}" <<EOF
[0:v]
drawbox=x=64:y=255:w=1152:h=250:color=white:t=fill:enable='between(t,0,7)',
drawbox=x=64:y=255:w=1152:h=250:color=0xcbd5e1:t=3:enable='between(t,0,7)',
drawbox=x=150:y=330:w=160:h=45:color=0xf97316:t=fill:enable='between(t,0,7)',
drawbox=x=560:y=330:w=160:h=45:color=0xef4444:t=fill:enable='between(t,0,7)',
drawbox=x=970:y=330:w=160:h=45:color=0xf97316:t=fill:enable='between(t,0,7)',
drawbox=x=110:y=230:w=900:h=300:color=white:t=fill:enable='between(t,7,15)',
drawbox=x=110:y=230:w=900:h=300:color=0xcbd5e1:t=3:enable='between(t,7,15)',
drawbox=x=110:y=290:w=900:h=3:color=0xcbd5e1:t=fill:enable='between(t,7,15)',
drawbox=x=110:y=350:w=900:h=3:color=0xcbd5e1:t=fill:enable='between(t,7,15)',
drawbox=x=110:y=410:w=900:h=3:color=0xcbd5e1:t=fill:enable='between(t,7,15)',
drawbox=x=170:y=248:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=245:y=248:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=320:y=248:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=170:y=308:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=245:y=308:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=320:y=308:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=170:y=368:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=245:y=368:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=320:y=368:w=54:h=30:color=0x22c55e:t=fill:enable='between(t,7,15)',
drawbox=x=700:y=305:w=245:h=105:color=0xecfeff:t=fill:enable='between(t,7,15)',
drawbox=x=700:y=305:w=245:h=105:color=0x06b6d4:t=3:enable='between(t,7,15)',
drawbox=x=120:y=225:w=900:h=310:color=white:t=fill:enable='between(t,15,23)',
drawbox=x=120:y=295:w=900:h=60:color=0xfff7ed:t=fill:enable='between(t,15,23)',
drawbox=x=120:y=355:w=900:h=60:color=0xfef2f2:t=fill:enable='between(t,15,23)',
drawbox=x=120:y=415:w=900:h=60:color=0xfff7ed:t=fill:enable='between(t,15,23)',
drawbox=x=120:y=225:w=900:h=310:color=0xcbd5e1:t=3:enable='between(t,15,23)',
drawbox=x=565:y=360:w=330:h=45:color=0xfee2e2:t=fill:enable='between(t,15,23)',
drawbox=x=120:y=245:w=900:h=245:color=white:t=fill:enable='between(t,23,31)',
drawbox=x=120:y=335:w=900:h=70:color=0xfef2f2:t=fill:enable='between(t,23,31)',
drawbox=x=120:y=245:w=900:h=245:color=0xcbd5e1:t=3:enable='between(t,23,31)',
drawbox=x=165:y=350:w=70:h=42:color=0x22c55e:t=fill:enable='between(t,23,31)',
drawbox=x=255:y=350:w=70:h=42:color=0x22c55e:t=fill:enable='between(t,23,31)',
drawbox=x=345:y=350:w=70:h=42:color=0xdc2626:t=fill:enable='between(t,23,31)',
drawbox=x=650:y=300:w=285:h=118:color=0xfef2f2:t=fill:enable='between(t,23,31)',
drawbox=x=650:y=300:w=285:h=118:color=0xef4444:t=3:enable='between(t,23,31)',
drawbox=x=80:y=230:w=1120:h=270:color=white:t=fill:enable='between(t,31,40)',
drawbox=x=80:y=230:w=1120:h=270:color=0xcbd5e1:t=3:enable='between(t,31,40)',
drawbox=x=760:y=310:w=300:h=92:color=0xdcfce7:t=fill:enable='between(t,31,40)',
drawbox=x=760:y=310:w=300:h=92:color=0x22c55e:t=3:enable='between(t,31,40)',
drawbox=x=80:y=230:w=1120:h=270:color=white:t=fill:enable='between(t,40,49)',
drawbox=x=80:y=230:w=1120:h=270:color=0xcbd5e1:t=3:enable='between(t,40,49)',
drawbox=x=805:y=360:w=310:h=100:color=0xeff6ff:t=fill:enable='between(t,40,49)',
drawbox=x=805:y=360:w=310:h=100:color=0x3b82f6:t=3:enable='between(t,40,49)',
drawbox=x=95:y=425:w=335:h=75:color=0xdcfce7:t=fill:enable='between(t,49,57)',
drawbox=x=95:y=425:w=335:h=75:color=0x22c55e:t=3:enable='between(t,49,57)',
drawbox=x=500:y=425:w=430:h=75:color=0xeff6ff:t=fill:enable='between(t,49,57)',
drawbox=x=500:y=425:w=430:h=75:color=0x3b82f6:t=3:enable='between(t,49,57)',
ass=${ASS_FILE},
format=yuv420p[v]
EOF

"${FFMPEG}" -y \
  -f lavfi -i "color=c=0xf7f8fb:s=1280x720:d=57:r=30" \
  -filter_complex_script "${FILTER_FILE}" \
  -map "[v]" \
  -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p \
  -movflags +faststart \
  "${OUT_MP4}"

echo "Generated ${OUT_MP4}"
