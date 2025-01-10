import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/message_provider.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';

class MessageInput extends StatefulWidget {
  final Future<bool> Function(String, List<MessageAttachment>) onSubmitted;
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
  final _dio = Dio();
  bool _isSubmittingMessage = false;
  bool _isUploadingFile = false;
  final List<MessageAttachment> _uploadedFiles = [];
  final Map<String, double> _uploadProgress = {};

  @override
  void dispose() {
    _messageController.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty && _uploadedFiles.isEmpty) return;

    setState(() {
      _isSubmittingMessage = true;
    });

    final attachments = List<MessageAttachment>.from(_uploadedFiles);
    _uploadedFiles.clear();

    final success = await widget.onSubmitted(text, attachments);

    if (!success && mounted) {
      setState(() {
        _uploadedFiles.addAll(attachments);
      });
    } else {
      _messageController.clear();
    }

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

  Future<void> _uploadFile(
    PlatformFile file,
    String uploadUrl,
    String fileKey,
  ) async {
    try {
      setState(() {
        _uploadProgress[file.name] = 0;
      });

      await _dio.put(
        uploadUrl,
        data: file.bytes,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
          },
        ),
        onSendProgress: (count, total) {
          if (mounted) {
            setState(() {
              _uploadProgress[file.name] = (count / total) * 100;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _uploadedFiles.add(MessageAttachment(
            fileKey: fileKey,
            filename: file.name,
            mimeType: _getContentType(file.extension ?? ''),
            size: file.size,
          ));
          _uploadProgress.remove(file.name);
        });
      }
    } catch (e) {
      _uploadProgress.remove(file.name);
      rethrow;
    }
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

          await _uploadFile(file, uploadUrl, fileKey);
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
          if (_uploadedFiles.isNotEmpty || _uploadProgress.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: [
                  ..._uploadedFiles.map((file) => Chip(
                        label: Text(file.filename),
                        onDeleted: () {
                          setState(() {
                            _uploadedFiles.remove(file);
                          });
                        },
                      )),
                  ..._uploadProgress.entries.map((entry) => Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(entry.key),
                            const SizedBox(width: 8),
                            Text('${entry.value.toStringAsFixed(0)}%'),
                          ],
                        ),
                      )),
                ],
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
                  icon: _isSubmittingMessage
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isSubmittingMessage
                      ? null
                      : () => _handleSubmitted(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
