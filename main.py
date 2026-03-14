from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import requests
import json
import os
import base64
from bs4 import BeautifulSoup
import re

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MERCURY_API_KEY = "sk_0f303a19575726c1579d899453ad8c37"
MERCURY_API_URL = "https://api.inceptionlabs.ai/v1/chat/completions"

# Google Gemini — used ONLY for OCR (extracting text from images).
# mercury-2 is text-only and cannot process images at all.
# Get a free key at https://aistudio.google.com/apikey
GEMINI_API_KEY = "AIzaSyC4RfVvZP0BDLOb_4OkNQwdphvQEkIFKZ0"
GEMINI_OCR_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

def extract_json_from_text(text: str) -> dict:
    if not text:
        raise ValueError("Received empty string from AI")
    try:
        return json.loads(text)
    except:
        pass
    
    # Try extracting markdown block
    match = re.search(r'```(?:json)?\s*(.*?)\s*```', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except:
            pass
            
    # Try extracting first matching { ... } block
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(0))
        except:
            pass
            
    raise ValueError(f"Could not parse valid JSON from: {text[:200]}")

class AnalyzeRequest(BaseModel):
    text: str

@app.post("/analyze")
async def analyze(request: AnalyzeRequest):
    text = request.text
    print(f"\n--- New Mercury 2 Analysis Request ---")
    print(f"Input Text: {text}")

    # Prompt engineering for the exact JSON format needed by the Flutter frontend
    system_prompt = """You are EchoGuard, an advanced, highly-accurate AI fact-checking engine. 
Analyze the user's claim. You are expected to provide the FINAL analysis. Do NOT output any intermediate search queries or tool calls.
You MUST output ONLY a single valid JSON object matching this exact structure:
{
  "credibility": <float between 0 and 100>,
  "fake_probability": <float between 0 and 100>,
  "manipulation": {
    "level": "<string: HIGH, MEDIUM, LOW>",
    "emotion": "<string: e.g., outrage, fear, neutral, excitement>",
    "intensity": <float between 0 and 100>,
    "keywords": ["<string>", "<string>"]
  },
  "bias": {
    "leaning": "<string: LEFT, RIGHT, NEUTRAL, BIAS-FREE>",
    "confidence": <float between 0 and 100>,
    "propaganda_flag": <boolean>
  },
  "source_reliability": {
    "level": "<string: HIGH, MEDIUM, LOW>",
    "score": <integer between 0 and 100>,
    "domain": "<string: primarily cross-referenced domain, e.g., reuters.com>"
  },
  "clickbait": {
    "is_clickbait": <boolean>,
    "probability": <float between 0 and 100>
  },
  "balanced_views": [
    "<string: Title of article - domain.com>",
    "<string: Title of article - domain.com>"
  ],
  "ai_reasoning": "<string: 2-3 sentences explaining your verdict and the sources you checked>"
}

Rules:
1. "credibility" is your main 0-100 score. 100=absolutely true, 0=absolutely false.
2. "balanced_views" must contain 2-3 actual article headlines and their domains that you found via web search. This is CRITICAL.
3. Be objective. Your ENTIRE output must be the JSON structure above. Do not output anything else.
"""

    try:
        response = requests.post(
            MERCURY_API_URL,
            headers={
                "Authorization": f"Bearer {MERCURY_API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": "mercury-2",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": text}
                ],
                "response_format": {"type": "json_object"}
            },
            timeout=30 # Allow time for web search
        )
        response.raise_for_status()
        
        # The API returns the JSON string in the 'content' field
        result_json_str = response.json()['choices'][0]['message']['content']
        result_data = extract_json_from_text(result_json_str)
        
        print(f"Final AI Score: {result_data.get('credibility')}")
        return result_data

    except Exception as e:
        print(f"Mercury API Error: {str(e)}")
        # Fallback response so the app doesn't crash on API failure
        return {
            "credibility": 50.0,
            "fake_probability": 50.0,
            "manipulation": {"level": "MEDIUM", "emotion": "neutral", "intensity": 50.0, "keywords": []},
            "bias": {"leaning": "NEUTRAL", "confidence": 50.0, "propaganda_flag": False},
            "source_reliability": {"level": "MEDIUM", "score": 50, "domain": "unknown"},
            "clickbait": {"is_clickbait": False, "probability": 20.0},
            "balanced_views": ["API Error fallback - Unable to fetch sources"],
            "ai_reasoning": f"Analysis failed due to API connectivity issues. ({str(e)})"
        }

# ──────────────────────────────────────────────
# IMAGE ANALYSIS — TWO-STEP PIPELINE
# Step 1: Gemini 1.5 Flash  → OCR-extract text from the image
# Step 2: Mercury 2         → Fact-check that extracted text (same as /analyze)
#
# WHY: mercury-2 is a text-only model. It silently ignores the image_url
# content block, so the entire image was being thrown away on the old
# single-pass approach, resulting in a credibility score of 0.
# ──────────────────────────────────────────────
class AnalyzeImageRequest(BaseModel):
    image_base64: str

def _detect_mime_type(image_base64: str) -> str:
    """Detect image MIME type from the first bytes of the base64 data."""
    try:
        # Decode just the first 16 bytes to check magic bytes
        header = base64.b64decode(image_base64[:24] + "==")
        if header[:2] == b'\xff\xd8':
            return "image/jpeg"
        if header[:8] == b'\x89PNG\r\n\x1a\n':
            return "image/png"
        if header[:4] in (b'RIFF', b'WEBP') or header[8:12] == b'WEBP':
            return "image/webp"
        if header[:6] in (b'GIF87a', b'GIF89a'):
            return "image/gif"
    except Exception:
        pass
    return "image/jpeg"  # safe default


def _extract_text_from_image_gemini(image_base64: str) -> str:
    """
    Step 1: call Gemini 1.5 Flash to OCR-extract all readable text
    from the base64-encoded image.  Returns the extracted text string.
    Raises on failure so the caller can fall back gracefully.
    """
    if not GEMINI_API_KEY:
        raise ValueError(
            "GEMINI_API_KEY environment variable is not set. "
            "Get a free key at https://aistudio.google.com/apikey and restart the server."
        )

    mime_type = _detect_mime_type(image_base64)
    print(f"[Gemini OCR] Detected MIME type: {mime_type}")

    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": (
                            "This is a news image or screenshot. Please do the following:\n"
                            "1. Extract ALL visible text — headlines, subheadings, captions, "
                            "chyrons, ticker text, watermarks, social media post text, article body.\n"
                            "2. If there is very little or no text, describe the visual content "
                            "as a news claim (e.g. 'Breaking news: US military plane crashes in Iraq').\n"
                            "3. Output ONLY the extracted text or description — no commentary, "
                            "no explanations, just the raw content from the image."
                        )
                    },
                    {
                        "inline_data": {
                            "mime_type": mime_type,
                            "data": image_base64
                        }
                    }
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0,
            "maxOutputTokens": 2048
        }
    }

    resp = requests.post(
        GEMINI_OCR_URL,
        headers={"Content-Type": "application/json"},
        params={"key": GEMINI_API_KEY},
        json=payload,
        timeout=30
    )

    # Log errors from Gemini for debugging
    if not resp.ok:
        print(f"[Gemini OCR] Error {resp.status_code}: {resp.text[:500]}")
    resp.raise_for_status()

    data = resp.json()
    candidates = data.get("candidates", [])
    if not candidates:
        # Check for promptFeedback block reason
        block = data.get("promptFeedback", {}).get("blockReason", "unknown")
        raise ValueError(f"Gemini returned no candidates (blockReason={block})")

    parts = candidates[0].get("content", {}).get("parts", [])
    if not parts:
        raise ValueError("Gemini candidate has no parts")

    extracted = parts[0].get("text", "").strip()
    return extracted



@app.post("/analyze-image")
async def analyze_image(request: AnalyzeImageRequest):
    print(f"\n--- New Image Analysis (2-Step: Gemini OCR → Mercury Fact-Check) ---")

    extracted_text = ""

    # ── Step 1: OCR ────────────────────────────────────────────────────────────
    try:
        extracted_text = _extract_text_from_image_gemini(request.image_base64)
        print(f"[Step 1] Gemini extracted {len(extracted_text)} chars: {extracted_text[:200]}")
    except Exception as ocr_err:
        print(f"[Step 1] Gemini OCR failed: {ocr_err}")
        return {
            "credibility": 50.0,
            "fake_probability": 50.0,
            "manipulation": {"level": "LOW", "emotion": "neutral", "intensity": 0.0, "keywords": []},
            "bias": {"leaning": "NEUTRAL", "confidence": 50.0, "propaganda_flag": False},
            "source_reliability": {"level": "LOW", "score": 0, "domain": "unknown"},
            "clickbait": {"is_clickbait": False, "probability": 0.0},
            "balanced_views": ["OCR step failed — check GEMINI_API_KEY"],
            "ai_reasoning": f"Could not extract text from the image: {str(ocr_err)}",
            "extracted_text": ""
        }

    if not extracted_text or len(extracted_text.strip()) < 10:
        print("[Step 1] No meaningful text found in image.")
        return {
            "credibility": 50.0,
            "fake_probability": 50.0,
            "manipulation": {"level": "LOW", "emotion": "neutral", "intensity": 0.0, "keywords": []},
            "bias": {"leaning": "NEUTRAL", "confidence": 50.0, "propaganda_flag": False},
            "source_reliability": {"level": "LOW", "score": 0, "domain": "unknown"},
            "clickbait": {"is_clickbait": False, "probability": 0.0},
            "balanced_views": ["No text found in the image"],
            "ai_reasoning": "The image does not contain any readable text to fact-check.",
            "extracted_text": ""
        }

    # ── Step 2: Fact-check the extracted text via Mercury 2 ───────────────────
    print(f"[Step 2] Sending extracted text to Mercury 2 for fact-checking...")
    try:
        analyze_req = AnalyzeRequest(text=extracted_text)
        result = await analyze(analyze_req)
        result["extracted_text"] = extracted_text   # attach OCR'd text to response
        print(f"[Step 2] Mercury credibility score: {result.get('credibility')}")
        return result
    except Exception as fc_err:
        print(f"[Step 2] Mercury fact-check failed: {fc_err}")
        return {
            "credibility": 50.0,
            "fake_probability": 50.0,
            "manipulation": {"level": "LOW", "emotion": "neutral", "intensity": 0.0, "keywords": []},
            "bias": {"leaning": "NEUTRAL", "confidence": 50.0, "propaganda_flag": False},
            "source_reliability": {"level": "LOW", "score": 0, "domain": "unknown"},
            "clickbait": {"is_clickbait": False, "probability": 0.0},
            "balanced_views": ["Fact-check step failed"],
            "ai_reasoning": f"Text was extracted but fact-checking failed: {str(fc_err)}",
            "extracted_text": extracted_text
        }


# ──────────────────────────────────────────────
# URL ANALYSIS — FAST SCRAPE + SINGLE AI CALL
# ──────────────────────────────────────────────
class AnalyzeUrlRequest(BaseModel):
    url: str

@app.post("/analyze-url")
async def analyze_url(request: AnalyzeUrlRequest):
    url = request.url
    print(f"\n--- New URL Analysis (Fast) ---")
    print(f"URL: {url}")
    
    try:
        # Fast scrape with tight timeout
        page = requests.get(url, headers={"User-Agent": "Mozilla/5.0"}, timeout=5)
        page.raise_for_status()
        
        soup = BeautifulSoup(page.text, 'html.parser')
        for tag in soup(['script', 'style', 'nav', 'footer']):
            tag.decompose()
        
        title = soup.title.string if soup.title else ''
        article = soup.find('article') or soup.find('main') or soup.find('body')
        paragraphs = article.find_all('p') if article else soup.find_all('p')
        # Only grab first 10 paragraphs — enough for fact-checking, much faster
        body_text = ' '.join([p.get_text().strip() for p in paragraphs[:10]])
        
        extracted = f"Title: {title}\n\n{body_text}"[:2000]  # Tighter limit = faster AI response
        print(f"Scraped {len(extracted)} chars")
        
        if len(body_text.strip()) < 30:
            return {
                "credibility": 50.0, "fake_probability": 50.0,
                "manipulation": {"level": "LOW", "emotion": "neutral", "intensity": 0.0, "keywords": []},
                "bias": {"leaning": "NEUTRAL", "confidence": 50.0, "propaganda_flag": False},
                "source_reliability": {"level": "LOW", "score": 0, "domain": "unknown"},
                "clickbait": {"is_clickbait": False, "probability": 0.0},
                "balanced_views": ["Not enough content at this URL"],
                "ai_reasoning": f"Could not extract enough text from '{url}'.",
                "extracted_text": extracted
            }
        
        # Single AI call with the scraped content
        analyze_req = AnalyzeRequest(text=extracted)
        result = await analyze(analyze_req)
        result["extracted_text"] = extracted
        return result
        
    except Exception as e:
        print(f"URL error: {e}")
        return {
            "credibility": 50.0, "fake_probability": 50.0,
            "manipulation": {"level": "LOW", "emotion": "neutral", "intensity": 0.0, "keywords": []},
            "bias": {"leaning": "NEUTRAL", "confidence": 50.0, "propaganda_flag": False},
            "source_reliability": {"level": "LOW", "score": 0, "domain": "unknown"},
            "clickbait": {"is_clickbait": False, "probability": 0.0},
            "balanced_views": [f"Failed: {url}"],
            "ai_reasoning": f"Could not access URL. ({str(e)})",
            "extracted_text": ""
        }


# 5. Keep Appwrite feedback working (Mocked endpoint for now so it doesn't 404)
class FeedbackRequest(BaseModel):
    feedback: str

@app.post("/feedback")
async def feedback(request: FeedbackRequest):
    print(f"Received feedback: {request.feedback}")
    return {"status": "success"}

# Health check / tunnel info endpoint
@app.get("/tunnel-url")
async def get_tunnel_url():
    return {"status": "ok", "message": "Use localtunnel URL to access this server publicly."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
