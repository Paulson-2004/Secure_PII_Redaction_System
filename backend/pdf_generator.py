from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Preformatted
from reportlab.lib.styles import getSampleStyleSheet


def generate_redacted_pdf(text, output_path="redacted_output.pdf"):
    doc = SimpleDocTemplate(output_path, pagesize=letter)
    elements = []

    styles = getSampleStyleSheet()
    style = styles["Normal"]

    formatted_text = Preformatted(text, style)
    elements.append(formatted_text)

    doc.build(elements)

    return output_path
