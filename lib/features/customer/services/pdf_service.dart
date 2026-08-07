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
    @media print {
      body { margin: 0; }
      .no-print { display: none; }
    }
    
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 32px;
      color: #333;
    }
    
    .header {
      background: #2e7d32;
      color: white;
      padding: 24px;
      border-radius: 8px 8px 0 0;
      margin-bottom: 24px;
    }
    
    .header h1 {
      font-size: 32px;
      margin-bottom: 8px;
    }
    
    .header .bill-number {
      font-size: 14px;
      opacity: 0.9;
    }
    
    .company-info {
      margin-bottom: 24px;
    }
    
    .company-info h2 {
      font-size: 20px;
      color: #2e7d32;
      margin-bottom: 4px;
    }
    
    .company-info p {
      color: #666;
    }
    
    .customer-info {
      background: #f5f5f5;
      padding: 16px;
      border-radius: 8px;
      border: 1px solid #ddd;
      margin-bottom: 24px;
    }
    
    .customer-info .label {
      font-size: 12px;
      color: #666;
      font-weight: bold;
      margin-bottom: 8px;
    }
    
    .customer-info .name {
      font-size: 16px;
      font-weight: bold;
      margin-bottom: 4px;
    }
    
    .order-info {
      display: flex;
      gap: 16px;
      margin-bottom: 24px;
    }
    
    .info-card {
      flex: 1;
      background: #e8f5e9;
      padding: 12px;
      border-radius: 8px;
    }
    
    .info-card .label {
      font-size: 12px;
      color: #666;
      margin-bottom: 4px;
    }
    
    .info-card .value {
      font-size: 14px;
      font-weight: bold;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 24px;
    }
    
    th {
      background: #f5f5f5;
      padding: 12px;
      text-align: left;
      font-size: 12px;
      font-weight: bold;
      border: 1px solid #ddd;
    }
    
    td {
      padding: 12px;
      border: 1px solid #ddd;
      font-size: 13px;
    }
    
    .totals {
      background: #f5f5f5;
      padding: 16px;
      border-radius: 8px;
      border: 1px solid #ddd;
      margin-bottom: 24px;
    }
    
    .total-row {
      display: flex;
      justify-content: space-between;
      padding: 4px 0;
    }
    
    .total-row.grand {
      font-size: 18px;
      font-weight: bold;
      padding-top: 12px;
      border-top: 2px solid #ddd;
      margin-top: 8px;
    }
    
    .payment-status {
      display: inline-block;
      padding: 8px 16px;
      border-radius: 20px;
      font-weight: bold;
      font-size: 12px;
      margin-top: 12px;
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
      padding: 16px;
      border-radius: 8px;
      border: 1px solid #ffb74d;
      margin-bottom: 24px;
    }
    
    .notes .title {
      font-weight: bold;
      color: #e65100;
      margin-bottom: 8px;
    }
    
    .footer {
      text-align: center;
      padding-top: 24px;
      border-top: 1px solid #ddd;
      color: #666;
      font-size: 12px;
    }
    
    .print-button {
      background: #2e7d32;
      color: white;
      padding: 12px 24px;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 14px;
      margin-bottom: 16px;
    }
    
    .print-button:hover {
      background: #1b5e20;
    }
  </style>
</head>
<body>
  <button class="print-button no-print" onclick="window.print()">🖨️ Print Invoice</button>
  
  <div class="header">
    <h1>INVOICE</h1>
    <div class="bill-number">${bill.billNumber}</div>
  </div>
  
  <div class="company-info">
    <h2>F2C - Farm2Community</h2>
    <p>Fresh from Farm to Your Community</p>
  </div>
  
  <div class="customer-info">
    <div class="label">Bill To:</div>
    <div class="name">${bill.customerName}</div>
    <div>${bill.customerPhone}</div>
    ${bill.customerEmail != null ? '<div>${bill.customerEmail}</div>' : ''}
    ${bill.customerAddress != null ? '<div>${bill.customerAddress}</div>' : ''}
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
  
  <table>
    <thead>
      <tr>
        <th>#</th>
        <th>Product</th>
        <th>Ordered</th>
        ${bill.hasVariations ? '<th>Actual</th>' : ''}
        <th style="text-align: right;">Price</th>
        <th style="text-align: right;">Amount</th>
      </tr>
    </thead>
    <tbody>
      ${_generateItemsHtml(bill)}
    </tbody>
  </table>
  
  <div class="totals">
    <div class="total-row">
      <span>Subtotal</span>
      <span>₹${bill.finalSubtotal.toStringAsFixed(2)}</span>
    </div>
    <div class="total-row">
      <span>Delivery Charges</span>
      <span>₹${bill.deliveryCharges.toStringAsFixed(2)}</span>
    </div>
    <div class="total-row">
      <span>Cleaning Charges</span>
      <span>₹${bill.cleaningCharges.toStringAsFixed(2)}</span>
    </div>
    <div class="total-row grand">
      <span>Total</span>
      <span>₹${bill.finalTotal.toStringAsFixed(2)}</span>
    </div>
    <div class="payment-status ${bill.paymentStatus}">
      ${bill.paymentStatus == 'paid' ? 'PAID' : 'PENDING'}
    </div>
  </div>
  
  ${bill.packagingNotes != null ? '''
  <div class="notes">
    <div class="title">Packaging Notes</div>
    <div>${bill.packagingNotes}</div>
  </div>
  ''' : ''}
  
  <div class="footer">
    <p>Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(bill.generatedAt)}</p>
    <p style="margin-top: 8px; font-weight: bold; color: #2e7d32;">Thank you for your business!</p>
  </div>
</body>
</html>
''';
  }

  String _generateItemsHtml(BillModel bill) {
    return bill.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return '''
        <tr>
          <td>${index + 1}</td>
          <td>
            <strong>${item.productName}</strong><br>
            <small style="color: #666;">Farmer: ${item.farmerName}</small>
            ${item.hasVariation && item.variationReason != null ? '<br><small style="color: #e65100;">${item.variationReason}</small>' : ''}
          </td>
          <td>${item.formattedOrderedQuantity}</td>
          ${bill.hasVariations ? '<td>${item.formattedActualQuantity}</td>' : ''}
          <td style="text-align: right;">₹${item.finalPrice.toStringAsFixed(2)}/${item.orderedUnit}</td>
          <td style="text-align: right;"><strong>₹${item.finalAmount.toStringAsFixed(2)}</strong></td>
        </tr>
      ''';
    }).join('\n');
  }
}
