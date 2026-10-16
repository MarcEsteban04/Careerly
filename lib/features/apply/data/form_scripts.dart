import 'dart:convert';

import 'form_field_info.dart';

/// JavaScript run inside application pages to read and fill their forms.
abstract final class FormScripts {
  /// Makes links that open new windows load in the same view, since the
  /// in-app browser has one page at a time.
  static const keepInView = r'''
(function () {
  if (window.__careerlyKeepInView) return;
  window.__careerlyKeepInView = true;
  window.open = function (url) { if (url) location.href = url; return window; };
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[target]') : null;
    if (a && a.target !== '_self') a.target = '_self';
  }, true);
})();
''';

  /// Lists the visible, fillable fields as JSON:
  /// `{"fields": [...], "frames": ["<embedded form URLs>"]}`.
  static const scan = r'''
(function () {
  function clean(t) { return (t || '').replace(/\s+/g, ' ').trim().slice(0, 200); }
  function visible(el) {
    var r = el.getBoundingClientRect();
    var s = window.getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none';
  }
  function labelFor(el) {
    var t = '';
    if (el.id) {
      var l = document.querySelector('label[for="' + CSS.escape(el.id) + '"]');
      if (l) t = l.innerText;
    }
    if (!t && el.closest) { var p = el.closest('label'); if (p) t = p.innerText; }
    if (!t) t = el.getAttribute('aria-label') || '';
    if (!t && el.getAttribute('aria-labelledby')) {
      t = el.getAttribute('aria-labelledby').split(' ').map(function (id) {
        var n = document.getElementById(id); return n ? n.innerText : '';
      }).join(' ');
    }
    // Otherwise the nearest text before the field.
    var node = el;
    for (var depth = 0; !t && node && depth < 4; depth++) {
      var sib = node.previousElementSibling;
      while (!t && sib) {
        var txt = clean(sib.innerText);
        if (txt && txt.length < 200) t = txt;
        sib = sib.previousElementSibling;
      }
      node = node.parentElement;
    }
    return clean(t);
  }
  var fields = [];
  var radios = {};
  var n = 0;
  var skip = ['hidden', 'password', 'file', 'submit', 'button', 'reset', 'image', 'checkbox', 'search', 'range', 'color'];
  document.querySelectorAll('input, textarea, select').forEach(function (el) {
    if (el.disabled || el.readOnly || !visible(el)) return;
    var tag = el.tagName.toLowerCase();
    var type = (el.getAttribute('type') || 'text').toLowerCase();
    if (tag === 'input' && skip.indexOf(type) >= 0) return;
    if (tag === 'input' && type === 'radio') {
      var group = el.name || ('radio' + (n++));
      if (!radios[group]) {
        var fieldset = el.closest('fieldset');
        var legend = fieldset ? fieldset.querySelector('legend') : null;
        var question = legend ? clean(legend.innerText) : '';
        if (!question) {
          var box = el.closest('[role="radiogroup"]') || el.parentElement && el.parentElement.parentElement;
          question = box ? labelFor(box) : '';
        }
        radios[group] = {
          id: 'radio:' + group, kind: 'radio', label: question, name: el.name || '',
          options: [], required: el.required, value: ''
        };
        fields.push(radios[group]);
      }
      var option = labelFor(el) || el.value;
      el.setAttribute('data-careerly-radio', group);
      el.setAttribute('data-careerly-option', option);
      radios[group].options.push(option);
      if (el.checked) radios[group].value = option;
      return;
    }
    var id = 'f' + (n++);
    el.setAttribute('data-careerly-id', id);
    var kind = tag === 'textarea' ? 'textarea' : tag === 'select' ? 'select' :
      (['email', 'tel', 'url', 'number', 'date'].indexOf(type) >= 0 ? type : 'text');
    var options = [];
    if (tag === 'select') {
      for (var i = 0; i < el.options.length; i++) {
        var o = el.options[i];
        if (o.value !== '' && !o.disabled) options.push(clean(o.text));
      }
    }
    fields.push({
      id: id, kind: kind, label: labelFor(el), name: el.name || el.id || '',
      autocomplete: el.getAttribute('autocomplete') || '',
      placeholder: el.getAttribute('placeholder') || '',
      options: options, required: el.required,
      maxLength: el.maxLength > 0 ? el.maxLength : null,
      value: tag === 'select' ? (el.selectedIndex > 0 ? clean(el.options[el.selectedIndex].text) : '') : (el.value || '')
    });
  });
  var frames = [];
  document.querySelectorAll('iframe[src]').forEach(function (f) {
    if (visible(f) && /^https?:/.test(f.src)) frames.push(f.src);
  });
  return JSON.stringify({ fields: fields, frames: frames });
})();
''';

  /// Fills fields by their Careerly ids, firing the events frameworks like
  /// React listen for, and outlines what was filled. Returns how many.
  static String fill(Map<String, String> values) => '''
(function (values) {
  function setNative(el, v) {
    var proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype :
      el.tagName === 'SELECT' ? HTMLSelectElement.prototype : HTMLInputElement.prototype;
    var desc = Object.getOwnPropertyDescriptor(proto, 'value');
    if (desc && desc.set) desc.set.call(el, v); else el.value = v;
    ['input', 'change', 'blur'].forEach(function (t) {
      el.dispatchEvent(new Event(t, { bubbles: true }));
    });
  }
  function mark(el) {
    el.style.outline = '2px solid #6FC4D0';
    el.style.outlineOffset = '2px';
  }
  var filled = 0;
  Object.keys(values).forEach(function (id) {
    var v = values[id];
    if (id.indexOf('radio:') === 0) {
      var group = id.slice(6);
      document.querySelectorAll('[data-careerly-radio]').forEach(function (r) {
        if (r.getAttribute('data-careerly-radio') === group &&
            r.getAttribute('data-careerly-option') === v) {
          r.click(); mark(r.closest('label') || r); filled++;
        }
      });
      return;
    }
    var el = document.querySelector('[data-careerly-id="' + id + '"]');
    if (!el) return;
    if (el.tagName === 'SELECT') {
      for (var i = 0; i < el.options.length; i++) {
        var t = el.options[i].text.replace(/\\s+/g, ' ').trim();
        if (t === v) { setNative(el, el.options[i].value); mark(el); filled++; return; }
      }
      return;
    }
    el.focus();
    setNative(el, v);
    mark(el);
    filled++;
  });
  return filled;
})(${jsonEncode(values)});
''';

  /// Reads the result of [scan] as returned by the web view, which may
  /// wrap the JSON string in a second layer of quotes.
  static ({List<FormFieldInfo> fields, List<String> frames}) parseScan(
    Object? result,
  ) {
    Object? decoded = result;
    for (var i = 0; i < 2 && decoded is String; i++) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        break;
      }
    }
    if (decoded is! Map<String, dynamic>) {
      return (fields: const [], frames: const []);
    }
    final fields = decoded['fields'];
    final frames = decoded['frames'];
    return (
      fields: fields is List
          ? fields
              .whereType<Map<String, dynamic>>()
              .map(FormFieldInfo.fromJson)
              .where((f) => f.id.isNotEmpty)
              .toList()
          : const [],
      frames: frames is List ? frames.whereType<String>().toList() : const [],
    );
  }
}
