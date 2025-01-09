import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:async';
import 'package:http_parser/http_parser.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSubmitted;
  final String hintText;

  const MessageInput({
    super.key,
    required this.onSubmitted,
    this.hintText = 'Send a message',
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _messageController = TextEditingController();
  bool _isSubmittingMessage = false;
  bool _isUploadingFile = false;
  List<FileUpload> _uploadedFiles = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty && _uploadedFiles.isEmpty) return;

    setState(() {
      _isSubmittingMessage = true;
    });

    String messageText = text;
    if (_uploadedFiles.isNotEmpty) {
      // Add file references to the message
      final fileLinks = await Future.wait(
          _uploadedFiles.map((file) => _getDownloadUrl(file.key)));
      final validLinks = fileLinks.where((link) => link != null).cast<String>();
      if (validLinks.isNotEmpty) {
        messageText = '$text\n${validLinks.join('\n')}';
      }
    }

    _messageController.clear();
    _uploadedFiles.clear();

    await widget.onSubmitted(messageText);

    setState(() {
      _isSubmittingMessage = false;
    });
  }

  Future<Map<String, dynamic>?> _getUploadUrl(String fileName) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.accessToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/file/upload-url'),
        headers: {
          'Authorization': 'Bearer ${authProvider.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fileName': fileName}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting upload URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get upload URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return null;
  }

  Future<String?> _getDownloadUrl(String key) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.accessToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/file/$key/download-url'),
        headers: {
          'Authorization': 'Bearer ${authProvider.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      }
    } catch (e) {
      debugPrint('Error getting download URL: $e');
    }
    return null;
  }

  Future<void> _uploadFileWithXHR(
    PlatformFile file,
    String uploadUrl,
    String fileKey,
  ) {
    final completer = Completer<void>();
    final xhr = html.HttpRequest();

    xhr.open('PUT', uploadUrl);
    xhr.setRequestHeader('Content-Type', 'application/octet-stream');

    xhr.upload.onProgress.listen((e) {
      if (e.lengthComputable) {
        final total = e.total ?? 0;
        final loaded = e.loaded ?? 0;
        if (total > 0) {
          final percentComplete = (loaded / total) * 100;
          debugPrint('Upload progress: $percentComplete%');
        }
      }
    });

    xhr.onLoad.listen((e) {
      if (xhr.status == 200) {
        if (mounted) {
          setState(() {
            _uploadedFiles.add(FileUpload(
              name: file.name,
              key: fileKey,
              size: file.bytes!.length,
            ));
          });
        }
        completer.complete();
      } else {
        completer.completeError('Upload failed with status: ${xhr.status}');
      }
    });

    xhr.onError.listen((e) {
      debugPrint('XHR Error: $e');
      completer.completeError('Upload failed: $e');
    });

    // Convert Uint8List to Blob and send
    final blob = html.Blob([file.bytes]);
    xhr.send(blob);

    return completer.future;
  }

  Future<void> _handleFileUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isUploadingFile = true;
      });

      for (final file in result.files) {
        if (file.bytes == null) continue;

        final uploadUrlResponse = await _getUploadUrl(file.name);
        if (uploadUrlResponse == null) continue;

        try {
          final uploadUrl = uploadUrlResponse['url'] as String;
          final fileKey = uploadUrlResponse['key'] as String;

          await _uploadFileWithXHR(file, uploadUrl, fileKey);
        } catch (e) {
          debugPrint('Error uploading file: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading ${file.name}: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });
      }
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          if (_uploadedFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: _uploadedFiles
                    .map((file) => Chip(
                          label: Text(file.name),
                          onDeleted: () {
                            setState(() {
                              _uploadedFiles.remove(file);
                            });
                          },
                        ))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: _isUploadingFile
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                  onPressed: _isUploadingFile ? null : _handleFileUpload,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      border: InputBorder.none,
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _handleSubmitted(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FileUpload {
  final String name;
  final String key;
  final int size;

  FileUpload({
    required this.name,
    required this.key,
    required this.size,
  });
}
