// On double-click, report the source line/column of the clicked text.
document.addEventListener('dblclick', e => {
  const r = document.caretRangeFromPoint(e.clientX, e.clientY);
  let node = r ? r.startContainer : e.target, off = r ? r.startOffset : 0;
  let el = node.nodeType === 3 ? node.parentElement : node;
  if (node.nodeType !== 3) off = 0;
  while (el && !el.getAttribute('data-pos')) { el = el.parentElement; off = 0; }
  let line = 1, col = 1;
  if (el) { const m = el.getAttribute('data-pos').match(/(\d+):(\d+)/); line = +m[1]; col = +m[2]; }
  window.getSelection().removeAllRanges();
  webkit.messageHandlers.edit.postMessage({line, col, off});
});
// Code colors, task boxes, and GitHub alert markup.
document.querySelectorAll('pre > code').forEach(c => {
  const lang = c.parentElement.className.split(' ')[0];
  if (lang) c.classList.add('language-' + lang);
  hljs.highlightElement(c);
});
document.querySelectorAll('li').forEach(li => {
  const t = li.firstChild;
  if (t && t.nodeType === 3 && /^[☒☐]/.test(t.data)) {
    const box = document.createElement('input');
    box.type = 'checkbox'; box.disabled = true; box.checked = t.data[0] === '☒';
    t.data = t.data.slice(1).replace(/^ /, '');
    li.prepend(box);
    li.classList.add('task-list-item');
    li.parentElement.classList.add('contains-task-list');
  }
});
['note', 'tip', 'important', 'warning', 'caution'].forEach(k => {
  document.querySelectorAll('div.' + k).forEach(d => {
    d.classList.add('markdown-alert', 'markdown-alert-' + k);
    const t = d.querySelector(':scope > div.title');
    if (t) { const p = document.createElement('p'); p.className = 'markdown-alert-title'; p.textContent = t.textContent.trim(); t.replaceWith(p); }
  });
});
function scrollToLine(n) {
  let best = null;
  for (const el of document.querySelectorAll('[data-pos]')) {
    const m = el.getAttribute('data-pos').match(/(\d+):/);
    if (+m[1] <= n) best = el; else break;
  }
  if (best) best.scrollIntoView({block: 'center'});
}
