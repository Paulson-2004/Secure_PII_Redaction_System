import argparse
import csv
import os
from pathlib import Path
from typing import List, Tuple

from ner_image_utils import PRESET_LABELS, find_entities, iter_images, ocr_image, select_patterns


def dump_matches(
    dataset: str,
    output_dir: str,
    patterns: List[Tuple[str, object]],
    limit: int,
    preprocess: bool,
    psm: int,
) -> None:
    os.makedirs(output_dir, exist_ok=True)
    image_paths = list(iter_images(dataset))
    if limit and limit > 0:
        image_paths = image_paths[:limit]

    summary_path = os.path.join(output_dir, "summary.csv")
    summary_rows = []

    for path in image_paths:
        text = ocr_image(path, preprocess=preprocess, psm=psm)
        entities = find_entities(text, patterns) if text else []
        out_name = Path(path).name + ".txt"
        out_path = os.path.join(output_dir, out_name)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(f"FILE: {path}\n")
            f.write(f"PREPROCESS: {preprocess}\n")
            f.write("MATCHES:\n")
            for start, end, label in entities:
                snippet = text[start:end]
                f.write(f"- {label} [{start}:{end}]: {snippet}\n")
            f.write("\nTEXT:\n")
            f.write(text or "")

        summary_rows.append(
            {
                "image": path,
                "ocr_length": len(text),
                "match_count": len(entities),
                "labels": ",".join(sorted({label for _, _, label in entities})),
            }
        )

    with open(summary_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=["image", "ocr_length", "match_count", "labels"])
        writer.writeheader()
        writer.writerows(summary_rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True, help="Path to image dataset root")
    parser.add_argument("--output-dir", required=True, help="Directory to write OCR dumps")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of images (0 = no limit)")
    parser.add_argument(
        "--label-set",
        choices=sorted(PRESET_LABELS.keys()),
        default="all",
        help="Label subset to match",
    )
    parser.add_argument(
        "--preprocess",
        action="store_true",
        help="Enable OCR preprocessing (thresholding/contrast/deskew)",
    )
    parser.add_argument("--psm", type=int, default=6, help="Tesseract page segmentation mode")
    args = parser.parse_args()

    patterns = select_patterns(args.label_set)
    dump_matches(
        dataset=args.dataset,
        output_dir=args.output_dir,
        patterns=patterns,
        limit=args.limit,
        preprocess=args.preprocess,
        psm=args.psm,
    )


if __name__ == "__main__":
    main()
