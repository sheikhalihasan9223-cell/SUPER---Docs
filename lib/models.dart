import 'dart:typed_data';
import 'package:flutter/material.dart';

const brandPurple = Color(0xFF7428F5);
const lavenderCanvas = Color(0xFFF8F6FF);
const lavenderBorder = Color(0xFFEDE7FA);
const blue = Color(0xFF4268ED);
const purple = Color(0xFF8F3CF8);
const green = Color(0xFF21B65B);

class DocTool {
  final String id, name, description, category;
  final IconData icon;
  final Color color;
  final bool local, available;
  const DocTool(
    this.id,
    this.name,
    this.description,
    this.category,
    this.icon,
    this.color, {
    this.local = false,
    this.available = true,
  });
  bool get image => category == 'Image tools';
  List<String> get inputExtensions => switch (id) {
    'word_pdf' => ['doc', 'docx'],
    'ppt_pdf' => ['ppt', 'pptx'],
    'excel_pdf' => ['xls', 'xlsx'],
    'image_pdf' => ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tif', 'tiff'],
    _ =>
      image
          ? ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tif', 'tiff']
          : ['pdf'],
  };
  bool get officeInput => ['word_pdf', 'ppt_pdf', 'excel_pdf'].contains(id);
  String get assetPath => 'assets/tool_icons_3d/$id.png';
}

const tools = <DocTool>[
  DocTool(
    'merge',
    'Merge PDF',
    'Bring your documents together.',
    'Organize',
    Icons.merge_type_rounded,
    brandPurple,
  ),
  DocTool(
    'split',
    'Split PDF',
    'Keep just the pages you need.',
    'Organize',
    Icons.call_split_rounded,
    brandPurple,
  ),
  DocTool(
    'organize',
    'Organize PDF',
    'Reorder, remove, and repeat pages.',
    'Organize',
    Icons.dashboard_customize_outlined,
    brandPurple,
  ),
  DocTool(
    'rotate',
    'Rotate PDF',
    'Get every page facing the right way.',
    'Organize',
    Icons.rotate_right_rounded,
    brandPurple,
  ),
  DocTool(
    'extract',
    'Extract Pages',
    'Make a new PDF from selected pages.',
    'Organize',
    Icons.content_copy_outlined,
    brandPurple,
  ),
  DocTool(
    'compress',
    'Compress PDF',
    'A smaller file. Easier to share.',
    'Optimize',
    Icons.compress_rounded,
    green,
  ),
  DocTool(
    'repair',
    'Repair PDF',
    'Rebuild readable PDF structures.',
    'Optimize',
    Icons.build_outlined,
    green,
  ),
  DocTool(
    'ocr',
    'OCR PDF',
    'Turn scans into searchable text.',
    'Optimize',
    Icons.document_scanner_outlined,
    green,
  ),
  DocTool(
    'word_pdf',
    'Word to PDF',
    'Turn your documents into PDFs.',
    'Convert to PDF',
    Icons.description_outlined,
    blue,
  ),
  DocTool(
    'ppt_pdf',
    'PowerPoint to PDF',
    'Give your slides a portable home.',
    'Convert to PDF',
    Icons.slideshow_rounded,
    blue,
  ),
  DocTool(
    'excel_pdf',
    'Excel to PDF',
    'Share spreadsheets with their layout.',
    'Convert to PDF',
    Icons.table_chart_outlined,
    blue,
  ),
  DocTool(
    'image_pdf',
    'Image to PDF',
    'Your photos in one document.',
    'Convert to PDF',
    Icons.image_outlined,
    blue,
    local: true,
  ),
  DocTool(
    'create',
    'Create PDF',
    'Start fresh with a note or letter.',
    'Convert to PDF',
    Icons.note_add_outlined,
    blue,
    local: true,
  ),
  DocTool(
    'pdf_word',
    'PDF to Word',
    'Make your document editable.',
    'Convert from PDF',
    Icons.article_outlined,
    purple,
  ),
  DocTool(
    'pdf_ppt',
    'PDF to PowerPoint',
    'Turn pages into a presentation.',
    'Convert from PDF',
    Icons.present_to_all_rounded,
    purple,
  ),
  DocTool(
    'pdf_excel',
    'PDF to Excel',
    'Give your tables room to work.',
    'Convert from PDF',
    Icons.grid_on_rounded,
    purple,
  ),
  DocTool(
    'pdf_jpg',
    'PDF to JPG',
    'Save each page as a crisp image.',
    'Convert from PDF',
    Icons.photo_library_outlined,
    purple,
  ),
  DocTool(
    'text',
    'Extract Text',
    'Take the words with you.',
    'Convert from PDF',
    Icons.text_snippet_outlined,
    purple,
  ),
  DocTool(
    'edit',
    'Edit PDF',
    'Annotate text, shapes, and highlights.',
    'Edit & enhance',
    Icons.edit_note_rounded,
    blue,
  ),
  DocTool(
    'numbers',
    'Page Numbers',
    'Keep your document in order.',
    'Edit & enhance',
    Icons.format_list_numbered_rounded,
    blue,
  ),
  DocTool(
    'watermark',
    'Watermark',
    'Make your mark on every page.',
    'Edit & enhance',
    Icons.branding_watermark_outlined,
    blue,
  ),
  DocTool(
    'sign',
    'Sign PDF',
    'Draw and place your signature.',
    'Edit & enhance',
    Icons.draw_outlined,
    blue,
  ),
  DocTool(
    'protect',
    'Protect PDF',
    'Keep it private with a password.',
    'Security',
    Icons.lock_outline_rounded,
    green,
  ),
  DocTool(
    'unlock',
    'Unlock PDF',
    'Open a file using its password.',
    'Security',
    Icons.lock_open_rounded,
    green,
  ),
  DocTool(
    'image_compress',
    'Compress Image',
    'Less weight, plenty of detail.',
    'Image tools',
    Icons.compress_rounded,
    brandPurple,
    local: true,
  ),
  DocTool(
    'image_jpg',
    'Convert to JPG',
    'Make photos easy to share.',
    'Image tools',
    Icons.image_outlined,
    blue,
    local: true,
  ),
  DocTool(
    'image_convert',
    'Convert from JPG',
    'Export as PNG, GIF, BMP, or TIFF.',
    'Image tools',
    Icons.swap_horiz_rounded,
    purple,
    local: true,
  ),
  DocTool(
    'image_resize',
    'Resize Image',
    'The perfect size for every occasion.',
    'Image tools',
    Icons.aspect_ratio_rounded,
    green,
    local: true,
  ),
];

class DocFile {
  final String id;
  String name;
  final Uint8List bytes;
  final DateTime created;
  final String tool;
  bool favorite;
  DocFile({
    required this.id,
    required this.name,
    required this.bytes,
    required this.created,
    required this.tool,
    this.favorite = false,
  });
  String get extension => name.split('.').last.toLowerCase();
}

String fileSize(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

const imageEnhanceTool = DocTool(
  'image_enhance',
  'Enhance Photo',
  'Enhance with on-device AI or local automatic correction.',
  'Image tools',
  Icons.auto_awesome,
  brandPurple,
  local: true,
);
