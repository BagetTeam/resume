#!/usr/bin/env bash
# Archive EwenGueguen.pdf from Documents/Jobs into old-resume/, then compile
# EwenGueguen.tex and place the new PDF in Documents/Jobs.
# Archive names: EwenGueguen_oldYYYYMM.pdf, then EwenGueguen_oldYYYYMM_2.pdf, _3, ...

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCUMENTS="$(cd "$ROOT/.." && pwd)"
NAME="EwenGueguen"
TEX_FILE="$ROOT/$NAME.tex"
JOBS_DIR="$DOCUMENTS/Jobs"
JOBS_PDF="$JOBS_DIR/$NAME.pdf"
OLD_RESUME_DIR="$ROOT/old-resume"

get_archive_path() {
    local directory="$1"
    local base_name="$2"
    local stamp
    stamp="$(date +%Y%m)"
    local stem="$directory/${base_name}_old${stamp}"
    local first="${stem}.pdf"

    if [[ ! -e "$first" ]]; then
        echo "$first"
        return
    fi

    local idx=2
    while [[ -e "${stem}_${idx}.pdf" ]]; do
        ((idx++))
    done
    echo "${stem}_${idx}.pdf"
}

if [[ ! -f "$TEX_FILE" ]]; then
    echo "Missing TeX source: $TEX_FILE" >&2
    exit 1
fi

if ! command -v pdflatex >/dev/null 2>&1; then
    echo "pdflatex not found. Install MacTeX and ensure pdflatex is on PATH." >&2
    exit 1
fi

archived_pdf=""
if [[ -f "$JOBS_PDF" ]]; then
    mkdir -p "$OLD_RESUME_DIR"
    archived_pdf="$(get_archive_path "$OLD_RESUME_DIR" "$NAME")"
    mv "$JOBS_PDF" "$archived_pdf"
    echo "Archived current CV -> $(basename "$archived_pdf")"
else
    echo "No existing $NAME.pdf in Jobs to archive."
fi

run_pdflatex() {
    local pass="$1"
    local output
    local status=0

    set +e
    output="$(pdflatex \
        -interaction=nonstopmode \
        -halt-on-error \
        -file-line-error \
        "$TEX_FILE" 2>&1)"
    status=$?
    set -e

    if [[ $status -ne 0 ]]; then
        echo "$output" | tail -n 40
        echo "pdflatex pass $pass failed with exit code $status" >&2
        return "$status"
    fi
}

cleanup_aux_files() {
    local ext
    for ext in aux log out toc synctex.gz; do
        local aux_file="$ROOT/$NAME.$ext"
        if [[ -f "$aux_file" ]]; then
            rm -f "$aux_file"
        fi
    done
}

restore_archived_pdf() {
    if [[ -n "$archived_pdf" && -f "$archived_pdf" && ! -f "$JOBS_PDF" ]]; then
        mkdir -p "$JOBS_DIR"
        mv "$archived_pdf" "$JOBS_PDF"
        echo "Compile failed; restored previous PDF to Jobs."
    fi
}

pushd "$ROOT" >/dev/null
if ! (
    run_pdflatex 1
    run_pdflatex 2
    cleanup_aux_files

    if [[ ! -f "$ROOT/$NAME.pdf" ]]; then
        echo "Compilation finished but $NAME.pdf was not produced." >&2
        exit 1
    fi
); then
    popd >/dev/null
    restore_archived_pdf
    exit 1
fi
popd >/dev/null

mkdir -p "$JOBS_DIR"
mv "$ROOT/$NAME.pdf" "$JOBS_PDF"
echo "Wrote $JOBS_PDF"
