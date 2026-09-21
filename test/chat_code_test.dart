import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/services/chat_code.dart';
import 'package:tyria_codex/util.dart';

/// palette pairs come back as [paletteId, skillId]
Json professionWith(Map<int, int> paletteBySkill) => {
      'skills_by_palette': [
        for (final e in paletteBySkill.entries) [e.value, e.key],
      ],
    };

Json guardianBuild() => {
      'profession': 'Guardian',
      'specializations': [
        {'id': 42, 'traits': [1, 5, 9]},
      ],
      'skills': {
        'heal': 100,
        'utilities': [101, 102, 103],
        'elite': 104,
      },
      'aquatic_skills': {
        'heal': 200,
        'utilities': [201, 202, 203],
        'elite': 204,
      },
    };

const _palette = {100: 1000, 200: 2000};

List<int> decode(String code) {
  expect(code.startsWith('[&'), isTrue);
  expect(code.endsWith(']'), isTrue);
  return base64Decode(code.substring(2, code.length - 1));
}

void main() {
  group('buildChatCode', () {
    test('returns null without the profession endpoint', () {
      expect(buildChatCode(guardianBuild(), null, const {}), isNull);
    });

    test('returns null for a profession that has no chat code id', () {
      final build = guardianBuild()..['profession'] = 'Bard';
      expect(buildChatCode(build, professionWith(_palette), const {}), isNull);
    });

    test('returns null when the profession carries no palette', () {
      expect(buildChatCode(guardianBuild(), {'skills_by_palette': []}, const {}), isNull);
    });

    test('emits a 44 byte link tagged as a build template', () {
      final code = buildChatCode(guardianBuild(), professionWith(_palette), const {});
      expect(code, isNotNull);
      final bytes = decode(code!);
      expect(bytes, hasLength(44));
      expect(bytes[0], 0x0D);
      // Guardian is profession 1
      expect(bytes[1], 1);
    });

    test('packs the chosen trait of each tier into two bits', () {
      // tier 0 -> slot 0, tier 1 -> slot 1, tier 2 -> slot 2
      const specDetails = <int, Json>{
        42: {
          'major_traits': [1, 4, 7, 2, 5, 8, 3, 6, 9],
        },
      };
      final code = buildChatCode(guardianBuild(), professionWith(_palette), specDetails);
      final bytes = decode(code!);
      expect(bytes[2], 42);
      // positions are 1, 2 and 3, packed two bits per tier
      expect(bytes[3], 1 | (2 << 2) | (3 << 4));
    });

    test('writes land and water skills as little endian palette ids', () {
      final code = buildChatCode(guardianBuild(), professionWith(_palette), const {});
      final bytes = decode(code!);
      // heal slot: land palette 1000, water palette 2000
      expect(bytes[8], 1000 & 0xFF);
      expect(bytes[9], 1000 >> 8);
      expect(bytes[10], 2000 & 0xFF);
      expect(bytes[11], 2000 >> 8);
    });

    test('leaves the profession block empty for a guardian', () {
      final code = buildChatCode(guardianBuild(), professionWith(_palette), const {});
      final bytes = decode(code!);
      expect(bytes.sublist(28, 32), everyElement(0));
    });

    test('stores revenant legend numbers in the profession block', () {
      final build = guardianBuild()
        ..['profession'] = 'Revenant'
        ..['legends'] = ['Legend2', 'Legend5'];
      final code = buildChatCode(build, professionWith(_palette), const {});
      final bytes = decode(code!);
      expect(bytes[28], 2);
      expect(bytes[29], 5);
      expect(bytes[30], 0);
    });

    test('stores ranger pets in the profession block', () {
      final build = guardianBuild()
        ..['profession'] = 'Ranger'
        ..['pets'] = {
          'terrestrial': [11, 12],
          'aquatic': [13, 14],
        };
      final code = buildChatCode(build, professionWith(_palette), const {});
      final bytes = decode(code!);
      expect(bytes.sublist(28, 32), [11, 12, 13, 14]);
    });
  });
}
