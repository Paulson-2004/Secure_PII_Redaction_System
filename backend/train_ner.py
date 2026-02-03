import spacy
from spacy.training.example import Example
import random

# ----------------------------
# STEP 1: CREATE BLANK MODEL
# ----------------------------
nlp = spacy.blank("en")

# Add NER pipeline
if "ner" not in nlp.pipe_names:
    ner = nlp.add_pipe("ner")
else:
    ner = nlp.get_pipe("ner")

# ----------------------------
# STEP 2: ADD CUSTOM LABELS
# ----------------------------
LABELS = ["PERSON", "AADHAAR", "PAN", "PHONE", "EMAIL"]

for label in LABELS:
    ner.add_label(label)

# ----------------------------
# STEP 3: TRAINING DATA
# ----------------------------
TRAIN_DATA = [
    ("My Aadhaar number is 1234 5678 9012",
     {"entities": [(21, 35, "AADHAAR")]}),

    ("PAN number ABCDE1234F belongs to Rahul",
     {"entities": [(11, 21, "PAN"), (33, 38, "PERSON")]}),

    ("Contact me at 9876543210",
     {"entities": [(14, 24, "PHONE")]}),

    ("Email id is rahul@gmail.com",
     {"entities": [(12, 28, "EMAIL")]}),

    ("Paulson J has PAN XYZAB1234K",
     {"entities": [(0, 9, "PERSON"), (18, 28, "PAN")]})
]
# ----------------------------
# STEP 4: TRAIN MODEL
# ----------------------------
optimizer = nlp.begin_training()

for epoch in range(30):
    random.shuffle(TRAIN_DATA)
    losses = {}

    for text, annotations in TRAIN_DATA:
        doc = nlp.make_doc(text)
        example = Example.from_dict(doc, annotations)
        nlp.update([example], drop=0.3, losses=losses)

    print(f"Epoch {epoch+1}, Loss: {losses}")

# ----------------------------
# STEP 5: SAVE MODEL
# ----------------------------
nlp.to_disk("custom_pii_model")
print("Model training complete. Saved as 'custom_pii_model'")
