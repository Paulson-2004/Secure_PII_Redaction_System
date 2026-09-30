"""
Module 5: RAG-Based AI Decision Engine.
Authoritative Privacy & Security Policy Corpus & Decision Engine.

AI Architecture:
- Authoritative Privacy & Security Policy Corpus codified across Legislation,
  Regulations, Standards, Official Guidance, and Policy Mappings.
- FAISS vector database + SentenceTransformer embeddings for semantic policy retrieval.
- Embedding caching & batch encoding for ultra-low latency.
- Deterministic TF-IDF / semantic similarity fallback when external vector DB dependencies are offline.
- Explicit distinction between statutory/regulatory requirements, security standards,
  official guidelines, and PrivLock technical recommendation actions.
"""

import math
import logging
import threading
import importlib.util
from collections import Counter

logger = logging.getLogger('rag_decision_engine')

# Module-level placeholders for lazy loading (allows unittests to patch SentenceTransformer)
SentenceTransformer = None
faiss = None

# Check dependency availability without eagerly loading heavy PyTorch weights into memory
try:
    EMBEDDINGS_AVAILABLE = importlib.util.find_spec('sentence_transformers') is not None
except Exception:
    EMBEDDINGS_AVAILABLE = False

try:
    FAISS_AVAILABLE = importlib.util.find_spec('faiss') is not None
except Exception:
    FAISS_AVAILABLE = False

COMPLIANCE_DISCLAIMER = (
    "PrivLock provides technical privacy/security guidance and automated redaction. "
    "It is not legal advice and does not certify regulatory compliance."
)

# Standardized source types:
# - legislation: Primary statutory acts passed by a parliament or legislative body
# - regulation: Subordinate rules/regulations notified pursuant to statutory authority
# - standard: Voluntary/industry published security specifications (e.g. PCI DSS, ISO)
# - official_guidance: Technical guidelines and publications by government/standards bodies (e.g. NIST)
# - policy_mapping: PrivLock-codified document and use-case technical redaction mappings derived from primary sources
SOURCE_TYPES = {'legislation', 'regulation', 'standard', 'official_guidance', 'policy_mapping'}


# ============================================================
# AUTHORITATIVE PRIVACY & SECURITY POLICY CORPUS
# ============================================================

PRIVACY_POLICIES = [
    {
        "id": "POL-001",
        "name": "UIDAI Aadhaar Privacy Framework",
        "pii_type": "AADHAAR",
        "source_type": "legislation",
        "citation": "Aadhaar (Targeted Delivery of Financial and Other Subsidies, Benefits and Services) Act, 2016 (Act 18 of 2016), Sec 29, 38A; Aadhaar (Sharing of Information) Regulations, 2016; UIDAI Circular No. 1 of 2018",
        "version": "Act 18 of 2016 (as amended by Act 14 of 2019)",
        "framework_version": "Aadhaar Act 2016 (Amended 2019)",
        "regulation": "Aadhaar Act 2016 (Sec 29, 38A), UIDAI Circular 2018 & Compendium 2021",
        "jurisdiction": "India (UIDAI / MeitY)",
        "publication_date": "2016-03-26",
        "effective_date": "2016-03-26",
        "status": "enacted",
        "applicability": "Applies to Aadhaar holders, requesting entities, offline verification-seeking entities, and all entities handling 12-digit Aadhaar numbers under Indian jurisdiction.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "source_url": "https://uidai.gov.in/en/legal-framework.html",
        "description": "Statutory restrictions prohibit publishing or public display of core 12-digit Aadhaar numbers under Section 29 of the Aadhaar Act 2016. UIDAI circulars permit masked Aadhaar (first 8 digits masked). PrivLock recommends full redaction or masking of the first 8 digits as an authoritative technical minimization treatment.",
        "policy_text": "Aadhaar number is a 12-digit unique identity number issued by UIDAI under the Aadhaar Act 2016. Section 29 restricts publishing or displaying Aadhaar numbers publicly. PrivLock recommends full redaction or masking as a technical minimization treatment.",
        "topics": ["aadhaar", "aadhaar number", "uidai", "indian personal data", "unique identification", "government id", "identity card"]
    },
    {
        "id": "POL-002",
        "name": "Income Tax Permanent Account Number (PAN) Confidentiality",
        "pii_type": "PAN",
        "source_type": "legislation",
        "citation": "Income Tax Act, 1961 (Act 43 of 1961), Sec 139A & Sec 138; Income Tax Rules, 1962",
        "version": "Income Tax Act 1961 (as amended 2024)",
        "framework_version": "Income Tax Act 1961 (as amended 2024)",
        "regulation": "Income Tax Act 1961 (Sec 139A), Income Tax Rules 1962",
        "jurisdiction": "India (CBDT / Ministry of Finance)",
        "publication_date": "1961-09-13",
        "effective_date": "1962-04-01",
        "status": "enacted",
        "applicability": "Applies to tax assessees, reporting entities, and financial institutions handling Permanent Account Numbers in India.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "source_url": "https://incometaxindia.gov.in/Pages/acts/income-tax-act.aspx",
        "description": "Permanent Account Number is a 10-character alphanumeric tax identifier under Section 139A of the Income Tax Act 1961. Assessee information is protected under confidentiality principles (Section 138). PrivLock recommends full redaction in shared documents to mitigate tax impersonation and fraudulent filing.",
        "policy_text": "Permanent Account Number is a 10-character alphanumeric tax identifier issued under Section 139A of the Income Tax Act 1961. Critical financial identity. PrivLock recommends full redaction in general documents to prevent tax identity theft.",
        "topics": ["pan", "permanent account number", "tax identifier", "financial information", "government id", "indian personal data"]
    },
    {
        "id": "POL-003",
        "name": "DPDP Telecommunications Identifier Protection",
        "pii_type": "PHONE",
        "source_type": "regulation",
        "citation": "Digital Personal Data Protection Rules, 2025 (Rule 6, Rule 11); DPDP Act, 2023 (Act 22 of 2023), Sec 8(5)",
        "version": "DPDP Rules 2025 (Notified Nov 2025 by MeitY)",
        "framework_version": "DPDP Rules 2025 (Notified 14 Nov 2025)",
        "regulation": "Digital Personal Data Protection (DPDP) Rules, 2025 (Rule 6), DPDP Act 2023 (Sec 8(5))",
        "jurisdiction": "India (MeitY)",
        "publication_date": "2025-11-14",
        "effective_date": "2025-11-14",
        "status": "notified_rules",
        "applicability": "Applies to Data Fiduciaries and Data Processors processing digital telecommunications contact numbers within India or for offering goods/services to Indian Data Principals.",
        "action": "PARTIAL_MASK",
        "mask_format": "XXXXXX{last4}",
        "severity": "HIGH",
        "source_url": "https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa",
        "description": "Telephone and mobile contact numbers constitute personal data under the DPDP Act 2023. Under Rule 6 of the final DPDP Rules 2025, Data Fiduciaries must implement reasonable security safeguards. PrivLock recommends partial masking (retaining only the last 4 digits) for verification workflows.",
        "policy_text": "Mobile and telephone contact numbers are personal identifiers under the DPDP Act 2023 and DPDP Rules 2025. PrivLock recommends partial masking displaying only the last 4 digits for verification workflows.",
        "topics": ["phone", "phone number", "mobile number", "contact details", "personal data", "indian personal data"]
    },
    {
        "id": "POL-004",
        "name": "Electronic Communications Identity Safeguards",
        "pii_type": "EMAIL",
        "source_type": "regulation",
        "citation": "Digital Personal Data Protection Rules, 2025 (Rule 6); Information Technology (SPDI) Rules, 2011; DPDP Act 2023, Sec 8(5)",
        "version": "DPDP Rules 2025 / IT SPDI Rules 2011",
        "framework_version": "DPDP Rules 2025",
        "regulation": "DPDP Rules 2025 (Rule 6), DPDP Act 2023 (Sec 8(5)), IT Act 2000 (Sec 43A)",
        "jurisdiction": "India (MeitY)",
        "publication_date": "2025-11-14",
        "effective_date": "2025-11-14",
        "status": "notified_rules",
        "applicability": "Applies to electronic mail addresses processed digitally by Data Fiduciaries and commercial entities.",
        "action": "PARTIAL_MASK",
        "mask_format": "{u}***@{domain}",
        "severity": "HIGH",
        "source_url": "https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa",
        "description": "Email addresses identify electronic communications endpoints. Under the DPDP framework and reasonable security safeguards, PrivLock recommends partial masking of the username while preserving the domain for contextual authenticity.",
        "policy_text": "Personal and enterprise email addresses reveal electronic communications identity. PrivLock recommends partial masking of the username while preserving the domain for contextual authenticity.",
        "topics": ["email", "email address", "electronic communication", "personal data", "online identifier"]
    },
    {
        "id": "POL-005",
        "name": "Data Principal & Data Subject Identity Protection",
        "pii_type": "PERSON_NAME",
        "source_type": "legislation",
        "citation": "Digital Personal Data Protection Act, 2023 (Act 22 of 2023), Sec 4, 8; Regulation (EU) 2016/679 (GDPR), Art 4(1), 5(1)(c)",
        "version": "Act 22 of 2023 / Regulation (EU) 2016/679",
        "framework_version": "Act 22 of 2023 / Regulation 2016/679",
        "regulation": "DPDP Act 2023 (Sec 4, 8), GDPR (EU) 2016/679 (Art 4(1), 5)",
        "jurisdiction": "India (MeitY) & European Union",
        "publication_date": "2023-08-11",
        "effective_date": "2023-08-11",
        "status": "enacted",
        "applicability": "Applies to natural persons (Data Principals under DPDP Act; Data Subjects under GDPR) whose identifiable names appear in documents.",
        "action": "PARTIAL_MASK",
        "mask_format": "{first_char}***",
        "severity": "MEDIUM",
        "source_url": "https://www.meity.gov.in/content/digital-personal-data-protection-act-2023",
        "description": "Individual names directly identify the data principal or data subject. Both the DPDP Act 2023 and GDPR mandate data minimization. PrivLock recommends partial masking of given names or surnames to preserve document flow while shielding personal identity.",
        "policy_text": "Individual names identify the data principal. Mask surname or middle name to preserve document context while safeguarding identity.",
        "topics": ["person name", "full name", "data principal", "data subject", "personal data", "identity"]
    },
    {
        "id": "POL-006",
        "name": "Geographic Location & Tracking Safeguards",
        "pii_type": "LOCATION",
        "source_type": "legislation",
        "citation": "Digital Personal Data Protection Act, 2023 (Act 22 of 2023), Sec 8; Regulation (EU) 2016/679 (GDPR), Art 5(1)(c), 32",
        "version": "Act 22 of 2023 / Regulation (EU) 2016/679",
        "framework_version": "Act 22 of 2023",
        "regulation": "DPDP Act 2023 (Sec 8), GDPR (Art 5, 32)",
        "jurisdiction": "India (MeitY) & European Union",
        "publication_date": "2023-08-11",
        "effective_date": "2023-08-11",
        "status": "enacted",
        "applicability": "Applies to geographic locations, localities, and tracking metadata identifying private residences or restricted movement.",
        "action": "FULL_REDACT",
        "severity": "MEDIUM",
        "source_url": "https://www.meity.gov.in/content/digital-personal-data-protection-act-2023",
        "description": "Specific geographic localities, districts, and coordinates can enable physical tracking when paired with other identifiers. PrivLock recommends full redaction under statutory data minimization principles.",
        "policy_text": "Specific geographic localities, districts, and regions can enable physical tracking when paired with other identifiers. PrivLock recommends redacting residential locations.",
        "topics": ["location", "geographical data", "district", "locality", "tracking"]
    },
    {
        "id": "POL-007",
        "name": "Motor Vehicles Driving Licence Identity Protection",
        "pii_type": "DRIVING_LICENSE",
        "source_type": "legislation",
        "citation": "Motor Vehicles Act, 1988 (Act 59 of 1988), Sec 8, 9, 10; Central Motor Vehicles Rules, 1989, Rule 16; DPDP Act 2023, Sec 8(5)",
        "version": "Act 59 of 1988 (as amended by Act 32 of 2019)",
        "framework_version": "Motor Vehicles Amendment Act 2019",
        "regulation": "Motor Vehicles Act 1988 (Sec 9), DPDP Act 2023 (Sec 8)",
        "jurisdiction": "India (MoRTH / State Transport Authorities)",
        "publication_date": "2019-08-09",
        "effective_date": "2019-09-01",
        "status": "enacted",
        "applicability": "Applies to driving licence credentials issued by Indian Regional Transport Offices (RTOs) recorded in the national SARATHI database.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "source_url": "https://morth.nic.in/motor-vehicles-act-1988",
        "description": "Driving licences are official state-issued identity documents under the Motor Vehicles Act 1988. Under Section 8(5) of the DPDP Act 2023, Data Fiduciaries must secure government identifiers. PrivLock recommends full redaction to prevent counterfeit licensing and impersonation.",
        "policy_text": "Government driving licence number issued by state RTOs under the Motor Vehicles Act 1988 is official identity proof. PrivLock recommends full redaction to prevent counterfeit licensing and impersonation.",
        "topics": ["driving license", "driving licence", "driver license", "rto", "government id", "transport identity"]
    },
    {
        "id": "POL-008",
        "name": "Electoral Photo Identity Card (EPIC) Safeguards",
        "pii_type": "VOTER_ID",
        "source_type": "legislation",
        "citation": "Representation of the People Act, 1951 (Act 43 of 1951), Sec 61; Registration of Electors Rules, 1960, Rule 28; DPDP Act 2023, Sec 8",
        "version": "Act 43 of 1951 / Registration of Electors Rules 1960",
        "framework_version": "Act 43 of 1951",
        "regulation": "Representation of the People Act 1951 (Sec 61), DPDP Act 2023",
        "jurisdiction": "India (Election Commission of India / ECI)",
        "publication_date": "1951-07-17",
        "effective_date": "1951-07-17",
        "status": "enacted",
        "applicability": "Applies to Electoral Photo Identity Card (EPIC) voter numbers issued to registered Indian electors.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "source_url": "https://eci.gov.in/",
        "description": "Electoral Photo Identity Card (EPIC) voter identification numbers are issued by the Election Commission of India under Rule 28 of the Registration of Electors Rules 1960. Voter identification records linked with public registers create profiling and privacy risks. PrivLock recommends full redaction.",
        "policy_text": "Electoral Photo Identity Card (EPIC) voter ID number issued by Election Commission. High sensitivity voter identification. PrivLock recommends full redaction to protect voter identity.",
        "topics": ["voter id", "epic", "voter_id_epic", "election card", "electoral photo identity", "government id"]
    },
    {
        "id": "POL-009",
        "name": "Date of Birth & Age Verification Protection",
        "pii_type": "DOB",
        "source_type": "legislation",
        "citation": "Digital Personal Data Protection Act, 2023 (Act 22 of 2023), Sec 8, 9; DPDP Rules 2025, Rule 6, 10; GDPR Art 8",
        "version": "DPDP Act 2023 / DPDP Rules 2025",
        "framework_version": "DPDP Rules 2025",
        "regulation": "DPDP Act 2023 (Sec 8, 9 - Children Data), DPDP Rules 2025 (Rule 6)",
        "jurisdiction": "India (MeitY) & European Union",
        "publication_date": "2025-11-14",
        "effective_date": "2025-11-14",
        "status": "enacted",
        "applicability": "Applies to birth dates of natural persons, with statutory duties when processing children's personal data under Section 9.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa",
        "description": "Date of birth serves as an authentication factor across banking, tax, and KYC verification. Section 9 of the DPDP Act 2023 imposes heightened duties regarding children's data. PrivLock recommends full redaction or masking to prevent age-related exploitation and credential reconstruction.",
        "policy_text": "Date of birth is an authentication factor in banking and KYC verification. PrivLock recommends full redaction or masking of day/month to prevent age-related vulnerability and protect children's data.",
        "topics": ["dob", "date of birth", "birth date", "age verification", "kyc verification", "authentication factor"]
    },
    {
        "id": "POL-010",
        "name": "Postal Index Demographic Policy Mapping",
        "pii_type": "PINCODE",
        "source_type": "policy_mapping",
        "citation": "Department of Posts PIN Code System Guidelines (1972); General Demographic Privacy Principles",
        "version": "India Post Postal Index Number System (1972)",
        "framework_version": "Postal Guidelines",
        "regulation": "General Privacy Practice - Semi-Public Postal Demographics",
        "jurisdiction": "India (Department of Posts)",
        "publication_date": "1972-08-15",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to 6-digit postal index numbers used for geographical mail sorting across India.",
        "action": "KEEP",
        "severity": "LOW",
        "source_url": "https://www.indiapost.gov.in/",
        "derived_from": ["Department of Posts PIN System (1972)", "Standard Geographic Privacy Practices"],
        "description": "Postal Index Numbers represent postal distribution zones. On their own, they are semi-public demographic routing indicators and do not identify an individual. PrivLock recommends keeping PIN codes for geographic context unless directly coupled with a private street address.",
        "policy_text": "Postal Index Numbers indicate general postal zones. PIN codes are semi-public and may be kept for regional demographics unless bound to street addresses.",
        "topics": ["pincode", "postal code", "zip code", "area code"]
    },
    {
        "id": "POL-011",
        "name": "Public Corporate Entity Governance Mapping",
        "pii_type": "ORGANIZATION",
        "source_type": "policy_mapping",
        "citation": "Companies Act, 2013 (Act 18 of 2013), Sec 399; General Commercial Disclosure Practices",
        "version": "Public Corporate Registry Guidelines",
        "framework_version": "Enterprise Governance",
        "regulation": "General Privacy Practice - Public Legal Entity Data",
        "jurisdiction": "Global / India (MCA)",
        "publication_date": "2013-08-29",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to incorporated companies, statutory corporations, universities, and commercial entities.",
        "action": "KEEP",
        "severity": "LOW",
        "source_url": "https://www.mca.gov.in/",
        "derived_from": ["Companies Act 2013 Public Registry Principles", "General Commercial Governance Standards"],
        "description": "Institutional and registered corporate names are public legal entity records under Section 399 of the Companies Act 2013. Unless explicitly designated confidential in non-disclosure agreements, organizational names do not constitute personal data of a natural person. PrivLock retains organizational names by default.",
        "policy_text": "Institutional names (employers, banks, universities) are generally public entities. Keep unless explicitly marked confidential.",
        "topics": ["organization", "company name", "institution", "employer", "university", "bank name"]
    },
    {
        "id": "POL-012",
        "name": "Residential Physical Address Protection",
        "pii_type": "ADDRESS",
        "source_type": "legislation",
        "citation": "Digital Personal Data Protection Act, 2023 (Act 22 of 2023), Sec 8; Regulation (EU) 2016/679 (GDPR), Art 5(1)(c)",
        "version": "Act 22 of 2023 / Regulation (EU) 2016/679",
        "framework_version": "Act 22 of 2023 / Regulation 2016/679",
        "regulation": "DPDP Act 2023 (Sec 8), GDPR (Art 5(1)(c)) - Data Minimization",
        "jurisdiction": "India (MeitY) & European Union",
        "publication_date": "2023-08-11",
        "effective_date": "2023-08-11",
        "status": "enacted",
        "applicability": "Applies to physical residential addresses, house numbers, and street-level location data of natural persons.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://www.meity.gov.in/content/digital-personal-data-protection-act-2023",
        "description": "Detailed residential or private address data poses physical security and stalking hazards. Under the statutory data minimization mandates of the DPDP Act 2023 and GDPR Article 5(1)(c), PrivLock recommends full redaction of granular residential address details.",
        "policy_text": "Detailed residential or private address data poses severe physical privacy risks. PrivLock recommends full redaction under data minimization mandates.",
        "topics": ["address", "residential address", "home address", "street address", "physical location", "personal data"]
    },
    {
        "id": "POL-013",
        "name": "Sovereign Travel Credential & Passport Protection",
        "pii_type": "PASSPORT",
        "source_type": "legislation",
        "citation": "Passports Act, 1967 (Act 15 of 1967), Sec 3, 12; ICAO Doc 9303 (MRTD Standard); DPDP Act 2023, Sec 8",
        "version": "Act 15 of 1967 (as amended) / ICAO Doc 9303 8th Edition",
        "framework_version": "Passports Act 1967 (Amended 2002)",
        "regulation": "Passports Act 1967 (Sec 3, 12), DPDP Act 2023 (Sec 8)",
        "jurisdiction": "India (MEA) & International (ICAO)",
        "publication_date": "1967-06-24",
        "effective_date": "1967-06-24",
        "status": "enacted",
        "applicability": "Applies to sovereign passport booklets, emergency certificates, and machine-readable travel documents.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "source_url": "https://www.passportindia.gov.in/",
        "description": "Passport numbers are sovereign identity credentials governed by the Passports Act 1967 and formatted under international ICAO Doc 9303 specifications. Unauthorized exposure presents risks of transnational identity theft and fraudulent documentation. PrivLock recommends full redaction.",
        "policy_text": "International travel passport number issued under the Passports Act 1967 and ICAO Doc 9303. Sovereign identity credential. PrivLock recommends full redaction to prevent passport fraud.",
        "topics": ["passport", "passport number", "international travel", "sovereign id", "government id"]
    },
    {
        "id": "POL-014",
        "name": "Payment Card Industry Data Security Standard (PCI DSS)",
        "pii_type": "CREDIT_CARD",
        "source_type": "standard",
        "citation": "PCI DSS v4.0.1 (Requirements 3.4, 3.5); RBI Master Direction on Digital Payment Security Controls (RBI/2020-21/74)",
        "version": "PCI DSS v4.0.1 (Published June 2024 by PCI SSC)",
        "framework_version": "PCI DSS v4.0.1 (Published June 2024)",
        "regulation": "PCI-DSS v4.0.1 (Req 3.4, 3.5), RBI Master Direction on Digital Payment Security Controls",
        "jurisdiction": "Global (PCI SSC) / India (RBI for Regulated Entities)",
        "publication_date": "2024-06-11",
        "effective_date": None,
        "status": "published_standard",
        "applicability": "Applies to entities that store, process, or transmit cardholder data (CHD) and/or sensitive authentication data (SAD). The RBI Master Direction applies specifically to RBI-regulated banking and card-issuing entities.",
        "action": "PARTIAL_MASK",
        "mask_format": "XXXX-XXXX-XXXX-{last4}",
        "severity": "CRITICAL",
        "source_url": "https://www.pcisecuritystandards.org/document_library/",
        "description": "PCI DSS v4.0.1 is an industry security standard issued by the PCI Security Standards Council. Requirement 3.4 specifies rendering PAN unreadable wherever stored (maximum first 6 and last 4 digits exposed). Requirement 3.5 prohibits storing Sensitive Authentication Data (CVV/PIN) after authorization. For RBI-regulated entities, RBI Digital Payment Directions apply. PrivLock recommends partial masking of PAN and full suppression of CVV.",
        "policy_text": "Payment card numbers (PAN/CVV) subject to PCI DSS v4.0.1 security standards. Primary Account Number must have middle digits masked (maximum first 6 and last 4 exposed). Sensitive Authentication Data (CVV/PIN) must never be stored. PrivLock recommends partial masking.",
        "topics": ["credit card", "debit card", "payment card", "pan cardholder data", "financial information", "primary account number", "pci dss"]
    },
    {
        "id": "POL-015",
        "name": "Bank Routing Code Metadata Policy Mapping",
        "pii_type": "IFSC",
        "source_type": "policy_mapping",
        "citation": "RBI Payment and Settlement Systems Guidelines; RTGS/NEFT Procedural Codes",
        "version": "RBI Electronic Payment Routing Standards",
        "framework_version": "RBI Payment Systems",
        "regulation": "RBI Banking Regulations & Master Directions",
        "jurisdiction": "India (RBI)",
        "publication_date": "2020-08-06",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to 11-character Indian Financial System Codes designating bank branches in electronic clearing systems.",
        "action": "KEEP",
        "severity": "LOW",
        "source_url": "https://www.rbi.org.in/",
        "derived_from": ["RBI NEFT/RTGS Procedural Guidelines", "RBI Public Bank Branch Directory"],
        "description": "Indian Financial System Code (IFSC) is a public 11-digit alphanumeric bank branch routing identifier maintained in public RBI directories. It does not identify a personal bank account or account holder on its own. PrivLock retains IFSC codes for transaction routing context.",
        "policy_text": "Indian Financial System Code identifying bank branch. Public bank routing metadata. May be kept for routing context.",
        "topics": ["ifsc", "ifsc code", "bank branch", "routing code", "financial routing"]
    },
    {
        "id": "POL-016",
        "name": "Data Minimization & Purpose Limitation Principles",
        "pii_type": "DATA_MINIMIZATION",
        "source_type": "legislation",
        "citation": "Digital Personal Data Protection Act, 2023 (Act 22 of 2023), Sec 6(1); Regulation (EU) 2016/679 (GDPR), Art 5(1)(c)",
        "version": "Act 22 of 2023 / Regulation (EU) 2016/679",
        "framework_version": "Act 22 of 2023 / Regulation 2016/679",
        "regulation": "DPDP Act 2023 (Sec 6(1)), GDPR (EU) 2016/679 (Art 5(1)(c))",
        "jurisdiction": "India (MeitY) & European Union",
        "publication_date": "2023-08-11",
        "effective_date": "2023-08-11",
        "status": "enacted",
        "applicability": "Applies to Data Fiduciaries and Controllers collecting or processing personal data in all digital workflows.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://eur-lex.europa.eu/eli/reg/2016/679/oj",
        "description": "Under Section 6(1) of the DPDP Act 2023 and GDPR Article 5(1)(c), personal data collected and processed must be adequate, relevant, and limited to what is strictly necessary in relation to the specified lawful purpose. PrivLock recommends full redaction or exclusion of extraneous personal data.",
        "policy_text": "Data Minimization and Storage Limitation Principle: Data Fiduciaries must only collect and retain personal data strictly necessary for the specified lawful purpose. Extraneous or non-essential sensitive personal data must be redacted or removed from workflows.",
        "topics": ["data minimization", "purpose limitation", "excessive personal data", "storage limitation", "extraneous data"]
    },
    {
        "id": "POL-017",
        "name": "Data Retention & Statutory Erasure Mandate",
        "pii_type": "DATA_RETENTION",
        "source_type": "regulation",
        "citation": "Digital Personal Data Protection Rules, 2025 (Rule 7); DPDP Act, 2023, Sec 8(7); Regulation (EU) 2016/679 (GDPR), Art 5(1)(e), 17",
        "version": "DPDP Rules 2025 / Regulation (EU) 2016/679",
        "framework_version": "DPDP Rules 2025",
        "regulation": "DPDP Rules 2025 (Rule 7), DPDP Act 2023 (Sec 8(7)), GDPR (Art 5(1)(e))",
        "jurisdiction": "India (MeitY) & European Union",
        "publication_date": "2025-11-14",
        "effective_date": "2025-11-14",
        "status": "notified_rules",
        "applicability": "Applies to Data Fiduciaries retaining personal data once the specified purpose has been served and retention is no longer necessary for statutory compliance.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa",
        "description": "Under DPDP Act Section 8(7) and DPDP Rules 2025 Rule 7, Data Fiduciaries must erase personal data upon withdrawal of consent or as soon as the specified purpose is fulfilled. PrivLock recommends automated redaction and artifact expiry to support compliance.",
        "policy_text": "Data Retention and Erasure Mandate: Personal data must not be retained beyond the period necessary for the specified purpose for which it was processed, unless retention is required by statute. Data Fiduciaries must erase personal data upon purpose fulfillment.",
        "topics": ["data retention", "data erasure", "retention period", "storage limitation", "erasure mandate", "retention schedule"]
    },
    {
        "id": "POL-018",
        "name": "Personal Data Breach Prevention & Incident Notification",
        "pii_type": "DATA_BREACH",
        "source_type": "regulation",
        "citation": "Digital Personal Data Protection Rules, 2025 (Rule 8); DPDP Act, 2023, Sec 8(6); Regulation (EU) 2016/679 (GDPR), Art 33, 34",
        "version": "DPDP Rules 2025 / Regulation (EU) 2016/679",
        "framework_version": "DPDP Rules 2025",
        "regulation": "DPDP Rules 2025 (Rule 8), DPDP Act 2023 (Sec 8(6)), GDPR (Art 33, 34)",
        "jurisdiction": "India (MeitY / DPBI) & European Union",
        "publication_date": "2025-11-14",
        "effective_date": "2025-11-14",
        "status": "notified_rules",
        "applicability": "Applies to Data Fiduciaries in the event of any personal data breach or security compromise.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "source_url": "https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa",
        "description": "Under DPDP Act Section 8(6) and DPDP Rules 2025 Rule 8, Data Fiduciaries must promptly notify the Data Protection Board of India (DPBI) and affected Data Principals in the event of a breach. PrivLock enforces preventative technical redaction to prevent accidental data leaks.",
        "policy_text": "Data Breach Prevention and Notification Controls: Mandatory reasonable security safeguards to prevent personal data breaches and statutory obligation to notify the Data Protection Board of India (DPBI) and affected Data Principals promptly following any security incident.",
        "topics": ["data breach", "security incident", "breach notification", "dpbi notice", "security compromise", "data leak"]
    },
    {
        "id": "POL-019",
        "name": "Reasonable Security Safeguards & Technical Measures",
        "pii_type": "SECURITY_SAFEGUARDS",
        "source_type": "regulation",
        "citation": "Digital Personal Data Protection Rules, 2025 (Rule 6); DPDP Act, 2023, Sec 8(5); IT Act 2000, Sec 43A",
        "version": "DPDP Rules 2025 / DPDP Act 2023",
        "framework_version": "DPDP Rules 2025 / ISO/IEC 27001:2022",
        "regulation": "DPDP Rules 2025 (Rule 6), DPDP Act 2023 (Sec 8(5)), ISO/IEC 27001:2022 (Control A.8.11), NIST SP 800-122",
        "jurisdiction": "India (MeitY)",
        "publication_date": "2025-11-14",
        "effective_date": "2025-11-14",
        "status": "notified_rules",
        "applicability": "Applies to all Data Fiduciaries holding or processing digital personal data.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa",
        "description": "Under Section 8(5) of the DPDP Act 2023 and Rule 6 of the DPDP Rules 2025, Data Fiduciaries must implement reasonable technical and organizational safeguards. PrivLock implements redaction, tokenization, and ephemeral processing as recommended technical measures.",
        "policy_text": "Reasonable Security Safeguards and De-identification: Technical and organizational measures including encryption, pseudonymisation, access control, and visual redaction must be implemented to protect personal data in possession or control against unauthorized access or disclosure.",
        "topics": ["security safeguards", "technical measures", "access control", "encryption", "pseudonymisation", "de-identification", "data protection"]
    },
    {
        "id": "POL-020",
        "name": "Notice, Consent, and Data Principal Rights",
        "pii_type": "CONSENT",
        "source_type": "legislation",
        "citation": "Digital Personal Data Protection Act, 2023 (Act 22 of 2023), Sec 5, 6; DPDP Rules 2025, Rule 3; Regulation (EU) 2016/679 (GDPR), Art 7",
        "version": "Act 22 of 2023 / DPDP Rules 2025 / Regulation (EU) 2016/679",
        "framework_version": "DPDP Act 2023 / DPDP Rules 2025",
        "regulation": "DPDP Act 2023 (Sec 5, 6), DPDP Rules 2025 (Rule 3), GDPR (Art 7)",
        "jurisdiction": "India (MeitY) & European Union",
        "publication_date": "2023-08-11",
        "effective_date": "2023-08-11",
        "status": "enacted",
        "applicability": "Applies to notices and consent declarations collected by Data Fiduciaries.",
        "action": "KEEP",
        "severity": "MEDIUM",
        "source_url": "https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa",
        "description": "Notice and consent records demonstrate lawful processing basis under DPDP Section 6 and GDPR Article 7. Consent declarations are retained in documents to preserve accountability and proof of lawful basis.",
        "policy_text": "Notice, Consent, and Data Principal Rights: Processing must be grounded in unconditional, informed, and specific consent accompanied by clear notice detailing purpose, data elements, and grievance redressal channels.",
        "topics": ["consent", "notice", "data principal rights", "withdrawal of consent", "lawful basis"]
    },
    {
        "id": "POL-021",
        "name": "Biometric & Special Category Data Safeguards",
        "pii_type": "BIOMETRIC",
        "source_type": "legislation",
        "citation": "Aadhaar Act, 2016 (Act 18 of 2016), Sec 29(1); Regulation (EU) 2016/679 (GDPR), Art 9; DPDP Act 2023, Sec 8(5), 9",
        "version": "Aadhaar Act 2016 / Regulation (EU) 2016/679",
        "framework_version": "Aadhaar Act 2016 / GDPR 2016/679",
        "regulation": "Aadhaar Act 2016 (Sec 29), DPDP Act 2023 (Sec 9), GDPR (Art 9)",
        "jurisdiction": "India (UIDAI/MeitY) & European Union",
        "publication_date": "2016-03-26",
        "effective_date": "2016-03-26",
        "status": "enacted",
        "applicability": "Applies to core biometric data (fingerprints, iris scans, facial recognition vectors) and special category biometric processing.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "source_url": "https://uidai.gov.in/en/legal-framework.html",
        "description": "Core biometric data receives the highest level of statutory protection. Section 29(1) of the Aadhaar Act strictly prohibits sharing core biometric information. GDPR Article 9 prohibits processing biometric data for uniquely identifying natural persons without explicit exemption. PrivLock strictly recommends full redaction.",
        "policy_text": "Biometric and Special Category Information: Core biometric data (fingerprints, iris, facial features) constitutes special category personal data. Strict prohibition on unauthorized disclosure, display, or retention without explicit statutory authorization.",
        "topics": ["biometric", "fingerprint", "iris", "facial recognition", "special category data", "sensitive personal data"]
    },
    {
        "id": "iso_27001_masking",
        "name": "ISO/IEC 27001:2022 Control A.8.11 Data Masking",
        "pii_type": "ISO_27001_MASKING",
        "source_type": "standard",
        "citation": "ISO/IEC 27001:2022, Information security, cybersecurity and privacy protection — Information security management systems, Control A.8.11",
        "version": "ISO/IEC 27001:2022 (Published Oct 2022)",
        "framework_version": "ISO/IEC 27001:2022",
        "regulation": "ISO/IEC 27001:2022 (Control A.8.11 Data Masking)",
        "jurisdiction": "International (ISO/IEC)",
        "publication_date": "2022-10-25",
        "effective_date": None,
        "status": "published_standard",
        "applicability": "Applies to organizations implementing an Information Security Management System (ISMS) across IT and business processes.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://www.iso.org/standard/27001",
        "description": "Control A.8.11 of ISO/IEC 27001:2022 specifies that data masking should be applied in accordance with the organization's topic-specific policy on access control and applicable requirements. This is an international security standard rather than a statutory enactment. PrivLock implements redaction and masking in alignment with Control A.8.11 guidance.",
        "policy_text": "ISO/IEC 27001:2022 Control A.8.11 Data Masking standard recommends applying data masking, pseudonymization, and obfuscation to limit exposure of sensitive data in systems and documents in alignment with access control policies.",
        "topics": ["iso 27001", "iso/iec 27001", "data masking", "control a.8.11", "information security standard", "security management"]
    },
    {
        "id": "nist_sp_800_122",
        "name": "NIST SP 800-122 PII Confidentiality Guidance",
        "pii_type": "NIST_SP_800_122",
        "source_type": "official_guidance",
        "citation": "NIST Special Publication 800-122, Guide to Protecting the Confidentiality of Personally Identifiable Information (PII) (2010)",
        "version": "NIST SP 800-122 (Published April 2010)",
        "framework_version": "NIST SP 800-122",
        "regulation": "NIST SP 800-122 (Guide to Protecting PII Confidentiality)",
        "jurisdiction": "United States / International Reference (NIST)",
        "publication_date": "2010-04-06",
        "effective_date": None,
        "status": "official_guidance",
        "applicability": "Federal agencies and organizations managing systems that process personally identifiable information (PII).",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://csrc.nist.gov/publications/detail/sp/800-122/final",
        "description": "NIST SP 800-122 is an official technical guidance publication from the U.S. National Institute of Standards and Technology. It outlines risk-based safeguards and de-identification techniques including redaction, masking, and suppression for protecting PII. It is technical guidance rather than a statute.",
        "policy_text": "NIST Special Publication 800-122 provides official technical guidance for protecting PII confidentiality, recommending de-identification, redaction, and access controls based on the impact level of unauthorized disclosure.",
        "topics": ["nist", "nist sp 800-122", "pii confidentiality", "official guidance", "de-identification", "redaction guidance"]
    },
    {
        "id": "medical_data_confidentiality",
        "name": "Medical & Health Record Protection Mapping",
        "pii_type": "MEDICAL_DATA",
        "source_type": "policy_mapping",
        "citation": "DPDP Act, 2023, Sec 8(5); DPDP Rules, 2025, Rule 6; Regulation (EU) 2016/679 (GDPR), Art 9(1)",
        "version": "DPDP Act 2023 / DPDP Rules 2025 / GDPR Art 9",
        "framework_version": "DPDP Act 2023 / GDPR Art 9",
        "regulation": "DPDP Act 2023 (Sec 8(5)), DPDP Rules 2025 (Rule 6), GDPR (Art 9)",
        "jurisdiction": "India & European Union / Applicable Jurisdictions",
        "publication_date": "2025-11-14",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to health, patient diagnostic records, clinical reports, and medical history documents.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "source_url": "https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa",
        "derived_from": [
            "DPDP Act 2023 (Sec 8(5))",
            "DPDP Rules 2025 (Rule 6)",
            "GDPR (EU) 2016/679 (Article 9 Special Category Data)",
            "National Health Data Management Policy principles"
        ],
        "description": "Medical and health records contain intimate personal data. NOTE: DISHA (Digital Information Security in Healthcare Act) was a 2018 draft bill and was never enacted into law. Authoritative legal protection is derived from DPDP Act 2023 Section 8(5) reasonable security safeguards, DPDP Rules 2025 Rule 6, and GDPR Article 9 special category prohibitions. PrivLock recommends full redaction as an essential technical protection.",
        "policy_text": "Medical and health records contain highly sensitive personal data. Derived from DPDP Act 2023 reasonable safeguards and GDPR Article 9 special category provisions (DISHA was only a 2018 draft and was not enacted). PrivLock recommends full redaction.",
        "topics": ["medical data", "health records", "patient diagnosis", "clinical reports", "medical confidentiality", "special category data", "health document"]
    },
    {
        "id": "bank_stmt_redaction",
        "name": "Bank Statement & Account Redaction Mapping",
        "pii_type": "BANK_STATEMENT",
        "source_type": "policy_mapping",
        "citation": "RBI Master Direction - Know Your Customer (KYC) Direction, 2016 (Updated 2024); DPDP Act 2023, Sec 8(5)",
        "version": "RBI KYC Master Direction / DPDP Act 2023",
        "framework_version": "RBI Master Direction / DPDP 2023",
        "regulation": "RBI Master Direction on KYC (Updated 2024), DPDP Act 2023 (Sec 8(5))",
        "jurisdiction": "India (RBI / MeitY)",
        "publication_date": "2024-01-04",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to financial account statements, transaction histories, and bank account numbers processed in commercial workflows.",
        "action": "PARTIAL_MASK",
        "mask_format": "XXXXXX{last4}",
        "severity": "HIGH",
        "source_url": "https://www.rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=11566",
        "derived_from": [
            "RBI Master Direction - KYC Direction, 2016 (as amended)",
            "DPDP Act 2023 (Sec 8(5))",
            "Banking Codes and Standards Board of India (BCSBI) guidelines"
        ],
        "description": "Bank account numbers and transaction ledgers disclose sensitive financial history. RBI directions require regulated entities to maintain customer confidentiality and protect account data. PrivLock recommends partial masking (displaying only the last 4 digits) for verification workflows.",
        "policy_text": "Bank statement and account numbers disclose sensitive financial transaction records. Derived from RBI KYC Directions and DPDP Act 2023 safeguards. PrivLock recommends partial masking showing only the last 4 digits.",
        "topics": ["bank statement", "bank account", "account number", "financial record", "transaction history", "banking confidentiality"]
    },
    {
        "id": "salary_slip_confidentiality",
        "name": "Salary Slip & Compensation Confidentiality Mapping",
        "pii_type": "SALARY_SLIP",
        "source_type": "policy_mapping",
        "citation": "DPDP Act, 2023 (Act 22 of 2023), Sec 4, 8; Payment of Wages Act, 1936; Code on Wages, 2019",
        "version": "DPDP Act 2023 / Code on Wages 2019",
        "framework_version": "DPDP Act 2023 / Enterprise Privacy",
        "regulation": "DPDP Act 2023 (Sec 4, 8), Code on Wages 2019",
        "jurisdiction": "India / Enterprise Workplace",
        "publication_date": "2023-08-11",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to employee pay stubs, compensation breakdowns, deductions, and wage slips.",
        "action": "PARTIAL_MASK",
        "severity": "HIGH",
        "source_url": "https://www.meity.gov.in/content/digital-personal-data-protection-act-2023",
        "derived_from": [
            "DPDP Act 2023 (Sec 4, 8)",
            "Code on Wages 2019 (Sec 50)",
            "Standard Human Resource Confidentiality Agreements"
        ],
        "description": "Employee compensation and salary slips contain personal financial details, tax deductions, and bank links. They constitute digital personal data under the DPDP Act 2023. PrivLock recommends masking compensation amounts and personal tax deductions in shared workplace documents.",
        "policy_text": "Salary slips and employee compensation details disclose personal income and tax deductions. Derived from DPDP Act 2023 data principal rights. PrivLock recommends partial masking or redaction of remuneration figures.",
        "topics": ["salary slip", "pay slip", "compensation", "remuneration", "wage slip", "employee financial data"]
    },
    {
        "id": "tax_return_confidentiality",
        "name": "Tax Return & ITR Confidentiality Mapping",
        "pii_type": "TAX_RETURN",
        "source_type": "policy_mapping",
        "citation": "Income Tax Act, 1961 (Act 43 of 1961), Sec 138; DPDP Act 2023, Sec 8",
        "version": "Income Tax Act 1961 (Sec 138) / DPDP Act 2023",
        "framework_version": "Income Tax Act 1961 / DPDP 2023",
        "regulation": "Income Tax Act 1961 (Sec 138), DPDP Act 2023 (Sec 8)",
        "jurisdiction": "India (CBDT / MeitY)",
        "publication_date": "1961-09-13",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to Income Tax Return (ITR) acknowledgments, Form 16, Form 26AS, and taxable income disclosures.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://incometaxindia.gov.in/Pages/acts/income-tax-act.aspx",
        "derived_from": [
            "Income Tax Act 1961 Section 138 (Disclosure of information respecting assessees)",
            "DPDP Act 2023 Section 8(5)"
        ],
        "description": "Income tax returns and assessment filings contain exhaustive financial disclosures, assets, and liabilities. Section 138 of the Income Tax Act establishes confidentiality regarding assessee information. PrivLock recommends full redaction of taxable income figures and tax computations in non-statutory distributions.",
        "policy_text": "Tax return documents and ITR disclosures contain confidential assessee financial data. Derived from Section 138 of the Income Tax Act 1961 and DPDP Act 2023. PrivLock recommends full redaction.",
        "topics": ["tax return", "itr", "form 16", "form 26as", "tax computation", "income tax filing", "tax confidentiality"]
    },
    {
        "id": "contract_nda_confidentiality",
        "name": "Commercial Contract & NDA Confidentiality Mapping",
        "pii_type": "CONTRACT_NDA",
        "source_type": "policy_mapping",
        "citation": "Indian Contract Act, 1872 (Act 9 of 1872), Sec 27; Trade Secret Protection Principles; DPDP Act 2023",
        "version": "Contract Law & Commercial Trade Secret Best Practices",
        "framework_version": "Commercial Practice",
        "regulation": "Indian Contract Act 1872, Commercial NDA Best Practice",
        "jurisdiction": "India / Common Law",
        "publication_date": "1872-04-25",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to non-disclosure agreements, master service agreements, proprietary pricing schedules, and signatory personal details.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://www.indiacode.nic.in/handle/123456789/2187",
        "derived_from": [
            "Indian Contract Act 1872",
            "Commercial Non-Disclosure Precedents",
            "DPDP Act 2023 Data Minimization Principles"
        ],
        "description": "Contracts and Non-Disclosure Agreements (NDAs) govern proprietary business relationships and contain signatory personal details. PrivLock provides technical redaction mappings for proprietary terms, party residential details, and financial consideration values.",
        "policy_text": "Contracts and Non-Disclosure Agreements contain confidential proprietary terms and party personal identifiers. Derived from commercial confidentiality and contract law principles. PrivLock recommends full redaction of confidential clauses.",
        "topics": ["contract", "nda", "non disclosure agreement", "confidential agreement", "commercial contract", "trade secret"]
    },
    {
        "id": "general_pii_default",
        "name": "General PII Technical Redaction Baseline",
        "pii_type": "GENERAL_PII",
        "source_type": "policy_mapping",
        "citation": "DPDP Act 2023, Sec 8(5); GDPR Art 5(1)(c); ISO/IEC 27001:2022 Control A.8.11",
        "version": "PrivLock Baseline Policy Mapping",
        "framework_version": "PrivLock Technical Baseline",
        "regulation": "DPDP Act 2023 (Sec 8(5)), GDPR (Art 5), ISO/IEC 27001 (A.8.11)",
        "jurisdiction": "Global Baseline",
        "publication_date": "2025-11-14",
        "effective_date": None,
        "status": "policy_mapping",
        "applicability": "Applies to unclassified or unrecognized personal data elements detected in documents.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "source_url": "https://www.meity.gov.in/content/digital-personal-data-protection-act-2023",
        "derived_from": [
            "DPDP Act 2023 (Sec 8(5))",
            "GDPR (EU) 2016/679 (Article 5)",
            "ISO/IEC 27001:2022 Control A.8.11"
        ],
        "description": "PrivLock's conservative default technical baseline: when an unclassified data element represents sensitive personal information without a specialized policy mapping, full redaction is applied to prevent accidental disclosure.",
        "policy_text": "General PII Default Redaction: Uncategorized or unrecognized sensitive personal data defaults to full redaction under conservative security baseline principles.",
        "topics": ["general pii", "uncategorized personal data", "default redaction", "sensitive data", "privacy baseline"]
    }
]


def _tokenize(text):
    return [w.lower() for w in text.split() if len(w) > 2]


class RAGDecisionEngine:
    """
    RAG Policy Decision Engine with fast deterministic direct matching,
    lazy on-demand FAISS vector search, batch caching, and TF-IDF fallback.
    Maintains an Authoritative Privacy & Security Policy Corpus spanning
    Legislation, Regulations, Standards, Official Guidance, and Policy Mappings.
    """

    def __init__(self):
        self.policies = PRIVACY_POLICIES
        self.policy_by_type = {p['pii_type']: p for p in self.policies}
        self.policy_by_id = {p['id']: p for p in self.policies}
        self.embedding_model = None
        self.faiss_index = None
        self.use_rag = False
        self._rag_initialized = False
        self._rag_init_failed = False
        self._init_lock = threading.Lock()
        self._embedding_cache = {}
        self._tfidf_docs = []
        self._vocab = set()

        self._build_deterministic_index()

    def _build_deterministic_index(self):
        """Build lightweight deterministic policy index and TF-IDF fallback vocabulary immediately."""
        self._tfidf_docs = []
        self._vocab = set()
        for p in self.policies:
            topics_text = " ".join(p.get('topics', []))
            derived_text = " ".join(p.get('derived_from', []))
            tokens = _tokenize(
                f"{p['pii_type']} {p.get('name', '')} {p['policy_text']} "
                f"{p.get('regulation', '')} {p.get('citation', '')} {topics_text} {derived_text}"
            )
            self._tfidf_docs.append((p, Counter(tokens)))
            self._vocab.update(tokens)

    def _initialize(self):
        """Backward-compatibility hook: ensures deterministic policy index is built."""
        self._build_deterministic_index()

    def _ensure_semantic_engine(self):
        """
        Lazily initialize SentenceTransformer and FAISS vector index on demand.
        Thread-safe for multi-threaded Gunicorn workers (1 worker / 4 threads).
        """
        if self._rag_initialized or self._rag_init_failed:
            return self.use_rag

        with self._init_lock:
            if self._rag_initialized or self._rag_init_failed:
                return self.use_rag

            if not (EMBEDDINGS_AVAILABLE and FAISS_AVAILABLE):
                self.use_rag = False
                self._rag_init_failed = True
                return False

            global SentenceTransformer, faiss
            try:
                if SentenceTransformer is None:
                    from sentence_transformers import SentenceTransformer as _ST
                    SentenceTransformer = _ST
                if faiss is None:
                    import faiss as _faiss
                    faiss = _faiss

                logger.info("Initializing lazy SentenceTransformer and FAISS index for semantic retrieval...")
                self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
                texts = [
                    f"{p['pii_type']}: {p.get('name', '')} - {p['policy_text']} "
                    f"({p.get('citation', p.get('regulation', ''))}) {' '.join(p.get('topics', []))}"
                    for p in self.policies
                ]
                embeddings = self.embedding_model.encode(texts)
                dimension = embeddings.shape[1]

                self.faiss_index = faiss.IndexFlatL2(dimension)
                self.faiss_index.add(embeddings.astype('float32'))
                self.use_rag = True
                self._rag_initialized = True
                logger.info("RAG Engine online: %d policies indexed in FAISS", len(self.policies))
                return True
            except Exception as e:
                logger.warning("RAG FAISS lazy initialization failed (%s). Using semantic fallback.", e)
                self.use_rag = False
                self._rag_init_failed = True
                return False

    def _enrich_policy_output(self, policy, retrieval_mode, score, query):
        """Return standardized, structured policy retrieval decision with disclaimer."""
        p = policy
        pii_label = p.get('pii_type', str(query))
        action = p.get('action', 'FULL_REDACT')
        reason = (
            f"The identified entity corresponds to {pii_label}. "
            f"Policy source '{p.get('name', p.get('id'))}' ({p.get('source_type', 'policy')}) "
            f"supports {action.lower()} treatment for technical risk minimization."
        )

        return {
            **p,
            'detected_pii': pii_label,
            'policy_id': p.get('id', 'POL-DEFAULT'),
            'policy_name': p.get('name', 'Privacy Policy'),
            'source_type': p.get('source_type', 'policy_mapping'),
            'citation': p.get('citation', p.get('regulation', 'Standard Privacy Policy')),
            'regulation': p.get('regulation', 'Standard Privacy Policy'),
            'framework_version': p.get('framework_version', p.get('version', '')),
            'jurisdiction': p.get('jurisdiction', 'Global / India'),
            'status': p.get('status', 'policy_mapping'),
            'applicability': p.get('applicability', 'General document processing'),
            'action': action,
            'recommended_treatment': action,
            'severity': p.get('severity', 'HIGH'),
            'source_url': p.get('source_url', ''),
            'policy_text': p.get('policy_text', ''),
            'derived_from': p.get('derived_from', []),
            'reason': reason,
            'disclaimer': COMPLIANCE_DISCLAIMER,
            'retrieval_mode': retrieval_mode,
            'score': score
        }

    def search_policy(self, query, top_k=1):
        """
        Search policy corpus semantically or via deterministic fallback.
        Supports queries like 'Aadhaar number', 'Indian personal data',
        'credit card', 'data breach', 'PCI DSS', 'security safeguards',
        'medical records', 'bank statement', 'salary slip', etc.

        Returns:
            dict containing policy details and metadata.
        """
        if not query or not str(query).strip():
            return self._enrich_policy_output(self.policies[0], 'DEFAULT', 1.0, 'DEFAULT')

        raw_q = str(query).strip()
        norm_q = raw_q.upper()
        lower_q = raw_q.lower()

        # Direct exact match by pii_type or policy id
        if norm_q in self.policy_by_type:
            return self._enrich_policy_output(self.policy_by_type[norm_q], 'DIRECT_MATCH', 1.0, raw_q)
        if lower_q in self.policy_by_id:
            return self._enrich_policy_output(self.policy_by_id[lower_q], 'DIRECT_MATCH', 1.0, raw_q)
        if norm_q in self.policy_by_id:
            return self._enrich_policy_output(self.policy_by_id[norm_q], 'DIRECT_MATCH', 1.0, raw_q)

        rag_ready = self._ensure_semantic_engine()
        if rag_ready and self.embedding_model is not None and self.faiss_index is not None:
            try:
                if raw_q not in self._embedding_cache:
                    q_emb = self.embedding_model.encode([raw_q])
                    self._embedding_cache[raw_q] = q_emb
                else:
                    q_emb = self._embedding_cache[raw_q]
                distances, indices = self.faiss_index.search(q_emb.astype('float32'), top_k)
                best_idx = indices[0][0]
                p = self.policies[best_idx]
                return self._enrich_policy_output(p, 'RAG_FAISS', float(distances[0][0]), raw_q)
            except Exception:
                pass

        policy, score = self._retrieve_tfidf_fallback(raw_q)
        p = policy or self.policies[0]
        return self._enrich_policy_output(p, 'TFIDF_FALLBACK', score, raw_q)

    def _retrieve_tfidf_fallback(self, query):
        """Lightweight semantic similarity fallback using token vector cosine similarity."""
        q_tokens = Counter(_tokenize(query))
        best_policy = None
        best_score = -1.0

        for policy, doc_tokens in self._tfidf_docs:
            common = set(q_tokens.keys()) & set(doc_tokens.keys())
            if not common:
                continue
            dot = sum(q_tokens[t] * doc_tokens[t] for t in common)
            norm_q = math.sqrt(sum(v * v for v in q_tokens.values()))
            norm_d = math.sqrt(sum(v * v for v in doc_tokens.values()))
            score = dot / (norm_q * norm_d) if norm_q and norm_d else 0.0

            if score > best_score:
                best_score = score
                best_policy = policy

        return best_policy, round(best_score, 3)

    def get_decision(self, pii_detection):
        """
        Evaluate redaction decision for a single PII entity.

        Fast path: Check direct_policy by pii_type or ID.
        If found, return deterministic regulatory decision immediately.
        SentenceTransformer and FAISS are NOT loaded.

        Slow path: For unknown/unmapped PII types, lazily initialize
        SentenceTransformer/FAISS or fall back to TF-IDF semantic matching.

        Args:
            pii_detection: dict with keys {type, value, confidence, ...}

        Returns:
            dict of decision metadata {action, severity, regulation, policy_id, ...}
        """
        pii_type = pii_detection.get('type', 'UNKNOWN')
        pii_val = pii_detection.get('value', '')

        # Fast deterministic lookup if exact policy exists
        direct_policy = self.policy_by_type.get(pii_type) or self.policy_by_id.get(str(pii_type).lower())
        if direct_policy:
            action = direct_policy.get('action', 'FULL_REDACT')
            reason = (
                f"The identified value is a sensitive {pii_type} identifier. "
                f"Policy source '{direct_policy.get('name')}' ({direct_policy.get('source_type')}) "
                f"supports technical {action.lower()} treatment for minimization."
            )
            return {
                'action': action,
                'recommended_treatment': action,
                'severity': direct_policy.get('severity', 'HIGH'),
                'regulation': direct_policy.get('regulation', 'Standard Privacy Policy'),
                'citation': direct_policy.get('citation', direct_policy.get('regulation', '')),
                'policy_id': direct_policy.get('id', 'POL-DEFAULT'),
                'policy_name': direct_policy.get('name', 'Privacy Policy'),
                'source_type': direct_policy.get('source_type', 'policy_mapping'),
                'framework_version': direct_policy.get('framework_version', direct_policy.get('version', '')),
                'jurisdiction': direct_policy.get('jurisdiction', 'India / Global'),
                'status': direct_policy.get('status', 'enacted'),
                'applicability': direct_policy.get('applicability', ''),
                'source_url': direct_policy.get('source_url', ''),
                'policy_text': direct_policy.get('policy_text', ''),
                'mask_format': direct_policy.get('mask_format'),
                'derived_from': direct_policy.get('derived_from', []),
                'detected_pii': pii_type,
                'reason': reason,
                'disclaimer': COMPLIANCE_DISCLAIMER,
                'retrieval_distance': 0.0,
                'engine': 'RULE_POLICY'
            }

        # Unknown / unmapped PII type -> lazy semantic retrieval on demand
        rag_ready = self._ensure_semantic_engine()

        if rag_ready and self.embedding_model is not None and self.faiss_index is not None:
            query = f"Privacy policy and redaction rules for {pii_type} with value {pii_val}"
            try:
                if query not in self._embedding_cache:
                    q_emb = self.embedding_model.encode([query])
                    self._embedding_cache[query] = q_emb
                else:
                    q_emb = self._embedding_cache[query]

                distances, indices = self.faiss_index.search(q_emb.astype('float32'), 1)
                best_idx = indices[0][0]
                dist = float(distances[0][0])
                policy = self.policies[best_idx]
                engine_mode = 'RAG_FAISS'
            except Exception:
                retrieved, score = self._retrieve_tfidf_fallback(f"{pii_type} {pii_val}")
                policy = retrieved or self.policies[0]
                dist = 1.0 - score if score > 0 else 1.0
                engine_mode = 'FALLBACK_DIRECT'
        else:
            # Deterministic TF-IDF semantic fallback
            retrieved, score = self._retrieve_tfidf_fallback(f"{pii_type} {pii_val}")
            policy = retrieved or self.policy_by_id.get('general_pii_default') or self.policies[0]
            dist = 1.0 - score if score > 0 else 1.0
            engine_mode = 'SEMANTIC_FALLBACK'

        action = policy.get('action', 'FULL_REDACT')
        reason = (
            f"The identified value '{pii_val}' ({pii_type}) was evaluated via {engine_mode}. "
            f"Mapped to '{policy.get('name')}' ({policy.get('source_type')}) recommending {action.lower()} treatment."
        )

        return {
            'action': action,
            'recommended_treatment': action,
            'severity': policy.get('severity', 'HIGH'),
            'regulation': policy.get('regulation', 'Standard Privacy Policy'),
            'citation': policy.get('citation', policy.get('regulation', '')),
            'policy_id': policy.get('id', 'POL-DEFAULT'),
            'policy_name': policy.get('name', 'Privacy Policy'),
            'source_type': policy.get('source_type', 'policy_mapping'),
            'framework_version': policy.get('framework_version', policy.get('version', '')),
            'jurisdiction': policy.get('jurisdiction', 'India / Global'),
            'status': policy.get('status', 'policy_mapping'),
            'applicability': policy.get('applicability', ''),
            'source_url': policy.get('source_url', ''),
            'policy_text': policy.get('policy_text', ''),
            'mask_format': policy.get('mask_format'),
            'derived_from': policy.get('derived_from', []),
            'detected_pii': pii_type,
            'reason': reason,
            'disclaimer': COMPLIANCE_DISCLAIMER,
            'retrieval_distance': dist,
            'engine': engine_mode
        }

    def process_all_detections(self, detections):
        """Enrich a list of PII detections with regulatory decisions."""
        enriched = []
        for d in detections:
            decision = self.get_decision(d)
            enriched.append({
                **d,
                'decision': decision['action'],
                'severity': decision['severity'],
                'regulation': decision['regulation'],
                'policy_id': decision['policy_id'],
                'policy_name': decision.get('policy_name'),
                'source_type': decision.get('source_type'),
                'citation': decision.get('citation'),
                'disclaimer': decision.get('disclaimer'),
                'mask_format': decision['mask_format'],
                'decision_engine': decision['engine']
            })
        return enriched

    def get_engine_status(self):
        """Return engine operational status for API diagnostics."""
        is_semantic_loaded = self._rag_initialized and self.embedding_model is not None
        source_type_counts = dict(Counter(p.get('source_type', 'unknown') for p in self.policies))
        return {
            'status': 'initialized',
            'corpus_name': 'Authoritative Privacy & Security Policy Corpus',
            'rag_enabled': EMBEDDINGS_AVAILABLE and FAISS_AVAILABLE,
            'initialized': True,
            'embeddings_loaded': is_semantic_loaded,
            'total_policies': len(self.policies),
            'source_type_breakdown': source_type_counts,
            'embedding_model': 'all-MiniLM-L6-v2' if is_semantic_loaded else 'lazy_on_demand',
            'vector_db': 'FAISS' if is_semantic_loaded else 'Embedded-Policy-Index',
            'index_size': self.faiss_index.ntotal if self.faiss_index else len(self.policies),
            'disclaimer': COMPLIANCE_DISCLAIMER
        }


# Singleton instance with thread-safe lock
_engine = None
_engine_lock = threading.Lock()


def get_rag_status_lightweight():
    """Return lightweight RAG status without instantiating or initializing the engine."""
    global _engine
    if _engine is not None:
        return _engine.get_engine_status()
    source_type_counts = dict(Counter(p.get('source_type', 'unknown') for p in PRIVACY_POLICIES))
    return {
        'status': 'ready_lazy',
        'corpus_name': 'Authoritative Privacy & Security Policy Corpus',
        'rag_enabled': EMBEDDINGS_AVAILABLE and FAISS_AVAILABLE,
        'initialized': False,
        'total_policies': len(PRIVACY_POLICIES),
        'source_type_breakdown': source_type_counts,
        'disclaimer': COMPLIANCE_DISCLAIMER
    }


def get_rag_engine():
    """Retrieve or construct the global RAG decision engine singleton."""
    global _engine
    if _engine is None:
        with _engine_lock:
            if _engine is None:
                _engine = RAGDecisionEngine()
    return _engine


def decide_redaction(detections):
    """Convenience function: process detections through policy decision pipeline."""
    return get_rag_engine().process_all_detections(detections)


def search_policy(query, top_k=1):
    """Convenience function: search policy corpus semantically or via deterministic fallback."""
    return get_rag_engine().search_policy(query, top_k)
