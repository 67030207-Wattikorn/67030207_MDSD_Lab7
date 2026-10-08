import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/listing_draft.dart';
import '../services/gemini_vision_service.dart';
import '../repositories/listing_draft_repository.dart';

class SellItemPage extends StatefulWidget {
  final ListingDraftRepository draftRepository;

  const SellItemPage({
    super.key,
    required this.draftRepository,
  });

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  // ============================================================
  // PROMPT
  // ============================================================

  // ใส่ Prompt เดิมของคุณตรงนี้
  static const String _prompt = '''
ใส่ Prompt เดิมของคุณที่ใช้กับ Gemini ตรงนี้
''';

  // ============================================================
  // ตัวแปร
  // ============================================================

  Uint8List? _imageBytes;
  String? _imagePath;

  bool _isLoading = false;

  ListingDraft? _draft;
  

  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // TextEditingController
  // ============================================================

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _categoryController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  // ============================================================
  // Dispose
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  // ============================================================
  // เลือกรูปภาพ
  // ============================================================

  Future<void> pickImage() async {
    final XFile? result = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (result == null) {
      return;
    }

    final bytes = await result.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      _imagePath = result.path;

      _draft = null;
      
      _errorMessage = null;

      _titleController.clear();
      _categoryController.clear();
      _descriptionController.clear();
    });
  }

  // ============================================================
  // ให้ Gemini วิเคราะห์รูป
  // ============================================================

  Future<void> analyzeImage() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกรูปสินค้าก่อน'),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
      _draft = null;
      _errorMessage = null;
    });

    try {
      final result =
          await GeminiVisionService().analyzeProductImage(
        _imageBytes!,
        _prompt,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _draft = result;
        _isLoading = false;

        // Human-in-the-loop
        _titleController.text = result.title;
        _categoryController.text = result.category;
        _descriptionController.text = result.description;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // ยืนยันร่างประกาศ
  // ============================================================

  Future<void> confirmDraft() async {
    // ตรวจสอบข้อมูล
    if (_titleController.text.trim().isEmpty ||
        _categoryController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง'),
        ),
      );

      return;
    }

    // ตรวจสอบรูป
    if (_imagePath == null || _imagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกรูปสินค้า'),
        ),
      );

      return;
    }

    // สร้าง ListingDraft จากข้อมูลที่ผู้ใช้ตรวจสอบแล้ว
    final finalDraft = ListingDraft(
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    try {
      // บันทึกลง Drift Database
      await widget.draftRepository.saveDraft(
        finalDraft,
        _imagePath!,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกร่างประกาศลงฐานข้อมูลแล้ว'),
        ),
      );

      // ล้างฟอร์ม
      setState(() {
        _imageBytes = null;
        _imagePath = null;
        _draft = null;
       
        _errorMessage = null;

        _titleController.clear();
        _categoryController.clear();
        _descriptionController.clear();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกไม่สำเร็จ: $e'),
        ),
      );
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงประกาศขาย'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            // ==================================================
            // รูปสินค้า
            // ==================================================

            Container(
              width: double.infinity,
              height: 250,

              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey,
                ),
                borderRadius: BorderRadius.circular(12),
              ),

              child: _imageBytes != null
                  ? ClipRRect(
                      borderRadius:
                          BorderRadius.circular(12),

                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Center(
                      child: Text(
                        'ยังไม่ได้เลือกรูปสินค้า',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // ปุ่มเลือกรูป
            // ==================================================

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed:
                    _isLoading ? null : pickImage,

                icon: const Icon(
                  Icons.photo_library,
                ),

                label: const Text(
                  'เลือกรูปภาพสินค้า',
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // ปุ่ม AI
            // ==================================================

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed:
                    _isLoading ? null : analyzeImage,

                icon: const Icon(
                  Icons.auto_awesome,
                ),

                label: const Text(
                  'ให้ AI ช่วยแนะนำ',
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // Loading
            // ==================================================

            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),

                  SizedBox(height: 12),

                  Text(
                    'AI กำลังวิเคราะห์ภาพสินค้า...',
                  ),
                ],
              ),

            // ==================================================
            // Error
            // ==================================================

            if (_errorMessage != null)
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(12),

                margin: const EdgeInsets.only(
                  top: 16,
                ),

                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.red,
                  ),
                  borderRadius:
                      BorderRadius.circular(8),
                ),

                child: Text(
                  'เกิดข้อผิดพลาด:\n$_errorMessage',

                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),

            // ==================================================
            // Human-in-the-loop
            // ==================================================

            if (_draft != null) ...[
              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  'ตรวจทานและแก้ไขข้อมูล',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  'ตรวจสอบข้อมูลที่ AI แนะนำก่อนยืนยัน',

                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ชื่อประกาศ
              TextField(
                controller: _titleController,

                decoration:
                    const InputDecoration(
                  labelText: 'ชื่อประกาศ',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // หมวดหมู่
              TextField(
                controller: _categoryController,

                decoration:
                    const InputDecoration(
                  labelText: 'หมวดหมู่',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // คำบรรยาย
              TextField(
                controller:
                    _descriptionController,

                maxLines: 4,

                decoration:
                    const InputDecoration(
                  labelText: 'คำบรรยาย',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 16),

              // =================================================
              // ยืนยันร่างประกาศ
              // =================================================

              SizedBox(
                width: double.infinity,

                child: ElevatedButton.icon(
                  onPressed: confirmDraft,

                  icon: const Icon(
                    Icons.check,
                  ),

                  label: const Text(
                    'ยืนยันร่างประกาศ',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}