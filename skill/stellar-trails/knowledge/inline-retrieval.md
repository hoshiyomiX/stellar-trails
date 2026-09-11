# Inline Content Retrieval Protocol

Moved from SKILL.md in v9.14.0. Reference-only — LLM can improvise without reading this.

## Step 1: Fetch with curl (v9.17.1: SSRF protection — no auto-redirect, block internal IPs)
```bash
URL="<url>"

# v9.17.1 Fix #4: Block internal/private IPs and metadata endpoints (SSRF protection)
case "$URL" in
  http://127.*|http://localhost*|http://169.254.*|http://10.*|http://192.168.*|http://172.16.*|https://127.*|https://localhost*)
    echo "✗ Blocked: internal/private URL not allowed (SSRF protection)"; exit 1 ;;
esac

# Validate URL format
if ! echo "$URL" | grep -qP '^https?://[a-zA-Z0-9]'; then
  echo "✗ Invalid URL format"; exit 1
fi

OUTFILE="/tmp/st-retrieval-$(echo "$URL" | sha256sum | cut -c1-8).html"
# Fetch WITHOUT -L (no auto-redirect following — SSRF protection)
HTTP_STATUS=$(curl -sS -m 10 -o "$OUTFILE" -w "%{http_code}" \
  -A "Mozilla/5.0 (compatible; StellarTrails/9.5)" \
  --max-redirs 0 "$URL")
[ "$HTTP_STATUS" = "200" ] || { echo "✗ Retrieval failed: HTTP $HTTP_STATUS"; exit 1; }
echo "✓ Fetched $(stat -c%s "$OUTFILE") bytes from $URL"
```

## Step 2: Extract text with python3
```bash
python3 << 'PYEOF'
import sys, re, html
from html.parser import HTMLParser
class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text = []
        self.skip = False
        self.skip_tags = {'script', 'style', 'nav', 'footer', 'header', 'aside', 'noscript'}
        self.title = ''
        self.in_title = False
    def handle_starttag(self, tag, attrs):
        if tag in self.skip_tags: self.skip = True
        if tag == 'title': self.in_title = True
        if tag in ('h1','h2','h3','h4','h5','h6','p','li','td','th','div','section','article','pre','code','blockquote'):
            self.text.append('\n')
    def handle_endtag(self, tag):
        if tag in self.skip_tags: self.skip = False
        if tag == 'title': self.in_title = False
        if tag in ('p','li','div','section','article','pre','blockquote'): self.text.append('\n')
    def handle_data(self, data):
        if self.skip: return
        if self.in_title: self.title += data
        text = data.strip()
        if text: self.text.append(text)
with open(sys.argv[1], 'r', encoding='utf-8', errors='ignore') as f: content = f.read()
parser = TextExtractor()
parser.feed(content)
result = ' '.join(parser.text)
result = re.sub(r'\s+', ' ', result)
result = re.sub(r' \n ', '\n', result)
result = re.sub(r'\n{3,}', '\n\n', result)
result = result[:3000]
if parser.title: print(f"# {parser.title.strip()}\n")
print(result)
PYEOF
```

## Step 3: Truncate to 500 words
```bash
TEXT_FILE="${OUTFILE%.html}.txt"
python3 -c "import sys; text=sys.stdin.read(); print(' '.join(text.split()[:500]))" < "$TEXT_FILE" > "${TEXT_FILE}.truncated"
echo "✓ Extracted $(wc -w < "${TEXT_FILE}.truncated") words"
```

## When to use: SADC Standard/Complex, VERIFY doc claims, any web text extraction
## Default: inline. Fallback: agent-browser (JS), then crawl4ai (last resort)
