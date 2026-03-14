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
# IMAGE ANALYSIS — SINGLE-PASS (OCR + Fact-Check in ONE call)
# ──────────────────────────────────────────────
class AnalyzeImageRequest(BaseModel):
    image_base64: str

@app.post("/analyze-image")
async def analyze_image(request: AnalyzeImageRequest):
    print(f"\n--- New Image Analysis (Single-Pass) ---")
    
    system_prompt = """You are EchoGuard, an AI fact-checking engine.
1. First, extract ALL text visible in the image.
2. Then, fact-check the extracted claims.
You MUST output ONLY a single valid JSON object:
{
  "credibility": <float 0-100>,
  "fake_probability": <float 0-100>,
  "manipulation": {"level": "<HIGH/MEDIUM/LOW>", "emotion": "<string>", "intensity": <float 0-100>, "keywords": ["<string>"]},
  "bias": {"leaning": "<LEFT/RIGHT/NEUTRAL/BIAS-FREE>", "confidence": <float 0-100>, "propaganda_flag": <boolean>},
  "source_reliability": {"level": "<HIGH/MEDIUM/LOW>", "score": <int 0-100>, "domain": "<string>"},
  "clickbait": {"is_clickbait": <boolean>, "probability": <float 0-100>},
  "balanced_views": ["<Article Title - domain.com>"],
  "ai_reasoning": "<2-3 sentences with verdict and sources>",
  "extracted_text": "<the text you extracted from the image>"
}
Rules: Output ONLY valid JSON. If no text in image, describe what you see and fact-check that."""

    try:
        response = requests.post(
            MERCURY_API_URL,
            headers={"Authorization": f"Bearer {MERCURY_API_KEY}", "Content-Type": "application/json"},
            json={
                "model": "mercury-2",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "Here is the image. Extract the text and fact-check it according to your system prompt."},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{request.image_base64}"
                                }
                            }
                        ]
                    }
                ]
            },
            timeout=45
        )
        response.raise_for_status()
        result_str = response.json()['choices'][0]['message']['content']
        result = extract_json_from_text(result_str)
        print(f"Image analysis score: {result.get('credibility')}")
        return result
    except Exception as e:
        print(f"Image analysis error: {e}")
        return {
            "credibility": 50.0, "fake_probability": 50.0,
            "manipulation": {"level": "LOW", "emotion": "neutral", "intensity": 0.0, "keywords": []},
            "bias": {"leaning": "NEUTRAL", "confidence": 50.0, "propaganda_flag": False},
            "source_reliability": {"level": "LOW", "score": 0, "domain": "unknown"},
            "clickbait": {"is_clickbait": False, "probability": 0.0},
            "balanced_views": ["Image analysis failed"],
            "ai_reasoning": f"Could not process the image. ({str(e)})",
            "extracted_text": ""
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
