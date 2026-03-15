import os

replacements = [
    ("0xFF1D468B", "0xFF4A342A"), # Dark Blue -> Espresso
    ("0xFFD4A373", "0xFFD7C9B8"), # Gold/Light -> Khaki
    ("0xFF2196F3", "0xFFD7C9B8"), # Generic Blue -> Khaki
    ("0xFF42A5F5", "0xFFD7C9B8"), # Generic Light Blue -> Khaki
]

directory = r"d:\echo guard\echoguard_app\lib"

count = 0
for root, dirs, files in os.walk(directory):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            
            new_content = content
            for old, new in replacements:
                new_content = new_content.replace(old, new)
            
            if new_content != content:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new_content)
                count += 1
                print(f"Updated colors in {file}")

print(f"Total files updated: {count}")
