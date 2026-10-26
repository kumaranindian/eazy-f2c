import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/services/bulk_product_normalizer.dart';
import 'package:xml/xml.dart';

class BulkParseResult {
  const BulkParseResult({required this.rows, required this.errors});

  final List<BulkProductRow> rows;

  /// File-level problems (unreadable file, missing columns, no data).
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// Reads an .xlsx or .csv product sheet into [BulkProductRow]s. Pure Dart
/// (no Firebase), so it can be unit tested.
class BulkProductParser {
  const BulkProductParser._();

  static const String templateCsv =
      'Sl No,PRODUCT NAME,DISPLAY NAME,PRICE,PROFIT MARGIN,STOCK,CATEGORY,'
      'UNIT,FARMER NAME\r\n'
      '1,Sample Rice - 1Kg,Sample Rice - 1Kg,100,10,30,Cereals,Packet,'
      'Existing Farmer Name\r\n';

  static const Map<String, List<String>> _aliases = {
    'slNo': ['slno', 'sno', 'sl', 'serialno', 'no', 'srno'],
    'name': ['productname', 'productnamefarmer', 'name'],
    'displayName': ['displayname', 'displaynamecustomer'],
    'price': ['price', 'sellingprice'],
    'margin': ['profitmargin', 'margin', 'profit'],
    'stock': ['stock', 'stockquantity', 'quantity', 'qty'],
    'category': ['category'],
    'unit': ['unit', 'uom'],
    'farmer': ['farmername', 'farmer'],
  };

  static const List<String> _requiredFields = [
    'name',
    'price',
    'category',
    'unit',
    'farmer',
  ];

  static const Map<String, String> _fieldLabels = {
    'name': 'PRODUCT NAME',
    'price': 'PRICE',
    'category': 'CATEGORY',
    'unit': 'UNIT',
    'farmer': 'FARMER NAME',
  };

  static BulkParseResult parse({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase();
    try {
      final List<List<String>> table;
      if (lower.endsWith('.csv')) {
        table = _readCsv(utf8.decode(bytes, allowMalformed: true));
      } else if (lower.endsWith('.xlsx')) {
        table = _readXlsx(bytes);
      } else {
        return const BulkParseResult(
          rows: [],
          errors: ['Unsupported file type. Upload an .xlsx or .csv file.'],
        );
      }
      return _toRows(table);
    } catch (e) {
      return BulkParseResult(
        rows: const [],
        errors: ['Could not read the file: $e'],
      );
    }
  }

  /// Reads the first worksheet of an .xlsx file. Done by hand (zip + XML)
  /// because spreadsheet packages choke on some Excel-written styles.
  static List<List<String>> _readXlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    String? read(String name) {
      final file = archive.findFile(name);
      if (file == null) return null;
      return utf8.decode(file.readBytes() ?? Uint8List(0));
    }

    final shared = <String>[];
    final sharedXml = read('xl/sharedStrings.xml');
    if (sharedXml != null) {
      for (final si in XmlDocument.parse(sharedXml).findAllElements('si')) {
        // Plain <t> or rich-text <r><t>; phonetic <rPh> text is ignored.
        final buffer = StringBuffer();
        for (final child in si.childElements) {
          if (child.name.local == 't') {
            buffer.write(child.innerText);
          } else if (child.name.local == 'r') {
            for (final t in child.findElements('t')) {
              buffer.write(t.innerText);
            }
          }
        }
        shared.add(buffer.toString());
      }
    }

    final sheetXml =
        read(_firstSheetPath(read)) ?? read('xl/worksheets/sheet1.xml');
    if (sheetXml == null) return const [];

    final table = <List<String>>[];
    for (final rowEl in XmlDocument.parse(sheetXml).findAllElements('row')) {
      final rowNumber = int.tryParse(rowEl.getAttribute('r') ?? '');
      final index = (rowNumber ?? table.length + 1) - 1;
      while (table.length < index) {
        table.add(<String>[]);
      }
      final line = <String>[];
      for (final c in rowEl.findElements('c')) {
        final column = _columnIndex(c.getAttribute('r') ?? '');
        if (column < 0) continue;
        while (line.length < column) {
          line.add('');
        }
        final value = _xlsxCellText(c, shared);
        if (line.length == column) {
          line.add(value);
        } else {
          line[column] = value;
        }
      }
      table.add(line);
    }
    return table;
  }

  static String _firstSheetPath(String? Function(String) read) {
    const fallback = 'xl/worksheets/sheet1.xml';
    final workbook = read('xl/workbook.xml');
    final rels = read('xl/_rels/workbook.xml.rels');
    if (workbook == null || rels == null) return fallback;
    final sheet =
        XmlDocument.parse(workbook).findAllElements('sheet').firstOrNull;
    final relId = sheet?.attributes
        .where((a) => a.name.local == 'id')
        .map((a) => a.value)
        .firstOrNull;
    if (relId == null) return fallback;
    for (final rel in XmlDocument.parse(rels).findAllElements('Relationship')) {
      if (rel.getAttribute('Id') == relId) {
        final target = rel.getAttribute('Target');
        if (target == null) return fallback;
        return target.startsWith('/') ? target.substring(1) : 'xl/$target';
      }
    }
    return fallback;
  }

  /// "AB12" -> 27 (zero-based column), or -1 if there is no column.
  static int _columnIndex(String ref) {
    var index = 0;
    var letters = 0;
    for (final unit in ref.toUpperCase().codeUnits) {
      if (unit < 65 || unit > 90) break;
      index = index * 26 + (unit - 64);
      letters++;
    }
    return letters == 0 ? -1 : index - 1;
  }

  static String _xlsxCellText(XmlElement cell, List<String> shared) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      return cell.findAllElements('t').map((t) => t.innerText).join();
    }
    final raw = cell.getElement('v')?.innerText ?? '';
    if (type == 's') {
      final i = int.tryParse(raw);
      return i != null && i >= 0 && i < shared.length ? shared[i] : '';
    }
    if (type == 'str' || type == 'e' || type == 'b') return raw;
    // Numeric: print integers without ".0" and avoid float noise.
    final number = double.tryParse(raw);
    if (number == null) return raw;
    return number == number.roundToDouble() && number.abs() < 1e15
        ? number.toInt().toString()
        : number.toString();
  }

  /// Minimal RFC 4180 reader (quoted fields, escaped quotes, CRLF).
  static List<List<String>> _readCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    final input = text.startsWith('﻿') ? text.substring(1) : text;

    void endField() {
      row.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        endField();
      } else if (c == '\n') {
        endRow();
      } else if (c != '\r') {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  static String _headerKey(String header) =>
      header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static BulkParseResult _toRows(List<List<String>> table) {
    if (table.isEmpty) {
      return const BulkParseResult(rows: [], errors: ['The file is empty.']);
    }

    final columns = <String, int>{};
    final headers = table.first.map(_headerKey).toList();
    for (final entry in _aliases.entries) {
      final index = headers.indexWhere(entry.value.contains);
      if (index >= 0) columns[entry.key] = index;
    }

    final missing = _requiredFields
        .where((f) => !columns.containsKey(f))
        .map((f) => _fieldLabels[f]!)
        .toList();
    if (missing.isNotEmpty) {
      return BulkParseResult(
        rows: const [],
        errors: ['Missing required column(s): ${missing.join(', ')}.'],
      );
    }

    String cell(List<String> line, String field) {
      final index = columns[field];
      if (index == null || index >= line.length) return '';
      return line[index];
    }

    String fix(
      String field,
      String raw,
      List<RowCorrection> corrections,
    ) {
      final original = BulkProductNormalizer.tidy(raw);
      final result = BulkProductNormalizer.fixTypos(raw);
      if (result.corrected) {
        corrections.add(
          RowCorrection(field: field, from: original, to: result.text),
        );
      }
      return result.text;
    }

    final rows = <BulkProductRow>[];
    for (var i = 1; i < table.length; i++) {
      final line = table[i];
      if (line.every((c) => c.trim().isEmpty)) continue;

      final corrections = <RowCorrection>[];
      final name = fix('Product name', cell(line, 'name'), corrections);
      final displayRaw = cell(line, 'displayName');
      final displayName = displayRaw.trim().isEmpty
          ? name
          : fix('Display name', displayRaw, corrections);

      rows.add(
        BulkProductRow(
          sheetRow: i + 1,
          slNo: cell(line, 'slNo').trim(),
          name: name,
          displayName: displayName,
          priceText: cell(line, 'price').trim(),
          marginText: cell(line, 'margin').trim(),
          stockText: cell(line, 'stock').trim(),
          category: fix('Category', cell(line, 'category'), corrections),
          unit: BulkProductNormalizer.tidy(cell(line, 'unit')),
          farmerName: BulkProductNormalizer.tidy(cell(line, 'farmer')),
          corrections: corrections,
        ),
      );
    }

    if (rows.isEmpty) {
      return const BulkParseResult(
        rows: [],
        errors: ['No product rows found below the header.'],
      );
    }
    return BulkParseResult(rows: rows, errors: const []);
  }
}
