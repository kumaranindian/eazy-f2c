import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:f2c/core/services/firebase_storage_service.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';

/// Widget for picking and uploading images to Firebase Storage
/// Provides a clean UI for image selection and upload progress
class FirebaseImagePicker extends StatefulWidget {
  final String? initialImageUrl;
  final Function(String imageUrl) onImageSelected;
  final String folder;
  final double? width;
  final double? height;

  const FirebaseImagePicker({
    super.key,
    this.initialImageUrl,
    required this.onImageSelected,
    this.folder = 'product_images',
    this.width,
    this.height,
  });

  @override
  State<FirebaseImagePicker> createState() => _FirebaseImagePickerState();
}

class _FirebaseImagePickerState extends State<FirebaseImagePicker> {
  final FirebaseStorageService _storageService = FirebaseStorageService();
  String? _imageUrl;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      // Create file input element for web
      final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/jpeg,image/jpg,image/png,image/gif,image/webp';
      uploadInput.click();

      // Wait for file selection
      await uploadInput.onChange.first;

      if (uploadInput.files == null || uploadInput.files!.isEmpty) {
        return;
      }

      final html.File file = uploadInput.files!.first;

      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        _showError('Image size must be less than 5MB');
        return;
      }

      // Validate file type
      final allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
      if (!allowedTypes.contains(file.type)) {
        _showError('Please select a valid image file (JPG, PNG, GIF, or WebP)');
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      // Read file as bytes
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final Uint8List bytes = reader.result as Uint8List;

      setState(() {
        _selectedImageBytes = bytes;
      });

      // Generate unique file name
      final fileName = _storageService.generateUniqueFileName(file.name);

      // Upload to Firebase Storage
      final downloadUrl = await _storageService.uploadFile(
        bytes: bytes,
        fileName: fileName,
        folder: widget.folder,
      );

      setState(() {
        _imageUrl = downloadUrl;
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      // Notify parent widget
      widget.onImageSelected(downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error picking/uploading image', e, stackTrace);
      setState(() {
        _isUploading = false;
      });
      _showError('Failed to upload image: ${e.toString()}');
    }
  }

  Future<void> _removeImage() async {
    try {
      if (_imageUrl != null) {
        // Delete from Firebase Storage
        await _storageService.deleteFile(_imageUrl!);
      }

      setState(() {
        _imageUrl = null;
        _selectedImageBytes = null;
      });

      widget.onImageSelected('');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image removed successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error removing image', e, stackTrace);
      _showError('Failed to remove image: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? 300,
      height: widget.height ?? 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: _imageUrl != null
          ? _buildImagePreview()
          : _isUploading
              ? _buildUploadProgress()
              : _buildPlaceholder(),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CachedNetworkImage(
            imageUrl: _imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
            ),
            httpHeaders: const {
              'Access-Control-Allow-Origin': '*',
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: _pickAndUploadImage,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: _removeImage,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Uploading image...',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_uploadProgress > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return InkWell(
      onTap: _pickAndUploadImage,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Click to upload image',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'JPG, PNG, GIF, or WebP (max 5MB)',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
