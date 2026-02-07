import os
import urllib.request
import ssl

# Bypass SSL verification for legacy java compatibility if needed, though python usually fine.
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

target_dir = "source/net/filebot/resources"
base_url = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons"

icons = {
    "action.load": "folder-open",
    "action.clear": "rotate-ccw",
    "package.extract": "package-open",
    "tree.open": "folder-open",
    "tree.closed": "folder",
    "file.generic": "file",
    "action.match": "shuffle",
    "action.match.strict": "wand",
    "action.rename": "pencil",
    "action.list": "list",
    "action.up": "arrow-up",
    "action.down": "arrow-down",
    "dialog.cancel": "circle-x",
    "action.fetch": "cloud-download",
    "action.settings": "settings",
    "action.report": "history",
    "action.script": "scroll",
    "window.icon16": "app-window",
    "panel.analyze": "search",
    "panel.episodelist": "list-video",
    "panel.list": "list",
    "panel.rename": "pencil",
    "panel.sfv": "shield-check",
    "panel.subtitle": "languages",
    "action.find": "search",
    "action.save": "save",
    "action.user": "user",
    "action.export": "list-ordered",
    "rename.action.copy": "copy",
    "status.warning": "triangle-alert",
    "dialog.continue": "check",
    "subtitle.exact.upload": "upload",
    "subtitle.exact.download": "download",
    "action.revert": "undo-2",
    "edit.clear": "circle-x"
}

if not os.path.exists(target_dir):
    os.makedirs(target_dir)

for key, val in icons.items():
    url = f"{base_url}/{val}.svg"
    dest = f"{target_dir}/{key}.svg"
    
    print(f"Downloading {val} -> {key}.svg ...")
    try:
        with urllib.request.urlopen(url, context=ctx, timeout=10) as response:
            content = response.read().decode('utf-8')
            
            # Inject light grey color
            content = content.replace('<svg', '<svg color="#E0E0E0"')
            
            with open(dest, 'w') as f:
                f.write(content)
                
    except Exception as e:
        print(f"Failed to download {key}: {e}")

print("Fetch complete.")
