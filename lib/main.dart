import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(SoundWaveApp());
}

class SoundWaveApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundWave',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        fontFamily: 'Arial',
      ),
      home: HomePage(),
    );
  }
}

class Song {
  final String title;
  final String artist;
  final String image;
  final String audioPath;

  Song({required this.title, required this.artist, required this.image, required this.audioPath});
}

final List<Song> songs = [
  Song(
    title: 'Vibes',
    artist: 'DJ Sonic',
    image: 'assets/images/artist1.jpg',
    audioPath: 'assets/audio/song1.mp3',
  ),
  Song(
    title: 'Groove Beats',
    artist: 'Echo Star',
    image: 'assets/images/artist2.jpg',
    audioPath: 'assets/audio/song2.mp3',
  ),
];

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoundWave', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NowPlayingPage(songIndex: index)),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade800.withOpacity(0.4), Colors.black26],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(song.image, width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    title: Text(song.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text(song.artist, style: TextStyle(color: Colors.grey[400])),
                    trailing: Icon(Icons.play_arrow, color: Colors.white70),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NowPlayingPage extends StatefulWidget {
  final int songIndex;
  const NowPlayingPage({required this.songIndex, Key? key}) : super(key: key);

  @override
  _NowPlayingPageState createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late final AudioPlayer _player;
  late int _currentIndex;
  bool _isRepeat = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.songIndex;
    _player = AudioPlayer();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.setAsset(songs[_currentIndex].audioPath);
      _player.setLoopMode(_isRepeat ? LoopMode.one : LoopMode.off);
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  void _playNext() {
    if (_currentIndex < songs.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _initializePlayer();
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _initializePlayer();
    }
  }

  Stream<DurationState> get _durationStateStream =>
      Rx.combineLatest2<Duration, Duration, DurationState>(
        _player.positionStream,
        _player.durationStream.map((d) => d ?? Duration.zero),
        (position, duration) => DurationState(position: position, total: duration),
      );

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = songs[_currentIndex];
    return Scaffold(
      appBar: AppBar(title: Text(song.title)),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(song.image, width: 250, height: 250, fit: BoxFit.cover),
            ),
            const SizedBox(height: 30),
            Text(song.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text(song.artist, style: TextStyle(fontSize: 18, color: Colors.grey[400])),
            const SizedBox(height: 30),
            StreamBuilder<DurationState>(
              stream: _durationStateStream,
              builder: (context, snapshot) {
                final durationState = snapshot.data;
                final progress = durationState?.position ?? Duration.zero;
                final total = durationState?.total ?? Duration.zero;
                return Column(
                  children: [
                    Slider(
                      activeColor: Colors.deepPurpleAccent,
                      inactiveColor: Colors.grey,
                      min: 0,
                      max: total.inMilliseconds.toDouble(),
                      value: progress.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                      onChanged: (value) => _player.seek(Duration(milliseconds: value.toInt())),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(progress), style: TextStyle(fontSize: 14)),
                          Text(_formatDuration(total), style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: Icon(Icons.skip_previous, size: 40), onPressed: _playPrevious),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final playing = playerState?.playing ?? false;
                    final processingState = playerState?.processingState;
                    if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                      return const CircularProgressIndicator();
                    } else {
                      return IconButton(
                        iconSize: 60,
                        icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                        onPressed: () => playing ? _player.pause() : _player.play(),
                      );
                    }
                  },
                ),
                IconButton(icon: Icon(Icons.skip_next, size: 40), onPressed: _playNext),
              ],
            ),
            IconButton(
              icon: Icon(
                _isRepeat ? Icons.repeat_one : Icons.repeat,
                size: 30,
                color: _isRepeat ? Colors.deepPurpleAccent : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isRepeat = !_isRepeat;
                  _player.setLoopMode(_isRepeat ? LoopMode.one : LoopMode.off);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class DurationState {
  final Duration position;
  final Duration total;

  DurationState({required this.position, required this.total});
}