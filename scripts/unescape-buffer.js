#!/usr/bin/env node

// unescape-buffer.js
// Reads from stdin, unescapes string literals, writes to stdout

const fs = require('fs');

let input = '';

process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => {
  input += chunk;
});

process.stdin.on('end', () => {
  const unescaped = input
    .replace(/\\n/g, '\n')
    .replace(/\\"/g, '"')
    .replace(/\\t/g, '\t')
    .replace(/\\r/g, '\r')
    .replace(/\\\\/g, '\\');

  process.stdout.write(unescaped);
});
