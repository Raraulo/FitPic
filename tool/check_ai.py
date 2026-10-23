"""Check configured providers without logging credentials or personal photos."""
import base64
import json
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV = dict(
    line.split('=', 1) for line in (ROOT / '.env').read_text().splitlines()
    if '=' in line and not line.startswith('#')
)

def request(provider, url, headers, body=None):
    try:
        headers = {**headers, 'User-Agent': 'FitPic/1.0'}
        req = urllib.request.Request(url, headers=headers,
            data=json.dumps(body).encode() if body is not None else None)
        with urllib.request.urlopen(req, timeout=35) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        try:
            data = json.loads(error.read())
        except ValueError:
            print(provider, 'HTTP', error.code, 'non-JSON response')
            return None
        detail = data.get('error', {})
        print(provider, 'HTTP', error.code, detail.get('code'), detail.get('status'))
    except Exception as error:
        print(provider, type(error).__name__)
    return None

if __name__ == '__main__':
    import sys
    groq_headers = {'Authorization': 'Bearer ' + ENV['GROQ_API_KEY'].strip().strip('\"\''), 'Content-Type': 'application/json'}
    gemini_headers = {'x-goog-api-key': ENV['GEMINI_API_KEY'].strip().strip('\"\''), 'Content-Type': 'application/json'}
    if len(sys.argv) == 1:
        for provider, url, headers in [
            ('groq', 'https://api.groq.com/openai/v1/models', groq_headers),
            ('gemini', 'https://generativelanguage.googleapis.com/v1beta/models', gemini_headers),
        ]:
            data = request(provider, url, headers)
            if data:
                print(provider, [item.get('id', item.get('name')) for item in data.get('data', data.get('models', []))])
    else:
        provider, model, asset = sys.argv[1:4]
        path = ROOT / 'assets' / 'ropa' / asset
        encoded = base64.b64encode(path.read_bytes()).decode()
        mime = 'image/jpeg' if path.suffix == '.jpg' else 'image/png'
        prompt = 'Identifica la prenda principal. JSON: {"nombre":"nombre concreto","color":"color visible","categoria":"categoria"}. No inventes si no hay ropa.'
        if provider == 'groq':
            data = request(provider, 'https://api.groq.com/openai/v1/chat/completions', groq_headers, {
                'model': model, 'messages': [{'role': 'user', 'content': [
                    {'type': 'text', 'text': prompt},
                    {'type': 'image_url', 'image_url': {'url': f'data:{mime};base64,{encoded}'}}
                ]}], 'temperature': 0.2, 'max_completion_tokens': 2048,
                'response_format': {'type': 'json_object'}
            })
            if data: print(provider, model, asset, data['choices'][0]['message']['content'])
        else:
            data = request(provider, f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent', gemini_headers, {
                'contents': [{'parts': [{'text': prompt}, {'inline_data': {'mime_type': mime, 'data': encoded}}]}],
                'generationConfig': {'temperature': 0.1, 'responseMimeType': 'application/json'}
            })
            if data:
                parts = data['candidates'][0]['content']['parts']
                print(provider, model, asset, ''.join(part.get('text', '') for part in parts if not part.get('thought')))
