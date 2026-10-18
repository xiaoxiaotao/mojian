#!/usr/bin/env python3
"""Publish a data-only template/card to your own hub. Never prints credentials."""
import argparse,json,urllib.request,urllib.parse,ipaddress
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('kind',choices=['templates','plugins']);p.add_argument('file',type=Path);p.add_argument('--url',default='http://127.0.0.1:8788');p.add_argument('--credentials',type=Path,default=Path('data/community/credentials.json'));args=p.parse_args()
if len(args.file.read_bytes())>16384:raise SystemExit('File exceeds 16KB')
parsed=urllib.parse.urlsplit(args.url)
local=parsed.hostname in ('localhost','127.0.0.1')
try:
 ip=ipaddress.ip_address(parsed.hostname or '')
 local=local or any(ip in ipaddress.ip_network(cidr) for cidr in ('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16'))
except ValueError:pass
if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.scheme not in ('http','https') or (parsed.scheme=='http' and not local):raise SystemExit('Use HTTPS for remote hubs; credentials must not appear in the URL')
class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs):return None
body=json.loads(args.file.read_text());tokens=json.loads(args.credentials.read_text())
r=urllib.request.Request(args.url.rstrip('/')+'/v1/'+args.kind,data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+tokens['owner'],'Content-Type':'application/json'})
try:
 with urllib.request.build_opener(NoRedirect()).open(r,timeout=15) as response:
  result=json.load(response)
 print('Published:',result.get('id',''))
except Exception:raise SystemExit('Publish failed. Check schema, connection and credentials.')
