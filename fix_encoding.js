const fs = require('fs');
const path = require('path');

const replacements = {
    "—": "—",
    "–": "–",
    "“": "“",
    "”": "”",
    "”\u009d": "”",
    "‘": "‘",
    "’": "’",
    "→": "→",
    "✅": "✅",
    "✖": "✖",
    "°": "°",
    "©": "©",
    "Â\xA0": " ", // NBSP
    " ": " " // literal
};

function fixEncoding(content) {
    let newContent = content;
    let fixCount = 0;
    
    const keys = Object.keys(replacements).sort((a, b) => b.length - a.length);
    
    for (const key of keys) {
        if (newContent.includes(key)) {
            const regex = new RegExp(key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');
            const matches = newContent.match(regex);
            if (matches) {
                fixCount += matches.length;
                newContent = newContent.replace(regex, replacements[key]);
            }
        }
    }
    
    if (newContent.includes("”")) {
        const regex = new RegExp("”".replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g');
        const matches = newContent.match(regex);
        if (matches) {
            fixCount += matches.length;
            newContent = newContent.replace(regex, "”");
        }
    }
    
    return { newContent, fixCount };
}

function walkSync(currentDirPath, callback) {
    const items = fs.readdirSync(currentDirPath);
    for (const name of items) {
        if (['node_modules', 'vendor', '.git'].includes(name)) continue;
        const filePath = path.join(currentDirPath, name);
        const stat = fs.statSync(filePath);
        if (stat.isFile()) {
            if (/\.(html|css|js|txt|json)$/i.test(filePath)) {
                callback(filePath);
            }
        } else if (stat.isDirectory()) {
            walkSync(filePath, callback);
        }
    }
}

let totalFixes = 0;
walkSync('.', function(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const { newContent, fixCount } = fixEncoding(content);
    if (fixCount > 0) {
        fs.writeFileSync(filePath, newContent, 'utf8');
        console.log(`Fixed ${fixCount} issues in ${filePath}`);
        totalFixes += fixCount;
    }
});

console.log(`\n--- SUMMARY ---`);
console.log(`Total fixes applied: ${totalFixes}`);
