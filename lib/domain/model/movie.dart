import 'package:freezed_annotation/freezed_annotation.dart';

part 'movie.freezed.dart';

@freezed
class Movie with _$Movie {
  const factory Movie({
    int? id,
    String? thumbnailPath,
    String? moviePath,
    @Default(false) bool isFavorite,
    DateTime? swungAt,
  }) = _Movie;
}
