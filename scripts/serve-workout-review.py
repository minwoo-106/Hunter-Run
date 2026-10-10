"""로컬 검토 전용. 체크 내용은 검토 폴더에만 저장한다."""
import argparse, json
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
p=argparse.ArgumentParser();p.add_argument('--directory',type=Path,required=True);p.add_argument('--port',type=int,default=8797);a=p.parse_args()
root=a.directory.resolve(); expected={c['key']:c['sha256'] for c in json.loads((root/'voice-review.json').read_text(encoding='utf-8'))['clips']}
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(root),**kwargs)
    def do_POST(self):
        if self.path!='/feedback':self.send_error(404);return
        size=int(self.headers.get('Content-Length','0'))
        if not 0<size<100000:self.send_error(400);return
        try:
            data=json.loads(self.rfile.read(size))
            assert {x['key']:x['sha256'] for x in data['entries']}==expected
            assert all(x['status'] in ['ok','different','other','unreviewed'] and isinstance(x['note'],str) for x in data['entries'])
            (root/'user-feedback.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        except (ValueError,KeyError,AssertionError,TypeError):self.send_error(400);return
        self.send_response(204);self.end_headers()
    def log_message(self,*args):pass
print(f'검토 페이지: http://127.0.0.1:{a.port}/',flush=True)
ThreadingHTTPServer(('127.0.0.1',a.port),Handler).serve_forever()
