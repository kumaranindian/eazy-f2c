import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UnsplashImagePicker extends StatefulWidget {
  final String? initialImageUrl;
  final Function(String imageUrl) onImageSelected;

  const UnsplashImagePicker({
    super.key,
    this.initialImageUrl,
    required this.onImageSelected,
  });

  @override
  State<UnsplashImagePicker> createState() => _UnsplashImagePickerState();
}

class _UnsplashImagePickerState extends State<UnsplashImagePicker> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _images = [];
  bool _isLoading = false;
  String? _selectedImageUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedImageUrl = widget.initialImageUrl;
    _searchController.text = 'food vegetables fruits';
    _searchImages(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchImages(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Using Unsplash API with demo access key
      // Note: In production, you should use your own API key
      final response = await http.get(
        Uri.parse(
          'https://api.unsplash.com/search/photos?query=$query&per_page=20&orientation=squarish',
        ),
        headers: {
          'Authorization': 'Client-ID demo', // Demo key for development
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _images = data['results'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load images. Using mock data.';
          _isLoading = false;
          _images = _getMockImages(query);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading images. Using mock data.';
        _isLoading = false;
        _images = _getMockImages(query);
      });
    }
  }

  List<dynamic> _getMockImages(String query) {
    // Mock images for development/demo purposes
    return [
      {
        'urls': {
          'regular': 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400',
          'small': 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=200',
        },
        'description': 'Fresh vegetables',
      },
      {
        'urls': {
          'regular': 'https://images.unsplash.com/photo-1568702846914-96b305d2ujk?w=400',
          'small': 'https://images.unsplash.com/photo-1568702846914-96b305d2ujk?w=200',
        },
        'description': 'Fresh fruits',
      },
      {
        'urls': {
          'regular': 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400',
          'small': 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=200',
        },
        'description': 'Organic produce',
      },
      {
        'urls': {
          'regular': 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=400',
          'small': 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=200',
        },
        'description': 'Fresh greens',
      },
      {
        'urls': {
          'regular': 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400',
          'small': 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=200',
        },
        'description': 'Farm fresh',
      },
      {
        'urls': {
          'regular': 'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?w=400',
          'small': 'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?w=200',
        },
        'description': 'Vegetables',
      },
      {
        'urls': {
          'regular': 'https://images.unsplash.com/photo-1518977676601-b53f82ber2?w=400',
          'small': 'https://images.unsplash.com/photo-1518977676601-b53f82ber2?w=200',
        },
        'description': 'Fresh produce',
      },
      {
        'urls': {
          'regular': 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=400',
          'small': 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=200',
        },
        'description': 'Organic food',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Select Image from Unsplash',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_selectedImageUrl != null)
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onImageSelected(_selectedImageUrl!);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Use Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search images (e.g., vegetables, fruits)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                  ),
                  onSubmitted: _searchImages,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _searchImages(_searchController.text),
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_images.isEmpty)
            const Center(
              child: Text('No images found'),
            )
          else
            Container(
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final image = _images[index];
                  final imageUrl = image['urls']['regular'];
                  final isSelected = _selectedImageUrl == imageUrl;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImageUrl = imageUrl;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.green : Colors.grey[300]!,
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          if (_selectedImageUrl != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text(
                    'Selected: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      _selectedImageUrl!,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
