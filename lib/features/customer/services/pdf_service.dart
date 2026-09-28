import 'dart:html' as html;
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/bill_model.dart';

class PdfService {
  /// Generate HTML invoice and download/print it
  Future<void> downloadBillPdf(BillModel bill) async {
    // Generate HTML content
    final htmlContent = _generateHtmlInvoice(bill);

    // Create a blob URL
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Open in new tab for printing
    html.window.open(url, '_blank');

    // Clean up after a delay
    Future.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  String _generateHtmlInvoice(BillModel bill) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Invoice - ${bill.billNumber}</title>
  <style>
    @page {
      size: A4;
      margin: 10mm;
    }
    
    @media print {
      body { 
        margin: 0; 
        padding: 0;
      }
      .no-print { display: none; }
      .page-break { page-break-before: always; }
      .avoid-break { page-break-inside: avoid; }
      table { page-break-inside: auto; }
      tr { page-break-inside: avoid; page-break-after: auto; }
      thead { display: table-header-group; }
      tfoot { display: table-footer-group; }
    }
    
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 12px;
      color: #333;
      font-size: 11px;
      line-height: 1.3;
    }
    
    .header {
      background: linear-gradient(135deg, #2e7d32 0%, #388e3c 100%);
      color: white;
      padding: 10px 12px;
      border-radius: 4px;
      margin-bottom: 8px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    
    .header h1 {
      font-size: 18px;
      margin: 0;
    }
    
    .header .bill-number {
      font-size: 10px;
      opacity: 0.9;
    }
    
    .header .updated-badge {
      background: #ff9800;
      padding: 3px 8px;
      border-radius: 3px;
      font-size: 9px;
      font-weight: bold;
    }
    
    .top-section {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 8px;
    }
    
    .company-info {
      flex: 1;
    }
    
    .company-info h2 {
      font-size: 14px;
      color: #2e7d32;
      margin-bottom: 2px;
    }
    
    .company-info p {
      color: #666;
      font-size: 10px;
    }
    
    .customer-info {
      flex: 1;
      background: #f9f9f9;
      padding: 8px;
      border-radius: 4px;
      border: 1px solid #e0e0e0;
    }
    
    .customer-info .label {
      font-size: 9px;
      color: #666;
      font-weight: bold;
      margin-bottom: 3px;
    }
    
    .customer-info .name {
      font-size: 12px;
      font-weight: bold;
      margin-bottom: 2px;
    }
    
    .customer-info div {
      font-size: 10px;
      line-height: 1.4;
    }
    
    .order-info {
      display: flex;
      gap: 8px;
      margin-bottom: 8px;
    }
    
    .info-card {
      flex: 1;
      background: #e8f5e9;
      padding: 6px 8px;
      border-radius: 3px;
      text-align: center;
    }
    
    .info-card .label {
      font-size: 9px;
      color: #666;
      margin-bottom: 2px;
    }
    
    .info-card .value {
      font-size: 11px;
      font-weight: bold;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 8px;
    }
    
    th {
      background: #f5f5f5;
      padding: 6px 4px;
      text-align: left;
      font-size: 10px;
      font-weight: bold;
      border: 1px solid #ddd;
    }
    
    td {
      padding: 5px 4px;
      border: 1px solid #e0e0e0;
      font-size: 10px;
      vertical-align: top;
    }
    
    td strong {
      font-size: 10px;
    }
    
    td small {
      font-size: 8px;
      line-height: 1.2;
    }
    
    .totals {
      background: #f9f9f9;
      padding: 8px 10px;
      border-radius: 4px;
      border: 1px solid #e0e0e0;
      margin-bottom: 8px;
      max-width: 350px;
      margin-left: auto;
    }
    
    .total-row {
      display: flex;
      justify-content: space-between;
      padding: 2px 0;
      font-size: 10px;
    }
    
    .total-row.grand {
      font-size: 13px;
      font-weight: bold;
      padding-top: 6px;
      border-top: 2px solid #2e7d32;
      margin-top: 4px;
    }
    
    .payment-status {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 12px;
      font-weight: bold;
      font-size: 9px;
      margin-top: 6px;
    }
    
    .payment-status.paid {
      background: #c8e6c9;
      color: #2e7d32;
      border: 1px solid #2e7d32;
    }
    
    .payment-status.pending {
      background: #ffe0b2;
      color: #e65100;
      border: 1px solid #e65100;
    }
    
    .notes {
      background: #fff3e0;
      padding: 8px;
      border-radius: 4px;
      border: 1px solid #ffb74d;
      margin-bottom: 8px;
    }
    
    .notes .title {
      font-weight: bold;
      color: #e65100;
      margin-bottom: 4px;
      font-size: 10px;
    }
    
    .notes div {
      font-size: 9px;
    }
    
    .footer {
      text-align: center;
      padding-top: 8px;
      border-top: 1px solid #ddd;
      color: #666;
      font-size: 9px;
    }
    
    .footer p {
      margin: 2px 0;
    }
    
    .print-button {
      background: #2e7d32;
      color: white;
      padding: 10px 20px;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 12px;
      margin-bottom: 12px;
    }
    
    .print-button:hover {
      background: #1b5e20;
    }
  </style>
</head>
<body>
  <button class="print-button no-print" onclick="window.print()">🖨️ Print Invoice</button>
  
  <div class="header">
    <div>
      <h1>INVOICE</h1>
      <div class="bill-number">${bill.billNumber}</div>
    </div>
    ${bill.hasVariations ? '<div class="updated-badge">UPDATED</div>' : ''}
  </div>
  
  <div class="top-section">
    <div class="company-info">
      <h2>F2C - Farm2Community</h2>
      <p>Fresh from Farm to Your Community</p>
    </div>
    
    <div class="customer-info">
      <div class="label">BILL TO:</div>
      <div class="name">${bill.customerName}</div>
      <div>${bill.customerPhone}</div>
      ${bill.customerEmail != null ? '<div>${bill.customerEmail}</div>' : ''}
      ${bill.customerAddress != null ? '<div>${bill.customerAddress}</div>' : ''}
    </div>
  </div>
  
  <div class="order-info">
    <div class="info-card">
      <div class="label">Order Date</div>
      <div class="value">${DateFormat('dd MMM yyyy').format(bill.orderDate)}</div>
    </div>
    <div class="info-card">
      <div class="label">Delivery Date</div>
      <div class="value">${DateFormat('dd MMM yyyy').format(bill.deliveryDate)}</div>
    </div>
    <div class="info-card">
      <div class="label">Schedule</div>
      <div class="value">${bill.scheduleName}</div>
    </div>
  </div>
  
  <table class="avoid-break">
    <thead>
      <tr>
        <th style="width: 25px;">#</th>
        <th style="width: ${bill.hasVariations ? '35%' : '45%'};">Product</th>
        <th style="width: ${bill.hasVariations ? '12%' : '15%'}; text-align: center;">Ordered</th>
        ${bill.hasVariations ? '<th style="width: 12%; text-align: center;">Actual</th>' : ''}
        <th style="width: ${bill.hasVariations ? '18%' : '20%'}; text-align: right;">Price</th>
        <th style="width: ${bill.hasVariations ? '18%' : '20%'}; text-align: right;">Amount</th>
      </tr>
    </thead>
    <tbody>
      ${_generateItemsHtml(bill)}
    </tbody>
  </table>
  
  <div class="totals avoid-break">
    ${bill.hasVariations && bill.orderedSubtotal != bill.actualSubtotal ? '''
    <div class="total-row" style="color: #999; text-decoration: line-through;">
      <span>Original Subtotal</span>
      <span>₹${bill.orderedSubtotal.toStringAsFixed(2)}</span>
    </div>
    ''' : ''}
    <div class="total-row">
      <span>Subtotal</span>
      <span>₹${bill.finalSubtotal.toStringAsFixed(2)}</span>
    </div>
    ${bill.deliveryCharges > 0 ? '''
    <div class="total-row">
      <span>Delivery Charges</span>
      <span>₹${bill.deliveryCharges.toStringAsFixed(2)}</span>
    </div>
    ''' : ''}
    ${bill.cleaningCharges > 0 ? '''
    <div class="total-row">
      <span>Cleaning Charges</span>
      <span>₹${bill.cleaningCharges.toStringAsFixed(2)}</span>
    </div>
    ''' : ''}
    ${bill.hasVariations && bill.totalVariation != 0 ? '''
    <div class="total-row" style="color: ${bill.totalVariation! > 0 ? '#d32f2f' : '#388e3c'};">
      <span>Variation</span>
      <span>${bill.totalVariation! > 0 ? '+' : ''}₹${bill.totalVariation!.toStringAsFixed(2)}</span>
    </div>
    ''' : ''}
    <div class="total-row grand">
      <span>TOTAL</span>
      <span>₹${bill.finalTotal.toStringAsFixed(2)}</span>
    </div>
    <div class="payment-status ${bill.paymentStatus}">
      ${bill.paymentStatus == 'paid' ? '✓ PAID' : '⏱ PENDING'}${bill.paidAt != null ? ' • ${DateFormat('dd MMM').format(bill.paidAt!)}' : ''}
    </div>
  </div>
  
  ${bill.packagingNotes != null ? '''
  <div class="notes avoid-break">
    <div class="title">📦 Packaging Notes</div>
    <div>${bill.packagingNotes}</div>
  </div>
  ''' : ''}
  
  <div class="footer">
    <p>Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(bill.generatedAt)}</p>
    <p style="margin-top: 3px; font-weight: bold; color: #2e7d32;">Thank you for choosing F2C - Farm2Community!</p>
  </div>
</body>
</html>
''';
  }

  String _generateItemsHtml(BillModel bill) {
    return bill.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      // Determine if ordered quantity should be struck through
      final orderedStyle = item.hasVariation
          ? 'text-decoration: line-through; color: #999;'
          : '';

      // Determine actual quantity style
      final actualStyle =
          item.hasVariation ? 'font-weight: bold; color: #e65100;' : '';

      return '''
        <tr>
          <td style="text-align: center;">${index + 1}</td>
          <td>
            <strong>${item.productName}</strong><br>
            <small style="color: #666;">Farmer: ${item.farmerName}</small>
            ${item.hasVariation && item.variationReason != null ? '<br><small style="color: #e65100;">⚠ ${item.variationReason}</small>' : ''}
          </td>
          <td style="text-align: center; $orderedStyle">${item.formattedOrderedQuantity}</td>
          ${bill.hasVariations ? '<td style="text-align: center; $actualStyle">${item.formattedActualQuantity}</td>' : ''}
          <td style="text-align: right;">₹${item.finalPrice.toStringAsFixed(0)}/${item.orderedUnit}</td>
          <td style="text-align: right;"><strong>₹${item.finalAmount.toStringAsFixed(2)}</strong></td>
        </tr>
      ''';
    }).join('\n');
  }
}
