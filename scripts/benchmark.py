#!/usr/bin/env python3
"""Measure llama.cpp prompt and decode timing via its OpenAI-compatible API."""
from __future__ import annotations
import argparse, json, time, urllib.request
parser=argparse.ArgumentParser()
parser.add_argument('--url',default='http://127.0.0.1:8096/v1/chat/completions')
parser.add_argument('--prompt-chars',type=int,default=4096)
parser.add_argument('--max-tokens',type=int,default=128)
a=parser.parse_args()
seed='Gemma 4 A4B benchmark. この文章はプロンプト処理速度を測定するための入力です。 '
prompt=(seed*((a.prompt_chars*4)//len(seed)+1))[:a.prompt_chars*4]+'\n上の文章を一文で日本語要約してください。'
payload={'model':'gemma4-a4b-qat-mtp','messages':[{'role':'user','content':prompt}], 'temperature':0, 'max_tokens':a.max_tokens, 'stream':False, 'chat_template_kwargs':{'enable_thinking':False}}
request=urllib.request.Request(a.url,data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
started=time.perf_counter()
with urllib.request.urlopen(request, timeout=3600) as response:
    result=json.loads(response.read())
result['_wall_s']=round(time.perf_counter()-started,3)
print(json.dumps(result,ensure_ascii=False,indent=2))
