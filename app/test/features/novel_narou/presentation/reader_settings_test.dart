import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geekplayer/features/novel_narou/presentation/reader_settings.dart';

void main() {
  test('default は 16pt / 1.6 / light', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    final ReaderTheme t = c.read(readerThemeProvider);
    expect(t.fontSize, 16);
    expect(t.lineHeight, 1.6);
    expect(t.colorScheme, ReaderColorScheme.light);
  });

  test('setFontSize は 12-32 にクランプ', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(readerThemeProvider.notifier).setFontSize(50);
    expect(c.read(readerThemeProvider).fontSize, 32);
    c.read(readerThemeProvider.notifier).setFontSize(5);
    expect(c.read(readerThemeProvider).fontSize, 12);
  });

  test('setLineHeight は 1.2-2.4 にクランプ', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(readerThemeProvider.notifier).setLineHeight(3.0);
    expect(c.read(readerThemeProvider).lineHeight, 2.4);
    c.read(readerThemeProvider.notifier).setLineHeight(0.5);
    expect(c.read(readerThemeProvider).lineHeight, 1.2);
  });

  test('setColorScheme は反映され keepAlive で保持', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(readerThemeProvider.notifier).setColorScheme(ReaderColorScheme.dark);
    expect(c.read(readerThemeProvider).colorScheme, ReaderColorScheme.dark);
    expect(c.read(readerThemeProvider).background, isA<Color>());
  });
}
