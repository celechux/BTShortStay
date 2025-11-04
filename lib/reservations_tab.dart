import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'chat_detail_page.dart';

class ReservationsTab extends StatefulWidget {
  final String hostUID;
  const ReservationsTab({super.key, required this.hostUID});

  @override
  State<ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends State<ReservationsTab> {
  String _selectedFilter = 'All Reservations';
  final Set<String> _expandedCards = <String>{};

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height - 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 16),
            child: Column(
              children: [
                // Filter Section - Using Payments Tab Card Design
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: isMobile ? 16 : 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(isMobile ? 16 : 28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isMobile
                      ? // Dropdown for Mobile
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2196F3).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFilter,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFF2196F3),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2196F3),
                              ),
                              items: ['All Reservations', 'Pending', 'Confirmed', 'Cancelled']
                                  .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _selectedFilter == value
                                              ? const Color(0xFF2196F3)
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(value),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedFilter = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        )
                      : // Filter Chips for Desktop/Tablet
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All Reservations', 'Pending', 'Confirmed', 'Cancelled']
                                .map((filter) => Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: _buildFilterChip(filter),
                                    ))
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
          
          // Reservations List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading reservations...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading reservations',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _selectedFilter == 'All Reservations'
                              ? 'No reservations yet'
                              : 'No ${_selectedFilter.toLowerCase()} reservations',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reservations for your apartments will appear here',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 16,
                    vertical: 8,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final reservation = snapshot.data!.docs[index];
                    final data = reservation.data() as Map<String, dynamic>;
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? double.infinity : 900,
                        ),
                        child: _buildReservationCard(
                          reservation.id,
                          data,
                          isMobile,
                          isTablet,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Download Button at Bottom
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Center(
              child: SizedBox(
                width: isMobile ? 200 : 250,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadReservationsPDF(),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download Reservations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChatWithGuest({
    required String? guestUid,
    required String guestName,
    required String? apartmentId,
    required String? apartmentTitle,
  }) async {
    if (guestUid == null || guestUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Guest information not available')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening chat...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Create deterministic chatId (same for both users)
      // Sort IDs to ensure consistency
      final ids = [widget.hostUID, guestUid]..sort();
      final chatId = '${ids[0]}_${ids[1]}';

      // Check if chat exists, if not create it
      final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final chatSnapshot = await chatDoc.get();

      if (!chatSnapshot.exists) {
        await chatDoc.set({
          'guestUid': guestUid,
          'hostId': widget.hostUID,
          'apartmentId': apartmentId ?? '',
          'apartmentTitle': apartmentTitle ?? 'Apartment',
          'lastMessage': '',
          'timestamp': FieldValue.serverTimestamp(),
          'participants': [widget.hostUID, guestUid],
          'unreadCount': {
            widget.hostUID: 0,
            guestUid: 0,
          },
        });
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Navigate to chat page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              chatId: chatId,
              otherUserId: guestUid,
              apartmentTitle: apartmentTitle ?? 'Apartment',
              otherUserName: guestName,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error opening chat: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _downloadReservationsPDF() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Generating PDF...'),
            ],
          ),
          backgroundColor: Color(0xFF2196F3),
          duration: Duration(seconds: 2),
        ),
      );

      // Fetch all reservations for the host
      final snapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('hostUID', isEqualTo: widget.hostUID)
          .get();

      // Create PDF
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reservations History',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Generated on: ${_formatFullDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Total Reservations: ${snapshot.docs.length}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                    pw.Divider(thickness: 2),
                  ],
                ),
              ),
              
              // Reservations Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                    children: [
                      _pdfTableCell('Apartment', isHeader: true),
                      _pdfTableCell('Guest', isHeader: true),
                      _pdfTableCell('Check-in', isHeader: true),
                      _pdfTableCell('Check-out', isHeader: true),
                      _pdfTableCell('Amount', isHeader: true),
                      _pdfTableCell('Status', isHeader: true),
                    ],
                  ),
                  
                  // Data Rows
                  ...snapshot.docs.map((doc) {
                    final data = doc.data();
                    final checkIn = data['checkIn'] as Timestamp?;
                    final checkOut = data['checkOut'] as Timestamp?;
                    
                    return pw.TableRow(
                      children: [
                        _pdfTableCell(data['apartmentTitle'] ?? 'N/A'),
                        _pdfTableCell(data['guestName'] ?? data['guestEmail'] ?? 'N/A'),
                        _pdfTableCell(checkIn != null ? _formatDate(checkIn.toDate()) : 'N/A'),
                        _pdfTableCell(checkOut != null ? _formatDate(checkOut.toDate()) : 'N/A'),
                        _pdfTableCell('₦${_formatAmount(data['totalAmount'] ?? data['total'])}'),
                        _pdfTableCell((data['status']?.toString() ?? 'N/A').toUpperCase()),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      // Save and share PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'reservations_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  pw.Widget _pdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(
        filter,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: isSelected ? Colors.white : const Color(0xFF2196F3),
        ),
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: const Color(0xFF2196F3),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF2196F3).withOpacity(0.3),
        width: 1.5,
      ),
      checkmarkColor: Colors.white,
      elevation: isSelected ? 2 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildReservationCard(
    String reservationId,
    Map<String, dynamic> data,
    bool isMobile,
    bool isTablet,
  ) {
    final isExpanded = _expandedCards.contains(reservationId);
    final checkIn = data['checkIn'] as Timestamp?;
    final checkOut = data['checkOut'] as Timestamp?;
    final status = data['status']?.toString().toLowerCase() ?? 'unknown';
    final paymentStatus = data['paymentStatus']?.toString().toLowerCase() ?? 'unknown';

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (Always Visible) - Slimmer Design
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(reservationId);
                } else {
                  _expandedCards.add(reservationId);
                }
              });
            },
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 12 : 14,
              ),
              child: Row(
                children: [
                  // Apartment Image - Smaller
                  Container(
                    width: isMobile ? 40 : 48,
                    height: isMobile ? 40 : 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                      color: Colors.grey.shade100,
                    ),
                    child: data['apartmentImage'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                            child: Image.network(
                              data['apartmentImage'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.home_rounded, 
                                       size: isMobile ? 20 : 24, 
                                       color: Colors.grey.shade400),
                            ),
                          )
                        : Icon(Icons.home_rounded, 
                               size: isMobile ? 20 : 24, 
                               color: Colors.grey.shade400),
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
                  // Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['apartmentTitle'] ?? 'Apartment Reservation',
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isMobile ? 2 : 3),
                        Text(
                          'Guest: ${data['guestName'] ?? data['guestEmail'] ?? 'Not specified'}',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  // Amount (visible on desktop only)
                  if (!isMobile)
                    Text(
                      '₦${_formatAmount(data['totalAmount'] ?? data['total'])}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  SizedBox(width: isMobile ? 6 : 12),
                  // Status and Expand Icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(status, _getStatusColor(status), isMobile),
                      SizedBox(height: isMobile ? 4 : 6),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                        size: isMobile ? 18 : 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded Content
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Status Badge
                  _buildStatusBadge(paymentStatus, _getPaymentStatusColor(paymentStatus), isMobile),
                  const SizedBox(height: 12),
                  
                  // Booking Details
                  isMobile
                      ? Column(
                          children: [
                            _buildInfoCard(
                              'Check-in',
                              checkIn != null ? _formatDate(checkIn.toDate()) : 'Not set',
                              Icons.login,
                              Colors.blue,
                              isMobile,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoCard(
                              'Check-out',
                              checkOut != null ? _formatDate(checkOut.toDate()) : 'Not set',
                              Icons.logout,
                              Colors.orange,
                              isMobile,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoCard(
                              'Total',
                              '₦${_formatAmount(data['totalAmount'] ?? data['total'])}',
                              Icons.payment,
                              Colors.green,
                              isMobile,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Check-in',
                                checkIn != null ? _formatDate(checkIn.toDate()) : 'Not set',
                                Icons.login,
                                Colors.blue,
                                isMobile,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                'Check-out',
                                checkOut != null ? _formatDate(checkOut.toDate()) : 'Not set',
                                Icons.logout,
                                Colors.orange,
                                isMobile,
                              ),
                            ),
                          ],
                        ),
                  
                  // Reservation ID
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${reservationId.substring(0, 8)}',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Special Requests (if any)
                  if (data['specialRequests'] != null && 
                      data['specialRequests'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note_outlined, 
                                   size: 14, 
                                   color: Colors.blue.shade600),
                              const SizedBox(width: 6),
                              Text(
                                'Special Requests:',
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['specialRequests'].toString(),
                            style: TextStyle(fontSize: isMobile ? 11 : 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Message Guest Button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openChatWithGuest(
                        guestUid: data['guestUID'] ?? data['guestUid'],
                        guestName: data['guestName'] ?? 'Guest',
                        apartmentId: data['apartmentId'],
                        apartmentTitle: data['apartmentTitle'],
                      ),
                      icon: const Icon(Icons.message_outlined, size: 18),
                      label: Text(
                        'Message ${data['guestName']?.split(' ')[0] ?? 'Guest'}',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8,
        vertical: isMobile ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 9 : 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: isMobile ? 16 : 18, color: color),
          SizedBox(height: isMobile ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 9 : 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 1 : 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = FirebaseFirestore.instance
        .collection('reservations')
        .where('hostUID', isEqualTo: widget.hostUID);

    if (_selectedFilter != 'All Reservations') {
      query = query.where('status', isEqualTo: _selectedFilter.toLowerCase());
    }

    return query.snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatFullDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return 'N/A';
    final num = double.tryParse(amount.toString()) ?? 0;
    if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toStringAsFixed(0);
  }
}