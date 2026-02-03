import argparse
import random
from typing import Dict, Pattern, Set, Tuple

import spacy

from ner_image_utils import PRESET_LABELS, find_entities, iter_images, ocr_image, select_patterns


def _score_sets(pred: Set[Tuple[int, int, str]], gold: Set[Tuple[int, int, str]]) -> Tuple[int, int, int]:
    tp = len(pred & gold)
    fp = len(pred - gold)
    fn = len(gold - pred)
    return tp, fp, fn


def _safe_div(n: int, d: int) -> float:
    return n / d if d else 0.0


def evaluate(
    model_path: str,
    dataset: str,
    patterns: Tuple[Tuple[str, Pattern], ...],
    holdout: float,
    limit: int,
    seed: int,
    preprocess: bool,
    psm: int,
) -> None:
    rng = random.Random(seed)
    image_paths = list(iter_images(dataset))
    if limit and limit > 0:
        image_paths = image_paths[:limit]
    rng.shuffle(image_paths)

    if not image_paths:
        raise RuntimeError("No images found in dataset.")

    holdout_count = max(1, int(len(image_paths) * holdout))
    test_paths = image_paths[:holdout_count]

    nlp = spacy.load(model_path)
    label_set = {label for label, _ in patterns}

    totals: Dict[str, Dict[str, int]] = {label: {"tp": 0, "fp": 0, "fn": 0} for label in label_set}
    micro = {"tp": 0, "fp": 0, "fn": 0}

    used = 0
    for path in test_paths:
        text = ocr_image(path, preprocess=preprocess, psm=psm)
        if not text:
            continue

        used += 1
        gold_entities = find_entities(text, list(patterns))
        gold = {(start, end, label) for start, end, label in gold_entities}

        doc = nlp(text)
        pred = {
            (ent.start_char, ent.end_char, ent.label_)
            for ent in doc.ents
            if ent.label_ in label_set
        }

        tp, fp, fn = _score_sets(pred, gold)
        micro["tp"] += tp
        micro["fp"] += fp
        micro["fn"] += fn

        for label in label_set:
            pred_l = {item for item in pred if item[2] == label}
            gold_l = {item for item in gold if item[2] == label}
            tp_l, fp_l, fn_l = _score_sets(pred_l, gold_l)
            totals[label]["tp"] += tp_l
            totals[label]["fp"] += fp_l
            totals[label]["fn"] += fn_l

    print(f"Evaluated {used} images out of {len(test_paths)} held-out samples.")
    p = _safe_div(micro["tp"], micro["tp"] + micro["fp"])
    r = _safe_div(micro["tp"], micro["tp"] + micro["fn"])
    f1 = _safe_div(2 * p * r, p + r)
    print(f"Micro Precision: {p:.4f}  Recall: {r:.4f}  F1: {f1:.4f}")

    print("Per-label:")
    for label in sorted(label_set):
        tp = totals[label]["tp"]
        fp = totals[label]["fp"]
        fn = totals[label]["fn"]
        p_l = _safe_div(tp, tp + fp)
        r_l = _safe_div(tp, tp + fn)
        f1_l = _safe_div(2 * p_l * r_l, p_l + r_l)
        print(f"- {label}: P={p_l:.4f} R={r_l:.4f} F1={f1_l:.4f} (tp={tp}, fp={fp}, fn={fn})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True, help="Path to image dataset root")
    parser.add_argument("--model", required=True, help="Path to spaCy model directory")
    parser.add_argument("--holdout", type=float, default=0.2, help="Hold-out fraction for evaluation")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of images (0 = no limit)")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    parser.add_argument(
        "--label-set",
        choices=sorted(PRESET_LABELS.keys()),
        default="all",
        help="Label subset to evaluate",
    )
    parser.add_argument(
        "--preprocess",
        action="store_true",
        help="Enable OCR preprocessing (thresholding/contrast/deskew)",
    )
    parser.add_argument("--psm", type=int, default=6, help="Tesseract page segmentation mode")
    args = parser.parse_args()

    patterns = select_patterns(args.label_set)
    evaluate(
        model_path=args.model,
        dataset=args.dataset,
        patterns=tuple(patterns),
        holdout=args.holdout,
        limit=args.limit,
        seed=args.seed,
        preprocess=args.preprocess,
        psm=args.psm,
    )


if __name__ == "__main__":
    main()
