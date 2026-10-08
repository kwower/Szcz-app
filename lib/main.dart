import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToothbrushApp());
}

class ToothbrushApp extends StatelessWidget {
  const ToothbrushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Licznik Szczoteczek',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class ToothbrushItem {
  final String id;
  final String serialNumber;
  final String repairDate;
  final String imagePath;

  ToothbrushItem({
    required this.id,
    required this.serialNumber,
    required this.repairDate,
    required this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serialNumber': serialNumber,
      'repairDate': repairDate,
      'imagePath': imagePath,
    };
  }

  factory ToothbrushItem.fromMap(Map<String, dynamic> map) {
    return ToothbrushItem(
      id: map['id'],
      serialNumber: map['serialNumber'],
      repairDate: map['repairDate'],
      imagePath: map['imagePath'],
    );
  }
}

class StorageService {
  static const String _key = 'toothbrush_items';

  static Future<void> saveItems(List<ToothbrushItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> stringList =
        items.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList(_key, stringList);
  }

  static Future<List<ToothbrushItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? stringList = prefs.getStringList(_key);
    if (stringList == null) return [];

    return stringList
        .map((item) => ToothbrushItem.fromMap(jsonDecode(item)))
        .toList();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ToothbrushItem> _items = [];
  List<ToothbrushItem> _filteredItems = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final data = await StorageService.getItems();
    if (!mounted) return;
    setState(() {
      _items = data.reversed.toList();
      _filteredItems = _items;
      _isLoading = false;
    });
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _items
          .where((item) =>
              item.serialNumber.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _addNewItem(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile == null) return;
    if (!mounted) return;

    final serialController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Dodaj nową naprawę'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.file(
                      File(pickedFile.path),
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: serialController,
                      decoration: const InputDecoration(
                        labelText: 'Numer seryjny szczoteczki',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Data naprawy'),
                      subtitle: Text(
                        DateFormat('dd.MM.yyyy').format(selectedDate),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anuluj'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (serialController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wprowadź numer seryjny!'),
                        ),
                      );
                      return;
                    }

                    final appDir = await getApplicationDocumentsDirectory();
                    final fileName =
                        '${DateTime.now().millisecondsSinceEpoch}.jpg';
                    final savedImage = await File(pickedFile.path)
                        .copy('${appDir.path}/$fileName');

                    final newItem = ToothbrushItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      serialNumber: serialController.text.trim(),
                      repairDate: DateFormat('dd.MM.yyyy').format(selectedDate),
                      imagePath: savedImage.path,
                    );

                    _items.insert(0, newItem);
                    await StorageService.saveItems(_items);

                    if (!context.mounted || !mounted) return;
                    Navigator.pop(context);
                    _loadItems();
                  },
                  child: const Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );
    serialController.dispose();
  }

  Future<void> _deleteItem(String id, String imagePath) async {
    _items.removeWhere((item) => item.id == id);
    await StorageService.saveItems(_items);

    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
    if (!mounted) return;
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeria Szczoteczek'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Łącznie naprawionych szczoteczek',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_items.length}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterItems,
              decoration: InputDecoration(
                hintText: 'Szukaj po numerze seryjnym...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? const Center(
                        child: Text('Brak zapisanych szczoteczek'),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _showDetailDialog(item),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Image.file(
                                            File(item.imagePath),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                const Icon(Icons.broken_image,
                                                    size: 50),
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: CircleAvatar(
                                            backgroundColor: Colors.black54,
                                            radius: 16,
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              onPressed: () {
                                                _deleteItem(
                                                    item.id, item.imagePath);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'S/N: ${item.serialNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.build,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.repairDate,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImageSourceDialog(),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Dodaj zdjęcie'),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Zrobić zdjęcie aparatem'),
              onTap: () {
                Navigator.pop(context);
                _addNewItem(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Wybierz z galerii telefonu'),
              onTap: () {
                Navigator.pop(context);
                _addNewItem(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(ToothbrushItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(
              File(item.imagePath),
              fit: BoxFit.contain,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Numer seryjny: ${item.serialNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data naprawy: ${item.repairDate}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zamknij'),
            ),
          ],
        ),
      ),
    );
  }
}
