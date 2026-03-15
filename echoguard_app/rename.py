import os
import shutil

# Step 1: Copy logo
source_logo = r'C:\Users\Arijeet\.gemini\antigravity\brain\de5c6ab6-76f7-4fab-95f0-62359f3721e1\media__1773528579878.png'
dest_dir = r'd:\echo guard\echoguard_app\assets'
dest_logo = os.path.join(dest_dir, 'logo.png')

if not os.path.exists(dest_dir):
    os.makedirs(dest_dir)

shutil.copy(source_logo, dest_logo)

# Step 2: Replace EchoGuard with Veritas
replacements = [
    ("EchoGuard", "Veritas")
]

directories = [r"d:\echo guard\echoguard_app\lib", r"d:\echo guard\echoguard_app\android\app\src\main"]

for directory in directories:
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart") or file.endswith(".xml"):
                path = os.path.join(root, file)
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        content = f.read()
                    
                    new_content = content
                    for old, new in replacements:
                        new_content = new_content.replace(old, new)
                    
                    if new_content != content:
                        with open(path, "w", encoding="utf-8") as f:
                            f.write(new_content)
                        print(f"Updated {path}")
                except Exception as e:
                    pass

print("Done renaming!")
