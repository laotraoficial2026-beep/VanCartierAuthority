import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

void main() {
  runApp(const WhisperDossierApp());
}

class WhisperDossierApp extends StatelessWidget {
  const WhisperDossierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Whisper Dossier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RecorderPage(),
    );
  }
}

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final AudioRecorder _recorder = AudioRecorder();
  final String _endpoint = 'http://192.168.0.251:8000/transcribe';

  bool _isRecording = false;
  bool _isSending = false;
  String _status = 'Pulsa el botón para grabar audio.';
  String _transcription = '';

  Future<void> _toggleRecording() async {
    if (_isSending) return;

    if (!_isRecording) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() {
          _status = 'Permiso de micrófono denegado.';
        });
        return;
      }

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
        path: 'whisper_input.wav',
      );

      setState(() {
        _isRecording = true;
        _status = 'Grabando...';
      });
      return;
    }

    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path == null) {
      setState(() {
        _status = 'No se pudo guardar el audio.';
      });
      return;
    }

    await _sendAudio(File(path));
  }

  Future<void> _sendAudio(File audioFile) async {
    setState(() {
      _isSending = true;
      _status = 'Enviando audio a $_endpoint...';
      _transcription = '';
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _status = 'Transcripción completada.';
          _transcription = responseBody;
        });
      } else {
        setState(() {
          _status = 'Error ${response.statusCode}: $responseBody';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error de conexión: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whisper Dossier Mobile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Detener y enviar' : 'Grabar audio'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Transcripción:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_transcription.isEmpty ? 'Sin resultados aún.' : _transcription),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
