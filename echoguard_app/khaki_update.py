import os

# Phase 1: Existing Khaki -> Camel (Darken it)
replacements_1 = [
    ("0xFFD7C9B8", "0xFFB2967D"), # Existing Khaki -> Camel
]

# Phase 2: Whites -> Khaki
replacements_2 = [
    ("Colors.white", "Color(0xFFD7C9B8)"),
    ("0xFFFFFFFF", "0xFFD7C9B8"),
    ("0xFFFDFBF7", "0xFFD7C9B8"), # Off-white background
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
            # Pass 1
            for old, new in replacements_1:
                new_content = new_content.replace(old, new)
            
            # Pass 2
            for old, new in replacements_2:
                new_content = new_content.replace(old, new)
            
            if new_content != content:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new_content)
                count += 1
                print(f"Updated colors in {file}")

print(f"Total files updated: {count}")
