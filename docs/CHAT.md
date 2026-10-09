# Chat and API access

The server binds to `127.0.0.1` by default so it is not exposed to the network.

## Browser chat

Open [http://127.0.0.1:8096](http://127.0.0.1:8096) on the machine running the container. This is llama.cpp's built-in chat interface.

## OpenAI-compatible API

Check the loaded model:

```bash
curl --fail-with-body http://127.0.0.1:8096/v1/models
```

Send a chat request:

```bash
curl --fail-with-body http://127.0.0.1:8096/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "messages": [
      {"role": "user", "content": "こんにちは。自己紹介してください。"}
    ],
    "max_tokens": 256
  }'
```

OpenAI-compatible clients can use `http://127.0.0.1:8096/v1` as their base URL. The local server does not require a real API key; if a client requires a value, use a non-secret placeholder such as `local`.

## Access from another computer

Keep the server bound to localhost and create an SSH tunnel from the client computer:

```bash
ssh -L 8096:127.0.0.1:8096 USER@SERVER_IP
```

Then open [http://127.0.0.1:8096](http://127.0.0.1:8096) on the client computer. Keep the SSH session open while chatting.

If local port 8096 is already in use, choose another local port without changing the server:

```bash
ssh -L 18096:127.0.0.1:8096 USER@SERVER_IP
```

Then open `http://127.0.0.1:18096`.
