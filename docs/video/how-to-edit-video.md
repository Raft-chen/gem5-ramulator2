# How To Edit The RowHammer Demo Video

Edit the video by changing the generator script, not by editing the MP4
directly.

The source of truth is:

```text
script/make_rowhammer_ras_video.sh
```

The generated output is:

```text
docs/videos/rowhammer_ras_demo.mp4
```

## Basic Workflow

Edit the generator:

```bash
vim script/make_rowhammer_ras_video.sh
```

Regenerate the video:

```bash
bash script/make_rowhammer_ras_video.sh
```

Open or download the generated MP4:

```text
docs/videos/rowhammer_ras_demo.mp4
```

If you are working on a desktop with video tools available, this may work:

```bash
xdg-open docs/videos/rowhammer_ras_demo.mp4
```

## Edit Text Placement

Most page layout is controlled inside the `scenes = [...]` list in:

```text
script/make_rowhammer_ras_video.sh
```

Text entries look like this:

```python
("Green", "Key result: DDR4 VRR mitigation is triggered.", 120, 450, r"\fs24")
```

The fields mean:

```text
(style, text, x-position, y-position, extra ASS style)
```

Common edits:

- Move text right: increase `x`.
- Move text left: decrease `x`.
- Move text down: increase `y`.
- Move text up: decrease `y`.
- Make text smaller: change `r"\fs24"` to something like `r"\fs20"`.
- Make text larger: change `r"\fs24"` to something like `r"\fs28"`.

For multi-line text, use `\n` inside the string:

```python
"ACT count\nper bank\nper row"
```

## Edit Box Placement

Boxes are controlled by entries like this:

```python
(90, 432, 700, 55, "0xdcfce7", "fill")
```

The fields mean:

```text
(x, y, width, height, color, border-or-fill)
```

Common edits:

- Move the box right: increase `x`.
- Move the box left: decrease `x`.
- Move the box down: increase `y`.
- Move the box up: decrease `y`.
- Make the box wider: increase `width`.
- Make the box taller: increase `height`.

If text overlaps a box border, usually increase the box height or adjust the
text `y` position.

## Edit Scene Timing

The generator measures each generated narration clip and keeps the page visible
until the narration is complete.

Each scene also has a minimum duration:

```python
"min": 9.0,
```

If a page still switches too quickly, increase its `min` value.

Between major scenes, the generator inserts a one-second silent transition
before the next frame appears.

## Edit Narration

Narration text lives inside each scene:

```python
"narration": "The DDR5 next step is clear. Track activations per bank and row...",
```

There is also a readable copy of the narration here:

```text
docs/rowhammer-video-narration.md
```

If you edit narration in the script, update the markdown file too so the docs
stay consistent.

The default generated voice is:

```text
en-US-RogerNeural
```

You can override it when regenerating:

```bash
VOICE=en-US-BrianNeural bash script/make_rowhammer_ras_video.sh
```

## Commit Changes

After editing and regenerating:

```bash
git add script/make_rowhammer_ras_video.sh docs/videos/rowhammer_ras_demo.mp4
git commit -m "Adjust RowHammer video layout"
git push origin main
```

If you also update narration docs:

```bash
git add docs/rowhammer-video-narration.md docs/video/how-to-edit-video.md
```

## Avoid Direct MP4 Editing

Avoid editing `docs/videos/rowhammer_ras_demo.mp4` directly in a video editor
unless you only need a one-off artifact. Direct MP4 edits are hard to reproduce.

For maintainable work, change:

```text
script/make_rowhammer_ras_video.sh
```

then regenerate the MP4.
