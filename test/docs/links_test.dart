import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The README and the documents it points to are read by someone who has only
/// the repository. A link to a file that was moved, or to a heading that was
/// renamed, is a dead end, so every relative link and every `#anchor` into a
/// Markdown file of the repository is checked.

/// The Markdown files of the repository that are documentation.
List<File> _documents() => [
  File('README.md'),
  File('AGENTS.md'),
  for (final directory in ['docs', '.agents'])
    for (final entity in Directory(directory).listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.md')) entity,
];

/// [markdown] without its fenced code blocks and inline code, where a `[x](y)`
/// is an example and not a link.
String _withoutCode(String markdown) => markdown
    .replaceAll(RegExp(r'^(```|~~~).*?^\1', multiLine: true, dotAll: true), '')
    .replaceAll(RegExp(r'`[^`\n]*`'), '');

/// GitHub's anchor for a heading: lower case, punctuation dropped, spaces as hyphens.
String _anchorOf(String heading) => heading
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^\w\- ]', unicode: true), '')
    .replaceAll(' ', '-');

Set<String> _anchors(File file) => {
  for (final match in RegExp(
    r'^#{1,6}\s+(.+?)\s*#*$',
    multiLine: true,
  ).allMatches(_withoutCode(file.readAsStringSync())))
    _anchorOf(match.group(1)!.replaceAll(RegExp(r'[`*_]'), '')),
};

void main() {
  final documents = _documents();

  test('the documents were found', () {
    expect(documents.length, greaterThan(8));
  });

  test('every relative link and anchor points at something that exists', () {
    final broken = <String>[];
    for (final document in documents) {
      final text = _withoutCode(document.readAsStringSync());
      for (final match in RegExp(
        r'!?\[[^\]]*\]\(([^)\s]+)[^)]*\)',
      ).allMatches(text)) {
        final target = match.group(1)!;
        // https:, mailto:
        if (RegExp(r'^[a-z][a-z0-9+.-]*:').hasMatch(target)) {
          continue;
        }
        final hash = target.indexOf('#');
        final path = hash == -1 ? target : target.substring(0, hash);
        final anchor = hash == -1 ? null : target.substring(hash + 1);

        final File file = path.isEmpty
            ? document
            : File(
                Uri.directory(
                  document.parent.path,
                ).resolve(Uri.decodeFull(path)).toFilePath(),
              );
        if (!file.existsSync() && !Directory(file.path).existsSync()) {
          broken.add('${document.path}: $target (no such file)');
        } else if (anchor != null &&
            anchor.isNotEmpty &&
            file.path.endsWith('.md') &&
            !_anchors(file).contains(anchor.toLowerCase())) {
          broken.add('${document.path}: $target (no such heading)');
        }
      }
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });
}
