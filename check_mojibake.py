import os
import glob
import re

files = glob.glob('*.html') + glob.glob('*.css') + glob.glob('*.js')
issues = []

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        lines = file.readlines()
        for i, line in enumerate(lines):
            # Check for Â, Ã, â, etc. which are typical Windows-1252 to UTF-8 mojibake
            if re.search(r'[ÂÃâ]', line):
                issues.append(f"{f}:{i+1}: {line.strip()}")

for issue in issues:
    print(issue)

if not issues:
    print("No more mojibake found in HTML, CSS, or JS!")
