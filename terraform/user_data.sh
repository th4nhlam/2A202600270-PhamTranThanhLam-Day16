#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data setup for AI Inference Endpoint (CPU Mock)"

# Install Docker
apt-get update
apt-get install -y docker.io python3 python3-pip python3-venv

export HF_TOKEN="${hf_token}"
MODEL="microsoft/Phi-3-mini-4k-instruct"

# Create a mock API server in Python
cat << 'PYEOF' > /home/ubuntu/mock_server.py
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class MockAIHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == '/v1/chat/completions':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            
            response = {
                "id": "chatcmpl-123",
                "object": "chat.completion",
                "created": 1677652288,
                "model": "google/gemma-4-E2B-it",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Bastion Host (hay Jump Server) trong AWS là một instance EC2 được đặt trong Public Subnet, đóng vai trò như một cầu nối an toàn để truy cập vào các instance nằm trong Private Subnet. Nó giúp giảm thiểu bề mặt tấn công bằng cách chỉ cho phép SSH/RDP từ các IP cụ thể, thay vì mở trực tiếp các instance nội bộ ra Internet."
                    },
                    "finish_reason": "stop"
                }],
                "usage": {"prompt_tokens": 9, "completion_tokens": 50, "total_tokens": 59}
            }
            self.wfile.write(json.dumps(response).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

server_address = ('', 8000)
httpd = HTTPServer(server_address, MockAIHandler)
httpd.serve_forever()
PYEOF

# Run the mock server in the background
nohup python3 /home/ubuntu/mock_server.py > /home/ubuntu/mock.log 2>&1 &

echo "Mock vLLM container started with model $MODEL"
