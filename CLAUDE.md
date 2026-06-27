# FairWind Claude Code Project Rules

Read this file at the start of every session before touching any file or Drive operation.

---

## WHO OWNS THIS PROJECT

Rex Guzzardo, Field Engineer, FairWind Lift Division.
Rex is always the final gatekeeper on every file, delete, and write operation.
Never purchase, delete, or change security settings without explicit confirmation in that message.

---

## DRIVE FILE PLACEMENT RULES (NON-NEGOTIABLE)

### Never write to Drive root.
Drive root ID is 0ACxCa1ZVjB_GUk9PVA.
Never use this as a parentId under any circumstances.
If you do not know which folder a file belongs in, stop and ask Rex.

### Approved folder IDs for FairWind Drive.

| Folder | ID |
|---|---|
| Master Register | 1xz59o-tcMs0X69Kv_fRgTWtGH0fWt5N_ |
| 10.0 HLWI Final Deliverables | 16xQu7ryvoNDBFrl5KTfQKWncFqkK0Hec |
| 4.0 Manuals | 1mWaCH1j_aeNPsBGEokr6rYA3HhoAysrO |
| 99.0 AI and Brand Kit | 14RduKARh6K5JACpUyIbol4O1aOLoHQxT |
| Rex GE WDI | 1HJJRF-HLViVQk6Jxv3NUdROnL2aBeTYg |
| Claude Trash | 1KxKrHdgBLRYTQ0wzKat77iojuIg0eoo8 |

### One copy per session maximum.
Check for existing files before creating new ones.
If a file exists, update it. Do not create a second copy.

### Dry run required before any batch file creation.
If you are about to create more than one file in a loop, print the file names and destination folder IDs first. Wait for Rex to approve before executing the actual writes.

### Version stamp format for register files.
FWI_Master_Register_YYYY-MM-DD
No other naming convention. No "v2", "FINAL2", or "new."

---

## MASTER REGISTER REFERENCE

| Item | Value |
|---|---|
| Live master file | FWI_Master_Register_CORRECTED_2026-06-27 |
| Live master file ID | 1nKMbn38-DqNYBTSwVMlTn16JJmrVHEf0_JjiO1WJIvk |
| Original preserved backup | FWI_Master_Register_257_FINAL |
| Backup file ID | 1hc5Nud73wIAHXmUdP9KAcoeI2EbScz3tgcnXsQf2Apo |

---

## DOCUMENT RULES

1. Never use em dashes or en dashes in any document you create.
2. Never guess on safety instructions, torque values, weights, or dimensions. Flag the gap and stop.
3. Never invent a part number, torque value, weight, or dimension. Only use values from source documents.
4. Never plagiarize. Reword source content in your own words without losing technical meaning.
5. FairWind document first page must always match HLWI 1017 Rotor Tie Down gold standard format.

---

## END OF SESSION REPORT (REQUIRED)

Before closing any Claude Code session that touched Drive, output a report in this format:

Files created:
- [filename] in [folder name] (folder ID: [id])

Files modified:
- [filename] in [folder name] (folder ID: [id])

Files moved:
- [filename] from [source folder] to [destination folder]

Nothing deleted without Rex's explicit instruction in that session.

---

## IF SOMETHING GOES WRONG

Stop immediately. Do not try to self-correct by creating more files.
Report to Rex exactly what happened and what state the files are in.
Wait for instructions before touching anything else.
