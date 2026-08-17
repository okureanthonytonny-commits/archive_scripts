#!/data/data/com.termux/files/usr/bin/bash
# lib/single_file_compressor.sh — single-file work: format branch,
# compress, verify, delete-original-if-safe. This is the ONLY file that
# should know how to compress one file. multi_file_pipeline.sh just
# calls into this.
# Depends on: track.py (called directly via $SCRIPT_DIR). Not meant to be
# run directly.

compressor_process() {
  local url="$1"
  local month_stage="$2"
  local relpath outdir base ext ext_lower kind out tool_err

  relpath="${url#/storage/emulated/0/}"
  outdir="$month_stage/$(dirname "$relpath")"
  mkdir -p "$outdir"
  base="$(basename "$url")"
  ext="${base##*.}"
  ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  tool_err=""

  if [[ "$url" == *"/WhatsApp/"* ]]; then
    kind="copy"
    out="$outdir/$base"
    if [ ! -s "$out" ]; then
      tool_err=$(cp "$url" "$out" 2>&1 >/dev/null)
    fi

  elif [[ "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" || "$ext_lower" == "png" ]]; then
    kind="webp"
    out="$outdir/${base%.*}.webp"
    if [ ! -s "$out" ]; then
      if [[ "$url" == *"/Screenshots/"* ]]; then
        tool_err=$(cwebp -quiet -lossless "$url" -o "$out" 2>&1 >/dev/null)
      else
        tool_err=$(cwebp -quiet -q 80 "$url" -o "$out" 2>&1 >/dev/null)
      fi
    fi

  elif [[ "$ext_lower" == "mp4" || "$ext_lower" == "mov" ]]; then
    kind="video"
    out="$outdir/$base"
    if [ ! -s "$out" ]; then
      tool_err=$(ffmpeg -nostdin -loglevel error -i "$url" -c:v libx264 -crf 30 -preset medium -c:a copy "$out" 2>&1 >/dev/null)
    fi

  else
    kind="copy"
    out="$outdir/$base"
    if [ ! -s "$out" ]; then
      tool_err=$(cp "$url" "$out" 2>&1 >/dev/null)
    fi
  fi

  # Stamp staged output with the original's mtime -- gives orphan
  # verification a trustworthy time anchor later (rename-proof, unlike
  # filename matching), and the final zip inherits it for free since zip
  # stores each entry's mtime from the file being zipped. Compression
  # itself doesn't preserve mtime (cp with no -p, fresh ffmpeg/cwebp
  # output), so this has to be explicit.
  [ -s "$out" ] && [ -f "$url" ] && touch -r "$url" "$out"

  python3 "$SCRIPT_DIR/lib/track.py" set "$url" COMPRESSED "$kind" "$out" "$tool_err"
}
