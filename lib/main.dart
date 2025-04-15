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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Color(0xFF121212),
        appBarTheme: AppBarTheme(backgroundColor: Color(0xFF1F1B24)),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1F1B24),
          selectedItemColor: Colors.deepPurpleAccent,
          unselectedItemColor: Colors.grey,
        ),
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
      appBar: AppBar(title: Text('SoundWave')),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(song.image, width: 50, height: 50, fit: BoxFit.cover),
            ),
            title: Text(song.title, style: TextStyle(color: Colors.white)),
            subtitle: Text(song.artist, style: TextStyle(color: Colors.grey)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NowPlayingPage(songIndex: index),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfilePage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Now Playing'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
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
        _player.durationStream,
        (position, duration) => DurationState(position: position, total: duration ?? Duration.zero),
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(song.image, width: 200, height: 200, fit: BoxFit.cover),
          SizedBox(height: 20),
          Text(song.title, style: TextStyle(fontSize: 24)),
          Text(song.artist, style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 30),
          StreamBuilder<DurationState>(
            stream: _durationStateStream,
            builder: (context, snapshot) {
              final durationState = snapshot.data;
              final progress = durationState?.position ?? Duration.zero;
              final total = durationState?.total ?? Duration.zero;
              return Column(
                children: [
                  Slider(
                    min: 0,
                    max: total.inMilliseconds.toDouble(),
                    value: progress.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                    onChanged: (value) => _player.seek(Duration(milliseconds: value.toInt())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(progress)),
                        Text(_formatDuration(total)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 48,
                icon: Icon(Icons.skip_previous),
                onPressed: _playPrevious,
              ),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final playing = playerState?.playing ?? false;
                  final processingState = playerState?.processingState;
                  if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                    return CircularProgressIndicator();
                  } else {
                    return IconButton(
                      iconSize: 64,
                      icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                      onPressed: () => playing ? _player.pause() : _player.play(),
                    );
                  }
                },
              ),
              IconButton(
                iconSize: 48,
                icon: Icon(Icons.skip_next),
                onPressed: _playNext,
              ),
              IconButton(
                iconSize: 32,
                icon: Icon(_isRepeat ? Icons.repeat_one : Icons.repeat, color: _isRepeat ? Colors.deepPurpleAccent : Colors.white),
                onPressed: () {
                  setState(() {
                    _isRepeat = !_isRepeat;
                    _player.setLoopMode(_isRepeat ? LoopMode.one : LoopMode.off);
                  });
                },
              ),
            ],
          ),
        ],
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

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Center(child: Text('User Profile Page', style: TextStyle(fontSize: 24))),
    );
  }
}
<inserted from canvas>