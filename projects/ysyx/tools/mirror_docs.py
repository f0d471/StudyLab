#!/usr/bin/env python3
"""Mirror public YSYX documentation as portable, searchable offline HTML."""
import argparse
import collections
import concurrent.futures
import datetime
import html
from html.parser import HTMLParser
import json
import mimetypes
import os
from pathlib import Path
import posixpath
import re
import shutil
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

ORIGIN = "https://ysyx.oscc.cc"
SEEDS = [ORIGIN + "/docs/", ORIGIN + "/docs/ics-pa/"]
UA = "YSYX-OfflineReader/1.0 (personal offline study; 3 workers, 4 requests/sec)"
CSS_URL = re.compile(r"url\(\s*(['\"]?)(.*?)\1\s*\)", re.I)
ATTR = re.compile(r'(\s(?:href|src|data-src|poster|data-background-image|xlink:href)\s*=\s*)(["\'])(.*?)\2', re.I | re.S)
MATH_URL = "https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-svg-full.js"
TEXT_KINDS = {"page", "css", "routes"}

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def canonical(value, base):
    value = html.unescape(value).strip()
    if not value or value.startswith(("#", "data:", "mailto:", "tel:", "javascript:", "blob:")):
        return None
    try:
        u = urllib.parse.urlsplit(urllib.parse.urljoin(base, value))
        if u.scheme not in ("http", "https") or u.username or u.password:
            return None
        scheme = "https" if u.hostname == "ysyx.oscc.cc" else u.scheme
        p = posixpath.normpath(u.path or "/")
        if u.path.endswith("/") and not p.endswith("/"):
            p += "/"
        return urllib.parse.urlunsplit((scheme, u.netloc.lower(), p, u.query, ""))
    except ValueError:
        return None

def page_scope(url):
    u = urllib.parse.urlsplit(url)
    if u.netloc != "ysyx.oscc.cc":
        return False
    p = u.path
    return p.startswith(("/docs/", "/slides/")) and (p.endswith(("/", ".html")) or not posixpath.splitext(p)[1])

def safe_part(value):
    value = urllib.parse.unquote(value)
    return re.sub(r'[<>:"\\|?*\x00-\x1f]', "_", value).rstrip(". ") or "_"

def url_path(url):
    u = urllib.parse.urlsplit(url)
    parts = [safe_part(x) for x in u.path.split("/") if x not in ("", ".", "..")]
    p = Path(safe_part(u.netloc), *parts)
    if u.path.endswith("/") or not posixpath.splitext(u.path)[1]:
        p /= "index.html"
    if u.query:
        import hashlib
        suffix = hashlib.sha256(u.query.encode()).hexdigest()[:12]
        p = p.with_name(p.stem + "__q_" + suffix + p.suffix)
    return p

class Scan(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.refs = []
        self.external = []
        self.scripts = []
        self.title = []
        self.in_title = False
        self.capture = 0
        self.depth = 0
        self.skip = 0
        self.text = []
        self.counts = collections.Counter()
        self.ids = set()
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if a.get("id"):
            self.ids.add(a["id"])
        if tag == "title":
            self.in_title = True
        void = tag in ("area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr")
        if not void:
            self.depth += 1
        if not self.capture and (tag == "main" or (tag == "div" and "slides" in a.get("class", "").split())):
            self.capture = self.depth
        if self.capture:
            if tag in ("script", "style"):
                self.skip += 1
            if tag in ("h1","h2","h3","h4","h5","h6","pre","code","table","details","img","mjx-container","math"):
                self.counts[tag] += 1
        if tag == "script":
            if a.get("src"):
                self.scripts.append(a["src"])
            return
        if tag == "link":
            if "stylesheet" in a.get("rel", ""):
                self.refs.append((a.get("href", ""), "css"))
            elif "icon" in a.get("rel", ""):
                self.refs.append((a.get("href", ""), "asset"))
            return
        if tag == "a":
            if a.get("href"):
                self.refs.append((a["href"], "link"))
            return
        for attr in ("src","data-src","poster","data-background-image","xlink:href"):
            if a.get(attr):
                self.refs.append((a[attr], "embed" if tag in ("iframe","object") else "asset"))
        if a.get("data") and tag == "object":
            self.refs.append((a["data"], "asset"))
        if a.get("srcset"):
            for item in a["srcset"].split(","):
                self.refs.append((item.strip().split(" ")[0], "asset"))
        if a.get("style"):
            self.refs.extend((m[1], "asset") for m in CSS_URL.findall(a["style"]))
    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in ("area","base","br","col","embed","hr","img","input","link","meta","param","source","track","wbr"):
            self.handle_endtag(tag)
    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False
        if self.capture:
            if tag in ("script","style") and self.skip:
                self.skip -= 1
            if self.depth == self.capture:
                self.capture = 0
        self.depth = max(0, self.depth - 1)
    def handle_data(self, data):
        if self.in_title:
            self.title.append(data)
        if self.capture and not self.skip:
            self.text.append(data)
    def result(self):
        return {"title":"".join(self.title).strip(), "text":re.sub(r"\s+", " ", " ".join(self.text)).strip(),
                "counts":dict(self.counts), "ids":sorted(self.ids)}

OFFLINE_CSS = """
html{scroll-behavior:smooth}body{padding-top:46px!important}
.offline-bar{position:fixed;inset:0 0 auto;z-index:99999;display:flex;align-items:center;gap:14px;
padding:9px 16px;background:#173148;color:#fff;font:14px/26px system-ui,sans-serif;box-sizing:border-box;min-height:44px}
.offline-bar a,.offline-bar button{color:#fff;text-decoration:none}
.offline-bar button{background:none;border:1px solid #8ba7b8;border-radius:4px;cursor:pointer}
.offline-bar .offline-source{margin-left:auto;font-size:12px}
.navbar{top:46px!important}.sidebar{top:calc(3.6rem + 46px)!important}
.navbar-dropdown-wrapper.offline-open>.navbar-dropdown{display:block!important}
.sidebar-item-children{display:block!important}.sidebar-group.is-sub-group>.sidebar-heading{cursor:auto}
@media(max-width:719px){body.offline-sidebar .sidebar{transform:translateX(0)!important}.offline-source{display:none}}
/* Reveal slides become a continuous reading edition; no hidden slides or fragments. */
body.offline-slides{background:#fff!important;color:#202c36!important;font:17px/1.75 system-ui,sans-serif!important}
.offline-slides .reveal,.offline-slides .reveal .slides{position:static!important;width:auto!important;height:auto!important;
transform:none!important;perspective:none!important;overflow:visible!important;font:inherit!important;color:inherit!important;
text-align:left!important;margin:0 auto!important;max-width:1100px!important}
.offline-slides .reveal .slides section{position:static!important;display:block!important;opacity:1!important;visibility:visible!important;
transform:none!important;inset:auto!important;margin:24px 0!important;padding:24px!important;width:auto!important;
height:auto!important;border-bottom:1px solid #d9e1e7;box-sizing:border-box}
.offline-slides .fragment{opacity:1!important;visibility:visible!important;transform:none!important}
.offline-slides img,.offline-slides svg{max-width:100%;height:auto}
.offline-slides pre{white-space:pre;overflow:auto;background:#f3f6f9;padding:16px}
.offline-slides .reveal h1,.offline-slides .reveal h2,.offline-slides .reveal h3{font:700 1.5em/1.4 system-ui,sans-serif;text-transform:none}
"""
OFFLINE_JS = """
document.querySelectorAll("img[data-src],source[data-src],video[data-src],audio[data-src]").forEach(function(n){if(!n.getAttribute("src"))n.setAttribute("src",n.getAttribute("data-src"))});
document.querySelectorAll("[data-background-image]").forEach(function(n){n.style.backgroundImage="url("+JSON.stringify(n.getAttribute("data-background-image"))+")";n.style.backgroundSize="contain";n.style.backgroundPosition="center";n.style.backgroundRepeat="no-repeat";n.style.minHeight="480px"});
document.querySelectorAll('.navbar-dropdown-title,.navbar-dropdown-title-mobile').forEach(function(b){
 b.addEventListener('click',function(){var p=b.closest('.navbar-dropdown-wrapper');if(p)p.classList.toggle('offline-open')})});
document.querySelectorAll('.toggle-sidebar-button').forEach(function(b){b.addEventListener('click',function(){document.body.classList.toggle('offline-sidebar')})});
document.querySelectorAll('button.copy').forEach(function(b){b.addEventListener('click',function(){
 var p=b.parentNode.querySelector('code');if(p&&navigator.clipboard)navigator.clipboard.writeText(p.textContent)})});
"""
PORTAL_JS = """
var input=document.getElementById('search'),searchStatus=document.getElementById('search-status'),results=document.getElementById('results');
function runSearch(){var q=input.value.trim().toLowerCase();results.replaceChildren();if(!q){searchStatus.textContent='输入关键词搜索全文；也可从下方目录进入。';return}
 var terms=q.split(/\\s+/),matches=OFFLINE_PAGES.filter(function(p){return terms.every(function(t){return (p.title+' '+p.text+' '+p.path).toLowerCase().includes(t)})});
 searchStatus.textContent='找到 '+matches.length+' 个页面（显示前 100 项）';
 matches.slice(0,100).forEach(function(p){var item=document.createElement('li'),a=document.createElement('a'),s=document.createElement('p');
 a.href=p.path;a.textContent=p.title+' · '+p.path;var at=p.text.toLowerCase().indexOf(terms[0]);s.textContent=p.text.slice(Math.max(0,at-65),Math.max(0,at-65)+230);
 item.append(a,s);results.append(item)})}
input.addEventListener('input',runSearch);input.value=new URLSearchParams(location.search).get('q')||'';runSearch();
"""

class Mirror:
    def __init__(self, output, refresh=False, workers=3, retry_failed=False):
        self.root = output.resolve()
        self.site = self.root / "site"
        self.originals = self.root / "originals"
        self.root.mkdir(parents=True, exist_ok=True)
        self.site.mkdir(exist_ok=True)
        self.originals.mkdir(exist_ok=True)
        self.manifest_path = self.root / "manifest.json"
        self.records = {}
        if self.manifest_path.exists():
            saved = json.loads(self.manifest_path.read_text(encoding="utf-8"))
            self.records = saved.get("records", {})
        self.refresh = refresh
        self.retry_failed = retry_failed
        self.workers = workers
        self.pending = collections.deque()
        self.seen = set()
        self.external = set()
        self.routes = set(saved.get("routes", [])) if self.manifest_path.exists() else set()
        external_file = self.root / "external-links.json"
        if external_file.exists():
            self.external = {(r["url"], r["relation"]) for r in json.loads(external_file.read_text(encoding="utf-8"))}
        self.rate_lock = threading.Lock()
        self.next_request = 0
        self.started = now()
        self.completed = 0
        self.total_bytes = sum(r.get("download_bytes",0) for r in self.records.values() if r.get("status") == "ok")

    def path_for(self, url):
        return self.site / url_path(url)

    def enqueue(self, url, kind, source):
        if kind == "page" and url and not url.endswith(("/", ".html")) and url + ".html" in self.routes:
            url += ".html"
        if not url or url in self.seen:
            return
        if self.total_bytes > 4*1024**3:
            raise RuntimeError("4 GiB download limit reached; review the scope before continuing")
        self.seen.add(url)
        self.pending.append((url, kind, source))

    def download(self, job):
        url, kind, source = job
        old = self.records.get(url)
        if old and old.get("status") == "failed" and not self.refresh and not self.retry_failed:
            return dict(old, reused=True)
        if not self.refresh and old and old.get("status") == "ok":
            p = self.root / old["original_file"]
            if p.is_file():
                return dict(old, reused=True)
        record = {"url":url, "kind":kind, "discovered_from":source, "fetched_utc":now()}
        for attempt in range(3):
            try:
                with self.rate_lock:
                    wait = max(0, self.next_request-time.monotonic())
                    if wait:
                        time.sleep(wait)
                    self.next_request = time.monotonic()+0.25
                req = urllib.request.Request(url, headers={"User-Agent":UA,"Accept-Encoding":"identity"})
                with urllib.request.urlopen(req, timeout=35) as response:
                    mime = response.headers.get_content_type()
                    record.update(http_status=response.status, final_url=response.url, content_type=mime,
                                  etag=response.headers.get("ETag"), last_modified=response.headers.get("Last-Modified"))
                    length = int(response.headers.get("Content-Length") or "0")
                    if length > 256*1024**2:
                        raise ValueError("asset exceeds 256 MiB per-file limit")
                    data = response.read(256*1024**2+1)
                    if len(data) > 256*1024**2:
                        raise ValueError("asset exceeds 256 MiB per-file limit")
                is_html = mime == "text/html" or data.lstrip().lower().startswith((b"<!doctype html",b"<html"))
                if is_html and kind not in ("page",):
                    raise ValueError("soft 404: requested asset returned HTML")
                if kind == "page" and not is_html:
                    kind = "asset"
                    record["kind"] = kind
                if kind == "page" and "/docs/" in urllib.parse.urlsplit(url).path:
                    if b"/docs/assets/" not in data:
                        raise ValueError("soft 404: requested documentation returned the main website")
                if kind == "page" and "/slides/" in urllib.parse.urlsplit(url).path:
                    if b"reveal" not in data:
                        raise ValueError("soft 404: requested slides returned a different page")
                relative = url_path(url)
                dest = (self.originals if kind in TEXT_KINDS else self.site) / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(data)
                record.update(status="ok", kind=kind, download_bytes=len(data),
                              original_file=dest.relative_to(self.root).as_posix(),
                              local_file=self.path_for(url).relative_to(self.root).as_posix())
                if kind == "routes":
                    record["local_file"] = None
                return record
            except Exception as exc:
                record.update(status="failed", error=str(exc))
                retry = isinstance(exc, (TimeoutError,urllib.error.URLError)) and not (
                    isinstance(exc,urllib.error.HTTPError) and exc.code in (400,401,403,404,410))
                if not retry or attempt == 2:
                    if isinstance(exc,urllib.error.HTTPError):
                        record["http_status"] = exc.code
                    return record
                time.sleep(1+attempt)

    def inspect(self, record):
        if record.get("status") != "ok":
            return
        url = record["url"]
        kind = record["kind"]
        if kind not in TEXT_KINDS:
            return
        text = (self.root / record["original_file"]).read_text(encoding="utf-8",errors="replace")
        if kind == "routes":
            paths = set(re.findall(r'\bpath\s*:\s*["\']([^"\']+)["\']',text))
            paths.update(re.findall(r'["\'](/[^"\'\s<>]*\.html)["\']',text))
            for p in sorted(paths):
                if not p.startswith("/docs/"):
                    p = "/docs"+p
                candidate = canonical(p,url)
                if candidate and page_scope(candidate) and "/assets/" not in p:
                    self.routes.add(candidate)
                    self.enqueue(candidate,"page",url)
            return
        if kind == "css":
            for _,ref in CSS_URL.findall(text):
                candidate = canonical(ref,url)
                if candidate:
                    self.enqueue(candidate,"css" if urllib.parse.urlsplit(candidate).path.endswith(".css") else "asset",url)
            for ref in re.findall(r'@import\s+["\']([^"\']+)["\']',text):
                self.enqueue(canonical(ref,url),"css",url)
            return
        scan = Scan()
        scan.feed(text)
        for ref, relation in scan.refs:
            candidate = canonical(ref,url)
            if not candidate:
                continue
            if relation in ("link","embed"):
                if page_scope(candidate):
                    self.enqueue(candidate,"page",url)
                elif urllib.parse.urlsplit(candidate).netloc == "ysyx.oscc.cc" and urllib.parse.urlsplit(candidate).path.startswith(("/docs/","/slides/")):
                    self.enqueue(candidate,"asset",url)
                else:
                    self.external.add((candidate,relation))
            else:
                assetkind = "css" if relation=="css" else "asset"
                self.enqueue(candidate,assetkind,url)
        if "/docs/" in urllib.parse.urlsplit(url).path:
            for script in scan.scripts:
                if re.search(r"/assets/app[^/]*\.js",script):
                    self.enqueue(canonical(script,url),"routes",url)
        for style in re.findall(r"<style\b[^>]*>(.*?)</style>",text,re.I|re.S):
            for _,ref in CSS_URL.findall(style):
                self.enqueue(canonical(ref,url),"asset",url)

    def save(self, finished=False):
        data = {"schema":1,"started_utc":self.started,"updated_utc":now(),"finished":finished,
                "seeds":SEEDS,"page_scope":["https://ysyx.oscc.cc/docs/","https://ysyx.oscc.cc/slides/ (linked course slides)"],
                "routes":sorted(self.routes),"records":self.records}
        tmp = self.manifest_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding="utf-8")
        tmp.replace(self.manifest_path)
        summary = collections.Counter(r["status"] for r in self.records.values())
        (self.root/"progress.json").write_text(json.dumps({"updated_utc":now(),"queued":len(self.pending),"completed":self.completed,
            "status":dict(summary),"download_bytes":self.total_bytes},ensure_ascii=False,indent=2),encoding="utf-8")

    def crawl(self):
        for url in SEEDS:
            self.enqueue(url,"page","seed")
        self.enqueue(MATH_URL,"asset","offline math rendering")
        self.enqueue("https://cdn.jsdelivr.net/npm/mathjax@3.2.2/LICENSE","asset","MathJax license")
        active = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.workers) as pool:
            while self.pending or active:
                while self.pending and len(active)<self.workers:
                    job = self.pending.popleft()
                    active[pool.submit(self.download,job)] = job
                done,_ = concurrent.futures.wait(active,return_when=concurrent.futures.FIRST_COMPLETED)
                for future in done:
                    job=active.pop(future)
                    record=future.result()
                    old=self.records.get(record["url"],{})
                    if record.get("status")=="ok" and not record.get("reused"):
                        self.total_bytes += record["download_bytes"]-old.get("download_bytes",0)
                    record.pop("reused",None)
                    self.records[record["url"]]=record
                    self.completed+=1
                    self.inspect(record)
                    if self.completed%25==0:
                        self.save()
                        print(json.dumps({"completed":self.completed,"queued":len(self.pending),"active":len(active),
                            "MiB":round(self.total_bytes/1024**2,1),"failed":sum(r["status"]=="failed" for r in self.records.values())}),flush=True)
        self.save(finished=True)

    def lookup(self, url, base=None):
        direct = self.records.get(url)
        if direct and direct.get("status") == "ok":
            return direct
        u = urllib.parse.urlsplit(url)
        candidates = [url+".html"]
        if u.path.endswith(".htm"):
            candidates.append(url+"l")
        parts = u.path.strip("/").split("/")
        if parts and parts[0] == "docs":
            core = parts[1:]
            if len(core)>1 and core[0] in ("en","ru") and core[1] in ("en","ru"):
                core = core[1:]
            offset = 1 if core and core[0] in ("en","ru") else 0
            if len(core)>offset+1 and re.fullmatch(r"\d{4}",core[offset]) and re.fullmatch(r"\d{4}",core[offset+1]):
                core.pop(offset)
            if base and len(core)>offset and core[offset] in ("f","e","d","c","b"):
                match = re.search(r"/docs/(?:en/|ru/)?(\d{4})(?:/|$)",base)
                if match:
                    core.insert(offset,match.group(1))
            corrected = "/docs/" + "/".join(core)
            if u.path.endswith("/"):
                corrected += "/"
            normalized = urllib.parse.urlunsplit((u.scheme,u.netloc,corrected,u.query,""))
            candidates.extend([normalized,normalized+".html"])
        if u.path.startswith("/slides/"):
            corrected=re.sub(r"/(\d)\.html$",lambda m:"/"+m[1].zfill(2)+".html",u.path)
            candidates.append(urllib.parse.urlunsplit((u.scheme,u.netloc,corrected,u.query,"")))
        for alternative in candidates:
            target=self.records.get(alternative)
            if target and target.get("status")=="ok":
                return target
        return direct

    def resolve_aliases(self):
        for url, record in self.records.items():
            if record.get("status") == "ok":
                continue
            target = self.lookup(url,record.get("discovered_from"))
            if target and target.get("status") == "ok":
                record["resolved_to"] = target["url"]
                record["resolution"] = "source navigation syntax resolved to an existing downloaded page"

    def rewrite_ref(self, ref, base, current):
        candidate=canonical(ref,base)
        if not candidate:
            return ref
        record=self.lookup(candidate,base)
        if not record or record.get("status")!="ok" or not record.get("local_file"):
            return ref if urllib.parse.urlsplit(ref).scheme else urllib.parse.urljoin(base,ref)
        target=self.root/record["local_file"]
        relative=os.path.relpath(target,current.parent).replace(os.sep,"/")
        fragment=urllib.parse.urlsplit(html.unescape(ref)).fragment
        if fragment and not ("/slides/" in candidate and fragment.startswith("/")):
            relative+="#"+fragment
        return relative

    def render(self):
        self.resolve_aliases()
        support=self.site/"_offline"
        support.mkdir(exist_ok=True)
        (support/"reader.css").write_text(OFFLINE_CSS,encoding="utf-8")
        (support/"reader.js").write_text(OFFLINE_JS,encoding="utf-8")
        pages=[]
        content_errors=[]
        for url,r in self.records.items():
            if r.get("status")!="ok" or r.get("kind") not in ("page","css"):
                continue
            original=(self.root/r["original_file"]).read_text(encoding="utf-8",errors="replace")
            current=self.root/r["local_file"]
            current.parent.mkdir(parents=True,exist_ok=True)
            rewrite=lambda ref:self.rewrite_ref(ref,url,current)
            text=original
            if r["kind"]=="css":
                text=CSS_URL.sub(lambda m:"url("+m[1]+rewrite(m[2])+m[1]+")",text)
                text=re.sub(r'(@import\s+)(["\'])(.*?)\2',lambda m:m[1]+m[2]+rewrite(m[3])+m[2],text)
            else:
                # Preserve server-rendered content; disable SPA routing and analytics.
                text=re.sub(r"<script\b[^>]*>.*?</script\s*>","",text,flags=re.I|re.S)
                text=re.sub(r"<link\b[^>]*\brel=[\"'](?:modulepreload|prefetch|preload|preconnect|dns-prefetch)[\"'][^>]*>","",text,flags=re.I)
                text=re.sub(r"<base\b[^>]*>","",text,flags=re.I)
                text=ATTR.sub(lambda m:m[1]+m[2]+html.escape(rewrite(html.unescape(m[3])),quote=True)+m[2],text)
                text=re.sub(r'(\ssrcset\s*=\s*)(["\'])(.*?)\2',
                    lambda m:m[1]+m[2]+", ".join(" ".join([rewrite(item.strip().split()[0])]+item.strip().split()[1:]) for item in m[3].split(",") if item.strip())+m[2],text,flags=re.I|re.S)
                text=CSS_URL.sub(lambda m:"url("+m[1]+rewrite(m[2])+m[1]+")",text)
                prefix=os.path.relpath(support,current.parent).replace(os.sep,"/")
                portal=os.path.relpath(self.site/"index.html",current.parent).replace(os.sep,"/")
                docs=self.rewrite_ref(SEEDS[0],url,current)
                pa=self.rewrite_ref(SEEDS[1],url,current)
                bar='<div class="offline-bar"><a href="'+portal+'">离线目录与全文搜索</a><a href="'+docs+'">YSYX</a><a href="'+pa+'">PA</a><a class="offline-source" href="'+html.escape(url,quote=True)+'" target="_blank" rel="noopener">原网页</a></div>'
                text=re.sub(r"(<body\b[^>]*>)",lambda m:m[1]+bar,text,count=1,flags=re.I)
                if "/slides/" in urllib.parse.urlsplit(url).path:
                    text=re.sub(r"<body\b([^>]*)>",lambda m:'<body'+m[1]+' class="offline-slides">',text,count=1,flags=re.I)
                extra='<link rel="stylesheet" href="'+prefix+'/reader.css"><script defer src="'+prefix+'/reader.js"></script>'
                math=self.records.get(MATH_URL,{})
                if math.get("status")=="ok":
                    mathref=self.rewrite_ref(MATH_URL,url,current)
                    extra+='<script>window.MathJax={tex:{inlineMath:[["\\\\(","\\\\)"]],displayMath:[["\\\\[","\\\\]"]]},options:{skipHtmlTags:["script","noscript","style","textarea","pre","code"]},svg:{fontCache:"local"}};</script><script defer src="'+mathref+'"></script>'
                text=text.replace("</head>",extra+"</head>")
                before=Scan();before.feed(original)
                after=Scan();after.feed(text)
                a,b=before.result(),after.result()
                if a["text"]!=b["text"] or a["counts"]!=b["counts"]:
                    content_errors.append({"url":url,"original_counts":a["counts"],"offline_counts":b["counts"],"text_equal":a["text"]==b["text"]})
                r["title"]=a["title"]
                r["content_counts"]=a["counts"]
                pages.append({"title":a["title"],"path":current.relative_to(self.site).as_posix(),"text":a["text"],"url":url})
            current.write_text(text,encoding="utf-8")
            r["local_bytes"]=current.stat().st_size
        pages=list({p["path"]:p for p in pages}.values())
        pages.sort(key=lambda p:p["path"])
        data="var OFFLINE_PAGES="+json.dumps(pages,ensure_ascii=False).replace("</","<\\/")+";"
        (support/"search-data.js").write_text(data,encoding="utf-8")
        (support/"search.js").write_text(PORTAL_JS,encoding="utf-8")
        groups=collections.defaultdict(list)
        for p in pages:
            u=urllib.parse.urlsplit(p["url"]).path
            if "/ics-pa/" in u:
                group="PA 实验讲义"+("（英文）" if "/en/" in u else "（俄文）" if "/ru/" in u else "（中文）")
            elif u.startswith("/slides/"):
                group="站内课程课件（连续阅读版）"
            elif "/2607/" in u or u=="/docs/":
                group="YSYX v26.07"
            else:
                group="YSYX 往期课程与其他文档"
            groups[group].append(p)
        catalog="".join("<details open><summary>"+html.escape(g)+" · "+str(len(ps))+" 页</summary><ul>"+
            "".join('<li><a href="'+html.escape(p["path"],quote=True)+'">'+html.escape(p["title"])+'</a><small> '+html.escape(p["path"])+"</small></li>" for p in ps)+"</ul></details>" for g,ps in groups.items())
        landing="""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>YSYX 与 PA 离线资料</title><style>body{font:16px/1.75 system-ui,sans-serif;max-width:1100px;margin:40px auto;padding:0 24px;color:#203348;background:#fafcfe}
a{color:#145f93}h1{font-size:30px}input{font:inherit;padding:12px;width:100%;box-sizing:border-box;border:1px solid #9aaebd;border-radius:6px}
summary{cursor:pointer;font-weight:bold;font-size:20px;padding:12px 0}li{margin:7px 0}small{color:#697b89;font-size:12px}p{max-width:900px}
#results p{font-size:14px;margin:2px 0 14px}nav{display:flex;gap:24px;padding:14px 0}.note{background:#eaf3fa;border-left:4px solid #3876a3;padding:12px 16px}</style></head><body>
<h1>YSYX 与 PA 离线资料</h1><p>公开网页的本地学习副本。保留来源、原有正文和许可说明；网页会持续更新，本副本只代表下载时的版本。</p>
<nav><a href="ysyx.oscc.cc/docs/index.html">一生一芯课程主页</a><a href="ysyx.oscc.cc/docs/ics-pa/index.html">PA 实验主页</a><a href="../offline-report.md">下载与核对记录</a></nav>
<p class="note">讲义使用本地网页跳转；站内课件提供连续阅读版。站外视频、文章、云文档及服务仍需联网，完整清单在 external-links.json。</p>
<label for="search">全文搜索（支持多个关键词）</label><input id="search" type="search" placeholder="例如：差分测试、流水线、表达式求值"><p id="search-status"></p><ul id="results"></ul>
<h2>全部页面目录</h2>"""+catalog+"""<script src="_offline/search-data.js"></script><script src="_offline/search.js"></script></body></html>"""
        if (self.root/"README.md").is_file():
            landing=landing.replace("</nav>", '<a href="../README.md">资料目录与维护规则</a></nav>', 1)
        (self.site/"index.html").write_text(landing,encoding="utf-8")
        (self.root/"content-check.json").write_text(json.dumps({"checked_pages":len(pages),"mismatches":content_errors},ensure_ascii=False,indent=2),encoding="utf-8")
        (self.root/"external-links.json").write_text(json.dumps([{"url":u,"relation":r} for u,r in sorted(self.external)],ensure_ascii=False,indent=2),encoding="utf-8")
        if not (self.root/"offline-report.md").exists():
            (self.root/"offline-report.md").write_text("# 离线镜像下载与核对记录\n\n离线网页已生成，下载与引用核对结果正在写入。\n",encoding="utf-8")
        self.save(finished=True)
        return pages,content_errors

    def verify(self):
        missing=[]
        remote_embeds=[]
        link_count=0
        fragments=[]
        scans={}
        existence_cache={}
        def exists(p):
            key=str(p)
            if key not in existence_cache:
                existence_cache[key]=p.is_file()
            return existence_cache[key]
        for url,r in self.records.items():
            if r.get("status")!="ok" or not r.get("local_file"):
                continue
            p=self.root/r["local_file"]
            if not exists(p):
                missing.append({"from":url,"target":str(p),"reason":"downloaded file missing"})
                continue
            if r.get("kind")=="page":
                scan=Scan();scan.feed(p.read_text(encoding="utf-8"))
                scans[Path(os.path.abspath(p))]=scan
        portal=self.site/"index.html"
        if portal.is_file():
            portal_scan=Scan();portal_scan.feed(portal.read_text(encoding="utf-8"))
            scans[Path(os.path.abspath(portal))]=portal_scan
        content_page_count=len(scans)-1
        for p,scan in scans.items():
            for ref,relation in scan.refs+[(ref,"asset") for ref in scan.scripts]:
                if not ref or ref.startswith(("data:","mailto:","javascript:","tel:")):
                    continue
                u=urllib.parse.urlsplit(html.unescape(ref))
                if u.scheme or u.netloc:
                    if relation not in ("link","embed"):
                        remote_embeds.append({"from":p.relative_to(self.root).as_posix(),"url":ref})
                    continue
                if not u.path:
                    if u.fragment and not u.fragment.startswith("/") and urllib.parse.unquote(u.fragment) not in scan.ids:
                        fragments.append({"from":p.relative_to(self.root).as_posix(),"target":ref})
                    continue
                link_count+=1
                target=Path(os.path.abspath(p.parent/urllib.parse.unquote(u.path)))
                if not exists(target):
                    missing.append({"from":p.relative_to(self.root).as_posix(),"target":ref,"reason":"local reference missing"})
                elif u.fragment and target in scans and not u.fragment.startswith("/"):
                    anchor=urllib.parse.unquote(u.fragment)
                    if anchor not in scans[target].ids:
                        fragments.append({"from":p.relative_to(self.root).as_posix(),"target":ref})
        # CSS font/image references are essential to disconnected rendering.
        for url,r in self.records.items():
            if r.get("status")!="ok" or r.get("kind")!="css":
                continue
            p=self.root/r["local_file"]
            for _,ref in CSS_URL.findall(p.read_text(encoding="utf-8",errors="replace")):
                u=urllib.parse.urlsplit(ref)
                if u.scheme or ref.startswith(("data:","#")):
                    continue
                if not exists(Path(os.path.abspath(p.parent/urllib.parse.unquote(u.path)))):
                    missing.append({"from":p.relative_to(self.root).as_posix(),"target":ref,"reason":"CSS dependency missing"})
        self.resolve_aliases()
        failures=[r for r in self.records.values() if r.get("status")!="ok" and not r.get("resolved_to")]
        aliases=[{"url":r["url"],"resolved_to":r["resolved_to"]} for r in self.records.values() if r.get("resolved_to")]
        content=json.loads((self.root/"content-check.json").read_text(encoding="utf-8"))
        report={"verified_utc":now(),"downloaded_pages":content_page_count,"page_route_count":len(self.routes),
                "route_coverage":{"discovered":len(self.routes),"downloaded":sum(self.records.get(u,{}).get("status")=="ok" for u in self.routes),
                                  "not_downloaded":[u for u in sorted(self.routes) if self.records.get(u,{}).get("status")!="ok"]},
                "downloaded_files":sum(r.get("status")=="ok" for r in self.records.values()),"resolved_navigation_aliases":aliases,
                "download_bytes":self.total_bytes,"checked_local_references":link_count,
                "content_preservation":content,"missing_local_files":missing,
                "remote_embedded_assets":remote_embeds,"unresolved_source_fragments":fragments,"download_failures":failures}
        report["local_reference_check_passed"]=not missing
        report["content_preservation_passed"]=not content["mismatches"]
        (self.root/"verification.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
        self.write_report(report)
        print(json.dumps({k:v for k,v in report.items() if k not in ("download_failures","missing_local_files","remote_embedded_assets","unresolved_source_fragments","content_preservation","resolved_navigation_aliases")},ensure_ascii=False,indent=2),flush=True)
        print(json.dumps({"failures":len(failures),"missing_local_files":len(missing),"remote_embedded_assets":len(remote_embeds),"unresolved_source_fragments":len(fragments)},ensure_ascii=False),flush=True)
        return report

    def write_report(self,r):
        kinds=collections.Counter(x.get("kind") for x in self.records.values() if x.get("status")=="ok")
        failures=r["download_failures"]
        ownership="本文件由 mirror_docs.py 生成。"
        if (self.root/"README.md").is_file():
            ownership+="目录结构与维护规则见 [README](README.md)。"
        text="\n".join(["# 离线镜像下载与核对记录","",ownership,"",
            "来源：[一生一芯官方讲义](https://ysyx.oscc.cc/docs/)；[PA 实验讲义](https://ysyx.oscc.cc/docs/ics-pa/)。",
            "","下载与核对时间（UTC）："+r["verified_utc"]+"。","",
            "## 本地阅读","","直接用浏览器打开 [离线首页](site/index.html)。无需启动服务器，目录、全文搜索、章节链接、代码块、表格、折叠块、图片与字体均使用本地文件。",
            "","- [一生一芯课程主页](site/ysyx.oscc.cc/docs/index.html)",
            "- [PA 实验主页](site/ysyx.oscc.cc/docs/ics-pa/index.html)",
            "","## 抓取范围与保留方式","",
            "从两个入口、站点公开路由表及页面链接递归发现 docs/ 内公开讲义，包含站点列出的往期版本与语言版本；同时抓取链接到的站内 slides/ 课件及正文引用的图片、样式、字体和附件。",
            "","保留服务端输出的完整正文，不通过摘要重写。禁用原站 SPA 路由与统计脚本，使链接能在 file:// 下直接跳转；站内课件改为连续阅读版，所有幻灯片与分步内容展开，公式使用随附 MathJax 离线渲染。",
            "","站外视频、网站文章、云文档、搜索、问卷和账号服务保留原链接，不递归复制第三方网站；清单见 external-links.json。未访问登录内容，也未绕过访问限制。",
            "","## 文件索引","",
            "| 路径 | 内容 |","| --- | --- |",
            "| site/ | 可直接浏览的离线网页与资源 |",
            "| originals/ | 下载时的原始 HTML、CSS 和路由脚本，用于来源比对与重新生成 |",
            "| manifest.json | 唯一下载清单：URL、时间、HTTP 状态、来源关系、字节数与文件位置 |",
            "| verification.json | 本地链接、依赖、正文保留及未获取资源的核对结果 |",
            "| content-check.json | 原网页与离线网页正文及结构计数比较 |",
            "| external-links.json | 保留为在线访问的站外链接 |",
            "| progress.json | 下载断点与当前进度 |",
            "","## 本次结果","",
            "- 官网公开路由表："+str(r["route_coverage"]["discovered"])+" 个地址，已取得 "+str(r["route_coverage"]["downloaded"])+" 个。",
            "- 页面："+str(r["downloaded_pages"])+"；样式："+str(kinds["css"])+"；成功下载文件："+str(r["downloaded_files"])+"。",
            "- 原始下载总量："+str(round(r["download_bytes"]/1024**2,2))+" MiB。",
            "- 已解析的导航路径或省略扩展名链接："+str(len(r["resolved_navigation_aliases"]))+"，原请求与对应页面记录在 verification.json。",
            "- 检查本地引用："+str(r["checked_local_references"])+"；缺失本地文件："+str(len(r["missing_local_files"]))+"。",
            "- 正文或结构比较差异："+str(len(r["content_preservation"]["mismatches"]))+"。",
            "- 未成功获取："+str(len(failures))+"；仍引用在线图片或样式："+str(len(r["remote_embedded_assets"]))+"。",
            "- 原站锚点无法对应："+str(len(r["unresolved_source_fragments"]))+"，详情见 verification.json。",
            "","## 更新与复核","",
            "工具见 [mirror_docs.py](../tools/mirror_docs.py)，使用方法见 [工具说明](../tools/README.md)。默认复用已下载内容并续传；刷新时显式使用 --refresh。站点会更新，离线副本不会自动同步。",
            "","## 来源与许可","",
            "本副本用于本地学习，保留原页面的作者、来源链接、许可声明和引用。PA 首页声明采用 CC BY-NC-SA 3.0 中国大陆许可；其他页面与第三方素材以各自原始声明为准。MathJax 来自 mathjax@3.2.2 官方 npm 包，采用 Apache-2.0 许可。",
            "","本次核对覆盖下载和离线文件，不代表课程实验代码已经实现或通过功能验证。",""])
        (self.root/"offline-report.md").write_text(text,encoding="utf-8")

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,default=Path(__file__).resolve().parent.parent/"docs")
    parser.add_argument("--refresh",action="store_true")
    parser.add_argument("--retry-failed",action="store_true")
    parser.add_argument("--verify-only",action="store_true")
    parser.add_argument("--render-only",action="store_true")
    parser.add_argument("--workers",type=int,default=3)
    args=parser.parse_args()
    mirror=Mirror(args.output,args.refresh,max(1,min(args.workers,4)),args.retry_failed)
    if not args.verify_only:
        if not args.render_only:
            mirror.crawl()
        else:
            for record in list(mirror.records.values()):
                mirror.inspect(record)
        mirror.render()
    report=mirror.verify()
    return 1 if report["missing_local_files"] or report["content_preservation"]["mismatches"] else 0

if __name__=="__main__":
    raise SystemExit(main())
