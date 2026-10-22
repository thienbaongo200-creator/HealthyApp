import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/network/token_storage.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/widgets/widgets.dart';
import 'package:frontend/widgets/profile_context_banner.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  static const _teal = Color(0xFF168B83);
  static const _ink = Color(0xFF18343A);

  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _documents = [];
  String? _profileId;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profiles = await ApiService.fetchProfiles();
      if (!mounted) return;
      ProfileSelectionScope.of(context).setProfiles(profiles);
      final globalProfileId = ProfileSelectionScope.of(
        context,
      ).selectedProfileId;
      final selectedProfileId =
          profiles.any((profile) => profile['id']?.toString() == _profileId)
          ? _profileId
          : profiles.any(
              (profile) => profile['id']?.toString() == globalProfileId,
            )
          ? globalProfileId
          : (profiles
                        .where((profile) => profile['profile_type'] == 'SELF')
                        .firstOrNull ??
                    profiles.firstOrNull)?['id']
                ?.toString();
      final documents = await ApiService.fetchMedicalDocuments(
        profileId: selectedProfileId,
      );
      if (!mounted) return;
      if (selectedProfileId != null) {
        ProfileSelectionScope.of(context).selectProfileId(selectedProfileId);
      }
      setState(() {
        _profiles = profiles;
        _profileId = selectedProfileId;
        _documents = documents;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException ? error.message : error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectProfile(String? id) async {
    if (id == null || id == _profileId) return;
    ProfileSelectionScope.of(context).selectProfileId(id);
    setState(() => _profileId = id);
    await _loadData();
  }

  Future<void> _uploadDocument() async {
    if (_profileId == null || _isUploading) return;
    final selection = await FilePicker.pickFiles(
      dialogTitle: 'Chọn ảnh hồ sơ y tế',
      type: FileType.image,
    );
    if (selection.isEmpty || !mounted) return;
    final file = selection.first;
    final fileSize = await file.length();
    if (!mounted) return;
    if (fileSize == null) {
      _showMessage('Không đọc được kích thước ảnh đã chọn.');
      return;
    }
    if (fileSize > 10 * 1024 * 1024) {
      _showMessage('Tệp phải nhỏ hơn hoặc bằng 10 MB.');
      return;
    }

    final metadata =
        await showDialog<({String title, String type, String description})>(
          context: context,
          builder: (context) => const _DocumentMetadataDialog(),
        );
    if (metadata == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final uploadedDocument = await ApiService.uploadMedicalDocument(
        profileId: _profileId!,
        documentType: metadata.type,
        title: metadata.title,
        description: metadata.description,
        fileName: file.name,
        fileBytes: await file.readAsBytes(),
      );
      if (!mounted) return;
      setState(() {
        _documents = [
          uploadedDocument,
          ..._documents.where(
            (document) => document['id'] != uploadedDocument['id'],
          ),
        ];
      });
      _showMessage('Đã tải tài liệu lên.');
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is ApiException ? error.message : 'Không thể tải tài liệu lên.',
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> document) async {
    try {
      final bytes = await ApiService.downloadMedicalDocument(
        document['id'].toString(),
      );
      if (!mounted) return;
      final fileName =
          document['file_name']?.toString() ??
          '${document['title'] ?? 'medical-document'}.pdf';
      final extension = fileName.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/pdf',
      };
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        dialogTitle: 'Lưu tài liệu y tế',
      );
      if (mounted && saved != null) {
        _showMessage('Đã lưu tài liệu xuống thiết bị.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is ApiException
              ? error.message
              : 'Không thể tải tài liệu xuống.',
        );
      }
    }
  }

  bool _isImageDocument(Map<String, dynamic> document) {
    final name = (document['file_name'] ?? document['file_url'] ?? '')
        .toString()
        .split('?')
        .first
        .toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  Future<void> _previewDocument(Map<String, dynamic> document) async {
    final token = await TokenStorage.getAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      _showMessage('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      return;
    }
    final documentId = document['id']?.toString();
    if (documentId == null || documentId.isEmpty) {
      _showMessage('Không tìm thấy mã tài liệu.');
      return;
    }
    final imageUrl =
        '${ApiService.baseUrl}/medical-records/documents/$documentId/download/';
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF101817),
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 900,
          height: MediaQuery.sizeOf(dialogContext).height * 0.82,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  document['title']?.toString() ?? 'Ảnh hồ sơ y tế',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      headers: {'Authorization': 'Bearer $token'},
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                      errorBuilder: (context, error, stackTrace) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Không thể tải ảnh xem trước. Hãy kiểm tra kết nối hoặc tải tệp xuống.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDocument(Map<String, dynamic> document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài liệu?'),
        content: Text('Tài liệu "${document['title']}" sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteMedicalDocument(document['id'].toString());
      if (!mounted) return;
      setState(() {
        _documents.removeWhere((item) => item['id'] == document['id']);
      });
      _showMessage('Đã xóa tài liệu.');
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is ApiException ? error.message : 'Không thể xóa tài liệu.',
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _documentType(String? type) => switch (type) {
    'PRESCRIPTION' => 'Đơn thuốc',
    'LAB_RESULT' => 'Kết quả xét nghiệm',
    'IMAGING' => 'Chẩn đoán hình ảnh',
    _ => 'Tài liệu khác',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Hồ sơ y tế',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isUploading ? null : _uploadDocument,
            icon: _isUploading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Thêm tài liệu'),
          ),
        ],
      ),
      body: SkyBackground(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: _teal,
            onRefresh: _loadData,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    children: [
                      const ProfileContextBanner(),
                      if (_profiles.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _profileId,
                          decoration: const InputDecoration(
                            labelText: 'Hồ sơ thành viên',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: [
                            for (final profile in _profiles)
                              DropdownMenuItem(
                                value: profile['id'].toString(),
                                child: Text(
                                  profile['full_name']?.toString() ?? 'Hồ sơ',
                                ),
                              ),
                          ],
                          onChanged: _selectProfile,
                        ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        _StateCard(
                          icon: Icons.error_outline,
                          text: _error!,
                          action: TextButton(
                            onPressed: _loadData,
                            child: const Text('Thử lại'),
                          ),
                        )
                      else if (_documents.isEmpty)
                        _StateCard(
                          icon: Icons.folder_open_outlined,
                          text: 'Chưa có tài liệu y tế cho hồ sơ này.',
                          action: FilledButton.icon(
                            onPressed: _isUploading ? null : _uploadDocument,
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm tài liệu'),
                          ),
                        )
                      else
                        for (final document in _documents) ...[
                          const SizedBox(height: 10),
                          _DocumentCard(
                            title:
                                document['title']?.toString() ??
                                'Tài liệu y tế',
                            type: _documentType(
                              document['document_type']?.toString(),
                            ),
                            description:
                                document['description']?.toString() ?? '',
                            uploadedAt:
                                document['uploaded_at']?.toString() ?? '',
                            onPreview: _isImageDocument(document)
                                ? () => _previewDocument(document)
                                : null,
                            onDownload: () => _downloadDocument(document),
                            onDelete: () => _deleteDocument(document),
                          ),
                        ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DocumentMetadataDialog extends StatefulWidget {
  const _DocumentMetadataDialog();

  @override
  State<_DocumentMetadataDialog> createState() =>
      _DocumentMetadataDialogState();
}

class _DocumentMetadataDialogState extends State<_DocumentMetadataDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'PRESCRIPTION';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thông tin tài liệu'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tên tài liệu'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nhập tên tài liệu'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Loại tài liệu'),
              items: const [
                DropdownMenuItem(
                  value: 'PRESCRIPTION',
                  child: Text('Đơn thuốc'),
                ),
                DropdownMenuItem(
                  value: 'LAB_RESULT',
                  child: Text('Xét nghiệm'),
                ),
                DropdownMenuItem(
                  value: 'IMAGING',
                  child: Text('Chẩn đoán hình ảnh'),
                ),
                DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            title: _titleController.text.trim(),
            type: _type,
            description: _descriptionController.text.trim(),
          ));
        },
        child: const Text('Tiếp tục tải lên'),
      ),
    ],
  );
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.title,
    required this.type,
    required this.description,
    required this.uploadedAt,
    this.onPreview,
    required this.onDownload,
    required this.onDelete,
  });

  final String title;
  final String type;
  final String description;
  final String uploadedAt;
  final VoidCallback? onPreview;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFE7F5F2),
          child: Icon(Icons.description_outlined, color: Color(0xFF168B83)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF18343A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$type${uploadedAt.isEmpty ? '' : ' · ${uploadedAt.substring(0, uploadedAt.length >= 10 ? 10 : uploadedAt.length)}'}',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onPreview,
          tooltip: 'Xem ảnh',
          icon: const Icon(Icons.zoom_in, color: Color(0xFF168B83)),
        ),
        IconButton(
          onPressed: onDownload,
          tooltip: 'Tải xuống',
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: 'Xóa tài liệu',
          icon: const Icon(Icons.delete_outline, color: Color(0xFFC74747)),
        ),
      ],
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.text,
    required this.action,
  });

  final IconData icon;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Icon(icon, size: 34, color: const Color(0xFF168B83)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        action,
      ],
    ),
  );
}
