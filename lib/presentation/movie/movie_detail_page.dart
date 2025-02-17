import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:swing_trimmer/const/const.dart';
import 'package:swing_trimmer/domain/model/club.dart';
import 'package:swing_trimmer/domain/model/movie.dart';
import 'package:swing_trimmer/main.dart';
import 'package:swing_trimmer/presentation/common_widget/custom_app_bar.dart';
import 'package:swing_trimmer/presentation/common_widget/multi_select.dart';
import 'package:swing_trimmer/presentation/movie/movie_detail_view_model.dart';
import 'package:swing_trimmer/presentation/movie/movie_list_view_model.dart';
import 'package:swing_trimmer/presentation/movie/widget/custom_movie_player.dart';
import 'package:swing_trimmer/util/string.dart';

class MovieDetailPage extends ConsumerStatefulWidget {
  const MovieDetailPage({
    Key? key,
    required this.movie,
  }) : super(key: key);

  final Movie movie;

  @override
  _MovieDetailPageState createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends ConsumerState<MovieDetailPage> {
  late BetterPlayerController _betterPlayerController;
  late bool _isFavorite;
  late Club _club;

  Movie get movie => widget.movie;

  @override
  void initState() {
    super.initState();
    ref.read(movieDetailVm).readIfNecessary(movie);

    _betterPlayerController = BetterPlayerController(BetterPlayerConfiguration(
      aspectRatio: 1 / 2,
      fit: BoxFit.cover,
      autoPlay: true,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableFullscreen: false,
        enableMute: false,
        enableSkips: false,
        enableOverflowMenu: false,
        playIcon: Icons.play_arrow,
        controlBarColor: Colors.black.withOpacity(0.4),
      ),
    ));

    final _betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      widget.movie.moviePath ?? '',
    );
    _betterPlayerController.setupDataSource(_betterPlayerDataSource);

    _isFavorite = movie.isFavorite;
    _club = movie.club;
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }

  static const double iconSize = 28;
  MovieDetailViewModel get vm => ref.read(movieDetailVm);

  void _toggleFavorite() {
    vm.toggleFavorite(movie);
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _saveToGallery() async {
    final ok = await vm.saveToGallery(movie.moviePath);
    showOkAlertDialog(
        context: context, title: '端末への保存に${ok ? '成功' : '失敗'}しました');
  }

  void _delete() async {
    if (movie.isFavorite) {
      final result = await showOkCancelAlertDialog(
        context: context,
        title: 'お気に入り登録されています',
        message: '本当に削除しますか？',
      );

      if (result == OkCancelResult.cancel) {
        return;
      }
    }

    vm.delete(movie);
    Navigator.pop(context);
    ref.read(movieListVm.notifier).refresh();
  }

  void _changeSwungAt() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: movie.swungAt ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale("ja"),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: mainGreenColor,
              surface: modalBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null) {
      return;
    }
    await vm.changeSwungAt(movie, pickedDate);
    showOkAlertDialog(
      context: context,
      title: '${dateStringWithWeek(pickedDate)}\nに変更しました',
    );
  }

  void _selectClub() async {
    final selectedClub = await showGeneralDialog<Club>(
      context: context,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 300),
      barrierLabel: MaterialLocalizations.of(context).dialogLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      pageBuilder: (context, _, __) {
        return SafeArea(
          child: Column(
            children: [
              Container(
                width: MediaQuery.of(context).size.width,
                decoration: const BoxDecoration(
                  color: modalBackgroundColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      children: [
                        MultiSelect<Club>(
                          title: 'クラブ選択',
                          value: _club,
                          itemList: Club.values
                              .map((e) => MultiSelectItem<Club>(
                                  value: e, title: e.displayName))
                              .toList(),
                          onChange: (value) {
                            if (value == null) {
                              return Navigator.of(context).pop(Club.none);
                            }
                            return Navigator.of(context).pop(value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ).drive(Tween<Offset>(
            begin: const Offset(0, -1.0),
            end: Offset.zero,
          )),
          child: child,
        );
      },
    );

    if (selectedClub == null) {
      return;
    }
    await vm.selectClub(movie, selectedClub);
    showOkAlertDialog(
      context: context,
      title: '${selectedClub.displayName}に設定しました',
    );

    setState(() {
      _club = selectedClub;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: CustomAppBar(
            backgroundColor: Colors.black.withOpacity(0.4),
            leading: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                ref.read(movieListVm.notifier).refresh();
              },
              child: const Icon(Icons.chevron_left, size: 36),
            ),
            actions: [
              GestureDetector(
                onTap: () {
                  showOkAlertDialog(
                    context: context,
                    title: '使い方',
                    message: baseText,
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lightbulb_outline, size: 24),
                    Text(
                      '使い方',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _toggleFavorite,
                child: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red.withOpacity(0.8) : null,
                  size: iconSize,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _selectClub,
                child: Image.asset(
                  'assets/images/club_icon.png',
                  width: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _changeSwungAt,
                child: const Icon(Icons.date_range_outlined, size: iconSize),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _saveToGallery,
                child: const Icon(Icons.save_alt, size: iconSize),
              ),
              const SizedBox(width: 16),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _delete,
                child: const Icon(Icons.delete, size: iconSize),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: CustomMoviePlayer(
            controller: _betterPlayerController,
          ),
        ),
      ),
    );
  }
}
