import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/network/token_storage.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/profile_selection.dart';
import 'package:frontend/theme/app_colors.dart';
import 'package:frontend/theme/app_spacing.dart';
import 'package:frontend/widgets/widgets.dart';
import 'package:frontend/widgets/profile_context_banner.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  static const _teal = AppColors.primary;

  // TODO(SCR-07): Add profile-scoped CRUD for MedicalHistory, Allergy, Visit,
  // Medication, and LabResult. This screen currently manages uploaded documents only.

  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _documents = [];
  String? _profileId;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;
  int _loadRequestId = 0;
  ProfileSelectionController? _profileSelection;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selection = ProfileSelectionScope.of(context);
    if (identical(selection, _profileSelection)) return;
    _profileSelection?.removeListener(_onProfileSelectionChanged);
    _profileSelection = selection;
    selection.addListener(_onProfileSelectionChanged);
  }

  void _onProfileSelectionChanged() {
    final selectedProfileId = _profileSelection?.selectedProfileId;
    if (!mounted ||
        selectedProfileId == null ||
        selectedProfileId == _profileId) {
      return;
    }
    setState(() {
      _profileId = selectedProfileId;
      _documents = [];
    });
    _loadData();
  }

  Future<void> _loadData() async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profiles = await ApiService.fetchProfiles();
      if (!mounted || requestId != _loadRequestId) return;
      final selection = ProfileSelectionScope.of(context);
      selection.setProfiles(profiles);
      final currentProfileId = selection.selectedProfileId;
      final selectedProfileId =
      profiles.any(
            (profile) => profile['id']?.toString() == currentProfileId,
      )
          ? currentProfileId
          : (profiles.where(isCurrentUserProfile).firstOrNull ??
          profiles.firstOrNull)?['id']
          ?.toString();
      final documents = await ApiService.fetchMedicalDocuments(
        profileId: selectedProfileId,
      );
      if (!mounted ||
          requestId != _loadRequestId ||
          selectedProfileId != selection.selectedProfileId) {
        return;
      }
      if (selectedProfileId != null) {
        selection.selectProfileId(selectedProfileId);
      }
      setState(() {
        _profiles = profiles;
        _profileId = selectedProfileId;
        _documents = documents;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _error = error is ApiException ? error.message : error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectProfile(String? id) async {
    if (id == null || id == _profileId) return;
    ProfileSelectionScope.of(context).selectProfileId(id);
  }

  @override
  void dispose() {
    _profileSelection?.removeListener(_onProfileSelectionChanged);
    super.dispose();
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
        backgroundColor: AppColors.textPrimary,
        insetPadding: const EdgeInsets.all(AppSpacing.x4),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.surface),
                ),
                trailing: IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: AppColors.surface),
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
                          color: AppColors.surface,
                        ),
                      ),
                      errorBuilder: (context, error, stackTrace) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.x6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.surface.withValues(alpha: .75),
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Không thể tải ảnh xem trước. Hãy kiểm tra kết nối hoặc tải tệp xuống.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                color: AppColors.surface.withValues(
                                  alpha: .75,
                                ),
                              ),
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
    final selectableProfiles = _profiles
        .where((profile) => profile['id'] != null)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Hồ sơ y tế',
          style: Theme.of(context).textTheme.titleLarge,
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x3,
                AppSpacing.x4,
                AppSpacing.x6,
              ),
              children: [
                const ProfileContextBanner(),
                if (selectableProfiles.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _profileId,
                    isExpanded: true,
                    // Menu options have a title and subtitle; let them
                    // size to content. The closed field uses one line.
                    itemHeight: null,
                    decoration: const InputDecoration(
                      labelText: 'Hồ sơ thành viên',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    selectedItemBuilder: (context) => selectableProfiles
                        .map(
                          (profile) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _profileOptionLabel(profile),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(growable: false),
                    items: [
                      for (final profile in selectableProfiles)
                        DropdownMenuItem(
                          value: profile['id'].toString(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _profileOptionLabel(profile),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                profileDemographicSubtitle(profile),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: _selectProfile,
                  ),
                const SizedBox(height: AppSpacing.x4),
                const SectionHeader(title: 'Tài liệu y tế'),
                const SizedBox(height: AppSpacing.x2),
                if (_error != null)
                  ErrorState(message: _error!, onRetry: _loadData)
                else if (_documents.isEmpty)
                  EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'Chưa có tài liệu y tế',
                    message:
                    'Tải lên đơn thuốc, xét nghiệm hoặc hồ sơ y tế cho thành viên này.',
                    action: PrimaryButton(
                      label: 'Thêm tài liệu',
                      icon: Icons.add,
                      isLoading: _isUploading,
                      onPressed: _uploadDocument,
                    ),
                  )
                else
                  for (final document in _documents) ...[
                    const SizedBox(height: AppSpacing.x2),
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

  String _profileOptionLabel(Map<String, dynamic> profile) {
    final name = profileDisplayName(profile);
    final role = profileRoleLabel(profile);
    return role == null ? name : '$name [$role]';
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
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.x3),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(Icons.description_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                '$type${uploadedAt.isEmpty ? '' : ' · ${uploadedAt.substring(0, uploadedAt.length >= 10 ? 10 : uploadedAt.length)}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x1),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onPreview,
          tooltip: 'Xem ảnh',
          icon: const Icon(Icons.zoom_in, color: AppColors.primary),
        ),
        IconButton(
          onPressed: onDownload,
          tooltip: 'Tải xuống',
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: 'Xóa tài liệu',
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        ),
      ],
    ),
  );
}
