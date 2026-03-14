from PIL import Image, ImageDraw, ImageFont
import requests
import base64
import io

img = Image.new('RGB', (200, 100), color = (73, 109, 137))
d = ImageDraw.Draw(img)
d.text((10,10), "The moon is made of cheese", fill=(255,255,0))

buffer = io.BytesIO()
img.save(buffer, format="JPEG")
img_b64 = base64.b64encode(buffer.getvalue()).decode('utf-8')

req = {'image_base64': img_b64}
print('Sending request to /analyze-image')
try:
    res = requests.post('http://localhost:8000/analyze-image', json=req)
    print("Status:", res.status_code)
    print("Response:", res.text)
except Exception as e:
    print('Failed:', e)
