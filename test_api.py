import requests

img_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="

req = {'image_base64': img_b64}
print('Sending request to /analyze-image')
try:
    res = requests.post('http://localhost:8000/analyze-image', json=req)
    print("Status:", res.status_code)
except Exception as e:
    print('Failed:', e)
