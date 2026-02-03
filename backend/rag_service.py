import json
from typing import List

import chromadb
from chromadb.utils import embedding_functions
from openai import OpenAI

from config import CONFIG


_DEFAULT_POLICIES = [
    "Aadhaar must be fully redacted.",
    "PAN should be masked, keep last 4 characters.",
    "Phone numbers should be masked, keep last 4 digits.",
    "Emails should be masked, keep domain visible.",
    "Driving license numbers should be masked.",
    "Passport numbers should be masked.",
    "Voter IDs should be masked.",
    "Bank account numbers should be masked, keep last 4 digits.",
    "IFSC codes should be masked.",
    "IP addresses should be masked.",
    "Dates of birth should be masked.",
    "Addresses should be redacted.",
    "Names (PERSON) should be kept unless policy says otherwise.",
]


def _client() -> OpenAI:
    if not CONFIG.openai_api_key:
        raise ValueError("OPENAI_API_KEY is not configured")
    return OpenAI(api_key=CONFIG.openai_api_key)


def _collection():
    db = chromadb.PersistentClient(path=CONFIG.rag_db_path)
    embed_fn = embedding_functions.OpenAIEmbeddingFunction(
        api_key=CONFIG.openai_api_key,
        model_name=CONFIG.openai_embed_model,
    )
    return db.get_or_create_collection(
        name=CONFIG.rag_collection,
        embedding_function=embed_fn,
    )


def ensure_policy_index() -> None:
    col = _collection()
    if col.count() > 0:
        return
    ids = [f"policy_{i}" for i in range(len(_DEFAULT_POLICIES))]
    col.add(documents=_DEFAULT_POLICIES, ids=ids)


def retrieve_policy_context(query: str, top_k: int) -> List[str]:
    ensure_policy_index()
    col = _collection()
    results = col.query(query_texts=[query], n_results=top_k)
    return results.get("documents", [[]])[0]


def decide_action_rag(pii_item, text: str) -> str:
    pii_type = pii_item.get("type")
    pii_value = pii_item.get("value")
    query = f"Policy for {pii_type} with value {pii_value}"
    context = retrieve_policy_context(query, CONFIG.rag_top_k)

    client = _client()
    prompt = {
        "pii_type": pii_type,
        "pii_value": pii_value,
        "policy_context": context,
        "instruction": "Return JSON with action in {REDACT, MASK, KEEP}.",
    }

    response = client.responses.create(
        model=CONFIG.openai_chat_model,
        input=json.dumps(prompt),
    )

    try:
        content = response.output_text
        data = json.loads(content)
        action = data.get("action", "KEEP")
        if action not in {"REDACT", "MASK", "KEEP"}:
            return "KEEP"
        return action
    except Exception:
        return "KEEP"
