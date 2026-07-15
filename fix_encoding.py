import os
import glob

files = glob.glob('*.html')
replacements = {
    'â‚¹': '₹',
    'â† ': '←',
    'â˜…': '★',
    'dÃ©cor': 'décor',
    '”“': '—',
    'â†’': '→',
    'â€”': '—',
    'â€œ': '“',
    'â€ ': '”',
    'Â©': '©',
    'CÃ©leste': 'Céleste',
    'CÃ©l': 'Cél',
    'â€': '”'
}

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
        
    for k, v in replacements.items():
        content = content.replace(k, v)
        
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)

print("Encoding fixed!")
