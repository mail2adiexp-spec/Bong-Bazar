import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentProofUploadWidget extends StatefulWidget {
  final String orderId;
  final String deliveryPartnerId;
  final VoidCallback onUploadComplete;

  const PaymentProofUploadWidget({
    super.key,
    required this.orderId,
    required this.deliveryPartnerId,
    required this.onUploadComplete,
  });

  @override
  State<PaymentProofUploadWidget> createState() => _PaymentProofUploadWidgetState();
}

class _PaymentProofUploadWidgetState extends State<PaymentProofUploadWidget> {
  File? _proofFile;
  Uint8List? _proofBytes;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (image == null) return;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _proofBytes = bytes;
          _proofFile = null;
        });
      } else {
        setState(() {
          _proofFile = File(image.path);
          _proofBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _uploadProof() async {
    if (_proofFile == null && _proofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select payment screenshot first')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload to Firebase Storage
      final fileName = 'payment_proof_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('payment_proofs')
          .child(widget.orderId)
          .child(fileName);

      String downloadUrl;
      if (kIsWeb) {
        await ref.putData(
          _proofBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        downloadUrl = await ref.getDownloadURL();
      } else {
        await ref.putFile(_proofFile!);
        downloadUrl = await ref.getDownloadURL();
      }

      // Update order document
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'paymentMethod': 'qr_code',
        'paymentProofUrl': downloadUrl,
        'paymentProofUploadedAt': FieldValue.serverTimestamp(),
        'paymentProofUploadedBy': widget.deliveryPartnerId,
        'paymentVerified': false, // Admin will verify
      });

      // Clear selection
      setState(() {
        _proofFile = null;
        _proofBytes = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUploadComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Upload Payment Proof',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Please upload screenshot of payment success message',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Image Preview
            if (_proofFile != null || _proofBytes != null) ...[
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.memory(_proofBytes!, fit: BoxFit.contain)
                        : Image.file(_proofFile!, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(
                      _proofFile == null && _proofBytes == null
                          ? 'Select Screenshot'
                          : 'Change Screenshot',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_proofFile == null && _proofBytes == null) || _isUploading
                        ? null
                        : _uploadProof,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
