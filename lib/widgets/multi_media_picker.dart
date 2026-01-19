import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class MediaItem {
  final String id;
  final File? fileWeb;
  final XFile? fileNative;
  final bool isVideo;
  final String? videoUrl;

  MediaItem({
    required this.id,
    this.fileWeb,
    this.fileNative,
    this.isVideo = false,
    this.videoUrl,
  });
}

class MultiMediaPicker extends StatefulWidget {
  final Function(List<MediaItem>) onMediaSelected;
  final int maxImages;
  final bool allowVideo;
  final int maxVideoDurationSeconds;

  const MultiMediaPicker({
    super.key,
    required this.onMediaSelected,
    this.maxImages = 4,
    this.allowVideo = true,
    this.maxVideoDurationSeconds = 40,
  });

  @override
  State<MultiMediaPicker> createState() => _MultiMediaPickerState();
}

class _MultiMediaPickerState extends State<MultiMediaPicker> {
  final List<MediaItem> _selectedMedia = [];
  final PageController _pageController = PageController();
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedMedia.length >= widget.maxImages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Maximum ${widget.maxImages} images allowed")),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedMedia.add(
          MediaItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            fileWeb: kIsWeb ? null : File(pickedFile.path),
            fileNative: kIsWeb ? pickedFile : null,
            isVideo: false,
          ),
        );
      });
      widget.onMediaSelected(_selectedMedia);

      // Auto-scroll to newly added item
      if (_selectedMedia.length > 1) {
        _pageController.animateToPage(
          _selectedMedia.length - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    if (!widget.allowVideo) {
      return;
    }

    if (_selectedMedia.any((m) => m.isVideo)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Only 1 video allowed per product")),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: Duration(seconds: widget.maxVideoDurationSeconds),
    );

    if (pickedFile != null) {
      setState(() {
        _selectedMedia.add(
          MediaItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            fileWeb: kIsWeb ? null : File(pickedFile.path),
            fileNative: kIsWeb ? pickedFile : null,
            isVideo: true,
          ),
        );
      });
      widget.onMediaSelected(_selectedMedia);
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
    widget.onMediaSelected(_selectedMedia);

    // Reset page position if needed
    if (_currentPage >= _selectedMedia.length && _selectedMedia.isNotEmpty) {
      _pageController.animateToPage(
        _selectedMedia.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media Display Area
        if (_selectedMedia.isEmpty)
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    "No media selected",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              // Media Carousel
              SizedBox(
                height: 300,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _selectedMedia.length,
                  itemBuilder: (context, index) => _buildMediaTile(index),
                ),
              ),
              const SizedBox(height: 12),

              // Indicator and Counter
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dots Indicator
                  if (_selectedMedia.length > 1)
                    Row(
                      children: List.generate(
                        _selectedMedia.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: index == _currentPage ? 24 : 8,
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? Colors.blue
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  // Item Counter
                  Text(
                    "${_currentPage + 1}/${_selectedMedia.length}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Add Media Buttons
        Row(
          children: [
            // Add Image Button
            if (_selectedMedia.length < widget.maxImages)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text("Add Image"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (_selectedMedia.length < widget.maxImages && widget.allowVideo)
              const SizedBox(width: 12),

            // Add Video Button
            if (widget.allowVideo && !_selectedMedia.any((m) => m.isVideo))
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: const Text("Add Video"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Help Text
        if (_selectedMedia.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Select up to ${widget.maxImages} images${widget.allowVideo ? ' and 1 video' : ''}",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaTile(int index) {
    final media = _selectedMedia[index];

    return Stack(
      children: [
        // Media Content
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: media.isVideo
              ? _buildVideoThumbnail(media)
              : _buildImagePreview(media),
        ),

        // Delete Button
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => _removeMedia(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),

        // Video Badge
        if (media.isVideo)
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.videocam, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    "Video",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePreview(MediaItem media) {
    if (kIsWeb && media.fileNative != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          media.fileNative!.path,
          fit: BoxFit.cover,
        ),
      );
    } else if (!kIsWeb && media.fileWeb != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          media.fileWeb!,
          fit: BoxFit.cover,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/placeholder.png', fit: BoxFit.cover),
    );
  }

  Widget _buildVideoThumbnail(MediaItem media) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(height: 8),
              Text(
                media.videoUrl ?? "Local video",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
