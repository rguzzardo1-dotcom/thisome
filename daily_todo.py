"""Build a fresh Microsoft To Do list each morning from unread mail, today's
calendar, and recent Teams chats. Uses delegated auth via MSAL device-code
flow; first run prompts in the console, after that the cached refresh token
keeps subsequent runs silent (suitable for Task Scheduler).
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
from dotenv import load_dotenv
from msal import PublicClientApplication, SerializableTokenCache

load_dotenv()

CLIENT_ID = os.getenv("CLIENT_ID")
TENANT_ID = os.getenv("TENANT_ID", "common")
CACHE_PATH = Path(os.getenv("TOKEN_CACHE", str(Path.home() / ".thisome_cache.bin")))

if not CLIENT_ID:
    sys.exit("CLIENT_ID is required (see .env.example)")

AUTHORITY = f"https://login.microsoftonline.com/{TENANT_ID}"
SCOPES = [
    "Mail.Read",
    "Calendars.Read",
    "Chat.Read",
    "Tasks.ReadWrite",
    "User.Read",
]

PRIORITY_NAMES = ["Bryan", "Tyler", "Luke", "Tim"]
GRAPH = "https://graph.microsoft.com/v1.0"
LIST_NAME = "Daily Tasks"


def get_token() -> str:
    cache = SerializableTokenCache()
    if CACHE_PATH.exists():
        cache.deserialize(CACHE_PATH.read_text())

    app = PublicClientApplication(CLIENT_ID, authority=AUTHORITY, token_cache=cache)

    result = None
    accounts = app.get_accounts()
    if accounts:
        result = app.acquire_token_silent(SCOPES, account=accounts[0])

    if not result:
        flow = app.initiate_device_flow(scopes=SCOPES)
        if "user_code" not in flow:
            sys.exit(f"Device flow init failed: {flow}")
        print(flow["message"], flush=True)
        result = app.acquire_token_by_device_flow(flow)

    if "access_token" not in result:
        sys.exit(f"Auth failed: {result.get('error_description', result)}")

    if cache.has_state_changed:
        CACHE_PATH.write_text(cache.serialize())
        try:
            os.chmod(CACHE_PATH, 0o600)
        except OSError:
            pass

    return result["access_token"]


def graph_get(session: requests.Session, path: str, **params):
    res = session.get(f"{GRAPH}{path}", params=params or None, timeout=30)
    res.raise_for_status()
    return res.json()


def get_emails(session):
    data = graph_get(
        session,
        "/me/messages",
        **{"$top": 30, "$filter": "isRead eq false", "$select": "subject,from"},
    )
    priority, normal = [], []
    for mail in data.get("value", []):
        sender = mail.get("from", {}).get("emailAddress", {}).get("name", "Unknown")
        item = {"subject": mail.get("subject", "(no subject)"), "from": sender}
        if any(name.lower() in sender.lower() for name in PRIORITY_NAMES):
            priority.append(item)
        else:
            normal.append(item)
    return priority, normal


def get_calendar(session):
    now = datetime.now(timezone.utc)
    end = now + timedelta(days=1)
    data = graph_get(
        session,
        "/me/calendarView",
        startDateTime=now.isoformat(),
        endDateTime=end.isoformat(),
    )
    return [
        {"time": e["start"]["dateTime"], "subject": e.get("subject", "(no subject)")}
        for e in data.get("value", [])
    ]


_HTML_TAG = re.compile(r"<[^>]+>")


def get_teams(session):
    chats = graph_get(session, "/me/chats", **{"$top": 10}).get("value", [])
    out = []
    for chat in chats:
        try:
            msgs = graph_get(
                session, f"/me/chats/{chat['id']}/messages", **{"$top": 3}
            ).get("value", [])
        except requests.HTTPError:
            continue
        for m in msgs:
            content = m.get("body", {}).get("content", "")
            text = _HTML_TAG.sub("", content).strip()
            if text:
                out.append(text)
    return out[:10]


def get_or_create_list(session) -> str:
    lists = graph_get(session, "/me/todo/lists").get("value", [])
    for lst in lists:
        if lst["displayName"] == LIST_NAME:
            return lst["id"]
    res = session.post(
        f"{GRAPH}/me/todo/lists", json={"displayName": LIST_NAME}, timeout=30
    )
    res.raise_for_status()
    return res.json()["id"]


def clear_tasks(session, list_id):
    tasks = graph_get(session, f"/me/todo/lists/{list_id}/tasks").get("value", [])
    for t in tasks:
        session.delete(
            f"{GRAPH}/me/todo/lists/{list_id}/tasks/{t['id']}", timeout=30
        )


def create_task(session, list_id, title, body_text):
    session.post(
        f"{GRAPH}/me/todo/lists/{list_id}/tasks",
        json={
            "title": title,
            "body": {"content": body_text, "contentType": "text"},
        },
        timeout=30,
    ).raise_for_status()


def push_tasks(session, priority_emails, normal_emails, meetings, teams):
    list_id = get_or_create_list(session)
    clear_tasks(session, list_id)

    for e in priority_emails:
        create_task(session, list_id, f"PRIORITY: {e['subject']}", f"From: {e['from']}")
    for e in normal_emails:
        create_task(session, list_id, f"Email: {e['subject']}", f"From: {e['from']}")
    for m in meetings:
        create_task(session, list_id, f"Meeting: {m['subject']}", f"Time: {m['time']}")
    for t in teams:
        create_task(session, list_id, "Teams Follow-up", t[:500])


def main():
    print("Running daily task builder...")
    token = get_token()
    session = requests.Session()
    session.headers.update(
        {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    )

    priority_emails, normal_emails = get_emails(session)
    meetings = get_calendar(session)
    teams = get_teams(session)

    push_tasks(session, priority_emails, normal_emails, meetings, teams)

    summary = {
        "priority_emails": len(priority_emails),
        "normal_emails": len(normal_emails),
        "meetings": len(meetings),
        "teams_messages": len(teams),
    }
    print("Done:", json.dumps(summary))


if __name__ == "__main__":
    main()
