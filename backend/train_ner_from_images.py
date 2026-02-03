import argparse
import os
import random
from typing import List, Pattern, Tuple

import spacy
from spacy.training.example import Example

from ner_image_utils import PRESET_LABELS, find_entities, iter_images, ocr_image, select_patterns


def build_training_examples(texts: List[str], patterns: List[Tuple[str, Pattern]]) -> List[Example]:
    nlp = spacy.blank("en")
    for label, _ in patterns:
        if label not in nlp.vocab.strings:
            nlp.vocab.strings.add(label)

    examples: List[Example] = []
    for text in texts:
        if not text:
            continue
        entities = find_entities(text, patterns)
        if not entities:
            continue
        doc = nlp.make_doc(text)
        example = Example.from_dict(doc, {"entities": entities})
        examples.append(example)
    return examples


def train_ner(examples: List[Example], patterns: List[Tuple[str, Pattern]], output_dir: str, epochs: int) -> None:
    if not examples:
        raise RuntimeError("No training examples were generated.")

    nlp = spacy.blank("en")
    ner = nlp.add_pipe("ner")
    for label, _ in patterns:
        ner.add_label(label)

    nlp.initialize(lambda: examples)
    for epoch in range(epochs):
        random.shuffle(examples)
        losses = {}
        nlp.update(examples, drop=0.2, losses=losses)
        print(f"Epoch {epoch + 1}/{epochs} - Loss: {losses.get('ner', 0):.4f}")

    os.makedirs(output_dir, exist_ok=True)
    nlp.to_disk(output_dir)
    print(f"Model saved to: {output_dir}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True, help="Path to image dataset root")
    parser.add_argument("--output", required=True, help="Output path for spaCy model")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of images (0 = no limit)")
    parser.add_argument("--epochs", type=int, default=20, help="Training epochs")
    parser.add_argument(
        "--label-set",
        choices=sorted(PRESET_LABELS.keys()),
        default="all",
        help="Label subset to train",
    )
    parser.add_argument(
        "--preprocess",
        action="store_true",
        help="Enable OCR preprocessing (thresholding/contrast/deskew)",
    )
    parser.add_argument("--psm", type=int, default=6, help="Tesseract page segmentation mode")
    args = parser.parse_args()

    patterns = select_patterns(args.label_set)

    image_paths = list(iter_images(args.dataset))
    if args.limit and args.limit > 0:
        image_paths = image_paths[: args.limit]

    texts = []
    for path in image_paths:
        text = ocr_image(path, preprocess=args.preprocess, psm=args.psm)
        if text:
            texts.append(text)

    examples = build_training_examples(texts, patterns)
    train_ner(examples, patterns, args.output, args.epochs)


if __name__ == "__main__":
    main()
