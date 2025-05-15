import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff7f5610),
      surfaceTint: Color(0xff7f5610),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffffddb2),
      onPrimaryContainer: Color(0xff624000),
      secondary: Color(0xff466730),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffc7eea9),
      onSecondaryContainer: Color(0xff2f4f1b),
      tertiary: Color(0xff904b3a),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffffdad2),
      onTertiaryContainer: Color(0xff723425),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffff8f4),
      onSurface: Color(0xff201b13),
      onSurfaceVariant: Color(0xff4f4539),
      outline: Color(0xff817567),
      outlineVariant: Color(0xffd3c4b4),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff362f27),
      inversePrimary: Color(0xfff3bd6e),
      primaryFixed: Color(0xffffddb2),
      onPrimaryFixed: Color(0xff291800),
      primaryFixedDim: Color(0xfff3bd6e),
      onPrimaryFixedVariant: Color(0xff624000),
      secondaryFixed: Color(0xffc7eea9),
      onSecondaryFixed: Color(0xff0a2100),
      secondaryFixedDim: Color(0xffacd28f),
      onSecondaryFixedVariant: Color(0xff2f4f1b),
      tertiaryFixed: Color(0xffffdad2),
      onTertiaryFixed: Color(0xff3a0a02),
      tertiaryFixedDim: Color(0xffffb4a2),
      onTertiaryFixedVariant: Color(0xff723425),
      surfaceDim: Color(0xffe4d8cc),
      surfaceBright: Color(0xfffff8f4),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffef2e5),
      surfaceContainer: Color(0xfff9ecdf),
      surfaceContainerHigh: Color(0xfff3e6da),
      surfaceContainerHighest: Color(0xffede0d4),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff4c3100),
      surfaceTint: Color(0xff7f5610),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff90651f),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff1f3d0b),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff55763d),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff5d2416),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffa15948),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffff8f4),
      onSurface: Color(0xff161009),
      onSurfaceVariant: Color(0xff3e3529),
      outline: Color(0xff5b5144),
      outlineVariant: Color(0xff776b5e),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff362f27),
      inversePrimary: Color(0xfff3bd6e),
      primaryFixed: Color(0xff90651f),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff744d04),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff55763d),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff3d5d27),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xffa15948),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff844232),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffd0c5b9),
      surfaceBright: Color(0xfffff8f4),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffef2e5),
      surfaceContainer: Color(0xfff3e6da),
      surfaceContainerHigh: Color(0xffe7dbcf),
      surfaceContainerHighest: Color(0xffdcd0c4),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff3f2700),
      surfaceTint: Color(0xff7f5610),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff654200),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff153302),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff32511d),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff501b0d),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff753727),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffff8f4),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff332b20),
      outlineVariant: Color(0xff51483b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff362f27),
      inversePrimary: Color(0xfff3bd6e),
      primaryFixed: Color(0xff654200),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff472d00),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff32511d),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff1c3a07),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff753727),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff592113),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc2b7ab),
      surfaceBright: Color(0xfffff8f4),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffbefe2),
      surfaceContainer: Color(0xffede0d4),
      surfaceContainerHigh: Color(0xffded2c6),
      surfaceContainerHighest: Color(0xffd0c5b9),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfff3bd6e),
      surfaceTint: Color(0xfff3bd6e),
      onPrimary: Color(0xff442b00),
      primaryContainer: Color(0xff624000),
      onPrimaryContainer: Color(0xffffddb2),
      secondary: Color(0xffacd28f),
      onSecondary: Color(0xff193705),
      secondaryContainer: Color(0xff2f4f1b),
      onSecondaryContainer: Color(0xffc7eea9),
      tertiary: Color(0xffffb4a2),
      onTertiary: Color(0xff561f11),
      tertiaryContainer: Color(0xff723425),
      onTertiaryContainer: Color(0xffffdad2),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff18120b),
      onSurface: Color(0xffede0d4),
      onSurfaceVariant: Color(0xffd3c4b4),
      outline: Color(0xff9b8f80),
      outlineVariant: Color(0xff4f4539),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffede0d4),
      inversePrimary: Color(0xff7f5610),
      primaryFixed: Color(0xffffddb2),
      onPrimaryFixed: Color(0xff291800),
      primaryFixedDim: Color(0xfff3bd6e),
      onPrimaryFixedVariant: Color(0xff624000),
      secondaryFixed: Color(0xffc7eea9),
      onSecondaryFixed: Color(0xff0a2100),
      secondaryFixedDim: Color(0xffacd28f),
      onSecondaryFixedVariant: Color(0xff2f4f1b),
      tertiaryFixed: Color(0xffffdad2),
      onTertiaryFixed: Color(0xff3a0a02),
      tertiaryFixedDim: Color(0xffffb4a2),
      onTertiaryFixedVariant: Color(0xff723425),
      surfaceDim: Color(0xff18120b),
      surfaceBright: Color(0xff3f382f),
      surfaceContainerLowest: Color(0xff120d07),
      surfaceContainerLow: Color(0xff201b13),
      surfaceContainer: Color(0xff251f17),
      surfaceContainerHigh: Color(0xff2f2921),
      surfaceContainerHighest: Color(0xff3b342b),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffffd69e),
      surfaceTint: Color(0xfff3bd6e),
      onPrimary: Color(0xff362100),
      primaryContainer: Color(0xffb8883f),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffc1e8a3),
      onSecondary: Color(0xff102c00),
      secondaryContainer: Color(0xff779b5e),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffffd2c8),
      onTertiary: Color(0xff481408),
      tertiaryContainer: Color(0xffcb7c68),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff18120b),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffe9dac9),
      outline: Color(0xffbeb0a0),
      outlineVariant: Color(0xff9b8e80),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffede0d4),
      inversePrimary: Color(0xff644100),
      primaryFixed: Color(0xffffddb2),
      onPrimaryFixed: Color(0xff1b0f00),
      primaryFixedDim: Color(0xfff3bd6e),
      onPrimaryFixedVariant: Color(0xff4c3100),
      secondaryFixed: Color(0xffc7eea9),
      onSecondaryFixed: Color(0xff051500),
      secondaryFixedDim: Color(0xffacd28f),
      onSecondaryFixedVariant: Color(0xff1f3d0b),
      tertiaryFixed: Color(0xffffdad2),
      onTertiaryFixed: Color(0xff2a0400),
      tertiaryFixedDim: Color(0xffffb4a2),
      onTertiaryFixedVariant: Color(0xff5d2416),
      surfaceDim: Color(0xff18120b),
      surfaceBright: Color(0xff4b433a),
      surfaceContainerLowest: Color(0xff0b0703),
      surfaceContainerLow: Color(0xff221d15),
      surfaceContainer: Color(0xff2d271f),
      surfaceContainerHigh: Color(0xff383129),
      surfaceContainerHighest: Color(0xff443c34),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffffedda),
      surfaceTint: Color(0xfff3bd6e),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffefb96b),
      onPrimaryContainer: Color(0xff130900),
      secondary: Color(0xffd4fcb5),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffa8ce8b),
      onSecondaryContainer: Color(0xff030e00),
      tertiary: Color(0xffffece8),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffffaf9b),
      onTertiaryContainer: Color(0xff1f0200),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff18120b),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xfffdeddc),
      outlineVariant: Color(0xffcfc0b0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffede0d4),
      inversePrimary: Color(0xff644100),
      primaryFixed: Color(0xffffddb2),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xfff3bd6e),
      onPrimaryFixedVariant: Color(0xff1b0f00),
      secondaryFixed: Color(0xffc7eea9),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffacd28f),
      onSecondaryFixedVariant: Color(0xff051500),
      tertiaryFixed: Color(0xffffdad2),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffffb4a2),
      onTertiaryFixedVariant: Color(0xff2a0400),
      surfaceDim: Color(0xff18120b),
      surfaceBright: Color(0xff574f46),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff251f17),
      surfaceContainer: Color(0xff362f27),
      surfaceContainerHigh: Color(0xff413a32),
      surfaceContainerHighest: Color(0xff4d463d),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }


  ThemeData theme(ColorScheme colorScheme) => ThemeData(
     useMaterial3: true,
     brightness: colorScheme.brightness,
     colorScheme: colorScheme,
     textTheme: textTheme.apply(
       bodyColor: colorScheme.onSurface,
       displayColor: colorScheme.onSurface,
     ),
     scaffoldBackgroundColor: colorScheme.background,
     canvasColor: colorScheme.surface,
  );


  List<ExtendedColor> get extendedColors => [
  ];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
