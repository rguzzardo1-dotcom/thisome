# thisome -- daily To Do + weekly desktop cleanup

Two scripts that run on your Windows PC:

- **`daily_todo.py`** -- every morning, rebuilds your **Daily Tasks** list in
  Microsoft To Do from unread Outlook mail, today's calendar, and recent Teams
  chats.
- **`desktop_organize.py`** -- once a week, sweeps loose desktop files into
  `Desktop\REX CHECK\<bucket>` after showing you a confirmation dialog.

---

## Quick setup (the easy path)

1. **Install Python 3.11 or newer** from <https://www.python.org/downloads/>
   (check "Add python.exe to PATH" in the installer).
2. **Clone or download this repo** to a stable location, e.g.
   `C:\Tools\thisome`.
3. Open **PowerShell** in that folder and run:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\scripts\install.ps1
   ```
   The installer will:
   - Create a virtualenv and install dependencies.
   - Prompt you for your Azure `CLIENT_ID` / `TENANT_ID` and write `.env`.
   - Run `daily_todo.py` once so you can complete the device-code sign-in.
   - Prompt for your Windows password so the daily task can run while you're
     signed out (the password is handed straight to Task Scheduler and not
     stored anywhere by this project).
   - Register two Windows scheduled tasks (daily 2:00 AM, weekly Fri 4:00 PM).

That's it. You can edit the times later in **Task Scheduler** under
`\thisome\`.

---

## Azure app registration (one-time, ~5 minutes)

You need a Microsoft Entra ID (Azure AD) **app registration** to give the
script permission to read your mail / chats / calendar and write to To Do.

1. Go to <https://entra.microsoft.com> -> **Identity** -> **Applications** ->
   **App registrations** -> **+ New registration**.
2. **Name:** `thisome daily todo` (any name is fine).
3. **Supported account types:** pick whichever matches your account. For a
   personal Microsoft account use *"Accounts in any organizational directory
   and personal Microsoft accounts"*.
4. **Redirect URI:** leave blank.
5. Click **Register**. Copy the **Application (client) ID** and the
   **Directory (tenant) ID** from the Overview page -- you'll paste these
   into `.env`.
6. In the left nav: **Authentication** -> **Advanced settings** -> set
   **"Allow public client flows"** to **Yes** -> Save. (This is what enables
   device-code sign-in.)
7. In the left nav: **API permissions** -> **+ Add a permission** ->
   **Microsoft Graph** -> **Delegated permissions**. Add each of these:
   - `Mail.Read`
   - `Calendars.Read`
   - `Chat.Read`
   - `Tasks.ReadWrite`
   - `User.Read`
   - `offline_access` (lets the token cache refresh silently)
8. Click **Grant admin consent** if you're on a work account and that button
   is available -- otherwise you'll just be prompted to consent during your
   first sign-in.

When the installer asks for `CLIENT_ID` and `TENANT_ID`, paste the values
from step 5.

---

## What gets created on your PC

```
C:\Tools\thisome\
  daily_todo.py
  desktop_organize.py
  skip.txt              <- list names here to keep them off the organizer
  .env                  <- your CLIENT_ID / TENANT_ID (gitignored)
  .thisome_cache.bin    <- MSAL refresh token cache (don't share)
  .venv\                <- isolated Python env
```

Scheduled tasks created under `\thisome\` in Task Scheduler:

| Task              | When            | Runs as                       | What it runs                       |
| ----------------- | --------------- | ----------------------------- | ---------------------------------- |
| `Daily To Do`     | Daily 2:00 AM   | You (signed in or not)        | `daily_todo.py`                    |
| `Weekly Cleanup`  | Fri 4:00 PM     | You (only when signed in)     | `desktop_organize.py` (shows Tk)   |

---

## Day-to-day use

- **Daily list:** Open the Microsoft To Do app -- the **Daily Tasks** list is
  rebuilt fresh each morning. Items are prefixed `PRIORITY:`, `Email:`,
  `Meeting:`, or `Teams Follow-up`.
- **Weekly cleanup:** Monday morning a window pops up listing every move it
  wants to make. Click **Move files** to proceed or **Cancel** to skip this
  week. Nothing moves without your click.
- **Protecting things:** add the file or folder name to `skip.txt` (one per
  line). Useful for anything you've "colored" or otherwise flagged. The three
  big work folders (`Main Page - 03. MCE Operations`, `2.0 Work Instructions`,
  `SharePoint WDI Final Link`) are already hard-coded to be skipped.

---

## Running manually

```powershell
# From the project folder, with the venv active:
.\.venv\Scripts\Activate.ps1

python daily_todo.py            # rebuild today's To Do list
python desktop_organize.py --dry-run   # preview cleanup, move nothing
python desktop_organize.py      # cleanup with the confirmation dialog
```

---

## Troubleshooting

- **"CLIENT_ID is required"** -- the `.env` file is missing or empty. Re-run
  `.\scripts\install.ps1`, or edit `.env` by hand.
- **Device-code prompt appears every day** -- the token cache file is being
  deleted between runs. Check that `.thisome_cache.bin` survives reboots and
  that the scheduled task runs as your user, not SYSTEM.
- **Daily task fails after a Windows password change** -- Task Scheduler holds
  the old password. Re-run `.\scripts\install.ps1` to refresh it.
- **Teams messages empty** -- some tenants block delegated `Chat.Read` for
  unmanaged apps. Ask IT to grant admin consent for the app registration.
- **Confirmation dialog never appears for weekly cleanup** -- the task must
  run with *"Run only when user is logged on"* (the installer sets this).
  Otherwise Tk can't show a window.
