import os
import subprocess

def run_build():
    print("Running flutter build...")
    result = subprocess.run(["flutter", "build", "apk", "--release"], capture_output=True, text=True, errors="replace", shell=True)
    
    print("\n\n=== STDOUT TAIL ===")
    print(result.stdout[-2500:])
    
    print("\n\n=== STDERR TAIL ===")
    print(result.stderr[-2500:])
    
if __name__ == "__main__":
    run_build()
