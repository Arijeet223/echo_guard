import os

replacements = [
    # Grey to Black
    ("Colors.grey", "Colors.black87"),
    ("Colors.black87.shade300", "Colors.black54"), # Catch side effects
    ("Colors.black87.shade400", "Colors.black54"),
    ("Colors.black87.shade500", "Colors.black54"),
    ("Colors.black87.shade600", "Colors.black87"),
    ("Colors.black87.shade700", "Colors.black87"),
    # Fix the side effects from naïve replacement
]

directory = r"d:\echo guard\echoguard_app\lib"

count = 0
for root, dirs, files in os.walk(directory):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            
            # Simple replace mechanism for Colors.grey -> Colors.black87
            # But wait, Colors.grey.shade300 becomes Colors.black87.shade300 which is invalid!
            # Let's fix this properly.
            pass

def clean_colors(text):
    text = text.replace("Colors.grey.shade300", "Colors.black54")
    text = text.replace("Colors.grey.shade400", "Colors.black54")
    text = text.replace("Colors.grey.shade500", "Colors.black54")
    text = text.replace("Colors.grey.shade600", "Colors.black87")
    text = text.replace("Colors.grey.shade700", "Colors.black87")
    text = text.replace("Colors.grey", "Colors.black87")
    return text

for root, dirs, files in os.walk(directory):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            
            new_content = clean_colors(content)
            
            if new_content != content:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new_content)
                count += 1
                print(f"Updated grey colors in {file}")

print(f"Total files updated: {count}")
