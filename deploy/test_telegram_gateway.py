#!/usr/bin/env python3
"""Quick Telegram Gateway + bot token check (run on VPS)."""
import os
import socket
import sys

sys.path.insert(0, "/root/backendGreen")
os.chdir("/root/backendGreen")

import httpx
from config import TELEGRAM_BOT_TOKEN, TELEGRAM_GATEWAY_TOKEN

phone = "+992986505650"
print("GATEWAY_TOKEN set:", bool(TELEGRAM_GATEWAY_TOKEN))
print("BOT_TOKEN set:", bool(TELEGRAM_BOT_TOKEN))

# DNS / connectivity
for host in ("gatewayapi.telegram.org", "api.telegram.org"):
    try:
        infos = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
        addrs = sorted({i[4][0] for i in infos})
        print(f"DNS {host}:", addrs[:6])
    except Exception as e:
        print(f"DNS {host} ERR:", e)

if TELEGRAM_BOT_TOKEN:
    try:
        r = httpx.get(
            f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getMe",
            timeout=10,
        )
        print("bot getMe:", r.status_code, r.text[:200])
    except Exception as e:
        print("bot getMe ERR:", type(e).__name__, e)

if TELEGRAM_GATEWAY_TOKEN:
    headers = {
        "Authorization": f"Bearer {TELEGRAM_GATEWAY_TOKEN}",
        "Content-Type": "application/json",
    }
    payload = {"phone_number": phone}
    for label, kwargs in (
        ("gateway default", {}),
        ("gateway force IPv4", {"local_address": "0.0.0.0"}),
    ):
        try:
            transport = httpx.HTTPTransport(local_address=kwargs.get("local_address")) if kwargs.get("local_address") else None
            with httpx.Client(timeout=20, transport=transport) as client:
                r = client.post(
                    "https://gatewayapi.telegram.org/checkSendAbility",
                    json=payload,
                    headers=headers,
                )
                print(f"{label}:", r.status_code, r.text[:400])
                if r.status_code == 200:
                    data = r.json()
                    if data.get("ok"):
                        rid = data["result"]["request_id"]
                        r2 = client.post(
                            "https://gatewayapi.telegram.org/sendVerificationMessage",
                            json={
                                "phone_number": phone,
                                "code_length": 4,
                                "ttl": 300,
                                "request_id": rid,
                            },
                            headers=headers,
                        )
                        print(f"{label} send:", r2.status_code, r2.text[:500])
        except Exception as e:
            print(f"{label} ERR:", type(e).__name__, e)

try:
    from services.telegram_gateway import send_verification_message, TelegramGatewayError

    s = send_verification_message(phone)
    print("send_verification_message OK:", s)
except TelegramGatewayError as e:
    print("send_verification_message GW ERR:", e, getattr(e, "description", ""))
except Exception as e:
    print("send_verification_message ERR:", type(e).__name__, e)
